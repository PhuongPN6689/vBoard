#if canImport(UIKit)
import UIKit
import vBoardEngine
#if canImport(AudioToolbox)
import AudioToolbox
#endif

/// Wrapper chuyển đổi UITextDocumentProxy của Apple sang TextDocumentProxyProtocol của vBoard
@MainActor
final class NativeTextProxyWrapper: TextDocumentProxyProtocol {
    private weak var proxy: UITextDocumentProxy?

    init(proxy: UITextDocumentProxy?) {
        self.proxy = proxy
    }

    var documentContextBeforeInput: String? {
        return proxy?.documentContextBeforeInput
    }

    var documentContextAfterInput: String? {
        return proxy?.documentContextAfterInput
    }

    var isSecureTextEntry: Bool {
        return proxy?.isSecureTextEntry ?? false
    }

    var keyboardTypeRawValue: Int? {
        if let type = proxy?.keyboardType {
            return Int(type.rawValue)
        }
        return nil
    }

    func deleteBackward() {
        proxy?.deleteBackward()
    }

    func insertText(_ text: String) {
        proxy?.insertText(text)
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        proxy?.adjustTextPosition(byCharacterOffset: offset)
    }
}

/// Controller chính của Bàn phím iOS vBoard (UIInputViewController)
@MainActor
open class KeyboardViewController: UIInputViewController, KeyboardViewDelegate, SuggestionBarViewDelegate, QuickSettingsViewDelegate, ClipboardViewDelegate, EmojiPickerViewDelegate {
    public private(set) var keyboardView: KeyboardView!
    public private(set) var adapter: TextProxyAdapter!
    private var proxyWrapper: NativeTextProxyWrapper!

    private var heightConstraint: NSLayoutConstraint?
    /// Quản lý trạng thái từ vừa vuốt (Composing State)
    private var isGlidedComposing: Bool = false
    private var glidedWord: String? = nil
    private var glidedPrefixSpaceCount: Int = 0
    private var lastRecordedWord: String?
    private var secondLastRecordedWord: String?

    open override func viewDidLoad() {
        super.viewDidLoad()

        // Khởi tạo Engine và Adapter OpenKey
        let openKeyAdapter = OpenKeyEngineAdapter()
        adapter = TextProxyAdapter(adapter: openKeyAdapter)
        proxyWrapper = NativeTextProxyWrapper(proxy: textDocumentProxy)

        // Khởi tạo KeyboardView
        keyboardView = KeyboardView(frame: .zero)
        keyboardView.delegate = self
        keyboardView.suggestionBar.delegate = self
        keyboardView.configureGestures(proxy: proxyWrapper)
        keyboardView.customBottomPadding = computedRealBottomPadding()
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)

        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Chuẩn bị Haptics
        HapticManager.shared.prepare()
        ActionHistoryManager.shared.onHistoryStateChanged = { [weak self] in
            self?.keyboardView.suggestionBar.updateHistoryButtons()
        }

        // Lắng nghe tín hiệu Darwin IPC từ Host App Settings (< 0.1ms)
        setupDarwinNotificationListener()
    }

    deinit {
        #if canImport(CoreFoundation)
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveEveryObserver(center, observer)
        #endif
    }

    private var lastSpaceTapTime: TimeInterval = 0

    private func setupDarwinNotificationListener() {
        #if canImport(CoreFoundation)
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        let name = CFNotificationName(vBoardSettings.settingsChangedNotification as CFString)
        CFNotificationCenterAddObserver(
            center,
            observer,
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let vc = Unmanaged<KeyboardViewController>.fromOpaque(observer).takeUnretainedValue()
                Task { @MainActor in
                    vc.applyLatestSettings()
                }
            },
            name.rawValue,
            nil,
            .deliverImmediately
        )
        #endif
    }

    public func applyLatestSettings() {
        let settings = vBoardSettings.shared
        switch settings.inputMethod {
        case .telex:
            adapter.engine.vInputType = .telex
        case .vni:
            adapter.engine.vInputType = .vni
        case .simpleTelex:
            adapter.engine.vInputType = .simpleTelex1
        }
        adapter.engine.vUseModernOrthography = (settings.diacriticStyle == .newStyle) ? 1 : 0
        adapter.engine.vQuickTelex = settings.isQuickTelexEnabled ? 1 : 0
        adapter.engine.vQuickStartConsonant = settings.isQuickStartConsonantEnabled ? 1 : 0
        adapter.engine.vQuickEndConsonant = settings.isQuickEndConsonantEnabled ? 1 : 0
        adapter.engine.vCheckSpelling = settings.isSpellingCheckEnabled ? 1 : 0
        adapter.engine.vRestoreIfWrongSpelling = settings.isRestoreIfWrongSpellingEnabled ? 1 : 0
        adapter.engine.vAllowConsonantZFWJ = settings.isAllowConsonantZFWJEnabled ? 1 : 0
        adapter.engine.vUseMacro = settings.isShortcutExpansionEnabled ? 1 : 0
        adapter.engine.vAutoCapsMacro = settings.isAutoCapsMacroEnabled ? 1 : 0
        adapter.engine.vFixRecommendBrowser = settings.isFixBrowserSuggestionEnabled ? 1 : 0
        adapter.engine.isBracketShortcutsEnabled = settings.isBracketShortcutsEnabled
        adapter.engine.isZKeyRemoveToneEnabled = settings.isZKeyRemoveToneEnabled
        adapter.engine.isWAtWordBeginningEnabled = settings.isWAtWordBeginningEnabled
        adapter.engine.isAutoUndoEnabled = settings.isAutoUndoEnabled
        adapter.engine.isModernToneBalancingEnabled = settings.isModernToneBalancingEnabled

        let isSecure = textDocumentProxy.isSecureTextEntry ?? false
        let isPassword = (textDocumentProxy.textContentType == .password || textDocumentProxy.textContentType == .newPassword)
        let isNumberRowActive = settings.isNumberRowEnabled || (settings.isNumberRowForPasswordEnabled && (isSecure || isPassword))
        keyboardView.isNumberRowActive = isNumberRowActive

        keyboardView.currentReturnKeyType = textDocumentProxy.returnKeyType ?? .default
        keyboardView.refreshLayout()

        let scale = settings.keyboardHeightScale
        let isPad = traitCollection.userInterfaceIdiom == .pad
        let baseHeight: CGFloat = isPad ? scale.padHeight : scale.phoneHeight

        var calculatedHeight: CGFloat = baseHeight
        if isNumberRowActive && !keyboardView.isNumberPadActive {
            calculatedHeight += 28.0
        }
        if settings.isSuggestionBarEnabled && !keyboardView.isNumberPadActive {
            calculatedHeight += 42.0
        }

        // Bổ sung khoảng đệm an toàn mép dưới (Home Indicator) và độ nâng tùy chỉnh
        let totalBottomPadding = computedRealBottomPadding()
        calculatedHeight += totalBottomPadding
        keyboardView.customBottomPadding = totalBottomPadding

        if heightConstraint == nil {
            heightConstraint = view.heightAnchor.constraint(equalToConstant: calculatedHeight)
            heightConstraint?.priority = UILayoutPriority(999)
            heightConstraint?.isActive = true
        } else {
            heightConstraint?.constant = calculatedHeight
        }

        keyboardView.suggestionBar.updatePasteButtonIcon()

        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        proxyWrapper = NativeTextProxyWrapper(proxy: textDocumentProxy)
        keyboardView.configureGestures(proxy: proxyWrapper)

        applyLatestSettings()

        let settings = vBoardSettings.shared
        // Tự động nhận diện loại bàn phím số
        let type = textDocumentProxy.keyboardType
        if settings.isAutoNumberPadEnabled && (type == .numberPad || type == .phonePad || type == .decimalPad) {
            keyboardView.setNumberPadMode(true)
        } else if type == .numbersAndPunctuation {
            keyboardView.setNumbersMode()
        }

        // Hiển thị Smart Quick Chip từ lịch sử Bảng tạm nội bộ (không tự ý đọc UIPasteboard khi mở bàn phím - tuân thủ Guideline 5.1.1)
        if settings.isClipboardEnabled, let lastClip = ClipboardManager.shared.getHistory().first {
            let trimmed = lastClip.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                keyboardView.suggestionBar.smartClipText = trimmed
            }
        }

        updateWordSuggestions()
    }

    open override func textDidChange(_ textInput: (any UITextInput)?) {
        super.textDidChange(textInput)
        keyboardView.currentReturnKeyType = textDocumentProxy.returnKeyType ?? .default

        let settings = vBoardSettings.shared
        let type = textDocumentProxy.keyboardType
        if settings.isAutoNumberPadEnabled && (type == .numberPad || type == .phonePad || type == .decimalPad) {
            if !keyboardView.isNumberPadActive {
                keyboardView.setNumberPadMode(true)
            }
        }
        updateWordSuggestions()
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Đồng bộ lại heightConstraint khi safeAreaInsets.bottom được hệ thống cập nhật
        let settings = vBoardSettings.shared
        let isPad = traitCollection.userInterfaceIdiom == .pad
        let isSecure = textDocumentProxy.isSecureTextEntry ?? false
        let isPassword = (textDocumentProxy.textContentType == .password || textDocumentProxy.textContentType == .newPassword)
        let isNumberRowActive = settings.isNumberRowEnabled || (settings.isNumberRowForPasswordEnabled && (isSecure || isPassword))
        let totalBottomPadding = computedRealBottomPadding()
        keyboardView.customBottomPadding = totalBottomPadding

        let scale = settings.keyboardHeightScale
        let baseHeight: CGFloat = isPad ? scale.padHeight : scale.phoneHeight
        var newHeight: CGFloat = baseHeight
        if isNumberRowActive && !keyboardView.isNumberPadActive {
            newHeight += 28.0
        }
        if settings.isSuggestionBarEnabled && !keyboardView.isNumberPadActive {
            newHeight += 42.0
        }
        newHeight += totalBottomPadding

        if heightConstraint?.constant != newHeight {
            heightConstraint?.constant = newHeight
        }
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    /// Khoảng đệm mép dưới của bàn phím THẬT: theo safe area (Home Indicator),
    /// cộng thêm độ nâng tùy chọn người dùng đặt trong Settings.
    private func computedRealBottomPadding() -> CGFloat {
        let settings = vBoardSettings.shared
        let bottomSafeInset = view.safeAreaInsets.bottom
        let base: CGFloat = bottomSafeInset > 0 ? max(bottomSafeInset - 6.0, 4.0) : 4.0
        return max(4.0, base + CGFloat(settings.keyboardBottomOffset))
    }

    private func updateWordSuggestions() {
        guard vBoardSettings.shared.isSuggestionBarEnabled, !keyboardView.isNumberPadActive else { return }
        let currentWord = adapter.extractCurrentWord(from: proxyWrapper.documentContextBeforeInput ?? "")
        if currentWord.isEmpty {
            var predictions: [String] = []
            let rawBefore = proxyWrapper.documentContextBeforeInput ?? ""
            let trimmed = rawBefore.trimmingCharacters(in: .whitespaces)

            // Kiểm tra gợi ý mở đầu câu sau dấu ngắt câu ('.', '!', '?') hoặc khi bắt đầu câu mới
            let isSentenceStart = trimmed.isEmpty || trimmed.hasSuffix(".") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?")
            if isSentenceStart {
                if vBoardSettings.shared.isNextWordPredictionEnabled {
                    predictions.append(contentsOf: NextWordPredictor.shared.predictSentenceStarters(limit: 3))
                }
            } else {
                let tokens = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                let lastWord = tokens.last.map { adapter.extractCurrentWord(from: $0) } ?? ""
                let secondLastWord = tokens.count >= 2 ? adapter.extractCurrentWord(from: tokens[tokens.count - 2]) : nil

                if !lastWord.isEmpty {
                    if vBoardSettings.shared.isNextWordPredictionEnabled {
                        predictions.append(contentsOf: NextWordPredictor.shared.predictNextWords(previousWord: lastWord, previousPreviousWord: secondLastWord, limit: 3))
                    }
                    if vBoardSettings.shared.isTextToEmojiEnabled {
                        predictions.append(contentsOf: TextToEmojiMapper.shared.emojis(for: lastWord))
                    }
                }
            }

            if !predictions.isEmpty {
                let formatted = predictions.map { keyboardView.formatSuggestionText($0) }
                keyboardView.suggestionBar.setSuggestions(Array(formatted.prefix(3)))
            } else {
                keyboardView.suggestionBar.setSuggestions([])
            }
        } else {
            let lowWord = currentWord.lowercased()
            let isKnownWord = WordTrie.shared.containsExactWord(lowWord) && !UserAdaptiveLearningStore.shared.isBlacklisted(lowWord)
            let newWordToSave: String? = (!isKnownWord && currentWord.count >= 2) ? currentWord : nil

            var suggestions = WordTrie.shared.suggest(prefix: currentWord, limit: 3)
            if vBoardSettings.shared.isTextToEmojiEnabled {
                let emojis = TextToEmojiMapper.shared.emojis(for: currentWord)
                if !emojis.isEmpty {
                    // Nếu có emoji phù hợp với từ khóa đang gõ (ví dụ 'tim' -> ❤️), đưa emoji vào vị trí thứ 3 để chọn nhanh
                    if suggestions.count >= 2 {
                        suggestions = [suggestions[0], suggestions[1], emojis[0]]
                    } else {
                        suggestions.append(emojis[0])
                    }
                }
            }
            let formatted = suggestions.map { keyboardView.formatSuggestionText($0) }
            keyboardView.suggestionBar.setSuggestions(formatted, newWordToSave: newWordToSave)
        }
    }

    // MARK: - KeyboardViewDelegate

    public func keyboardView(_ keyboardView: KeyboardView, didPressKey key: KeyboardKey) {
        keyboardView.hideClipboardView()

        switch key.type {
        case .character(let charStr):
            SoundManager.shared.playKeyClick()

            if charStr == "←" || (keyboardView.isSymbolsLayerActive && charStr == "<") {
                proxyWrapper.adjustTextPosition(byCharacterOffset: -1)
            } else if charStr == "→" || (keyboardView.isSymbolsLayerActive && charStr == ">") {
                proxyWrapper.adjustTextPosition(byCharacterOffset: 1)
            } else if charStr == "⇤" {
                let before = proxyWrapper.documentContextBeforeInput ?? ""
                if let lastNewline = before.lastIndex(of: "\n") {
                    let offset = before.distance(from: before.index(after: lastNewline), to: before.endIndex)
                    proxyWrapper.adjustTextPosition(byCharacterOffset: -offset)
                } else {
                    proxyWrapper.adjustTextPosition(byCharacterOffset: -before.count)
                }
            } else if charStr == "⇥" {
                let after = proxyWrapper.documentContextAfterInput ?? ""
                if let nextNewline = after.firstIndex(of: "\n") {
                    let offset = after.distance(from: after.startIndex, to: nextNewline)
                    proxyWrapper.adjustTextPosition(byCharacterOffset: offset)
                } else {
                    proxyWrapper.adjustTextPosition(byCharacterOffset: after.count)
                }
            } else if keyboardView.isDeveloperModeActive {
                if charStr == "Tab" {
                    let tabStr = vBoardSettings.shared.developerTabBehavior.insertString
                    proxyWrapper.insertText(tabStr)
                } else if vBoardSettings.shared.isPairAutoCompleteEnabled, let pair = pairForChar(charStr) {
                    proxyWrapper.insertText(pair)
                    proxyWrapper.adjustTextPosition(byCharacterOffset: -1)
                } else {
                    proxyWrapper.insertText(charStr)
                }
            } else {
                // Kiểm tra trạng thái từ vừa vuốt (Composing State)
                if isGlidedComposing, let base = glidedWord, charStr.count == 1, let ch = charStr.first {
                    let isPunctuation = [".", ",", "!", "?", ":", ";", ")", "]", "}", "-", "...", "/"].contains(charStr)
                    if isPunctuation {
                        // Gõ dấu câu ngay sau từ vừa vuốt -> Chốt từ vừa vuốt mà KHÔNG chèn dấu cách thừa
                        UserAdaptiveLearningStore.shared.recordWordInput(base, previousWord: lastRecordedWord, previousPreviousWord: secondLastRecordedWord)
                        if lastRecordedWord == nil || [".", "!", "?"].contains(lastRecordedWord) {
                            UserAdaptiveLearningStore.shared.recordSentenceStartWord(base)
                        }
                        secondLastRecordedWord = lastRecordedWord
                        lastRecordedWord = base
                        isGlidedComposing = false
                        glidedWord = nil
                        glidedPrefixSpaceCount = 0
                        adapter.adapter.reset()
                    } else {
                        let (isValid, combinedWord) = combineGlidedWord(base, with: ch)
                        if isValid {
                            // Ký tự gõ khiến từ hiện tại vẫn là tiếng Việt hợp lệ (thêm dấu thanh, nguyên âm đôi, âm cuối)
                            for _ in 0..<base.count {
                                proxyWrapper.deleteBackward()
                            }
                            proxyWrapper.insertText(combinedWord)
                            isGlidedComposing = false
                            glidedWord = nil
                            glidedPrefixSpaceCount = 0
                            adapter.adapter.reset()
                            adapter.adapter.syncContextWord(combinedWord)
                            updateWordSuggestions()
                            return
                        } else {
                            // Ký tự gõ không thể ghép vào từ tiếng Việt hợp lệ -> Tự động chèn dấu cách và chốt từ cũ
                            proxyWrapper.insertText(" ")
                            UserAdaptiveLearningStore.shared.recordWordInput(base, previousWord: lastRecordedWord, previousPreviousWord: secondLastRecordedWord)
                            if lastRecordedWord == nil || [".", "!", "?"].contains(lastRecordedWord) {
                                UserAdaptiveLearningStore.shared.recordSentenceStartWord(base)
                            }
                            secondLastRecordedWord = lastRecordedWord
                            lastRecordedWord = base
                            isGlidedComposing = false
                            glidedWord = nil
                            glidedPrefixSpaceCount = 0
                            adapter.adapter.reset()
                        }
                    }
                } else {
                    isGlidedComposing = false
                    glidedWord = nil
                    glidedPrefixSpaceCount = 0
                }

                // Tự động thêm dấu cách sau dấu câu nếu gõ chữ cái liền kề
                if vBoardSettings.shared.isAutoSpaceAfterPunctuationEnabled {
                    let before = proxyWrapper.documentContextBeforeInput ?? ""
                    if let last = before.last, (last == "," || last == "." || last == "!" || last == "?" || last == ":" || last == ";") {
                        if charStr.count == 1, let firstCh = charStr.first, firstCh.isLetter {
                            proxyWrapper.insertText(" ")
                        }
                    }
                }

                // Nếu vừa chọn gợi ý (có dấu cách trailing) mà người dùng gõ dấu câu, tự động bỏ dấu cách để dấu câu bám sát vào từ (ví dụ 'vợ .' -> 'vợ.')
                let isPunctuation = (charStr.count == 1 && [".", ",", "!", "?", ":", ";", ")", "]", "}"].contains(charStr))
                if isPunctuation, let before = proxyWrapper.documentContextBeforeInput, before.hasSuffix(" ") {
                    proxyWrapper.deleteBackward()
                }
                if [".", "!", "?"].contains(charStr) {
                    lastRecordedWord = charStr
                }

                if charStr.count == 1, let firstChar = charStr.first {
                    adapter.handleKeyInput(firstChar, proxy: proxyWrapper)
                } else {
                    proxyWrapper.insertText(charStr)
                }
            }
            checkAutoCapitalization()

        case .space:
            if isGlidedComposing, let base = glidedWord {
                UserAdaptiveLearningStore.shared.recordWordInput(base, previousWord: lastRecordedWord, previousPreviousWord: secondLastRecordedWord)
                if lastRecordedWord == nil || [".", "!", "?"].contains(lastRecordedWord) {
                    UserAdaptiveLearningStore.shared.recordSentenceStartWord(base)
                }
                secondLastRecordedWord = lastRecordedWord
                lastRecordedWord = base
                isGlidedComposing = false
                glidedWord = nil
                glidedPrefixSpaceCount = 0
                adapter.adapter.reset()
            }
            let currentWord = adapter.extractCurrentWord(from: proxyWrapper.documentContextBeforeInput ?? "")
            if !currentWord.isEmpty {
                UserAdaptiveLearningStore.shared.recordWordInput(currentWord, previousWord: lastRecordedWord, previousPreviousWord: secondLastRecordedWord)
                if lastRecordedWord == nil || [".", "!", "?"].contains(lastRecordedWord) {
                    UserAdaptiveLearningStore.shared.recordSentenceStartWord(currentWord)
                }
                secondLastRecordedWord = lastRecordedWord
                lastRecordedWord = currentWord
            }

            let now = Date().timeIntervalSince1970
            if !keyboardView.isDeveloperModeActive && vBoardSettings.shared.isSpaceDoubleTapPeriodEnabled && (now - lastSpaceTapTime < 0.4) {
                // Nhấn đúp Space nhanh -> Thay thế khoảng trắng vừa nhập bằng ". "
                proxyWrapper.deleteBackward()
                proxyWrapper.insertText(". ")
                lastRecordedWord = "."
                lastSpaceTapTime = 0
            } else {
                adapter.handleSpace(proxy: proxyWrapper)
                lastSpaceTapTime = now
            }

        case .delete:
            if isGlidedComposing, let base = glidedWord {
                // Xóa trọn vẹn cả từ vừa vuốt VÀ khoảng trắng tiền tố tự động chèn trong 1 chạm
                let totalCharsToDelete = base.count + glidedPrefixSpaceCount
                for _ in 0..<totalCharsToDelete {
                    proxyWrapper.deleteBackward()
                }
                isGlidedComposing = false
                glidedWord = nil
                glidedPrefixSpaceCount = 0
                adapter.adapter.reset()
                updateWordSuggestions()
                return
            }
            isGlidedComposing = false
            glidedWord = nil
            glidedPrefixSpaceCount = 0
            adapter.handleBackspace(proxy: proxyWrapper)

        case .returnKey:
            isGlidedComposing = false
            glidedWord = nil
            glidedPrefixSpaceCount = 0
            adapter.handleReturn(proxy: proxyWrapper)

        default:
            break
        }
        updateWordSuggestions()
    }

    public func keyboardView(_ keyboardView: KeyboardView, didLongPressKey key: KeyboardKey) {
        if case .character(let charStr) = key.type {
            if keyboardView.isDeveloperModeActive {
                proxyWrapper.insertText(charStr)
            } else if charStr.count == 1, let firstChar = charStr.first {
                adapter.handleKeyInput(firstChar, proxy: proxyWrapper)
            } else {
                proxyWrapper.insertText(charStr)
            }
            updateWordSuggestions()
        }
    }

    public func keyboardViewDidDismiss(_ keyboardView: KeyboardView) {
        dismissKeyboard()
    }

    public func keyboardView(_ keyboardView: KeyboardView, didGlideWord word: String) {
        let beforeText = proxyWrapper.documentContextBeforeInput ?? ""

        // Nếu trước đó đang có một từ vừa vuốt (isGlidedComposing == true) và người dùng vuốt tiếp từ mới:
        // Nghĩa là từ trước đã đúng ý người dùng -> Ta chốt từ trước và thêm khoảng trắng
        if isGlidedComposing, let prevGlided = glidedWord {
            UserAdaptiveLearningStore.shared.recordWordInput(prevGlided, previousWord: lastRecordedWord, previousPreviousWord: secondLastRecordedWord)
            if lastRecordedWord == nil || [".", "!", "?"].contains(lastRecordedWord) {
                UserAdaptiveLearningStore.shared.recordSentenceStartWord(prevGlided)
            }
            secondLastRecordedWord = lastRecordedWord
            lastRecordedWord = prevGlided
            isGlidedComposing = false
            glidedWord = nil
        } else {
            // Người dùng đang gõ dở bằng phím thường (chưa cách) mà vuốt từ tiếp theo:
            // Tuyệt đối KHÔNG xóa mất từ đang gõ! Hoàn thiện từ đang gõ bằng gợi ý tốt nhất (nếu có), thêm dấu cách và chốt từ.
            let currentWord = adapter.extractCurrentWord(from: beforeText)
            if !currentWord.isEmpty {
                // Tra cứu từ gợi ý chuẩn nhất cho từ đang gõ dở (ví dụ 'nguo' -> 'người', 'viet' -> 'Việt')
                let topSuggestion = WordTrie.shared.suggest(prefix: currentWord, limit: 1).first ?? keyboardView.suggestionBar.currentSuggestions.first
                let committedWord: String

                if let suggestion = topSuggestion, !suggestion.isEmpty, suggestion.lowercased() != currentWord.lowercased() {
                    for _ in 0..<currentWord.count {
                        proxyWrapper.deleteBackward()
                    }
                    let formatted = keyboardView.formatSuggestionText(suggestion)
                    proxyWrapper.insertText(formatted)
                    committedWord = formatted
                } else {
                    // Từ đang gõ đã hoàn chỉnh (ví dụ đã gõ 'người' hoặc từ riêng) -> Giữ nguyên
                    committedWord = currentWord
                }

                UserAdaptiveLearningStore.shared.recordWordInput(committedWord, previousWord: lastRecordedWord, previousPreviousWord: secondLastRecordedWord)
                if lastRecordedWord == nil || [".", "!", "?"].contains(lastRecordedWord) {
                    UserAdaptiveLearningStore.shared.recordSentenceStartWord(committedWord)
                }
                secondLastRecordedWord = lastRecordedWord
                lastRecordedWord = committedWord
                adapter.adapter.reset()
            }
        }

        let formattedWord = keyboardView.formatSuggestionText(word)
        let updatedBefore = proxyWrapper.documentContextBeforeInput ?? ""
        let prefixSpace = (!updatedBefore.isEmpty && !updatedBefore.hasSuffix(" ") && !updatedBefore.hasSuffix("\n")) ? " " : ""

        proxyWrapper.insertText(prefixSpace + formattedWord)
        isGlidedComposing = true
        glidedWord = formattedWord
        glidedPrefixSpaceCount = prefixSpace.count
        adapter.adapter.reset()

        keyboardView.resetShiftIfNeeded()
    }

    private func pairForChar(_ s: String) -> String? {
        switch s {
        case "{": return "{}"
        case "[": return "[]"
        case "(": return "()"
        case "<": return "<>"
        case "\"": return "\"\""
        case "'": return "''"
        case "`": return "``"
        default: return nil
        }
    }

    // MARK: - SuggestionBarViewDelegate

    public func suggestionBar(_ bar: SuggestionBarView, didSelectWord word: String) {
        let beforeText = proxyWrapper.documentContextBeforeInput ?? ""

        if isGlidedComposing, let currentGlided = glidedWord {
            // 1. Người dùng chọn từ thay thế cho từ vừa vuốt
            let totalCharsToDelete = currentGlided.count + glidedPrefixSpaceCount
            for _ in 0..<totalCharsToDelete {
                proxyWrapper.deleteBackward()
            }
            isGlidedComposing = false
            glidedWord = nil
            glidedPrefixSpaceCount = 0
        } else {
            let currentWord = adapter.extractCurrentWord(from: beforeText)
            if !currentWord.isEmpty {
                // 2. Nếu đang gõ dở một từ thông thường -> Xóa từ đang gõ dở
                for _ in 0..<currentWord.count {
                    proxyWrapper.deleteBackward()
                }
            }
            // 3. Nếu con trỏ sau dấu cách (trạng thái đã chốt) -> Giữ nguyên từ trước, nối tiếp từ mới!
        }

        let formattedWord = keyboardView.formatSuggestionText(word)
        let updatedBefore = proxyWrapper.documentContextBeforeInput ?? ""
        let prefixSpace = (!updatedBefore.isEmpty && !updatedBefore.hasSuffix(" ") && !updatedBefore.hasSuffix("\n")) ? " " : ""

        // Chèn từ mới kèm dấu cách để sẵn sàng cho từ tiếp theo
        proxyWrapper.insertText(prefixSpace + formattedWord + " ")

        // Ghi nhận vào bộ học thích ứng cá nhân
        UserAdaptiveLearningStore.shared.recordWordInput(formattedWord, previousWord: lastRecordedWord, previousPreviousWord: secondLastRecordedWord)
        if lastRecordedWord == nil || [".", "!", "?"].contains(lastRecordedWord) {
            UserAdaptiveLearningStore.shared.recordSentenceStartWord(formattedWord)
        }
        secondLastRecordedWord = lastRecordedWord
        lastRecordedWord = formattedWord

        // Reset OpenKey engine để tránh lệch pha bộ đệm
        adapter.adapter.reset()

        // DUY TRÌ VÒNG LẶP GỢI Ý LIÊN TỤC: Cập nhật ngay dự đoán từ tiếp theo
        updateWordSuggestions()
        checkAutoCapitalization()
        keyboardView.resetShiftIfNeeded()
    }

    public func suggestionBarDidTapClipboard(_ bar: SuggestionBarView) {
        guard self.hasFullAccess else {
            keyboardView.suggestionBar.showToast("Cần bật 'Cho phép truy cập đầy đủ' để dùng Bảng tạm")
            return
        }
        if UIPasteboard.general.hasStrings, let text = UIPasteboard.general.string, !text.isEmpty {
            ClipboardManager.shared.addClip(text)
        }
        keyboardView.showClipboardView(delegate: self)
    }

    public func suggestionBarDidTapSettings(_ bar: SuggestionBarView) {
        keyboardView.showQuickSettingsView(delegate: self)
    }

    public func suggestionBarDidTapTextEditing(_ bar: SuggestionBarView) {
        keyboardView.showTextEditingView(proxy: proxyWrapper)
    }

    public func suggestionBarDidTapDeveloperMode(_ bar: SuggestionBarView) {
        keyboardView.setDeveloperMode(!keyboardView.isDeveloperModeActive)
    }

    public func suggestionBar(_ bar: SuggestionBarView, didRequestAddWord word: String) {
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanWord.isEmpty else { return }
        HapticManager.shared.playSpecialKey()
        UserAdaptiveLearningStore.shared.addUserWordDirectly(cleanWord, frequency: 15)
        WordTrie.shared.insert(word: cleanWord, frequency: 150)

        // Sau khi lưu từ vào từ điển cá nhân, kết thúc từ hiện tại bằng dấu cách để gõ tiếp từ mới
        let before = proxyWrapper.documentContextBeforeInput ?? ""
        if !before.isEmpty && !before.hasSuffix(" ") && !before.hasSuffix("\n") {
            proxyWrapper.insertText(" ")
        }
        lastRecordedWord = cleanWord
        adapter.adapter.reset()
        updateWordSuggestions()
        checkAutoCapitalization()
    }

    public func suggestionBar(_ bar: SuggestionBarView, didRequestDeleteWord word: String) {
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanWord.isEmpty else { return }
        HapticManager.shared.playSpecialKey()
        UserAdaptiveLearningStore.shared.blacklistWord(cleanWord)
        UserAdaptiveLearningStore.shared.deleteUserWord(cleanWord)
        updateWordSuggestions()
    }


    // MARK: - Undo & Redo & One-Handed & SmartChip Delegate

    public func suggestionBarDidTapUndo(_ bar: SuggestionBarView) {
        adapter.handleUndo(proxy: proxyWrapper)
        updateWordSuggestions()
        checkAutoCapitalization()
        bar.updateHistoryButtons()
    }

    public func suggestionBarDidTapRedo(_ bar: SuggestionBarView) {
        adapter.handleRedo(proxy: proxyWrapper)
        updateWordSuggestions()
        checkAutoCapitalization()
        bar.updateHistoryButtons()
    }

    public func suggestionBarDidTapSmartChip(_ bar: SuggestionBarView, clipText: String) {
        proxyWrapper.insertText(clipText)
        updateWordSuggestions()
        checkAutoCapitalization()
    }

    public func suggestionBarDidTapOneHanded(_ bar: SuggestionBarView) {
        let cur = vBoardSettings.shared.oneHandedMode
        vBoardSettings.shared.oneHandedMode = (cur == .off) ? vBoardSettings.shared.lastOneHandedSide : .off
        vBoardSettings.shared.notifySettingsChanged()
        applyLatestSettings()
    }

    public func suggestionBarDidTapPaste(_ bar: SuggestionBarView) {
        guard self.hasFullAccess else {
            keyboardView.suggestionBar.showToast("Cần bật 'Cho phép truy cập đầy đủ' để dán")
            return
        }
        if UIPasteboard.general.hasStrings, let text = UIPasteboard.general.string, !text.isEmpty {
            ClipboardManager.shared.addClip(text)
            HapticManager.shared.playKeyTap()
            proxyWrapper.insertText(text)
            updateWordSuggestions()
            checkAutoCapitalization()
        } else {
            keyboardView.showClipboardView(delegate: self)
        }
    }

    private func checkAutoCapitalization() {
        guard vBoardSettings.shared.isAutoCapitalizationEnabled, !keyboardView.isDeveloperModeActive, !keyboardView.isNumberPadActive else { return }
        let before = proxyWrapper.documentContextBeforeInput ?? ""
        let shouldCap = before.isEmpty || before.hasSuffix(". ") || before.hasSuffix("! ") || before.hasSuffix("? ") || before.hasSuffix("\n")
        keyboardView.setShiftState(shouldCap)
    }

    // MARK: - ClipboardViewDelegate

    public func clipboardViewDidRequestClose(_ view: ClipboardView) {
        keyboardView.hideClipboardView()
    }

    public func clipboardView(_ view: ClipboardView, didSelectClip text: String) {
        proxyWrapper.insertText(text)
        updateWordSuggestions()
        keyboardView.hideClipboardView()
    }

    // MARK: - QuickSettingsViewDelegate

    public func quickSettingsDidRequestClose(_ view: QuickSettingsView) {
        keyboardView.hideQuickSettingsView()
    }

    public func quickSettingsDidChangeConfiguration(_ view: QuickSettingsView) {
        applyLatestSettings()
        keyboardView.quickSettingsView?.updateUIState()
    }

    // MARK: - KeyboardViewDelegate - Emoji & Settings App
    public func keyboardViewDidRequestEmojiPicker(_ keyboardView: KeyboardView) {
        keyboardView.showEmojiPickerView(delegate: self)
    }

    public func keyboardViewDidOpenSettingsApp(_ keyboardView: KeyboardView) {
        guard let url = URL(string: "vboard://settings") else { return }
        
        if let context = extensionContext {
            context.open(url) { [weak self] success in
                if !success {
                    DispatchQueue.main.async {
                        self?.fallbackOpenSettings()
                    }
                }
            }
            return
        }
        fallbackOpenSettings()
    }

    private func fallbackOpenSettings() {
        guard let url = URL(string: "vboard://settings") else { return }
        
        var responder: UIResponder? = self
        let selWithHandler = sel_registerName("openURL:completionHandler:")
        let selSingle = sel_registerName("openURL:")
        while let r = responder {
            if r.responds(to: selWithHandler) {
                r.perform(selWithHandler, with: url, with: nil)
                return
            } else if r.responds(to: selSingle) {
                r.perform(selSingle, with: url)
                return
            }
            responder = r.next
        }
        
        // Mở QuickSettings nội bộ nếu hệ thống iOS chặn mở ứng dụng ngoài (chưa bật Allow Full Access)
        keyboardView.showQuickSettingsView(delegate: self)
    }

    // MARK: - EmojiPickerViewDelegate
    public func emojiPickerView(_ view: EmojiPickerView, didSelectEmoji emoji: String) {
        proxyWrapper.insertText(emoji)
        updateWordSuggestions()
    }

    public func emojiPickerViewDidRequestBackspace(_ view: EmojiPickerView) {
        proxyWrapper.deleteBackward()
        updateWordSuggestions()
    }

    public func emojiPickerViewDidRequestSwitchToABC(_ view: EmojiPickerView) {
        keyboardView.hideEmojiPickerView()
    }

    /// Kết hợp từ vừa vuốt với một ký tự gõ tiếp theo để kiểm tra tính hợp lệ tiếng Việt
    private func combineGlidedWord(_ baseWord: String, with char: Character) -> (isValid: Bool, combinedWord: String) {
        // 1. Thử dùng OpenKeyEngineAdapter để xử lý ký tự gõ vào baseWord (cho phím dấu Telex/VNI và biến âm)
        let testAdapter = OpenKeyEngineAdapter()
        testAdapter.engine.vInputType = adapter.engine.vInputType
        testAdapter.engine.vUseModernOrthography = adapter.engine.vUseModernOrthography
        testAdapter.engine.vQuickTelex = adapter.engine.vQuickTelex
        testAdapter.engine.vQuickStartConsonant = adapter.engine.vQuickStartConsonant
        testAdapter.engine.vQuickEndConsonant = adapter.engine.vQuickEndConsonant
        testAdapter.engine.vAllowConsonantZFWJ = adapter.engine.vAllowConsonantZFWJ

        testAdapter.syncContextWord(baseWord)
        let action = testAdapter.processKeystroke(char)

        if action.deleteCount > 0 || !action.textToInsert.isEmpty {
            let prefixKept = String(baseWord.dropLast(action.deleteCount))
            let candidate = prefixKept + action.textToInsert
            if candidate != baseWord && (WordTrie.shared.isValidVietnameseSyllable(candidate) || testAdapter.isValidVietnameseSpelling(candidate)) {
                return (true, candidate)
            }
        }

        // 2. Thử nối trực tiếp: baseWord + char (cho nguyên âm phụ hoặc phụ âm cuối, ví dụ "vợ" + "i" -> "vợi")
        let directCandidate = baseWord + String(char)
        if WordTrie.shared.isValidVietnameseSyllable(directCandidate) || testAdapter.isValidVietnameseSpelling(directCandidate) {
            return (true, directCandidate)
        }

        return (false, "")
    }
}

// MARK: - UIInputViewAudioFeedback Protocol
extension KeyboardViewController: UIInputViewAudioFeedback {
    public var enableInputClicksWhenVisible: Bool {
        return true
    }
}
#endif
