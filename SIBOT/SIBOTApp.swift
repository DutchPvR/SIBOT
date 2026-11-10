import SwiftData
import SwiftUI
import UserNotifications

@main
struct SIBOTApp: App {
    private let notificationDelegate = NotificationDelegate()

    init() {
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.largeTitleTextAttributes = [.foregroundColor: Theme.purpleUI, .font: UIFont.systemFont(ofSize: 38, weight: .heavy)]
        nav.titleTextAttributes = [.foregroundColor: Theme.purpleUI, .font: UIFont.systemFont(ofSize: 17, weight: .heavy)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UNUserNotificationCenter.current().delegate = notificationDelegate
        NotificationManager.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear { Appearance.saved.apply() }
                .task { await setUpReminders() }
        }
        .modelContainer(Persistence.container)
    }

    @MainActor
    private func setUpReminders() async {
        _ = await NotificationManager.requestAuthorization()
        NotificationManager.cancelLegacyGinger()

        let context = Persistence.container.mainContext
        let defaults = UserDefaults.standard

        // First launch: start with a nightly ginger reminder at 10 PM. Edit or delete it in the Reminders tab.
        if !defaults.bool(forKey: "seededSupplements") {
            context.insert(Supplement(name: "Ginger pills", minutes: 22 * 60))
            try? context.save()
            defaults.set(true, forKey: "seededSupplements")
        }

        BowelMovement.migrateFromDailyChecks(context)
        SupplementLogger.migrateLegacySlots(context)

        let supplements = (try? context.fetch(FetchDescriptor<Supplement>())) ?? []
        NotificationManager.rescheduleAll(supplements)
    }
}
