import Foundation
import FirebaseFirestore

/// Firestore との読み書きを管理
class FirestoreService {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()
    private let collectionName = "sleep_records"

    private init() {}

    // MARK: - 書き込み

    /// SleepRecord を Firestore に保存
    func save(_ record: SleepRecord) async throws {
        let data = toFirestoreData(record)
        try await db.collection(collectionName).document(record.id.uuidString).setData(data)
    }

    // MARK: - 読み取り

    /// Firestore から全レコードを新しい順で取得
    func fetchAll() async throws -> [SleepRecord] {
        let snapshot = try await db.collection(collectionName)
            .order(by: "alarmSetTime", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { fromFirestoreData($0.documentID, $0.data()) }
    }

    // MARK: - 変換

    private func toFirestoreData(_ record: SleepRecord) -> [String: Any] {
        var data: [String: Any] = [
            "mode": record.mode.rawValue,
            "alarmSetTime": Timestamp(date: record.alarmSetTime),
        ]

        if let t = record.alarmFiredTime {
            data["alarmFiredTime"] = Timestamp(date: t)
        }
        if let t = record.actionButtonTime {
            data["actionButtonTime"] = Timestamp(date: t)
        }
        if let t = record.missionCompletedTime {
            data["missionCompletedTime"] = Timestamp(date: t)
        }
        if let s = record.reactionSeconds {
            data["reactionSeconds"] = s
        }
        if let s = record.missionSeconds {
            data["missionSeconds"] = s
        }
        if let s = record.totalSeconds {
            data["totalSeconds"] = s
        }

        // Web版との互換フィールド
        data["timestamp"] = Timestamp(date: record.alarmSetTime)
        if record.mode == .night {
            if let t = record.actionButtonTime {
                data["bedtime"] = Timestamp(date: t)
            }
        } else {
            if let t = record.actionButtonTime {
                data["waketime"] = Timestamp(date: t)
            }
        }

        return data
    }

    private func fromFirestoreData(_ docId: String, _ data: [String: Any]) -> SleepRecord? {
        guard let modeStr = data["mode"] as? String,
              let mode = SleepRecord.RecordMode(rawValue: modeStr),
              let alarmSetTs = data["alarmSetTime"] as? Timestamp else {
            return nil
        }

        var record = SleepRecord(mode: mode, alarmSetTime: alarmSetTs.dateValue())

        // ドキュメントIDからUUIDを復元（できなければ新規生成）
        if let uuid = UUID(uuidString: docId) {
            record.id = uuid
        }

        if let t = data["alarmFiredTime"] as? Timestamp {
            record.alarmFiredTime = t.dateValue()
        }
        if let t = data["actionButtonTime"] as? Timestamp {
            record.actionButtonTime = t.dateValue()
        }
        if let t = data["missionCompletedTime"] as? Timestamp {
            record.missionCompletedTime = t.dateValue()
        }

        return record
    }
}
