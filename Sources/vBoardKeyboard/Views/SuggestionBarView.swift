#if canImport(UIKit)
import UIKit
import vBoardEngine

@MainActor
public protocol SuggestionBarViewDelegate: AnyObject {
    func suggestionBar(_ bar: SuggestionBarView, didSelectWord word: String)
    func suggestionBarDidTapClipboard(_ bar: SuggestionBarView)
    func suggestionBarDidTapSettings(_ bar: SuggestionBarView)
    func suggestionBarDidTapTextEditing(_ bar: SuggestionBarView)
    func suggestionBarDidTapDeveloperMode(_ bar: SuggestionBarView)
    func suggestionBarDidTapUndo(_ bar: SuggestionBarView)
    func suggestionBarDidTapRedo(_ bar: SuggestionBarView)
    func suggestionBarDidTapSmartChip(_ bar: SuggestionBarView, clipText: String)
    func suggestionBarDidTapOneHanded(_ bar: SuggestionBarView)
    func suggestionBarDidTapPaste(_ bar: SuggestionBarView)
}

public final class SuggestionBarView: UIView {
    public weak var delegate: SuggestionBarViewDelegate?

    public private(set) var currentSuggestions: [String] = []
    public private(set) var isToolsExpanded: Bool = false
    public var smartClipText: String? = nil {
        didSet {
            updateSmartChip()
        }
    }

    // Normal mode views - dùng Vector Icons
    private let menuButton = UIButton(type: .system)
    private let pasteButton = UIButton(type: .system)
    private let clipboardButton = UIButton(type: .system)
    private let textEditingButton = UIButton(type: .system)
    private let developerButton = UIButton(type: .system)
    private let settingsButton = UIButton(type: .system)
    private let undoButton = UIButton(type: .system)
    private let redoButton = UIButton(type: .system)
    private let oneHandedButton = UIButton(type: .system)
    private let smartChipButton = UIButton(type: .system)

    private var suggestionButtons: [UIButton] = []
    private let dividerLayer1 = CALayer()
    private let dividerLayer2 = CALayer()
    private let separatorLayer = CALayer()

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

        // Nút Menu chuyển đổi Gợi ý / Công cụ
        let menuIcon = UIImage(systemName: "square.grid.2x2.fill", withConfiguration: symbolConfig) ?? UIImage(systemName: "square.grid.2x2", withConfiguration: symbolConfig)
        menuButton.setImage(menuIcon, for: .normal)
        menuButton.tintColor = .secondaryLabel
        menuButton.addTarget(self, action: #selector(toggleToolsMenu), for: .touchUpInside)
        addSubview(menuButton)

        // Nút Dán / Lịch sử copy (Paste / Clipboard Button) luôn hiển thị ở mép phải
        updatePasteButtonIcon()
        pasteButton.tintColor = .secondaryLabel
        pasteButton.addTarget(self, action: #selector(handlePasteTap), for: .touchUpInside)

        let pasteLongPress = UILongPressGestureRecognizer(target: self, action: #selector(handlePasteLongPress(_:)))
        pasteLongPress.minimumPressDuration = 0.35
        pasteButton.addGestureRecognizer(pasteLongPress)
        addSubview(pasteButton)

        // Nút Clipboard (Vector SF Symbol)
        let clipIcon = UIImage(systemName: "doc.on.clipboard", withConfiguration: symbolConfig)
        clipboardButton.setImage(clipIcon, for: .normal)
        clipboardButton.tintColor = .secondaryLabel
        clipboardButton.addTarget(self, action: #selector(handleClipboardTap), for: .touchUpInside)
        addSubview(clipboardButton)

        // Nút Text Editing D-Pad
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

        // Nút Undo & Redo (Sprint 1)
        let undoIcon = UIImage(systemName: "arrow.uturn.backward", withConfiguration: symbolConfig)
        undoButton.setImage(undoIcon, for: .normal)
        undoButton.tintColor = .secondaryLabel
        undoButton.addTarget(self, action: #selector(handleUndoTap), for: .touchUpInside)
        addSubview(undoButton)

        let redoIcon = UIImage(systemName: "arrow.uturn.forward", withConfiguration: symbolConfig)
        redoButton.setImage(redoIcon, for: .normal)
        redoButton.tintColor = .secondaryLabel
        redoButton.addTarget(self, action: #selector(handleRedoTap), for: .touchUpInside)
        addSubview(redoButton)

        // Nút One-Handed
        let oneHandedIcon = UIImage(systemName: "rectangle.lefthalf.inset.filled", withConfiguration: symbolConfig)
        oneHandedButton.setImage(oneHandedIcon, for: .normal)
        oneHandedButton.tintColor = .secondaryLabel
        oneHandedButton.addTarget(self, action: #selector(handleOneHandedTap), for: .touchUpInside)
        addSubview(oneHandedButton)

        // Smart Quick Chip
        smartChipButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        smartChipButton.backgroundColor = UIColor.secondarySystemBackground
        smartChipButton.layer.cornerRadius = 13.0
        smartChipButton.layer.masksToBounds = true
        smartChipButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        smartChipButton.setTitleColor(.label, for: .normal)
        smartChipButton.addTarget(self, action: #selector(handleSmartChipTap), for: .touchUpInside)
        smartChipButton.isHidden = true
        addSubview(smartChipButton)

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

        updateHistoryButtons()
    }

    public func updateHistoryButtons() {
        let canUndo = ActionHistoryManager.shared.canUndo
        let canRedo = ActionHistoryManager.shared.canRedo
        undoButton.alpha = canUndo ? 1.0 : 0.35
        undoButton.isEnabled = canUndo
        redoButton.alpha = canRedo ? 1.0 : 0.35
        redoButton.isEnabled = canRedo
    }

    public func setSuggestions(_ words: [String]) {
        currentSuggestions = words
        let hasWords = !words.isEmpty
        menuButton.isHidden = false

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let menuIconName = isToolsExpanded ? "chevron.backward" : "square.grid.2x2.fill"
        menuButton.setImage(UIImage(systemName: menuIconName, withConfiguration: symbolConfig), for: .normal)

        let showTools = !hasWords || isToolsExpanded
        dividerLayer1.isHidden = showTools || words.count < 2
        dividerLayer2.isHidden = showTools || words.count < 3

        let showSmartChip = !showTools && words.isEmpty && smartClipText != nil

        clipboardButton.isHidden = !showTools
        textEditingButton.isHidden = true // Đã gộp vào Dev Mode
        developerButton.isHidden = !showTools
        settingsButton.isHidden = !showTools
        undoButton.isHidden = !showTools
        redoButton.isHidden = !showTools
        oneHandedButton.isHidden = !showTools

        smartChipButton.isHidden = !showSmartChip
        if showSmartChip, let clip = smartClipText {
            let preview = clip.count > 18 ? String(clip.prefix(18)) + "..." : clip
            smartChipButton.setTitle("📋 Dán: \"\(preview)\"", for: .normal)
        }

        for (i, btn) in suggestionButtons.enumerated() {
            if i < words.count && !showTools {
                btn.setTitle(words[i], for: .normal)
                btn.isHidden = false
            } else {
                btn.setTitle("", for: .normal)
                btn.isHidden = true
            }
        }
        updateHistoryButtons()
        setNeedsLayout()
    }

    private func updateSmartChip() {
        if currentSuggestions.isEmpty {
            setSuggestions([])
        }
    }

    @objc private func toggleToolsMenu() {
        isToolsExpanded.toggle()
        HapticManager.shared.playSpecialKey()
        setSuggestions(currentSuggestions)
    }

    @objc private func handleTextEditingTap() {
        isToolsExpanded = false
        HapticManager.shared.playSpecialKey()
        delegate?.suggestionBarDidTapTextEditing(self)
        setSuggestions(currentSuggestions)
    }

    @objc private func handleDeveloperTap() {
        HapticManager.shared.playSpecialKey()
        delegate?.suggestionBarDidTapDeveloperMode(self)
    }

    @objc private func handleSettingsTap() {
        isToolsExpanded = false
        HapticManager.shared.playSpecialKey()
        delegate?.suggestionBarDidTapSettings(self)
        setSuggestions(currentSuggestions)
    }

    @objc private func handleUndoTap() {
        HapticManager.shared.playSpecialKey()
        delegate?.suggestionBarDidTapUndo(self)
        updateHistoryButtons()
    }

    @objc private func handleRedoTap() {
        HapticManager.shared.playSpecialKey()
        delegate?.suggestionBarDidTapRedo(self)
        updateHistoryButtons()
    }

    @objc private func handleOneHandedTap() {
        HapticManager.shared.playSpecialKey()
        delegate?.suggestionBarDidTapOneHanded(self)
    }

    @objc private func handleSmartChipTap() {
        guard let clip = smartClipText else { return }
        HapticManager.shared.playKeyTap()
        delegate?.suggestionBarDidTapSmartChip(self, clipText: clip)
    }

    @objc private func suggestionTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index < currentSuggestions.count else { return }
        let selected = currentSuggestions[index]
        HapticManager.shared.playKeyTap()
        delegate?.suggestionBar(self, didSelectWord: selected)
    }

    public func updatePasteButtonIcon() {
        let isClipboardMode = (vBoardSettings.shared.pasteButtonMode == "clipboard")
        if isClipboardMode {
            pasteButton.setImage(KeyboardIcons.clipboardHistoryIcon(size: CGSize(width: 18, height: 18)), for: .normal)
        } else {
            pasteButton.setImage(KeyboardIcons.pasteIcon(size: CGSize(width: 18, height: 18)), for: .normal)
        }
    }

    @objc private func handleClipboardTap() {
        HapticManager.shared.playSpecialKey()
        delegate?.suggestionBarDidTapClipboard(self)
    }

    @objc private func handlePasteTap() {
        HapticManager.shared.playSpecialKey()
        let isClipboardMode = (vBoardSettings.shared.pasteButtonMode == "clipboard")
        if isClipboardMode {
            delegate?.suggestionBarDidTapClipboard(self)
        } else {
            delegate?.suggestionBarDidTapPaste(self)
        }
    }

    @objc private func handlePasteLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        HapticManager.shared.playSpecialKey()
        let currentMode = vBoardSettings.shared.pasteButtonMode
        let newMode = (currentMode == "clipboard") ? "paste" : "clipboard"
        vBoardSettings.shared.pasteButtonMode = newMode
        vBoardSettings.shared.notifySettingsChanged()
        updatePasteButtonIcon()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let barWidth = bounds.width
        let barHeight = bounds.height

        separatorLayer.frame = CGRect(x: 0, y: barHeight - 0.5, width: barWidth, height: 0.5)

        let flankWidth: CGFloat = 36.0
        let rightFlankWidth: CGFloat = 36.0
        menuButton.frame = CGRect(x: 4, y: 0, width: flankWidth, height: barHeight)

        // Nút Dán (Paste) luôn hiển thị cố định ở góc phải thanh công cụ
        pasteButton.frame = CGRect(x: barWidth - rightFlankWidth - 4, y: 0, width: rightFlankWidth, height: barHeight)
        pasteButton.isHidden = false

        let showTools = isToolsExpanded || currentSuggestions.isEmpty
        if showTools {
            dividerLayer1.isHidden = true
            dividerLayer2.isHidden = true

            // Lấy danh sách các công cụ hiển thị theo cấu hình
            var toolViews: [UIView] = []
            let order = vBoardSettings.shared.toolbarItemsOrder

            for item in order {
                switch item {
                case "clipboard":
                    toolViews.append(clipboardButton)
                case "dev":
                    toolViews.append(developerButton)
                case "undoRedo":
                    toolViews.append(undoButton)
                    toolViews.append(redoButton)
                case "quickSettings":
                    toolViews.append(settingsButton)
                case "oneHanded":
                    toolViews.append(oneHandedButton)
                default:
                    break
                }
            }
            if toolViews.isEmpty {
                toolViews = [clipboardButton, developerButton, undoButton, redoButton, settingsButton]
            }

            let availableToolsWidth = barWidth - flankWidth - rightFlankWidth - 12.0
            let count = CGFloat(toolViews.count)
            let toolBtnWidth = min(46.0, availableToolsWidth / count)
            let startX = flankWidth + max(0, (availableToolsWidth - (toolBtnWidth * count)) / 2.0)

            for (idx, v) in toolViews.enumerated() {
                v.frame = CGRect(x: startX + CGFloat(idx) * toolBtnWidth, y: 0, width: toolBtnWidth, height: barHeight)
                v.isHidden = false
            }
        } else if !smartChipButton.isHidden {
            dividerLayer1.isHidden = true
            dividerLayer2.isHidden = true
            let maxChipW = barWidth - flankWidth - rightFlankWidth - 16.0
            let chipSize = smartChipButton.sizeThatFits(CGSize(width: maxChipW, height: 28))
            let chipW = min(chipSize.width, maxChipW)
            smartChipButton.frame = CGRect(
                x: flankWidth + (maxChipW - chipW) / 2.0,
                y: (barHeight - 26.0) / 2.0,
                width: chipW,
                height: 26.0
            )
        } else {
            let startX = flankWidth + 4.0
            let availableWidth = barWidth - startX - rightFlankWidth - 8.0
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
