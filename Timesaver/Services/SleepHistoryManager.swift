import Foundation

/// 睡眠・起床記録の管理
/// Firestore をプライマリ、ローカルJSONをキャッシュとして使用
class SleepHistoryManager: ObservableObject {
    @Published var records: [SleepRecord] = []
    @Published var currentRecord: SleepRecord?
    @Published var isLoading = false

    private let fileName = "sleep_history.json"
    private let firestore = FirestoreService.shared

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }

    init() {
        loadLocal()
    }

    // MARK: - Firestore同期

    /// アプリ起動時にFirestoreからデータを取得
    func fetchFromFirestore() {
        guard !isLoading else { return }
        isLoading = true

        Task {
            do {
                let fetched = try await firestore.fetchAll()
                await MainActor.run {
                    self.records = fetched
                    self.isLoading = false
                    self.saveLocal()
                }
            } catch {
                print("Firestore取得エラー: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    /// レコードをFirestoreに保存
    private func saveToFirestore(_ record: SleepRecord) {
        Task {
            do {
                try await firestore.save(record)
            } catch {
                print("Firestore保存エラー: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - 記録操作

    /// Morning: アラームセット時にレコード開始
    func startMorningRecord(alarmTime: Date) {
        currentRecord = SleepRecord(mode: .morning, alarmSetTime: alarmTime)
    }

    /// Night: アラームセット時にレコード開始
    func startNightRecord(alarmTime: Date) {
        currentRecord = SleepRecord(mode: .night, alarmSetTime: alarmTime)
    }

    /// アラームが鳴り始めた時刻を記録
    func recordAlarmFired() {
        currentRecord?.alarmFiredTime = Date()
    }

    /// 「起きた」or「布団に入った」ボタン押下時刻を記録
    func recordActionButton() {
        currentRecord?.actionButtonTime = Date()
    }

    /// ミッション完了 → 履歴に追加 + Firestoreに送信
    func recordMissionCompleted() {
        guard var record = currentRecord else { return }
        record.missionCompletedTime = Date()
        records.insert(record, at: 0)
        currentRecord = nil
        saveLocal()
        saveToFirestore(record)
    }

    /// 記録を削除
    func deleteRecord(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        saveLocal()
    }

    /// 全記録を削除
    func clearAll() {
        records.removeAll()
        currentRecord = nil
        saveLocal()
    }

    // MARK: - ローカルキャッシュ

    private func saveLocal() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL)
        } catch {
            print("ローカル保存エラー: \(error.localizedDescription)")
        }
    }

    private func loadLocal() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            records = try JSONDecoder().decode([SleepRecord].self, from: data)
        } catch {
            print("ローカル読み込みエラー: \(error.localizedDescription)")
        }
    }
}
