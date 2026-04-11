# Agents.md

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
設定時刻から「起きた」ボタンを押すまで1分おきにアラームが**際限なく**鳴り続け、
1階の洗面台まで移動して自分の写真を撮り、Gemini AIが洗面台にいると判定しない限り振動が止まらない。
就寝時にも布団に入った写真をGemini AIが判定し、睡眠習慣の定着をサポートする。

## 使用フロー

### Morning（起床）
1. **就寝前**: アラーム開始時刻を入力
2. **就寝**: iPhoneを充電器に繋ぎ、アプリを起動したまま枕元に置く
3. **アラーム発動**: 設定時刻から1分おきにアラーム音が鳴る
4. **「起きた」タップ**: アラーム音が止まり、iPhoneの**振動**に切り替わる
5. **起床ミッション**: 洗面台で自撮り写真を送信
6. **Gemini判定OK**: 振動停止 → 起床成功画面

### Night（就寝）
1. **就寝時刻を設定**: Nightタブで時刻を入力
2. **アラーム発動**: 設定時刻になるとアラーム音+画面点滅
3. **「布団に入った」タップ**: 音が止まり、振動に切り替わる
4. **就寝ミッション**: 布団の中の自撮り写真を送信
5. **判定OK**: 振動停止 → 就寝成功画面

## プロジェクト構成
```
Timesaver/
├── Timesaver.xcodeproj/
├── Timesaver/
│   ├── TimesaverApp.swift              # アプリエントリポイント
│   ├── Secrets.plist                   # APIキー格納（git管理外）
│   ├── Models/
│   │   ├── WakeSession.swift           # 起床セッションデータ
│   │   └── SleepRecord.swift           # 睡眠記録データ
│   ├── Views/
│   │   ├── ContentView.swift           # メイン画面（タブ切替）
│   │   ├── AlarmActiveView.swift       # アラーム発動中画面
│   │   ├── VerificationChatView.swift  # Gemini AIチャット認証画面
│   │   ├── HistoryView.swift           # 履歴画面
│   │   └── SettingsView.swift          # 設定画面
│   ├── Services/
│   │   ├── AlarmScheduler.swift        # アラームスケジュール管理
│   │   ├── AlarmSoundManager.swift     # アラーム音・振動管理
│   │   ├── GeminiService.swift         # Gemini API通信・プロンプト
│   │   ├── SleepHistoryManager.swift   # 睡眠記録管理
│   │   └── FirestoreService.swift      # Firestore読み書き
│   └── Assets.xcassets/                # アセット（参照写真スロット含む）
└── Agents.md
```

## アーキテクチャ・主要機能
- **バックグラウンド維持**: `silence.wav` 無音ループ再生によるサスペンド防止。
- **ロック画面連携**: Now Playing センターを利用したアプリ復帰ガイダンス。
- **強制振動**: 認証成功まで停止不可能な振動ループ（UIImpactFeedbackGenerator）。
- **Gemini AI 判定**: 顔照合と場所の固定ポイントによる厳格な認証（服装・寝具の変化は許容）。
- **データ同期**: Firebase Firestore を使用した睡眠記録の保存。

## 開発ルール
- UIは日本語で統一
- SwiftUI を使用
- コードのコメントは日本語で記述

## セキュリティ・個人情報保護ルール（最重要）
- **機密情報の除外**: APIキー、サービス設定ファイル（GoogleService-Info.plist等）、個人を特定できる写真は**絶対に GitHub にプッシュしない**。
- **.gitignore の徹底**: `Secrets.plist`, `GoogleService-Info.plist`, `reference_*.imageset/` 内の画像ファイルが除外されていることを常に確認する。
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
