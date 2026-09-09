#if canImport(UIKit)
import UIKit
import vBoardEngine

/// Bộ xử lý cử chỉ vuốt phím Backspace sang trái để xóa nhanh (Swipe-to-Delete)
@MainActor
public final class BackspaceSwipeHandler: NSObject, UIGestureRecognizerDelegate {
    private weak var proxy: TextDocumentProxyProtocol?
    private let wordStepDistance: CGFloat = 36.0 // Khoảng cách vuốt (pt) để chọn/xóa 1 từ

    public var onSwipeStateChange: ((Bool) -> Void)?

    private var wordsToChunk: [String] = []
    private var deletedChunks: [String] = []

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

    /// Tách chuỗi ngữ cảnh thành các khối từ lùi từ cuối về đầu
    private func parseWordChunks(from text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        var chunks: [String] = []
        var currentChunk = ""
        let chars = Array(text)
        var i = chars.count - 1

        while i >= 0 {
            currentChunk = ""
            // Gom các khoảng trắng / dấu câu ở cuối nếu có
            while i >= 0 && (chars[i].isWhitespace || chars[i].isPunctuation) {
                currentChunk.insert(chars[i], at: currentChunk.startIndex)
                i -= 1
            }
            // Gom phần chữ cái của từ
            while i >= 0 && !chars[i].isWhitespace && !chars[i].isPunctuation {
                currentChunk.insert(chars[i], at: currentChunk.startIndex)
                i -= 1
            }
            if !currentChunk.isEmpty {
                chunks.append(currentChunk)
            }
        }
        return chunks.reversed()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let proxy = proxy else { return }

        switch gesture.state {
        case .began:
            HapticManager.shared.prepare()
            onSwipeStateChange?(true)
            let context = proxy.documentContextBeforeInput ?? ""
            wordsToChunk = parseWordChunks(from: context)
            deletedChunks.removeAll()

        case .changed:
            let translationX = gesture.translation(in: gesture.view).x

            // Chỉ xử lý xóa khi vuốt sang trái (translationX < 0)
            let targetWordCount: Int
            if translationX < -15.0 {
                let distance = abs(translationX) - 15.0
                targetWordCount = min(wordsToChunk.count + deletedChunks.count, Int(distance / wordStepDistance) + 1)
            } else {
                targetWordCount = 0
            }

            // Nếu cần xóa thêm từ
            while deletedChunks.count < targetWordCount && !wordsToChunk.isEmpty {
                let chunk = wordsToChunk.removeLast()
                for _ in 0..<chunk.count {
                    proxy.deleteBackward()
                }
                deletedChunks.append(chunk)
                HapticManager.shared.playSpecialKey()
            }

            // Nếu trượt tay ngược lại về bên phải: Khôi phục lại từ đã xóa!
            while deletedChunks.count > targetWordCount && !deletedChunks.isEmpty {
                let restored = deletedChunks.removeLast()
                proxy.insertText(restored)
                wordsToChunk.append(restored)
                HapticManager.shared.playKeyTap()
            }

        case .ended:
            onSwipeStateChange?(false)
            wordsToChunk.removeAll()
            deletedChunks.removeAll()

        case .cancelled, .failed:
            // Khôi phục lại toàn bộ nếu cử chỉ bị hủy
            while !deletedChunks.isEmpty {
                let restored = deletedChunks.removeLast()
                proxy.insertText(restored)
            }
            onSwipeStateChange?(false)
            wordsToChunk.removeAll()

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
