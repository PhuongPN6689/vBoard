#if canImport(UIKit)
import UIKit

@MainActor
public protocol KeyCalloutViewDelegate: AnyObject {
    func keyCalloutView(_ calloutView: KeyCalloutView, didSelectItem text: String)
    func keyCalloutViewDidDismiss(_ calloutView: KeyCalloutView)
}

/// Bong bóng popover hiển thị danh sách ký tự nhấn giữ (Long Press Callout) chuẩn Gboard
@MainActor
public final class KeyCalloutView: UIView {
    public weak var delegate: KeyCalloutViewDelegate?

    private var items: [String] = []
    private var itemViews: [UILabel] = []
    private var selectedIndex: Int = 0
    private var isGrid: Bool = false
    private var gridColumns: Int = 8

    private let bubbleLayer = CAShapeLayer()
    private let contentView = UIView()

    public private(set) var isVisible: Bool = false
    private weak var sourceKeyView: UIView?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        backgroundColor = .clear
        isUserInteractionEnabled = false // Touches tracked by KeyView / KeyboardView

        bubbleLayer.fillColor = UIColor.white.cgColor
        bubbleLayer.shadowColor = UIColor.black.cgColor
        bubbleLayer.shadowOpacity = 0.28
        bubbleLayer.shadowOffset = CGSize(width: 0, height: 3.0)
        bubbleLayer.shadowRadius = 8.0
        layer.addSublayer(bubbleLayer)

        addSubview(contentView)
        isHidden = true
    }

    public func show(items: [String], defaultIndex: Int = 0, sourceKey: UIView, in containerView: UIView) {
        guard !items.isEmpty else { return }
        self.items = items
        self.selectedIndex = min(max(defaultIndex, 0), items.count - 1)
        self.sourceKeyView = sourceKey
        self.isVisible = true

        let isDark = containerView.traitCollection.userInterfaceStyle == .dark
        let bgColor = isDark ? UIColor(red: 45/255, green: 47/255, blue: 51/255, alpha: 1.0) : UIColor.white
        bubbleLayer.fillColor = bgColor.cgColor

        // Quyết định hiển thị dạng 1 hàng (nguyên âm / số) hay 2 hàng dạng lưới (ký hiệu phím phẩy Gboard)
        self.isGrid = items.count > 10
        if isGrid {
            self.gridColumns = 8
        }

        // Tái sử dụng hoặc tạo mới các item label
        for sub in contentView.subviews {
            sub.removeFromSuperview()
        }
        itemViews.removeAll()

        let textColor = isDark ? UIColor.white : UIColor(red: 31/255, green: 31/255, blue: 31/255, alpha: 1.0)

        for item in items {
            let label = UILabel()
            label.textAlignment = .center
            label.layer.cornerRadius = 6.0
            label.layer.masksToBounds = true

            if item == "⚙️" || item == "settings" {
                // Hiển thị biểu tượng bánh răng Vector
                label.text = nil
                let iconView = UIImageView(image: KeyboardIcons.settingsGearIcon(size: CGSize(width: 22, height: 22)))
                iconView.tintColor = textColor
                iconView.contentMode = .center
                iconView.tag = 999
                label.addSubview(iconView)
            } else if item == "☺" || item == "emoji" {
                // Hiển thị biểu tượng mặt cười Vector
                label.text = nil
                let iconView = UIImageView(image: KeyboardIcons.emojiSmileIcon(size: CGSize(width: 22, height: 22)))
                iconView.tintColor = textColor
                iconView.contentMode = .center
                iconView.tag = 999
                label.addSubview(iconView)
            } else {
                label.text = item
                label.font = (item.count > 1) ? UIFont.systemFont(ofSize: 15, weight: .medium) : UIFont.systemFont(ofSize: 19, weight: .regular)
                label.textColor = textColor
            }

            contentView.addSubview(label)
            itemViews.append(label)
        }

        // Layout kích thước
        let itemWidth: CGFloat = isGrid ? 38.0 : max(32.0, min(42.0, (containerView.bounds.width - 24.0) / CGFloat(items.count)))
        let itemHeight: CGFloat = 44.0
        let padding: CGFloat = 6.0

        let contentWidth: CGFloat
        let contentHeight: CGFloat

        if isGrid {
            let cols = min(gridColumns, items.count)
            let rows = Int(ceil(Double(items.count) / Double(cols)))
            contentWidth = CGFloat(cols) * itemWidth + padding * 2.0
            contentHeight = CGFloat(rows) * itemHeight + padding * 2.0
        } else {
            contentWidth = CGFloat(items.count) * itemWidth + padding * 2.0
            contentHeight = itemHeight + padding * 2.0
        }

        // Tính toạ độ hiển thị ngay phía trên sourceKey
        let keyRect = sourceKey.convert(sourceKey.bounds, to: containerView)
        var calloutX = keyRect.midX - (contentWidth / 2.0)
        // Đảm bảo không tràn viền trái/phải màn hình
        calloutX = max(6.0, min(containerView.bounds.width - contentWidth - 6.0, calloutX))
        
        // Đảm bảo không tràn lên trên mép trên của bàn phím iOS (tránh bị clip khi phím ở hàng trên cùng)
        var calloutY = keyRect.minY - contentHeight - 8.0
        calloutY = max(2.0, min(containerView.bounds.height - contentHeight - 2.0, calloutY))

        self.frame = CGRect(x: round(calloutX), y: round(calloutY), width: round(contentWidth), height: round(contentHeight))
        contentView.frame = bounds
        bubbleLayer.frame = bounds

        // Sắp xếp các item label
        if isGrid {
            let cols = min(gridColumns, items.count)
            for (idx, label) in itemViews.enumerated() {
                let r = idx / cols
                let c = idx % cols
                label.frame = CGRect(
                    x: padding + CGFloat(c) * itemWidth,
                    y: padding + CGFloat(r) * itemHeight,
                    width: itemWidth,
                    height: itemHeight
                )
            }
        } else {
            for (idx, label) in itemViews.enumerated() {
                label.frame = CGRect(
                    x: padding + CGFloat(idx) * itemWidth,
                    y: padding,
                    width: itemWidth,
                    height: itemHeight
                )
                if let iconView = label.viewWithTag(999) as? UIImageView {
                    iconView.frame = label.bounds
                }
            }
        }

        // Vẽ bubble background với bo tròn mềm mại chuẩn Gboard
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: 10.0)
        bubbleLayer.path = path.cgPath
        bubbleLayer.shadowPath = path.cgPath

        updateHighlight()
        isHidden = false
    }

    public func updateTouchLocation(_ pointInContainer: CGPoint) {
        guard isVisible, !itemViews.isEmpty else { return }
        let pointInCallout = convert(pointInContainer, from: superview)

        var closestIndex = selectedIndex
        var minDistance: CGFloat = .greatestFiniteMagnitude

        for (idx, view) in itemViews.enumerated() {
            let center = CGPoint(x: view.frame.midX, y: view.frame.midY)
            let dist = hypot(pointInCallout.x - center.x, pointInCallout.y - center.y)
            if dist < minDistance {
                minDistance = dist
                closestIndex = idx
            }
        }

        if closestIndex != selectedIndex {
            selectedIndex = closestIndex
            updateHighlight()
            // Haptic nhẹ khi trượt qua ký tự mới
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private func updateHighlight() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let highlightBg = isDark ? UIColor(red: 0/255, green: 137/255, blue: 123/255, alpha: 1.0) : UIColor(red: 26/255, green: 115/255, blue: 232/255, alpha: 1.0)
        let highlightText = UIColor.white
        let defaultText = isDark ? UIColor.white : UIColor(red: 31/255, green: 31/255, blue: 31/255, alpha: 1.0)

        for (idx, label) in itemViews.enumerated() {
            let isSelected = (idx == selectedIndex)
            if isSelected {
                label.backgroundColor = highlightBg
                label.textColor = highlightText
                label.font = UIFont.systemFont(ofSize: label.font.pointSize, weight: .bold)
                label.layer.cornerRadius = min(label.bounds.width, label.bounds.height) / 2.0
                label.layer.masksToBounds = true
                if let iconView = label.viewWithTag(999) as? UIImageView {
                    iconView.tintColor = highlightText
                }
            } else {
                label.backgroundColor = .clear
                label.textColor = defaultText
                label.font = UIFont.systemFont(ofSize: label.font.pointSize, weight: .regular)
                label.layer.cornerRadius = 6.0
                if let iconView = label.viewWithTag(999) as? UIImageView {
                    iconView.tintColor = defaultText
                }
            }
        }
    }

    public func commitSelection() -> String? {
        guard isVisible, selectedIndex >= 0, selectedIndex < items.count else {
            dismiss()
            return nil
        }
        let selected = items[selectedIndex]
        dismiss()
        return selected
    }

    public func dismiss() {
        isVisible = false
        isHidden = true
        sourceKeyView = nil
        items.removeAll()
        itemViews.removeAll()
        delegate?.keyCalloutViewDidDismiss(self)
    }

    // MARK: - Từ điển ký tự phụ Long Press chuẩn Gboard
    public static func calloutItems(for char: String, isShift: Bool) -> [String]? {
        let lower = char.lowercased()

        switch lower {
        // Số: hỗ trợ số mũ, chỉ số dưới hóa học (H₂O), phân số chuẩn Gboard
        case "0": return ["⁰", "₀", "°", "∅", "0"]
        case "1": return ["¹", "₁", "½", "⅓", "¼", "⅛", "1"]
        case "2": return ["²", "₂", "½", "⅔", "2"] // Hỗ trợ ký tự mũ 2 và chân 2 (công thức hóa học H₂O)
        case "3": return ["³", "₃", "¾", "⅜", "3"]
        case "4": return ["⁴", "₄", "4"]
        case "5": return ["⁵", "₅", "⅝", "5"]
        case "6": return ["⁶", "₆", "6"]
        case "7": return ["⁷", "₇", "⅞", "7"]
        case "8": return ["⁸", "₈", "8"]
        case "9": return ["⁹", "₉", "9"]

        // Nguyên âm tiếng Việt tinh gọn chuẩn Gboard (ưu tiên ký tự số/phụ ở đầu, các biến thể dấu phổ biến nhất)
        case "e":
            return isShift ?
                ["3", "E", "Ê", "É", "È", "Ẻ", "Ẽ", "Ẹ"] :
                ["3", "e", "ê", "é", "è", "ẻ", "ẽ", "ẹ"]
        case "a":
            return isShift ?
                ["1", "A", "Â", "Ă", "Á", "À", "Ả", "Ã", "Ạ"] :
                ["1", "a", "â", "ă", "á", "à", "ả", "ã", "ạ"]
        case "o":
            return isShift ?
                ["9", "O", "Ô", "Ơ", "Ó", "Ò", "Ỏ", "Õ", "Ọ"] :
                ["9", "o", "ô", "ơ", "ó", "ò", "ỏ", "õ", "ọ"]
        case "u":
            return isShift ?
                ["7", "U", "Ư", "Ú", "Ù", "Ủ", "Ũ", "Ụ"] :
                ["7", "u", "ư", "ú", "ù", "ủ", "ũ", "ụ"]
        case "i":
            return isShift ?
                ["8", "I", "Í", "Ì", "Ỉ", "Ĩ", "Ị"] :
                ["8", "i", "í", "ì", "ỉ", "ĩ", "ị"]
        case "y":
            return isShift ?
                ["6", "Y", "Ý", "Ỳ", "Ỷ", "Ỹ", "Ỵ"] :
                ["6", "y", "ý", "ỳ", "ỷ", "ỹ", "ỵ"]

        // Phụ âm đặc biệt tiếng Việt
        case "d":
            return isShift ? ["Đ", "D"] : ["đ", "d"]

        // Dấu chấm câu và ký hiệu (Bảng lưới 2 hàng x 8 cột = 16 ký hiệu chuẩn Gboard)
        case ".":
            return [
                "&", "%", "+", "\"", "-", ":", "'", "@",
                ";", "/", "(", ")", "#", "!", "?", "."
            ]
        case ",":
            // Phím phẩy tích hợp thao tác nhanh: Emoji, Cài đặt ứng dụng chính
            return ["☺", "⚙️"]

        // Ký tự tiền tệ & toán học
        case "$": return ["₫", "€", "£", "¥", "¢", "$"]
        case "+": return ["±", "+"]
        case "-": return ["–", "—", "•", "-"]
        case "%": return ["‰", "%"]
        case "/": return ["\\", "/"]

        default:
            return nil
        }
    }
}
#endif
