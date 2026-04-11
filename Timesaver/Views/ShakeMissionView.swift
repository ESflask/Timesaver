import SwiftUI
import CoreMotion

/// シェイクミッション: スマホを激しく振って覚醒を証明
struct ShakeMissionView: View {
    let onComplete: () -> Void

    @State private var shakeCount: Int = 0
    @State private var motionManager = CMMotionManager()
    @State private var isMonitoring = false

    private let requiredShakes = 100  // 必要なシェイク回数

    var progress: Double {
        Double(shakeCount) / Double(requiredShakes)
    }

    var body: some View {
        VStack(spacing: 30) {
            Text("スマホを振れ！")
                .font(.system(size: 28, weight: .black))

            // プログレスリング
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.2), value: shakeCount)

                VStack {
                    Text("\(shakeCount)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))

                    Text("/ \(requiredShakes)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 180, height: 180)

            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundColor(.orange)
                .symbolEffect(.bounce, options: .repeating, value: isMonitoring)

            Text("激しくシェイクしてください")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .onAppear {
            startMotionDetection()
        }
        .onDisappear {
            stopMotionDetection()
        }
    }

    // MARK: - モーション検出

    private func startMotionDetection() {
        guard motionManager.isAccelerometerAvailable else { return }
        isMonitoring = true
        motionManager.accelerometerUpdateInterval = 0.1

        motionManager.startAccelerometerUpdates(to: .main) { data, _ in
            guard let data = data else { return }

            // 加速度の大きさを計算（重力を除く）
            let magnitude = sqrt(
                pow(data.acceleration.x, 2) +
                pow(data.acceleration.y, 2) +
                pow(data.acceleration.z, 2)
            )

            // 閾値以上ならシェイクとしてカウント
            if magnitude > 2.5 {
                shakeCount += 1

                if shakeCount >= requiredShakes {
                    stopMotionDetection()
                    onComplete()
                }
            }
        }
    }

    private func stopMotionDetection() {
        motionManager.stopAccelerometerUpdates()
        isMonitoring = false
    }
}

#Preview {
    ShakeMissionView(onComplete: {})
}
