import Foundation

struct StatsSnapshot: Codable {
    var cumulativeAwakeSeconds: Double
    var updatedAt: Date
}

/// The in-memory base excludes the running session. Periodic snapshots include
/// it on disk without changing the base, avoiding double counting on stop.
final class StatsStore {
    static var defaultFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("keep-awake/stats.json")
    }

    private let fileURL: URL
    private(set) var cumulativeAwakeSeconds: Double = 0
    private(set) var loadError: String?
    private(set) var hasUnsavedChanges = false

    init(fileURL: URL = StatsStore.defaultFileURL) {
        self.fileURL = fileURL
        do {
            let data = try Data(contentsOf: fileURL)
            let snapshot = try JSONDecoder().decode(StatsSnapshot.self, from: data)
            guard snapshot.cumulativeAwakeSeconds.isFinite,
                  snapshot.cumulativeAwakeSeconds >= 0 else {
                throw CocoaError(.coderReadCorrupt)
            }
            cumulativeAwakeSeconds = snapshot.cumulativeAwakeSeconds
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && error.code == NSFileReadNoSuchFileError {
            // A new installation has no statistics yet.
        } catch {
            loadError = "累计记录无法读取，原文件已保留，本次仍可计时。请检查 stats.json：\(error.localizedDescription)"
        }
    }

    /// Keep the increment in memory even on write failure, so retrying the save
    /// never adds the same session twice.
    func commit(delta: Double) throws {
        guard delta.isFinite, delta >= 0 else { return }
        cumulativeAwakeSeconds += delta
        try persistSnapshot(totalIncludingSession: cumulativeAwakeSeconds)
    }

    func persistSnapshot(totalIncludingSession: Double) throws {
        hasUnsavedChanges = true
        // Never replace unreadable/corrupt historical data with a zero base.
        if let loadError {
            throw StatsError(message: loadError)
        }
        do {
            guard totalIncludingSession.isFinite, totalIncludingSession >= 0 else {
                throw CocoaError(.coderInvalidValue)
            }
            let data = try JSONEncoder().encode(StatsSnapshot(
                cumulativeAwakeSeconds: totalIncludingSession, updatedAt: Date()
            ))
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
            hasUnsavedChanges = false
        } catch {
            throw StatsError(message: "统计未能保存，稍后会重试；退出可能丢失未保存时长。\(error.localizedDescription)")
        }
    }
}

struct StatsError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
