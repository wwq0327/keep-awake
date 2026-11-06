import AppKit

/// Orange means keeping awake. Green/gray only describe recent user input.
enum DisplayState: Equatable {
    case keepingAwake
    case active
    case idle
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var isKeepingAwake = false
    @Published private(set) var now: TimeInterval
    @Published private(set) var powerError: String?
    @Published private(set) var hotKeyError: String?
    @Published private(set) var statsError: String?

    var onStateChange: ((DisplayState) -> Void)?
    var onError: (() -> Void)?

    private let power: any PowerControlling
    private let stats: StatsStore
    private let hotKey: any HotKeyRegistering
    private let clock: () -> TimeInterval
    private let launchTime: TimeInterval
    private var sessionStart: TimeInterval?
    private var lastSessionSeconds: TimeInterval = 0
    private var lastSnapshotTime: TimeInterval
    private var lastNotifiedState: DisplayState?
    private var timer: Timer?
    private var started = false
    private var preparedToQuit = false

    init(
        power: any PowerControlling = PowerManager(),
        stats: StatsStore = StatsStore(),
        hotKey: any HotKeyRegistering = HotKeyManager(),
        clock: @escaping () -> TimeInterval = AwakeClock.seconds
    ) {
        self.power = power
        self.stats = stats
        self.hotKey = hotKey
        self.clock = clock
        let time = clock()
        now = time
        launchTime = time
        lastSnapshotTime = time
        statsError = stats.loadError
        hotKey.onToggle = { [weak self] in self?.toggleKeepAwake() }
    }

    func start() {
        guard !started else { return }
        started = true
        hotKeyError = hotKey.registerDefaultHotKey()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // Common modes also tick while the user interacts with the popover.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        notifyStateChange()
        if !errors.isEmpty { onError?() }
    }

    func prepareToQuit() {
        guard !preparedToQuit else { return }
        preparedToQuit = true
        timer?.invalidate()
        timer = nil
        hotKey.unregister()
        if isKeepingAwake {
            stopKeepAwake()
            // If releasing failed, process exit still releases its assertions.
            // Save the running session once without double committing it.
            if isKeepingAwake { saveSnapshot() }
        } else if stats.hasUnsavedChanges {
            saveSnapshot()
        }
    }

    func toggleKeepAwake() {
        guard !preparedToQuit else { return }
        if isKeepingAwake { stopKeepAwake() } else { startKeepAwake() }
    }

    /// Recover from a shortcut conflict without restarting the running session.
    func retryHotKey() {
        guard started, !preparedToQuit, hotKeyError != nil else { return }
        hotKeyError = hotKey.registerDefaultHotKey()
    }

    private func startKeepAwake() {
        do {
            try power.startKeepingAwake()
            let time = clock()
            sessionStart = time
            lastSnapshotTime = time
            isKeepingAwake = true
            powerError = nil
            now = time
            notifyStateChange()
        } catch {
            powerError = error.localizedDescription
            onError?()
        }
    }

    private func stopKeepAwake() {
        do {
            try power.stopKeepingAwake()
        } catch {
            // Leave the switch ON if the assertion could not be released.
            powerError = error.localizedDescription
            onError?()
            return
        }
        let time = clock()
        let elapsed = max(0, time - (sessionStart ?? time))
        lastSessionSeconds = elapsed
        sessionStart = nil
        isKeepingAwake = false
        powerError = nil
        now = time
        do {
            try stats.commit(delta: elapsed)
            statsError = nil
        } catch {
            statsError = error.localizedDescription
            onError?()
        }
        lastSnapshotTime = time
        notifyStateChange()
    }

    var errors: [String] { [powerError, hotKeyError, statsError].compactMap { $0 } }
    var hasSession: Bool { sessionStart != nil || lastSessionSeconds > 0 }

    var displayState: DisplayState {
        if isKeepingAwake { return .keepingAwake }
        let anyInput = CGEventType(rawValue: 0xFFFFFFFF)
        let idle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState, eventType: anyInput ?? .null
        )
        return idle < 120 ? .active : .idle
    }

    var uptimeSeconds: TimeInterval { max(0, now - launchTime) }

    var sessionSeconds: TimeInterval {
        if let sessionStart { return max(0, now - sessionStart) }
        return lastSessionSeconds
    }

    var totalAwakeSeconds: TimeInterval {
        stats.cumulativeAwakeSeconds + (sessionStart == nil ? 0 : sessionSeconds)
    }

    /// Internal for deterministic regression tests; production uses the timer.
    func tick() {
        now = clock()
        if displayState != lastNotifiedState { notifyStateChange() }
        // Check elapsed time, not a particular wall-clock second. Failed saves
        // retry after 60 awake seconds, including while the switch is OFF.
        if (isKeepingAwake || stats.hasUnsavedChanges), now - lastSnapshotTime >= 60 {
            saveSnapshot()
        }
    }

    private func saveSnapshot() {
        now = clock()
        lastSnapshotTime = now
        let previousError = statsError
        do {
            try stats.persistSnapshot(totalIncludingSession: totalAwakeSeconds)
            statsError = nil
        } catch {
            statsError = error.localizedDescription
            if statsError != previousError { onError?() }
        }
    }

    private func notifyStateChange() {
        let state = displayState
        lastNotifiedState = state
        onStateChange?(state)
    }
}
