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

        var deletedString = ""
        if action.deleteCount > 0 {
            deletedString = String(context.suffix(action.deleteCount))
            for _ in 0..<action.deleteCount {
                proxy.deleteBackward()
            }
        }

        if !action.textToInsert.isEmpty {
            proxy.insertText(action.textToInsert)
        }

        // Ghi nhận giao dịch vào ngăn xếp Hoàn tác
        let transaction = AtomicTransaction(
            kind: .typing(deletedString: deletedString, insertedString: action.textToInsert),
            contextBefore: context
        )
        ActionHistoryManager.shared.record(transaction)

        return action
    }

    /// Xử lý phím xóa (Backspace)
    public func handleBackspace(proxy: TextDocumentProxyProtocol) {
        let context = proxy.documentContextBeforeInput ?? ""
        let deletedChar = context.last ?? " "
        proxy.deleteBackward()

        let transaction = AtomicTransaction(
            kind: .backspace(deletedChar: deletedChar),
            contextBefore: context
        )
        ActionHistoryManager.shared.record(transaction)
    }

    /// Xử lý phím Space (kết hợp tự động thay thế gõ tắt cá nhân hóa)
    public func handleSpace(proxy: TextDocumentProxyProtocol) {
        let context = proxy.documentContextBeforeInput ?? ""
        if vBoardSettings.shared.isShortcutExpansionEnabled {
            let currentWord = engine.extractCurrentWord(from: context)
            if !currentWord.isEmpty, let replacement = ShortcutManager.shared.replacement(for: currentWord) {
                // Xóa từ viết tắt và thay thế bằng từ mở rộng
                for _ in 0..<currentWord.count {
                    proxy.deleteBackward()
                }
                // Giữ nguyên định dạng chữ hoa đầu từ nếu có
                let finalReplacement: String
                if currentWord.first?.isUppercase == true {
                    finalReplacement = replacement.prefix(1).uppercased() + replacement.dropFirst()
                } else {
                    finalReplacement = replacement
                }
                let inserted = finalReplacement + " "
                proxy.insertText(inserted)

                let transaction = AtomicTransaction(
                    kind: .shortcutExpansion(originalShortcut: currentWord, expandedText: inserted),
                    contextBefore: context
                )
                ActionHistoryManager.shared.record(transaction)
                return
            }
        }
        proxy.insertText(" ")
        let transaction = AtomicTransaction(
            kind: .typing(deletedString: "", insertedString: " "),
            contextBefore: context
        )
        ActionHistoryManager.shared.record(transaction)
    }

    /// Xử lý phím xuống dòng (Return / Enter)
    public func handleReturn(proxy: TextDocumentProxyProtocol) {
        let context = proxy.documentContextBeforeInput ?? ""
        proxy.insertText("\n")
        let transaction = AtomicTransaction(
            kind: .typing(deletedString: "", insertedString: "\n"),
            contextBefore: context
        )
        ActionHistoryManager.shared.record(transaction)
    }

    /// Hoàn tác (Undo)
    @discardableResult
    public func handleUndo(proxy: TextDocumentProxyProtocol) -> Bool {
        return ActionHistoryManager.shared.undo(proxy: proxy, engine: engine)
    }

    /// Làm lại (Redo)
    @discardableResult
    public func handleRedo(proxy: TextDocumentProxyProtocol) -> Bool {
        return ActionHistoryManager.shared.redo(proxy: proxy, engine: engine)
    }

    /// Di chuyển con trỏ (dùng cho cử chỉ vuốt phím Space)
    public func moveCursor(by offset: Int, proxy: TextDocumentProxyProtocol) {
        proxy.adjustTextPosition(byCharacterOffset: offset)
    }
}
