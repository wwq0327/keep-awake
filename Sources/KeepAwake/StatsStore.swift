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
            guard AwakeDuration.isSupported(snapshot.cumulativeAwakeSeconds) else {
                throw CocoaError(.coderReadCorrupt)
            }
            cumulativeAwakeSeconds = snapshot.cumulativeAwakeSeconds
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && error.code == NSFileReadNoSuchFileError {
            // A new installation has no statistics yet.
        } catch {
            loadError = localized("累计记录无法读取，原文件已保留，本次仍可计时。请检查 stats.json：\(error.localizedDescription)", "Could not read total time. The original file is preserved; this session can still be timed. Check stats.json: \(error.localizedDescription)")
        }
    }

    /// Keep the increment in memory even on write failure, so retrying the save
    /// never adds the same session twice.
    func commit(delta: Double) throws {
        let total = cumulativeAwakeSeconds + delta
        guard AwakeDuration.isSupported(delta), AwakeDuration.isSupported(total) else {
            throw StatsError(message: localized(
                "统计时长超出可支持范围，已有累计记录已保留。",
                "Duration is outside the supported range. Existing statistics are preserved."
            ))
        }
        cumulativeAwakeSeconds = total
        try persistSnapshot(totalIncludingSession: cumulativeAwakeSeconds)
    }

    func persistSnapshot(totalIncludingSession: Double) throws {
        guard AwakeDuration.isSupported(totalIncludingSession) else {
            throw StatsError(message: localized(
                "统计时长超出可支持范围，已有累计记录已保留。",
                "Duration is outside the supported range. Existing statistics are preserved."
            ))
        }
        hasUnsavedChanges = true
        // Never replace unreadable/corrupt historical data with a zero base.
        if let loadError {
            throw StatsError(message: loadError)
        }
        do {
            let data = try JSONEncoder().encode(StatsSnapshot(
                cumulativeAwakeSeconds: totalIncludingSession, updatedAt: Date()
            ))
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
            hasUnsavedChanges = false
        } catch {
            throw StatsError(message: localized("统计未能保存，稍后会重试；退出可能丢失未保存时长。\(error.localizedDescription)", "Could not save statistics; retrying later. Quitting may lose unsaved time. \(error.localizedDescription)"))
        }
    }
}

struct StatsError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
