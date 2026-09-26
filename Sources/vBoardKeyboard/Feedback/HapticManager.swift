#if canImport(UIKit)
import UIKit
import vBoardEngine

/// Quản lý phản hồi xúc giác (Haptic Feedback) siêu nhạy không độ trễ
@MainActor
public final class HapticManager {
    public static let shared = HapticManager()

    public var isEnabled: Bool {
        get { vBoardSettings.shared.isHapticEnabled }
        set { vBoardSettings.shared.isHapticEnabled = newValue }
    }

    private var impactGenerator: UIImpactFeedbackGenerator?
    private var selectionGenerator: UISelectionFeedbackGenerator?

    private init() {
        prepare()
    }

    /// Khởi động sẵn Taptic Engine (Pre-warm) để gõ không bị trễ
    public func prepare() {
        guard isEnabled else { return }
        if impactGenerator == nil {
            impactGenerator = UIImpactFeedbackGenerator(style: .light)
        }
        impactGenerator?.prepare()

        if selectionGenerator == nil {
            selectionGenerator = UISelectionFeedbackGenerator()
        }
        selectionGenerator?.prepare()
    }

    /// Rung khi chạm phím thường
    public func playKeyTap() {
        guard isEnabled else { return }
        let intensity: CGFloat
        switch vBoardSettings.shared.hapticIntensity {
        case .light: intensity = 0.5
        case .medium: intensity = 0.75
        case .heavy: intensity = 1.0
        }
        impactGenerator?.impactOccurred(intensity: intensity)
        impactGenerator?.prepare()
    }

    /// Rung khi con trỏ di chuyển qua 1 ký tự (trượt Space)
    public func playCursorTick() {
        guard isEnabled else { return }
        selectionGenerator?.selectionChanged()
        selectionGenerator?.prepare()
    }

    /// Rung khi kích hoạt phím đặc biệt (Shift, Return, Delete)
    public func playSpecialKey() {
        guard isEnabled else { return }
        let intensity: CGFloat
        switch vBoardSettings.shared.hapticIntensity {
        case .light: intensity = 0.7
        case .medium: intensity = 0.9
        case .heavy: intensity = 1.0
        }
        impactGenerator?.impactOccurred(intensity: intensity)
        impactGenerator?.prepare()
    }
}
#endif
