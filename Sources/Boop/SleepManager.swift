import Foundation
import IOKit.pwr_mgt

/// Prevents macOS from sleeping (and the display from turning off) while Claude Code is active.
/// Supports both auto-detection (triggered by permission requests) and manual override.
class SleepManager {
    static let shared = SleepManager()

    private var assertionID: IOPMAssertionID = 0
    private var isHoldingAssertion = false
    private var inactivityTimer: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.loop.boop.sleep-manager")

    /// How long after the last activity before releasing the assertion (seconds)
    var inactivityTimeout: TimeInterval = 30 * 60  // 30 minutes

    /// Whether auto-detect is enabled
    var autoPreventSleep: Bool = false

    /// Whether the user has manually forced "keep awake"
    private(set) var manualOverride: Bool = false

    /// Whether sleep prevention is currently active
    var isActive: Bool { isHoldingAssertion }

    // MARK: - Auto-detect

    /// Called on every permission request from Claude Code
    func recordActivity() {
        guard autoPreventSleep else { return }
        queue.async { [weak self] in
            self?.acquireIfNeeded()
            self?.resetInactivityTimer()
        }
    }

    // MARK: - Manual override

    func setManualOverride(_ enabled: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            self.manualOverride = enabled
            if enabled {
                self.cancelInactivityTimer()
                self.acquireIfNeeded()
            } else {
                // Only release if auto-detect isn't holding it
                if !self.autoPreventSleep {
                    self.release()
                } else {
                    // Let the inactivity timer handle release
                    self.resetInactivityTimer()
                }
            }
        }
    }

    // MARK: - Power assertion management

    private func acquireIfNeeded() {
        guard !isHoldingAssertion else { return }

        let reason = "Boop: Claude Code session active" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )

        if result == kIOReturnSuccess {
            isHoldingAssertion = true
            print("[Boop] Sleep prevention activated")
        }
    }

    private func release() {
        guard isHoldingAssertion else { return }
        // Don't release if manual override is on
        guard !manualOverride else { return }

        IOPMAssertionRelease(assertionID)
        isHoldingAssertion = false
        assertionID = 0
        print("[Boop] Sleep prevention released")
    }

    private func resetInactivityTimer() {
        inactivityTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.queue.async {
                self?.release()
            }
        }
        inactivityTimer = work
        queue.asyncAfter(deadline: .now() + inactivityTimeout, execute: work)
    }

    private func cancelInactivityTimer() {
        inactivityTimer?.cancel()
        inactivityTimer = nil
    }

    /// Force release everything (called on app quit)
    func releaseAll() {
        queue.async { [weak self] in
            guard let self else { return }
            self.manualOverride = false
            self.cancelInactivityTimer()
            if self.isHoldingAssertion {
                IOPMAssertionRelease(self.assertionID)
                self.isHoldingAssertion = false
                self.assertionID = 0
            }
        }
    }
}
