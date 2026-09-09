#if canImport(UIKit)
import UIKit
import vBoardEngine

@MainActor
public protocol EmojiPickerViewDelegate: AnyObject {
    func emojiPickerView(_ view: EmojiPickerView, didSelectEmoji emoji: String)
    func emojiPickerViewDidRequestBackspace(_ view: EmojiPickerView)
    func emojiPickerViewDidRequestSwitchToABC(_ view: EmojiPickerView)
}

/// Danh mục Emoji
public struct EmojiCategory: Sendable {
    public let title: String
    public let iconName: String
    public let emojis: [String]
}

/// Bảng chọn Emoji chuyên dụng thuần UIKit siêu nhẹ (RAM < 2MB)
@MainActor
public final class EmojiPickerView: UIView, UIScrollViewDelegate {
    public weak var delegate: EmojiPickerViewDelegate?

    private let scrollView = UIScrollView()
    private let bottomToolbar = UIView()
    private let abcButton = UIButton(type: .system)
    private let backspaceButton = UIButton(type: .system)
    private var categoryTabButtons: [UIButton] = []

    private var categories: [EmojiCategory] = []
    private var categoryOffsets: [CGFloat] = []
    private var selectedCategoryIndex: Int = 0

    // Key lưu lịch sử emoji
    private static let recentsKey = "vboard_emoji_recents"
    private var recentEmojis: [String] = []

    public override init(frame: CGRect) {
        super.init(frame: frame)
        loadRecents()
        setupCategories()
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func loadRecents() {
        let defaults = UserDefaults(suiteName: vBoardSettings.appGroupSuiteName) ?? UserDefaults.standard
        recentEmojis = defaults.stringArray(forKey: Self.recentsKey) ?? [
            "😊", "😂", "❤️", "👍", "🔥", "🎉", "🙏", "😍", "🤣", "🥺", "✨", "💯"
        ]
    }

    private func saveRecent(_ emoji: String) {
        recentEmojis.removeAll { $0 == emoji }
        recentEmojis.insert(emoji, at: 0)
        if recentEmojis.count > 32 {
            recentEmojis = Array(recentEmojis.prefix(32))
        }
        let defaults = UserDefaults(suiteName: vBoardSettings.appGroupSuiteName) ?? UserDefaults.standard
        defaults.set(recentEmojis, forKey: Self.recentsKey)
    }

    private func setupCategories() {
        categories = [
            EmojiCategory(
                title: "Gần đây",
                iconName: "clock",
                emojis: recentEmojis
            ),
            EmojiCategory(
                title: "Mặt cười & Cảm xúc",
                iconName: "face.smiling",
                emojis: [
                    "😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "🥲", "🥹", "😊", "😇",
                    "🙂", "🙃", "😉", "😌", "😍", "🥰", "😘", "😗", "😙", "😚", "😋", "😛",
                    "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🥸", "🤩", "🥳", "😏", "😒",
                    "😞", "😔", "😟", "😕", "🙁", "😣", "😖", "😫", "😩", "🥺", "😢", "😭",
                    "😮‍💨", "😤", "😠", "😡", "🤬", "🤯", "😳", "🥵", "🥶", "😱", "😨", "😰",
                    "😥", "😓", "🫣", "🤗", "🫡", "🤔", "🫢", "🤫", "🤥", "😶", "😶‍🌫️", "😐",
                    "😑", "😬", "🫠", "🙄", "😯", "😦", "😧", "😮", "😲", "🥱", "😴", "🤤"
                ]
            ),
            EmojiCategory(
                title: "Cử chỉ & Con người",
                iconName: "hand.thumbsup",
                emojis: [
                    "👋", "🤚", "🖐️", "✋", "🖖", "🫱", "🫲", "🫳", "🫴", "👌", "🤌", "🤏",
                    "✌️", "🤞", "🫰", "🤟", "🤘", "🤙", "👈", "👉", "👆", "🖕", "👇", "☝️",
                    "🫵", "👍", "👎", "✊", "👊", "🤛", "🤜", "👏", "🙌", "🫶", "👐", "🤲",
                    "🤝", "🙏", "✍️", "💅", "🤳", "💪", "🦾", "🦿", "🦵", "🦶", "👂", "🦻",
                    "👃", "🧠", "🫀", "🫁", "🦷", "🦴", "👀", "👁️", "👅", "👄", "🫦", "👶"
                ]
            ),
            EmojiCategory(
                title: "Động vật & Tự nhiên",
                iconName: "hare",
                emojis: [
                    "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐻‍❄️", "🐨", "🐯", "🦁",
                    "🐮", "🐷", "🐽", "🐸", "🐵", "🙈", "🙉", "🙊", "🐒", "🐔", "🐧", "🐦",
                    "🐤", "🐣", "🐥", "🦆", "🦅", "🦉", "🦇", "🐺", "🐗", "🐴", "🦄", "🐝",
                    "🪱", "🐛", "🦋", "🐌", "🐞", "🐜", "🪰", "🪲", "🪳", "🪴", "🌲", "🌳",
                    "🌴", "🌵", "🌾", "🌿", "☘️", "🍀", "🍁", "🍂", "🍃", "🍄", "🌸", "🌺"
                ]
            ),
            EmojiCategory(
                title: "Đồ ăn & Thức uống",
                iconName: "fork.knife",
                emojis: [
                    "🍏", "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍈", "🍒",
                    "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🥑", "🍆", "🥔", "🥕", "🌽", "🌶️",
                    "🫑", "🥒", "🥬", "🥦", "🧄", "🧅", "🍞", "🥐", "🥖", "🫓", "🥨", "🥯",
                    "🥞", "🧇", "🧀", "🍖", "🍗", "🥩", "🥓", "🍔", "🍟", "🍕", "🌭", "🥪",
                    "🌮", "🌯", "🫔", "🥙", "🧆", "🍜", "🍝", "🍣", "🍱", "🥟", "🧋", "☕️"
                ]
            ),
            EmojiCategory(
                title: "Hoạt động & Thể thao",
                iconName: "sportscourt",
                emojis: [
                    "⚽️", "🏀", "🏈", "⚾️", "🥎", "🎾", "🏐", "🏉", "🥏", "🎱", "🪀", "🏓",
                    "🏸", "🏒", "🏑", "🥍", "🏏", "🪃", "🥅", "⛳️", "🪁", "🏹", "🎣", "🤿",
                    "🥊", "🥋", "🎽", "🛹", "🛼", "🛷", "⛸️", "🥌", "🎿", "⛷️", "🏂", "🪂",
                    "🏋️", "🤼", "🤸", "🤺", "⛹️", "🤾", "🧗", "🧘", "🏆", "🥇", "🥈", "🥉"
                ]
            ),
            EmojiCategory(
                title: "Du lịch & Phương tiện",
                iconName: "car",
                emojis: [
                    "🚗", "🚕", "🚙", "🚌", "🚎", "🏎️", "🚓", "🚑", "🚒", "🚐", "🛻", "🚚",
                    "🚛", "🚜", "🦯", "🦽", "🦼", "🛴", "🚲", "🛵", "🏍️", "🛺", "🚨", "🚔",
                    "✈️", "🛫", "🛬", "🛩️", "🚀", "🚁", "🚂", "🚆", "🚄", "🚅", "🚈", "🚝",
                    "🗺️", "🗾", "🏔️", "⛰️", "🌋", "🗻", "🏕️", "🏖️", "🏜️", "🏝️", "🌅", "🌄"
                ]
            ),
            EmojiCategory(
                title: "Ký hiệu & Trái tim",
                iconName: "heart",
                emojis: [
                    "❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", "❤️‍🔥", "❤️‍🩹",
                    "❣️", "💕", "💞", "💓", "💗", "💖", "💘", "💝", "💟", "☮️", "✝️", "☪️",
                    "🕉️", "☸️", "✡️", "🔯", "🕎", "☯️", "☦️", "🛐", "⛎", "♈️", "♉️", "♊️",
                    "♋️", "♌️", "♍️", "♎️", "♏️", "♐️", "♑️", "♒️", "♓️", "🆔", "⚛️", "🉑",
                    "☢️", "☣️", "📴", "📳", "🈶", "🈚️", "🈸", "🈺", "🉐", "㊙️", "㊗️", "🈴",
                    "💯", "💢", "♨️", "🚷", "🚯", "🚳", "🚱", "🔞", "📵", "🚭", "❗️", "❓"
                ]
            )
        ]
    }

    private func setupUI() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        backgroundColor = isDark ? UIColor(red: 30/255, green: 31/255, blue: 34/255, alpha: 1.0) : UIColor(red: 241/255, green: 243/255, blue: 244/255, alpha: 1.0)

        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)

        // Bottom toolbar
        bottomToolbar.backgroundColor = isDark ? UIColor(red: 24/255, green: 25/255, blue: 27/255, alpha: 1.0) : UIColor(red: 230/255, green: 232/255, blue: 235/255, alpha: 1.0)
        addSubview(bottomToolbar)

        // ABC Button
        abcButton.setTitle("ABC", for: .normal)
        abcButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        abcButton.setTitleColor(isDark ? .white : .black, for: .normal)
        abcButton.backgroundColor = isDark ? UIColor(red: 45/255, green: 47/255, blue: 51/255, alpha: 1.0) : UIColor.white
        abcButton.layer.cornerRadius = 6.0
        abcButton.addTarget(self, action: #selector(handleABCTap), for: .touchUpInside)
        bottomToolbar.addSubview(abcButton)

        // Category Tab Buttons
        for (index, cat) in categories.enumerated() {
            let btn = UIButton(type: .system)
            let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            btn.setImage(UIImage(systemName: cat.iconName, withConfiguration: config), for: .normal)
            btn.tintColor = (index == selectedCategoryIndex) ? UIColor.systemBlue : UIColor.secondaryLabel
            btn.tag = index
            btn.addTarget(self, action: #selector(handleCategoryTabTap(_:)), for: .touchUpInside)
            bottomToolbar.addSubview(btn)
            categoryTabButtons.append(btn)
        }

        // Backspace button
        let bsConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        backspaceButton.setImage(UIImage(systemName: "delete.backward", withConfiguration: bsConfig), for: .normal)
        backspaceButton.tintColor = isDark ? .white : .black
        backspaceButton.backgroundColor = isDark ? UIColor(red: 45/255, green: 47/255, blue: 51/255, alpha: 1.0) : UIColor.white
        backspaceButton.layer.cornerRadius = 6.0
        backspaceButton.addTarget(self, action: #selector(handleBackspaceTap), for: .touchUpInside)
        bottomToolbar.addSubview(backspaceButton)
    }

    public func reloadContent() {
        loadRecents()
        if !categories.isEmpty {
            categories[0] = EmojiCategory(title: "Gần đây", iconName: "clock", emojis: recentEmojis)
        }
        rebuildEmojiGrid()
    }

    private func rebuildEmojiGrid() {
        scrollView.subviews.forEach { $0.removeFromSuperview() }
        categoryOffsets.removeAll()

        let totalWidth = bounds.width
        let columns: CGFloat = 8.0
        let itemWidth: CGFloat = totalWidth / columns
        let itemHeight: CGFloat = 42.0

        var currentY: CGFloat = 4.0

        for (catIndex, category) in categories.enumerated() {
            categoryOffsets.append(currentY)

            // Category Header
            let header = UILabel(frame: CGRect(x: 12, y: currentY, width: totalWidth - 24, height: 24))
            header.text = category.title
            header.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            header.textColor = .secondaryLabel
            scrollView.addSubview(header)
            currentY += 28.0

            // Emojis in category
            for (i, emoji) in category.emojis.enumerated() {
                let col = CGFloat(i % Int(columns))
                let row = CGFloat(i / Int(columns))
                let x = col * itemWidth
                let y = currentY + (row * itemHeight)

                let btn = UIButton(type: .system)
                btn.frame = CGRect(x: x, y: y, width: itemWidth, height: itemHeight)
                btn.setTitle(emoji, for: .normal)
                btn.titleLabel?.font = UIFont.systemFont(ofSize: 28.0)
                btn.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    self.selectEmoji(emoji)
                }, for: .touchUpInside)
                scrollView.addSubview(btn)
            }

            let totalRows = ceil(CGFloat(category.emojis.count) / columns)
            currentY += (totalRows * itemHeight) + 12.0
        }

        scrollView.contentSize = CGSize(width: totalWidth, height: currentY + 16.0)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 && bounds.height > 0 else { return }

        let toolbarHeight: CGFloat = 42.0
        bottomToolbar.frame = CGRect(x: 0, y: bounds.height - toolbarHeight, width: bounds.width, height: toolbarHeight)
        scrollView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - toolbarHeight)

        // Bottom toolbar items layout
        let sideBtnWidth: CGFloat = 50.0
        abcButton.frame = CGRect(x: 6, y: 5, width: sideBtnWidth, height: 32)
        backspaceButton.frame = CGRect(x: bounds.width - sideBtnWidth - 6, y: 5, width: sideBtnWidth, height: 32)

        let remainingWidth = bounds.width - (sideBtnWidth * 2) - 24
        let catBtnWidth = remainingWidth / CGFloat(categoryTabButtons.count)
        var catX = sideBtnWidth + 12

        for btn in categoryTabButtons {
            btn.frame = CGRect(x: catX, y: 5, width: catBtnWidth, height: 32)
            catX += catBtnWidth
        }

        if scrollView.subviews.isEmpty || scrollView.frame.width != bounds.width {
            rebuildEmojiGrid()
        }
    }

    private func selectEmoji(_ emoji: String) {
        HapticManager.shared.playKeyTap()
        saveRecent(emoji)
        delegate?.emojiPickerView(self, didSelectEmoji: emoji)
    }

    @objc private func handleABCTap() {
        HapticManager.shared.playSpecialKey()
        delegate?.emojiPickerViewDidRequestSwitchToABC(self)
    }

    @objc private func handleBackspaceTap() {
        HapticManager.shared.playKeyTap()
        delegate?.emojiPickerViewDidRequestBackspace(self)
    }

    @objc private func handleCategoryTabTap(_ sender: UIButton) {
        let index = sender.tag
        guard index >= 0 && index < categoryOffsets.count else { return }
        selectedCategoryIndex = index
        updateCategoryButtonsUI()

        let targetY = categoryOffsets[index]
        let maxOffsetY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
        let clampedY = min(targetY, maxOffsetY)
        scrollView.setContentOffset(CGPoint(x: 0, y: clampedY), animated: true)
        HapticManager.shared.playSpecialKey()
    }

    private func updateCategoryButtonsUI() {
        for (i, btn) in categoryTabButtons.enumerated() {
            btn.tintColor = (i == selectedCategoryIndex) ? UIColor.systemBlue : UIColor.secondaryLabel
        }
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let currentY = scrollView.contentOffset.y + 10.0
        var activeIndex = 0
        for (i, offset) in categoryOffsets.enumerated() {
            if currentY >= offset {
                activeIndex = i
            }
        }
        if activeIndex != selectedCategoryIndex {
            selectedCategoryIndex = activeIndex
            updateCategoryButtonsUI()
        }
    }
}
#endif
