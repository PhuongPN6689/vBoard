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

/// Lớp điều phối giữa bàn phím và bộ gõ OpenKey
@MainActor
public final class TextProxyAdapter {
    public let adapter: OpenKeyEngineAdapter
    public var engine: OpenKeyEngine { adapter.engine }

    public init(adapter: OpenKeyEngineAdapter = OpenKeyEngineAdapter()) {
        self.adapter = adapter
    }

    public convenience init(engine: OpenKeyEngine) {
        self.init(adapter: OpenKeyEngineAdapter(engine: engine))
    }

    /// Trích xuất từ hiện tại từ ngữ cảnh trước con trỏ
    public func extractCurrentWord(from context: String) -> String {
        return adapter.extractCurrentWord(from: context)
    }

    /// Xử lý một phím gõ và tự động gửi lệnh tới proxy
    @discardableResult
    public func handleKeyInput(_ char: Character, proxy: TextDocumentProxyProtocol) -> EngineAction {
        let context = proxy.documentContextBeforeInput ?? ""
        let currentWord = adapter.extractCurrentWord(from: context)

        if context.isEmpty {
            adapter.reset()
        } else if !adapter.engine.isEmpty {
            let engineWord = adapter.engine.getCurrentWord()
            if !currentWord.hasPrefix(engineWord) && !engineWord.hasPrefix(currentWord) {
                adapter.reset()
                if !currentWord.isEmpty {
                    adapter.syncContextWord(currentWord)
                }
            }
        } else if !currentWord.isEmpty {
            adapter.syncContextWord(currentWord)
        }

        let action = adapter.processKeystroke(char, contextBefore: context)

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

        if let action = adapter.processBackspace() {
            if action.deleteCount > 0 {
                for _ in 0..<action.deleteCount {
                    proxy.deleteBackward()
                }
            }
            if !action.textToInsert.isEmpty {
                proxy.insertText(action.textToInsert)
            }
            let transaction = AtomicTransaction(
                kind: .typing(deletedString: String(context.suffix(action.deleteCount)), insertedString: action.textToInsert),
                contextBefore: context
            )
            ActionHistoryManager.shared.record(transaction)
            return
        }

        proxy.deleteBackward()

        let transaction = AtomicTransaction(
            kind: .backspace(deletedChar: deletedChar),
            contextBefore: context
        )
        ActionHistoryManager.shared.record(transaction)
    }

    /// Xử lý phím Space (kết hợp tự động thay thế gõ tắt cá nhân hóa và macro OpenKey)
    public func handleSpace(proxy: TextDocumentProxyProtocol) {
        let context = proxy.documentContextBeforeInput ?? ""
        if vBoardSettings.shared.isShortcutExpansionEnabled {
            let currentWord = adapter.extractCurrentWord(from: context)
            if !currentWord.isEmpty, let replacement = ShortcutManager.shared.replacement(for: currentWord) {
                // Xóa từ viết tắt và thay thế bằng từ mở rộng
                for _ in 0..<currentWord.count {
                    proxy.deleteBackward()
                }
                // Áp dụng quy tắc Auto Caps của OpenKey
                let finalReplacement: String
                if vBoardSettings.shared.isAutoCapsMacroEnabled {
                    let isAllUpper = currentWord.count > 1 && currentWord.allSatisfy { $0.isUppercase }
                    let isFirstUpper = currentWord.first?.isUppercase == true

                    if isAllUpper {
                        finalReplacement = replacement.uppercased()
                    } else if isFirstUpper {
                        finalReplacement = replacement.prefix(1).uppercased() + replacement.dropFirst()
                    } else {
                        finalReplacement = replacement
                    }
                } else {
                    finalReplacement = replacement
                }
                let inserted = finalReplacement + " "
                proxy.insertText(inserted)
                adapter.reset()

                let transaction = AtomicTransaction(
                    kind: .shortcutExpansion(originalShortcut: currentWord, expandedText: inserted),
                    contextBefore: context
                )
                ActionHistoryManager.shared.record(transaction)
                return
            }
        }

        let action = adapter.processKeystroke(" ", contextBefore: context)
        var deletedString = ""
        if action.deleteCount > 0 {
            deletedString = String(context.suffix(action.deleteCount))
            for _ in 0..<action.deleteCount {
                proxy.deleteBackward()
            }
        }
        proxy.insertText(action.textToInsert)

        let transaction = AtomicTransaction(
            kind: .typing(deletedString: deletedString, insertedString: action.textToInsert),
            contextBefore: context
        )
        ActionHistoryManager.shared.record(transaction)
    }

    /// Xử lý phím xuống dòng (Return / Enter)
    public func handleReturn(proxy: TextDocumentProxyProtocol) {
        let context = proxy.documentContextBeforeInput ?? ""
        _ = adapter.processKeystroke("\n", contextBefore: context)
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
        return ActionHistoryManager.shared.undo(proxy: proxy, adapter: adapter)
    }

    /// Làm lại (Redo)
    @discardableResult
    public func handleRedo(proxy: TextDocumentProxyProtocol) -> Bool {
        return ActionHistoryManager.shared.redo(proxy: proxy, adapter: adapter)
    }

    /// Di chuyển con trỏ (dùng cho cử chỉ vuốt phím Space)
    public func moveCursor(by offset: Int, proxy: TextDocumentProxyProtocol) {
        proxy.adjustTextPosition(byCharacterOffset: offset)
        adapter.reset()
    }
}
