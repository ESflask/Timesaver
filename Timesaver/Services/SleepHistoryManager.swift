import Foundation

/// 睡眠・起床記録の永続化マネージャー
/// データはアプリのDocumentsディレクトリにJSON保存（git管理外）
class SleepHistoryManager: ObservableObject {
    @Published var records: [SleepRecord] = []
    @Published var currentRecord: SleepRecord?

    private let fileName = "sleep_history.json"

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(fileName)
    }

    init() {
        loadRecords()
    }

    // MARK: - 記録操作

    /// 就寝時刻を記録（新しいレコード開始）
    func recordBedtime(_ time: Date) {
        var record = SleepRecord(date: time)
        record.bedtime = time
        currentRecord = record
    }

    /// 起床時刻を記録（Woke upボタン押下時）
    func recordWakeUp() {
        currentRecord?.wakeUpTime = Date()
    }

    /// ミッション完了時刻を記録し、履歴に保存
    func recordMissionCompleted() {
        guard var record = currentRecord else { return }
        record.missionCompletedTime = Date()
        records.insert(record, at: 0)
        currentRecord = nil
        saveRecords()
    }

    /// 記録を削除
    func deleteRecord(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        saveRecords()
    }

    /// 全記録を削除
    func clearAll() {
        records.removeAll()
        currentRecord = nil
        saveRecords()
    }

    // MARK: - 永続化（Documentsディレクトリ — git管理外）

    private func saveRecords() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: fileURL)
        } catch {
            print("睡眠記録の保存に失敗: \(error.localizedDescription)")
        }
    }

    private func loadRecords() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            records = try JSONDecoder().decode([SleepRecord].self, from: data)
        } catch {
            print("睡眠記録の読み込みに失敗: \(error.localizedDescription)")
        }
    }
}
