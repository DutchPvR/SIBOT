import SwiftUI

@main
struct SIBOTWatchApp: App {
    init() {
        WatchReceiver.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            StatusView()
        }
        // Lets watchOS wake the app in the background to take timer updates from the iPhone.
        .backgroundTask(.watchConnectivity) {
            await WatchReceiver.shared.waitForPendingContent()
        }
    }
}
