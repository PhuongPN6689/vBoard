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

    open override func viewDidLoad() {
        super.viewDidLoad()

        // Khởi tạo Engine và Adapter
        let engine = VietnameseEngine(inputMethod: .telex, diacriticStyle: .newStyle)
        adapter = TextProxyAdapter(engine: engine)
        proxyWrapper = NativeTextProxyWrapper(proxy: textDocumentProxy)

        // Khởi tạo KeyboardView
        keyboardView = KeyboardView(frame: .zero)
        keyboardView.delegate = self
        keyboardView.suggestionBar.delegate = self
        keyboardView.configureGestures(proxy: proxyWrapper)
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
        adapter.engine.inputMethod = settings.inputMethod
        adapter.engine.diacriticStyle = settings.diacriticStyle
        adapter.engine.isQuickTelexEnabled = settings.isQuickTelexEnabled
        adapter.engine.isBracketShortcutsEnabled = settings.isBracketShortcutsEnabled
        adapter.engine.isZKeyRemoveToneEnabled = settings.isZKeyRemoveToneEnabled
        adapter.engine.isWAtWordBeginningEnabled = settings.isWAtWordBeginningEnabled
        adapter.engine.isModernToneBalancingEnabled = settings.isModernToneBalancingEnabled
        adapter.engine.isQuickStartConsonantEnabled = settings.isQuickStartConsonantEnabled
        adapter.engine.isQuickEndConsonantEnabled = settings.isQuickEndConsonantEnabled
        adapter.engine.isSpellingCheckEnabled = settings.isSpellingCheckEnabled
        adapter.engine.isRestoreIfWrongSpellingEnabled = settings.isRestoreIfWrongSpellingEnabled
        adapter.engine.isAllowConsonantZFWJEnabled = settings.isAllowConsonantZFWJEnabled

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
            calculatedHeight += 34.0
        }

        if heightConstraint == nil {
            heightConstraint = view.heightAnchor.constraint(equalToConstant: calculatedHeight)
            heightConstraint?.priority = UILayoutPriority(999)
            heightConstraint?.isActive = true
        } else {
            heightConstraint?.constant = calculatedHeight
        }

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

        // Tự động lưu mẩu văn bản vừa copy vào Bảng tạm và hiển thị Smart Quick Chip
        if settings.isClipboardEnabled, UIPasteboard.general.hasStrings, let text = UIPasteboard.general.string {
            ClipboardManager.shared.addClip(text)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
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

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Gắn tương tác chuyển bàn phím hệ thống của Apple vào phím Globe
        if let globe = keyboardView.globeKeyView {
            globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        }
    }

    private func updateWordSuggestions() {
        guard vBoardSettings.shared.isSuggestionBarEnabled, !keyboardView.isNumberPadActive else { return }
        let currentWord = adapter.engine.extractCurrentWord(from: proxyWrapper.documentContextBeforeInput ?? "")
        if currentWord.isEmpty {
            var predictions: [String] = []
            let trimmed = (proxyWrapper.documentContextBeforeInput ?? "").trimmingCharacters(in: .whitespaces)
            let lastWord = adapter.engine.extractCurrentWord(from: trimmed)

            if !lastWord.isEmpty {
                if vBoardSettings.shared.isNextWordPredictionEnabled {
                    predictions.append(contentsOf: NextWordPredictor.shared.predictNextWords(after: lastWord, limit: 3))
                }
                if vBoardSettings.shared.isTextToEmojiEnabled {
                    predictions.append(contentsOf: TextToEmojiMapper.shared.emojis(for: lastWord))
                }
            }

            if !predictions.isEmpty {
                let formatted = predictions.map { keyboardView.formatSuggestionText($0) }
                keyboardView.suggestionBar.setSuggestions(Array(formatted.prefix(3)))
            } else {
                keyboardView.suggestionBar.setSuggestions([])
            }
        } else {
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
            keyboardView.suggestionBar.setSuggestions(formatted)
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
                // Tự động thêm dấu cách sau dấu câu nếu gõ chữ cái liền kề
                if vBoardSettings.shared.isAutoSpaceAfterPunctuationEnabled {
                    let before = proxyWrapper.documentContextBeforeInput ?? ""
                    if let last = before.last, (last == "," || last == "." || last == "!" || last == "?" || last == ":" || last == ";") {
                        if charStr.count == 1, let firstCh = charStr.first, firstCh.isLetter {
                            proxyWrapper.insertText(" ")
                        }
                    }
                }

                if charStr.count == 1, let firstChar = charStr.first {
                    adapter.handleKeyInput(firstChar, proxy: proxyWrapper)
                } else {
                    proxyWrapper.insertText(charStr)
                }
            }
            checkAutoCapitalization()

        case .space:
            let now = Date().timeIntervalSince1970
            if !keyboardView.isDeveloperModeActive && vBoardSettings.shared.isSpaceDoubleTapPeriodEnabled && (now - lastSpaceTapTime < 0.4) {
                // Nhấn đúp Space nhanh -> Thay thế khoảng trắng vừa nhập bằng ". "
                proxyWrapper.deleteBackward()
                proxyWrapper.insertText(". ")
                lastSpaceTapTime = 0
            } else {
                adapter.handleSpace(proxy: proxyWrapper)
                lastSpaceTapTime = now
            }

        case .delete:
            adapter.handleBackspace(proxy: proxyWrapper)

        case .returnKey:
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

    public func keyboardViewDidRequestNextKeyboard(_ keyboardView: KeyboardView) {
        advanceToNextInputMode()
    }

    public func keyboardViewDidDismiss(_ keyboardView: KeyboardView) {
        dismissKeyboard()
    }

    public func keyboardView(_ keyboardView: KeyboardView, didGlideWord word: String) {
        let currentWord = adapter.engine.extractCurrentWord(from: proxyWrapper.documentContextBeforeInput ?? "")
        for _ in 0..<currentWord.count {
            proxyWrapper.deleteBackward()
        }
        let formattedWord = keyboardView.formatSuggestionText(word)
        proxyWrapper.insertText(formattedWord + " ")
        updateWordSuggestions()
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
        let currentWord = adapter.engine.extractCurrentWord(from: proxyWrapper.documentContextBeforeInput ?? "")
        for _ in 0..<currentWord.count {
            proxyWrapper.deleteBackward()
        }
        let formattedWord = keyboardView.formatSuggestionText(word)
        proxyWrapper.insertText(formattedWord + " ")
        keyboardView.suggestionBar.setSuggestions([])
        keyboardView.resetShiftIfNeeded()
    }

    public func suggestionBarDidTapClipboard(_ bar: SuggestionBarView) {
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
        vBoardSettings.shared.oneHandedMode = (cur == .off) ? .right : .off
        vBoardSettings.shared.notifySettingsChanged()
        applyLatestSettings()
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

    // MARK: - KeyboardViewDelegate - Emoji
    public func keyboardViewDidRequestEmojiPicker(_ keyboardView: KeyboardView) {
        keyboardView.showEmojiPickerView(delegate: self)
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
}
#endif
