# Memo.md
これはプロジェクトの編集の状況を確認するために作成したmarkdownファイルです。AIエージェントが編集する場合も、必ず日付をまず記載して、
既に記載されている記録から学習してそれと同じ構図・形式で編集してください。

## 4月11日 (土)-------------------------------------------------

- 就寝・起床アラームをセットのボタン2つとも正式なliquid glassデザインに変更
- 自動or手動でアラームをセットとユーザーが設定の項目から選択できるように変更
- Gemini API の判定ロジック（プロンプト）を大幅に強化
    - **変更前**: 布団のデザインや環境の一致を重視していたため、シーツやパジャマが変わると失敗しやすかった。
    - **変更後**: 服装や寝具の変化を無視し、「ユーザー本人の顔（骨格）」と「特定の場所（洗面台の設備や寝室の配置）」を最優先で照合するように変更。
    - **ガイド追加**: チャット開始時に「顔を含めて自撮りすること」を促すメッセージを追加。
- ~Firebase Storage が未設定のため、写真の保存・連携機能は保留中~
        ↓
    普通にプロジェクトに洗面台の写真やベッドに入った自分の写真をぶち込めばfirebaseのStorageは不要だった
### Claude codeへののプロンプトのメモ
「ボタンを Apple の Liquid Glass ボタンスタイル（GlassButtonStyle）に変更して」
- デフォルトで用意されたGlassButtonStyleは、ユーザーがボタンを押したら光ってはずむような反応をするエフェクト、ガラスデザイン適応が可能になる。

## 4月12日 (日)-------------------------------------------------

- 緊急セキュリティ対応と履歴の完全抹消
    - `GoogleService-Info.plist` が誤って GitHub にプッシュされ、シークレット（APIキー）が検知された。
    - `git-filter-repo` を使用し、リポジトリの**全履歴から該当ファイルを完全に抹消**。
    - GitHub への強制プッシュ（`force push`）により、過去のコミットからも鍵を消去。
    - 新しい API キーの再発行と、旧キーの無効化（ユーザー側）を推奨。
- Gemini API の判定ロジック最終調整
    - 服装（パジャマ）や寝具（シーツ・枕カバー）の変化を完全に無視するようプロンプトを刷新。
    - **「ユーザーの顔（骨格）」**と**「場所の固定ポイント（設備の形状や家具配置）」**を最優先で照合するように変更。
    - ユーザーへの案内（初回メッセージ）に「顔を含めて自撮りすること」を明示。
- プライバシー保護の強化（参照写真の多重ガード)
    - `Assets.xcassets` 内に `reference_bedtime` と `reference_washstand` の専用スロットを作成。
    - `.gitignore` を強化し、参照写真ファイル自体を Git 管理から完全に除外（`Contents.json` のみ管理）。これにより、ユーザーが自分の写真をドロップしても GitHub には流出しない構成を実現。
- ドキュメントの整理とルール明文化
    - `Agents.md` にセキュリティ・個人情報保護ルールを最重要項目として追記。
    - 破損・重複していたドキュメント箇所を修復。
- 仕様確認(起床) : 
1 ユーザーが設定した時間まで無音ファイルをループしてバックグラウンド動作の状態を維持
2 設定時刻になればアラーム音をバックグラウンド再生に変更、ユーザーが目覚めてコントロールパネルのタイトルをタップ
3 gemini APIによって必須タスクをクリア(万が一オフラインだった場合はスマホを100回ふる... private let requiredShakes = 100 )
- gemini APIが参考とする洗面台の写真とベッドに入った自分の写真はプロジェクト内に入れてある前提の動作
- **[NEW] アラーム発動ロジックの堅牢化**:
    - バックグラウンドでの無音ループから有音アラームへの自動切り替えを `AlarmScheduler` 側で確実に発動するように修正。
    - 重複していたメソッドの整理と `AppState` の細分化。
    - オフライン救済（シェイク）が就寝・起床の両モードで正しく成功画面へ遷移するように修正。
- **[NEW] 曜日別自動アラーム設定 + 明日だけスキップの導入**:
    - Firestore の `app_settings/alarm_settings` を、単一時刻の保存から `weekly_schedule` + `skip_overrides` を持つ週次設定形式に拡張。
    - iOS 側では `WeeklyAlarmSettings` と `AlarmSettingsStore` を追加し、`Settings` タブは自動モード切替のみ、`Morning` / `Night` タブは曜日ごとの起床・就寝時刻編集UIに再編成。
    - `Morning` / `Night` の自動モード画面に、**曜日表のタップ編集**、**次回アラーム表示**、**明朝 / 明夜 / 両方スキップ** の操作を追加。
    - `AlarmScheduler` を週次設定対応に変更し、就寝成功後の起床アラーム解決も曜日ベースで計算するように修正。
    - Web版 `settings` 画面も曜日カード + モーダル編集UIに変更し、iOS と同じ Firestore スキーマを共有するように統一。
- **[NEW] アラーム音の試用機能（デバッグモード）**:
    - 設定画面の下部に「アラーム音を試用」ボタンを追加。
    - ボタンを押すと10秒後に起床アラームが発動し、実際の音量や通知、バックグラウンド動作をテスト可能。
    - `NotificationCenter` を介して `SettingsStore` から `AlarmScheduler` へ即時スケジュール命令を出す設計。

## 4月18日 (土)-------------------------------------------------

- **キャンセルボタンのスタイル統一**:
    - 就寝・起床のアラーム待ち画面（`ArmedView` / `NightArmedView`）のキャンセルボタンを、他のメインボタンと同様に `GlassButtonStyle`（およびフォールバック用の `MaterialBounceButtonStyle`）に適応。赤色で強調。
- **[NEW] 就寝アラーム終了後の起床アラーム自動セット機能**:
    - 手動モード時でも、就寝ミッション成功時に起床アラームを自動的に予約できる設定を追加。
    - `WeeklyAlarmSettings` に `autoSetWakeAlarmAfterBedtime` プロパティを追加し、Firestore との同期に対応。
    - `SettingsView` に上記設定を有効化するトグルを追加（自動アラームがオフの時のみ表示）。
    - `AlarmScheduler` のロジックを更新し、設定が有効な場合に就寝成功後、曜日設定に基づいた起床時刻を自動計算してセットするように変更。
## 4月19日 (土)-------------------------------------------------

- alarm_sound.wav のプロジェクト登録と有効化
- **alarm_sound.wav の音量4倍増幅（ピーク100%）
- **アラーム再生音量を最大化（volume 0.8 → 1.0）
- **アラーム発動時にシステム音量を自動設定（33%）
- **Gemini API 画像送信を Full HD に自動リサイズ（トークン約97%削減）
- **実機での写真保存対応（シミュレータ限定だったのを修正）
- **スリープ中アラーム発動修正（Timer → AVAudioPlayerDelegate方式）
- **デバッグモード停止ボタン追加（チャット画面から離脱可能に
- **Woke up ボタンデザイン変更（赤文字 + 青ボタン）
- **音量ガイド画像を待機画面・設定画面に追加
- **スクロール中の振動停止バグ修正（RunLoop .common モード）
- **スリープ・バックグラウンド時の振動停止バグ修正（UIImpactFeedbackGenerator から AudioServicesPlaySystemSound に変更）
- **[NEW] オフラインデバッグモードの追加**:
    - 設定画面の「アラーム音を試用」の下に「オフラインデバッグモード」ボタンを配置。
    - ボタンを押すと、アラーム発動・Gemini認証を飛ばして当時の必須回数である100回のシェイクミッション（`ShakeMissionView`）に直接遷移（4/25以降は200回）。
    - `AlarmScheduler.startOfflineDebugMission()` を追加し、`currentState` を `.fallbackMission` に切り替える設計。
    - 目的: オフライン状況下でシェイクタスクが問題なく動作するかを単独で検証できるようにする。
### 現在の課題
- Web版においての機能性・利便性がiOS版に劣る(ただしアラーム機能はWebには不要)
4月25日　(土)
- Web版から適応してfirebaseに送られた時間をiOSは常時引っ張ってきて適応するロジックへ改善
- オフライン必須タスクのシェイク数を100→200へ変更
- iOS版のUI改善(GlassButtonStyle適応多数)

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Timesaver アプリ: 設定データの保存場所
    match /app_settings/{document=**} {
      allow read, write: if true;
    }

    // Timesaver アプリ: 睡眠・起床履歴の保存場所
    match /sleep_records/{document=**} {
      allow read, write: if true;
    }
  }
}

4月26日 (日)
-

## 5月4日 (月)-------------------------------------------------

- **[NEW] Web版カラーテーマ設定の追加**:
    - 左サイドバーに `Settings` を追加し、Web版専用の設定画面へ遷移できるように変更。
    - Web版設定画面に「テーマ設定」欄を追加し、クリックでテーマ選択画面へ遷移する構成に変更。
    - テーマ選択画面に「紫(デフォルト)」「黒」「白」「Tokyo Night」を追加。
    - 選択テーマは `localStorage` に保存し、Dashboard / History / Detail / 時間設定を含むWeb版全体に反映。
    - 紫固定だった主要な枠線・ホバー・アクティブ色をCSS変数化し、テーマごとに色調が切り替わるように整理。
- **[NEW] Web版Historyのタスク完了時間グラフ追加**:
    - `sleep_records` の `alarmFiredTime` と `missionCompletedTime` から、アラーム発動〜ミッション完了までの所要時間を集計。
    - History画面に Weekly / Monthly の切替付きグラフを追加し、Morning / Night / All のフィルターと連動するように変更。
    - night単体・morning単体・両方が揃ったセッションを区別できるよう、カード側の `has_morning` / `has_night` / 表示ラベルを整理。
- **[NEW] iOS版カラーテーマ設定の追加**:
    - `AppTheme` と `AppThemeStore` を追加し、「紫」「白」「黒」「Tokyo Night」の4テーマをiOS版にも導入。
    - `TimesaverApp` で `AppThemeStore` を `EnvironmentObject` として注入し、`preferredColorScheme` と `tint` を選択テーマに連動。
    - Settings画面に「カラーテーマ」設定画面を追加し、選択テーマを `UserDefaults` に保存するように変更。
    - Night / Morning / History / 認証チャット / アラーム発動中 / シェイクミッション / 成功画面の固定色をテーマ参照に置き換え。
    - ナビゲーションバー、タブバー、リスト背景、カード背景、ボタン色をテーマごとに切り替わるように調整。
- **[UPDATE] iOS版設定画面の時間設定見出し整理**:
    - Settings画面のナビゲーションタイトルを「時間設定」から「設定」に変更。
    - 「カラーテーマ」設定をSettings画面上部へ移動し、その下に大きい「時間設定」見出しを配置。
    - `LazyVStack` の `Section` ヘッダーを使い、スクロール中に「時間設定」見出しが画面上部へ残るSwiftUI標準の挙動を適用。
    - `List` の行背景ごと固定されていたため、`ScrollView` + `LazyVStack(pinnedViews:)` に変更し、「時間設定」見出しと設定カードの固定判定を分離。
- その他:
    - `MaterialBounceButtonStyle` に `foregroundColor` を追加し、白テーマや黒テーマでも文字色を調整できるように変更。
    - `AppTheme.swift` / `AppThemeStore.swift` をXcodeプロジェクトのSourcesへ登録。
    - `README.md` 冒頭にスクリーンショット日付メモを追加。
    - `README.md` / `Agents.md` にテーマ設定、Web履歴グラフ、Web設定同期保護、シェイク200回仕様、`silence.wav` ループコールバック方式、Web版SVGロゴ、Flask版認証設定を反映。
- **[FIX] Web版設定保存時の iOS 共有キー欠落を修正**:
    - `normalize_settings()` に `auto_set_wake_alarm_after_bedtime` を追加し、Web版が読み込んだ設定を保存しても iOS 側の「就寝アラーム終了後に起床を自動セット」設定が消えないように変更。
    - Firestore 保存処理を既存データとPOST内容のマージ後に `update` する方式へ変更し、古いWeb画面やWeb側が知らないトップレベルキーで設定が欠落しにくい構成へ変更。
    - Web版の時間設定画面にも同設定のトグルを追加し、自動アラームOFF時のみ表示されるように変更。
- **[UI] Web版サイドバーの並び順を調整**:
    - 左ナビバーの「時間設定」を「Settings」のすぐ下に移動。
- **[UI] Web版サイドバーのタイトルロゴをSVG化**:
    - `Infinite-Wake-logo.svg` を Web版の `static` 配下へ配置。
    - 左サイドバー上部の文字タイトル「Infinite Wake」をSVGロゴ画像に置き換え。
    - ロゴクリック時はWeb版のデフォルトページ（Dashboard / `/`）へ遷移するように変更。
- **[DOC] 最新状況の再同期**:
    - `Agents.md` のプロジェクト構成を実際の `Timesaver_SW/Timesaver` + `web` + `shared_photos` 構成に合わせて更新。
    - `README.md` の古い「アプリ内Timer」表記を、現在の `silence.wav` 手動ループ完了コールバック方式に修正。
    - READMEのセットアップに `GoogleService-Info.plist` とWeb版 `FIREBASE_SERVICE_ACCOUNT` / `web/` 配下Firebase Admin SDK JSON の前提を追加。
    - ロゴを枠内の左右中央に配置し、枠の高さを使い切る表示に調整。
- **[UI] iOS版アプリアイコンをSVGロゴ由来に変更**:
    - `web/static/Infinite-Wake-logo.svg` と同一のSVGロゴから1024pxの透過なしPNGを生成し、`AppIcon.appiconset` に登録。
    - `Contents.json` に `AppIcon.png` を紐づけ、iOS AppIconとしてビルド対象に含めるように変更。
