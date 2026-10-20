#if canImport(UIKit)
import UIKit
import vBoardEngine

@MainActor
public protocol KeyViewDelegate: AnyObject {
    func keyViewDidTap(_ keyView: KeyView)
    func keyViewDidLongPress(_ keyView: KeyView)
    func keyView(_ keyView: KeyView, didRequestCalloutFor key: KeyboardKey)
    func keyView(_ keyView: KeyView, didUpdateCalloutTouch point: CGPoint)
    func keyViewDidEndCallout(_ keyView: KeyView) -> String?
    func keyViewDidCancelCallout(_ keyView: KeyView)
}

@MainActor
public final class KeyView: UIControl {
    public let key: KeyboardKey
    public weak var delegate: KeyViewDelegate?

    private let label = UILabel()
    private let secondaryLabel = UILabel()
    private let secondaryIconView = UIImageView()
    private let iconImageView = UIImageView()
    private var longPressTimer: Timer?
    private var isLongPressedTriggered = false
    private var isCalloutActive = false
    private var initialTouchPoint: CGPoint = .zero
    private var hasMovedBeyondTapThreshold = false
    private var didFlickDown = false

    public init(key: KeyboardKey) {
        self.key = key
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        // Bo góc mềm mại chuẩn Gboard Material You
        layer.cornerRadius = 8.0
        layer.masksToBounds = false

        // Đổ bóng thanh mảnh, tinh tế chuẩn Material You
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 1.2)
        layer.shadowRadius = 1.0

        // Nhãn chính giữa phím
        label.text = key.displayLabel
        label.textAlignment = .center
        label.isUserInteractionEnabled = false
        label.font = fontForKey(key)
        addSubview(label)

        // Vector Icon (SF Symbols) cho các phím chức năng
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.isUserInteractionEnabled = false
        addSubview(iconImageView)

        // Nhãn phụ (góc trên phải - ví dụ số 1..0 hoặc ký tự đặc biệt)
        if let secondary = key.secondaryLabel {
            if secondary == "☺" {
                secondaryIconView.image = KeyboardIcons.emojiSmileIcon(size: CGSize(width: 10, height: 10))
                secondaryIconView.contentMode = .scaleAspectFit
                secondaryIconView.isUserInteractionEnabled = false
                addSubview(secondaryIconView)
            } else if secondary == "dismiss" || secondary == "⤓" {
                secondaryIconView.image = KeyboardIcons.dismissIcon(size: CGSize(width: 10, height: 8))
                secondaryIconView.contentMode = .scaleAspectFit
                secondaryIconView.isUserInteractionEnabled = false
                addSubview(secondaryIconView)
            } else {
                secondaryLabel.text = secondary
                secondaryLabel.textAlignment = .center
                secondaryLabel.font = UIFont.systemFont(ofSize: 9.5, weight: .medium)
                secondaryLabel.isUserInteractionEnabled = false
                addSubview(secondaryLabel)
            }
        }

        updateTheme()
    }

    private func fontForKey(_ key: KeyboardKey) -> UIFont {
        let settings = vBoardSettings.shared
        let scale = CGFloat(settings.fontSizeScale)
        let baseSize: CGFloat
        let weight: UIFont.Weight

        switch key.type {
        case .character:
            baseSize = 21.0 * scale
            weight = .regular
        case .space:
            baseSize = 13.0 * scale
            weight = .regular
        case .shift, .delete:
            baseSize = 17.0 * scale
            weight = .medium
        case .modeSwitch:
            baseSize = 15.0 * scale
            weight = .regular
        case .returnKey, .emoji, .dismiss:
            baseSize = 15.0 * scale
            weight = .regular
        }

        switch settings.fontFamily {
        case .system:
            return UIFont.systemFont(ofSize: baseSize, weight: weight)
        case .rounded:
            if let desc = UIFont.systemFont(ofSize: baseSize, weight: weight).fontDescriptor.withDesign(.rounded) {
                return UIFont(descriptor: desc, size: baseSize)
            }
            return UIFont.systemFont(ofSize: baseSize, weight: weight)
        case .mono:
            return UIFont.monospacedSystemFont(ofSize: baseSize, weight: weight)
        case .serif:
            if let desc = UIFont.systemFont(ofSize: baseSize, weight: weight).fontDescriptor.withDesign(.serif) {
                return UIFont(descriptor: desc, size: baseSize)
            }
            return UIFont.systemFont(ofSize: baseSize, weight: weight)
        }
    }

    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Mở rộng vùng chạm cạnh viền (đặc biệt cho phím A ở mép trái và L ở mép phải)
        let touchArea = bounds.insetBy(dx: -14.0, dy: -6.0)
        return touchArea.contains(point)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds
        
        // Phím Return/Action bo viên thuốc chuẩn Gboard Material You
        if case .returnKey = key.type {
            layer.cornerRadius = bounds.height / 2.0
        } else {
            layer.cornerRadius = 8.0
        }

        let iconDim: CGFloat = 19.0
        iconImageView.frame = CGRect(
            x: round((bounds.width - iconDim) / 2.0),
            y: round((bounds.height - iconDim) / 2.0),
            width: iconDim,
            height: iconDim
        )

        if secondaryLabel.superview != nil {
            let secW: CGFloat = 13.0
            let secH: CGFloat = 12.0
            secondaryLabel.frame = CGRect(x: bounds.width - secW - 2.5, y: 2.5, width: secW, height: secH)
        }
        if secondaryIconView.superview != nil {
            let iconDim: CGFloat = 10.0
            secondaryIconView.frame = CGRect(x: bounds.width - iconDim - 3.0, y: 3.5, width: iconDim, height: iconDim)
        }
    }

    private func parseHexColor(_ hex: String) -> UIColor? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }

    public func updateTheme() {
        let settings = vBoardSettings.shared
        label.font = fontForKey(key)
        let isDark: Bool
        switch settings.themeMode {
        case .light: isDark = false
        case .dark: isDark = true
        case .system: isDark = (traitCollection.userInterfaceStyle == .dark)
        }

        // Viền phím (Key Border Toggle)
        let hasBorder = settings.isKeyBorderEnabled
        layer.shadowOpacity = hasBorder ? 0.15 : 0.0
        layer.borderWidth = hasBorder ? 0.5 : 0.0
        layer.borderColor = (isDark ? UIColor.white.withAlphaComponent(0.08) : UIColor.black.withAlphaComponent(0.08)).cgColor

        // Bảng màu theo Theme đã chọn
        var darkCharBg = UIColor(red: 54/255, green: 56/255, blue: 61/255, alpha: 1.0)
        var darkSpecialBg = UIColor(red: 40/255, green: 41/255, blue: 45/255, alpha: 1.0)
        var darkText = UIColor.white
        var darkSecondary = UIColor(red: 154/255, green: 160/255, blue: 166/255, alpha: 1.0)

        var lightCharBg = UIColor.white
        var lightSpecialBg = UIColor(red: 211/255, green: 227/255, blue: 253/255, alpha: 1.0)
        var lightText = UIColor(red: 31/255, green: 31/255, blue: 31/255, alpha: 1.0)
        var lightSecondary = UIColor(red: 95/255, green: 99/255, blue: 104/255, alpha: 1.0)

        switch settings.colorTheme {
        case .pitchBlack:
            darkCharBg = UIColor(red: 20/255, green: 20/255, blue: 20/255, alpha: 1.0)
            darkSpecialBg = UIColor(red: 10/255, green: 10/255, blue: 10/255, alpha: 1.0)
            layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        case .paperWhite:
            lightCharBg = UIColor(red: 250/255, green: 250/255, blue: 250/255, alpha: 1.0)
            lightSpecialBg = UIColor(red: 235/255, green: 238/255, blue: 242/255, alpha: 1.0)
        case .midnightNavy:
            darkCharBg = UIColor(red: 28/255, green: 37/255, blue: 65/255, alpha: 1.0)
            darkSpecialBg = UIColor(red: 18/255, green: 25/255, blue: 45/255, alpha: 1.0)
            darkSecondary = UIColor(red: 140/255, green: 160/255, blue: 190/255, alpha: 1.0)
        case .cyberpunk:
            darkCharBg = UIColor(red: 26/255, green: 20/255, blue: 45/255, alpha: 1.0)
            darkSpecialBg = UIColor(red: 18/255, green: 14/255, blue: 36/255, alpha: 1.0)
            darkText = UIColor(red: 0/255, green: 245/255, blue: 255/255, alpha: 1.0)
            darkSecondary = UIColor(red: 255/255, green: 110/255, blue: 200/255, alpha: 1.0)
            layer.borderColor = UIColor(red: 0/255, green: 245/255, blue: 255/255, alpha: 0.35).cgColor
        default:
            break
        }

        let secColor = isDark ? darkSecondary : lightSecondary
        secondaryLabel.textColor = secColor
        secondaryIconView.tintColor = secColor
        secondaryLabel.isHidden = !settings.isHintSymbolsEnabled
        secondaryIconView.isHidden = !settings.isHintSymbolsEnabled

        let isBottomPunctuation: Bool
        if case .character(let s) = key.type, (s == "," || s == ".") {
            isBottomPunctuation = true
        } else {
            isBottomPunctuation = false
        }

        switch key.type {
        case .character:
            if isBottomPunctuation {
                backgroundColor = isDark ? darkSpecialBg : lightSpecialBg
                label.textColor = isDark ? darkText : lightText
            } else {
                backgroundColor = isDark ? darkCharBg : lightCharBg
                label.textColor = isDark ? darkText : lightText
            }
            label.isHidden = false
            iconImageView.isHidden = true

        case .space:
            backgroundColor = isDark ? darkCharBg : lightCharBg
            label.textColor = isDark ? darkSecondary : lightSecondary
            label.isHidden = false
            iconImageView.isHidden = true

        case .delete:
            backgroundColor = isDark ? darkSpecialBg : lightSpecialBg
            label.isHidden = true
            iconImageView.isHidden = false
            iconImageView.image = KeyboardIcons.deleteIcon()
            iconImageView.tintColor = isDark ? darkText : lightText

        case .shift:
            backgroundColor = isDark ? darkSpecialBg : lightSpecialBg
            label.isHidden = true
            iconImageView.isHidden = false
            let isCaps = (key.displayLabel == "⇪")
            let isShift = (key.displayLabel == "⬆")
            iconImageView.image = KeyboardIcons.shiftIcon(isCapsLocked: isCaps, isShiftActive: isShift)
            iconImageView.tintColor = isDark ? darkText : lightText

        case .emoji:
            backgroundColor = isDark ? darkSpecialBg : lightSpecialBg
            label.isHidden = true
            iconImageView.isHidden = false
            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            iconImageView.image = UIImage(systemName: "face.smiling", withConfiguration: config)
            iconImageView.tintColor = isDark ? darkText : lightText

        case .dismiss:
            backgroundColor = isDark ? darkSpecialBg : lightSpecialBg
            label.isHidden = true
            iconImageView.isHidden = false
            iconImageView.image = KeyboardIcons.dismissIcon()
            iconImageView.tintColor = isDark ? darkText : lightText

        case .modeSwitch:
            backgroundColor = isDark ? darkSpecialBg : lightSpecialBg
            label.textColor = isDark ? darkText : lightText
            label.isHidden = false
            iconImageView.isHidden = true

        case .returnKey:
            label.isHidden = true
            iconImageView.isHidden = false

            let isSearch = (key.returnKeyType == .search)
            let searchColor = UIColor(red: 80/255, green: 194/255, blue: 178/255, alpha: 1.0)
            let defaultBlue = UIColor(red: 26/255, green: 115/255, blue: 232/255, alpha: 1.0)
            let accent = parseHexColor(settings.accentColorHex) ?? defaultBlue

            backgroundColor = isSearch ? searchColor : accent
            iconImageView.tintColor = isSearch ? UIColor(red: 17/255, green: 17/255, blue: 17/255, alpha: 1.0) : UIColor.white
            iconImageView.image = KeyboardIcons.returnIcon(type: key.returnKeyType)
        }
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateTheme()
    }

    // MARK: - Touch Tracking & Long Press

    private var previewPopup: UIView?
    private var repeatDeleteTimer: Timer?
    private var didRepeatDelete = false

    private func showPreviewPopup() {
        guard case .character = key.type, vBoardSettings.shared.isKeyPreviewEnabled else { return }
        hidePreviewPopup()

        let isDark = traitCollection.userInterfaceStyle == .dark
        let popup = UIView()
        popup.backgroundColor = isDark ? UIColor(white: 0.28, alpha: 1.0) : UIColor.white
        popup.layer.cornerRadius = 9.0
        popup.layer.shadowColor = UIColor.black.cgColor
        popup.layer.shadowOpacity = 0.35
        popup.layer.shadowOffset = CGSize(width: 0, height: 2.0)
        popup.layer.shadowRadius = 5.0
        popup.isUserInteractionEnabled = false

        let popupWidth = bounds.width * 1.35
        let popupHeight: CGFloat = 56.0
        popup.frame = CGRect(
            x: (bounds.width - popupWidth) / 2.0,
            y: -popupHeight + 8.0,
            width: popupWidth,
            height: popupHeight
        )

        let charLabel = UILabel(frame: CGRect(x: 0, y: 4, width: popupWidth, height: 38))
        charLabel.text = key.displayLabel
        charLabel.textAlignment = .center
        charLabel.font = UIFont.systemFont(ofSize: 30.0, weight: .regular)
        charLabel.textColor = isDark ? .white : .black
        popup.addSubview(charLabel)

        addSubview(popup)
        self.previewPopup = popup
    }

    private func hidePreviewPopup() {
        previewPopup?.removeFromSuperview()
        previewPopup = nil
    }

    // MARK: - Nhấn giữ Backspace xóa liên tục (Repeat Delete)
    private func startRepeatDeleteTimer() {
        guard case .delete = key.type, vBoardSettings.shared.isContinuousDeleteEnabled else { return }
        repeatDeleteTimer?.invalidate()
        didRepeatDelete = false

        // Đè giữ 0.35s thì bắt đầu vòng lặp xóa lùi liên tục
        repeatDeleteTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, self.isHighlighted else { return }
                self.startContinuousDeleteCycle()
            }
        }
    }

    private func startContinuousDeleteCycle() {
        repeatDeleteTimer?.invalidate()
        // Mỗi 0.08s (80ms) xóa lùi 1 ký tự
        repeatDeleteTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self, self.isHighlighted else {
                    self?.stopRepeatDeleteTimer()
                    return
                }
                self.didRepeatDelete = true
                HapticManager.shared.playSpecialKey()
                SoundManager.shared.playKeyClick()
                self.delegate?.keyViewDidTap(self)
            }
        }
    }

    public func stopRepeatDeleteTimer() {
        repeatDeleteTimer?.invalidate()
        repeatDeleteTimer = nil
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        initialTouchPoint = touch.location(in: self)
        isHighlighted = true
        isLongPressedTriggered = false
        isCalloutActive = false
        hasMovedBeyondTapThreshold = false
        didFlickDown = false
        showPreviewPopup()
        HapticManager.shared.playKeyTap()
        SoundManager.shared.playKeyClick()

        if case .delete = key.type {
            startRepeatDeleteTimer()
        }

        // Nhấn giữ theo cấu hình (mặc định 250ms chuẩn Gboard)
        let delaySec = max(0.15, Double(vBoardSettings.shared.longPressDelayMs) / 1000.0)
        longPressTimer?.invalidate()

        let hasCallout = (KeyCalloutView.calloutItems(for: key.displayLabel, isShift: false) != nil) || (key.secondaryLabel != nil)
        if hasCallout {
            longPressTimer = Timer.scheduledTimer(withTimeInterval: delaySec, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self = self, self.isHighlighted, !self.hasMovedBeyondTapThreshold else { return }
                    self.isLongPressedTriggered = true
                    self.hidePreviewPopup()
                    self.isCalloutActive = true
                    HapticManager.shared.playSpecialKey()
                    self.delegate?.keyView(self, didRequestCalloutFor: self.key)
                }
            }
        } else if case .modeSwitch = key.type {
            // Trường hợp 3: Phím chuyển chế độ (?123) nhấn giữ để chuyển Dev Mode
            longPressTimer = Timer.scheduledTimer(withTimeInterval: delaySec, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self = self, self.isHighlighted, !self.hasMovedBeyondTapThreshold else { return }
                    self.isLongPressedTriggered = true
                    self.hidePreviewPopup()
                    self.delegate?.keyViewDidLongPress(self)
                }
            }
        } else if case .space = key.type {
            // Trường hợp 4: Phím Space
            longPressTimer = Timer.scheduledTimer(withTimeInterval: delaySec, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self = self, self.isHighlighted, !self.hasMovedBeyondTapThreshold else { return }
                    self.isLongPressedTriggered = true
                    self.delegate?.keyViewDidLongPress(self)
                }
            }
        }
    }

    /// Hủy bỏ nhấn giữ ngay lập tức (dùng khi vuốt Glide hoặc nhận diện cử chỉ khác)
    public func cancelLongPress() {
        longPressTimer?.invalidate()
        longPressTimer = nil
        stopRepeatDeleteTimer()
        isLongPressedTriggered = false
        isCalloutActive = false
        hidePreviewPopup()
        isHighlighted = false
        hasMovedBeyondTapThreshold = true
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        let currentPoint = touch.location(in: self)
        let dist = hypot(currentPoint.x - initialTouchPoint.x, currentPoint.y - initialTouchPoint.y)

        if isCalloutActive {
            let ptInSelf = touch.location(in: self)
            let ptInTarget = convert(ptInSelf, to: delegate as? UIView ?? superview)
            delegate?.keyView(self, didUpdateCalloutTouch: ptInTarget)
        } else {
            let dy = currentPoint.y - initialTouchPoint.y
            let dx = abs(currentPoint.x - initialTouchPoint.x)

            // Nhận diện cử chỉ Flick Down chỉ khi vuốt thuần túy thẳng xuống và chưa trượt ngang
            if vBoardSettings.shared.isFlickDownEnabled, !didFlickDown, !hasMovedBeyondTapThreshold, let sec = key.secondaryLabel, dy > 16.0, dy > 2.2 * dx {
                didFlickDown = true
                hasMovedBeyondTapThreshold = true
                cancelLongPress()
                HapticManager.shared.playSpecialKey()
                // ⤓ = lệnh đóng bàn phím (dismissKeyboard), KHÔNG phải ký tự để gõ
                if sec == "⤓" || sec == "dismiss" {
                    delegate?.keyViewDidTap(KeyView(key: KeyboardKey.dismiss()))
                } else {
                    let simulatedKey = KeyboardKey.char(sec)
                    delegate?.keyViewDidTap(KeyView(key: simulatedKey))
                }
                return
            }

            if dist > 8.0 {
                hasMovedBeyondTapThreshold = true
                cancelLongPress()
            }
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        isHighlighted = false
        hidePreviewPopup()
        stopRepeatDeleteTimer()
        longPressTimer?.invalidate()

        if didFlickDown {
            didFlickDown = false
            return
        }

        if isCalloutActive {
            isCalloutActive = false
            _ = delegate?.keyViewDidEndCallout(self)
        } else if !isLongPressedTriggered && !hasMovedBeyondTapThreshold {
            if case .delete = key.type {
                if !didRepeatDelete {
                    delegate?.keyViewDidTap(self)
                }
            } else {
                delegate?.keyViewDidTap(self)
            }
        }
        didRepeatDelete = false
        hasMovedBeyondTapThreshold = false
        didFlickDown = false
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        isHighlighted = false
        hidePreviewPopup()
        stopRepeatDeleteTimer()
        longPressTimer?.invalidate()

        if didFlickDown {
            didFlickDown = false
            return
        }
        hasMovedBeyondTapThreshold = false
        didFlickDown = false

        if isCalloutActive {
            isCalloutActive = false
            delegate?.keyViewDidCancelCallout(self)
        }
        didRepeatDelete = false
    }

    public override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.7 : 1.0
        }
    }

    public func setTemporaryHighlight(_ highlighted: Bool) {
        if highlighted {
            transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
            alpha = 0.75
            layer.borderColor = UIColor.systemTeal.cgColor
            layer.borderWidth = 1.5
        } else {
            transform = .identity
            alpha = 1.0
            layer.borderWidth = 0.0
            updateTheme()
        }
    }
}
#endif
