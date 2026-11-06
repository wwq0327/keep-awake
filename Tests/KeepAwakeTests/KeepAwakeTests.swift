import AppKit
import SwiftUI
import Testing
@testable import KeepAwake

private struct SimulatedFailure: LocalizedError {
    var errorDescription: String? { "模拟系统调用失败" }
}

private final class FakePower: PowerControlling {
    var startFails = false
    var stopFails = false
    var active = false
    var starts = 0
    var stops = 0

    func startKeepingAwake() throws {
        starts += 1
        if startFails { throw SimulatedFailure() }
        active = true
    }

    func stopKeepingAwake() throws {
        stops += 1
        if stopFails { throw SimulatedFailure() }
        active = false
    }
}

private final class FakeHotKey: HotKeyRegistering {
    var onToggle: (@MainActor () -> Void)?
    var error: String?
    var registrations = 0
    var unregistrations = 0
    func registerDefaultHotKey() -> String? {
        registrations += 1
        return error
    }
    func unregister() { unregistrations += 1 }
}

private final class TestClock {
    var seconds: TimeInterval = 100
}

private final class Scratch {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("keep-awake-tests-\(UUID().uuidString)", isDirectory: true)
    var statsURL: URL { directory.appendingPathComponent("stats.json") }

    init() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    deinit { try? FileManager.default.removeItem(at: directory) }
}

@MainActor
private struct Fixture {
    let scratch: Scratch
    let power = FakePower()
    let hotKey = FakeHotKey()
    let clock = TestClock()
    let store: StatsStore
    let model: AppState

    init() throws {
        let scratch = try Scratch()
        self.scratch = scratch
        store = StatsStore(fileURL: scratch.statsURL)
        let clock = self.clock
        model = AppState(power: power, stats: store, hotKey: hotKey, clock: { clock.seconds })
    }
}

@Suite(.serialized)
@MainActor
struct AppStateTests {
    @Test func startsOffEvenWithHistory() throws {
        let f = try Fixture()
        try f.store.commit(delta: 125)
        let relaunched = AppState(
            power: f.power, stats: StatsStore(fileURL: f.scratch.statsURL), hotKey: f.hotKey
        )
        #expect(!relaunched.isKeepingAwake)
        #expect(relaunched.totalAwakeSeconds == 125)
        #expect(f.power.starts == 0)
    }

    @Test func failedStartIsVisibleAndDoesNotEnable() throws {
        let f = try Fixture()
        f.power.startFails = true
        var reported = 0
        f.model.onError = { reported += 1 }
        f.model.toggleKeepAwake()
        #expect(!f.model.isKeepingAwake)
        #expect(f.model.powerError != nil)
        #expect(f.model.sessionSeconds == 0)
        #expect(reported == 1)
        f.power.startFails = false
        f.model.toggleKeepAwake()
        #expect(f.model.isKeepingAwake)
        #expect(f.model.powerError == nil)
        f.model.prepareToQuit()
    }

    @Test func failedStopKeepsSwitchOnUntilRetry() throws {
        let f = try Fixture()
        f.model.toggleKeepAwake()
        f.clock.seconds += 15
        f.power.stopFails = true
        f.model.toggleKeepAwake()
        #expect(f.model.isKeepingAwake)
        #expect(f.model.powerError != nil)
        #expect(f.store.cumulativeAwakeSeconds == 0)
        f.power.stopFails = false
        f.clock.seconds += 5
        f.model.toggleKeepAwake()
        #expect(!f.model.isKeepingAwake)
        #expect(f.model.sessionSeconds == 20)
        #expect(f.store.cumulativeAwakeSeconds == 20)
    }

    @Test func delayedTickSavesAndStopDoesNotDoubleCount() throws {
        let f = try Fixture()
        f.model.toggleKeepAwake()
        f.clock.seconds += 61.4
        f.model.tick() // Missed the exact 60-second mark.
        #expect(abs(StatsStore(fileURL: f.scratch.statsURL).cumulativeAwakeSeconds - 61.4) < 0.001)
        #expect(f.store.cumulativeAwakeSeconds == 0)
        f.clock.seconds += 9
        f.model.toggleKeepAwake()
        #expect(abs(f.model.totalAwakeSeconds - 70.4) < 0.001)
        #expect(abs(StatsStore(fileURL: f.scratch.statsURL).cumulativeAwakeSeconds - 70.4) < 0.001)
        f.clock.seconds += 30
        f.model.tick()
        #expect(abs(f.model.sessionSeconds - 70.4) < 0.001)
        f.model.toggleKeepAwake()
        #expect(f.model.sessionSeconds == 0)
        f.clock.seconds += 5
        f.model.toggleKeepAwake()
        #expect(abs(f.model.totalAwakeSeconds - 75.4) < 0.001)
    }

    @Test func sleepAndWallClockChangesDoNotIncreaseAwakeTime() throws {
        let f = try Fixture()
        f.model.toggleKeepAwake()
        f.clock.seconds += 12
        f.model.tick()
        // The injected clock follows CLOCK_UPTIME_RAW: it pauses while asleep.
        // No Date-based value enters the duration calculation.
        f.model.tick()
        #expect(f.model.sessionSeconds == 12)
        #expect(f.model.uptimeSeconds == 12)
        f.clock.seconds += 3
        f.model.toggleKeepAwake()
        #expect(f.model.totalAwakeSeconds == 15)
    }

    @Test func hotkeyFailureLeavesButtonFunctionalAndStartIsIdempotent() throws {
        let f = try Fixture()
        f.hotKey.error = "快捷键被占用，请使用按钮。"
        f.model.start()
        defer { f.model.prepareToQuit() }
        f.model.start()
        #expect(f.hotKey.registrations == 1)
        #expect(f.model.hotKeyError != nil)
        f.model.toggleKeepAwake()
        #expect(f.model.isKeepingAwake)
        #expect(f.model.hotKeyError != nil)
    }

    @Test func hotkeyTogglesAndQuitCommitsOnlyOnce() throws {
        let f = try Fixture()
        f.hotKey.onToggle?()
        #expect(f.model.isKeepingAwake)
        f.clock.seconds += 7
        f.model.prepareToQuit()
        f.model.prepareToQuit()
        #expect(!f.power.active)
        #expect(f.power.stops == 1)
        #expect(f.store.cumulativeAwakeSeconds == 7)
        f.model.toggleKeepAwake()
        #expect(!f.model.isKeepingAwake)
    }

    @Test func hotkeyRetryRecoversWithoutRestartingSession() throws {
        let f = try Fixture()
        f.hotKey.error = "Shortcut in use"
        f.model.start()
        defer { f.model.prepareToQuit() }
        f.model.toggleKeepAwake()
        f.clock.seconds += 10
        f.model.tick()

        f.model.retryHotKey()
        #expect(f.model.hotKeyError != nil)
        #expect(f.hotKey.registrations == 2)
        #expect(f.model.isKeepingAwake)
        #expect(f.model.sessionSeconds == 10)

        f.hotKey.error = nil
        f.model.retryHotKey()
        #expect(f.model.hotKeyError == nil)
        #expect(f.hotKey.registrations == 3)
        #expect(f.model.sessionSeconds == 10)
        #expect(f.model.totalAwakeSeconds == 10)
        #expect(f.power.starts == 1)
        #expect(f.power.stops == 0)
        f.model.retryHotKey() // Already registered: nothing to recover.
        f.model.start()
        #expect(f.hotKey.registrations == 3)

        f.hotKey.onToggle?()
        #expect(!f.model.isKeepingAwake)
        #expect(f.power.stops == 1)
        #expect(f.store.cumulativeAwakeSeconds == 10)
    }

    @Test func hotkeyRetryWhileOffAndAfterQuit() throws {
        let f = try Fixture()
        f.hotKey.error = "Shortcut in use"
        f.model.retryHotKey()
        #expect(f.hotKey.registrations == 0)
        f.model.start()
        f.hotKey.error = nil
        f.model.retryHotKey()
        #expect(f.model.hotKeyError == nil)
        #expect(!f.model.isKeepingAwake)
        #expect(f.power.starts == 0)
        #expect(!f.model.hasSession)

        let quitting = try Fixture()
        quitting.hotKey.error = "Shortcut still in use"
        quitting.model.start()
        quitting.model.prepareToQuit()
        quitting.hotKey.error = nil
        quitting.model.retryHotKey()
        #expect(quitting.hotKey.registrations == 1)
        #expect(quitting.model.hotKeyError != nil)
        f.model.prepareToQuit()
    }

    @Test func quitSavesEvenIfReleaseFails() throws {
        let f = try Fixture()
        f.model.toggleKeepAwake()
        f.power.stopFails = true
        f.clock.seconds += 23
        f.model.prepareToQuit()
        #expect(StatsStore(fileURL: f.scratch.statsURL).cumulativeAwakeSeconds == 23)
    }

    @Test func failedSaveRetriesWhileOffWithoutCountingTwice() throws {
        let f = try Fixture()
        // A directory at the destination reliably causes atomic writes to fail.
        try FileManager.default.createDirectory(at: f.scratch.statsURL, withIntermediateDirectories: true)
        f.model.toggleKeepAwake()
        f.clock.seconds += 10
        f.model.toggleKeepAwake()
        #expect(!f.model.isKeepingAwake)
        #expect(f.model.statsError != nil)
        #expect(f.store.hasUnsavedChanges)
        #expect(f.model.totalAwakeSeconds == 10)
        try FileManager.default.removeItem(at: f.scratch.statsURL)
        f.clock.seconds += 61
        f.model.tick()
        #expect(f.model.statsError == nil)
        #expect(!f.store.hasUnsavedChanges)
        #expect(StatsStore(fileURL: f.scratch.statsURL).cumulativeAwakeSeconds == 10)
    }

    @Test func snapshotFailureDoesNotStopKeepingAndRecovers() throws {
        let f = try Fixture()
        try FileManager.default.createDirectory(at: f.scratch.statsURL, withIntermediateDirectories: true)
        f.model.toggleKeepAwake()
        f.clock.seconds += 61
        f.model.tick()
        #expect(f.model.isKeepingAwake)
        #expect(f.model.statsError != nil)
        try FileManager.default.removeItem(at: f.scratch.statsURL)
        f.clock.seconds += 61
        f.model.tick()
        #expect(f.model.statsError == nil)
        #expect(StatsStore(fileURL: f.scratch.statsURL).cumulativeAwakeSeconds == 122)
        f.model.toggleKeepAwake()
        #expect(f.model.totalAwakeSeconds == 122)
    }

    @Test func rendersOffOnAndMultipleErrors() throws {
        let f = try Fixture()
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let output = root.appendingPathComponent(".build/qa", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        func render(_ name: String, appearance: NSAppearance.Name = .aqua) throws {
            let png = try PanelSnapshot.png(model: f.model, appearance: appearance)
            try png.write(to: output.appendingPathComponent("\(name).png"))
        }
        try render("panel-off")
        try render("panel-off-dark", appearance: .darkAqua)
        f.model.toggleKeepAwake()
        f.clock.seconds += 3661
        f.model.tick()
        try render("panel-on")
        try render("panel-on-dark", appearance: .darkAqua)
        f.model.toggleKeepAwake()
        try render("panel-last-session")
        f.model.toggleKeepAwake()
        f.hotKey.error = "快捷键不可用，可能已被占用（-9878），请使用面板开关。"
        f.model.start()
        f.power.stopFails = true
        f.model.toggleKeepAwake()
        try FileManager.default.removeItem(at: f.scratch.statsURL)
        try FileManager.default.createDirectory(at: f.scratch.statsURL, withIntermediateDirectories: true)
        f.clock.seconds += 61
        f.model.tick()
        #expect(f.model.errors.count == 3)
        try render("panel-errors")
        try render("panel-errors-dark", appearance: .darkAqua)
        f.power.stopFails = false
        f.model.prepareToQuit()

        let long = try Fixture()
        long.model.toggleKeepAwake()
        long.clock.seconds += 35_999_999 // 9999:59:59
        long.model.tick()
        let png = try PanelSnapshot.png(model: long.model)
        try png.write(to: output.appendingPathComponent("panel-long-duration.png"))
        long.model.prepareToQuit()

        for (name, state) in [("on", DisplayState.keepingAwake), ("active", .active), ("idle", .idle)] {
            let image = StatusIcon.image(for: state)
            let tiff = try #require(image.tiffRepresentation)
            let bitmap = try #require(NSBitmapImageRep(data: tiff))
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            try png.write(to: output.appendingPathComponent("icon-\(name).png"))
        }
    }
}

struct PersistenceAndLockTests {
    @Test func oversizedHistoryIsRejectedAndPreserved() throws {
        let scratch = try Scratch()
        let original = try JSONEncoder().encode(StatsSnapshot(cumulativeAwakeSeconds: 1e100, updatedAt: Date()))
        try original.write(to: scratch.statsURL)
        let store = StatsStore(fileURL: scratch.statsURL)
        #expect(store.loadError != nil)
        #expect(store.cumulativeAwakeSeconds == 0)
        #expect(throws: (any Error).self) { try store.commit(delta: 12.5) }
        #expect(store.cumulativeAwakeSeconds == 12.5)
        #expect(try Data(contentsOf: scratch.statsURL) == original)
    }

    @Test func invalidIncrementsAndOverflowPreserveStatistics() throws {
        let scratch = try Scratch()
        let store = StatsStore(fileURL: scratch.statsURL)
        try store.commit(delta: 1.25)
        let original = try Data(contentsOf: scratch.statsURL)
        for delta in [-1.0, .nan, .infinity, 1e100] {
            #expect(throws: (any Error).self) { try store.commit(delta: delta) }
            #expect(store.cumulativeAwakeSeconds == 1.25)
            #expect(try Data(contentsOf: scratch.statsURL) == original)
        }
        let largest = Double(Int64.max).nextDown
        try store.commit(delta: largest - store.cumulativeAwakeSeconds)
        let beforeOverflow = try Data(contentsOf: scratch.statsURL)
        #expect(throws: (any Error).self) { try store.commit(delta: 4096) }
        #expect(store.cumulativeAwakeSeconds == largest)
        #expect(try Data(contentsOf: scratch.statsURL) == beforeOverflow)
    }

    @Test func invalidSnapshotsDoNotOverwriteValidFile() throws {
        let scratch = try Scratch()
        let store = StatsStore(fileURL: scratch.statsURL)
        try store.commit(delta: 42.75)
        let original = try Data(contentsOf: scratch.statsURL)
        for total in [-1.0, .nan, .infinity, 1e100] {
            #expect(throws: (any Error).self) { try store.persistSnapshot(totalIncludingSession: total) }
            #expect(try Data(contentsOf: scratch.statsURL) == original)
            #expect(store.cumulativeAwakeSeconds == 42.75)
        }
    }

    @Test func snapshotSurvivesRestartWithoutRestoringSwitch() throws {
        let scratch = try Scratch()
        let store = StatsStore(fileURL: scratch.statsURL)
        try store.commit(delta: 20)
        try store.persistSnapshot(totalIncludingSession: 35)
        #expect(store.cumulativeAwakeSeconds == 20)
        #expect(StatsStore(fileURL: scratch.statsURL).cumulativeAwakeSeconds == 35)
        try store.commit(delta: 15)
        #expect(StatsStore(fileURL: scratch.statsURL).cumulativeAwakeSeconds == 35)
    }

    @Test func corruptHistoryIsReportedAndNeverOverwritten() throws {
        let scratch = try Scratch()
        let original = Data("broken history".utf8)
        try original.write(to: scratch.statsURL)
        let store = StatsStore(fileURL: scratch.statsURL)
        #expect(store.loadError != nil)
        #expect(throws: (any Error).self) { try store.commit(delta: 10) }
        #expect(try Data(contentsOf: scratch.statsURL) == original)
        #expect(store.cumulativeAwakeSeconds == 10)
    }

    @Test func negativeHistoryIsRejectedAndPreserved() throws {
        let scratch = try Scratch()
        let original = try JSONEncoder().encode(StatsSnapshot(cumulativeAwakeSeconds: -1, updatedAt: Date()))
        try original.write(to: scratch.statsURL)
        let store = StatsStore(fileURL: scratch.statsURL)
        #expect(store.loadError != nil)
        #expect(throws: (any Error).self) { try store.persistSnapshot(totalIncludingSession: 5) }
        #expect(try Data(contentsOf: scratch.statsURL) == original)
    }

    @Test func secondInstanceIsRejectedAndExitReleasesLock() throws {
        let scratch = try Scratch()
        let path = scratch.directory.appendingPathComponent("instance.lock")
        var first: SingleInstanceLock? = try SingleInstanceLock(fileURL: path)
        #expect(first != nil)
        do {
            _ = try SingleInstanceLock(fileURL: path)
            Issue.record("Second instance unexpectedly acquired the lock")
        } catch SingleInstanceLock.LockError.alreadyRunning {
            // Expected: a process cannot silently create another holder.
        }
        first = nil
        let next = try SingleInstanceLock(fileURL: path)
        withExtendedLifetime(next) { #expect(FileManager.default.fileExists(atPath: path.path)) }
    }

    @Test func lockRefusesSymlink() throws {
        let scratch = try Scratch()
        let path = scratch.directory.appendingPathComponent("instance.lock")
        try FileManager.default.createSymbolicLink(at: path, withDestinationURL: scratch.statsURL)
        #expect(throws: (any Error).self) { _ = try SingleInstanceLock(fileURL: path) }
    }
}

@Test func languageFollowsFirstSystemPreference() {
    #expect(AppLanguage.isChinese(["zh-Hans-CN", "en-US"]))
    #expect(AppLanguage.isChinese(["zh-Hant-TW"]))
    #expect(!AppLanguage.isChinese(["en-US", "zh-Hans"]))
    #expect(!AppLanguage.isChinese(["fr-FR"]))
    #expect(!AppLanguage.isChinese([]))
}

@Test func durationFormattingHandlesUnsafeValuesAndLargeHours() {
    for invalid in [-1.0, Double.nan, .infinity, 1e100, Double(Int64.max)] {
        #expect(!AwakeDuration.isSupported(invalid))
        #expect(AwakeDuration.full(invalid) == "—")
        #expect(AwakeDuration.menuBar(invalid) == "—")
    }
    #expect(AwakeDuration.isSupported(Double(Int64.max).nextDown))
    #expect(AwakeDuration.full(3661.99) == "01:01:01")
    #expect(AwakeDuration.full(0) == "00:00:00")
    #expect(AwakeDuration.full(3_000_000_000 * 3600.0) == "3000000000:00:00")
    #expect(AwakeDuration.menuBar(3_000_000_000 * 3600.0) == "3000000000:00")
    #expect(AwakeDuration.menuBar(3599.99) == "0:59")
    #expect(AwakeDuration.menuBar(3600) == "1:00")
}
