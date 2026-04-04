# Timesaver (Infinite Wake)

An alarm app that physically and psychologically defeats oversleeping. Gemini AI verifies your photos at bedtime and wake-up — vibration won't stop until you complete the mission.

## Features

### Morning — Wake-up Alarm
- Fires alarms every minute starting N minutes before your deadline (5–30 alarms, configurable)
- Tap "Woke up" → sound stops → vibration starts
- Take a photo of your washstand → Gemini AI verifies → vibration continues until you pass

### Night — Bedtime Alarm
- Alarm fires at your set bedtime (indigo flashing screen)
- Tap "Went to bed" → sound stops → vibration starts
- Take a photo from inside your bed → Gemini AI verifies → vibration continues until you pass

### Other
- **Chat-based verification UI**: ChatGPT-style interface for AI photo verification
- **Sleep history**: Records bedtime, wake-up time, and sleep duration
- **Screen brightness control**: Maximizes brightness when alarm fires
- **Backup notifications**: Critical alerts even when the app is in the background

## Usage
1. Open the app
2. **Night**: Set your bedtime → take a photo from your bed when the alarm fires
3. **Morning**: Set your deadline → take a photo of your washstand when the alarm fires
4. Gemini AI approves → vibration stops → done

## Setup
1. Create `Timesaver/Secrets.plist` and set your Gemini API key as `GEMINI_API_KEY`
2. Build on a real device with Xcode (iOS 17.0+)

## Architecture Change Log

### 2026-03-28

#### Removed: iOS Shortcuts-based alarm creation
The original design used iOS Shortcuts (`IW_CreateAlarm` / `IW_DeleteAlarms`) to create 30 alarms in the native Clock app, one per minute. This approach was abandoned because the setup was too complex for users — it required manually importing two Shortcuts and granting permissions. The app now handles alarm/timer scheduling entirely in-app.

**What was removed:**
- `ShortcutManager.swift` — deleted entirely
- `SetupInstructionsView` — shortcut setup guide screen removed from `ContentView.swift`
- All references to `ShortcutManager` in `AlarmScheduler.swift` (`.createAlarms()`, `.deleteAllAlarms()`)
- `import UIKit` from `AlarmScheduler.swift` (was only needed for `UIApplication.shared.open`)
- `project.pbxproj` — 4 references to `ShortcutManager.swift` removed

**What was changed:**
- `AlarmScheduler.scheduleAlarmBatch()` — removed `ShortcutManager.createAlarms()` call, now uses local notifications only
- `AlarmScheduler.cancelAllAlarms()` — removed `ShortcutManager.deleteAllAlarms()` call
- UI text updated accordingly

#### Added: In-app alarm sound + vibration system (`AlarmSoundManager.swift`)
New service that handles alarm audio playback via `AVAudioPlayer` and vibration loop via `UIImpactFeedbackGenerator`. Configures `AVAudioSession` for `.playback` category so alarms sound even in silent mode. Falls back to system sound (ID 1005) if no custom audio file is bundled.

#### Added: Night alarm flow (full state machine)
Added complete night/bedtime alarm flow with dedicated states (`nightArmed` → `nightRinging` → `nightMission` → `nightSuccess`), sharing `AlarmActiveView` and `VerificationChatView` with Morning mode via `VerificationMode` parameter. Night flow uses indigo accent color and "Went to bed" button text. Includes `NightArmedView` and `NightSuccessView` for state-specific screens.

#### Added: Gemini API integration (`GeminiService.swift`)
Communicates with Gemini 2.0 Flash to verify bedtime/wake-up via photo comparison. Supports two modes (`.night` / `.morning`), each with a reference-photo and single-photo prompt variant. Returns JSON: `{"result": true/false, "reason": "..."}`.

API key is loaded from `Secrets.plist` (gitignored).

#### Added: Chat-based verification UI (`VerificationChatView.swift`)
ChatGPT-style interface for the wake-up/bedtime mission. User selects a photo via `PhotosPicker`, optionally adds text, sends to Gemini API. AI response is parsed — if `"result": true`, calls the appropriate completion method (`missionCompleted()` or `nightMissionCompleted()`) to stop vibration and transition to success screen.

#### Added: Tab-based main screen (`ContentView.swift` restructured)
Replaced single `DeadlineSetupView` with `MainTabView` containing three tabs:
- **Night** — bedtime alarm setup
- **Morning** — wake-up alarm setup (deadline + alarm count)
- **History** — sleep/wake records

#### Added: Sleep history (`SleepRecord.swift`, `SleepHistoryManager.swift`, `HistoryView.swift`)
Records bedtime, wake-up time, sleep duration, and time-to-wake. Stored via `SleepHistoryManager` (UserDefaults).

#### Added: API key management (`APIKeyManager.swift`, `SettingsView.swift`, `Secrets.plist`)
- `APIKeyManager` — stores Gemini API key in iOS Keychain
- `SettingsView` — SecureField UI for key input
- `Secrets.plist` — plist file containing `GEMINI_API_KEY`, gitignored

## Stack
- Platform: iOS (iPhone)
- Framework: SwiftUI
- Language: Swift 5
- Min iOS: 17.0
- AI: Gemini 2.0 Flash (photo verification)
