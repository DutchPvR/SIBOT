# SIBOT

A personal iPhone app for following the Cedars-Sinai low-fermentation diet for SIBO.

- **Can I eat this?** Search a bundled food list (Safe / Limit / Avoid). For foods not on the list, optionally ask an AI model (clearly labeled as an AI guess).
- **Meal log** with a 14-day chart and an optional 1-5 symptom rating per meal.
- **Fasting timer** that counts up from your last meal (tap "I just ate" to restart it). A goal gap (default 4 hours per the Cedars-Sinai handout, adjustable) turns it green and sends a notification.
- **Home screen widget + Live Activity** that show the count-up and let you restart it.
- **Apple Watch complication** that shows a red **Wait** with the time left, then a green **OK to eat** once the goal gap from Settings is up.
- **Reminders tab** for supplements (ginger pills are set up for you at 10 PM). Pick the time and days for each one, then log Taken or Skipped from the app or straight from the notification. A history list keeps the record.

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
- Allow notifications when asked. Supplement reminders and the end-of-timer alert use them. In the simulator, long-press a notification banner to see the Taken / Skipped buttons.
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

## Automatic builds and TestFlight uploads (GitHub Actions)

Two workflows live in `.github/workflows/`:

- **Build** runs on every push to `main` and on pull requests. It compiles the app and widget for the
  simulator so compile errors show up on GitHub. It needs no secrets.
- **TestFlight** archives the app and uploads it to TestFlight. Run it from the repo's **Actions** tab
  (TestFlight > Run workflow) or push a tag such as `v1.0.0`. Each run uses the run number as the build number.

One-time setup for TestFlight:

1. In App Store Connect, go to **Users and Access > Integrations > App Store Connect API** and create a key
   with the **App Manager** role. Download the `.p8` file (you can only download it once) and note the
   **Key ID** and **Issuer ID**.
2. Create the app record in App Store Connect with bundle ID `com.dutchpvr.sibot`.
3. In the repo go to **Settings > Secrets and variables > Actions** and add these secrets:

| Secret | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Your 10-character Team ID (developer.apple.com > Membership) |
| `ASC_KEY_ID` | The API key's Key ID |
| `ASC_ISSUER_ID` | The Issuer ID |
| `ASC_KEY_BASE64` | The `.p8` file encoded as base64, e.g. `base64 -i AuthKey_XXXX.p8 \| pbcopy` on a Mac |

4. Run the TestFlight workflow. After Apple finishes processing (a few minutes), the build appears in the
   app's TestFlight tab.

If signing fails on the App Group, register `group.com.dutchpvr.sibot` once at
developer.apple.com > Certificates, Identifiers & Profiles > Identifiers > App Groups, then re-run.

## Apple Watch

The watch app is embedded in the iPhone app, so it installs with it (from Xcode or TestFlight). The iPhone
sends the time of your last meal and the goal gap to the watch whenever either changes, and the watch keeps
its own copy, so the complication keeps counting even when the phone is away.

1. In Xcode, give the `SIBOTWatch` and `SIBOTWatchWidget` targets the same Team under
   **Signing & Capabilities**, and confirm the App Group `group.com.dutchpvr.sibot` is on both.
2. Run the **SIBOT** scheme on your iPhone. The watch app installs on the paired watch (check the Watch app
   on the iPhone > My Watch > Available Apps if it does not).
3. Open SIBOT on the watch once, then on the watch face: touch and hold > **Edit** > **Complications**, pick a
   slot and choose **SIBOT > Safe to eat**. It also works as a Smart Stack widget.

Tapping the complication opens SIBOT on the watch (watchOS always opens the watch app, not the iPhone app).
In the simulator, run the `SIBOTWatch` scheme on a paired iPhone + Apple Watch simulator pair.

## iCloud sync

Meals, bloating, bowel movements, reminders and their answers, and food trials sync to your private iCloud database, so they follow you to a new phone and survive a reinstall. Settings (timer gap, appearance, your own food list, the AI key) stay on the phone; use Back up for those.

One-time setup:

1. At developer.apple.com > Certificates, Identifiers & Profiles > Identifiers, add the iCloud container `iCloud.com.dutchpvr.sibot` (if Xcode has not already). Then open the App ID `com.dutchpvr.sibot` and turn on iCloud (CloudKit, with that container selected) and Push Notifications.
2. Run `xcodegen` again and check Signing & Capabilities in Xcode for the SIBOT target: iCloud with CloudKit and the container ticked, Push Notifications, and Background Modes > Remote notifications.
3. Run the app once from Xcode on your iPhone (a Debug build) while signed in to iCloud. That creates the record types in CloudKit's Development environment.
4. In CloudKit Console (icloud.developer.apple.com), open the container and choose Deploy Schema Changes to Production. TestFlight and App Store builds use Production, so they will not sync until this is done. Repeat it whenever a model gains a new field.

Settings > Data shows whether sync is on. When adding a field to a model later, give it a default value or make it optional; CloudKit requires it.

## AI fallback (optional)

In **Settings**, paste an [OpenRouter](https://openrouter.ai) API key and, if you like, change the model name
(default `anthropic/claude-haiku-5.5`; any model from openrouter.ai/models works). The key is stored in the
iPhone Keychain and sent only to openrouter.ai. Without a key, the app still works with the bundled list.

## Project layout

- `project.yml` XcodeGen definition (app, widget extension, watch app, watch complication)
- `Shared/` timer state, controller and App Intents, compiled into both targets
- `SIBOT/` the app (SwiftUI, SwiftData, Swift Charts)
- `SIBOTWidget/` home screen widget and Live Activity
- `SIBOTWatch/` Apple Watch app; `SIBOTWatchWidget/` the watch face complication
- `WatchShared/` what the iPhone sends the watch, and the Wait / OK to eat logic
