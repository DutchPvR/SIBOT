# SIBOT

A personal iPhone app for following the Cedars-Sinai low-fermentation diet for SIBO.

- **Can I eat this?** Search a bundled food list (Safe / Limit / Avoid). For foods not on the list, optionally ask Claude (clearly labeled as an AI guess).
- **Meal log** with a 14-day chart and an optional 1-5 symptom rating per meal.
- **Meal timer** (default 5 hours, adjustable) that you start manually, with a notification when it ends.
- **Home screen widget + Live Activity** to start and watch the countdown.
- **Bedtime ginger reminder** at a time you choose in Settings.

SIBOT is a personal tracking tool, not medical advice. The starter food list in
`SIBOT/Resources/foods.json` is based on summaries of the Cedars-Sinai guide. Check it against your own
copy and edit it.

## Run it in the simulator

Requires a Mac with Xcode 15 or later.

```sh
brew install xcodegen
git clone https://github.com/DutchPvR/SIBOT.git
cd SIBOT
xcodegen            # creates SIBOT.xcodeproj from project.yml
open SIBOT.xcodeproj
```

In Xcode choose an iPhone simulator (iOS 17+) and press Run.

Notes for the simulator:
- Allow notifications when asked. The ginger reminder and the end-of-timer alert use them.
- Add the widget by long-pressing the home screen, tapping **+**, and searching "SIBOT".
- For a quick test, set the wait to 1 hour in Settings (the stepper's minimum) and watch the countdown.

## Put it on your iPhone via TestFlight

1. Finish enrolling in the Apple Developer Program.
2. In Xcode, select the **SIBOT** project, then for **both** the `SIBOT` and `SIBOTWidget` targets open
   **Signing & Capabilities**, tick *Automatically manage signing* and choose your Team.
   (Or put your Team ID in `DEVELOPMENT_TEAM` in `project.yml` and re-run `xcodegen`.)
3. Confirm the App Group `group.com.dutchpvr.sibot` appears on both targets. If Xcode cannot register
   it, change the group name in `project.yml` and in `Shared/MealTimerStore.swift`.
4. Create the app at appstoreconnect.apple.com (My Apps > +) with bundle ID `com.dutchpvr.sibot`.
5. In Xcode: set the run destination to **Any iOS Device (arm64)**, then **Product > Archive**, then
   **Distribute App > App Store Connect > Upload**.
6. In App Store Connect open the app's **TestFlight** tab, add yourself as an internal tester, and install
   through the TestFlight app.

## Ask Claude (optional)

In **Settings**, paste an Anthropic API key. It is stored in the iPhone Keychain and sent only to
api.anthropic.com. Without a key, the app still works with the bundled list.

## Project layout

- `project.yml` XcodeGen definition (app + widget extension)
- `Shared/` timer state, controller and App Intents, compiled into both targets
- `SIBOT/` the app (SwiftUI, SwiftData, Swift Charts)
- `SIBOTWidget/` home screen widget and Live Activity
