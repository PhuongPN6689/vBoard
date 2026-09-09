#if canImport(UIKit)
import UIKit
import vBoardEngine

@MainActor
public protocol KeyboardViewDelegate: AnyObject {
    func keyboardView(_ keyboardView: KeyboardView, didPressKey key: KeyboardKey)
    func keyboardView(_ keyboardView: KeyboardView, didLongPressKey key: KeyboardKey)
    func keyboardViewDidRequestNextKeyboard(_ keyboardView: KeyboardView)
    func keyboardViewDidDismiss(_ keyboardView: KeyboardView)
    func keyboardView(_ keyboardView: KeyboardView, didGlideWord word: String)
    func keyboardViewDidRequestEmojiPicker(_ keyboardView: KeyboardView)
}

public final class KeyboardView: UIView, KeyViewDelegate, UIGestureRecognizerDelegate, KeyCalloutViewDelegate, TextEditingViewDelegate {
    public weak var delegate: KeyboardViewDelegate?

    public var currentReturnKeyType: UIReturnKeyType = .default {
        didSet {
            if oldValue != currentReturnKeyType {
                buildCurrentLayout()
            }
        }
    }

    public private(set) var isShiftActive: Bool = false
    public private(set) var isCapsLockActive: Bool = false
    public private(set) var isNumberLayerActive: Bool = false
    public private(set) var isSymbolsLayerActive: Bool = false
    public private(set) var isNumberPadActive: Bool = false
    public private(set) var isDeveloperModeActive: Bool = false
    public var isNumberRowActive: Bool = false {
        didSet {
            if oldValue != isNumberRowActive {
                buildCurrentLayout()
            }
        }
    }
    public private(set) weak var globeKeyView: KeyView?
    public private(set) var textEditingView: TextEditingView?
    public private(set) var quickSettingsView: QuickSettingsView?
    public private(set) var clipboardView: ClipboardView?
    public private(set) var emojiPickerView: EmojiPickerView?

    public let suggestionBar = SuggestionBarView()
    public let glideTrailLayer = GlideTrailLayer()
    public let calloutView = KeyCalloutView()
    private let dismissButton = UIButton(type: .system)
    private let gradientLayer = CAGradientLayer()

    // One-handed Mode Side Panel
    private let oneHandedSidePanel = UIView()
    private let oneHandedSwapButton = UIButton(type: .system)
    private let oneHandedExpandButton = UIButton(type: .system)
    private var panGesture: UIPanGestureRecognizer?
    private var isGlideTrackingActive: Bool = false
    private var glideTrackedChars: [Character] = []
    private var lastGlidePoint: CGPoint = .zero
    private var lastGlideCompletedTimestamp: TimeInterval = 0

    private var lastShiftTapTime: TimeInterval = 0
    private var rowViews: [[KeyView]] = []
    private var currentRows: [[KeyboardKey]] = []

    public var spaceCursorHandler: SpaceCursorHandler?
    public var backspaceSwipeHandler: BackspaceSwipeHandler?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func configureGestures(proxy: TextDocumentProxyProtocol?) {
        spaceCursorHandler = SpaceCursorHandler(proxy: proxy)
        backspaceSwipeHandler = BackspaceSwipeHandler(proxy: proxy)
        textEditingView?.updateProxy(proxy)
    }

    public func setNumberPadMode(_ active: Bool) {
        isNumberPadActive = active
        if active {
            isNumberLayerActive = false
            isSymbolsLayerActive = false
            isDeveloperModeActive = false
        }
        buildCurrentLayout()
    }

    public func setNumbersMode() {
        isNumberPadActive = false
        isNumberLayerActive = true
        isSymbolsLayerActive = false
        isDeveloperModeActive = false
        buildCurrentLayout()
    }

    public func setLettersMode() {
        isNumberPadActive = false
        isNumberLayerActive = false
        isSymbolsLayerActive = false
        isDeveloperModeActive = false
        buildCurrentLayout()
    }

    public func setDeveloperMode(_ active: Bool) {
        isDeveloperModeActive = active
        if active {
            isNumberPadActive = false
            isNumberLayerActive = false
            isSymbolsLayerActive = false
        }
        buildCurrentLayout()
    }

    public func showTextEditingView(proxy: TextDocumentProxyProtocol?) {
        if textEditingView == nil {
            let tev = TextEditingView(frame: bounds, proxy: proxy)
            tev.delegate = self
            addSubview(tev)
            textEditingView = tev
        }
        textEditingView?.updateProxy(proxy)
        textEditingView?.frame = bounds
        textEditingView?.isHidden = false
        bringSubviewToFront(textEditingView!)
        updateSuggestionBarVisibility()
    }

    public func hideTextEditingView() {
        textEditingView?.isHidden = true
        updateSuggestionBarVisibility()
    }

    public func showQuickSettingsView(delegate: QuickSettingsViewDelegate?) {
        if quickSettingsView == nil {
            let qs = QuickSettingsView(frame: bounds)
            qs.delegate = delegate
            addSubview(qs)
            quickSettingsView = qs
        }
        quickSettingsView?.frame = bounds
        quickSettingsView?.updateUIState()
        quickSettingsView?.isHidden = false
        bringSubviewToFront(quickSettingsView!)
        updateSuggestionBarVisibility()
    }

    public func hideQuickSettingsView() {
        quickSettingsView?.isHidden = true
        updateSuggestionBarVisibility()
    }

    public func showClipboardView(delegate: ClipboardViewDelegate?) {
        if clipboardView == nil {
            let cv = ClipboardView(frame: bounds)
            cv.delegate = delegate
            addSubview(cv)
            clipboardView = cv
        }
        clipboardView?.delegate = delegate
        clipboardView?.frame = bounds
        clipboardView?.reloadData()
        clipboardView?.isHidden = false
        bringSubviewToFront(clipboardView!)
        updateSuggestionBarVisibility()
    }

    public func hideClipboardView() {
        clipboardView?.isHidden = true
        updateSuggestionBarVisibility()
    }

    public func showEmojiPickerView(delegate: EmojiPickerViewDelegate?) {
        if emojiPickerView == nil {
            let epv = EmojiPickerView(frame: bounds)
            epv.delegate = delegate
            addSubview(epv)
            emojiPickerView = epv
        }
        emojiPickerView?.delegate = delegate
        emojiPickerView?.frame = bounds
        emojiPickerView?.reloadContent()
        emojiPickerView?.isHidden = false
        bringSubviewToFront(emojiPickerView!)
        updateSuggestionBarVisibility()
    }

    public func hideEmojiPickerView() {
        emojiPickerView?.isHidden = true
        updateSuggestionBarVisibility()
    }

    private func updateSuggestionBarVisibility() {
        let isOverlayOpen = (textEditingView != nil && !textEditingView!.isHidden) ||
                            (quickSettingsView != nil && !quickSettingsView!.isHidden) ||
                            (clipboardView != nil && !clipboardView!.isHidden) ||
                            (emojiPickerView != nil && !emojiPickerView!.isHidden)
        let hasSuggestionBar = vBoardSettings.shared.isSuggestionBarEnabled && !isNumberPadActive
        suggestionBar.isHidden = !hasSuggestionBar || isOverlayOpen

        // Tuyệt đối vô hiệu hoá cử chỉ vuốt để nhập khi có bất kỳ màn hình lớp phủ nào đang mở
        panGesture?.isEnabled = !isOverlayOpen
        if isOverlayOpen {
            glideTrailLayer.clear()
            isGlideTrackingActive = false
            glideTrackedChars.removeAll()
        }
        if !suggestionBar.isHidden {
            bringSubviewToFront(suggestionBar)
        }
        setNeedsLayout()
        layoutIfNeeded()
    }

    private func setupLayers() {
        layer.insertSublayer(gradientLayer, at: 0)
        addSubview(suggestionBar)
        layer.addSublayer(glideTrailLayer)

        // Setup One-Handed Side Panel
        let sideConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        oneHandedSwapButton.setImage(UIImage(systemName: "arrow.left.and.right", withConfiguration: sideConfig), for: .normal)
        oneHandedSwapButton.tintColor = .secondaryLabel
        oneHandedSwapButton.addTarget(self, action: #selector(handleOneHandedSwap), for: .touchUpInside)
        oneHandedSidePanel.addSubview(oneHandedSwapButton)

        oneHandedExpandButton.setImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right", withConfiguration: sideConfig), for: .normal)
        oneHandedExpandButton.tintColor = .secondaryLabel
        oneHandedExpandButton.addTarget(self, action: #selector(handleOneHandedExpand), for: .touchUpInside)
        oneHandedSidePanel.addSubview(oneHandedExpandButton)

        oneHandedSidePanel.isHidden = true
        addSubview(oneHandedSidePanel)

        let dismissConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        let dismissIcon = UIImage(systemName: "keyboard.chevron.compact.down", withConfiguration: dismissConfig) ?? UIImage(systemName: "chevron.down", withConfiguration: dismissConfig)
        dismissButton.setImage(dismissIcon, for: .normal)
        dismissButton.tintColor = .secondaryLabel
        dismissButton.addTarget(self, action: #selector(handleDismissTap), for: .touchUpInside)
        addSubview(dismissButton)

        calloutView.delegate = self
        addSubview(calloutView)

        setupGlideGesture()
        buildCurrentLayout()
    }


    @objc private func handleOneHandedSwap() {
        let current = vBoardSettings.shared.oneHandedMode
        vBoardSettings.shared.oneHandedMode = (current == .left) ? .right : .left
        HapticManager.shared.playSpecialKey()
        vBoardSettings.shared.notifySettingsChanged()
        setNeedsLayout()
        layoutIfNeeded()
    }

    @objc private func handleOneHandedExpand() {
        vBoardSettings.shared.oneHandedMode = .off
        HapticManager.shared.playSpecialKey()
        vBoardSettings.shared.notifySettingsChanged()
        setNeedsLayout()
        layoutIfNeeded()
    }

    public func setShiftState(_ active: Bool) {
        if isShiftActive != active && !isCapsLockActive {
            isShiftActive = active
            buildCurrentLayout()
            updateSuggestionsCase()
        }
    }

    @objc private func handleDismissTap() {
        HapticManager.shared.playSpecialKey()
        delegate?.keyboardViewDidDismiss(self)
    }

    private func setupGlideGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleGlidePan(_:)))
        pan.cancelsTouchesInView = false
        pan.delegate = self
        addGestureRecognizer(pan)
        self.panGesture = pan
    }

    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == panGesture {
            // Không bao giờ bắt đầu vuốt nếu tính năng Glide Typing chưa được bật trong cài đặt
            guard vBoardSettings.shared.isGlideTypingEnabled else { return false }

            // Tuyệt đối không bắt đầu vuốt nếu Callout popup đang hiển thị
            if calloutView.isVisible {
                return false
            }

            let isOverlayOpen = (textEditingView != nil && !textEditingView!.isHidden) ||
                                (quickSettingsView != nil && !quickSettingsView!.isHidden) ||
                                (clipboardView != nil && !clipboardView!.isHidden) ||
                                (emojiPickerView != nil && !emojiPickerView!.isHidden)
            if isOverlayOpen || isNumberPadActive || isNumberLayerActive || isDeveloperModeActive {
                return false
            }

            // Chỉ cho phép kích hoạt cử chỉ vuốt nếu bắt đầu trên phím chữ cái (a..z)
            let loc = gestureRecognizer.location(in: self)
            if let hitKey = findNearestKeyView(at: loc),
               case .character(let charStr) = hitKey.key.type,
               let first = charStr.first,
               first.isLetter {
                return true
            } else {
                return false
            }
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer == panGesture {
            // Không nhận touch cho vuốt nếu tính năng Glide Typing đang tắt
            guard vBoardSettings.shared.isGlideTypingEnabled else { return false }

            // Không nhận touch nếu Callout popup đang mở
            if calloutView.isVisible {
                return false
            }

            let isOverlayOpen = (textEditingView != nil && !textEditingView!.isHidden) ||
                                (quickSettingsView != nil && !quickSettingsView!.isHidden) ||
                                (clipboardView != nil && !clipboardView!.isHidden) ||
                                (emojiPickerView != nil && !emojiPickerView!.isHidden)
            if isOverlayOpen || isNumberPadActive || isNumberLayerActive || isDeveloperModeActive {
                return false
            }

            // Chặn cử chỉ vuốt nếu chạm vào thanh công cụ hoặc bất kỳ màn hình lớp phủ nào
            if let v = touch.view {
                if v.isDescendant(of: suggestionBar) {
                    return false
                }
                if let cv = clipboardView, v.isDescendant(of: cv) {
                    return false
                }
                if let tev = textEditingView, v.isDescendant(of: tev) {
                    return false
                }
                if let qs = quickSettingsView, v.isDescendant(of: qs) {
                    return false
                }
                if let ep = emojiPickerView, v.isDescendant(of: ep) {
                    return false
                }
                if v.isDescendant(of: calloutView) {
                    return false
                }
            }

            // Chỉ nhận touch nếu điểm chạm ban đầu nằm trên phím chữ cái
            let loc = touch.location(in: self)
            if let hitKey = findNearestKeyView(at: loc),
               case .character(let charStr) = hitKey.key.type,
               let first = charStr.first,
               first.isLetter {
                return true
            } else {
                return false
            }
        }
        return true
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == panGesture {
            // Tuyệt đối không cho phép nhận diện đồng thời với cử chỉ cuộn danh sách (UIScrollView)
            if otherGestureRecognizer.view is UIScrollView {
                return false
            }
            let isOverlayOpen = (textEditingView != nil && !textEditingView!.isHidden) ||
                                (quickSettingsView != nil && !quickSettingsView!.isHidden) ||
                                (clipboardView != nil && !clipboardView!.isHidden) ||
                                (emojiPickerView != nil && !emojiPickerView!.isHidden)
            if isOverlayOpen || calloutView.isVisible {
                return false
            }
        }
        return true
    }

    public func cancelAllKeyLongPresses() {
        if calloutView.isVisible { return }
        for row in rowViews {
            for kv in row {
                kv.cancelLongPress()
            }
        }
        calloutView.dismiss()
    }

    @objc private func handleGlidePan(_ pan: UIPanGestureRecognizer) {
        let isOverlayOpen = (textEditingView != nil && !textEditingView!.isHidden) ||
                            (quickSettingsView != nil && !quickSettingsView!.isHidden) ||
                            (clipboardView != nil && !clipboardView!.isHidden) ||
                            (emojiPickerView != nil && !emojiPickerView!.isHidden)
        guard vBoardSettings.shared.isGlideTypingEnabled,
              !isNumberPadActive,
              !isNumberLayerActive,
              !isDeveloperModeActive,
              !isOverlayOpen,
              !calloutView.isVisible else {
            glideTrailLayer.clear()
            isGlideTrackingActive = false
            glideTrackedChars.removeAll()
            return
        }

        let loc = pan.location(in: self)

        switch pan.state {
        case .began:
            guard let hitKey = findNearestKeyView(at: loc),
                  case .character(let charStr) = hitKey.key.type,
                  let first = charStr.first,
                  first.isLetter else {
                pan.state = .cancelled
                return
            }
            if !calloutView.isVisible {
                cancelAllKeyLongPresses()
            }
            isGlideTrackingActive = false
            glideTrackedChars.removeAll()
            glideTrailLayer.clear()
            lastGlidePoint = loc
            glideTrackedChars.append(first)

        case .changed:
            guard !calloutView.isVisible else { return }
            let translation = pan.translation(in: self)
            let distance = hypot(translation.x, translation.y)
            if distance > 6.0 {
                if !isGlideTrackingActive {
                    isGlideTrackingActive = true
                    cancelAllKeyLongPresses()
                }
            }

            if isGlideTrackingActive {
                if vBoardSettings.shared.isGlideTrailEnabled {
                    glideTrailLayer.addPoint(loc)
                }

                // Nội suy các điểm giữa lastGlidePoint và loc để không bỏ sót phím khi vuốt nhanh
                let totalDist = hypot(loc.x - lastGlidePoint.x, loc.y - lastGlidePoint.y)
                let stepDist: CGFloat = 16.0
                let steps = max(1, Int(ceil(totalDist / stepDist)))

                for i in 1...steps {
                    let t = CGFloat(i) / CGFloat(steps)
                    let interpX = lastGlidePoint.x + (loc.x - lastGlidePoint.x) * t
                    let interpY = lastGlidePoint.y + (loc.y - lastGlidePoint.y) * t
                    let samplePt = CGPoint(x: interpX, y: interpY)

                    if let hitView = findNearestKeyView(at: samplePt),
                       case .character(let charStr) = hitView.key.type,
                       let ch = charStr.first {
                        if glideTrackedChars.last != ch {
                            glideTrackedChars.append(ch)
                        }
                    }
                }
                lastGlidePoint = loc
            }

        case .ended:
            if isGlideTrackingActive && glideTrackedChars.count >= 2 {
                // Đảm bảo phím cuối cùng tại điểm kết thúc được ghi nhận
                if let lastHit = findNearestKeyView(at: loc),
                   case .character(let charStr) = lastHit.key.type,
                   let lastChar = charStr.first {
                    if glideTrackedChars.last != lastChar {
                        glideTrackedChars.append(lastChar)
                    }
                }

                let rawMatches = WordTrie.shared.matchGlide(keySequence: glideTrackedChars, limit: 3)
                let matches = rawMatches.map { self.formatSuggestionText($0) }
                if let bestWord = matches.first {
                    HapticManager.shared.playSpecialKey()
                    delegate?.keyboardView(self, didGlideWord: bestWord)
                    suggestionBar.setSuggestions(matches)
                    resetShiftIfNeeded()
                }
            }
            glideTrailLayer.fadeOut()
            isGlideTrackingActive = false
            lastGlideCompletedTimestamp = CACurrentMediaTime()
            glideTrackedChars.removeAll()

        case .cancelled, .failed:
            glideTrailLayer.fadeOut()
            isGlideTrackingActive = false
            glideTrackedChars.removeAll()

        default:
            break
        }
    }

    // MARK: - Extended Edge Hit-Testing (Chấm dứt lỗi trượt phím A và L mép viền & Bảo vệ Overlay)
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if calloutView.isVisible {
            return super.hitTest(point, with: event)
        }

        // 1. Kiểm tra màn hình Điều hướng văn bản (TextEditingView)
        if let tev = textEditingView, !tev.isHidden, tev.alpha > 0.01 {
            let pt = convert(point, to: tev)
            if tev.point(inside: pt, with: event) {
                return tev.hitTest(pt, with: event)
            }
        }

        // 2. Kiểm tra màn hình Cài đặt nhanh (QuickSettingsView)
        if let qs = quickSettingsView, !qs.isHidden, qs.alpha > 0.01 {
            let pt = convert(point, to: qs)
            if qs.point(inside: pt, with: event) {
                return qs.hitTest(pt, with: event)
            }
        }

        // 3. Kiểm tra màn hình Bảng tạm (ClipboardView)
        if let cv = clipboardView, !cv.isHidden, cv.alpha > 0.01 {
            let pt = convert(point, to: cv)
            if cv.point(inside: pt, with: event) {
                return cv.hitTest(pt, with: event)
            }
        }

        // 4. Kiểm tra màn hình Emoji (EmojiPickerView)
        if let epv = emojiPickerView, !epv.isHidden, epv.alpha > 0.01 {
            let pt = convert(point, to: epv)
            if epv.point(inside: pt, with: event) {
                return epv.hitTest(pt, with: event)
            }
        }

        // 5. Nếu đang mở overlay toàn màn hình, tuyệt đối không cho phép chạm xuyên qua xuống bàn phím
        if (textEditingView != nil && !textEditingView!.isHidden) ||
           (quickSettingsView != nil && !quickSettingsView!.isHidden) ||
           (clipboardView != nil && !clipboardView!.isHidden) ||
           (emojiPickerView != nil && !emojiPickerView!.isHidden) {
            return nil
        }

        // 4. Thanh gợi ý / công cụ trên cùng
        if !suggestionBar.isHidden && suggestionBar.frame.contains(point) {
            return suggestionBar.hitTest(convert(point, to: suggestionBar), with: event)
        }

        // 5. Phím hạ bàn phím
        if !dismissButton.isHidden && dismissButton.frame.contains(point) {
            return dismissButton
        }

        // 6. Nhận diện phím bấm bàn phím
        if let nearestKey = findNearestKeyView(at: point) {
            return nearestKey
        }

        return super.hitTest(point, with: event)
    }

    public func findNearestKeyView(at point: CGPoint) -> KeyView? {
        guard !rowViews.isEmpty else { return nil }

        // Tìm hàng phím có khoảng cách tâm dọc (midY) gần điểm chạm nhất (tránh lỗi giao thoa nuốt phím A và L)
        var closestRowIndex = 0
        var minRowDiff: CGFloat = .greatestFiniteMagnitude
        for (rIdx, row) in rowViews.enumerated() {
            guard let firstKey = row.first else { continue }
            let diff = abs(point.y - firstKey.frame.midY)
            if diff < minRowDiff {
                minRowDiff = diff
                closestRowIndex = rIdx
            }
        }

        let row = rowViews[closestRowIndex]
        guard let firstKey = row.first, let lastKey = row.last else { return nil }

        // Mở rộng viền trái tuyệt đối ra sát mép màn hình (x: 0) cho phím đầu hàng (đặc biệt phím A mép trái)
        if point.x <= firstKey.frame.maxX {
            return firstKey
        }
        // Mở rộng viền phải tuyệt đối ra sát mép màn hình (x: bounds.width) cho phím cuối hàng (đặc biệt phím L mép phải)
        if point.x >= lastKey.frame.minX {
            return lastKey
        }

        return findClosestKeyInRow(row, x: point.x)
    }

    private func findClosestKeyInRow(_ row: [KeyView], x: CGFloat) -> KeyView? {
        var closestKey: KeyView?
        var minDiff: CGFloat = .greatestFiniteMagnitude

        for keyView in row {
            if x >= keyView.frame.minX && x <= keyView.frame.maxX {
                return keyView
            }
            let diff = abs(x - keyView.frame.midX)
            if diff < minDiff {
                minDiff = diff
                closestKey = keyView
            }
        }
        return closestKey
    }

    public func refreshLayout() {
        buildCurrentLayout()
    }

    private func buildCurrentLayout() {
        // Xóa các view cũ
        for row in rowViews {
            for kv in row {
                kv.removeFromSuperview()
            }
        }
        rowViews.removeAll()
        globeKeyView = nil

        if isNumberPadActive {
            currentRows = makeDedicatedNumberPadLayout()
        } else if isDeveloperModeActive {
            currentRows = makeDeveloperLayout()
        } else if isNumberLayerActive {
            currentRows = isSymbolsLayerActive ? makeSymbolsLayout() : makeNumberLayout()
        } else {
            currentRows = makeLetterLayout(isShift: isShiftActive || isCapsLockActive)
        }

        for row in currentRows {
            var viewsInRow: [KeyView] = []
            for key in row {
                let kv = KeyView(key: key)
                kv.delegate = self
                addSubview(kv)
                viewsInRow.append(kv)

                // Gắn cử chỉ đặc biệt
                if case .space = key.type {
                    spaceCursorHandler?.attach(to: kv)
                } else if case .delete = key.type {
                    backspaceSwipeHandler?.attach(to: kv)
                } else if case .globe = key.type {
                    globeKeyView = kv
                }
            }
            rowViews.append(viewsInRow)
        }

        bringSubviewToFront(suggestionBar)
        setNeedsLayout()
    }

    private func makeLetterLayout(isShift: Bool) -> [[KeyboardKey]] {
        let settings = vBoardSettings.shared
        var rows: [[KeyboardKey]] = []

        let hasNumberRow = settings.isNumberRowEnabled || isNumberRowActive
        if hasNumberRow {
            let numberRow = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map { KeyboardKey.char($0) }
            rows.append(numberRow)
        }

        let r1Chars = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
        let r1SecNumber = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
        let r1SecSymbols = ["%", "\\", "|", "=", "[", "]", "<", ">", "{", "}"]

        let r2Chars = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
        let r2Sec = ["@", "#", "đ", "_", "&", "-", "+", "(", ")"]

        let r3Chars = ["z", "x", "c", "v", "b", "n", "m"]
        let r3Sec = ["*", "\"", "'", ":", ";", "!", "?"]

        let r1Sec = hasNumberRow ? r1SecSymbols : r1SecNumber

        let row1 = zip(r1Chars, r1Sec).map { char, sec in
            KeyboardKey.char(isShift ? char.uppercased() : char, secondary: sec)
        }

        let row2 = zip(r2Chars, r2Sec).map { char, sec in
            KeyboardKey.char(isShift ? char.uppercased() : char, secondary: sec)
        }

        var row3: [KeyboardKey] = [KeyboardKey.shift(isCapsLocked: isCapsLockActive, isShiftActive: isShiftActive, weight: 1.55)]
        row3.append(contentsOf: zip(r3Chars, r3Sec).map { char, sec in
            KeyboardKey.char(isShift ? char.uppercased() : char, secondary: sec)
        })
        row3.append(KeyboardKey.delete(weight: 1.55))

        let isGlobeHidden = settings.isGlobeKeyHidden
        let isCommaEnabled = settings.isCommaKeyEnabled
        let isPeriodEnabled = settings.isPeriodKeyEnabled

        var row4: [KeyboardKey] = [
            KeyboardKey.modeSwitch("?123", weight: 1.55)
        ]
        if isCommaEnabled {
            row4.append(KeyboardKey.char(",", secondary: "☺", weight: 1.0))
        }
        if !isGlobeHidden {
            row4.append(KeyboardKey.globe(weight: 1.0))
        } else {
            row4.append(KeyboardKey.emoji(weight: 1.0))
        }
        row4.append(KeyboardKey.space(label: "Tiếng Việt", weight: 4.0))
        if isPeriodEnabled {
            row4.append(KeyboardKey.char(".", weight: 1.0))
        }
        row4.append(KeyboardKey.returnKey(actionType: currentReturnKeyType, label: "nhập", weight: 1.55))

        rows.append(row1)
        rows.append(row2)
        rows.append(row3)
        rows.append(row4)

        return rows
    }

    private func makeNumberLayout() -> [[KeyboardKey]] {
        let r1 = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map { KeyboardKey.char($0) }
        let r2 = ["@", "#", "đ", "_", "&", "-", "+", "(", ")", "/"].map { KeyboardKey.char($0) }

        var r3: [KeyboardKey] = [KeyboardKey.modeSwitch("=\\<", weight: 1.55)]
        r3.append(contentsOf: ["*", "\"", "'", ":", ";", "!", "?"].map { KeyboardKey.char($0) })
        r3.append(KeyboardKey.delete(weight: 1.55))

        let row4: [KeyboardKey] = [
            KeyboardKey.modeSwitch("ABC", weight: 1.55),
            KeyboardKey.char(",", weight: 1.0),
            KeyboardKey.modeSwitch("12/34", weight: 1.0),
            KeyboardKey.space(label: "Tiếng Việt", weight: 4.0),
            KeyboardKey.char(".", weight: 1.0),
            KeyboardKey.returnKey(actionType: currentReturnKeyType, label: "nhập", weight: 1.55)
        ]

        return [r1, r2, r3, row4]
    }

    private func makeSymbolsLayout() -> [[KeyboardKey]] {
        let r1 = ["~", "`", "|", "•", "√", "π", "÷", "×", "§", "Δ"].map { KeyboardKey.char($0) }
        let r2 = ["£", "€", "$", "¢", "^", "°", "=", "{", "}", "\\"].map { KeyboardKey.char($0) }

        var r3: [KeyboardKey] = [KeyboardKey.modeSwitch("?123", weight: 1.55)]
        r3.append(contentsOf: ["%", "©", "®", "™", "✓", "[", "]"].map { KeyboardKey.char($0) })
        r3.append(KeyboardKey.delete(weight: 1.55))

        let row4: [KeyboardKey] = [
            KeyboardKey.modeSwitch("ABC", weight: 1.55),
            KeyboardKey.char("←", weight: 1.0),
            KeyboardKey.modeSwitch("12/34", weight: 1.0),
            KeyboardKey.space(label: "Tiếng Việt", weight: 4.0),
            KeyboardKey.char("→", weight: 1.0),
            KeyboardKey.returnKey(actionType: currentReturnKeyType, label: "nhập", weight: 1.55)
        ]

        return [r1, r2, r3, row4]
    }

    private func makeDedicatedNumberPadLayout() -> [[KeyboardKey]] {
        let r1 = ["1", "2", "3", "-"].map { KeyboardKey.char($0, weight: 1.0) }
        let r2 = ["4", "5", "6", "+"].map { KeyboardKey.char($0, weight: 1.0) }
        let r3: [KeyboardKey] = [
            KeyboardKey.char("7", weight: 1.0),
            KeyboardKey.char("8", weight: 1.0),
            KeyboardKey.char("9", weight: 1.0),
            KeyboardKey.delete(weight: 1.0)
        ]
        let r4: [KeyboardKey] = [
            KeyboardKey.modeSwitch("ABC", weight: 1.0),
            KeyboardKey.char("0", weight: 1.0),
            KeyboardKey.char(".", weight: 1.0),
            KeyboardKey.returnKey(actionType: currentReturnKeyType, label: "nhập", weight: 1.0)
        ]

        return [r1, r2, r3, r4]
    }

    private func makeDeveloperLayout() -> [[KeyboardKey]] {
        let r1 = ["Tab", "{", "}", "[", "]", "(", ")", "<", ">", "/", "\\"].map { KeyboardKey.char($0, weight: 1.0) }
        let r2 = ["=", "+", "-", "*", "&", "|", "!", "~", "^", "%", "$"].map { KeyboardKey.char($0, weight: 1.0) }
        var r3: [KeyboardKey] = [KeyboardKey.shift(isCapsLocked: isCapsLockActive, isShiftActive: isShiftActive, weight: 1.2)]
        r3.append(contentsOf: ["_", ":", ";", "'", "\"", "`", "?", "#"].map { KeyboardKey.char($0, weight: 1.0) })
        r3.append(KeyboardKey.delete(weight: 1.2))
        let r4: [KeyboardKey] = [
            KeyboardKey.modeSwitch("ABC", weight: 1.2),
            KeyboardKey.char("⇤", weight: 1.0),
            KeyboardKey.char("←", weight: 1.0),
            KeyboardKey.space(label: "Code", weight: 3.2),
            KeyboardKey.char("→", weight: 1.0),
            KeyboardKey.char("⇥", weight: 1.0),
            KeyboardKey.returnKey(actionType: currentReturnKeyType, label: "↵", weight: 1.2)
        ]

        return [r1, r2, r3, r4]
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard !rowViews.isEmpty else { return }

        let isDark = traitCollection.userInterfaceStyle == .dark
        backgroundColor = isDark ? UIColor(red: 30/255, green: 31/255, blue: 34/255, alpha: 1.0) : UIColor(red: 241/255, green: 243/255, blue: 244/255, alpha: 1.0)

        if let tev = textEditingView, !tev.isHidden {
            tev.frame = bounds
            bringSubviewToFront(tev)
        }
        if let qs = quickSettingsView, !qs.isHidden {
            qs.frame = bounds
            bringSubviewToFront(qs)
        }
        if let cv = clipboardView, !cv.isHidden {
            cv.frame = bounds
            bringSubviewToFront(cv)
        }
        if let epv = emojiPickerView, !epv.isHidden {
            epv.frame = bounds
            bringSubviewToFront(epv)
        }

        let isOverlayOpen = (textEditingView != nil && !textEditingView!.isHidden) ||
                            (quickSettingsView != nil && !quickSettingsView!.isHidden) ||
                            (clipboardView != nil && !clipboardView!.isHidden) ||
                            (emojiPickerView != nil && !emojiPickerView!.isHidden)

        let hasSuggestionBar = vBoardSettings.shared.isSuggestionBarEnabled && !isNumberPadActive
        suggestionBar.isHidden = !hasSuggestionBar || isOverlayOpen

        var topPadding: CGFloat = 3.0
        if hasSuggestionBar {
            let barHeight: CGFloat = 34.0
            suggestionBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: barHeight)
            topPadding = barHeight + 3.0
        }

        if !suggestionBar.isHidden {
            bringSubviewToFront(suggestionBar)
        }

        glideTrailLayer.frame = bounds

        let bottomSafeInset = max(safeAreaInsets.bottom, 0)
        let bottomPadding: CGFloat = bottomSafeInset > 0 ? max(bottomSafeInset - 6.0, 4.0) : 4.0
        let sideMargin: CGFloat = 3.0
        let keySpacing: CGFloat = 5.0
        let rowSpacing: CGFloat = 5.0

        if bottomPadding > 12 {
            dismissButton.isHidden = false
            dismissButton.frame = CGRect(x: 14, y: bounds.height - bottomPadding + 2, width: 36, height: 26)
        } else {
            dismissButton.isHidden = true
        }

        let availableHeight = bounds.height - topPadding - bottomPadding
        let rowCount = CGFloat(rowViews.count)
        let rowHeight = max(32.0, (availableHeight - (rowCount - 1) * rowSpacing) / rowCount)

        var currentY = topPadding

        // One-Handed Mode calculation
        let oneHanded = vBoardSettings.shared.oneHandedMode
        let isOneHandedActive = (oneHanded != .off)
        let keyboardWidth = isOneHandedActive ? bounds.width * 0.84 : bounds.width
        let keyboardOriginX: CGFloat
        let sidePanelWidth = bounds.width * 0.16

        if oneHanded == .left {
            keyboardOriginX = 0
            oneHandedSidePanel.frame = CGRect(x: keyboardWidth, y: topPadding, width: sidePanelWidth, height: availableHeight)
            oneHandedSidePanel.isHidden = false
        } else if oneHanded == .right {
            keyboardOriginX = sidePanelWidth
            oneHandedSidePanel.frame = CGRect(x: 0, y: topPadding, width: sidePanelWidth, height: availableHeight)
            oneHandedSidePanel.isHidden = false
        } else {
            keyboardOriginX = 0
            oneHandedSidePanel.isHidden = true
        }

        if !oneHandedSidePanel.isHidden {
            let halfH = availableHeight / 2.0
            oneHandedSwapButton.frame = CGRect(x: 0, y: 0, width: sidePanelWidth, height: halfH)
            oneHandedExpandButton.frame = CGRect(x: 0, y: halfH, width: sidePanelWidth, height: halfH)
            bringSubviewToFront(oneHandedSidePanel)
        }

        // Gradient Layer handling
        let theme = vBoardSettings.shared.colorTheme
        if theme.isGradient {
            gradientLayer.frame = bounds
            gradientLayer.isHidden = false
            switch theme {
            case .gradientPastelRose:
                gradientLayer.colors = [UIColor(red: 255/255, green: 229/255, blue: 236/255, alpha: 1.0).cgColor, UIColor(red: 240/255, green: 230/255, blue: 255/255, alpha: 1.0).cgColor]
            case .gradientSkyBreeze:
                gradientLayer.colors = [UIColor(red: 224/255, green: 242/255, blue: 254/255, alpha: 1.0).cgColor, UIColor(red: 237/255, green: 233/255, blue: 254/255, alpha: 1.0).cgColor]
            case .gradientMintWhisper:
                gradientLayer.colors = [UIColor(red: 230/255, green: 255/255, blue: 250/255, alpha: 1.0).cgColor, UIColor(red: 235/255, green: 248/255, blue: 255/255, alpha: 1.0).cgColor]
            case .gradientTwilightPurple:
                gradientLayer.colors = [UIColor(red: 30/255, green: 27/255, blue: 75/255, alpha: 1.0).cgColor, UIColor(red: 49/255, green: 46/255, blue: 129/255, alpha: 1.0).cgColor]
            case .gradientDeepOcean:
                gradientLayer.colors = [UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0).cgColor, UIColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 1.0).cgColor]
            case .gradientSunsetGlow:
                gradientLayer.colors = [UIColor(red: 45/255, green: 27/255, blue: 54/255, alpha: 1.0).cgColor, UIColor(red: 74/255, green: 21/255, blue: 75/255, alpha: 1.0).cgColor]
            default:
                break
            }
        } else {
            gradientLayer.isHidden = true
        }

        let standard10Spacing = 9.0 * keySpacing
        let standardAvailableWidth = keyboardWidth - (sideMargin * 2) - standard10Spacing
        let stdKeyWidth = standardAvailableWidth / 10.0
        let row3AvailableForKeys = keyboardWidth - (sideMargin * 2) - (8.0 * keySpacing)
        let sideFunctionKeyWidth = max(stdKeyWidth * 1.5, (row3AvailableForKeys - (7.0 * stdKeyWidth)) / 2.0)

        for (rowIndex, row) in rowViews.enumerated() {
            let totalKeyCount = CGFloat(row.count)
            let isStandardKeyboard = !isNumberPadActive && !isDeveloperModeActive
            let isRow4 = isStandardKeyboard && rowIndex == (rowViews.count - 1)
            let isRow3 = isStandardKeyboard && rowIndex == (rowViews.count - 2)
            let isLetterRow2 = isStandardKeyboard && rowIndex == (rowViews.count - 3) && !isNumberLayerActive

            if isRow4 {
                // Row 4 (Hàng đáy): ?123 / ABC (sideFunctionKeyWidth) + phím giữa + Return (sideFunctionKeyWidth)
                let firstKeyWidth = sideFunctionKeyWidth
                let lastKeyWidth = sideFunctionKeyWidth
                let middleKeys = row.dropFirst().dropLast()
                let totalMiddleSpacing = CGFloat(row.count - 1) * keySpacing
                let remainingForMiddle = keyboardWidth - (sideMargin * 2) - firstKeyWidth - lastKeyWidth - totalMiddleSpacing

                // Phím giữa cố định (phẩy, chấm, chuyển ngữ): 1 stdKeyWidth; Space co dãn
                let nonSpaceCount = CGFloat(middleKeys.filter { $0.key.type != .space }.count)
                let nonSpaceWidth = nonSpaceCount * stdKeyWidth
                let spaceWidth = max(stdKeyWidth * 2.0, remainingForMiddle - nonSpaceWidth)

                var currentX = keyboardOriginX + sideMargin
                for (idx, keyView) in row.enumerated() {
                    let w: CGFloat
                    if idx == 0 {
                        w = firstKeyWidth
                    } else if idx == row.count - 1 {
                        w = lastKeyWidth
                        // Căn thẳng hàng tuyệt đối với mép phải
                        currentX = keyboardOriginX + keyboardWidth - sideMargin - lastKeyWidth
                    } else if case .space = keyView.key.type {
                        w = spaceWidth
                    } else {
                        w = stdKeyWidth
                    }
                    keyView.frame = CGRect(
                        x: round(currentX),
                        y: round(currentY),
                        width: round(w),
                        height: round(rowHeight)
                    )
                    currentX += w + keySpacing
                }
            } else if isRow3 {
                // Row 3: Shift (sideFunctionKeyWidth) + 7 ký tự (stdKeyWidth) + Delete (sideFunctionKeyWidth)
                // Đảm bảo phím Shift bề ngang BẰNG ĐÚNG phím ?123, và phím Xóa bề ngang BẰNG ĐÚNG phím Enter
                var currentX = keyboardOriginX + sideMargin
                for (idx, keyView) in row.enumerated() {
                    let w: CGFloat
                    if idx == 0 {
                        w = sideFunctionKeyWidth
                    } else if idx == row.count - 1 {
                        w = sideFunctionKeyWidth
                        // Căn thẳng hàng tuyệt đối với phím Enter ngay bên dưới
                        currentX = keyboardOriginX + keyboardWidth - sideMargin - sideFunctionKeyWidth
                    } else {
                        w = stdKeyWidth
                    }
                    keyView.frame = CGRect(
                        x: round(currentX),
                        y: round(currentY),
                        width: round(w),
                        height: round(rowHeight)
                    )
                    currentX += w + keySpacing
                }
            } else if isLetterRow2 {
                // Row 2 (a .. l): Thụt đều 0.5 phím hai bên mép
                let row2Width = (9.0 * stdKeyWidth) + (8.0 * keySpacing)
                var currentX = keyboardOriginX + (keyboardWidth - row2Width) / 2.0

                for keyView in row {
                    keyView.frame = CGRect(
                        x: round(currentX),
                        y: round(currentY),
                        width: round(stdKeyWidth),
                        height: round(rowHeight)
                    )
                    currentX += stdKeyWidth + keySpacing
                }
            } else {
                let totalSpacing = (totalKeyCount - 1) * keySpacing
                let availableWidth = keyboardWidth - (sideMargin * 2) - totalSpacing
                let totalFlexWeight = row.reduce(0.0) { $0 + $1.key.flexWeight }
                let unitWidth = availableWidth / totalFlexWeight

                var currentX = keyboardOriginX + sideMargin

                for keyView in row {
                    let keyWidth = unitWidth * keyView.key.flexWeight
                    keyView.frame = CGRect(
                        x: round(currentX),
                        y: round(currentY),
                        width: round(keyWidth),
                        height: round(rowHeight)
                    )
                    currentX += keyWidth + keySpacing
                }
            }

            currentY += rowHeight + rowSpacing
        }
    }

    // MARK: - Suggestion Casing & Shift Helpers
    public func formatSuggestionText(_ text: String) -> String {
        let lower = text.lowercased()
        if isCapsLockActive {
            return lower.uppercased()
        } else if isShiftActive {
            guard let first = lower.first else { return lower }
            return String(first).uppercased() + lower.dropFirst()
        } else {
            return lower
        }
    }

    public func updateSuggestionsCase() {
        guard !suggestionBar.currentSuggestions.isEmpty else { return }
        let updated = suggestionBar.currentSuggestions.map { formatSuggestionText($0) }
        suggestionBar.setSuggestions(updated)
    }

    public func resetShiftIfNeeded() {
        if isShiftActive && !isCapsLockActive && !isNumberLayerActive {
            isShiftActive = false
            buildCurrentLayout()
            updateSuggestionsCase()
        }
    }

    public func keyViewDidTap(_ keyView: KeyView) {
        // Bỏ qua sự kiện tap nếu đang vuốt Glide hoặc vừa kết thúc vuốt trong 0.25s
        if isGlideTrackingActive || (CACurrentMediaTime() - lastGlideCompletedTimestamp < 0.25) {
            return
        }

        let key = keyView.key

        switch key.type {
        case .shift:
            let now = Date().timeIntervalSince1970
            if now - lastShiftTapTime < 0.35 {
                isCapsLockActive.toggle()
                isShiftActive = isCapsLockActive
            } else {
                if isCapsLockActive {
                    isCapsLockActive = false
                    isShiftActive = false
                } else {
                    isShiftActive.toggle()
                }
            }
            lastShiftTapTime = now
            buildCurrentLayout()
            HapticManager.shared.playSpecialKey()
            updateSuggestionsCase()

        case .character(let charStr):
            if isSymbolsLayerActive {
                if charStr == "←" || charStr == "<" {
                    HapticManager.shared.playCursorTick()
                    delegate?.keyboardView(self, didPressKey: KeyboardKey.char("←"))
                    return
                } else if charStr == "→" || charStr == ">" {
                    HapticManager.shared.playCursorTick()
                    delegate?.keyboardView(self, didPressKey: KeyboardKey.char("→"))
                    return
                }
            }
            if charStr == "'" && vBoardSettings.shared.isAutoSwitchToABCAfterApostropheEnabled && (isNumberLayerActive || isSymbolsLayerActive) {
                setLettersMode()
            }
            if isShiftActive && !isCapsLockActive && !isNumberLayerActive {
                isShiftActive = false
                buildCurrentLayout()
                updateSuggestionsCase()
            }
            delegate?.keyboardView(self, didPressKey: key)

        case .modeSwitch(let label):
            hideEmojiPickerView()
            if label == "123" || label == "?123" {
                isNumberPadActive = false
                isNumberLayerActive = true
                isSymbolsLayerActive = false
            } else if label == "#+=" || label == "=\\<" {
                isNumberPadActive = false
                isNumberLayerActive = true
                isSymbolsLayerActive = true
            } else if label == "ABC" {
                isNumberPadActive = false
                isNumberLayerActive = false
                isSymbolsLayerActive = false
                isDeveloperModeActive = false
            } else if label == "12/34" {
                setNumberPadMode(true)
                HapticManager.shared.playSpecialKey()
                return
            }
            buildCurrentLayout()
            HapticManager.shared.playSpecialKey()

        case .globe:
            delegate?.keyboardViewDidRequestNextKeyboard(self)

        case .emoji:
            HapticManager.shared.playSpecialKey()
            delegate?.keyboardViewDidRequestEmojiPicker(self)

        case .dismiss:
            handleDismissTap()

        case .space, .delete, .returnKey:
            if isShiftActive && !isCapsLockActive && !isNumberLayerActive {
                isShiftActive = false
                buildCurrentLayout()
                updateSuggestionsCase()
            }
            delegate?.keyboardView(self, didPressKey: key)
        }
    }

    public func keyViewDidLongPress(_ keyView: KeyView) {
        if case .modeSwitch(let label) = keyView.key.type, label == "?123" {
            HapticManager.shared.playSpecialKey()
            setDeveloperMode(!isDeveloperModeActive)
            return
        }
        self.keyView(keyView, didRequestCalloutFor: keyView.key)
    }

    // MARK: - KeyView Callout Delegate Methods
    public func keyView(_ keyView: KeyView, didRequestCalloutFor key: KeyboardKey) {
        let isShift = isShiftActive || isCapsLockActive
        let char = key.displayLabel
        var items = KeyCalloutView.calloutItems(for: char, isShift: isShift)

        // Nếu phím có ký tự phụ secondaryLabel (ví dụ: hàng số tắt thì p có secondary "0"):
        if let sec = key.secondaryLabel {
            if items == nil {
                items = [sec, char]
            } else if !items!.contains(sec) {
                items!.insert(sec, at: 0)
            }
        }

        guard let calloutItems = items, !calloutItems.isEmpty else { return }

        // Xác định defaultIndex phù hợp nhất:
        var defaultIdx = 0
        if char == "." {
            // Đối với dấu chấm ".", ưu tiên chọn dấu phẩy "," (index 14) hoặc "?" (index 15) giống hình mẫu Gboard
            if let commaIdx = calloutItems.firstIndex(of: ",") {
                defaultIdx = commaIdx
            } else if let qIdx = calloutItems.firstIndex(of: "?") {
                defaultIdx = qIdx
            }
        } else if char == "," {
            if let dotIdx = calloutItems.firstIndex(of: ".") {
                defaultIdx = dotIdx
            } else if let qIdx = calloutItems.firstIndex(of: "?") {
                defaultIdx = qIdx
            }
        } else if let sec = key.secondaryLabel, let secIdx = calloutItems.firstIndex(of: sec) {
            defaultIdx = secIdx
        }

        calloutView.show(items: calloutItems, defaultIndex: defaultIdx, sourceKey: keyView, in: self)
        bringSubviewToFront(calloutView)
    }

    public func keyView(_ keyView: KeyView, didUpdateCalloutTouch point: CGPoint) {
        calloutView.updateTouchLocation(point)
    }

    public func keyViewDidEndCallout(_ keyView: KeyView) -> String? {
        if let selected = calloutView.commitSelection() {
            HapticManager.shared.playKeyTap()
            if selected == "⚙️" {
                showQuickSettingsView(delegate: delegate as? QuickSettingsViewDelegate)
                return selected
            } else if selected == "📱" {
                let cur = vBoardSettings.shared.oneHandedMode
                vBoardSettings.shared.oneHandedMode = (cur == .off) ? .right : .off
                vBoardSettings.shared.notifySettingsChanged()
                return selected
            }
            let simulatedKey = KeyboardKey.char(selected)
            delegate?.keyboardView(self, didPressKey: simulatedKey)
            return selected
        }
        return nil
    }

    public func keyViewDidCancelCallout(_ keyView: KeyView) {
        calloutView.dismiss()
    }

    // MARK: - KeyCalloutViewDelegate
    public func keyCalloutView(_ calloutView: KeyCalloutView, didSelectItem text: String) {
        if text == "⚙️" {
            showQuickSettingsView(delegate: delegate as? QuickSettingsViewDelegate)
            return
        } else if text == "📱" {
            let cur = vBoardSettings.shared.oneHandedMode
            vBoardSettings.shared.oneHandedMode = (cur == .off) ? .right : .off
            vBoardSettings.shared.notifySettingsChanged()
            return
        }
        let simulatedKey = KeyboardKey.char(text)
        delegate?.keyboardView(self, didPressKey: simulatedKey)
    }

    public func keyCalloutViewDidDismiss(_ calloutView: KeyCalloutView) {
    }

    // MARK: - TextEditingViewDelegate
    public func textEditingViewDidRequestClose(_ view: TextEditingView) {
        hideTextEditingView()
    }
}
#endif
