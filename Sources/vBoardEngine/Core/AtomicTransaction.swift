import Foundation

/// Cấu trúc đại diện cho một giao dịch nhập liệu nguyên tử (Atomic Transaction)
public struct AtomicTransaction: Sendable {
    public enum TransactionKind: Sendable {
        /// Gõ phím tiếng Việt (kể cả phím tạo dấu gây ra xóa/chèn của OpenKey)
        case typing(deletedString: String, insertedString: String)
        /// Mở rộng từ viết tắt (Shortcuts: dc -> được)
        case shortcutExpansion(originalShortcut: String, expandedText: String)
        /// Xóa từ bằng cử chỉ vuốt (Swipe-to-delete)
        case swipeDelete(deletedText: String)
        /// Dán từ bảng tạm (Clipboard paste)
        case paste(pastedText: String)
        /// Phím xóa lùi thông thường (Single Backspace)
        case backspace(deletedChar: Character)
    }

    public let kind: TransactionKind
    public let contextBefore: String
    public let timestamp: TimeInterval

    public init(kind: TransactionKind, contextBefore: String, timestamp: TimeInterval = Date().timeIntervalSince1970) {
        self.kind = kind
        self.contextBefore = contextBefore
        self.timestamp = timestamp
    }
}

/// Trình quản lý ngăn xếp Hoàn tác (Undo) và Làm lại (Redo) tương thích 100% với OpenKey FSM
@MainActor
public final class ActionHistoryManager {
    public static let shared = ActionHistoryManager()

    private var undoStack: [AtomicTransaction] = []
    private var redoStack: [AtomicTransaction] = []
    private let maxDepth: Int = 30

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public var onHistoryStateChanged: (() -> Void)?

    private init() {}

    /// Ghi nhận một giao dịch mới vào ngăn xếp Hoàn tác
    public func record(_ transaction: AtomicTransaction) {
        undoStack.append(transaction)
        if undoStack.count > maxDepth {
            undoStack.removeFirst()
        }
        // Bất kỳ thao tác gõ mới nào cũng xóa sạch redo stack
        redoStack.removeAll()
        onHistoryStateChanged?()
    }

    /// Thực hiện Hoàn tác (Undo)
    @discardableResult
    public func undo(proxy: TextDocumentProxyProtocol, engine: VietnameseEngine) -> Bool {
        guard let transaction = undoStack.popLast() else { return false }

        // Thực thi nghịch đảo (Reverse Mutation)
        switch transaction.kind {
        case .typing(let deletedString, let insertedString):
            for _ in 0..<insertedString.count {
                proxy.deleteBackward()
            }
            if !deletedString.isEmpty {
                proxy.insertText(deletedString)
            }

        case .shortcutExpansion(let originalShortcut, let expandedText):
            for _ in 0..<expandedText.count {
                proxy.deleteBackward()
            }
            proxy.insertText(originalShortcut)

        case .swipeDelete(let deletedText):
            proxy.insertText(deletedText)

        case .paste(let pastedText):
            for _ in 0..<pastedText.count {
                proxy.deleteBackward()
            }

        case .backspace(let deletedChar):
            proxy.insertText(String(deletedChar))
        }

        // Đồng bộ hóa trạng thái OpenKey FSM
        engine.reset()

        // Đẩy sang Redo stack
        redoStack.append(transaction)
        if redoStack.count > maxDepth {
            redoStack.removeFirst()
        }

        onHistoryStateChanged?()
        return true
    }

    /// Thực hiện Làm lại (Redo)
    @discardableResult
    public func redo(proxy: TextDocumentProxyProtocol, engine: VietnameseEngine) -> Bool {
        guard let transaction = redoStack.popLast() else { return false }

        // Thực thi áp dụng lại (Forward Mutation)
        switch transaction.kind {
        case .typing(let deletedString, let insertedString):
            for _ in 0..<deletedString.count {
                proxy.deleteBackward()
            }
            if !insertedString.isEmpty {
                proxy.insertText(insertedString)
            }

        case .shortcutExpansion(let originalShortcut, let expandedText):
            for _ in 0..<originalShortcut.count {
                proxy.deleteBackward()
            }
            proxy.insertText(expandedText)

        case .swipeDelete(let deletedText):
            for _ in 0..<deletedText.count {
                proxy.deleteBackward()
            }

        case .paste(let pastedText):
            proxy.insertText(pastedText)

        case .backspace:
            proxy.deleteBackward()
        }

        // Đồng bộ hóa trạng thái OpenKey FSM
        engine.reset()

        // Đẩy trở lại Undo stack
        undoStack.append(transaction)
        if undoStack.count > maxDepth {
            undoStack.removeFirst()
        }

        onHistoryStateChanged?()
        return true
    }

    /// Xóa toàn bộ lịch sử thao tác
    public func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        onHistoryStateChanged?()
    }
}
