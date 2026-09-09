#if canImport(UIKit)
import UIKit
import vBoardEngine

@MainActor
public protocol ClipboardViewDelegate: AnyObject {
    func clipboardViewDidRequestClose(_ view: ClipboardView)
    func clipboardView(_ view: ClipboardView, didSelectClip text: String)
}

/// Màn hình Quản lý Bảng tạm (Clipboard History View) chuyên sâu dạng lớp phủ (Overlay)
@MainActor
public final class ClipboardView: UIView {
    public weak var delegate: ClipboardViewDelegate?

    // Top action bar
    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    // Quick action buttons
    private let directPasteButton = UIButton(type: .system)
    private let clearAllButton = UIButton(type: .system)

    // Content
    private let scrollView = UIScrollView()
    private let emptyView = UIView()
    private let emptyIconView = UIImageView()
    private let emptyLabel = UILabel()
    private var cardViews: [UIView] = []

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        backgroundColor = isDark ? UIColor(red: 30/255, green: 31/255, blue: 34/255, alpha: 1.0) : UIColor(red: 241/255, green: 243/255, blue: 244/255, alpha: 1.0)

        // Title
        titleLabel.text = "Bảng tạm"
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = isDark ? .white : UIColor(red: 31/255, green: 31/255, blue: 31/255, alpha: 1.0)
        addSubview(titleLabel)

        // Close button (X)
        let xConfig = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: xConfig), for: .normal)
        closeButton.tintColor = .secondaryLabel
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        addSubview(closeButton)

        // Direct Paste button
        let btnConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        directPasteButton.setTitle("  Dán mới nhất", for: .normal)
        directPasteButton.setImage(UIImage(systemName: "doc.on.clipboard", withConfiguration: btnConfig), for: .normal)
        directPasteButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        directPasteButton.layer.cornerRadius = 8.0
        directPasteButton.addTarget(self, action: #selector(handleDirectPaste), for: .touchUpInside)
        addSubview(directPasteButton)

        // Clear All button
        clearAllButton.setTitle("  Xóa tất cả", for: .normal)
        clearAllButton.setImage(UIImage(systemName: "trash", withConfiguration: btnConfig), for: .normal)
        clearAllButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        clearAllButton.layer.cornerRadius = 8.0
        clearAllButton.addTarget(self, action: #selector(handleClearAll), for: .touchUpInside)
        addSubview(clearAllButton)

        // ScrollView
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        addSubview(scrollView)

        // Empty state view
        let emptyConfig = UIImage.SymbolConfiguration(pointSize: 26, weight: .regular)
        emptyIconView.image = UIImage(systemName: "doc.on.clipboard", withConfiguration: emptyConfig)
        emptyIconView.tintColor = .tertiaryLabel
        emptyIconView.contentMode = .scaleAspectFit
        emptyView.addSubview(emptyIconView)

        emptyLabel.text = "Chưa có nội dung nào trong bảng tạm\nSao chép văn bản để lưu lịch sử tại đây"
        emptyLabel.numberOfLines = 2
        emptyLabel.textAlignment = .center
        emptyLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        emptyLabel.textColor = .secondaryLabel
        emptyView.addSubview(emptyLabel)

        scrollView.addSubview(emptyView)
    }

    /// Làm mới dữ liệu bảng tạm và giao diện danh sách
    public func reloadData() {
        // Tự động kiểm tra và thêm nội dung mới nhất từ UIPasteboard nếu có
        if let clip = UIPasteboard.general.string {
            let trimmed = clip.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                ClipboardManager.shared.addClip(trimmed)
            }
        }

        rebuildListUI()
    }

    private func rebuildListUI() {
        // Xóa sạch các thẻ cũ
        for card in cardViews {
            card.removeFromSuperview()
        }
        cardViews.removeAll()

        let items = ClipboardManager.shared.getHistory()
        let isDark = traitCollection.userInterfaceStyle == .dark
        let cardBg = isDark ? UIColor(red: 45/255, green: 46/255, blue: 50/255, alpha: 1.0) : UIColor.white
        let textColor = isDark ? UIColor.white : UIColor(red: 31/255, green: 31/255, blue: 31/255, alpha: 1.0)

        if items.isEmpty {
            emptyView.isHidden = false
        } else {
            emptyView.isHidden = true
            let trashConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .regular)

            for item in items {
                let card = UIView()
                card.backgroundColor = cardBg
                card.layer.cornerRadius = 8.0
                card.layer.shadowColor = UIColor.black.cgColor
                card.layer.shadowOpacity = 0.08
                card.layer.shadowOffset = CGSize(width: 0, height: 1.0)
                card.layer.shadowRadius = 1.0

                // Label hiển thị văn bản
                let label = UILabel()
                label.text = item
                label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
                label.textColor = textColor
                label.numberOfLines = 2
                label.lineBreakMode = .byTruncatingTail
                card.addSubview(label)

                // Nút Xóa từng mục
                let delBtn = UIButton(type: .system)
                delBtn.setImage(UIImage(systemName: "trash", withConfiguration: trashConfig), for: .normal)
                delBtn.tintColor = .secondaryLabel
                delBtn.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    HapticManager.shared.playKeyTap()
                    ClipboardManager.shared.deleteClip(item)
                    self.rebuildListUI()
                    self.setNeedsLayout()
                }, for: .touchUpInside)
                card.addSubview(delBtn)

                // Nút Chạm vào thẻ để Dán
                let tapBtn = UIButton(type: .custom)
                tapBtn.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    HapticManager.shared.playKeyTap()
                    self.delegate?.clipboardView(self, didSelectClip: item)
                }, for: .touchUpInside)
                card.addSubview(tapBtn)
                card.sendSubviewToBack(tapBtn)

                scrollView.addSubview(card)
                cardViews.append(card)
            }
        }

        setNeedsLayout()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        let isDark = traitCollection.userInterfaceStyle == .dark
        let actionBtnBg = isDark ? UIColor(red: 54/255, green: 56/255, blue: 61/255, alpha: 1.0) : UIColor.white
        let actionBtnTint = isDark ? UIColor.white : UIColor(red: 31/255, green: 31/255, blue: 31/255, alpha: 1.0)

        [directPasteButton, clearAllButton].forEach {
            $0.backgroundColor = actionBtnBg
            $0.tintColor = actionBtnTint
            $0.setTitleColor(actionBtnTint, for: .normal)
            $0.layer.shadowColor = UIColor.black.cgColor
            $0.layer.shadowOpacity = 0.08
            $0.layer.shadowOffset = CGSize(width: 0, height: 1.0)
            $0.layer.shadowRadius = 1.0
        }

        let padW = bounds.width
        let padH = bounds.height

        // Top Header
        titleLabel.frame = CGRect(x: 16, y: 8, width: 140, height: 24)
        closeButton.frame = CGRect(x: padW - 44, y: 6, width: 32, height: 32)

        // Top Action Buttons
        let btnH: CGFloat = 28.0
        directPasteButton.frame = CGRect(x: 16, y: 36, width: 120, height: btnH)
        clearAllButton.frame = CGRect(x: 144, y: 36, width: 104, height: btnH)

        // Scrollable List Area (bên dưới hàng nút bấm)
        let listY: CGFloat = 70.0
        let listH: CGFloat = max(0, padH - listY)
        scrollView.frame = CGRect(x: 0, y: listY, width: padW, height: listH)

        if cardViews.isEmpty {
            emptyView.frame = CGRect(x: 0, y: 0, width: padW, height: listH)
            emptyIconView.frame = CGRect(x: (padW - 36) / 2.0, y: max(8, (listH - 70) / 2.0 - 16), width: 36, height: 36)
            emptyLabel.frame = CGRect(x: 16, y: emptyIconView.frame.maxY + 6, width: padW - 32, height: 36)
            scrollView.contentSize = CGSize(width: padW, height: listH)
        } else {
            let cardX: CGFloat = 12.0
            let cardW = max(100, padW - 24.0)
            let cardH: CGFloat = 46.0
            var currentY: CGFloat = 4.0

            for card in cardViews {
                card.frame = CGRect(x: cardX, y: currentY, width: cardW, height: cardH)

                // Subviews of card
                if let tapBtn = card.subviews.first(where: { $0 is UIButton && ($0 as? UIButton)?.buttonType == .custom }) {
                    tapBtn.frame = CGRect(x: 0, y: 0, width: cardW - 40, height: cardH)
                }
                if let delBtn = card.subviews.first(where: { $0 is UIButton && ($0 as? UIButton)?.buttonType == .system }) {
                    delBtn.frame = CGRect(x: cardW - 38, y: (cardH - 32) / 2.0, width: 32, height: 32)
                }
                if let label = card.subviews.first(where: { $0 is UILabel }) {
                    label.frame = CGRect(x: 12, y: 4, width: cardW - 54, height: cardH - 8)
                }

                currentY += cardH + 6.0
            }

            scrollView.contentSize = CGSize(width: padW, height: currentY + 10.0)
        }
    }

    // MARK: - Actions

    @objc private func handleClose() {
        HapticManager.shared.playSpecialKey()
        delegate?.clipboardViewDidRequestClose(self)
    }

    @objc private func handleDirectPaste() {
        HapticManager.shared.playSpecialKey()
        if let clip = UIPasteboard.general.string {
            let trimmed = clip.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                ClipboardManager.shared.addClip(trimmed)
                delegate?.clipboardView(self, didSelectClip: trimmed)
                return
            }
        }
        // Nếu không có trong UIPasteboard, lấy mục đầu tiên trong lịch sử
        if let first = ClipboardManager.shared.getHistory().first {
            delegate?.clipboardView(self, didSelectClip: first)
        }
    }

    @objc private func handleClearAll() {
        HapticManager.shared.playSpecialKey()
        ClipboardManager.shared.clearHistory()
        rebuildListUI()
    }
}
#endif
