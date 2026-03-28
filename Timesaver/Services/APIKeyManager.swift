import Foundation
import Security

/// Gemini APIキーをKeychainで安全に管理
class APIKeyManager {
    static let shared = APIKeyManager()
    private let keychainKey = "com.timesaver.gemini-api-key"

    private init() {}

    /// APIキーを保存
    func save(_ apiKey: String) {
        let data = Data(apiKey.utf8)

        // 既存を削除してから保存
        delete()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    /// APIキーを取得
    func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// APIキーを削除
    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// APIキーが設定済みかどうか
    var hasAPIKey: Bool {
        load() != nil
    }
}
