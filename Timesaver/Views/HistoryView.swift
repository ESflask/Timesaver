import SwiftUI

/// 睡眠・起床記録の履歴画面
struct HistoryView: View {
    @EnvironmentObject var historyManager: SleepHistoryManager
    @Environment(\.dismiss) private var dismiss

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d (E)"
        return f
    }()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if historyManager.records.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("まだ記録がありません")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(historyManager.records) { record in
                            RecordRow(record: record,
                                      dateFormatter: dateFormatter,
                                      timeFormatter: timeFormatter)
                        }
                        .onDelete { offsets in
                            historyManager.deleteRecord(at: offsets)
                        }
                    }
                }
            }
            .navigationTitle("履歴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 記録行

struct RecordRow: View {
    let record: SleepRecord
    let dateFormatter: DateFormatter
    let timeFormatter: DateFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 日付
            Text(dateFormatter.string(from: record.date))
                .font(.headline)

            HStack(spacing: 16) {
                // 就寝時刻
                if let bedtime = record.bedtime {
                    Label(timeFormatter.string(from: bedtime), systemImage: "moon.fill")
                        .font(.subheadline)
                        .foregroundColor(.indigo)
                }

                // 起床時刻
                if let wakeUp = record.wakeUpTime {
                    Label(timeFormatter.string(from: wakeUp), systemImage: "sun.max.fill")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }

            // 睡眠時間
            if let duration = record.sleepDuration {
                HStack(spacing: 4) {
                    Image(systemName: "bed.double.fill")
                        .foregroundColor(.secondary)
                    Text("睡眠: \(formattedDuration(duration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 起床にかかった時間
            if let wakeUpDuration = record.wakeUpDuration {
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .foregroundColor(.secondary)
                    Text("覚醒まで: \(formattedDuration(wakeUpDuration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// 秒数を「○時間○分」形式に変換
    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        }
        return "\(minutes)分"
    }
}

#Preview {
    HistoryView()
        .environmentObject(SleepHistoryManager())
}
