import Foundation
import IOKit.pwr_mgt

protocol PowerControlling: AnyObject {
    func startKeepingAwake() throws
    func stopKeepingAwake() throws
}

struct PowerError: LocalizedError {
    let action: String
    let code: IOReturn

    var errorDescription: String? {
        "\(action)失败（\(String(format: "0x%08x", code))），请重试。"
    }
}

/// Wraps a single IOPMAssertion that prevents idle system sleep while still
/// allowing the display to sleep and the screen to be locked.
///
/// Uses `kIOPMAssertionTypePreventUserIdleSystemSleep` (not
/// `PreventUserIdleDisplaySleep`) exactly because the user wants:
/// "可以锁屏，但不能进入休眠"。
final class PowerManager: PowerControlling {

    private(set) var assertionID: IOPMAssertionID = 0
    private(set) var isKeepingAwake = false

    func startKeepingAwake() throws {
        guard !isKeepingAwake else { return }

        var assertionID: IOPMAssertionID = 0
        let reason = "keep-awake: user wants the Mac to keep running (screen lock allowed)" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        guard result == kIOReturnSuccess else {
            throw PowerError(action: "开启防休眠", code: result)
        }
        self.assertionID = assertionID
        isKeepingAwake = true
    }

    func stopKeepingAwake() throws {
        guard isKeepingAwake else { return }
        let result = IOPMAssertionRelease(assertionID)
        guard result == kIOReturnSuccess else {
            throw PowerError(action: "关闭防休眠", code: result)
        }
        assertionID = 0
        isKeepingAwake = false
    }
}
