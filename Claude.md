# CLAUDE.md

このmarkdownファイルは、AIエージェントが一貫した編集を可能にするために作成されました。

## プロジェクト概要
- **アプリ名**: Infinite Wake（インフィニット・ウェイク）
- **プラットフォーム**: iOS (iPhone)
- **フレームワーク**: SwiftUI
- **最低対応OS**: iOS 17.0
- **言語**: Swift 5
- **Bundle ID**: com.timesaver.app

## コンセプト
「二度寝を物理的かつ心理的に完封する」目覚ましアプリ。
デッドライン時刻の30分前から1分おきにアラーム波状攻撃を行い、
1階の洗面台まで移動して写真を撮らない限りアラーム（振動）が止まらない。
就寝時にも布団に入った写真をGemini AIが判定し、睡眠習慣の定着をサポートする。

## 使用フロー

### Morning（起床）
1. **就寝前**: デッドライン時刻（絶対に遅刻できない時刻）を入力
2. **就寝**: iPhoneを充電器に繋ぎ、アプリを起動したまま枕元に置く
3. **アラーム発動**: デッドライン前から1分おきにアラーム波状攻撃
4. **"Woke up" タップ**: 音が止まり、iPhoneの振動に切り替わる
5. **起床ミッション**: チャットUIで洗面台の写真を送信 → Gemini APIが判定
6. **判定OK**: 振動停止 → 起床成功画面
7. **判定NG**: 振動継続、再撮影を促す

### Night（就寝）
1. **就寝時刻を設定**: Nightタブで時刻を入力
2. **アラーム発動**: 設定時刻になるとアラーム音+画面点滅（indigo）
3. **"Went to bed" タップ**: 音が止まり、振動に切り替わる
4. **就寝ミッション**: チャットUIで布団の中の写真を送信 → Gemini APIが判定
5. **判定OK**: 振動停止 → 就寝成功画面（「おやすみなさい」）
6. **判定NG**: 振動継続、再撮影を促す

## プロジェクト構成
```
Timesaver/
├── Timesaver.xcodeproj/
├── Timesaver/
│   ├── TimesaverApp.swift              # アプリエントリポイント
│   ├── Secrets.plist                   # APIキー格納（git管理外）
│   ├── Models/
│   │   ├── WakeSession.swift           # 起床セッションデータ
│   │   ├── Mission.swift               # 覚醒ミッション定義
│   │   └── SleepRecord.swift           # 睡眠記録データ
│   ├── Views/
│   │   ├── ContentView.swift           # メイン画面（タブ: Night/Morning）
│   │   ├── AlarmActiveView.swift       # アラーム発動中画面 + "Woke up"ボタン
│   │   ├── MissionView.swift           # 覚醒ミッション画面 → VerificationChatViewを表示
│   │   ├── VerificationChatView.swift  # Gemini AIチャット認証画面
│   │   ├── ShakeMissionView.swift      # シェイクミッション（レガシー）
│   │   ├── WakeUpSuccessView.swift     # 起床成功画面
│   │   ├── HistoryView.swift           # 起床・睡眠記録の履歴画面
│   │   └── SettingsView.swift          # 設定画面（APIキー入力）
│   ├── Services/
│   │   ├── AlarmScheduler.swift        # アラームスケジュール管理
│   │   ├── AlarmSoundManager.swift     # アラーム音再生 + 振動ループ管理
│   │   ├── GeminiService.swift         # Gemini API通信 + プロンプト + 判定
│   │   ├── ScreenBrightnessManager.swift # 画面明るさ管理
│   │   ├── SleepHistoryManager.swift   # 睡眠記録の永続化
│   │   └── APIKeyManager.swift         # Gemini APIキーのKeychain管理
│   ├── Assets.xcassets/
│   ├── Preview Content/
│   └── Info.plist
├── .claude/
│   └── settings.local.json
└── CLAUDE.md
```

## アーキテクチャ
- **SwiftUI + ObservableObject** でシンプルな状態管理
- **状態遷移**: `AlarmScheduler.AppState` で全画面遷移を管理（idle → armed/nightArmed → ringing/nightRinging → mission/nightMission → success/nightSuccess）
- **アプリ内アラーム**: AVAudioPlayer + サイレントモード対応（`.playback`カテゴリ）、フォールバックはSystemSound
- **振動ループ**: UIImpactFeedbackGenerator(.heavy) で1秒間隔、ミッション完了まで停止不可
- **画面輝度制御**: アラーム発動時に最大化、復帰後に元に戻す（ScreenBrightnessManager）
- **UNUserNotificationCenter**: バックアップ通知（アプリがバックグラウンドの場合の保険、criticalAlert対応）
- **Gemini API**: Gemini 2.0 Flash で撮影写真とリファレンス写真を比較して就寝/起床を判定
- **Secrets.plist**: APIキーの格納（git管理外）
- **Keychain**: APIキーの安全な保存（設定画面から入力時）
- **永続化**: UserDefaults（セッション状態 + 睡眠履歴）

## 開発ルール
- UIは日本語で統一
- SwiftUI を使用（UIKit は使わない）
- コードのコメントは日本語で記述

## 未実装項目

### 写真が必要（後回し）
- [ ] リファレンス写真（布団に入った状態）をAssets.xcassetsに "reference_bedtime" として追加
- [ ] リファレンス写真（洗面台）をAssets.xcassetsに "reference_washstand" として追加
- [ ] 実機での判定精度の検証・プロンプト調整

### 実装済み
- [x] アプリ内でアラーム音を鳴らす仕組み（AlarmSoundManager）
- [x] AlarmActiveView — Night/Morning共通、モード別テキスト・色切り替え
- [x] Night: "Went to bed" ボタン → 音停止 → 振動 → 就寝ミッション
- [x] Morning: "Woke up" ボタン → 音停止 → 振動 → 起床ミッション
- [x] 振動ループ管理（AlarmSoundManager: startVibration/stopVibration）
- [x] 就寝アラーム完全フロー（nightArmed → nightRinging → nightMission → nightSuccess）
- [x] 起床アラーム完全フロー（armed → ringing → missionActive → success）
- [x] 就寝アラーム — アプリ内タイマー + バックアップ通知（criticalAlert）
- [x] VerificationChatView — Night/Morning両モード対応のチャット認証UI
- [x] NightArmedView / NightSuccessView — 就寝フロー専用画面
- [x] 履歴画面（HistoryView）
- [x] 設定画面 + APIキーKeychain管理
- [x] Gemini API通信（GeminiService）— Night/Morning各プロンプト（参照写真あり/なし）
- [x] PhotosPickerで写真選択 → Gemini APIに送信 → 判定
- [x] Secrets.plist でAPIキー管理（git管理外）
- [x] 画面輝度最大化（ScreenBrightnessManager）

## チャット認証フロー
```
ContentView → VerificationChatView(mode: .night/.morning)
  ├─ ＋ボタン → PhotosPicker → 写真選択
  ├─ テキスト入力（任意）
  ├─ 送信 → GeminiService.sendChat(mode:message:image:referenceImage:)
  │   ├─ Night + 参照写真あり: nightPromptWithReference（2枚比較）
  │   ├─ Night + 参照写真なし: nightPromptSingle（1枚判定）
  │   ├─ Morning + 参照写真あり: morningPromptWithReference（2枚比較）
  │   └─ Morning + 参照写真なし: morningPromptSingle（1枚判定）
  ├─ レスポンス {"result": true/false, "reason": "..."}
  │   ├─ Night + true → scheduler.nightMissionCompleted() → 振動停止 → 就寝成功画面
  │   ├─ Morning + true → scheduler.missionCompleted() → 振動停止 → 起床成功画面
  │   └─ false → 再送を促す
  └─ エラー時 → エラーメッセージ表示、再送可能
```