import Foundation
import WatchConnectivity
import WidgetKit

/// Takes timer updates from the iPhone, stores them for the complication and refreshes it.
final class WatchReceiver: NSObject, WCSessionDelegate {
    static let shared = WatchReceiver()

    func activate() {
        guard WCSession.isSupported(), WCSession.default.activationState != .activated else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Keeps a background wake alive until WatchConnectivity has handed over everything queued.
    func waitForPendingContent() async {
        activate()
        let session = WCSession.default
        var tries = 0
        while tries < 50, session.activationState != .activated || session.hasContentPending {
            try? await Task.sleep(for: .milliseconds(200))
            tries += 1
        }
    }

    /// The reset button: restart the timer here right away, then tell the iPhone,
    /// which logs the meal and sends the timer back.
    func ateNow() {
        let now = Date()
        store(WatchTimerPayload.make(start: now, gapHours: MealTimerStore.gapHours, sent: now))
        activate()
        let session = WCSession.default
        let message = WatchTimerPayload.ateNowMessage(at: now)
        // Queued delivery always arrives, even if the iPhone is out of reach right now.
        session.transferUserInfo(message)
        // When the iPhone is reachable this gets there at once.
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        }
    }

    private func store(_ payload: [String: Any]) {
        guard WatchTimerPayload.apply(payload) else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        if !context.isEmpty { store(context) }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        store(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        store(userInfo)
    }
}
