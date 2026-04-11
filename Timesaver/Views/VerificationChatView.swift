import SwiftUI
import PhotosUI

/// チャットメッセージのデータ
struct ChatMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String?
    let image: UIImage?
    let timestamp = Date()
}

/// Gemini API 認証チャット画面
/// 写真を送ってAIに就寝/起床を判定してもらう
struct VerificationChatView: View {
    let mode: GeminiService.VerificationMode
    @EnvironmentObject var scheduler: AlarmScheduler
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingImage: UIImage?
    @State private var isLoading = false
    @State private var isFocused = false
    @FocusState private var textFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            headerView

            Divider()

            // メッセージ一覧
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }

                        if isLoading {
                            HStack {
                                TypingIndicator()
                                Spacer()
                            }
                            .padding(.horizontal)
                            .id("loading")
                        }
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: messages.count) {
                    withAnimation {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isLoading) {
                    if isLoading {
                        withAnimation {
                            proxy.scrollTo("loading", anchor: .bottom)
                        }
                    }
                }
            }

            // 添付画像プレビュー
            if let img = pendingImage {
                HStack {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        pendingImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            // オフライン救済ボタン
            if scheduler.consecutiveErrors >= 3 {
                Button {
                    scheduler.switchToFallbackMission()
                } label: {
                    HStack {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                        Text("オフラインミッション（シェイク）に切り替える")
                            .fontWeight(.bold)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }

            // 入力バー
            inputBar
        }
        .onAppear {
            // モードに応じた初回メッセージ
            let greeting = ChatMessage(
                isUser: false,
                text: GeminiService.greetingMessage(for: mode),
                image: nil
            )
            messages.append(greeting)
        }
    }

    // MARK: - ヘッダー

    private var headerView: some View {
        HStack {
            Image(systemName: mode == .night ? "moon.fill" : "sun.max.fill")
                .foregroundColor(mode == .night ? .indigo : .orange)
            Text(GeminiService.headerTitle(for: mode))
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - 入力バー

    private var inputBar: some View {
        HStack(spacing: 10) {
            // ＋ボタン（写真選択）
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .onChange(of: selectedPhoto) {
                loadPhoto()
            }

            // テキスト入力欄
            HStack(spacing: 8) {
                TextField("メッセージ（任意）", text: $inputText)
                    .focused($textFieldFocused)
                    .onChange(of: textFieldFocused) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFocused = textFieldFocused
                        }
                    }

                // 送信ボタン
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(canSend ? .purple : .gray.opacity(0.4))
                }
                .disabled(!canSend || isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isFocused ? Color.purple.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
            .shadow(color: isFocused ? .purple.opacity(0.2) : .clear, radius: 8)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - ロジック

    private var canSend: Bool {
        pendingImage != nil || !inputText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func loadPhoto() {
        guard let item = selectedPhoto else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                pendingImage = image
            }
            selectedPhoto = nil
        }
    }

    private func sendMessage() {
        guard canSend else { return }

        let text = inputText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : inputText
        let image = pendingImage

        // ユーザーメッセージを追加
        messages.append(ChatMessage(isUser: true, text: text, image: image))
        inputText = ""
        pendingImage = nil
        textFieldFocused = false
        isLoading = true

        // Gemini API に送信
        Task {
            do {
                let response = try await GeminiService.sendChat(
                    mode: mode,
                    message: text,
                    image: image,
                    referenceImage: loadReferenceImage()
                )

                let aiMessage = ChatMessage(isUser: false, text: response, image: nil)
                messages.append(aiMessage)

                // 判定結果をチェック
                if let result = GeminiService.extractVerification(from: response), result.passed {
                    // 認証成功 → 少し待ってから完了処理
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    if mode == .night {
                        scheduler.nightMissionCompleted()
                    } else {
                        scheduler.missionCompleted()
                    }
                }
            } catch {
                scheduler.reportCommunicationError()
                
                var errorText = "エラーが発生しました: \(error.localizedDescription)\nもう一度写真を送ってみてください。"
                
                if scheduler.consecutiveErrors >= 3 {
                    errorText += "\n\n⚠️ ネットワークが不安定なようです。通信を伴わない「シェイクミッション」に切り替えることも可能です。"
                }

                let aiMessage = ChatMessage(
                    isUser: false,
                    text: errorText,
                    image: nil
                )
                messages.append(aiMessage)
            }
            isLoading = false
        }
    }

    /// モードに応じた参照写真をバンドルから読み込み
    private func loadReferenceImage() -> UIImage? {
        UIImage(named: GeminiService.referenceImageName(for: mode))
    }
}

// MARK: - チャットバブル

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer() }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                // 画像
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // テキスト
                if let text = message.text {
                    Text(text)
                        .font(.body)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(message.isUser ? Color.purple : Color(.systemGray5))
                        .foregroundColor(message.isUser ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)

            if !message.isUser { Spacer() }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - タイピングインジケーター

struct TypingIndicator: View {
    @State private var dotCount = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .opacity(dotCount == i ? 1.0 : 0.3)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                dotCount = (dotCount + 1) % 3
            }
        }
    }
}

#Preview {
    VerificationChatView(mode: .morning)
        .environmentObject(AlarmScheduler())
}
