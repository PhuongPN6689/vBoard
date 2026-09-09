#if canImport(UIKit)
import UIKit
import vBoardEngine

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
open class KeyboardViewController: UIInputViewController, KeyboardViewDelegate, SuggestionBarViewDelegate, QuickSettingsViewDelegate {
    public private(set) var keyboardView: KeyboardView!
    public private(set) var adapter: TextProxyAdapter!
    private var proxyWrapper: NativeTextProxyWrapper!
    private var quickSettingsView: QuickSettingsView?

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

        keyboardView.currentReturnKeyType = textDocumentProxy.returnKeyType ?? .default
        keyboardView.refreshLayout()

        let scale = settings.keyboardHeightScale
        let isPad = traitCollection.userInterfaceIdiom == .pad
        let baseHeight: CGFloat = isPad ? scale.padHeight : scale.phoneHeight
        var calculatedHeight: CGFloat = baseHeight
        if settings.isNumberRowEnabled && !keyboardView.isNumberPadActive {
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

        // Tự động lưu mẩu văn bản vừa copy vào Bảng tạm nếu được cấp quyền
        if settings.isClipboardEnabled, UIPasteboard.general.hasStrings, let text = UIPasteboard.general.string {
            ClipboardManager.shared.addClip(text)
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
            keyboardView.suggestionBar.setSuggestions([])
        } else {
            let suggestions = WordTrie.shared.suggest(prefix: currentWord, limit: 3)
            keyboardView.suggestionBar.setSuggestions(suggestions)
        }
    }

    // MARK: - KeyboardViewDelegate

    public func keyboardView(_ keyboardView: KeyboardView, didPressKey key: KeyboardKey) {
        switch key.type {
        case .character(let charStr):
            if keyboardView.isDeveloperModeActive {
                // Ở chế độ Lập trình viên: bypass bộ gõ tiếng Việt, chèn trực tiếp các ký tự / phím điều hướng
                if charStr == "Tab" {
                    let tabStr = vBoardSettings.shared.developerTabBehavior.insertString
                    proxyWrapper.insertText(tabStr)
                } else if charStr == "←" {
                    proxyWrapper.adjustTextPosition(byCharacterOffset: -1)
                } else if charStr == "→" {
                    proxyWrapper.adjustTextPosition(byCharacterOffset: 1)
                } else {
                    proxyWrapper.insertText(charStr)
                }
            } else if keyboardView.isSymbolsLayerActive && (charStr == "<" || charStr == ">") {
                // Phím điều hướng con trỏ trên Layer Ký hiệu cấp 2 chuẩn Gboard
                let offset = (charStr == "<") ? -1 : 1
                proxyWrapper.adjustTextPosition(byCharacterOffset: offset)
            } else {
                if charStr.count == 1, let firstChar = charStr.first {
                    adapter.handleKeyInput(firstChar, proxy: proxyWrapper)
                } else {
                    proxyWrapper.insertText(charStr)
                }
            }

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
        proxyWrapper.insertText(word + " ")
        updateWordSuggestions()
    }

    // MARK: - SuggestionBarViewDelegate

    public func suggestionBar(_ bar: SuggestionBarView, didSelectWord word: String) {
        let currentWord = adapter.engine.extractCurrentWord(from: proxyWrapper.documentContextBeforeInput ?? "")
        for _ in 0..<currentWord.count {
            proxyWrapper.deleteBackward()
        }
        proxyWrapper.insertText(word + " ")
        keyboardView.suggestionBar.setSuggestions([])
    }

    public func suggestionBar(_ bar: SuggestionBarView, didSelectClipboardText text: String) {
        proxyWrapper.insertText(text)
        updateWordSuggestions()
    }

    public func suggestionBarDidTapSettings(_ bar: SuggestionBarView) {
        if quickSettingsView == nil {
            let qs = QuickSettingsView(frame: keyboardView.bounds)
            qs.delegate = self
            keyboardView.addSubview(qs)
            quickSettingsView = qs
        }
        quickSettingsView?.frame = keyboardView.bounds
        quickSettingsView?.updateUIState()
        quickSettingsView?.isHidden = false
        keyboardView.bringSubviewToFront(quickSettingsView!)
    }

    public func suggestionBarDidTapTextEditing(_ bar: SuggestionBarView) {
        keyboardView.showTextEditingView(proxy: proxyWrapper)
    }

    public func suggestionBarDidTapDeveloperMode(_ bar: SuggestionBarView) {
        keyboardView.setDeveloperMode(!keyboardView.isDeveloperModeActive)
    }

    // MARK: - QuickSettingsViewDelegate

    public func quickSettingsDidRequestClose(_ view: QuickSettingsView) {
        view.isHidden = true
    }

    public func quickSettingsDidChangeConfiguration(_ view: QuickSettingsView) {
        applyLatestSettings()

        if let qs = quickSettingsView, !qs.isHidden {
            qs.frame = keyboardView.bounds
            qs.setNeedsLayout()
        }
    }
}
#endif
