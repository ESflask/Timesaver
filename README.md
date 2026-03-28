# Timesaver (Infinite Wake)

An alarm app that defeats oversleeping by firing repeated alarms until you physically prove you're awake.

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
- UI text updated: "純正時計アプリに..." → "...からアラーム開始", "(ショートカット経由)" removed, etc.

#### Added: In-app alarm sound + vibration system (`AlarmSoundManager.swift`)
New service that handles alarm audio playback via `AVAudioPlayer` and vibration loop via `UIImpactFeedbackGenerator`. Configures `AVAudioSession` for `.playback` category so alarms sound even in silent mode. Falls back to system sound (ID 1005) if no custom audio file is bundled.

```swift
// AlarmSoundManager.swift — core API
func playAlarm()       // loop audio at 0.7 volume
func stopAlarm()       // stop audio
func startVibration()  // 1s interval heavy impact loop
func stopVibration()   // stop vibration
```

#### Added: "Woke up" button on `AlarmActiveView` (`.ultraThinMaterial` glass style)
Replaced the old "起きた！ミッションに挑戦" button (white bg, red text) with a "Woke up" button using SwiftUI's `.ultraThinMaterial` for a frosted glass look. On tap: alarm sound stops → vibration starts → mission screen.

```swift
// AlarmActiveView.swift
Button {
    soundManager.stopAlarm()
    scheduler.startMission()
} label: {
    Text("Woke up")
        .font(.title2)
        .fontWeight(.bold)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
}
```

#### Added: Gemini API integration (`GeminiService.swift`)
Communicates with Gemini 2.0 Flash to verify bedtime/wake-up via photo comparison. Supports two modes (`.night` / `.morning`), each with a reference-photo and single-photo prompt variant. Returns JSON: `{"result": true/false, "reason": "..."}`.

```swift
// GeminiService.swift — API call
static func sendChat(
    mode: VerificationMode,
    message: String?,
    image: UIImage?,
    referenceImage: UIImage?
) async throws -> String
```

API key is loaded from `Secrets.plist` (gitignored):
```swift
private static var apiKey: String {
    guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
          let dict = NSDictionary(contentsOfFile: path),
          let key = dict["GEMINI_API_KEY"] as? String,
          key != "YOUR_API_KEY_HERE" else {
        fatalError("Secrets.plist に有効な GEMINI_API_KEY を設定してください")
    }
    return key
}
```

#### Added: Chat-based verification UI (`VerificationChatView.swift`)
ChatGPT-style interface for the wake-up/bedtime mission. User selects a photo via `PhotosPicker`, optionally adds text, sends to Gemini API. AI response is parsed — if `"result": true`, calls `scheduler.missionCompleted()` to stop vibration and transition to success screen.

#### Added: Tab-based main screen (`ContentView.swift` restructured)
Replaced single `DeadlineSetupView` with `MainTabView` containing three tabs:
- **Night** — bedtime alarm setup
- **Morning** — wake-up alarm setup (deadline + alarm count)
- **History** — sleep/wake records

#### Added: Sleep history (`SleepRecord.swift`, `SleepHistoryManager.swift`, `HistoryView.swift`)
Records bedtime, wake-up time, sleep duration, and time-to-wake. Stored via `SleepHistoryManager` (UserDefaults). History data is gitignored (`sleep_history.json`).

#### Added: API key management (`APIKeyManager.swift`, `SettingsView.swift`, `Secrets.plist`)
- `APIKeyManager` — stores Gemini API key in iOS Keychain
- `SettingsView` — SecureField UI for key input (later removed from main navigation, `Secrets.plist` is now the primary method)
- `Secrets.plist` — plist file containing `GEMINI_API_KEY`, gitignored

## Usage
1. Download the app
2. Set your deadline time (the time you absolutely cannot be late for)
3. Sleep
4. Alarms fire repeatedly — press "Woke up", then take a photo of your washstand to prove you're up
5. Wake up on time

## Stack
- Platform: iOS (iPhone)
- Framework: SwiftUI
- Language: Swift 5
- Min iOS: 17.0
- AI: Gemini 2.0 Flash (photo verification)
