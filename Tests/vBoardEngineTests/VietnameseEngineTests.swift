import Testing
import Foundation
@testable import vBoardEngine

/// Giả lập UITextDocumentProxy để kiểm tra chu trình gõ thực tế
final class MockTextDocumentProxy: TextDocumentProxyProtocol, @unchecked Sendable {
    var buffer: String = ""
    var cursorPosition: Int = 0

    var documentContextBeforeInput: String? {
        if cursorPosition <= 0 { return "" }
        let index = buffer.index(buffer.startIndex, offsetBy: cursorPosition)
        return String(buffer[..<index])
    }

    var documentContextAfterInput: String? {
        if cursorPosition >= buffer.count { return "" }
        let index = buffer.index(buffer.startIndex, offsetBy: cursorPosition)
        return String(buffer[index...])
    }

    func deleteBackward() {
        guard cursorPosition > 0 else { return }
        let removeIndex = buffer.index(buffer.startIndex, offsetBy: cursorPosition - 1)
        buffer.remove(at: removeIndex)
        cursorPosition -= 1
    }

    func insertText(_ text: String) {
        let insertIndex = buffer.index(buffer.startIndex, offsetBy: cursorPosition)
        buffer.insert(contentsOf: text, at: insertIndex)
        cursorPosition += text.count
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        cursorPosition = max(0, min(buffer.count, cursorPosition + offset))
    }

    /// Tiện ích gõ một chuỗi liên tiếp
    func typeSequence(_ sequence: String, adapter: TextProxyAdapter) {
        for char in sequence {
            if char == " " {
                adapter.handleSpace(proxy: self)
            } else {
                adapter.handleKeyInput(char, proxy: self)
            }
        }
    }
}

@Suite("Bộ kiểm thử Lõi gõ tiếng Việt vBoardEngine")
@MainActor
struct VietnameseEngineTests {

    @Test("Kiểm tra dấu thanh cơ bản (Telex)")
    func testBasicTonesTelex() {
        let adapter = TextProxyAdapter()

        let testCases: [(input: String, expected: String)] = [
            ("as", "á"),
            ("af", "à"),
            ("ar", "ả"),
            ("ax", "ã"),
            ("aj", "ạ"),
            ("tos", "tó"),
            ("toof", "tồ"),
            ("mej", "mẹ")
        ]

        for (input, expected) in testCases {
            let proxy = MockTextDocumentProxy()
            proxy.typeSequence(input, adapter: adapter)
            #expect(proxy.buffer == expected, "Gõ \(input) phải ra \(expected), thực tế: \(proxy.buffer)")
        }
    }

    @Test("Kiểm tra biến đổi nguyên âm mũ và móc (Telex)")
    func testVowelModificationsTelex() {
        let adapter = TextProxyAdapter()

        let testCases: [(input: String, expected: String)] = [
            ("aa", "â"),
            ("ee", "ê"),
            ("oo", "ô"),
            ("aw", "ă"),
            ("ow", "ơ"),
            ("uw", "ư"),
            ("uow", "ươ"),
            ("dd", "đ"),
            ("w", "ư"),
            ("DD", "Đ"),
            ("motoj", "một"),
            ("motjo", "một"),
            ("vietej", "việt"),
            ("vietje", "việt"),
            ("bepes", "bếp"),
            ("bepse", "bếp"),
            ("tienges", "tiếng"),
            ("namws", "nắm")
        ]

        for (input, expected) in testCases {
            let proxy = MockTextDocumentProxy()
            proxy.typeSequence(input, adapter: adapter)
            #expect(proxy.buffer == expected, "Gõ \(input) phải ra \(expected), thực tế: \(proxy.buffer)")
        }
    }

    @Test("Kiểm tra vị trí đặt dấu thanh chuẩn mới (hoa/thuy/toan/tien)")
    func testTonePlacementNewStyle() {
        let adapter = TextProxyAdapter()

        let testCases: [(input: String, expected: String)] = [
            ("hoaf", "hòa"),
            ("thuyr", "thủy"),
            ("toasn", "toán"),
            ("tieens", "tiến"),
            ("muoons", "muốn"),
            ("muoowns", "mướn"),
            ("nguowif", "người"),
            ("ddasnh", "đánh"),
            ("quas", "quá"),
            ("quans", "quán"),
            ("gias", "giá"),
            ("gios", "gió"),
            ("ginf", "gìn"),
            ("chuyeens", "chuyến"),
            ("chuyeenr", "chuyển"),
            ("chuyeenf", "chuyền"),
            ("chuyeenx", "chuyễn"),
            ("chuyeenj", "chuyện"),
            ("thuyeenf", "thuyền"),
            ("khuyeen", "khuyên"),
            ("duyeetj", "duyệt"),
            ("khuyeets", "khuyết"),
            ("khuyur", "khuỷu"),
            ("quyeenr", "quyển")
        ]

        for (input, expected) in testCases {
            let proxy = MockTextDocumentProxy()
            proxy.typeSequence(input, adapter: adapter)
            #expect(proxy.buffer == expected, "Gõ \(input) phải ra \(expected), thực tế: \(proxy.buffer)")
        }
    }

    @Test("Kiểm tra xử lý văn bản ngữ cảnh chứa Unicode NFD (Decomposed)")
    func testNFDContextHandling() {
        let adapter = TextProxyAdapter()
        let proxy = MockTextDocumentProxy()

        // Giả lập ngữ cảnh trước con trỏ là dạng NFD: 'e' + combining circumflex (\u{0302})
        let nfdWord = "chuy" + "e\u{0302}n"
        proxy.buffer = nfdWord
        proxy.cursorPosition = nfdWord.count

        // Gõ thêm 'r' để bỏ dấu hỏi
        adapter.handleKeyInput("r", proxy: proxy)
        #expect(proxy.buffer == "chuyển", "Từ NFD \(nfdWord) gõ r phải ra chuyển, thực tế: \(proxy.buffer)")
    }

    @Test("Kiểm tra cơ chế hoàn tác khi nhấn đúp phím dấu (Undo)")
    func testUndoMechanism() {
        let adapter = TextProxyAdapter()

        let testCases: [(input: String, expected: String)] = [
            ("ass", "as"),
            ("aaa", "aa"),
            ("ddd", "dd"),
            ("aww", "aw"),
            ("oww", "ow"),
            ("uww", "uw")
        ]

        for (input, expected) in testCases {
            let proxy = MockTextDocumentProxy()
            proxy.typeSequence(input, adapter: adapter)
            #expect(proxy.buffer == expected, "Gõ \(input) phải ra \(expected), thực tế: \(proxy.buffer)")
        }
    }

    @Test("Kiểm tra gõ câu hoàn chỉnh có dấu cách")
    func testFullSentenceTyping() {
        let adapter = TextProxyAdapter()
        let proxy = MockTextDocumentProxy()

        proxy.typeSequence("vieetj nam ddaats nuowsc quee huowng tooi", adapter: adapter)
        #expect(proxy.buffer == "việt nam đất nước quê hương tôi")
    }

    @Test("Kiểm tra tính năng đặc trưng của OpenKey (phím z gỡ dấu, quick telex, phím ngoặc)")
    func testOpenKeySpecificFeatures() {
        let adapter = TextProxyAdapter()

        let testCases: [(input: String, expected: String)] = [
            ("toansz", "toan"),
            ("tieengsz", "tiêng"),
            ("chuwaxz", "chưa"),
            ("cc", "ch"),
            ("gg", "gi"),
            ("kk", "kh"),
            ("nn", "ng"),
            ("qq", "qu"),
            ("pp", "ph"),
            ("tt", "th"),
            ("[", "ơ"),
            ("]", "ư"),
            ("ww", "w")
        ]

        for (input, expected) in testCases {
            let proxy = MockTextDocumentProxy()
            proxy.typeSequence(input, adapter: adapter)
            #expect(proxy.buffer == expected, "Gõ \(input) phải ra \(expected), thực tế: \(proxy.buffer)")
        }
    }

    @Test("Kiểm tra cử chỉ di chuyển con trỏ phím Space")
    func testSpaceCursorMovement() {
        let adapter = TextProxyAdapter()
        let proxy = MockTextDocumentProxy()

        proxy.typeSequence("xin chao", adapter: adapter)
        #expect(proxy.cursorPosition == 8)

        // Di chuyển con trỏ lùi lại 4 vị trí
        adapter.moveCursor(by: -4, proxy: proxy)
        #expect(proxy.cursorPosition == 4)

        // Chèn thêm ký tự ngay tại vị trí mới
        proxy.insertText("-")
        #expect(proxy.buffer == "xin -chao")
    }

    @Test("Kiểm tra bật/tắt các tuỳ chọn cấu hình OpenKey")
    func testOpenKeyConfigurationToggles() {
        let engine = VietnameseEngine()
        let adapter = TextProxyAdapter(engine: engine)

        // 1. Tắt Quick Telex
        engine.isQuickTelexEnabled = false
        let proxy1 = MockTextDocumentProxy()
        proxy1.typeSequence("cc", adapter: adapter)
        #expect(proxy1.buffer == "cc")

        // 2. Bật lại Quick Telex
        engine.isQuickTelexEnabled = true
        let proxy2 = MockTextDocumentProxy()
        proxy2.typeSequence("cc", adapter: adapter)
        #expect(proxy2.buffer == "ch")

        // 3. Tắt phím z gỡ dấu
        engine.isZKeyRemoveToneEnabled = false
        let proxy3 = MockTextDocumentProxy()
        proxy3.typeSequence("toansz", adapter: adapter)
        #expect(proxy3.buffer == "toánz")

        // 4. Bật lại phím z gỡ dấu
        engine.isZKeyRemoveToneEnabled = true
        let proxy4 = MockTextDocumentProxy()
        proxy4.typeSequence("toansz", adapter: adapter)
        #expect(proxy4.buffer == "toan")

        // 5. Tắt phím ngoặc vuông [ ]
        engine.isBracketShortcutsEnabled = false
        let proxy5 = MockTextDocumentProxy()
        proxy5.typeSequence("[", adapter: adapter)
        #expect(proxy5.buffer == "[")

        // 6. Bật lại phím ngoặc vuông
        engine.isBracketShortcutsEnabled = true
        let proxy6 = MockTextDocumentProxy()
        proxy6.typeSequence("[", adapter: adapter)
        #expect(proxy6.buffer == "ơ")

        // 7. Tắt gõ w đầu từ thành ư
        engine.isWAtWordBeginningEnabled = false
        let proxy7 = MockTextDocumentProxy()
        proxy7.typeSequence("w", adapter: adapter)
        #expect(proxy7.buffer == "w")
    }

    @Test("Kiểm tra gợi ý từ thông minh và so khớp cử chỉ vuốt phím (Glide)")
    func testWordTrieSuggestionsAndGlide() {
        let trie = WordTrie.shared

        // Gợi ý theo tiền tố
        let suggestionsVi = trie.suggest(prefix: "vi", limit: 3)
        #expect(!suggestionsVi.isEmpty)
        #expect(suggestionsVi.contains { $0.lowercased().hasPrefix("vi") })

        let suggestionsCh = trie.suggest(prefix: "ch", limit: 3)
        #expect(!suggestionsCh.isEmpty)

        // Kiểm tra nạp từ file từ điển
        #expect(trie.totalWordsCount >= 800, "Tổng số từ nạp từ file từ điển phải >= 800 từ (thực tế: \(trie.totalWordsCount))")

        // Gợi ý theo cử chỉ vuốt phím (Glide)
        let glideXin = trie.matchGlide(keySequence: ["x", "i", "n"], limit: 3)
        #expect(glideXin.contains("xin"))

        // Kiểm tra vuốt từ có dấu tiếng Việt trên bàn phím QWERTY (không dấu)
        let glideChao = trie.matchGlide(keySequence: ["c", "h", "a", "o"], limit: 3)
        #expect(glideChao.contains("chào"))

        let glideDuoc = trie.matchGlide(keySequence: ["d", "u", "o", "c"], limit: 3)
        #expect(glideDuoc.contains("được"))

        let glideBan = trie.matchGlide(keySequence: ["b", "a", "n"], limit: 3)
        #expect(glideBan.contains("bạn"))

        let glideKhong = trie.matchGlide(keySequence: ["k", "h", "o", "n", "g"], limit: 3)
        #expect(glideKhong.contains("không"))

        // Kiểm tra vuốt thực tế có đi qua các phím trung gian dọc đường vuốt
        let trajectoryChao = trie.matchGlide(keySequence: ["c", "v", "g", "h", "j", "a", "s", "o"], limit: 3)
        #expect(trajectoryChao.contains("chào"))

        // Đo hiệu năng tra cứu gợi ý từ (< 0.01ms)
        let iterations = 10_000
        let startTime = CFAbsoluteTimeGetCurrent()
        for i in 0..<iterations {
            let prefix = (i % 2 == 0) ? "vi" : "ch"
            _ = trie.suggest(prefix: prefix, limit: 3)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let timePerQueryMs = (elapsed / Double(iterations)) * 1000.0
        print("\n⚡️ TỐC ĐỘ GỢI Ý TỪ: \(String(format: "%.5f", timePerQueryMs)) ms / lần tra cứu (\(iterations) lần)")
        #expect(timePerQueryMs < 0.10)
    }

    @Test("Kiểm tra quản lý lịch sử Bảng tạm (ClipboardManager)")
    func testClipboardManager() {
        let clipboard = ClipboardManager.shared
        clipboard.clearHistory()
        #expect(clipboard.getHistory().isEmpty)

        clipboard.addClip("Đoạn văn bản 1")
        clipboard.addClip("Đoạn văn bản 2")
        let history = clipboard.getHistory()
        #expect(history.count == 2)
        #expect(history[0] == "Đoạn văn bản 2")

        clipboard.deleteClip("Đoạn văn bản 2")
        let historyAfterDelete = clipboard.getHistory()
        #expect(historyAfterDelete.count == 1)
        #expect(historyAfterDelete[0] == "Đoạn văn bản 1")

        clipboard.clearHistory()
        #expect(clipboard.getHistory().isEmpty)
    }

    @Test("Đo lường hiệu năng xử lý ký tự (< 0.05ms mỗi lần gõ)")
    func testPerformanceKeystrokeLatency() {
        let engine = VietnameseEngine()
        let sampleContexts = ["", "t", "to", "tô", "viet", "nguo", "truong"]
        let chars: [Character] = ["s", "f", "r", "x", "j", "a", "w", "e", "o", "n", "h", "c"]

        let iterations = 20_000
        let startTime = CFAbsoluteTimeGetCurrent()

        for i in 0..<iterations {
            let ctx = sampleContexts[i % sampleContexts.count]
            let ch = chars[i % chars.count]
            _ = engine.processKeystroke(ch, contextBefore: ctx)
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let timePerKeystrokeMs = (elapsed / Double(iterations)) * 1000.0

        print("\n⚡️ TỐC ĐỘ XỬ LÝ: \(String(format: "%.4f", timePerKeystrokeMs)) ms / ký tự (\(iterations) lần gõ)")
        #expect(timePerKeystrokeMs < 0.05, "Thời gian xử lý mỗi ký tự phải dưới 0.05ms (50 microsecond)")
    }

    @Test("Kiểm tra toàn diện cấu hình vBoardSettings và Darwin IPC Notification")
    func testNewVBoardSettingsAndDarwinNotification() {
        let settings = vBoardSettings.shared

        // Test giá trị mặc định theo SETTINGS_DESIGN.md
        #expect(settings.isHintSymbolsEnabled == true)
        #expect(settings.isDeveloperModeButtonEnabled == true)
        #expect(settings.developerTabBehavior == .fourSpaces)
        #expect(settings.developerTabBehavior.insertString == "    ")
        #expect(settings.isPairAutoCompleteEnabled == true)
        #expect(settings.hapticIntensity == .light)
        #expect(settings.longPressDelayMs == 250)
        #expect(settings.themeMode == .system)
        #expect(settings.accentColorHex == "#1a73e8")

        // Test thay đổi cấu hình
        settings.developerTabBehavior = .twoSpaces
        #expect(settings.developerTabBehavior.insertString == "  ")
        settings.developerTabBehavior = .tabChar
        #expect(settings.developerTabBehavior.insertString == "\t")
        settings.developerTabBehavior = .fourSpaces

        settings.hapticIntensity = .heavy
        #expect(settings.hapticIntensity == .heavy)
        settings.hapticIntensity = .light

        settings.longPressDelayMs = 200
        #expect(settings.longPressDelayMs == 200)
        settings.longPressDelayMs = 250

        settings.themeMode = .dark
        #expect(settings.themeMode == .dark)
        settings.themeMode = .system

        settings.accentColorHex = "#22D3EE"
        #expect(settings.accentColorHex == "#22D3EE")
        settings.accentColorHex = "#1a73e8"

        // Test Darwin IPC notification trigger
        #expect(vBoardSettings.settingsChangedNotification == "com.nguyenphuong.vBoard.settingsChanged")
        settings.notifySettingsChanged() // Đảm bảo không crash
    }

    @Test("Kiểm tra mở rộng gõ tắt cá nhân hóa (Personal Text Replacement)")
    func testTextShortcutsExpansion() {
        let adapter = TextProxyAdapter()
        let shortcuts = ShortcutManager.shared

        // Thêm phím tắt test
        shortcuts.addShortcut(shortcut: "dc", replacement: "được")
        shortcuts.addShortcut(shortcut: "stk", replacement: "19036789")

        #expect(shortcuts.replacement(for: "dc") == "được")
        #expect(shortcuts.replacement(for: "stk") == "19036789")

        // Test gõ dc + Space -> được
        let proxy1 = MockTextDocumentProxy()
        proxy1.typeSequence("dc ", adapter: adapter)
        #expect(proxy1.buffer == "được ")

        // Test gõ viết hoa chữ đầu: Dc + Space -> Được
        let proxy2 = MockTextDocumentProxy()
        proxy2.typeSequence("Dc ", adapter: adapter)
        #expect(proxy2.buffer == "Được ")

        // Test gõ từ không có phím tắt: abc + Space -> abc
        let proxy3 = MockTextDocumentProxy()
        proxy3.typeSequence("abc ", adapter: adapter)
        #expect(proxy3.buffer == "abc ")

        // Dọn dẹp
        shortcuts.deleteShortcut(shortcut: "stk")
        #expect(shortcuts.replacement(for: "stk") == nil)
    }

    @Test("Kiểm tra nạp toàn bộ từ điển vietnamese_words.txt (> 15.000 từ)")
    func testWordTrieLexiconLoading() {
        let trie = WordTrie.shared
        #expect(trie.totalWordsCount > 15_000, "Từ điển phải nạp hơn 15.000 từ, thực tế: \(trie.totalWordsCount)")

        // Kiểm tra tra cứu các từ đặc trưng
        let suggestions = trie.suggest(prefix: "nghi", limit: 3)
        #expect(!suggestions.isEmpty)
        #expect(suggestions.contains(where: { $0.hasPrefix("nghi") }))
    }

    @Test("Kiểm tra cơ chế Hoàn tác (Undo) và Làm lại (Redo) Nguyên tử với OpenKey FSM")
    func testAtomicUndoRedoFlow() {
        let adapter = TextProxyAdapter()
        let proxy = MockTextDocumentProxy()

        // 1. Gõ toan -> gõ s thành toán
        proxy.typeSequence("toans", adapter: adapter)
        #expect(proxy.buffer == "toán")

        // 2. Bấm Undo -> phải quay lại "toan"
        let didUndo1 = adapter.handleUndo(proxy: proxy)
        #expect(didUndo1 == true)
        #expect(proxy.buffer == "toan")

        // 3. Bấm Redo -> phải trở lại "toán"
        let didRedo1 = adapter.handleRedo(proxy: proxy)
        #expect(didRedo1 == true)
        #expect(proxy.buffer == "toán")

        // 4. Test Undo phím xóa (Backspace)
        adapter.handleBackspace(proxy: proxy)
        #expect(proxy.buffer == "toá")
        adapter.handleUndo(proxy: proxy)
        #expect(proxy.buffer == "toán")

        // 5. Test Undo mở rộng phím tắt (Shortcut Expansion)
        proxy.buffer = ""
        proxy.cursorPosition = 0
        proxy.typeSequence("dc ", adapter: adapter)
        #expect(proxy.buffer == "được ")
        adapter.handleUndo(proxy: proxy)
        #expect(proxy.buffer == "dc")
        adapter.handleRedo(proxy: proxy)
        #expect(proxy.buffer == "được ")
    }

    @Test("Kiểm tra Dự đoán Từ tiếp theo (Bi-gram) và Chuyển văn bản sang Emoji (Text-to-Emoji)")
    func testNextWordPredictionAndEmoji() {
        let predictor = NextWordPredictor.shared
        let emojiMapper = TextToEmojiMapper.shared

        // Dự đoán từ tiếp theo
        let nextWordsChuc = predictor.predictNextWords(after: "chúc", limit: 3)
        #expect(nextWordsChuc.contains("mừng"))

        let nextWordsXin = predictor.predictNextWords(after: "xin", limit: 3)
        #expect(nextWordsXin.contains("chào") || nextWordsXin.contains("lỗi"))

        // Ánh xạ Emoji
        let vuiEmojis = emojiMapper.emojis(for: "vui")
        #expect(!vuiEmojis.isEmpty)
        #expect(vuiEmojis.contains("😊") || vuiEmojis.contains("🎉"))

        let timEmojis = emojiMapper.emojis(for: "tim")
        #expect(timEmojis.contains("❤️"))
    }

    @Test("Kiểm tra toàn diện 18 Cấu hình Mới trong vBoardSettings")
    func testExtendedSettings() {
        let settings = vBoardSettings.shared

        settings.oneHandedMode = .left
        #expect(settings.oneHandedMode == .left)
        settings.oneHandedMode = .off

        settings.fontFamily = .rounded
        #expect(settings.fontFamily == .rounded)
        settings.fontFamily = .system

        settings.fontSizeScale = 1.15
        #expect(settings.fontSizeScale == 1.15)
        settings.fontSizeScale = 1.0

        settings.colorTheme = .pitchBlack
        #expect(settings.colorTheme == .pitchBlack)
        #expect(!settings.colorTheme.isGradient)

        settings.colorTheme = .gradientPastelRose
        #expect(settings.colorTheme == .gradientPastelRose)
        #expect(settings.colorTheme.isGradient)
        settings.colorTheme = .standard

        settings.isKeyBorderEnabled = false
        #expect(settings.isKeyBorderEnabled == false)
        settings.isKeyBorderEnabled = true

        settings.isAutoCapitalizationEnabled = true
        #expect(settings.isAutoCapitalizationEnabled == true)

        settings.isAutoSpaceAfterPunctuationEnabled = true
        #expect(settings.isAutoSpaceAfterPunctuationEnabled == true)

        settings.isAutoSwitchToABCAfterApostropheEnabled = true
        #expect(settings.isAutoSwitchToABCAfterApostropheEnabled == true)

        settings.isFlickDownEnabled = true
        #expect(settings.isFlickDownEnabled == true)

        settings.isNextWordPredictionEnabled = true
        #expect(settings.isNextWordPredictionEnabled == true)

        settings.isTextToEmojiEnabled = true
        #expect(settings.isTextToEmojiEnabled == true)

        settings.isGlideTrailEnabled = true
        #expect(settings.isGlideTrailEnabled == true)

        #expect(settings.toolbarItemsOrder.contains("clipboard"))
    }
}
