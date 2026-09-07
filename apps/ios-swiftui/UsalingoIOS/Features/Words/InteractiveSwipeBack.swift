import SwiftUI
import UIKit

extension View {
    /// UIKit 側の開始地点判定に使う印。ヒットテスト自体は担当しないため、カードや
    /// ボタンが受け取るタッチを奪わない。
    func backSwipeProtectedRegion() -> some View {
        background(BackSwipeProtectedRegionMarker())
    }
}

struct BackSwipeProtectedRegionMarker: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = BackSwipeProtectedRegionView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

final class BackSwipeProtectedRegionView: UIView {}

/// 戻る操作は UIKit 標準の対話的 pop にそのまま任せる。iOS 26 以降はコンテンツ全体、
/// それ以前は画面端からのスワイプ。指への追従・しきい値・前画面の視差は UIKit が持つので、
/// ここでは「どこから始めたら戻さないか」だけを足す。
///
/// ナビゲーションバーを隠している画面は UIKit がこのジェスチャーを止めるため、
/// ヘッダーを持たない画面（学習・単語リストなど）はこれを敷いて戻す。
struct BackSwipeEnabler: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BackSwipeHostView {
        let view = BackSwipeHostView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.onWindowChange = { [weak coordinator = context.coordinator, weak view] in
            coordinator?.attach(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: BackSwipeHostView, context: Context) {
        context.coordinator.attach(from: uiView)
    }

    static func dismantleUIView(_ uiView: BackSwipeHostView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var hostView: BackSwipeHostView?
        private weak var gesture: UIGestureRecognizer?
        private weak var originalDelegate: UIGestureRecognizerDelegate?
        private var originalIsEnabled = true

        func attach(from view: BackSwipeHostView?) {
            guard let view,
                  let navigationController = view.owningNavigationController,
                  let target = navigationController.backSwipeGesture else { return }

            if let current = gesture, current !== target {
                restore(current)
            }
            if gesture !== target {
                gesture = target
                originalDelegate = target.delegate
                originalIsEnabled = target.isEnabled
            }
            hostView = view

            // 戻るボタンを隠している間 UIKit はこのジェスチャーを止めるので、明示的に戻す。
            target.isEnabled = true
            if target.delegate !== self {
                target.delegate = self
            }
        }

        func detach() {
            if let gesture {
                restore(gesture)
            }
            gesture = nil
            hostView = nil
        }

        private func restore(_ gesture: UIGestureRecognizer) {
            if gesture.delegate === self {
                gesture.delegate = originalDelegate
            }
            gesture.isEnabled = originalIsEnabled
            originalDelegate = nil
        }

        /// marker を敷いたところから始まったタッチだけ、標準の戻るへ渡さない。
        /// それ以外の判断はすべて UIKit 本来の delegate に戻す。
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let hostView, let window = hostView.window else { return false }
            let location = touch.location(in: window)
            let startsInProtectedRegion = window.backSwipeProtectedRegions.contains { marker in
                !marker.isHidden
                    && marker.alpha > 0.01
                    && marker.convert(marker.bounds, to: window).contains(location)
            }
            if startsInProtectedRegion { return false }
            return originalDelegate?.gestureRecognizer?(gestureRecognizer, shouldReceive: touch) ?? true
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            originalDelegate?.gestureRecognizerShouldBegin?(gestureRecognizer) ?? true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            originalDelegate?.gestureRecognizer?(
                gestureRecognizer,
                shouldRecognizeSimultaneouslyWith: otherGestureRecognizer
            ) ?? false
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            originalDelegate?.gestureRecognizer?(
                gestureRecognizer,
                shouldRequireFailureOf: otherGestureRecognizer
            ) ?? false
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            originalDelegate?.gestureRecognizer?(
                gestureRecognizer,
                shouldBeRequiredToFailBy: otherGestureRecognizer
            ) ?? false
        }
    }
}

final class BackSwipeHostView: UIView {
    var onWindowChange: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onWindowChange?()
    }
}

private extension UIView {
    var owningNavigationController: UINavigationController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let controller = current as? UIViewController {
                return controller.navigationController
            }
            responder = current.next
        }
        return nil
    }
}

private extension UINavigationController {
    /// iOS 26 はコンテンツ全体で戻れる recognizer を持つ。無い世代は従来の端スワイプ。
    ///
    /// CI の Xcode は iOS 26 SDK を持たない世代があり、シンボルを直に書くと
    /// `cannot find ... in scope` でビルドできない。宣言に依存しないよう
    /// セレクタで引き、応答しない実行環境では従来の端スワイプへ落ちる。
    var backSwipeGesture: UIGestureRecognizer? {
        let contentPopSelector = NSSelectorFromString("interactiveContentPopGestureRecognizer")
        if responds(to: contentPopSelector),
           let contentGesture = perform(contentPopSelector)?.takeUnretainedValue() as? UIGestureRecognizer {
            return contentGesture
        }
        return interactivePopGestureRecognizer
    }
}

private extension UIView {
    var backSwipeProtectedRegions: [BackSwipeProtectedRegionView] {
        subviews.reduce(into: []) { result, subview in
            if let marker = subview as? BackSwipeProtectedRegionView {
                result.append(marker)
            }
            result.append(contentsOf: subview.backSwipeProtectedRegions)
        }
    }
}
