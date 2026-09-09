import Foundation

/// Quản lý lịch sử bảng tạm (Clipboard History) siêu nhẹ lưu trong App Group
public final class ClipboardManager: @unchecked Sendable {
    public static let shared = ClipboardManager()

    private let key = "vboard_clipboard_history"
    private let maxItems = 20
    private let maxCharLength = 500
    private let lock = NSLock()

    private var defaults: UserDefaults {
        return UserDefaults(suiteName: vBoardSettings.appGroupSuiteName) ?? UserDefaults.standard
    }

    private init() {}

    /// Lấy danh sách các đoạn văn bản đã copy gần nhất
    public func getHistory() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return defaults.stringArray(forKey: key) ?? []
    }

    /// Thêm một đoạn văn bản vào lịch sử
    public func addClip(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Cắt bớt nếu dài quá giới hạn để tiết kiệm bộ nhớ
        let limited = String(trimmed.prefix(maxCharLength))

        lock.lock()
        defer { lock.unlock() }

        var list = defaults.stringArray(forKey: key) ?? []
        // Xóa nếu đã tồn tại để đưa lên đầu
        list.removeAll { $0 == limited }
        list.insert(limited, at: 0)

        // Giữ lại tối đa 20 items
        if list.count > maxItems {
            list = Array(list.prefix(maxItems))
        }

        defaults.set(list, forKey: key)
    }

    /// Xóa một mục khỏi lịch sử
    public func deleteClip(_ text: String) {
        lock.lock()
        defer { lock.unlock() }

        var list = defaults.stringArray(forKey: key) ?? []
        list.removeAll { $0 == text }
        defaults.set(list, forKey: key)
    }

    /// Xóa toàn bộ lịch sử bảng tạm
    public func clearHistory() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: key)
    }
}
