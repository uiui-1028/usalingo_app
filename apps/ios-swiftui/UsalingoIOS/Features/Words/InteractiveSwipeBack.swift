import SwiftUI
import UIKit

/// ナビゲーションバーを隠すと、端からのスワイプで戻る動きも一緒に止まる。
/// この画面は操作をすべて下のバーへ移してヘッダーを持たないので、
/// 標準の戻るスワイプだけをここで戻す。
///
/// 大きさゼロの UIViewController を背面に置き、その親の
/// UINavigationController のスワイプ判定を自前の delegate へ差し替える。
struct InteractiveSwipeBackEnabler: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackProbeController(coordinator: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    /// 一番下の画面では戻さない。ここを空の delegate にすると根元で落ちることがある。
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }

        /// 一覧の縦スクロールと取り合いにならないよう、同時認識はしない。
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            false
        }
    }

    private final class SwipeBackProbeController: UIViewController {
        private let coordinator: Coordinator

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(nibName: nil, bundle: nil)
            view.isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard let navigationController = findNavigationController() else { return }
            coordinator.navigationController = navigationController
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = coordinator
        }

        /// SwiftUI は画面ごとに子 UIViewController を挟むので、親をたどって探す。
        private func findNavigationController() -> UINavigationController? {
            if let navigationController { return navigationController }
            var current = parent
            while let candidate = current {
                if let navigationController = candidate as? UINavigationController {
                    return navigationController
                }
                if let navigationController = candidate.navigationController {
                    return navigationController
                }
                current = candidate.parent
            }
            return nil
        }
    }
}
