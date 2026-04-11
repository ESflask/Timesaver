# Timesaver (Infinite Wake) *

# English Version

An alarm app that physically and psychologically defeats oversleeping. Alarms fire every minute **with no limit** until you press "Woke up", then vibration continues until Gemini AI confirms you're standing at your washstand.

## Caution
Since the app works by playing silent audio files while you sleep, it's highly unlikely to pass the App Store review process, but you can still easily transfer it from your Mac to your iPhone.

## Features

### Morning — Wake-up Alarm
- Set your alarm time — **no alarm count setting**; alarms fire every 1 minute indefinitely until you tap "Woke up"
- While sleeping, `silence.wav` plays silently on loop (starts immediately after setting alarm) to keep the app alive in the background — phone can be locked right away
- When alarm time arrives, the in-app Timer auto-switches from silence to alarm sound; Now Playing on the lock screen shows "Tap here to open app" so the user can return to the app
- Tap "Woke up" → alarm sound stops → **vibration starts** (cannot be stopped manually)
- Take a photo of yourself at your washstand and send it to Gemini AI
  - Your home washstand reference photo is pre-registered in the app (gitignored)
  - **Unlimited retries** — send as many photos as needed
- Gemini AI returns `{"result": true}` → vibration stops → wake-up success screen
- Gemini AI returns `{"result": false}` → vibration continues, re-take prompted

### Night — Bedtime Alarm
- Alarm fires at your set bedtime (indigo flashing screen)
- Tap "Went to bed" → sound stops → vibration starts
- Take a photo from inside your bed → Gemini AI verifies → vibration continues until you pass

### Other
- **Chat-based verification UI**: ChatGPT-style interface for AI photo verification
- **Sleep history**: Records each action's timestamp (alarm set → alarm fired → button tap → mission complete) with reaction time, mission time, and total time
- **Firebase Firestore sync**: Records are saved to Firestore on mission completion and fetched on app launch (shared with web dashboard). *Note: Firebase Storage is not yet configured, so photo data is not being uploaded.*
- **API key via Secrets.plist**: Gemini API key is bundled at build time (no in-app settings UI)
- **Screen brightness control**: Maximizes brightness when alarm fires
- **Backup notifications**: Critical alerts even when the app is in the background
- **Memo.md**: A file where daily coding challenges, tasks completed, and thoughts are recorded.

## How It Works

```
Set alarm → silence.wav loop starts immediately → sleep (phone can be locked)
  → in-app Timer detects alarm time → auto-switch from silence to alarm sound
  → alarm fires every 1 min (infinite loop)
  → Now Playing shows "Tap here to open app" on lock screen
  → user taps Now Playing → returns to app
  → "Woke up" tap → sound off, vibration on
  → take photo at washstand → send to Gemini API
  → Gemini says "result: true" → vibration stops → done
  → Gemini says "result: false" → vibration continues → retry
```

## Setup
1. Create `Timesaver/Secrets.plist` with your Gemini API key as `GEMINI_API_KEY` (bundled into the app at build time — no in-app key entry)
2. Add your home washstand photo to `Assets.xcassets` as `reference_washstand` and your bedtime photo as `reference_bedtime` (these files are gitignored)
3. Build on a real device with Xcode (iOS 17.0+)

## Architecture Change Log

### 2026-03-28

#### Removed: iOS Shortcuts-based alarm creation
The original design used iOS Shortcuts (`IW_CreateAlarm` / `IW_DeleteAlarms`) to create 30 alarms in the native Clock app. Abandoned — too complex for users. The app now handles scheduling entirely in-app.

#### Added: In-app alarm sound + vibration system (`AlarmSoundManager.swift`)
Handles alarm audio via `AVAudioPlayer`, vibration loop via `UIImpactFeedbackGenerator`, and `silence.wav` background loop to prevent app suspension. Configures `AVAudioSession` for `.playback` category (works in silent mode). Falls back to system sound (ID 1005) if no custom audio file is bundled.

#### Added: Night alarm flow (full state machine)
Complete night/bedtime flow: `nightArmed` → `nightRinging` → `nightMission` → `nightSuccess`. Shares `AlarmActiveView` and `VerificationChatView` with Morning mode via `VerificationMode` parameter.

#### Added: Gemini API integration (`GeminiService.swift`)
Communicates with Gemini 2.0 Flash to verify bedtime/wake-up via photo comparison. Two modes (`.night` / `.morning`), each with reference-photo and single-photo prompt variants. Returns `{"result": true/false, "reason": "..."}`. Unlimited submission retries. When `"result": true`, triggers `missionCompleted()` / `nightMissionCompleted()` which stops vibration.

#### Added: Chat-based verification UI (`VerificationChatView.swift`)
ChatGPT-style interface. User selects photo via `PhotosPicker`, sends to Gemini API. If `"result": true`, vibration stops and transitions to success screen.

#### Added: Tab-based main screen, sleep history, API key management
Three tabs (Night / Morning / History). API key via `Secrets.plist` (gitignored, bundled at build time).

### 2026-04-11

#### Changed: SleepRecord — action timestamp tracking
`SleepRecord` now tracks mode (night/morning) and four timestamps: `alarmSetTime`, `alarmFiredTime`, `actionButtonTime`, `missionCompletedTime`. Computed properties provide `reactionSeconds`, `missionSeconds`, and `totalSeconds`.

#### Added: Firestore integration (`FirestoreService.swift`)
Reads/writes `sleep_records` collection in Firestore. Records are saved on mission completion and fetched on app launch. Web-compatible fields (`bedtime`, `waketime`, `timestamp`) are included for the Flask dashboard.

#### Updated: HistoryView — time tracking display
Shows mode badge (night/morning), alarm fired time, action button time, and computed durations (reaction time, mission time, total time). Pull-to-refresh fetches latest data from Firestore.

#### Added: Settings tab with auto/manual alarm mode (`SettingsView.swift`)
Four tabs (Night / Morning / History / Settings). Settings tab lets users toggle between manual mode (set alarm each time) and auto mode (fixed bedtime + wake time). When auto mode is ON, DatePickers for bedtime and wake-up time appear. In auto mode, completing the bedtime mission automatically schedules the wake-up alarm.

#### Updated: Gemini AI verification logic (`GeminiService.swift`)
The AI verification prompt has been enhanced to prioritize **face matching** (using bone structure/facial features) and **location fixed-points** (washstand fixtures, room layout). It now explicitly ignores changes in clothing (pajamas) and bedding (sheets/pillow covers) to ensure stable verification even when your appearance or bed setup changes.

## Stack
- Platform: iOS (iPhone)
- Framework: SwiftUI
- Language: Swift 5
- Min iOS: 17.0
- AI: Gemini 2.0 Flash (photo verification)
# Japanese version

物理的・心理的に二度寝を粉砕する目覚ましアプリ。「起きた」ボタンを押すまで**無制限**に1分おきにアラームが鳴り続け、ボタンを押した後も洗面所に立っていることをGemini AIが確認するまでバイブレーションが止まりません。

## 注意
睡眠中に無音のオーディオファイルを再生し続けることでアプリをバックグラウンドで維持する仕組みのため、App Storeの審査を通過する可能性は極めて低いですが、MacからiPhoneに直接転送して使用することは可能です。

## 機能

### 朝 — 起床アラーム
- アラーム時刻の設定 — **回数設定はありません**。「起きた」をタップするまで、1分おきに無期限で鳴り続けます。
- アラームセット直後に `silence.wav` の無音ループ再生が開始され、バックグラウンドでのアプリ生存を維持します。セット後すぐにiPhoneをロック（スリープ）して就寝可能。
- 設定時刻になるとアプリ内タイマーが自動検知し、無音ループから有音アラームに切替。ロック画面のNow Playingエリアに「ここをタップしてアプリを開く」と表示され、タップでアプリに復帰。
- 「起きた」をタップ → アラーム音が停止 → **バイブレーション開始**（手動では停止不可）
- 洗面所で自分の写真を撮り、Gemini AIに送信
  - 自宅の洗面所の参照写真はアプリ内に事前登録（gitignored）
  - **リトライ無制限** — 認証されるまで何度でも送信可能
- Gemini AIが `{"result": true}` を返す → バイブレーション停止 → 起床成功画面へ
- Gemini AIが `{"result": false}` を返す → バイブレーション継続、再撮影を促す

### 夜 — 就寝アラーム
- 設定した就寝時刻にアラームが鳴動（藍色の点滅画面）
- 「寝る」をタップ → アラーム音停止 → バイブレーション開始
- 布団の中から写真を撮影 → Gemini AIが検証 → 合格するまでバイブレーションが継続

### その他
- **チャット形式の検証UI**: AIによる写真検証のためのChatGPT風インターフェース
- **睡眠履歴**: 各アクションのタイムスタンプ（アラーム設定 → 鳴動 → ボタンタップ → ミッション完了）を記録。反応時間、ミッション時間、合計時間を算出。
- **Firebase Firestore 同期**: ミッション完了時にFirestoreへ記録を保存し、アプリ起動時に取得（Webダッシュボードと共有）。※Firebase Storageは未設定のため、写真データ自体はアップロードされません。
- **Secrets.plistによるAPIキー管理**: Gemini APIキーはビルド時にバンドル（アプリ内設定UIなし）
- **画面輝度制御**: アラーム鳴動時に輝度を最大化
- **バックアップ通知**: アラーム時にクリティカルアラートを通知

## 仕組み

```
アラーム設定 → 無音ループ即開始 → スリープ可能（iPhoneロックOK）
  → アプリ内タイマーが設定時刻を自動検知 → 無音→有音アラームに切替
  → 1分おきにアラーム鳴動（無限ループ）
  → ロック画面のNow Playing「ここをタップしてアプリを開く」をタップ → アプリに復帰
  → 「起きた」タップ → 音停止、バイブ開始
  → 洗面所で写真撮影 → Gemini APIに送信
  → Gemini が "result: true" と回答 → バイブ停止 → 完了
  → Gemini が "result: false" と回答 → バイブ継続 → リトライ
```

## セットアップ
1. `Timesaver/Secrets.plist` を作成し、Gemini APIキーを `GEMINI_API_KEY` として追加（ビルド時にバンドルされます）
2. `Assets.xcassets` に自宅の洗面所写真を `reference_washstand` として、就寝時の写真を `reference_bedtime` として追加してください（これらのファイルは gitignore されています）
3. Xcodeで実機（iOS 17.0+）にビルド

## アーキテクチャ変更ログ

### 2026-03-28

#### 削除: iOSショートカットベースのアラーム作成
初期設計ではiOSショートカット (`IW_CreateAlarm` / `IW_DeleteAlarms`) を使用して標準時計アプリに30個のアラームを作成していましたが、ユーザーにとって複雑すぎるため廃止しました。現在はアプリ内でスケジューリングを完結させています。

#### 追加: アプリ内アラーム音 + バイブレーションシステム (`AlarmSoundManager.swift`)
`AVAudioPlayer` によるアラーム再生、`UIImpactFeedbackGenerator` によるバイブレーションループ、およびアプリ停止を防ぐための `silence.wav` バックグラウンド再生を実装。マナーモードでも動作するよう `.playback` カテゴリで `AVAudioSession` を構成。カスタム音源がない場合はシステム音（ID 1005）を使用します。

#### 追加: 夜間アラームフロー（フル状態マシン）
就寝・起床のフローを統合管理: `nightArmed` → `nightRinging` → `nightMission` → `nightSuccess`。`VerificationMode` パラメータにより、朝モードと `AlarmActiveView` / `VerificationChatView` を共有。

#### 追加: Gemini API 連携 (`GeminiService.swift`)
Gemini 2.0 Flash を使用して、写真比較による就寝・起床の検証を実装。`.night` / `.morning` の2つのモードを持ち、参照写真あり・なしのプロンプトを使い分けます。`{"result": true/false, "reason": "..."}` を返します。リトライは無制限。検証成功時に `missionCompleted()` 等が呼ばれ、バイブレーションが停止します。

#### 追加: チャット形式の検証UI (`VerificationChatView.swift`)
ChatGPTスタイルのインターフェース。`PhotosPicker` で写真を選択し、Gemini APIに送信します。

#### 追加: タブベースのメイン画面、睡眠履歴、APIキー管理
3つのタブ（Night / Morning / History）を実装。APIキーは `Secrets.plist` で管理。

### 2026-04-11

#### 変更: SleepRecord — アクションタイムスタンプの追跡
`SleepRecord` でモード（夜/朝）と4つのタイムスタンプ（`alarmSetTime`, `alarmFiredTime`, `actionButtonTime`, `missionCompletedTime`）を追跡するように変更。計算プロパティにより反応時間、ミッション時間、合計時間を提供します。

#### 追加: Firestore 連携 (`FirestoreService.swift`)
Firestoreの `sleep_records` コレクションへの読み書きを実装。ミッション完了時に保存し、起動時に取得。Flaskダッシュボード用に `bedtime`, `waketime`, `timestamp` フィールドを含みます。

#### 更新: HistoryView — 時間追跡表示
モードバッジ（夜/朝）、鳴動時刻、ボタン押下時刻、および計算された各所要時間を表示。プルリフレッシュで最新データを取得可能。

#### 追加: 設定タブと自動/手動アラームモード (`SettingsView.swift`)
4つ目の「Settings」タブを追加。手動モード（都度設定）と自動モード（固定時刻）を切り替え可能。自動モードがONの場合、就寝・起床時刻のDatePickerが表示されます。自動モードでは、就寝ミッション完了時に起床アラームが自動的にセットされます。

#### 更新: Gemini AI 検証ロジックの強化 (`GeminiService.swift`)
AI検証プロンプトを刷新。服装（パジャマ）や寝具（シーツ・枕カバー）の変化を無視し、**「ユーザー本人の顔（骨格）」**と**「特定の場所（洗面所の設備や部屋の配置）」**を最優先で照合するように変更しました。これにより、日常生活での些細な変化による認証エラーを最小限に抑えます。

## スタック
- プラットフォーム: iOS (iPhone)
- フレームワーク: SwiftUI
- 言語: Swift 5
- 最小OS: iOS 17.0
- AI: Gemini 2.0 Flash (写真検証)
