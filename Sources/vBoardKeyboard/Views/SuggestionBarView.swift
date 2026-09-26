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
    func suggestionBar(_ bar: SuggestionBarView, didRequestAddWord word: String)
    func suggestionBar(_ bar: SuggestionBarView, didRequestDeleteWord word: String)
}

public extension SuggestionBarViewDelegate {
    func suggestionBar(_ bar: SuggestionBarView, didRequestAddWord word: String) {}
    func suggestionBar(_ bar: SuggestionBarView, didRequestDeleteWord word: String) {}
}

public final class SuggestionBarView: UIView {
    public weak var delegate: SuggestionBarViewDelegate?

    public private(set) var currentSuggestions: [String] = []
    public private(set) var currentNewWordToSave: String? = nil
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

    // Nút thêm từ vào từ điển cá nhân
    private let addWordButton = UIButton(type: .system)

    // Khung xác nhận xoá từ khỏi từ điển
    private let confirmationContainer = UIView()
    private let confirmLabel = UILabel()
    private let cancelDeleteButton = UIButton(type: .system)
    private let confirmDeleteButton = UIButton(type: .system)
    private var wordPendingDeletion: String? = nil

    // Thông báo nổi tạm thời (Toast feedback)
    private let toastLabel = UILabel()
    private var toastDismissWorkItem: DispatchWorkItem? = nil

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
        var smartChipConfig = UIButton.Configuration.plain()
        smartChipConfig.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        smartChipButton.configuration = smartChipConfig
        smartChipButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        smartChipButton.backgroundColor = UIColor.secondarySystemBackground
        smartChipButton.layer.cornerRadius = 13.0
        smartChipButton.layer.masksToBounds = true
        smartChipButton.setTitleColor(.label, for: .normal)
        smartChipButton.addTarget(self, action: #selector(handleSmartChipTap), for: .touchUpInside)
        smartChipButton.isHidden = true
        addSubview(smartChipButton)

        // Nút thêm từ vào từ điển cá nhân
        var addWordConfig = UIButton.Configuration.plain()
        addWordConfig.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        addWordButton.configuration = addWordConfig
        addWordButton.titleLabel?.font = UIFont.systemFont(ofSize: 13.5, weight: .semibold)
        addWordButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.12)
        addWordButton.setTitleColor(.systemBlue, for: .normal)
        addWordButton.layer.cornerRadius = 13.0
        addWordButton.layer.masksToBounds = true
        addWordButton.addTarget(self, action: #selector(handleAddWordTap), for: .touchUpInside)
        addWordButton.isHidden = true
        addSubview(addWordButton)

        // 3 nút gợi ý từ
        for i in 0..<3 {
            let btn = UIButton(type: .system)
            btn.titleLabel?.font = (i == 1) ? UIFont.systemFont(ofSize: 16.5, weight: .semibold) : UIFont.systemFont(ofSize: 15, weight: .regular)
            btn.setTitleColor(UIColor.label, for: .normal)
            btn.tag = i
            btn.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)

            let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleSuggestionLongPress(_:)))
            lp.minimumPressDuration = 0.4
            btn.addGestureRecognizer(lp)

            addSubview(btn)
            suggestionButtons.append(btn)
        }

        // Khung xác nhận xoá từ khỏi từ điển
        confirmationContainer.backgroundColor = UIColor.secondarySystemBackground
        confirmationContainer.layer.cornerRadius = 10.0
        confirmationContainer.layer.masksToBounds = true
        confirmationContainer.isHidden = true
        confirmationContainer.alpha = 0.0

        confirmLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        confirmLabel.textColor = .label
        confirmLabel.textAlignment = .left
        confirmationContainer.addSubview(confirmLabel)

        cancelDeleteButton.setTitle("Huỷ", for: .normal)
        cancelDeleteButton.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .regular)
        cancelDeleteButton.setTitleColor(.secondaryLabel, for: .normal)
        cancelDeleteButton.backgroundColor = UIColor.systemGray5
        cancelDeleteButton.layer.cornerRadius = 11.0
        cancelDeleteButton.contentEdgeInsets = UIEdgeInsets(top: 3, left: 10, bottom: 3, right: 10)
        cancelDeleteButton.addTarget(self, action: #selector(handleCancelDeleteTap), for: .touchUpInside)
        confirmationContainer.addSubview(cancelDeleteButton)

        confirmDeleteButton.setTitle("Xoá", for: .normal)
        confirmDeleteButton.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .semibold)
        confirmDeleteButton.setTitleColor(.white, for: .normal)
        confirmDeleteButton.backgroundColor = UIColor.systemRed
        confirmDeleteButton.layer.cornerRadius = 11.0
        confirmDeleteButton.contentEdgeInsets = UIEdgeInsets(top: 3, left: 10, bottom: 3, right: 10)
        confirmDeleteButton.addTarget(self, action: #selector(handleConfirmDeleteTap), for: .touchUpInside)
        confirmationContainer.addSubview(confirmDeleteButton)

        addSubview(confirmationContainer)

        // Nhãn thông báo nổi (Toast feedback)
        toastLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .medium)
        toastLabel.textColor = .label
        toastLabel.backgroundColor = UIColor.secondarySystemBackground
        toastLabel.layer.cornerRadius = 13.0
        toastLabel.layer.masksToBounds = true
        toastLabel.textAlignment = .center
        toastLabel.isHidden = true
        toastLabel.alpha = 0.0
        addSubview(toastLabel)

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

    private var slotToWordMap: [Int: String] = [:]

    public func setSuggestions(_ words: [String], newWordToSave: String? = nil) {
        currentSuggestions = words
        currentNewWordToSave = newWordToSave
        let hasWords = !words.isEmpty
        let hasNewWord = (newWordToSave != nil)
        menuButton.isHidden = false

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let menuIconName = isToolsExpanded ? "chevron.backward" : "square.grid.2x2.fill"
        menuButton.setImage(UIImage(systemName: menuIconName, withConfiguration: symbolConfig), for: .normal)

        let showTools = (!hasWords && !hasNewWord) || isToolsExpanded
        dividerLayer1.isHidden = showTools || (words.count < 2 && !hasNewWord)
        dividerLayer2.isHidden = showTools || words.count < 3

        let showSmartChip = !showTools && words.isEmpty && !hasNewWord && smartClipText != nil

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

        slotToWordMap.removeAll()
        if !showTools {
            if let newWord = newWordToSave {
                let display = newWord.count > 10 ? String(newWord.prefix(10)) + "…" : newWord
                addWordButton.setTitle("+ Lưu \"\(display)\"", for: .normal)
                addWordButton.isHidden = false

                if words.isEmpty {
                    // Không có gợi ý
                } else if words.count == 1 {
                    slotToWordMap[1] = words[0] // Center
                } else {
                    slotToWordMap[1] = words[0] // Center
                    slotToWordMap[2] = words[1] // Right
                }
            } else {
                addWordButton.isHidden = true
                if !words.isEmpty {
                    if words.count == 1 {
                        slotToWordMap[1] = words[0]
                    } else if words.count == 2 {
                        slotToWordMap[1] = words[0] // Center
                        slotToWordMap[0] = words[1] // Left
                    } else {
                        slotToWordMap[1] = words[0] // Center
                        slotToWordMap[0] = words[1] // Left
                        slotToWordMap[2] = words[2] // Right
                    }
                }
            }
        } else {
            addWordButton.isHidden = true
        }

        for (i, btn) in suggestionButtons.enumerated() {
            if let word = slotToWordMap[i], !showTools {
                btn.setTitle(word, for: .normal)
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
        guard let selected = slotToWordMap[sender.tag] else { return }
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

        // Nếu đang hiện thông báo Toast -> canh giữa và đưa lên trước
        if !toastLabel.isHidden {
            bringSubviewToFront(toastLabel)
        }

        // Nếu đang hiện banner xác nhận xoá từ -> phủ lên toàn bộ thanh gợi ý
        if !confirmationContainer.isHidden {
            confirmationContainer.frame = CGRect(x: 6, y: 3, width: barWidth - 12, height: barHeight - 6)
            bringSubviewToFront(confirmationContainer)
            let boxW = barWidth - 12
            let boxH = barHeight - 6
            let btnW: CGFloat = 52.0
            let btnH: CGFloat = 26.0
            let btnY = (boxH - btnH) / 2.0
            confirmDeleteButton.frame = CGRect(x: boxW - btnW - 8, y: btnY, width: btnW, height: btnH)
            cancelDeleteButton.frame = CGRect(x: boxW - (btnW * 2) - 14, y: btnY, width: btnW, height: btnH)
            confirmLabel.frame = CGRect(x: 12, y: 0, width: boxW - (btnW * 2) - 30, height: boxH)
            return
        }

        let flankWidth: CGFloat = 38.0
        let rightFlankWidth: CGFloat = 38.0
        menuButton.frame = CGRect(x: 4, y: 0, width: flankWidth, height: barHeight)

        // Nút Dán (Paste) luôn hiển thị cố định ở góc phải thanh công cụ
        pasteButton.frame = CGRect(x: barWidth - rightFlankWidth - 4, y: 0, width: rightFlankWidth, height: barHeight)
        pasteButton.isHidden = false

        let showTools = isToolsExpanded || (currentSuggestions.isEmpty && currentNewWordToSave == nil)
        if showTools {
            addWordButton.isHidden = true
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
            let toolBtnWidth = min(48.0, availableToolsWidth / count)
            let startX = flankWidth + max(0, (availableToolsWidth - (toolBtnWidth * count)) / 2.0)

            for (idx, v) in toolViews.enumerated() {
                v.frame = CGRect(x: startX + CGFloat(idx) * toolBtnWidth, y: 0, width: toolBtnWidth, height: barHeight)
                v.isHidden = false
            }
        } else if !smartChipButton.isHidden {
            addWordButton.isHidden = true
            dividerLayer1.isHidden = true
            dividerLayer2.isHidden = true
            let maxChipW = barWidth - flankWidth - rightFlankWidth - 16.0
            let chipSize = smartChipButton.sizeThatFits(CGSize(width: maxChipW, height: 28))
            let chipW = min(chipSize.width, maxChipW)
            smartChipButton.frame = CGRect(
                x: flankWidth + (maxChipW - chipW) / 2.0,
                y: (barHeight - 28.0) / 2.0,
                width: chipW,
                height: 28.0
            )
        } else {
            let startX = flankWidth + 4.0
            let availableWidth = barWidth - startX - rightFlankWidth - 8.0

            if currentNewWordToSave != nil {
                // Đang có từ chưa có trong từ điển
                if currentSuggestions.isEmpty {
                    dividerLayer1.isHidden = true
                    dividerLayer2.isHidden = true
                    let maxBtnW = min(availableWidth, 240.0)
                    addWordButton.frame = CGRect(
                        x: startX + (availableWidth - maxBtnW) / 2.0,
                        y: (barHeight - 28.0) / 2.0,
                        width: maxBtnW,
                        height: 28.0
                    )
                    addWordButton.isHidden = false
                    suggestionButtons[0].isHidden = true
                    suggestionButtons[1].isHidden = true
                    suggestionButtons[2].isHidden = true
                } else {
                    let cellWidth = availableWidth / 3.0
                    addWordButton.frame = CGRect(
                        x: round(startX),
                        y: round((barHeight - 28.0) / 2.0),
                        width: round(cellWidth) - 4.0,
                        height: 28.0
                    )
                    addWordButton.isHidden = false
                    suggestionButtons[0].isHidden = true

                    dividerLayer1.frame = CGRect(x: round(startX + cellWidth), y: round((barHeight - 18) / 2), width: 1.0, height: 18)
                    dividerLayer1.isHidden = false

                    suggestionButtons[1].frame = CGRect(x: round(startX + cellWidth), y: 0, width: round(cellWidth), height: barHeight)
                    suggestionButtons[1].isHidden = false

                    if currentSuggestions.count >= 2 {
                        dividerLayer2.frame = CGRect(x: round(startX + cellWidth * 2), y: round((barHeight - 18) / 2), width: 1.0, height: 18)
                        dividerLayer2.isHidden = false
                        suggestionButtons[2].frame = CGRect(x: round(startX + cellWidth * 2), y: 0, width: round(cellWidth), height: barHeight)
                        suggestionButtons[2].isHidden = false
                    } else {
                        dividerLayer2.isHidden = true
                        suggestionButtons[2].isHidden = true
                    }
                }
            } else {
                addWordButton.isHidden = true
                let cellWidth = availableWidth / 3.0
                var currentX = startX

                for (i, btn) in suggestionButtons.enumerated() {
                    btn.frame = CGRect(x: round(currentX), y: 0, width: round(cellWidth), height: barHeight)
                    if i == 0 {
                        dividerLayer1.frame = CGRect(x: round(currentX + cellWidth), y: round((barHeight - 18) / 2), width: 1.0, height: 18)
                    } else if i == 1 {
                        dividerLayer2.frame = CGRect(x: round(currentX + cellWidth), y: round((barHeight - 18) / 2), width: 1.0, height: 18)
                    }
                    currentX += cellWidth
                }
            }
        }
    }

    // MARK: - Quản lý Thêm & Xoá từ từ điển

    @objc private func handleAddWordTap() {
        guard let word = currentNewWordToSave, !word.isEmpty else { return }
        HapticManager.shared.playSpecialKey()
        delegate?.suggestionBar(self, didRequestAddWord: word)
        showToast("✓ Đã lưu \"\(word)\"")
    }

    @objc private func handleSuggestionLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        guard let btn = gesture.view as? UIButton, let word = slotToWordMap[btn.tag], !word.isEmpty else { return }
        HapticManager.shared.playSpecialKey()
        showDeleteConfirmation(for: word)
    }

    private func showDeleteConfirmation(for word: String) {
        wordPendingDeletion = word
        let display = word.count > 10 ? String(word.prefix(10)) + "…" : word
        confirmLabel.text = "Xoá \"\(display)\" khỏi từ điển?"
        confirmationContainer.isHidden = false
        bringSubviewToFront(confirmationContainer)
        setNeedsLayout()
        UIView.animate(withDuration: 0.2) {
            self.confirmationContainer.alpha = 1.0
        }
    }

    @objc private func handleCancelDeleteTap() {
        wordPendingDeletion = nil
        UIView.animate(withDuration: 0.15, animations: {
            self.confirmationContainer.alpha = 0.0
        }, completion: { _ in
            self.confirmationContainer.isHidden = true
            self.setNeedsLayout()
        })
    }

    @objc private func handleConfirmDeleteTap() {
        guard let word = wordPendingDeletion else { return }
        HapticManager.shared.playSpecialKey()
        wordPendingDeletion = nil
        UIView.animate(withDuration: 0.15, animations: {
            self.confirmationContainer.alpha = 0.0
        }, completion: { _ in
            self.confirmationContainer.isHidden = true
            self.setNeedsLayout()
        })
        delegate?.suggestionBar(self, didRequestDeleteWord: word)
        showToast("✓ Đã xoá \"\(word)\"")
    }

    public func showToast(_ message: String) {
        toastDismissWorkItem?.cancel()
        toastLabel.text = message
        toastLabel.sizeToFit()
        let padW: CGFloat = 24.0
        let padH: CGFloat = 8.0
        let w = min(toastLabel.bounds.width + padW, bounds.width - 32.0)
        let h = max(26.0, toastLabel.bounds.height + padH)
        toastLabel.frame = CGRect(
            x: (bounds.width - w) / 2.0,
            y: (bounds.height - h) / 2.0,
            width: w,
            height: h
        )
        toastLabel.isHidden = false
        bringSubviewToFront(toastLabel)
        UIView.animate(withDuration: 0.15) {
            self.toastLabel.alpha = 1.0
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            UIView.animate(withDuration: 0.25, animations: {
                self.toastLabel.alpha = 0.0
            }, completion: { _ in
                self.toastLabel.isHidden = true
            })
        }
        toastDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
    }
}
#endif
