import UIKit

enum HapticFeedbackService {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func swipeThresholdCrossed() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
