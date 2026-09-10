#if canImport(UIKit)
import UIKit
import vBoardEngine

@MainActor
public protocol QuickSettingsViewDelegate: AnyObject {
    func quickSettingsDidRequestClose(_ view: QuickSettingsView)
    func quickSettingsDidChangeConfiguration(_ view: QuickSettingsView)
}

/// Bảng điều khiển cài đặt nhanh trực tiếp ngay trên bàn phím (Instant in-keyboard settings)
public final class QuickSettingsView: UIView {
    public weak var delegate: QuickSettingsViewDelegate?

    private let scrollView = UIScrollView()
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    // Sizing segment buttons
    private var sizeButtons: [UIButton] = []
    // Input method buttons
    private var methodButtons: [UIButton] = []

    // Toggle buttons
    private let numberRowButton = UIButton(type: .system)
    private let hideGlobeButton = UIButton(type: .system)
    private let glideButton = UIButton(type: .system)
    private let suggestionButton = UIButton(type: .system)

    // OpenKey Quick Toggles
    private let spellingCheckButton = UIButton(type: .system)
    private let diacriticStyleButton = UIButton(type: .system)
    private let macroButton = UIButton(type: .system)
    private let quickTelexButton = UIButton(type: .system)

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.97)
        layer.cornerRadius = 8.0
        layer.masksToBounds = true

        // Tiêu đề
        titleLabel.text = "Cài đặt nhanh vBoard"
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .label
        addSubview(titleLabel)

        // Nút đóng
        let xmarkConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: xmarkConfig), for: .normal)
        closeButton.tintColor = .secondaryLabel
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        addSubview(closeButton)

        scrollView.showsVerticalScrollIndicator = false
        addSubview(scrollView)

        buildControls()
        updateUIState()
    }

    private func buildControls() {
        // Section: Chiều cao
        let heightTitle = createSectionLabel(text: "Kích thước bàn phím:")
        scrollView.addSubview(heightTitle)

        let scales = KeyboardHeightScale.allCases
        for scale in scales {
            let btn = UIButton(type: .system)
            let shortName: String
            switch scale {
            case .verySmall: shortName = "R.Nhỏ"
            case .small: shortName = "Nhỏ"
            case .medium: shortName = "Vừa"
            case .large: shortName = "Lớn"
            case .veryLarge: shortName = "R.Lớn"
            }
            btn.setTitle(shortName, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            btn.layer.cornerRadius = 6
            btn.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                vBoardSettings.shared.keyboardHeightScale = scale
                HapticManager.shared.playKeyTap()
                self.updateUIState()
                self.delegate?.quickSettingsDidChangeConfiguration(self)
            }, for: .touchUpInside)
            scrollView.addSubview(btn)
            sizeButtons.append(btn)
        }

        // Section: Hàng số & Ẩn quả cầu
        setupToggleRow(button: numberRowButton, labelText: "Hàng số trên cùng (1..0):") { [weak self] in
            guard let self = self else { return }
            vBoardSettings.shared.isNumberRowEnabled.toggle()
            HapticManager.shared.playKeyTap()
            self.updateUIState()
            self.delegate?.quickSettingsDidChangeConfiguration(self)
        }

        setupToggleRow(button: hideGlobeButton, labelText: "Ẩn nút quả cầu 🌐 (Mở rộng Space):") { [weak self] in
            guard let self = self else { return }
            vBoardSettings.shared.isGlobeKeyHidden.toggle()
            HapticManager.shared.playKeyTap()
            self.updateUIState()
            self.delegate?.quickSettingsDidChangeConfiguration(self)
        }

        // Section: Kiểu gõ
        let methodTitle = createSectionLabel(text: "Kiểu gõ tiếng Việt:")
        scrollView.addSubview(methodTitle)

        let methods: [(InputMethod, String)] = [
            (.telex, "Telex"),
            (.vni, "VNI"),
            (.simpleTelex, "Simple")
        ]
        for (m, title) in methods {
            let btn = UIButton(type: .system)
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            btn.layer.cornerRadius = 6
            btn.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                vBoardSettings.shared.inputMethod = m
                HapticManager.shared.playKeyTap()
                self.updateUIState()
                self.delegate?.quickSettingsDidChangeConfiguration(self)
            }, for: .touchUpInside)
            scrollView.addSubview(btn)
            methodButtons.append(btn)
        }

        // Section: Gõ lướt & Gợi ý từ
        setupToggleRow(button: glideButton, labelText: "Gõ lướt cử chỉ (Glide Typing):") { [weak self] in
            guard let self = self else { return }
            vBoardSettings.shared.isGlideTypingEnabled.toggle()
            HapticManager.shared.playKeyTap()
            self.updateUIState()
            self.delegate?.quickSettingsDidChangeConfiguration(self)
        }

        setupToggleRow(button: suggestionButton, labelText: "Thanh gợi ý từ thông minh:") { [weak self] in
            guard let self = self else { return }
            vBoardSettings.shared.isSuggestionBarEnabled.toggle()
            HapticManager.shared.playKeyTap()
            self.updateUIState()
            self.delegate?.quickSettingsDidChangeConfiguration(self)
        }

        // Section: OpenKey Bộ gõ & Gõ tắt
        setupToggleRow(button: spellingCheckButton, labelText: "Kiểm tra chính tả tiếng Việt:") { [weak self] in
            guard let self = self else { return }
            vBoardSettings.shared.isSpellingCheckEnabled.toggle()
            HapticManager.shared.playKeyTap()
            self.updateUIState()
            self.delegate?.quickSettingsDidChangeConfiguration(self)
        }

        setupToggleRow(button: diacriticStyleButton, labelText: "Dấu kiểu mới (òa, úy):") { [weak self] in
            guard let self = self else { return }
            let current = vBoardSettings.shared.diacriticStyle
            vBoardSettings.shared.diacriticStyle = (current == .newStyle) ? .oldStyle : .newStyle
            HapticManager.shared.playKeyTap()
            self.updateUIState()
            self.delegate?.quickSettingsDidChangeConfiguration(self)
        }

        setupToggleRow(button: macroButton, labelText: "Cho phép gõ tắt (Macro):") { [weak self] in
            guard let self = self else { return }
            vBoardSettings.shared.isShortcutExpansionEnabled.toggle()
            HapticManager.shared.playKeyTap()
            self.updateUIState()
            self.delegate?.quickSettingsDidChangeConfiguration(self)
        }

        setupToggleRow(button: quickTelexButton, labelText: "Gõ nhanh phụ âm (Quick Telex):") { [weak self] in
            guard let self = self else { return }
            vBoardSettings.shared.isQuickTelexEnabled.toggle()
            HapticManager.shared.playKeyTap()
            self.updateUIState()
            self.delegate?.quickSettingsDidChangeConfiguration(self)
        }
    }

    private func createSectionLabel(text: String) -> UILabel {
        let lbl = UILabel()
        lbl.text = text
        lbl.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        lbl.textColor = .secondaryLabel
        return lbl
    }

    private func setupToggleRow(button: UIButton, labelText: String, action: @escaping () -> Void) {
        let lbl = UILabel()
        lbl.text = labelText
        lbl.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        lbl.textColor = .label
        lbl.tag = 100
        scrollView.addSubview(lbl)

        button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        button.layer.cornerRadius = 6
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        scrollView.addSubview(button)
    }

    public func updateUIState() {
        let settings = vBoardSettings.shared

        // Cập nhật Size buttons
        let currentScale = settings.keyboardHeightScale
        let scales = KeyboardHeightScale.allCases
        for (i, btn) in sizeButtons.enumerated() {
            if i < scales.count && scales[i] == currentScale {
                btn.backgroundColor = .systemBlue
                btn.setTitleColor(.white, for: .normal)
            } else {
                btn.backgroundColor = .secondarySystemFill
                btn.setTitleColor(.label, for: .normal)
            }
        }

        // Cập nhật Method buttons
        let currentMethod = settings.inputMethod
        let methods: [InputMethod] = [.telex, .vni, .simpleTelex]
        for (i, btn) in methodButtons.enumerated() {
            if i < methods.count && methods[i] == currentMethod {
                btn.backgroundColor = .systemBlue
                btn.setTitleColor(.white, for: .normal)
            } else {
                btn.backgroundColor = .secondarySystemFill
                btn.setTitleColor(.label, for: .normal)
            }
        }

        // Cập nhật Toggle buttons
        updateToggleButton(numberRowButton, isOn: settings.isNumberRowEnabled)
        updateToggleButton(hideGlobeButton, isOn: settings.isGlobeKeyHidden)
        updateToggleButton(glideButton, isOn: settings.isGlideTypingEnabled)
        updateToggleButton(suggestionButton, isOn: settings.isSuggestionBarEnabled)
        updateToggleButton(spellingCheckButton, isOn: settings.isSpellingCheckEnabled)
        updateToggleButton(diacriticStyleButton, isOn: settings.diacriticStyle == .newStyle)
        updateToggleButton(macroButton, isOn: settings.isShortcutExpansionEnabled)
        updateToggleButton(quickTelexButton, isOn: settings.isQuickTelexEnabled)
    }

    private func updateToggleButton(_ btn: UIButton, isOn: Bool) {
        btn.setTitle(isOn ? "BẬT" : "TẮT", for: .normal)
        btn.backgroundColor = isOn ? UIColor.systemGreen.withAlphaComponent(0.2) : UIColor.secondarySystemFill
        btn.setTitleColor(isOn ? .systemGreen : .secondaryLabel, for: .normal)
    }

    @objc private func handleClose() {
        HapticManager.shared.playKeyTap()
        delegate?.quickSettingsDidRequestClose(self)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        let w = bounds.width
        let h = bounds.height

        titleLabel.frame = CGRect(x: 16, y: 8, width: w - 60, height: 26)
        closeButton.frame = CGRect(x: w - 40, y: 6, width: 30, height: 30)

        scrollView.frame = CGRect(x: 12, y: 36, width: w - 24, height: h - 40)

        var curY: CGFloat = 4.0
        let contentW = scrollView.frame.width

        // Sizing
        if let heightLbl = scrollView.subviews.compactMap({ $0 as? UILabel }).first(where: { $0.text == "Kích thước bàn phím:" }) {
            heightLbl.frame = CGRect(x: 0, y: curY, width: contentW, height: 18)
            curY += 22.0

            let btnW = (contentW - CGFloat(sizeButtons.count - 1) * 6.0) / CGFloat(sizeButtons.count)
            for (i, btn) in sizeButtons.enumerated() {
                btn.frame = CGRect(x: CGFloat(i) * (btnW + 6.0), y: curY, width: btnW, height: 28)
            }
            curY += 34.0
        }

        // Toggle rows
        curY = layoutToggleRow(button: numberRowButton, labelText: "Hàng số trên cùng (1..0):", startY: curY, width: contentW)
        curY = layoutToggleRow(button: hideGlobeButton, labelText: "Ẩn nút quả cầu 🌐 (Mở rộng Space):", startY: curY, width: contentW)

        // Method
        if let methodLbl = scrollView.subviews.compactMap({ $0 as? UILabel }).first(where: { $0.text == "Kiểu gõ tiếng Việt:" }) {
            methodLbl.frame = CGRect(x: 0, y: curY, width: contentW, height: 18)
            curY += 22.0

            let btnW = (contentW - CGFloat(methodButtons.count - 1) * 6.0) / CGFloat(methodButtons.count)
            for (i, btn) in methodButtons.enumerated() {
                btn.frame = CGRect(x: CGFloat(i) * (btnW + 6.0), y: curY, width: btnW, height: 28)
            }
            curY += 34.0
        }

        curY = layoutToggleRow(button: glideButton, labelText: "Gõ lướt cử chỉ (Glide Typing):", startY: curY, width: contentW)
        curY = layoutToggleRow(button: suggestionButton, labelText: "Thanh gợi ý từ thông minh:", startY: curY, width: contentW)
        curY = layoutToggleRow(button: spellingCheckButton, labelText: "Kiểm tra chính tả tiếng Việt:", startY: curY, width: contentW)
        curY = layoutToggleRow(button: diacriticStyleButton, labelText: "Dấu kiểu mới (òa, úy):", startY: curY, width: contentW)
        curY = layoutToggleRow(button: macroButton, labelText: "Cho phép gõ tắt (Macro):", startY: curY, width: contentW)
        curY = layoutToggleRow(button: quickTelexButton, labelText: "Gõ nhanh phụ âm (Quick Telex):", startY: curY, width: contentW)

        scrollView.contentSize = CGSize(width: contentW, height: curY + 10.0)
    }

    private func layoutToggleRow(button: UIButton, labelText: String, startY: CGFloat, width: CGFloat) -> CGFloat {
        if let lbl = scrollView.subviews.compactMap({ $0 as? UILabel }).first(where: { $0.text == labelText }) {
            let btnW: CGFloat = 60.0
            lbl.frame = CGRect(x: 0, y: startY + 4, width: width - btnW - 8, height: 20)
            button.frame = CGRect(x: width - btnW, y: startY, width: btnW, height: 26)
            return startY + 32.0
        }
        return startY
    }
}
#endif
