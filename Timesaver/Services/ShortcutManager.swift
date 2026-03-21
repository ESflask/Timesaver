import UIKit

/// iOSショートカット連携: 純正時計アプリのアラームを操作
struct ShortcutManager {

    // MARK: - ショートカット名

    /// アラーム作成用ショートカット（時刻を受け取り純正時計にアラームを作成）
    static let createAlarmShortcut = "IW_CreateAlarm"

    /// 全アラーム削除用ショートカット（Infinite Wakeが作ったアラームを全削除）
    static let deleteAlarmsShortcut = "IW_DeleteAlarms"

    // MARK: - ショートカット実行

    /// 指定開始時刻から1分おきにN回分のアラーム時刻リストを渡してショートカットを1回だけ呼ぶ
    /// - Parameters:
    ///   - startTime: 最初のアラーム時刻
    ///   - count: アラーム回数
    static func createAlarms(startTime: Date, count: Int) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let times = (0..<count).map { i in
            formatter.string(from: startTime.addingTimeInterval(TimeInterval(i * 60)))
        }
        runShortcut(name: createAlarmShortcut, input: times.joined(separator: "\n"))
    }

    /// Infinite Wakeが作成した全アラームを削除する
    static func deleteAllAlarms() {
        runShortcut(name: deleteAlarmsShortcut, input: nil)
    }

    /// ショートカットをURLスキームで実行
    private static func runShortcut(name: String, input: String?) {
        var urlString = "shortcuts://run-shortcut?name=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)"

        if let input = input {
            let encodedInput = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
            urlString += "&input=text&text=\(encodedInput)"
        }

        guard let url = URL(string: urlString) else { return }

        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }

    // MARK: - 時刻フォーマット

    /// Date → "HH:mm" 文字列に変換
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - セットアップ手順

    static let setupInstructions = """
    【初回セットアップ — 2つのショートカットを作成】

    ━━━━━━━━━━━━━━━━━━━━━━━━
    ショートカット①: IW_CreateAlarm
    （アラーム作成用）
    ━━━━━━━━━━━━━━━━━━━━━━━━
    1. 「ショートカット」アプリを開く
    2. 右上の「＋」で新規作成
    3. 名前を「IW_CreateAlarm」に設定
    4. アクションを以下の順で追加:

       ① 「ショートカットの入力」を取得
          → 入力がテキストとして渡されます（例: "07:00"）

       ② 「アラームを作成」
          → 時刻: ショートカットの入力
          → ラベル: "InfiniteWake"
          → オン

    5. 保存

    ━━━━━━━━━━━━━━━━━━━━━━━━
    ショートカット②: IW_DeleteAlarms
    （全アラーム削除用）
    ━━━━━━━━━━━━━━━━━━━━━━━━
    1. 新規ショートカットを作成
    2. 名前を「IW_DeleteAlarms」に設定
    3. アクションを追加:

       ① 「アラームを検索」
          → ラベルが "InfiniteWake" のアラーム

       ② 「各項目を繰り返す」
          → 繰り返し項目の中で「アラームを切り替え」→ オフ

    4. 保存

    ━━━━━━━━━━━━━━━━━━━━━━━━
    これで準備完了です！
    """
}
