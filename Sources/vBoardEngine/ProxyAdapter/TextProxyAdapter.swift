import Foundation

/// Giao thức trừu tượng đại diện cho UITextDocumentProxy của UIKit
/// Giúp code engine có thể test độc lập trên cả macOS lẫn iOS mà không phụ thuộc UIKit
@MainActor
public protocol TextDocumentProxyProtocol: AnyObject {
    var documentContextBeforeInput: String? { get }
    var documentContextAfterInput: String? { get }
    var isSecureTextEntry: Bool { get }
    var keyboardTypeRawValue: Int? { get }
    func deleteBackward()
    func insertText(_ text: String)
    func adjustTextPosition(byCharacterOffset offset: Int)
}

public extension TextDocumentProxyProtocol {
    var isSecureTextEntry: Bool { false }
    var keyboardTypeRawValue: Int? { nil }
}

/// Lớp điều phối giữa bàn phím và bộ gõ OpenKey
@MainActor
public final class TextProxyAdapter {
    public let adapter: OpenKeyEngineAdapter
    public var engine: OpenKeyEngine { adapter.engine }
    private var rawWord: String = ""

    public static let commonEnglishWords: Set<String> = [
        "test", "post", "google", "system", "server", "website", "pass", "user",
        "code", "apple", "facebook", "online", "game", "email", "free", "view",
        "admin", "domain", "reset", "click", "debug", "update", "image", "media",
        "group", "share", "start", "close", "video", "status", "login", "error",
        "setup", "audio", "device", "layout", "input", "action", "custom"
    ]

    public init(adapter: OpenKeyEngineAdapter = OpenKeyEngineAdapter()) {
        self.adapter = adapter
    }

    public convenience init(engine: OpenKeyEngine) {
        self.init(adapter: OpenKeyEngineAdapter(engine: engine))
    }

    public func reset() {
        adapter.reset()
        rawWord = ""
    }

    /// Trích xuất từ hiện tại từ ngữ cảnh trước con trỏ
    public func extractCurrentWord(from context: String) -> String {
        return adapter.extractCurrentWord(from: context)
    }

    /// Kiểm tra xem ngữ cảnh trước con trỏ có thuộc về URL, Email hoặc Web Address không
    public static func isUrlOrEmailContext(context: String) -> Bool {
        guard !context.isEmpty else { return false }
        var token = ""
        for ch in context.reversed() {
            if ch.isWhitespace || ch.isNewline {
                break
            }
            token.insert(ch, at: token.startIndex)
        }
        guard !token.isEmpty else { return false }
        let lower = token.lowercased()

        // 1. Tiền tố URL
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("ftp://") || lower.hasPrefix("www.") {
            return true
        }
        // 2. Chứa ký tự email '@'
        if token.contains("@") {
            return true
        }
        // 3. Chứa dấu gạch chéo '/' (đường dẫn web path)
        if token.contains("/") {
            return true
        }
        // 4. Chứa tên miền phổ biến
        let tlds = [".com", ".vn", ".net", ".org", ".io", ".edu", ".gov", ".co", ".app", ".dev", ".ai", ".me", ".info"]
        for tld in tlds {
            if lower.contains(tld) {
                return true
            }
        }
        return false
    }

    /// Kiểm tra xem trường nhập liệu hiện tại có yêu cầu bypass Telex không
    public static func shouldBypassForInputTraits(proxy: TextDocumentProxyProtocol) -> Bool {
        if proxy.isSecureTextEntry { return true }
        if let type = proxy.keyboardTypeRawValue {
            // UIKeyboardType: asciiCapable (1), URL (3), emailAddress (7), webSearch (10), asciiCapableNumberPad (11)
            if [1, 3, 7, 10, 11].contains(type) {
                return true
            }
        }
        return false
    }

    /// Xử lý một phím gõ và tự động gửi lệnh tới proxy
    @discardableResult
    public func handleKeyInput(_ char: Character, proxy: TextDocumentProxyProtocol) -> EngineAction {
        let context = proxy.documentContextBeforeInput ?? ""

        // 1. Tự động tắt bộ gõ (Auto-Bypass) cho URL, Email, WebSearch hoặc trường mật khẩu
        if Self.shouldBypassForInputTraits(proxy: proxy) || Self.isUrlOrEmailContext(context: context) {
            proxy.insertText(String(char))
            adapter.reset()
            rawWord = ""
            let transaction = AtomicTransaction(
                kind: .typing(deletedString: "", insertedString: String(char)),
                contextBefore: context
            )
            ActionHistoryManager.shared.record(transaction)
            return .insertOnly(String(char))
        }

        // 2. Nếu gõ các ký tự ngắt từ hoặc ký tự đặc biệt của URL/Email như '@', '/', '_'
        if char == "@" || char == "/" || char == ":" || char == "_" {
            let currentWord = adapter.extractCurrentWord(from: context)
            let lowerRaw = rawWord.lowercased()
            if !rawWord.isEmpty && currentWord != rawWord && (Self.commonEnglishWords.contains(lowerRaw) || (!currentWord.isEmpty && !WordTrie.shared.isValidVietnameseSyllable(currentWord))) {
                for _ in 0..<currentWord.count {
                    proxy.deleteBackward()
                }
                proxy.insertText(rawWord)
            }
            proxy.insertText(String(char))
            adapter.reset()
            rawWord = ""
            return .insertOnly(String(char))
        }

        let currentWord = adapter.extractCurrentWord(from: context)

        if context.isEmpty {
            adapter.reset()
            rawWord = ""
        } else if !adapter.engine.isEmpty {
            let engineWord = adapter.engine.getCurrentWord()
            if !currentWord.hasPrefix(engineWord) && !engineWord.hasPrefix(currentWord) {
                adapter.reset()
                rawWord = currentWord
                if !currentWord.isEmpty {
                    adapter.syncContextWord(currentWord)
                }
            }
        } else if !currentWord.isEmpty {
            if rawWord.isEmpty {
                rawWord = currentWord
            }
            adapter.syncContextWord(currentWord)
        }

        if char.isLetter {
            rawWord.append(char)
        } else {
            rawWord = ""
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

        // 3. Khôi phục từ tiếng Anh thông dụng hoặc khi từ bị gõ sai ngữ âm tiếng Việt
        let updatedContext = proxy.documentContextBeforeInput ?? ""
        let currentWordInProxy = adapter.extractCurrentWord(from: updatedContext)
        let lowerRaw = rawWord.lowercased()

        let isEnglishMatch = Self.commonEnglishWords.contains(lowerRaw)

        if isEnglishMatch && currentWordInProxy != rawWord && !currentWordInProxy.isEmpty {
            let delCount = currentWordInProxy.count
            for _ in 0..<delCount {
                proxy.deleteBackward()
            }
            proxy.insertText(rawWord)
            adapter.reset()

            let transaction = AtomicTransaction(
                kind: .typing(deletedString: currentWordInProxy, insertedString: rawWord),
                contextBefore: context
            )
            ActionHistoryManager.shared.record(transaction)
            return EngineAction(deleteCount: delCount, textToInsert: rawWord)
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
        if !rawWord.isEmpty {
            rawWord.removeLast()
        }
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
        let currentWord = adapter.extractCurrentWord(from: context)

        // Tự động khôi phục từ tiếng Anh hoặc từ không hợp lệ tiếng Việt khi gõ phím cách
        let lowerRaw = rawWord.lowercased()
        if !rawWord.isEmpty && currentWord != rawWord && !currentWord.isEmpty {
            if Self.commonEnglishWords.contains(lowerRaw) || !WordTrie.shared.isValidVietnameseSyllable(currentWord) {
                for _ in 0..<currentWord.count {
                    proxy.deleteBackward()
                }
                proxy.insertText(rawWord)
                adapter.reset()
            }
        }
        rawWord = ""

        if vBoardSettings.shared.isShortcutExpansionEnabled {
            let cur = adapter.extractCurrentWord(from: proxy.documentContextBeforeInput ?? "")
            if !cur.isEmpty, let replacement = ShortcutManager.shared.replacement(for: cur) {
                // Xóa từ viết tắt và thay thế bằng từ mở rộng
                for _ in 0..<cur.count {
                    proxy.deleteBackward()
                }
                // Áp dụng quy tắc Auto Caps của OpenKey
                let finalReplacement: String
                if vBoardSettings.shared.isAutoCapsMacroEnabled {
                    let isAllUpper = cur.count > 1 && cur.allSatisfy { $0.isUppercase }
                    let isFirstUpper = cur.first?.isUppercase == true

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
                    kind: .shortcutExpansion(originalShortcut: cur, expandedText: inserted),
                    contextBefore: context
                )
                ActionHistoryManager.shared.record(transaction)
                return
            }
        }

        let action = adapter.processKeystroke(" ", contextBefore: proxy.documentContextBeforeInput ?? "")
        var deletedString = ""
        if action.deleteCount > 0 {
            let ctx = proxy.documentContextBeforeInput ?? ""
            deletedString = String(ctx.suffix(action.deleteCount))
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
        rawWord = ""
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
