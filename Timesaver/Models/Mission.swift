import Foundation

/// 覚醒ミッションの種類
enum MissionType: String, CaseIterable, Codable {
    case math = "計算問題"
    case shake = "シェイク"
}

/// 計算問題ミッション
struct MathProblem {
    let question: String
    let answer: Int

    /// ランダムな計算問題を生成
    static func generate() -> MathProblem {
        let operations: [(String, (Int, Int) -> Int)] = [
            ("+", { $0 + $1 }),
            ("×", { $0 * $1 }),
        ]

        let (symbol, operation) = operations.randomElement()!
        let a: Int
        let b: Int

        if symbol == "×" {
            a = Int.random(in: 2...12)
            b = Int.random(in: 2...12)
        } else {
            a = Int.random(in: 10...99)
            b = Int.random(in: 10...99)
        }

        let result = operation(a, b)
        return MathProblem(question: "\(a) \(symbol) \(b) = ?", answer: result)
    }
}
