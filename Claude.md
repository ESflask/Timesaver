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
覚醒ミッション（シェイク）をクリアしない限りアラームが止まらない。

## 使用フロー
1. **就寝前**: デッドライン時刻（絶対に遅刻できない時刻）を入力
2. **就寝**: iPhoneを充電器に繋ぎ、アプリを起動したまま枕元に置く
3. **セット時**: ショートカット(IW_CreateAlarm)経由で純正時計アプリに30回分(1分おき)のアラームを作成
4. **設定した時間になったら〜**: 純正時計アプリのアラームが1分おきに鳴る
5. **アラーム停止しても**: 「起きたボタン」を押さない限り、次のアラームが1分後に鳴る
6. **覚醒ミッション**: スマホを激しく振る → 脳の覚醒を証明
7. **ミッション完遂**: ショートカット(IW_DeleteAlarms)で残りアラーム全削除、画面明るさ復元、「おはよう」

## 事前準備（ショートカット2つを登録）
- **IW_CreateAlarm**: 時刻テキストを受け取り、純正時計アプリにラベル"InfiniteWake"のアラームを作成
- **IW_DeleteAlarms**: ラベル"InfiniteWake"のアラームを検索してオフにする

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
- **URLスキーム** (`shortcuts://run-shortcut`) でiOSショートカット呼び出し → 純正時計アプリにアラーム作成/削除
- **UNUserNotificationCenter** はバックアップ通知（アプリが閉じられた場合の保険）
- **CoreMotion** でシェイク検出
- **永続化**: UserDefaults

## 開発ルール
- UIは日本語で統一
- SwiftUI を使用（UIKit は使わない）
- コードのコメントは日本語で記述
