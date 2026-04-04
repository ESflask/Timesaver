# Timesaver (Infinite Wake)

二度寝を物理的かつ心理的に完封する目覚ましアプリ。就寝時・起床時にGemini AIが写真を判定し、ミッション完了まで振動が止まらない。

## Features

### Morning — 起床アラーム
- デッドライン時刻のN分前から1分おきにアラーム波状攻撃（回数: 5〜30回選択可能）
- "Woke up" タップ → 音停止 → 振動に切り替え
- 洗面台の写真をGemini AIが判定 → 合格まで振動継続

### Night — 就寝アラーム
- 就寝時刻にアラーム発動（indigo背景で点滅）
- "Went to bed" タップ → 音停止 → 振動に切り替え
- 布団の中の写真をGemini AIが判定 → 合格まで振動継続

### その他
- **チャット形式認証UI**: ChatGPT風のインターフェースでAI判定
- **睡眠履歴**: 就寝・起床・睡眠時間を記録・一覧表示
- **画面輝度最大化**: アラーム発動時に画面を最大輝度に
- **バックアップ通知**: アプリがバックグラウンドでもcriticalAlert通知

## Usage
1. アプリを開く
2. **Night**: 就寝時刻を設定 → 時刻になったら布団の写真を撮る
3. **Morning**: デッドライン時刻を設定 → アラームが鳴ったら洗面台の写真を撮る
4. Gemini AIが判定OK → 振動停止 → 完了

## Setup
1. `Timesaver/Secrets.plist` を作成し、`GEMINI_API_KEY` にGemini APIキーを設定
2. Xcodeで実機ビルド（iOS 17.0+）

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
