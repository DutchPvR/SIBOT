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
