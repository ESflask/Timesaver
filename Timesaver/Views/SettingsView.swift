import SwiftUI

/// 設定画面: APIキーの入力・管理
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var isSaved = false
    @State private var isKeyVisible = false

    private let manager = APIKeyManager.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if isKeyVisible {
                            TextField("AIza...", text: $apiKey)
                                .font(.system(.body, design: .monospaced))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("AIza...", text: $apiKey)
                                .font(.system(.body, design: .monospaced))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }

                        Button {
                            isKeyVisible.toggle()
                        } label: {
                            Image(systemName: isKeyVisible ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Gemini API Key")
                } footer: {
                    Text("キーはこの端末のKeychainに安全に保存されます")
                }

                Section {
                    Button {
                        manager.save(apiKey)
                        isSaved = true
                    } label: {
                        HStack {
                            Text("保存")
                            if isSaved {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .disabled(apiKey.isEmpty)

                    if manager.hasAPIKey {
                        Button(role: .destructive) {
                            manager.delete()
                            apiKey = ""
                            isSaved = false
                        } label: {
                            Text("キーを削除")
                        }
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear {
                // 既存キーがあればマスク表示用に読み込み
                if let existing = manager.load() {
                    apiKey = existing
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
