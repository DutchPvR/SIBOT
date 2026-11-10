import Foundation
import WatchConnectivity

/// Sends the fasting timer to the Apple Watch, where the complication shows Wait / OK to eat.
final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Call whenever the last meal or the goal gap changes.
    func push() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled else { return }

        let payload = WatchTimerPayload.make(start: MealTimerStore.startDate, gapHours: MealTimerStore.gapHours)
        // The latest context is delivered whenever the watch app next runs.
        try? session.updateApplicationContext(payload)
        // While the complication is on the watch face, this wakes the watch so it updates right away.
        // Apple allows about 50 of these a day.
        if session.isComplicationEnabled, session.remainingComplicationUserInfoTransfers > 0 {
            session.transferCurrentComplicationUserInfo(payload)
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated { push() }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Switching to another watch: activate again so the new one gets updates.
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        // Fires when the watch app is installed or the complication is added.
        push()
    }
}
