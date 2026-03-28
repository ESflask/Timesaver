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
            return "布団に入った状態の写真を送ってください。\n左の＋ボタンから写真を選べます。"
        case .morning:
            return "1階の洗面台の写真を撮って送ってください。\n左の＋ボタンから写真を選べます。"
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
    あなたは「就寝確認AI」です。ユーザーが布団に入って寝る準備ができているか判定します。

    2枚の画像が添付されています。
    - 1枚目: 参照写真（ユーザーが布団に入っている正解の状態）
    - 2枚目: 確認写真（ユーザーが今撮影した写真）

    ## 判定基準（すべて満たす場合のみ true）
    1. 確認写真に人が写っていて、布団またはベッドの中にいる
    2. 横になっている、または布団を被っている状態である
    3. 参照写真と同じ寝室・同じ布団であると合理的に判断できる

    ## 不合格の例
    - 布団の外に座っている / 立っている
    - 布団だけが写っていて人がいない
    - 明らかに別の場所で撮影されている
    - 過去の写真の使い回し（照明や時間帯が不自然）

    回答はJSON形式のみ。他のテキストは一切含めないこと:
    {"result": true, "reason": "20文字以内の日本語で理由"}
    {"result": false, "reason": "20文字以内の日本語で理由"}
    """

    /// 就寝判定（参照写真なし）: 撮影写真1枚から布団に入っているか判定
    private static let nightPromptSingle = """
    あなたは「就寝確認AI」です。ユーザーが布団に入って寝る準備ができているか判定します。

    1枚の画像が添付されています。ユーザーが今撮影した写真です。

    ## 判定基準（すべて満たす場合のみ true）
    1. 写真に人が写っていて、布団またはベッドの中にいる
    2. 横になっている、または布団を被っている状態である
    3. 寝室のような環境で撮影されている

    ## 不合格の例
    - 布団の外に座っている / 立っている
    - 布団だけが写っていて人がいない
    - リビングや外出先で撮影されている

    回答はJSON形式のみ。他のテキストは一切含めないこと:
    {"result": true, "reason": "20文字以内の日本語で理由"}
    {"result": false, "reason": "20文字以内の日本語で理由"}
    """

    // MARK: - Morning プロンプト

    /// 起床判定（参照写真あり）: 参照写真と比較して洗面台の前にいるか判定
    private static let morningPromptWithReference = """
    あなたは「起床確認AI」です。ユーザーが1階の洗面台まで移動したか判定します。

    2枚の画像が添付されています。
    - 1枚目: 参照写真（ユーザーの家の1階にある洗面台の写真）
    - 2枚目: 確認写真（ユーザーが今撮影した写真）

    ## 判定基準（すべて満たす場合のみ true）
    1. 確認写真に洗面台・洗面所が写っている
    2. 参照写真と同じ洗面台であると合理的に判断できる（蛇口、鏡、壁の色、小物等が一致）
    3. 現在その場所にいることが分かる（自撮りや手が写っている等）

    ## 不合格の例
    - 布団の中やベッドの上から撮影されている
    - 洗面台ではない場所（キッチン、トイレ等）
    - 参照写真と明らかに異なる洗面台
    - 過去の写真の使い回し（照明や時間帯が不自然）

    回答はJSON形式のみ。他のテキストは一切含めないこと:
    {"result": true, "reason": "20文字以内の日本語で理由"}
    {"result": false, "reason": "20文字以内の日本語で理由"}
    """

    /// 起床判定（参照写真なし）: 撮影写真1枚から洗面台の前にいるか判定
    private static let morningPromptSingle = """
    あなたは「起床確認AI」です。ユーザーが洗面台まで移動したか判定します。

    1枚の画像が添付されています。ユーザーが今撮影した写真です。

    ## 判定基準（すべて満たす場合のみ true）
    1. 写真に洗面台・洗面所が写っている
    2. ユーザーが洗面台の前にいることが分かる（自撮りや手が写っている等）
    3. 実際にその場にいると判断できる（布団の中からの撮影ではない）

    ## 不合格の例
    - 布団の中やベッドの上から撮影されている
    - 洗面台が写っていない
    - 洗面台の写真だがユーザーがその場にいる証拠がない

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
