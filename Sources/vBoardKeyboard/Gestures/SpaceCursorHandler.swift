#if canImport(UIKit)
import UIKit
import vBoardEngine

/// Bộ xử lý cử chỉ trượt ngón tay trên phím Space để di chuyển con trỏ (Spacebar Cursor Glide)
@MainActor
public final class SpaceCursorHandler: NSObject, UIGestureRecognizerDelegate {
    private weak var proxy: TextDocumentProxyProtocol?
    private var accumulatedTranslationX: CGFloat = 0
    private let stepDistance: CGFloat = 11.0 // Khoảng cách trượt (pt) để nhảy 1 ký tự

    public var onTrackpadStateChange: ((Bool) -> Void)?

    public init(proxy: TextDocumentProxyProtocol?) {
        self.proxy = proxy
        super.init()
    }

    public func updateProxy(_ proxy: TextDocumentProxyProtocol?) {
        self.proxy = proxy
    }

    /// Đăng ký cử chỉ Pan vào View phím Space
    public func attach(to spaceView: UIView) {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        spaceView.addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let proxy = proxy else { return }

        switch gesture.state {
        case .began:
            accumulatedTranslationX = 0
            HapticManager.shared.prepare()
            onTrackpadStateChange?(true)

        case .changed:
            let translation = gesture.translation(in: gesture.view)
            accumulatedTranslationX += translation.x
            // Đặt lại translation của gesture để nhận delta tiếp theo
            gesture.setTranslation(.zero, in: gesture.view)

            if abs(accumulatedTranslationX) >= stepDistance {
                let steps = Int(accumulatedTranslationX / stepDistance)
                if steps != 0 {
                    proxy.adjustTextPosition(byCharacterOffset: steps)
                    HapticManager.shared.playCursorTick()
                    accumulatedTranslationX -= CGFloat(steps) * stepDistance
                }
            }

        case .ended, .cancelled, .failed:
            accumulatedTranslationX = 0
            onTrackpadStateChange?(false)

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
