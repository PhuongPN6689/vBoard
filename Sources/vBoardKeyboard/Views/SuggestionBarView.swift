#if canImport(UIKit)
import UIKit
import vBoardEngine

@MainActor
public protocol SuggestionBarViewDelegate: AnyObject {
    func suggestionBar(_ bar: SuggestionBarView, didSelectWord word: String)
    func suggestionBar(_ bar: SuggestionBarView, didSelectClipboardText text: String)
    func suggestionBarDidTapSettings(_ bar: SuggestionBarView)
    func suggestionBarDidTapTextEditing(_ bar: SuggestionBarView)
    func suggestionBarDidTapDeveloperMode(_ bar: SuggestionBarView)
}

public final class SuggestionBarView: UIView {
    public weak var delegate: SuggestionBarViewDelegate?

    private var currentSuggestions: [String] = []
    private var isClipboardMode: Bool = false

    // Normal mode views - dùng Vector SF Symbols
    private let menuButton = UIButton(type: .system) // 4-square grid icon
    private let clipboardButton = UIButton(type: .system)
    private let textEditingButton = UIButton(type: .system)
    private let developerButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    private let micButton = UIButton(type: .system)
    private var suggestionButtons: [UIButton] = []
    private let dividerLayer1 = CALayer()
    private let dividerLayer2 = CALayer()
    private let separatorLayer = CALayer()

    // Clipboard mode views
    private let clipboardScrollView = UIScrollView()
    private let closeClipboardButton = UIButton(type: .system)
    private var isToolsExpanded: Bool = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear

        // Đường kẻ phân cách mỏng ở đáy
        separatorLayer.backgroundColor = UIColor.separator.cgColor
        layer.addSublayer(separatorLayer)

        dividerLayer1.backgroundColor = UIColor.separator.cgColor
        dividerLayer2.backgroundColor = UIColor.separator.cgColor
        layer.addSublayer(dividerLayer1)
        layer.addSublayer(dividerLayer2)

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)

        // Nút Menu 4 ô vuông chuẩn Gboard (Vector SF Symbol)
        let menuIcon = UIImage(systemName: "square.grid.2x2.fill", withConfiguration: symbolConfig) ?? UIImage(systemName: "square.grid.2x2", withConfiguration: symbolConfig)
        menuButton.setImage(menuIcon, for: .normal)
        menuButton.tintColor = .secondaryLabel
        menuButton.addTarget(self, action: #selector(toggleToolsMenu), for: .touchUpInside)
        addSubview(menuButton)

        // Nút Clipboard (Vector SF Symbol)
        let clipIcon = UIImage(systemName: "doc.on.clipboard", withConfiguration: symbolConfig)
        clipboardButton.setImage(clipIcon, for: .normal)
        clipboardButton.tintColor = .secondaryLabel
        clipboardButton.addTarget(self, action: #selector(toggleClipboardMode), for: .touchUpInside)
        addSubview(clipboardButton)

        // Nút Text Editing D-Pad ‹I›
        let editIcon = UIImage(systemName: "arrow.up.and.down.and.arrow.left.and.right", withConfiguration: symbolConfig) ?? UIImage(systemName: "pencil", withConfiguration: symbolConfig)
        textEditingButton.setImage(editIcon, for: .normal)
        textEditingButton.tintColor = .secondaryLabel
        textEditingButton.addTarget(self, action: #selector(handleTextEditingTap), for: .touchUpInside)
        addSubview(textEditingButton)

        // Nút Developer Mode </>
        let devIcon = UIImage(systemName: "chevron.left.forwardslash.chevron.right", withConfiguration: symbolConfig) ?? UIImage(systemName: "curlybraces", withConfiguration: symbolConfig)
        developerButton.setImage(devIcon, for: .normal)
        developerButton.tintColor = .secondaryLabel
        developerButton.addTarget(self, action: #selector(handleDeveloperTap), for: .touchUpInside)
        addSubview(developerButton)

        // Nút Cài đặt ⚙️ (Vector SF Symbol)
        let gearIcon = UIImage(systemName: "gearshape.fill", withConfiguration: symbolConfig)
        settingsButton.setImage(gearIcon, for: .normal)
        settingsButton.tintColor = .secondaryLabel
        settingsButton.addTarget(self, action: #selector(handleSettingsTap), for: .touchUpInside)
        addSubview(settingsButton)

        // Nút Microphone 🎙️ (Vector SF Symbol)
        let micIcon = UIImage(systemName: "mic.fill", withConfiguration: symbolConfig)
        micButton.setImage(micIcon, for: .normal)
        micButton.tintColor = .secondaryLabel
        micButton.addTarget(self, action: #selector(handleMicTap), for: .touchUpInside)
        addSubview(micButton)

        // 3 nút gợi ý từ
        for i in 0..<3 {
            let btn = UIButton(type: .system)
            btn.titleLabel?.font = (i == 1) ? UIFont.systemFont(ofSize: 15, weight: .semibold) : UIFont.systemFont(ofSize: 14, weight: .regular)
            btn.setTitleColor(UIColor.label, for: .normal)
            btn.tag = i
            btn.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
            addSubview(btn)
            suggestionButtons.append(btn)
        }

        // Clipboard ScrollView
        clipboardScrollView.showsHorizontalScrollIndicator = false
        clipboardScrollView.isHidden = true
        addSubview(clipboardScrollView)

        // Nút Đóng Bảng tạm ✕ (Vector SF Symbol)
        let xIcon = UIImage(systemName: "xmark.circle.fill", withConfiguration: symbolConfig)
        closeClipboardButton.setImage(xIcon, for: .normal)
        closeClipboardButton.tintColor = .secondaryLabel
        closeClipboardButton.addTarget(self, action: #selector(toggleClipboardMode), for: .touchUpInside)
        closeClipboardButton.isHidden = true
        addSubview(closeClipboardButton)
    }

    @objc private func handleMicTap() {
        HapticManager.shared.playSpecialKey()
        // Kiểm tra pasteboard hoặc nhắc mở Dictation
        if let clip = UIPasteboard.general.string, !clip.isEmpty {
            delegate?.suggestionBar(self, didSelectClipboardText: clip)
        }
    }

    public func setSuggestions(_ words: [String]) {
        currentSuggestions = words
        let hasWords = !words.isEmpty
        dividerLayer1.isHidden = words.count < 2 || isClipboardMode || isToolsExpanded
        dividerLayer2.isHidden = words.count < 3 || isClipboardMode || isToolsExpanded

        for (i, btn) in suggestionButtons.enumerated() {
            if i < words.count && !isToolsExpanded && !isClipboardMode {
                btn.setTitle(words[i], for: .normal)
                btn.isHidden = false
            } else {
                btn.setTitle("", for: .normal)
                btn.isHidden = true
            }
        }

        let showTools = !hasWords || isToolsExpanded
        if !isClipboardMode {
            clipboardButton.isHidden = !showTools
            textEditingButton.isHidden = !showTools
            developerButton.isHidden = !showTools
            settingsButton.isHidden = !showTools
            micButton.isHidden = false
        }
        setNeedsLayout()
    }

    @objc private func toggleToolsMenu() {
        isToolsExpanded.toggle()
        HapticManager.shared.playSpecialKey()
        setSuggestions(currentSuggestions)
    }

    @objc private func handleTextEditingTap() {
        HapticManager.shared.playSpecialKey()
        delegate?.suggestionBarDidTapTextEditing(self)
    }

    @objc private func handleDeveloperTap() {
        HapticManager.shared.playSpecialKey()
        delegate?.suggestionBarDidTapDeveloperMode(self)
    }

    @objc private func suggestionTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index < currentSuggestions.count else { return }
        let selected = currentSuggestions[index]
        HapticManager.shared.playKeyTap()
        delegate?.suggestionBar(self, didSelectWord: selected)
    }

    @objc private func toggleClipboardMode() {
        isClipboardMode.toggle()
        clipboardScrollView.isHidden = !isClipboardMode
        closeClipboardButton.isHidden = !isClipboardMode

        clipboardButton.isHidden = isClipboardMode
        settingsButton.isHidden = isClipboardMode
        micButton.isHidden = isClipboardMode
        for btn in suggestionButtons {
            btn.isHidden = isClipboardMode
        }

        if isClipboardMode {
            // Tự động kiểm tra và nạp nội dung clipboard hệ thống mới nhất
            if UIPasteboard.general.hasStrings, let text = UIPasteboard.general.string {
                ClipboardManager.shared.addClip(text)
            }
            loadClipboardItems()
        }
        HapticManager.shared.playSpecialKey()
        setNeedsLayout()
    }

    @objc private func handleSettingsTap() {
        HapticManager.shared.playSpecialKey()
        delegate?.suggestionBarDidTapSettings(self)
    }

    private func loadClipboardItems() {
        for sub in clipboardScrollView.subviews {
            sub.removeFromSuperview()
        }

        var currentX: CGFloat = 8.0

        // Nút 1: Dán trực tiếp từ bộ nhớ tạm hệ thống (1-Tap Paste)
        let directPastePill = UIButton(type: .system)
        directPastePill.setTitle("📋 Dán", for: .normal)
        directPastePill.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        directPastePill.setTitleColor(UIColor.systemBlue, for: .normal)
        directPastePill.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.14)
        directPastePill.layer.cornerRadius = 13
        directPastePill.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        let pasteSize = directPastePill.sizeThatFits(CGSize(width: 250, height: 26))
        directPastePill.frame = CGRect(x: currentX, y: 4, width: max(pasteSize.width, 60), height: 26)

        directPastePill.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            HapticManager.shared.playKeyTap()
            if let clip = UIPasteboard.general.string, !clip.isEmpty {
                ClipboardManager.shared.addClip(clip)
                self.delegate?.suggestionBar(self, didSelectClipboardText: clip)
            }
            self.toggleClipboardMode()
        }, for: .touchUpInside)

        clipboardScrollView.addSubview(directPastePill)
        currentX += max(pasteSize.width, 60) + 8.0

        var items = ClipboardManager.shared.getHistory()
        if items.isEmpty {
            // Thêm mẫu để người dùng dùng thử ngay
            items = ["Xin chào!", "Cảm ơn bạn!", "vBoard siêu tốc"]
        }

        for item in items {
            let pill = UIButton(type: .system)
            let displayText = item.replacingOccurrences(of: "\n", with: " ")
            pill.setTitle(displayText, for: .normal)
            pill.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            pill.setTitleColor(UIColor.label, for: .normal)
            pill.backgroundColor = UIColor.secondarySystemFill
            pill.layer.cornerRadius = 13
            pill.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)

            let size = pill.sizeThatFits(CGSize(width: 250, height: 26))
            let pillWidth = min(max(size.width, 40), 200)
            pill.frame = CGRect(x: currentX, y: 4, width: pillWidth, height: 26)

            pill.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                HapticManager.shared.playKeyTap()
                self.delegate?.suggestionBar(self, didSelectClipboardText: item)
                self.toggleClipboardMode()
            }, for: .touchUpInside)

            clipboardScrollView.addSubview(pill)
            currentX += pillWidth + 8.0
        }

        clipboardScrollView.contentSize = CGSize(width: currentX, height: bounds.height)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let barWidth = bounds.width
        let barHeight = bounds.height

        separatorLayer.frame = CGRect(x: 0, y: barHeight - 0.5, width: barWidth, height: 0.5)

        let flankWidth: CGFloat = 36.0
        let rightFlankWidth: CGFloat = 34.0
        menuButton.frame = CGRect(x: 4, y: 0, width: flankWidth, height: barHeight)
        micButton.frame = CGRect(x: barWidth - rightFlankWidth - 4, y: 0, width: rightFlankWidth, height: barHeight)

        if isClipboardMode {
            menuButton.isHidden = true
            clipboardButton.isHidden = true
            textEditingButton.isHidden = true
            developerButton.isHidden = true
            settingsButton.isHidden = true
            micButton.isHidden = true
            closeClipboardButton.frame = CGRect(x: barWidth - 36, y: 0, width: 34, height: barHeight)
            clipboardScrollView.frame = CGRect(x: 0, y: 0, width: barWidth - 38, height: barHeight)
            return
        }

        menuButton.isHidden = false
        micButton.isHidden = false

        let showTools = isToolsExpanded || currentSuggestions.isEmpty
        if showTools {
            dividerLayer1.isHidden = true
            dividerLayer2.isHidden = true

            let toolsCount: CGFloat = 4.0
            let availableToolsWidth = barWidth - flankWidth - rightFlankWidth - 16.0
            let toolBtnWidth = min(50.0, availableToolsWidth / toolsCount)
            let startX = flankWidth + 8.0

            clipboardButton.frame = CGRect(x: startX, y: 0, width: toolBtnWidth, height: barHeight)
            textEditingButton.frame = CGRect(x: startX + toolBtnWidth, y: 0, width: toolBtnWidth, height: barHeight)
            developerButton.frame = CGRect(x: startX + toolBtnWidth * 2.0, y: 0, width: toolBtnWidth, height: barHeight)
            settingsButton.frame = CGRect(x: startX + toolBtnWidth * 3.0, y: 0, width: toolBtnWidth, height: barHeight)
            return
        } else {
            let startX = flankWidth + 4.0
            let availableWidth = barWidth - startX - rightFlankWidth - 6.0
            let cellWidth = availableWidth / 3.0
            var currentX = startX

            for (i, btn) in suggestionButtons.enumerated() {
                btn.frame = CGRect(x: round(currentX), y: 0, width: round(cellWidth), height: barHeight)
                if i == 0 {
                    dividerLayer1.frame = CGRect(x: round(currentX + cellWidth), y: round((barHeight - 15) / 2), width: 1.0, height: 15)
                } else if i == 1 {
                    dividerLayer2.frame = CGRect(x: round(currentX + cellWidth), y: round((barHeight - 15) / 2), width: 1.0, height: 15)
                }
                currentX += cellWidth
            }
        }
    }
}
#endif
