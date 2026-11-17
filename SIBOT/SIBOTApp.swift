import SwiftData
import SwiftUI
import UserNotifications

@main
struct SIBOTApp: App {
    private let notificationDelegate = NotificationDelegate()

    init() {
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.titleTextAttributes = [.foregroundColor: Theme.purpleUI, .font: UIFont.systemFont(ofSize: 17, weight: .heavy)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UNUserNotificationCenter.current().delegate = notificationDelegate
        NotificationManager.registerCategories()
        WatchSync.shared.activate()
        ReportBuilder.clearExports()
        MealTimerController.didChange = { WatchSync.shared.push() }
        // Bloating logged by a shortcut while the app is running goes straight into the diary.
        PendingLog.onAdd = {
            Task { @MainActor in BloatLog.reconcilePending(in: Persistence.container.mainContext) }
        }
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
        // Skipped when reminders are already here (e.g. restored from iCloud); if iCloud brings an
        // identical one later, SyncCleanup folds the two together.
        if !defaults.bool(forKey: "seededSupplements") {
            if ((try? context.fetchCount(FetchDescriptor<Supplement>())) ?? 0) == 0 {
                context.insert(Supplement(name: "Ginger pills", minutes: 22 * 60))
                try? context.save()
            }
            defaults.set(true, forKey: "seededSupplements")
        }

        BowelMovement.migrateFromDailyChecks(context)
        // Runs once per install, so days that arrive from iCloud before their bloating
        // entries do are not given a second entry.
        if !defaults.bool(forKey: "migratedLegacyBloat") {
            BloatLog.migrateLegacy(in: context)
            defaults.set(true, forKey: "migratedLegacyBloat")
        }
        BloatLog.reconcilePending(in: context)
        SupplementLogger.migrateLegacySlots(context)
        SyncCleanup.run(in: context)

        let supplements = (try? context.fetch(FetchDescriptor<Supplement>())) ?? []
        NotificationManager.rescheduleAll(supplements)
    }
}
