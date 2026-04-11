import Foundation
import UIKit

/// Gemini API との通信を管理
/// 画像を送信し、布団に入っているか等の判定を行う
class GeminiService {

    // MARK: - APIキー

    private static var apiKey: String {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path),
              let key = dict["GEMINI_API_KEY"] as? String,
              key != "YOUR_API_KEY_HERE" else {
            fatalError("Secrets.plist に有効な GEMINI_API_KEY を設定してください")
        }
        return key
    }

    // MARK: - エンドポイント

    /// Gemini 2.0 Flash（画像対応・高速・低コスト）
    private static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

    // MARK: - モード定義

    /// 認証モード
    enum VerificationMode {
        case night    // 就寝認証: 布団に入っているか
        case morning  // 起床認証: 1階の洗面台まで移動したか
    }

    // MARK: - プロンプト定義

    /// モードに応じたプロンプトを返す
    static func prompt(for mode: VerificationMode, hasReference: Bool) -> String {
        switch (mode, hasReference) {
        case (.night, true):   return nightPromptWithReference
        case (.night, false):  return nightPromptSingle
        case (.morning, true): return morningPromptWithReference
        case (.morning, false): return morningPromptSingle
        }
    }

    /// モードに応じた初回メッセージを返す
    static func greetingMessage(for mode: VerificationMode) -> String {
        switch mode {
        case .night:
            return "ご自身の顔が写るように、布団に入った状態の自撮り写真を送ってください。\n服装や布団の柄は自由です。左の＋ボタンから選べます。"
        case .morning:
            return "ご自身の顔と洗面台が一緒に写るように、自撮りして送ってください。\n左の＋ボタンから撮影・選択できます。"
        }
    }

    /// モードに応じたヘッダータイトルを返す
    static func headerTitle(for mode: VerificationMode) -> String {
        switch mode {
        case .night:   return "就寝認証"
        case .morning: return "起床認証"
        }
    }

    /// モードに応じた参照写真のアセット名を返す
    static func referenceImageName(for mode: VerificationMode) -> String {
        switch mode {
        case .night:   return "reference_bedtime"
        case .morning: return "reference_washstand"
        }
    }

    // MARK: - Night プロンプト

    /// 就寝判定（参照写真あり）: 参照写真と比較して布団に入っているか判定
    private static let nightPromptWithReference = """
    あなたは「就寝確認AI」です。ユーザーが布団に入り、就寝準備が整ったかを厳格に判定してください。

    2枚の画像が添付されています。
    - 1枚目: 参照写真（ユーザー本人の顔と、寝室の基本環境）
    - 2枚目: 確認写真（ユーザーが今撮影した、布団の中の自撮り）

    ## 重要：判定の優先順位
    1. **顔の照合（最優先）**: 確認写真の顔が、参照写真の人物と同一であるか。骨格や顔のパーツで判断し、**髪型、眼鏡の有無、表情の違いは許容**してください。
    2. **状況の確認**: ユーザーが布団またはベッドの中に完全に入っているか。
    3. **場所の恒常性**: 背景の壁や家具の配置が参照写真と矛盾しないか。

    ## 許容事項（これらが違っても true と判定すること）
    - **服装**: パジャマの種類、色、柄。
    - **寝具**: 掛け布団カバー、枕、シーツの色や柄。これらは頻繁に変わるため、判定基準から除外してください。
    - **照明**: 部屋の明るさや光の色。

    ## 不合格の例
    - 顔が参照写真の人物と明らかに異なる。
    - 布団の外にいる（座っている、立っている）。
    - 人が写っていない。
    - 明らかに別の部屋。

    回答はJSON形式のみ。他のテキストは一切含めないこと:
    {"result": true, "reason": "20文字以内の日本語で理由"}
    {"result": false, "reason": "20文字以内の日本語で理由"}
    """

    /// 就寝判定（参照写真なし）: 撮影写真1枚から布団に入っているか判定
    private static let nightPromptSingle = """
    あなたは「就寝確認AI」です。ユーザーが布団に入っているか判定します。

    1枚の画像（自撮り）が添付されています。

    ## 判定基準
    1. 写真に「人の顔」がはっきりと写っていること。
    2. その人物が布団またはベッドの中にいて、寝る体勢（横になっている等）であること。

    ## 許容事項
    - 服装や寝具の色・柄、照明の状態。

    ## 不合格の例
    - 布団の外にいる。
    - 顔が写っていない、または判別できない。
    - 寝室ではない場所（ソファ、屋外等）。

    回答はJSON形式のみ。他のテキストは一切含めないこと:
    {"result": true, "reason": "20文字以内の日本語で理由"}
    {"result": false, "reason": "20文字以内の日本語で理由"}
    """

    // MARK: - Morning プロンプト

    /// 起床判定（参照写真あり）: 参照写真と比較して洗面台の前にいるか判定
    private static let morningPromptWithReference = """
    あなたは「起床確認AI」です。ユーザーが洗面台まで移動したか判定してください。

    2枚の画像が添付されています。
    - 1枚目: 参照写真（正しい場所である洗面台と、ユーザー本人の顔）
    - 2枚目: 確認写真（ユーザーが今撮影した自撮り）

    ## 重要：判定の優先順位
    1. **顔の照合（最優先）**: 確認写真の顔が、参照写真の人物と同一であるか。骨格等で判断し、**寝起きの顔のむくみや髪の乱れは許容**してください。
    2. **場所の特定**: 写っている洗面台の設備（蛇口の形、鏡の枠、タイルの柄等）が参照写真と一致するか。
    3. **現在の状況**: 布団から出て、洗面所の前に立って（または座って）撮影していることが明確か。

    ## 許容事項
    - **服装**: 着ている服の色や種類。
    - **照明**: 朝の光の入り方、電球の色の違い。

    ## 不合格の例
    - 顔が参照写真の人物と異なる。
    - 布団やベッドの中から撮影されている（背景に寝具が見えるなど）。
    - 参照写真と異なる場所（キッチン、外出先等）。

    回答はJSON形式のみ。他のテキストは一切含めないこと:
    {"result": true, "reason": "20文字以内の日本語で理由"}
    {"result": false, "reason": "20文字以内の日本語で理由"}
    """

    /// 起床判定（参照写真なし）: 撮影写真1枚から洗面台の前にいるか判定
    private static let morningPromptSingle = """
    あなたは「起床確認AI」です。ユーザーが洗面台まで移動したか判定します。

    1枚の画像（洗面台での自撮り）が添付されています。

    ## 判定基準
    1. 写真に「人の顔」と「洗面台」が同時に写っていること。
    2. 布団から完全に脱出し、洗面所にいることが背景から判断できること。

    ## 不合格の例
    - 洗面台が写っていない。
    - 人の顔が写っていない。
    - 布団の中や寝室で撮影されている。

    回答はJSON形式のみ。他のテキストは一切含めないこと:
    {"result": true, "reason": "20文字以内の日本語で理由"}
    {"result": false, "reason": "20文字以内の日本語で理由"}
    """

    // MARK: - API通信

    /// 判定結果
    struct VerificationResult {
        let passed: Bool
        let reason: String
    }

    /// チャット形式で送信（モード + テキスト + 任意の画像）
    static func sendChat(
        mode: VerificationMode,
        message: String?,
        image: UIImage?,
        referenceImage: UIImage?
    ) async throws -> String {
        var parts: [[String: Any]] = []

        // 参照写真がある場合は先に添付
        if let ref = referenceImage,
           let refData = ref.jpegData(compressionQuality: 0.8) {
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": refData.base64EncodedString()
                ]
            ])
        }

        // ユーザーが送った画像
        if let img = image,
           let imgData = img.jpegData(compressionQuality: 0.8) {
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": imgData.base64EncodedString()
                ]
            ])
        }

        // モードに応じたプロンプト + ユーザーメッセージ
        let systemPrompt = prompt(for: mode, hasReference: referenceImage != nil)
        let userText = message?.isEmpty == false ? "\n\nユーザーからの追加メッセージ: \(message!)" : ""
        parts.append(["text": systemPrompt + userText])

        let url = URL(string: "\(endpoint)?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 512
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw GeminiError.apiError(statusCode: code)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let respParts = content["parts"] as? [[String: Any]],
              let text = respParts.first?["text"] as? String else {
            throw GeminiError.invalidResponse
        }
        return text
    }

    /// レスポンステキストからJSON判定結果を抽出
    static func extractVerification(from text: String) -> VerificationResult? {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? Bool,
              let reason = json["reason"] as? String else {
            return nil
        }
        return VerificationResult(passed: result, reason: reason)
    }

    // MARK: - エラー定義

    enum GeminiError: LocalizedError {
        case apiError(statusCode: Int)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .apiError(let code):
                return "Gemini API エラー (ステータス: \(code))"
            case .invalidResponse:
                return "Gemini API のレスポンスを解析できませんでした"
            }
        }
    }
}
