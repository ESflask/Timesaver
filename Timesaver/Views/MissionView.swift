import SwiftUI

/// 覚醒ミッション画面: Gemini AI チャットで起床認証（1階の洗面台を撮影）
struct MissionView: View {
    @EnvironmentObject var scheduler: AlarmScheduler

    var body: some View {
        VerificationChatView(mode: .morning)
    }
}

#Preview {
    MissionView()
        .environmentObject(AlarmScheduler())
}
