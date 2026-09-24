import UIKit

enum HapticFeedbackService {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func swipeThresholdCrossed() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// カルーセルが枠に吸い付いたときの、ダイヤルのような軽い手ごたえ。
    static func detent() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
