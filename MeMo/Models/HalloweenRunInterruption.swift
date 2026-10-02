import Foundation

/// Runtime only. A repeated inactive notification must not restart or bypass the resume gate.
struct HalloweenRunInterruption {
    private(set) var isSuspended = false
    private(set) var resumeRemaining: TimeInterval = 0
    var canSimulate: Bool { !isSuspended && resumeRemaining <= 0 }

    mutating func setActive(_ active: Bool) {
        if active {
            guard isSuspended else { return }
            isSuspended = false
            resumeRemaining = Halloween2026Configuration.resumeCountdownDuration
        } else {
            isSuspended = true
            resumeRemaining = Halloween2026Configuration.resumeCountdownDuration
        }
    }

    mutating func advanceCountdown(by seconds: TimeInterval) {
        guard !isSuspended, seconds.isFinite else { return }
        resumeRemaining = max(0, resumeRemaining - max(0, seconds))
    }
}
