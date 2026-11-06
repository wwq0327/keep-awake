import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let model = AppState()
    private let popover = NSPopover()
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app: no Dock icon, no main window.
        NSApp.setActivationPolicy(.accessory)

        popover.behavior = .transient
        popover.animates = true
        // Lock the popover size BEFORE showing: a size change after `show()`
        // makes AppKit re-derive the anchor and the popover drifts away from
        // the icon. `sizingOptions = []` freezes the hosting controller so
        // SwiftUI cannot trigger such a resize.
        popover.contentSize = PanelView.size
        let hosting = NSHostingController(rootView: PanelView(model: model))
        hosting.sizingOptions = []
        popover.contentViewController = hosting

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp])
        }

        model.onStateChange = { [weak self] state in
            self?.renderIcon(state)
        }
        model.$now
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshTitle() }
            .store(in: &cancellables)

        // UI test hook: renders the panel to a PNG (no screen-recording
        // permission needed) and exits, so layout can be verified visually.
        if let idx = CommandLine.arguments.firstIndex(of: "--render-preview") {
            let path = idx + 1 < CommandLine.arguments.count
                ? CommandLine.arguments[idx + 1]
                : "/tmp/keep-awake-preview.png"
            do {
                try renderPreview(path: path)
                exit(0)
            } catch {
                print("DEBUG renderPreview error: \(error)")
                exit(1)
            }
        }

        model.onError = { [weak self] in self?.showPopover() }
        model.start()

        // Login launch and enabling keep-awake are separate choices. Never
        // restore the switch from the previous process's statistics.
        if CommandLine.arguments.contains("--keep-awake-on"), !model.isKeepingAwake {
            model.toggleKeepAwake()
        }

        // UI test hook: opens the popover after launch and prints the anchor
        // geometry so the position can be verified without a screenshot.
        if CommandLine.arguments.contains("--demo-popover") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.showPopover()
                    self.printPopoverGeometry()
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.prepareToQuit()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model.prepareToQuit()
        if let error = model.statsError {
            let alert = NSAlert()
            alert.messageText = "统计尚未保存"
            alert.informativeText = error
            alert.addButton(withTitle: "退出")
            alert.runModal()
        }
        return .terminateNow
    }

    // MARK: Icon & title

    private func renderIcon(_ state: DisplayState) {
        statusItem.button?.image = StatusIcon.image(for: state)
        statusItem.button?.toolTip = state == .keepingAwake
            ? "防止闲置休眠已开启；允许锁屏和熄屏"
            : "防休眠已关闭；跟随系统设置"
        statusItem.button?.setAccessibilityLabel(state == .keepingAwake
            ? "Keep Awake，保持唤醒中" : "Keep Awake，防休眠已关闭")
        refreshTitle()
    }

    /// While keeping awake, show the session duration next to the bolt
    /// (`12:34` = hours:minutes) so long runs are visible at a glance.
    private func refreshTitle() {
        guard let button = statusItem.button else { return }
        if model.isKeepingAwake {
            let seconds = Int(model.sessionSeconds)
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            button.title = " \(hours):\(String(format: "%02d", minutes))"
        } else if button.title.isEmpty == false {
            button.title = ""
        }
    }

    // MARK: Popover

    @objc private func statusItemClicked() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard !popover.isShown, let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    /// Debug helper used by `--render-preview`: renders PanelView to a PNG.
    private func renderPreview(path: String) throws {
        let png = try PanelSnapshot.png(model: model)
        try png.write(to: URL(fileURLWithPath: path))
        print("DEBUG renderPreview wrote \(path)")
        fflush(stdout)
    }

    /// Debug helper used by `--demo-popover`: prints the icon's screen rect
    /// and the popover window's screen rect. Expected: popover.maxY ≈
    /// button.minY (popover hangs right under the icon) and button.midX lies
    /// within the popover's x-range (arrow under the icon).
    private func printPopoverGeometry() {
        guard let button = statusItem.button else { return }
        if let buttonWindow = button.window {
            let screenRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            print("DEBUG button.screenRect = \(screenRect)")
        }
        if let popoverWindow = popover.contentViewController?.view.window {
            print("DEBUG popover.frame     = \(popoverWindow.frame)")
        }
        print("DEBUG screen.frame      = \(NSScreen.main?.frame ?? .zero)")
        fflush(stdout) // the demo run is killed with SIGTERM; flush now or lose it
    }
}
