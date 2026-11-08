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

## Ask Claude (optional)

In **Settings**, paste an Anthropic API key. It is stored in the iPhone Keychain and sent only to
api.anthropic.com. Without a key, the app still works with the bundled list.

## Project layout

- `project.yml` XcodeGen definition (app + widget extension)
- `Shared/` timer state, controller and App Intents, compiled into both targets
- `SIBOT/` the app (SwiftUI, SwiftData, Swift Charts)
- `SIBOTWidget/` home screen widget and Live Activity
