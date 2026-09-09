import Foundation

/// Giao thức trừu tượng đại diện cho UITextDocumentProxy của UIKit
/// Giúp code engine có thể test độc lập trên cả macOS lẫn iOS mà không phụ thuộc UIKit
@MainActor
public protocol TextDocumentProxyProtocol: AnyObject {
    var documentContextBeforeInput: String? { get }
    var documentContextAfterInput: String? { get }
    func deleteBackward()
    func insertText(_ text: String)
    func adjustTextPosition(byCharacterOffset offset: Int)
}

/// Lớp điều phối giữa bàn phím và bộ gõ vBoardEngine
@MainActor
public final class TextProxyAdapter {
    public let engine: VietnameseEngine

    public init(engine: VietnameseEngine = VietnameseEngine()) {
        self.engine = engine
    }

    /// Xử lý một phím gõ và tự động gửi lệnh tới proxy
    @discardableResult
    public func handleKeyInput(_ char: Character, proxy: TextDocumentProxyProtocol) -> EngineAction {
        let context = proxy.documentContextBeforeInput ?? ""
        let action = engine.processKeystroke(char, contextBefore: context)

        if action.deleteCount > 0 {
            for _ in 0..<action.deleteCount {
                proxy.deleteBackward()
            }
        }

        if !action.textToInsert.isEmpty {
            proxy.insertText(action.textToInsert)
        }

        return action
    }

    /// Xử lý phím xóa (Backspace)
    public func handleBackspace(proxy: TextDocumentProxyProtocol) {
        proxy.deleteBackward()
    }

    /// Xử lý phím Space
    public func handleSpace(proxy: TextDocumentProxyProtocol) {
        proxy.insertText(" ")
    }

    /// Xử lý phím xuống dòng (Return / Enter)
    public func handleReturn(proxy: TextDocumentProxyProtocol) {
        proxy.insertText("\n")
    }

    /// Di chuyển con trỏ (dùng cho cử chỉ vuốt phím Space)
    public func moveCursor(by offset: Int, proxy: TextDocumentProxyProtocol) {
        proxy.adjustTextPosition(byCharacterOffset: offset)
    }
}
