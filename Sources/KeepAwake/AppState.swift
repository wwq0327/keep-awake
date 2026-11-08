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
    @Published private(set) var displayState: DisplayState = .idle
    @Published private(set) var usesTimer = false
    @Published private(set) var durationMinutes = 120
    @Published var durationDraft: String?

    var onStateChange: ((DisplayState) -> Void)?
    var onError: (() -> Void)?

    private let power: any PowerControlling
    private let stats: StatsStore
    private let hotKey: any HotKeyRegistering
    private let clock: () -> TimeInterval
    private let idleSeconds: () -> TimeInterval
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
        clock: @escaping () -> TimeInterval = AwakeClock.seconds,
        idleSeconds: @escaping () -> TimeInterval = {
            CGEventSource.secondsSinceLastEventType(
                .combinedSessionState, eventType: CGEventType(rawValue: 0xFFFFFFFF) ?? .null
            )
        }
    ) {
        self.power = power
        self.stats = stats
        self.hotKey = hotKey
        self.clock = clock
        self.idleSeconds = idleSeconds
        let time = clock()
        now = time
        launchTime = time
        lastSnapshotTime = time
        statsError = stats.loadError
        displayState = sampledDisplayState()
        hotKey.onToggle = { [weak self] in self?.toggleKeepAwake() }
    }

    func start() {
        guard !started else { return }
        started = true
        hotKeyError = hotKey.registerDefaultHotKey()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // Allow small scheduling adjustments to coalesce wakeups. Elapsed
        // time and the save interval still use the monotonic clock.
        timer.tolerance = 0.1
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
        if isKeepingAwake {
            stopKeepAwake()
        } else if commitDurationEdit() {
            startKeepAwake()
        }
    }

    func selectTimer(_ timed: Bool) {
        guard !isKeepingAwake, !preparedToQuit else { return }
        if !timed { durationDraft = nil }
        usesTimer = timed
    }

    func beginDurationEdit() {
        guard !isKeepingAwake, !preparedToQuit else { return }
        usesTimer = true
        durationDraft = String(format: "%02d:%02d", durationMinutes / 60, durationMinutes % 60)
    }

    @discardableResult
    func commitDurationEdit() -> Bool {
        guard let durationDraft else { return true }
        guard let minutes = AwakeDuration.timerMinutes(durationDraft) else { return false }
        durationMinutes = minutes
        self.durationDraft = nil
        return true
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

    private func stopKeepAwake(reportRepeatedError: Bool = true) {
        do {
            try power.stopKeepingAwake()
        } catch {
            // Leave the switch ON if the assertion could not be released.
            let message = error.localizedDescription
            if reportRepeatedError || powerError != message {
                powerError = message
                onError?()
            }
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

    private func sampledDisplayState() -> DisplayState {
        if isKeepingAwake { return .keepingAwake }
        let idle = idleSeconds()
        return idle >= 0 && idle < 120 ? .active : .idle
    }

    var uptimeSeconds: TimeInterval { max(0, now - launchTime) }

    var sessionSeconds: TimeInterval {
        if let sessionStart { return max(0, now - sessionStart) }
        return lastSessionSeconds
    }

    var countdownSeconds: TimeInterval? {
        guard isKeepingAwake, usesTimer else { return nil }
        return max(0, TimeInterval(durationMinutes * 60) - sessionSeconds)
    }

    var totalAwakeSeconds: TimeInterval {
        stats.cumulativeAwakeSeconds + (sessionStart == nil ? 0 : sessionSeconds)
    }

    /// Internal for deterministic regression tests; production uses the timer.
    func tick() {
        now = clock()
        if countdownSeconds == 0 {
            stopKeepAwake(reportRepeatedError: false)
        } else {
            notifyStateChange()
        }
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
        let state = sampledDisplayState()
        if displayState != state { displayState = state }
        guard state != lastNotifiedState else { return }
        lastNotifiedState = state
        onStateChange?(state)
    }
}
