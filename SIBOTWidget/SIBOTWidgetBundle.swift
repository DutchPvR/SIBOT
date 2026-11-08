import SwiftUI
import WidgetKit

@main
struct SIBOTWidgetBundle: WidgetBundle {
    var body: some Widget {
        MealTimerWidget()
        MealTimerLiveActivity()
    }
}
