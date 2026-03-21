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
デッドライン時刻の30分前から1分おきに30回のアラーム波状攻撃を行い、
覚醒ミッション（計算問題・シェイク）をクリアしない限りアラームが止まらない。

## 使用フロー
1. **就寝前**: デッドライン時刻（絶対に遅刻できない時刻）を入力
2. **就寝**: iPhoneを充電器に繋ぎ、アプリを起動したまま枕元に置く
3. **30分前**: URLスキーム経由でiOSショートカットを呼び出し、システム音量でアラーム発動
4. **アラーム停止しても**: アプリ上の「起きたボタン」が押されない限り、1分後に再アラーム
5. **覚醒ミッション**: 計算問題 or スマホを激しく振る → 脳の覚醒を証明
6. **ミッション完遂**: 全アラーム予約解除、画面明るさ復元、「おはよう」メッセージで勝利確定

## 事前準備
- アプリ専用のiOSショートカットを一度だけ登録

## プロジェクト構成
```
Timesaver/
├── Timesaver.xcodeproj/
├── Timesaver/
│   ├── TimesaverApp.swift              # アプリエントリポイント
│   ├── Models/
│   │   ├── WakeSession.swift           # 起床セッションデータ
│   │   └── Mission.swift               # 覚醒ミッション定義
│   ├── Views/
│   │   ├── ContentView.swift           # メイン画面（デッドライン設定）
│   │   ├── AlarmActiveView.swift       # アラーム発動中画面
│   │   ├── MissionView.swift           # 覚醒ミッション画面
│   │   ├── MathMissionView.swift       # 計算問題ミッション
│   │   ├── ShakeMissionView.swift      # シェイクミッション
│   │   └── WakeUpSuccessView.swift     # 起床成功画面
│   ├── Services/
│   │   ├── AlarmScheduler.swift        # 30回アラームスケジュール管理
│   │   ├── ShortcutManager.swift       # iOSショートカット連携
│   │   └── ScreenBrightnessManager.swift # 画面明るさ管理
│   ├── Assets.xcassets/
│   ├── Preview Content/
│   └── Info.plist
├── .claude/
│   └── settings.local.json
└── Claude.md
```

## アーキテクチャ
- **SwiftUI + ObservableObject** でシンプルな状態管理
- **UNUserNotificationCenter** で1分おきの通知スケジュール（30回）
- **URLスキーム** でiOSショートカット呼び出し（システムアラーム音）
- **CoreMotion** でシェイク検出
- **永続化**: UserDefaults

## 開発ルール
- UIは日本語で統一
- SwiftUI を使用（UIKit は使わない）
- コードのコメントは日本語で記述
