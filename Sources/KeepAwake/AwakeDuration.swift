import Foundation

/// Shared numeric boundary for stored durations and their presentation.
enum AwakeDuration {
    static func isSupported(_ seconds: TimeInterval) -> Bool {
        wholeSeconds(seconds) != nil
    }

    static func full(_ seconds: TimeInterval) -> String {
        guard let total = wholeSeconds(seconds) else { return "—" }
        return String(format: "%02lld:%02lld:%02lld", total / 3600, (total % 3600) / 60, total % 60)
    }

    static func menuBar(_ seconds: TimeInterval) -> String {
        guard let total = wholeSeconds(seconds) else { return "—" }
        return String(format: "%lld:%02lld", total / 3600, (total % 3600) / 60)
    }

    private static func wholeSeconds(_ seconds: TimeInterval) -> Int64? {
        guard seconds.isFinite, seconds >= 0 else { return nil }
        // Unlike Int(seconds), this fails safely for out-of-range doubles,
        // including Double(Int64.max), which rounds up past Int64.max.
        return Int64(exactly: seconds.rounded(.towardZero))
    }
}
