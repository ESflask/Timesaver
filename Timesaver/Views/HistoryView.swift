import SwiftUI

/// 睡眠・起床記録の履歴画面
struct HistoryView: View {
    @EnvironmentObject var historyManager: SleepHistoryManager

    var body: some View {
        NavigationStack {
            Group {
                if historyManager.isLoading && historyManager.records.isEmpty {
                    ProgressView("読み込み中...")
                } else if historyManager.records.isEmpty {
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
                            RecordRow(record: record)
                        }
                        .onDelete { offsets in
                            historyManager.deleteRecord(at: offsets)
                        }
                    }
                }
            }
            .navigationTitle("履歴")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                historyManager.fetchFromFirestore()
            }
        }
    }
}

// MARK: - 記録行

struct RecordRow: View {
    let record: SleepRecord

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
        VStack(alignment: .leading, spacing: 8) {
            // 日付 + モードアイコン
            HStack {
                Image(systemName: record.mode == .night ? "moon.fill" : "sun.max.fill")
                    .foregroundColor(record.mode == .night ? .indigo : .orange)
                Text(dateFormatter.string(from: record.alarmSetTime))
                    .font(.headline)
                Text(record.mode == .night ? "就寝" : "起床")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(record.mode == .night ? Color.indigo.opacity(0.2) : Color.orange.opacity(0.2))
                    .cornerRadius(4)
            }

            // タイムライン
            HStack(spacing: 16) {
                if let fired = record.alarmFiredTime {
                    Label(timeFormatter.string(from: fired), systemImage: "bell.fill")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                if let action = record.actionButtonTime {
                    Label(timeFormatter.string(from: action),
                          systemImage: record.mode == .night ? "bed.double.fill" : "figure.walk")
                        .font(.subheadline)
                        .foregroundColor(record.mode == .night ? .indigo : .orange)
                }
            }

            // タイム計測
            HStack(spacing: 12) {
                if let reaction = record.reactionSeconds {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .foregroundColor(.secondary)
                        Text("反応: \(formattedDuration(reaction))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if let mission = record.missionSeconds {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.secondary)
                        Text("認証: \(formattedDuration(mission))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if let total = record.totalSeconds {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text("合計: \(formattedDuration(total))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// 秒数を「○分○秒」or「○時間○分」形式に変換
    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        }
        if minutes > 0 {
            return "\(minutes)分\(secs)秒"
        }
        return "\(secs)秒"
    }
}

#Preview {
    HistoryView()
        .environmentObject(SleepHistoryManager())
}
