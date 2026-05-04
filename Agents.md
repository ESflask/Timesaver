# Agents.md

このmarkdownファイルは、AIエージェントが一貫した編集を可能にするために作成されました。

## プロジェクト概要
- **アプリ名**: Infinite Wake（インフィニット・ウェイク）
- **プラットフォーム**: iOS (iPhone) + Web dashboard
- **フレームワーク**: SwiftUI / Flask
- **最低対応OS**: iOS 17.0
- **言語**: Swift 5
- **Bundle ID**: com.endo.timesaver

## コンセプト
「二度寝を物理的かつ心理的に完封する」目覚ましアプリ。
設定時刻から「起きた」ボタンを押すまで1分おきにアラームが**際限なく**鳴り続け、
1階の洗面台まで移動して自分の写真を撮り、Gemini AIが洗面台にいると判定しない限り振動が止まらない。
就寝時にも布団に入った写真をGemini AIが判定し、睡眠習慣の定着をサポートする。

## 使用フロー

### Morning（起床）
1. **就寝前**: アラーム開始時刻を入力
2. **就寝**: iPhoneを充電器に繋ぎ、アプリを起動したまま枕元に置く（セット直後に無音ループが開始されるため、すぐにスリープ可能）
3. **アラーム発動**: `silence.wav` の手動ループ完了コールバックが設定時刻到達を検知 → 無音ループから有音アラームに切替、1分おきに鳴り続ける
4. **ロック画面から復帰**: Now Playingエリアの「ここをタップしてアプリを開く」をタップしてアプリに移動
5. **「起きた」タップ**: アラーム音が止まり、iPhoneの**振動**に切り替わる
6. **起床ミッション**: 洗面台で自撮り写真を送信
7. **Gemini判定OK**: 振動停止 → 起床成功画面

### Night（就寝）
1. **就寝時刻を設定**: Nightタブで時刻を入力
2. **セット後スリープ**: セット直後に無音ループが開始されるため、iPhoneをスリープ状態にして過ごせる
3. **アラーム発動**: `silence.wav` の手動ループ完了コールバックが設定時刻到達を検知 → アラーム音+画面点滅
4. **ロック画面から復帰**: Now Playingエリアのアイコンをタップしてアプリに移動
5. **「布団に入った」タップ**: 音が止まり、振動に切り替わる
6. **就寝ミッション**: 布団の中の自撮り写真を送信
7. **判定OK**: 振動停止 → 就寝成功画面

## プロジェクト構成
```
Timesaver_SW/
├── Timesaver/                          # iOS / Xcode プロジェクト
│   ├── Timesaver.xcodeproj/
│   ├── Timesaver/
│   │   ├── TimesaverApp.swift          # アプリエントリポイント
│   │   ├── Secrets.plist               # APIキー格納（git管理外）
│   │   ├── Models/
│   │   │   ├── WakeSession.swift       # 起床セッションデータ
│   │   │   ├── SleepRecord.swift       # 睡眠記録データ
│   │   │   ├── WeeklyAlarmSettings.swift
│   │   │   ├── Mission.swift
│   │   │   └── AppTheme.swift          # カラーテーマ定義
│   │   ├── Views/
│   │   │   ├── ContentView.swift       # メイン画面（タブ切替）
│   │   │   ├── AlarmActiveView.swift
│   │   │   ├── VerificationChatView.swift
│   │   │   ├── HistoryView.swift
│   │   │   ├── SettingsView.swift      # 設定 + カラーテーマ
│   │   │   ├── ShakeMissionView.swift
│   │   │   └── WakeUpSuccessView.swift
│   │   ├── Services/
│   │   │   ├── AlarmScheduler.swift
│   │   │   ├── AlarmSoundManager.swift
│   │   │   ├── GeminiService.swift
│   │   │   ├── SleepHistoryManager.swift
│   │   │   ├── FirestoreService.swift
│   │   │   ├── AlarmSettingsStore.swift
│   │   │   └── AppThemeStore.swift
│   │   └── Assets.xcassets/
│   │       └── AppIcon.appiconset/AppIcon.png
│   ├── Agents.md
│   ├── Memo.md
│   └── README.md
├── web/                                # Flask版ダッシュボード
│   ├── app.py
│   ├── static/
│   │   └── Infinite-Wake-logo.svg
│   └── templates/                      # Dashboard / History / Settings / Theme
└── shared_photos/                      # シミュレータ用写真共有（git管理外）
```

## アーキテクチャ・主要機能
- **バックグラウンド維持**: `silence.wav` 無音ループ再生（`AVAudioSession.playback`カテゴリ）によるサスペンド防止。アラームセット直後に開始されるため、ユーザーはセット後すぐにiPhoneをスリープ状態にして就寝可能。
- **自動アラーム発動**: 無音ループ再生の進行を使って設定時刻到達を検知し、無音ループから有音アラーム（`alarm_sound.wav`）に自動切替。ユーザー操作不要。
- **ロック画面連携**: `MPNowPlayingInfoCenter` を利用し、アラーム発動時にNow Playingエリアに「ここをタップしてアプリを開く」と表示。ユーザーはロック画面からこのアイコンをタップしてアプリに復帰する。
- **強制振動**: 認証成功まで停止不可能な振動ループ（AudioServices系のシステム振動）。
- **Gemini AI 判定**: 顔照合と場所の固定ポイントによる厳格な認証（服装・寝具の変化は許容）。
- **データ同期**: Firebase Firestore を使用した睡眠記録とアラーム設定の保存。Web版設定保存時も iOS 共有キーを消さないように注意する。
- **カラーテーマ**: iOS / Web ともに「紫(デフォルト)」「白」「黒」「Tokyo Night」を選択可能。iOSは `AppThemeStore` が `UserDefaults` に保存し、Webは `localStorage` で保持。
- **iOS設定画面**: `SettingsView` は `ScrollView` + `LazyVStack(pinnedViews:)` 構成。上部に表示設定、その下に固定ヘッダー付きの「時間設定」セクションを配置。
- **Web版履歴**: `alarmFiredTime` → `missionCompletedTime` の所要時間を Weekly / Monthly グラフで可視化。
- **Web版UI**: 左サイドバーにSVGロゴ、Dashboard / History / Settings / 時間設定の導線を配置。
- **アプリアイコン**: `AppIcon.appiconset/AppIcon.png` にSVGロゴ由来の1024px PNGを登録。

## 開発ルール
- UIは日本語で統一
- SwiftUI を使用
- コードのコメントは日本語で記述

## セキュリティ・個人情報保護ルール（最重要）
- **機密情報の除外**: APIキー、サービス設定ファイル（GoogleService-Info.plist等）、個人を特定できる写真は**絶対に GitHub にプッシュしない**。
- **.gitignore の徹底**: `Secrets.plist`, `GoogleService-Info.plist`, `reference_*.imageset/` 内の画像ファイルが除外されていることを常に確認する。
- **Web機密情報**: `web/.env` と Firebase Admin SDK のJSONは絶対に公開しない。
- **多重対策**: ステージング前の `git status` 確認、および万が一の流出時の履歴抹消手順（`git-filter-repo`）を把握しておく。

## 各認証フロー

### 起床認証フロー（Morning）
```
「起きた」タップ → 音停止 → 振動開始 → VerificationChatView
  ├─ ＋ボタン → 自撮り写真（顔＋洗面台）を選択・撮影
  ├─ 送信 → Gemini API (顔照合＋場所特定)
  ├─ true → 振動停止 → 成功画面
  └─ false → 振動継続、再撮影
```

### 就寝認証フロー（Night）
```
「布団に入った」タップ → 音停止 → 振動開始 → VerificationChatView
  ├─ ＋ボタン → 自撮り写真（顔＋布団の中）を選択・撮影
  ├─ 送信 → Gemini API (顔照合＋場所特定)
  ├─ true → 振動停止 → 成功画面
  └─ false → 振動継続、再撮影
```
