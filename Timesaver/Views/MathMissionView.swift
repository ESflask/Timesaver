import SwiftUI

/// 計算問題ミッション: 3問正解で覚醒を証明
struct MathMissionView: View {
    let onComplete: () -> Void

    @State private var currentProblem = MathProblem.generate()
    @State private var userAnswer = ""
    @State private var solvedCount = 0
    @State private var isWrong = false
    @FocusState private var isInputFocused: Bool

    private let requiredCorrect = 3

    var body: some View {
        VStack(spacing: 24) {
            // 進捗
            HStack {
                ForEach(0..<requiredCorrect, id: \.self) { i in
                    Circle()
                        .fill(i < solvedCount ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 16, height: 16)
                }
            }

            Text("問題 \(solvedCount + 1) / \(requiredCorrect)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // 問題
            Text(currentProblem.question)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .padding()

            // 回答入力
            TextField("答えを入力", text: $userAnswer)
                .font(.system(size: 32, weight: .medium, design: .rounded))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)
                .focused($isInputFocused)

            // 回答ボタン
            Button {
                checkAnswer()
            } label: {
                Text("回答")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 200)
                    .padding(.vertical, 14)
                    .background(userAnswer.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(12)
            }
            .disabled(userAnswer.isEmpty)

            if isWrong {
                Text("不正解！もう一度！")
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .fontWeight(.bold)
            }
        }
        .onAppear {
            isInputFocused = true
        }
    }

    private func checkAnswer() {
        guard let answer = Int(userAnswer) else {
            isWrong = true
            return
        }

        if answer == currentProblem.answer {
            solvedCount += 1
            isWrong = false
            userAnswer = ""

            if solvedCount >= requiredCorrect {
                onComplete()
            } else {
                currentProblem = MathProblem.generate()
            }
        } else {
            isWrong = true
            userAnswer = ""
        }
    }
}

#Preview {
    MathMissionView(onComplete: {})
}
