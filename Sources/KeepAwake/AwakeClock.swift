import Foundation
import Darwin

enum AwakeClock {
    /// Monotonic seconds, excluding system sleep and unaffected by date changes.
    static func seconds() -> TimeInterval {
        TimeInterval(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1_000_000_000
    }
}
