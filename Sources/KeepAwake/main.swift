import AppKit

// Acquire the lock BEFORE loading statistics or registering the hotkey.
let supportDirectory = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    .appendingPathComponent("keep-awake", isDirectory: true)
let instanceLock: SingleInstanceLock?
if CommandLine.arguments.contains("--render-preview") {
    instanceLock = nil
} else {
    do {
        instanceLock = try SingleInstanceLock(
            fileURL: supportDirectory.appendingPathComponent("instance.lock")
        )
    } catch SingleInstanceLock.LockError.alreadyRunning {
        print(localized("keep-awake 已在运行，请使用菜单栏图标操作。", "keep-awake is already running. Use the menu bar icon."))
        exit(0)
    } catch {
        let alert = NSAlert()
        alert.messageText = localized("keep-awake 无法启动", "keep-awake could not start")
        alert.informativeText = localized("无法建立单实例保护，请检查应用数据目录的访问权限。\n\(error.localizedDescription)", "Could not establish single-instance protection. Check access to the app data folder.\n\(error.localizedDescription)")
        alert.runModal()
        exit(1)
    }
}

// keep-awake: menu-bar-only resident app (no Dock icon, no windows).
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
