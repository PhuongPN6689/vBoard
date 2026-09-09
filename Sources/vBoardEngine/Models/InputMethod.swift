import Foundation

/// Kiểu gõ tiếng Việt được hỗ trợ
public enum InputMethod: String, Codable, Sendable {
    case telex
    case vni
    case simpleTelex
}

/// Phong cách đặt dấu thanh
public enum DiacriticStyle: String, Codable, Sendable {
    /// Chuẩn mới: hòa, thủy, tòa, khỏe
    case newStyle
    /// Chuẩn cũ: hoà, thuỷ, toà, khoẻ
    case oldStyle
}

/// Hành động gửi tới UITextDocumentProxy của iOS
public struct EngineAction: Equatable, Sendable {
    /// Số ký tự cần xóa lùi (deleteBackward)
    public let deleteCount: Int
    /// Chuỗi văn bản cần chèn vào (insertText)
    public let textToInsert: String

    public init(deleteCount: Int, textToInsert: String) {
        self.deleteCount = deleteCount
        self.textToInsert = textToInsert
    }

    /// Hành động không sửa đổi gì, chỉ chèn ký tự mới
    public static func insertOnly(_ text: String) -> EngineAction {
        return EngineAction(deleteCount: 0, textToInsert: text)
    }
}
