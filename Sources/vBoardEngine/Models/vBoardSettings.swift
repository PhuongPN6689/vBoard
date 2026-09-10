import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(CoreFoundation)
import CoreFoundation
#endif

/// Các mức kích thước chiều cao của bàn phím
public enum KeyboardHeightScale: String, CaseIterable, Identifiable, Sendable {
    case verySmall = "verySmall"
    case small = "small"
    case medium = "medium"
    case large = "large"
    case veryLarge = "veryLarge"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .verySmall: return "Rất nhỏ (85%)"
        case .small: return "Nhỏ (92%)"
        case .medium: return "Trung bình (100% - Mặc định)"
        case .large: return "Lớn (108%)"
        case .veryLarge: return "Rất lớn (115%)"
        }
    }

    public var phoneHeight: CGFloat {
        switch self {
        case .verySmall: return 205.0
        case .small: return 218.0
        case .medium: return 230.0
        case .large: return 246.0
        case .veryLarge: return 262.0
        }
    }

    public var padHeight: CGFloat {
        switch self {
        case .verySmall: return 240.0
        case .small: return 260.0
        case .medium: return 280.0
        case .large: return 305.0
        case .veryLarge: return 330.0
        }
    }
}

/// Tùy chọn chèn phím Tab trong Dev Mode
public enum DevTabBehavior: String, CaseIterable, Identifiable, Sendable {
    case fourSpaces = "fourSpaces"
    case twoSpaces = "twoSpaces"
    case tabChar = "tabChar"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fourSpaces: return "4 Khoảng trắng"
        case .twoSpaces: return "2 Khoảng trắng"
        case .tabChar: return "Ký tự Tab (\\t)"
        }
    }

    public var insertString: String {
        switch self {
        case .fourSpaces: return "    "
        case .twoSpaces: return "  "
        case .tabChar: return "\t"
        }
    }
}

/// Cường độ rung Taptic Engine
public enum HapticIntensity: String, CaseIterable, Identifiable, Sendable {
    case light = "light"
    case medium = "medium"
    case heavy = "heavy"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .light: return "Nhẹ"
        case .medium: return "Vừa"
        case .heavy: return "Mạnh"
        }
    }
}

/// Chế độ giao diện (Themes)
public enum ThemeMode: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "Tự động theo hệ thống"
        case .light: return "Luôn luôn Sáng (Light)"
        case .dark: return "Luôn luôn Tối (Dark)"
        }
    }
}


/// Chế độ gõ một tay (One-Handed Mode)
public enum OneHandedMode: String, CaseIterable, Identifiable, Sendable {
    case off = "off"
    case left = "left"
    case right = "right"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .off: return "Tắt (Toàn màn hình)"
        case .left: return "Bàn tay trái"
        case .right: return "Bàn tay phải"
        }
    }
}

/// Lựa chọn phông chữ cho bàn phím
public enum KeyboardFontFamily: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case rounded = "rounded"
    case mono = "mono"
    case serif = "serif"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return "San Francisco (Mặc định)"
        case .rounded: return "SF Pro Rounded (Bo tròn)"
        case .mono: return "SF Mono (Lập trình)"
        case .serif: return "New York (Serif Cổ điển)"
        }
    }
}

/// Danh mục Theme màu sắc & Gradient
public enum KeyboardColorTheme: String, CaseIterable, Identifiable, Sendable {
    case standard = "standard"
    case gboardSlate = "gboardSlate"
    case pitchBlack = "pitchBlack"
    case paperWhite = "paperWhite"
    case midnightNavy = "midnightNavy"
    case cyberpunk = "cyberpunk"
    case gradientPastelRose = "gradientPastelRose"
    case gradientSkyBreeze = "gradientSkyBreeze"
    case gradientMintWhisper = "gradientMintWhisper"
    case gradientTwilightPurple = "gradientTwilightPurple"
    case gradientDeepOcean = "gradientDeepOcean"
    case gradientSunsetGlow = "gradientSunsetGlow"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .standard: return "Chuẩn hệ thống Material You"
        case .gboardSlate: return "Gboard Dark Slate"
        case .pitchBlack: return "OLED Pitch Black"
        case .paperWhite: return "Clean Paper White"
        case .midnightNavy: return "Deep Midnight Navy"
        case .cyberpunk: return "Cyberpunk Neon"
        case .gradientPastelRose: return "Pastel Rose (Dốc nhẹ)"
        case .gradientSkyBreeze: return "Sky Breeze (Dốc nhẹ)"
        case .gradientMintWhisper: return "Mint Whisper (Dốc nhẹ)"
        case .gradientTwilightPurple: return "Twilight Purple (Dốc đứng)"
        case .gradientDeepOcean: return "Deep Ocean (Dốc đứng)"
        case .gradientSunsetGlow: return "Sunset Glow (Dốc đứng)"
        }
    }

    public var isGradient: Bool {
        return rawValue.starts(with: "gradient")
    }
}

/// Quản lý cấu hình toàn cục cho bàn phím vBoard (dùng chung cho Host App và Keyboard Extension)
public final class vBoardSettings: @unchecked Sendable {
    public static let shared = vBoardSettings()

    public static let appGroupSuiteName = "group.com.nguyenphuong.vBoard"
    public static let settingsChangedNotification = "com.nguyenphuong.vBoard.settingsChanged"

    private var defaults: UserDefaults {
        return UserDefaults(suiteName: vBoardSettings.appGroupSuiteName) ?? UserDefaults.standard
    }

    private init() {}

    /// Phát thông báo Darwin IPC để đồng bộ tức thì (< 0.1ms) sang Keyboard Extension
    public func notifySettingsChanged() {
        #if canImport(CoreFoundation)
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(Self.settingsChangedNotification as CFString),
            nil,
            nil,
            true
        )
        #endif
    }

    // MARK: - Keys
    private enum Keys {
        static let inputMethod = "vboard_input_method"
        static let diacriticStyle = "vboard_diacritic_style"
        static let isQuickTelexEnabled = "vboard_quick_telex"
        static let isBracketShortcutsEnabled = "vboard_bracket_shortcuts"
        static let isZKeyRemoveToneEnabled = "vboard_z_remove_tone"
        static let isWAtWordBeginningEnabled = "vboard_w_beginning"
        static let isModernToneBalancingEnabled = "vboard_tone_balancing"
        static let isAutoUndoEnabled = "vboard_auto_undo"

        static let keyboardHeightScale = "vboard_height_scale"
        static let isGlobeKeyHidden = "vboard_hide_globe_key"
        static let isNumberRowEnabled = "vboard_number_row"
        static let isHintSymbolsEnabled = "vboard_hint_symbols"

        static let isDeveloperModeButtonEnabled = "vboard_dev_button_enabled"
        static let developerTabBehavior = "vboard_dev_tab_behavior"
        static let isPairAutoCompleteEnabled = "vboard_pair_autocomplete"

        static let isHapticEnabled = "vboard_haptic_feedback"
        static let hapticIntensity = "vboard_haptic_intensity"
        static let isKeyPreviewEnabled = "vboard_key_preview"
        static let isSpaceDoubleTapPeriodEnabled = "vboard_space_double_tap"
        static let isSpaceCursorGlideEnabled = "vboard_space_cursor_glide"
        static let isSwipeDeleteEnabled = "vboard_swipe_delete"
        static let isContinuousDeleteEnabled = "vboard_continuous_delete"
        static let isAutoNumberPadEnabled = "vboard_auto_number_pad"
        static let longPressDelayMs = "vboard_long_press_delay_ms"

        static let themeMode = "vboard_theme_mode"
        static let accentColorHex = "vboard_accent_color_hex"

        static let isSuggestionBarEnabled = "vboard_suggestion_bar"
        static let isClipboardEnabled = "vboard_clipboard_enabled"
        static let isGlideTypingEnabled = "vboard_glide_typing"
                static let isShortcutExpansionEnabled = "vboard_shortcut_expansion"

        static let oneHandedMode = "vboard_one_handed_mode"
        static let toolbarItemsOrder = "vboard_toolbar_items_order"
        static let isNumberRowForPasswordEnabled = "vboard_number_row_password"
        static let isCommaKeyEnabled = "vboard_comma_key_enabled"
        static let isPeriodKeyEnabled = "vboard_period_key_enabled"
        static let fontFamily = "vboard_font_family"
        static let fontSizeScale = "vboard_font_size_scale"
        static let isAutoCapitalizationEnabled = "vboard_auto_capitalization"
        static let isAutoSpaceAfterPunctuationEnabled = "vboard_auto_space_punctuation"
        static let isAutoSwitchToABCAfterApostropheEnabled = "vboard_auto_abc_apostrophe"
        static let isKeySoundEnabled = "vboard_key_sound_enabled"
        static let soundVolume = "vboard_sound_volume"
        static let isFlickDownEnabled = "vboard_flick_down_enabled"
        static let isNextWordPredictionEnabled = "vboard_next_word_prediction"
        static let isTextToEmojiEnabled = "vboard_text_to_emoji"
        static let colorTheme = "vboard_color_theme"
        static let isKeyBorderEnabled = "vboard_key_border_enabled"
        static let isGlideTrailEnabled = "vboard_glide_trail_enabled"

        // OpenKey Enhanced Settings
        static let isSpellingCheckEnabled = "vboard_spelling_check"
        static let isFixBrowserSuggestionEnabled = "vboard_fix_browser_suggestion"
        static let isRestoreIfWrongSpellingEnabled = "vboard_restore_wrong_spelling"
        static let isAllowConsonantZFWJEnabled = "vboard_allow_zfwj"
        static let isSmartSwitchModeEnabled = "vboard_smart_switch_mode"
        static let isMacroEvenWhenOffEnabled = "vboard_macro_even_when_off"
        static let isAutoCapsMacroEnabled = "vboard_auto_caps_macro"
        static let isQuickStartConsonantEnabled = "vboard_quick_start_consonant"
        static let isQuickEndConsonantEnabled = "vboard_quick_end_consonant"
    }

    // MARK: - Properties: OpenKey Core Settings

    public var inputMethod: InputMethod {
        get {
            let raw = defaults.string(forKey: Keys.inputMethod) ?? "telex"
            switch raw {
            case "vni": return .vni
            case "simpleTelex": return .simpleTelex
            default: return .telex
            }
        }
        set {
            defaults.set(newValue == .vni ? "vni" : (newValue == .simpleTelex ? "simpleTelex" : "telex"), forKey: Keys.inputMethod)
        }
    }

    public var diacriticStyle: DiacriticStyle {
        get {
            let raw = defaults.string(forKey: Keys.diacriticStyle) ?? "newStyle"
            return raw == "oldStyle" ? .oldStyle : .newStyle
        }
        set {
            defaults.set(newValue == .oldStyle ? "oldStyle" : "newStyle", forKey: Keys.diacriticStyle)
        }
    }

    public var isQuickTelexEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isQuickTelexEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isQuickTelexEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isQuickTelexEnabled)
        }
    }

    public var isBracketShortcutsEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isBracketShortcutsEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isBracketShortcutsEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isBracketShortcutsEnabled)
        }
    }

    public var isZKeyRemoveToneEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isZKeyRemoveToneEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isZKeyRemoveToneEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isZKeyRemoveToneEnabled)
        }
    }

    public var isWAtWordBeginningEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isWAtWordBeginningEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isWAtWordBeginningEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isWAtWordBeginningEnabled)
        }
    }

    public var isModernToneBalancingEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isModernToneBalancingEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isModernToneBalancingEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isModernToneBalancingEnabled)
        }
    }

    public var isAutoUndoEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isAutoUndoEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isAutoUndoEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isAutoUndoEnabled)
        }
    }

    /// Kiểm tra chính tả tiếng Việt (ngăn chặn bỏ dấu sai nguyên âm / phụ âm sai)
    public var isSpellingCheckEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isSpellingCheckEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isSpellingCheckEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isSpellingCheckEnabled)
        }
    }

    /// Sửa lỗi gợi ý nhập liệu (trình duyệt, thanh tìm kiếm...)
    public var isFixBrowserSuggestionEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isFixBrowserSuggestionEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isFixBrowserSuggestionEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isFixBrowserSuggestionEnabled)
        }
    }

    /// Tự khôi phục phím gốc với từ sai chính tả
    public var isRestoreIfWrongSpellingEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isRestoreIfWrongSpellingEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isRestoreIfWrongSpellingEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isRestoreIfWrongSpellingEnabled)
        }
    }

    /// Cho phép các ký tự "z, w, j, f" làm phụ âm (tên riêng, từ mượn ngoại lai...)
    public var isAllowConsonantZFWJEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isAllowConsonantZFWJEnabled) == nil { return false }
            return defaults.bool(forKey: Keys.isAllowConsonantZFWJEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isAllowConsonantZFWJEnabled)
        }
    }

    /// Chuyển chế độ thông minh (tự động nhận biết tiếng Anh / tiếng Việt)
    public var isSmartSwitchModeEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isSmartSwitchModeEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isSmartSwitchModeEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isSmartSwitchModeEnabled)
        }
    }

    /// Gõ tắt cả khi tắt gõ tiếng Việt (chế độ tiếng Anh ABC)
    public var isMacroEvenWhenOffEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isMacroEvenWhenOffEnabled) == nil { return false }
            return defaults.bool(forKey: Keys.isMacroEvenWhenOffEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isMacroEvenWhenOffEnabled)
        }
    }

    /// Tự động viết hoa / viết thường theo từ khóa gõ tắt
    public var isAutoCapsMacroEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isAutoCapsMacroEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isAutoCapsMacroEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isAutoCapsMacroEnabled)
        }
    }

    /// Gõ tắt phụ âm đầu: f -> ph, j -> gi, w -> qu
    public var isQuickStartConsonantEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isQuickStartConsonantEnabled) == nil { return false }
            return defaults.bool(forKey: Keys.isQuickStartConsonantEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isQuickStartConsonantEnabled)
        }
    }

    /// Gõ tắt phụ âm cuối: g -> ng, h -> nh, k -> ch
    public var isQuickEndConsonantEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isQuickEndConsonantEnabled) == nil { return false }
            return defaults.bool(forKey: Keys.isQuickEndConsonantEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isQuickEndConsonantEnabled)
        }
    }

    // MARK: - Properties: Bố cục & Kích thước bàn phím

    public var keyboardHeightScale: KeyboardHeightScale {
        get {
            let raw = defaults.string(forKey: Keys.keyboardHeightScale) ?? "medium"
            return KeyboardHeightScale(rawValue: raw) ?? .medium
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.keyboardHeightScale)
        }
    }

    /// Ẩn hoàn toàn phím quả cầu để mở rộng tối đa phím Spacebar (mặc định: bật ẩn)
    public var isGlobeKeyHidden: Bool {
        get {
            if defaults.object(forKey: Keys.isGlobeKeyHidden) == nil { return true }
            return defaults.bool(forKey: Keys.isGlobeKeyHidden)
        }
        set {
            defaults.set(newValue, forKey: Keys.isGlobeKeyHidden)
        }
    }

    /// Hiển thị hàng phím số chuyên dụng ở trên cùng
    public var isNumberRowEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isNumberRowEnabled) == nil { return false }
            return defaults.bool(forKey: Keys.isNumberRowEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isNumberRowEnabled)
        }
    }

    /// Hiển thị ký tự phụ nhỏ ở góc trên bên phải các phím chữ
    public var isHintSymbolsEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isHintSymbolsEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isHintSymbolsEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isHintSymbolsEnabled)
        }
    }

    // MARK: - Properties: Developer Mode

    public var isDeveloperModeButtonEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isDeveloperModeButtonEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isDeveloperModeButtonEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isDeveloperModeButtonEnabled)
        }
    }

    public var developerTabBehavior: DevTabBehavior {
        get {
            let raw = defaults.string(forKey: Keys.developerTabBehavior) ?? "fourSpaces"
            return DevTabBehavior(rawValue: raw) ?? .fourSpaces
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.developerTabBehavior)
        }
    }

    public var isPairAutoCompleteEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isPairAutoCompleteEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isPairAutoCompleteEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isPairAutoCompleteEnabled)
        }
    }

    // MARK: - Properties: Cử chỉ & Phản hồi

    public var isHapticEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isHapticEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isHapticEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isHapticEnabled)
        }
    }

    public var hapticIntensity: HapticIntensity {
        get {
            let raw = defaults.string(forKey: Keys.hapticIntensity) ?? "light"
            return HapticIntensity(rawValue: raw) ?? .light
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.hapticIntensity)
        }
    }

    public var isKeyPreviewEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isKeyPreviewEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isKeyPreviewEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isKeyPreviewEnabled)
        }
    }

    public var isSpaceDoubleTapPeriodEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isSpaceDoubleTapPeriodEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isSpaceDoubleTapPeriodEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isSpaceDoubleTapPeriodEnabled)
        }
    }

    public var isSpaceCursorGlideEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isSpaceCursorGlideEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isSpaceCursorGlideEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isSpaceCursorGlideEnabled)
        }
    }

    public var isSwipeDeleteEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isSwipeDeleteEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isSwipeDeleteEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isSwipeDeleteEnabled)
        }
    }

    public var isContinuousDeleteEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isContinuousDeleteEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isContinuousDeleteEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isContinuousDeleteEnabled)
        }
    }

    public var isAutoNumberPadEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isAutoNumberPadEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isAutoNumberPadEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isAutoNumberPadEnabled)
        }
    }

    /// Độ trễ nhấn giữ (mili-giây, mặc định 250ms chuẩn Gboard)
    public var longPressDelayMs: Int {
        get {
            let val = defaults.integer(forKey: Keys.longPressDelayMs)
            return val == 0 ? 250 : val
        }
        set {
            defaults.set(newValue, forKey: Keys.longPressDelayMs)
        }
    }

    // MARK: - Properties: Giao diện & Chủ đề Màu sắc

    public var themeMode: ThemeMode {
        get {
            let raw = defaults.string(forKey: Keys.themeMode) ?? "system"
            return ThemeMode(rawValue: raw) ?? .system
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.themeMode)
        }
    }

    public var accentColorHex: String {
        get {
            return defaults.string(forKey: Keys.accentColorHex) ?? "#1a73e8"
        }
        set {
            defaults.set(newValue, forKey: Keys.accentColorHex)
        }
    }

    // MARK: - Properties: Gợi ý từ, Bảng tạm & Gõ lướt

    public var isSuggestionBarEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isSuggestionBarEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isSuggestionBarEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isSuggestionBarEnabled)
        }
    }

    public var isClipboardEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isClipboardEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isClipboardEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isClipboardEnabled)
        }
    }

    public var isGlideTypingEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isGlideTypingEnabled) == nil { return false }
            return defaults.bool(forKey: Keys.isGlideTypingEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isGlideTypingEnabled)
        }
    }

    /// Bật/Tắt tính năng tự động thay thế gõ tắt (Macro) khi gõ phím Space
    public var isShortcutExpansionEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isShortcutExpansionEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isShortcutExpansionEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isShortcutExpansionEnabled)
        }
    }

    // MARK: - Properties: Tính năng mở rộng v1.2.0 & v2.0

    public var oneHandedMode: OneHandedMode {
        get {
            let raw = defaults.string(forKey: Keys.oneHandedMode) ?? "off"
            return OneHandedMode(rawValue: raw) ?? .off
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.oneHandedMode)
        }
    }

    public var toolbarItemsOrder: [String] {
        get {
            return defaults.stringArray(forKey: Keys.toolbarItemsOrder) ?? [
                "clipboard", "dev", "undoRedo", "quickSettings", "oneHanded"
            ]
        }
        set {
            defaults.set(newValue, forKey: Keys.toolbarItemsOrder)
        }
    }

    public var isNumberRowForPasswordEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isNumberRowForPasswordEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isNumberRowForPasswordEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isNumberRowForPasswordEnabled)
        }
    }

    public var isCommaKeyEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isCommaKeyEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isCommaKeyEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isCommaKeyEnabled)
        }
    }

    public var isPeriodKeyEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isPeriodKeyEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isPeriodKeyEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isPeriodKeyEnabled)
        }
    }

    public var fontFamily: KeyboardFontFamily {
        get {
            let raw = defaults.string(forKey: Keys.fontFamily) ?? "system"
            return KeyboardFontFamily(rawValue: raw) ?? .system
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.fontFamily)
        }
    }

    public var fontSizeScale: Double {
        get {
            let val = defaults.double(forKey: Keys.fontSizeScale)
            return val == 0 ? 1.0 : val
        }
        set {
            defaults.set(newValue, forKey: Keys.fontSizeScale)
        }
    }

    public var isAutoCapitalizationEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isAutoCapitalizationEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isAutoCapitalizationEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isAutoCapitalizationEnabled)
        }
    }

    public var isAutoSpaceAfterPunctuationEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isAutoSpaceAfterPunctuationEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isAutoSpaceAfterPunctuationEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isAutoSpaceAfterPunctuationEnabled)
        }
    }

    public var isAutoSwitchToABCAfterApostropheEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isAutoSwitchToABCAfterApostropheEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isAutoSwitchToABCAfterApostropheEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isAutoSwitchToABCAfterApostropheEnabled)
        }
    }

    public var isKeySoundEnabled: Bool {
        get {
            return defaults.bool(forKey: Keys.isKeySoundEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isKeySoundEnabled)
        }
    }

    public var soundVolume: Float {
        get {
            let val = defaults.float(forKey: Keys.soundVolume)
            return val == 0 ? 0.5 : val
        }
        set {
            defaults.set(newValue, forKey: Keys.soundVolume)
        }
    }

    public var isFlickDownEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isFlickDownEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isFlickDownEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isFlickDownEnabled)
        }
    }

    public var isNextWordPredictionEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isNextWordPredictionEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isNextWordPredictionEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isNextWordPredictionEnabled)
        }
    }

    public var isTextToEmojiEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isTextToEmojiEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isTextToEmojiEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isTextToEmojiEnabled)
        }
    }

    public var colorTheme: KeyboardColorTheme {
        get {
            let raw = defaults.string(forKey: Keys.colorTheme) ?? "standard"
            return KeyboardColorTheme(rawValue: raw) ?? .standard
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.colorTheme)
        }
    }

    public var isKeyBorderEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isKeyBorderEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isKeyBorderEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isKeyBorderEnabled)
        }
    }

    public var isGlideTrailEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.isGlideTrailEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.isGlideTrailEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isGlideTrailEnabled)
        }
    }
}
