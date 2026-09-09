#if canImport(UIKit)
import UIKit
import vBoardEngine

@MainActor
public protocol TextEditingViewDelegate: AnyObject {
    func textEditingViewDidRequestClose(_ view: TextEditingView)
}

/// Bảng điều khiển Chỉnh sửa Văn bản Chuyên sâu (Text Editing D-Pad) chuẩn Gboard
@MainActor
public final class TextEditingView: UIView {
    public weak var delegate: TextEditingViewDelegate?
    private weak var proxy: TextDocumentProxyProtocol?

    private var isSelecting: Bool = false {
        didSet {
            updateSelectButtonUI()
        }
    }

    // Top action bar
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    // D-Pad buttons
    private let upButton = UIButton(type: .system)
    private let downButton = UIButton(type: .system)
    private let leftButton = UIButton(type: .system)
    private let rightButton = UIButton(type: .system)
    private let selectCenterButton = UIButton(type: .system)

    // Line boundary navigation
    private let lineStartButton = UIButton(type: .system)
    private let lineEndButton = UIButton(type: .system)

    // Action side buttons
    private let selectAllButton = UIButton(type: .system)
    private let copyButton = UIButton(type: .system)
    private let pasteButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)

    public init(frame: CGRect, proxy: TextDocumentProxyProtocol?) {
        self.proxy = proxy
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func updateProxy(_ proxy: TextDocumentProxyProtocol?) {
        self.proxy = proxy
    }

    private func setupUI() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        backgroundColor = isDark ? UIColor(red: 30/255, green: 31/255, blue: 34/255, alpha: 1.0) : UIColor(red: 241/255, green: 243/255, blue: 244/255, alpha: 1.0)

        // Title & Close
        titleLabel.text = "Chỉnh sửa văn bản"
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = isDark ? .white : UIColor(red: 31/255, green: 31/255, blue: 31/255, alpha: 1.0)
        addSubview(titleLabel)

        let xConfig = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: xConfig), for: .normal)
        closeButton.tintColor = .secondaryLabel
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        addSubview(closeButton)

        // D-Pad configuration
        let arrowConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
        configureDPadButton(upButton, icon: "arrow.up", config: arrowConfig, action: #selector(moveUp))
        configureDPadButton(downButton, icon: "arrow.down", config: arrowConfig, action: #selector(moveDown))
        configureDPadButton(leftButton, icon: "arrow.left", config: arrowConfig, action: #selector(moveLeft))
        configureDPadButton(rightButton, icon: "arrow.right", config: arrowConfig, action: #selector(moveRight))

        // Center Select Button
        selectCenterButton.setTitle("Chọn", for: .normal)
        selectCenterButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        selectCenterButton.layer.cornerRadius = 10.0
        selectCenterButton.addTarget(self, action: #selector(toggleSelect), for: .touchUpInside)
        addSubview(selectCenterButton)
        updateSelectButtonUI()

        // Line start / end buttons
        let lineConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        configureActionButton(lineStartButton, title: "Đầu dòng", icon: "arrow.left.to.line", config: lineConfig, action: #selector(moveToLineStart))
        configureActionButton(lineEndButton, title: "Cuối dòng", icon: "arrow.right.to.line", config: lineConfig, action: #selector(moveToLineEnd))

        // Side action buttons
        configureActionButton(selectAllButton, title: "Chọn tất cả", icon: "selection.pin.in.out", config: lineConfig, action: #selector(handleSelectAll))
        configureActionButton(copyButton, title: "Sao chép", icon: "doc.on.doc", config: lineConfig, action: #selector(handleCopy))
        configureActionButton(pasteButton, title: "Dán", icon: "doc.on.clipboard", config: lineConfig, action: #selector(handlePaste))
        configureActionButton(deleteButton, title: "Xóa", icon: "delete.left", config: lineConfig, action: #selector(handleDelete))
    }

    private func configureDPadButton(_ button: UIButton, icon: String, config: UIImage.SymbolConfiguration, action: Selector) {
        button.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
        button.layer.cornerRadius = 12.0
        button.addTarget(self, action: action, for: .touchUpInside)
        addSubview(button)
    }

    private func configureActionButton(_ button: UIButton, title: String, icon: String, config: UIImage.SymbolConfiguration, action: Selector) {
        button.setTitle("  " + title, for: .normal)
        button.setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        button.layer.cornerRadius = 8.0
        button.addTarget(self, action: action, for: .touchUpInside)
        addSubview(button)
    }

    private func updateSelectButtonUI() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        if isSelecting {
            selectCenterButton.backgroundColor = UIColor(red: 26/255, green: 115/255, blue: 232/255, alpha: 1.0)
            selectCenterButton.setTitleColor(.white, for: .normal)
        } else {
            selectCenterButton.backgroundColor = isDark ? UIColor(red: 54/255, green: 56/255, blue: 61/255, alpha: 1.0) : UIColor.white
            selectCenterButton.setTitleColor(isDark ? .white : UIColor(red: 31/255, green: 31/255, blue: 31/255, alpha: 1.0), for: .normal)
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let isDark = traitCollection.userInterfaceStyle == .dark
        let buttonBg = isDark ? UIColor(red: 54/255, green: 56/255, blue: 61/255, alpha: 1.0) : UIColor.white
        let buttonTint = isDark ? UIColor.white : UIColor(red: 31/255, green: 31/255, blue: 31/255, alpha: 1.0)

        [upButton, downButton, leftButton, rightButton, lineStartButton, lineEndButton, selectAllButton, copyButton, pasteButton, deleteButton].forEach {
            $0.backgroundColor = buttonBg
            $0.tintColor = buttonTint
            $0.setTitleColor(buttonTint, for: .normal)
            $0.layer.shadowColor = UIColor.black.cgColor
            $0.layer.shadowOpacity = 0.12
            $0.layer.shadowOffset = CGSize(width: 0, height: 1.0)
            $0.layer.shadowRadius = 1.0
        }

        let padW = bounds.width
        let padH = bounds.height

        // Top bar
        titleLabel.frame = CGRect(x: 16, y: 8, width: 200, height: 24)
        closeButton.frame = CGRect(x: padW - 44, y: 6, width: 32, height: 32)

        // D-Pad dimensions
        let dpadSize: CGFloat = min(padH - 50, 160.0)
        let dpadOriginX: CGFloat = 16.0
        let dpadOriginY: CGFloat = 40.0 + (padH - 40.0 - dpadSize) / 2.0
        let cellW = dpadSize / 3.0
        let cellH = cellW

        upButton.frame = CGRect(x: dpadOriginX + cellW, y: dpadOriginY, width: cellW, height: cellH)
        downButton.frame = CGRect(x: dpadOriginX + cellW, y: dpadOriginY + cellH * 2.0, width: cellW, height: cellH)
        leftButton.frame = CGRect(x: dpadOriginX, y: dpadOriginY + cellH, width: cellW, height: cellH)
        rightButton.frame = CGRect(x: dpadOriginX + cellW * 2.0, y: dpadOriginY + cellH, width: cellW, height: cellH)
        selectCenterButton.frame = CGRect(x: dpadOriginX + cellW + 4, y: dpadOriginY + cellH + 4, width: cellW - 8, height: cellH - 8)

        // Line start & end buttons below/beside D-Pad
        let middleX = dpadOriginX + dpadSize + 12.0
        let sideColW = (padW - middleX - 16.0)

        let actionBtnH: CGFloat = max(32.0, (padH - 52.0) / 4.0 - 6.0)

        selectAllButton.frame = CGRect(x: middleX, y: 40.0, width: sideColW, height: actionBtnH)
        copyButton.frame = CGRect(x: middleX, y: 40.0 + actionBtnH + 6.0, width: sideColW, height: actionBtnH)
        pasteButton.frame = CGRect(x: middleX, y: 40.0 + (actionBtnH + 6.0) * 2.0, width: sideColW, height: actionBtnH)
        deleteButton.frame = CGRect(x: middleX, y: 40.0 + (actionBtnH + 6.0) * 3.0, width: sideColW, height: actionBtnH)
    }

    // MARK: - Actions
    @objc private func handleClose() {
        HapticManager.shared.playSpecialKey()
        delegate?.textEditingViewDidRequestClose(self)
    }

    @objc private func toggleSelect() {
        isSelecting.toggle()
        HapticManager.shared.playSpecialKey()
    }

    @objc private func moveUp() {
        HapticManager.shared.playKeyTap()
        proxy?.adjustTextPosition(byCharacterOffset: -25)
    }

    @objc private func moveDown() {
        HapticManager.shared.playKeyTap()
        proxy?.adjustTextPosition(byCharacterOffset: 25)
    }

    @objc private func moveLeft() {
        HapticManager.shared.playKeyTap()
        proxy?.adjustTextPosition(byCharacterOffset: -1)
    }

    @objc private func moveRight() {
        HapticManager.shared.playKeyTap()
        proxy?.adjustTextPosition(byCharacterOffset: 1)
    }

    @objc private func moveToLineStart() {
        HapticManager.shared.playSpecialKey()
        proxy?.adjustTextPosition(byCharacterOffset: -100)
    }

    @objc private func moveToLineEnd() {
        HapticManager.shared.playSpecialKey()
        proxy?.adjustTextPosition(byCharacterOffset: 100)
    }

    @objc private func handleSelectAll() {
        HapticManager.shared.playSpecialKey()
        isSelecting = true
    }

    @objc private func handleCopy() {
        HapticManager.shared.playSpecialKey()
        if let before = proxy?.documentContextBeforeInput, !before.isEmpty {
            UIPasteboard.general.string = before
        }
    }

    @objc private func handlePaste() {
        HapticManager.shared.playSpecialKey()
        if let clip = UIPasteboard.general.string, !clip.isEmpty {
            proxy?.insertText(clip)
        }
    }

    @objc private func handleDelete() {
        HapticManager.shared.playKeyTap()
        proxy?.deleteBackward()
    }
}
#endif
