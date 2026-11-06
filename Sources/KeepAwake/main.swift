import AppKit

// Acquire the lock BEFORE loading statistics or registering the hotkey.
let supportDirectory = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    .appendingPathComponent("keep-awake", isDirectory: true)
let instanceLock: SingleInstanceLock
do {
    instanceLock = try SingleInstanceLock(
        fileURL: supportDirectory.appendingPathComponent("instance.lock")
    )
} catch SingleInstanceLock.LockError.alreadyRunning {
    print("keep-awake 已在运行，请使用菜单栏图标操作。")
    exit(0)
} catch {
    let alert = NSAlert()
    alert.messageText = "keep-awake 无法启动"
    alert.informativeText = "无法建立单实例保护，请检查应用数据目录的访问权限。\n\(error.localizedDescription)"
    alert.runModal()
    exit(1)
}

// keep-awake: menu-bar-only resident app (no Dock icon, no windows).
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
