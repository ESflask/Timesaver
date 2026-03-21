import UIKit

/// iOSショートカット連携: URLスキームでアラームショートカットを起動
struct ShortcutManager {

    /// ショートカット名（ユーザーが事前登録するもの）
    static let shortcutName = "InfiniteWakeAlarm"

    /// ショートカットを実行してシステムアラーム音を鳴らす
    static func triggerAlarmShortcut() {
        // URLスキームでショートカットアプリを呼び出す
        let encodedName = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? shortcutName
        guard let url = URL(string: "shortcuts://run-shortcut?name=\(encodedName)") else { return }

        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }

    /// ショートカットのセットアップ手順テキスト
    static let setupInstructions = """
    【初回セットアップ】
    1. iOSの「ショートカット」アプリを開く
    2. 新規ショートカットを作成
    3. 名前を「InfiniteWakeAlarm」に設定
    4. アクションを追加：
       ・「音量を設定」→ 100%
       ・「アラームを切り替え」→ オン
       ・または「サウンドを再生」
    5. 保存して完了

    これで準備OKです！
    """
}
