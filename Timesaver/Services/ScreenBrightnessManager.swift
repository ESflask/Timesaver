import UIKit

/// 画面の明るさを管理（アラーム時は最大、起床後は元に戻す）
class ScreenBrightnessManager {
    private var originalBrightness: CGFloat = 0.5

    /// 元の明るさを保存して最大にする
    func maximizeBrightness() {
        DispatchQueue.main.async {
            self.originalBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
        }
    }

    /// 元の明るさに復元する
    func restoreBrightness() {
        DispatchQueue.main.async {
            UIScreen.main.brightness = self.originalBrightness
        }
    }
}
