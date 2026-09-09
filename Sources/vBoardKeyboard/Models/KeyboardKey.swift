#if canImport(UIKit)
import UIKit

public enum KeyType: Equatable, Sendable {
    case character(String)
    case space
    case delete
    case shift
    case returnKey
    case modeSwitch(String) // "123", "ABC", "#+="
    case globe
    case emoji
    case dismiss
}

public struct KeyboardKey: Equatable, Sendable {
    public let type: KeyType
    public let displayLabel: String
    public let secondaryLabel: String?
    public let flexWeight: CGFloat
    public let returnKeyType: UIReturnKeyType

    public init(
        type: KeyType,
        displayLabel: String,
        secondaryLabel: String? = nil,
        flexWeight: CGFloat = 1.0,
        returnKeyType: UIReturnKeyType = .default
    ) {
        self.type = type
        self.displayLabel = displayLabel
        self.secondaryLabel = secondaryLabel
        self.flexWeight = flexWeight
        self.returnKeyType = returnKeyType
    }

    public static func char(_ char: String, secondary: String? = nil, weight: CGFloat = 1.0) -> KeyboardKey {
        return KeyboardKey(type: .character(char), displayLabel: char, secondaryLabel: secondary, flexWeight: weight)
    }

    public static func space(label: String = "Tiếng Việt", weight: CGFloat = 4.4) -> KeyboardKey {
        return KeyboardKey(type: .space, displayLabel: label, secondaryLabel: nil, flexWeight: weight)
    }

    public static func delete(weight: CGFloat = 1.55) -> KeyboardKey {
        return KeyboardKey(type: .delete, displayLabel: "⌫", secondaryLabel: nil, flexWeight: weight)
    }

    public static func shift(isCapsLocked: Bool = false, isShiftActive: Bool = false, weight: CGFloat = 1.55) -> KeyboardKey {
        let label = isCapsLocked ? "⇪" : (isShiftActive ? "⬆" : "⇧")
        return KeyboardKey(type: .shift, displayLabel: label, secondaryLabel: nil, flexWeight: weight)
    }

    public static func returnKey(actionType: UIReturnKeyType = .default, label: String = "nhập", weight: CGFloat = 1.55) -> KeyboardKey {
        return KeyboardKey(type: .returnKey, displayLabel: label, secondaryLabel: nil, flexWeight: weight, returnKeyType: actionType)
    }

    public static func modeSwitch(_ label: String, weight: CGFloat = 1.55) -> KeyboardKey {
        return KeyboardKey(type: .modeSwitch(label), displayLabel: label, secondaryLabel: nil, flexWeight: weight)
    }

    public static func globe(weight: CGFloat = 1.0) -> KeyboardKey {
        return KeyboardKey(type: .globe, displayLabel: "🌐", secondaryLabel: nil, flexWeight: weight)
    }

    public static func emoji(weight: CGFloat = 1.0) -> KeyboardKey {
        return KeyboardKey(type: .emoji, displayLabel: "☺", secondaryLabel: nil, flexWeight: weight)
    }

    public static func dismiss(weight: CGFloat = 1.0) -> KeyboardKey {
        return KeyboardKey(type: .dismiss, displayLabel: "▼", secondaryLabel: nil, flexWeight: weight)
    }
}
#endif
