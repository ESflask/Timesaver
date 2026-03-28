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

## 使用フロー
1. **就寝前**: デッドライン時刻（絶対に遅刻できない時刻）を入力
2. **就寝**: iPhoneを充電器に繋ぎ、アプリを起動したまま枕元に置く
3. **セット時**: アプリ内でアラームをスケジュール
4. **設定した時間になったら〜**: アプリ内アラームが適度な音量で鳴る
5. **"Woke up" タップ**: 音が止まり、iPhoneの振動に切り替わる
6. **覚醒ミッション**: カメラで1階の洗面台を撮影 → Gemini APIが判定
7. **判定OK**: 振動停止 → 起床成功画面（「おはよう」）
8. **判定NG**: 振動継続、再撮影を促す

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
- **アプリ内アラーム**: AVAudioPlayer等でアプリ内から音を鳴らす
- **UNUserNotificationCenter** はバックアップ通知（アプリが閉じられた場合の保険）
- **Gemini API**: 撮影写真とリファレンス写真を比較して就寝/起床を判定
- **Secrets.plist**: APIキーの格納（git管理外）
- **Keychain**: APIキーの安全な保存（設定画面から入力時）
- **永続化**: UserDefaults

## 開発ルール
- UIは日本語で統一
- SwiftUI を使用（UIKit は使わない）
- コードのコメントは日本語で記述

## 未実装項目

### 写真が必要（後回し）
- [ ] リファレンス写真（布団に入った状態）をAssets.xcassetsに "reference_bedtime" として追加
- [ ] 実機での判定精度の検証・プロンプト調整
- [ ] 朝の起床認証（Morning用Gemini判定）

### 実装済み
- [x] アプリ内でアラーム音を鳴らす仕組み（AlarmSoundManager）
- [x] AlarmActiveView に "Woke up" ボタン（`.ultraThinMaterial` ガラス質感）
- [x] "Woke up" タップ後、音を停止しiPhoneの振動に切り替え
- [x] 振動ループ管理（AlarmSoundManager: startVibration/stopVibration）
- [x] 就寝アラーム（Nightタブ）
- [x] 履歴画面（HistoryView）— ナビバー右端に配置
- [x] 設定画面 + APIキーKeychain管理
- [x] Gemini API通信（GeminiService）— 画像送信 + プロンプト + 判定結果パース
- [x] チャット形式認証UI（VerificationChatView）— ChatGPT風、liquid glass質感
- [x] PhotosPickerで写真選択 → Gemini APIに送信 → 就寝判定
- [x] Secrets.plist でAPIキー管理（git管理外）

## チャット認証フロー
```
MissionView → VerificationChatView
  ├─ ＋ボタン → PhotosPicker → 写真選択
  ├─ テキスト入力（任意）
  ├─ 送信 → GeminiService.sendChat()
  │   ├─ 参照写真あり: bedtimeVerificationPrompt（2枚比較）
  │   └─ 参照写真なし: bedtimeVerificationPromptSingle（1枚判定）
  ├─ レスポンス {"result": true/false, "reason": "..."}
  │   ├─ true → scheduler.missionCompleted() → 振動停止 → 成功画面
  │   └─ false → 再送を促す
  └─ エラー時 → エラーメッセージ表示、再送可能
```