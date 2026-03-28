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
3. **セット時**: アプリ内でアラームをスケジュール
4. **設定した時間になったら〜**: アプリ内アラームが鳴る
5. **アラーム停止しても**: 「Woke up」を押さない限り、次のアラームが鳴る
6. **覚醒アクション**: 何らかのアクション（未定）を完了するまで振動が続く
7. **完遂**: 全アラーム停止、画面明るさ復元、「おはよう」

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
- **アプリ内アラーム**: AVAudioPlayer等でアプリ内から音を鳴らす
- **UNUserNotificationCenter** はバックアップ通知（アプリが閉じられた場合の保険）
- **CoreMotion** でシェイク検出
- **永続化**: UserDefaults

## 開発ルール
- UIは日本語で統一
- SwiftUI を使用（UIKit は使わない）
- コードのコメントは日本語で記述

## 未実装項目
- [ ] アプリ内でアラーム音を鳴らす仕組み（AVAudioPlayer等）— 適度な音量で再生
- [ ] AlarmActiveView に "Woke up" ボタンを追加 — 画面下部、`.ultraThinMaterial` のガラス質感（SwiftUI標準のMaterial）
- [ ] "Woke up" タップ後、音を停止しiPhoneの振動に切り替える
- [ ] 振動は何らかの覚醒アクション（内容未定・保留）を完了するまで継続
- [ ] 就寝時にもアラームを設定できるようにする（寝る時間のアラーム）
- [ ] ナビバーの右端に新しく履歴を追加、そこで過去の起床・睡眠記録を残すようにする。起床・睡眠までの時間を記録。(ただしgithubにはこの記録は載せないように。)
