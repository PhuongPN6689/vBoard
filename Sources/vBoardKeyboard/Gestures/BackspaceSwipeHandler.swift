#if canImport(UIKit)
import UIKit
import vBoardEngine

/// Bộ xử lý cử chỉ vuốt phím Backspace sang trái để xóa nhanh (Swipe-to-Delete)
@MainActor
public final class BackspaceSwipeHandler: NSObject, UIGestureRecognizerDelegate {
    private weak var proxy: TextDocumentProxyProtocol?
    private var accumulatedTranslationX: CGFloat = 0
    private let stepDistance: CGFloat = 20.0 // Khoảng cách vuốt để xóa 1 từ/ký tự

    public var onSwipeStateChange: ((Bool) -> Void)?

    public init(proxy: TextDocumentProxyProtocol?) {
        self.proxy = proxy
        super.init()
    }

    public func updateProxy(_ proxy: TextDocumentProxyProtocol?) {
        self.proxy = proxy
    }

    public func attach(to deleteView: UIView) {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        deleteView.addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let proxy = proxy else { return }

        switch gesture.state {
        case .began:
            accumulatedTranslationX = 0
            HapticManager.shared.prepare()
            onSwipeStateChange?(true)

        case .changed:
            let translation = gesture.translation(in: gesture.view)
            accumulatedTranslationX += translation.x
            gesture.setTranslation(.zero, in: gesture.view)

            // Chỉ xử lý khi vuốt sang trái (translation.x < 0)
            if accumulatedTranslationX <= -stepDistance {
                let steps = Int(abs(accumulatedTranslationX) / stepDistance)
                for _ in 0..<steps {
                    proxy.deleteBackward()
                    HapticManager.shared.playSpecialKey()
                }
                accumulatedTranslationX += CGFloat(steps) * stepDistance
            }

        case .ended, .cancelled, .failed:
            accumulatedTranslationX = 0
            onSwipeStateChange?(false)

        default:
            break
        }
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return false
    }
}
#endif
