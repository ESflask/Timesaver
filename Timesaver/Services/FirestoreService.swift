import Foundation
import FirebaseFirestore
import UIKit

/// Firestore との読み書き、およびローカル共有フォルダへの写真保存を管理
class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    private let collectionName = "sleep_records"
    private let settingsCollection = "app_settings"
    private let settingsDoc = "alarm_settings"

    // 共有写真ディレクトリのフルパス（シミュレータ用）
    private let sharedPhotosPath = "/Users/endoushougo/Python_pjs/Timesaver_SW/shared_photos"

    /// アプリ内の写真保存ディレクトリ（実機・シミュレータ共通）
    private var localPhotosDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("verification_photos")
    }

    private init() {
        // 写真保存ディレクトリを作成
        try? FileManager.default.createDirectory(at: localPhotosDirectory, withIntermediateDirectories: true)
    }

    // MARK: - 設定同期

    /// Firestore から設定を取得
    func fetchSettings() async throws -> WeeklyAlarmSettings {
        let doc = try await db.collection(settingsCollection).document(settingsDoc).getDocument()
        return WeeklyAlarmSettings.fromFirestoreData(doc.data())
    }

    /// Firestore へ設定を保存
    func saveSettings(_ settings: WeeklyAlarmSettings) async throws {
        var data = settings.asFirestoreData()
        data["updated_at"] = FieldValue.serverTimestamp()
        try await db.collection(settingsCollection).document(settingsDoc).setData(data)
    }

    // MARK: - 書き込み

    /// SleepRecord を Firestore に保存し、画像がある場合は共有フォルダに保存
    func save(_ record: SleepRecord, image: UIImage? = nil) async throws {
        var data = toFirestoreData(record)
        
        // 画像がある場合、共有フォルダに保存してパスを記録
        if let image = image {
            let filename = "\(record.id.uuidString).jpg"
            if saveImageToSharedFolder(image, filename: filename) {
                data["photo_path"] = "shared_photos/\(filename)"
            }
        }
        
        try await db.collection(collectionName).document(record.id.uuidString).setData(data)
    }

    // MARK: - 内部処理

    /// 認証写真をローカルに保存（実機・シミュレータ共通）
    /// シミュレータではプロジェクトの共有フォルダにも追加保存する
    private func saveImageToSharedFolder(_ image: UIImage, filename: String) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return false }

        // アプリ内Documentsに保存（実機・シミュレータ共通）
        let localURL = localPhotosDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: localURL)
            print("写真をアプリ内に保存: \(localURL.path)")
        } catch {
            print("アプリ内への写真保存に失敗: \(error)")
            return false
        }

        // シミュレータの場合はプロジェクトフォルダにも保存
        #if targetEnvironment(simulator)
        let sharedURL = URL(fileURLWithPath: sharedPhotosPath).appendingPathComponent(filename)
        do {
            try data.write(to: sharedURL)
            print("写真を共有フォルダにも保存: \(sharedURL.path)")
        } catch {
            print("共有フォルダへの保存に失敗（アプリ内には保存済み）: \(error)")
        }
        #endif

        return true
    }

    /// 保存済み写真のURLを取得（存在する場合）
    func photoURL(for recordID: UUID) -> URL? {
        let url = localPhotosDirectory.appendingPathComponent("\(recordID.uuidString).jpg")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func toFirestoreData(_ record: SleepRecord) -> [String: Any] {
        var data: [String: Any] = [
            "mode": record.mode.rawValue,
            "alarmSetTime": Timestamp(date: record.alarmSetTime),
            "timestamp": Timestamp(date: record.alarmSetTime) // Web版との互換用
        ]

        if let t = record.alarmFiredTime { data["alarmFiredTime"] = Timestamp(date: t) }
        if let t = record.actionButtonTime { 
            data["actionButtonTime"] = Timestamp(date: t)
            if record.mode == .night { data["bedtime"] = Timestamp(date: t) }
            else { data["waketime"] = Timestamp(date: t) }
        }
        if let t = record.missionCompletedTime { data["missionCompletedTime"] = Timestamp(date: t) }
        
        return data
    }

    /// Firestore から全レコードを新しい順で取得
    func fetchAll() async throws -> [SleepRecord] {
        let snapshot = try await db.collection(collectionName)
            .order(by: "timestamp", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let modeStr = data["mode"] as? String,
                  let mode = SleepRecord.RecordMode(rawValue: modeStr),
                  let ts = data["timestamp"] as? Timestamp else { return nil }
            
            var record = SleepRecord(mode: mode, alarmSetTime: ts.dateValue())
            if let uuid = UUID(uuidString: doc.documentID) { record.id = uuid }
            if let t = data["alarmFiredTime"] as? Timestamp { record.alarmFiredTime = t.dateValue() }
            if let t = data["actionButtonTime"] as? Timestamp { record.actionButtonTime = t.dateValue() }
            if let t = data["missionCompletedTime"] as? Timestamp { record.missionCompletedTime = t.dateValue() }
            return record
        }
    }
}
