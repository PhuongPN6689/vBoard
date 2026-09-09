import Foundation

/// Đại diện cho một cặp từ gõ tắt cá nhân hóa
public struct ShortcutEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: String { shortcut }
    public let shortcut: String
    public let replacement: String

    public init(shortcut: String, replacement: String) {
        self.shortcut = shortcut.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.replacement = replacement
    }
}

/// Trình quản lý danh sách gõ tắt cá nhân (Text Replacement / Macro Expansion)
/// Lưu trữ an toàn trong App Group Container để đồng bộ thời gian thực giữa Host App và Keyboard Extension
public final class ShortcutManager: @unchecked Sendable {
    public static let shared = ShortcutManager()

    private let lock = NSLock()
    private var shortcutsMap: [String: String] = [:]
    private let fileName = "shortcuts.json"

    private init() {
        loadShortcuts()
    }

    private var fileURL: URL? {
        let fileManager = FileManager.default
        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: vBoardSettings.appGroupSuiteName) {
            return groupURL.appendingPathComponent(fileName)
        }
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
    }

    /// Tải danh sách phím tắt từ file hoặc gán mặc định
    public func loadShortcuts() {
        lock.lock()
        defer { lock.unlock() }

        if let url = fileURL,
           let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([ShortcutEntry].self, from: data) {
            shortcutsMap.removeAll()
            for item in list {
                shortcutsMap[item.shortcut] = item.replacement
            }
            return
        }

        // Danh sách gõ tắt mẫu tiếng Việt thông dụng
        let defaultShortcuts: [ShortcutEntry] = [
            ShortcutEntry(shortcut: "dc", replacement: "được"),
            ShortcutEntry(shortcut: "ko", replacement: "không"),
            ShortcutEntry(shortcut: "k", replacement: "không"),
            ShortcutEntry(shortcut: "ng", replacement: "người"),
            ShortcutEntry(shortcut: "vn", replacement: "Việt Nam"),
            ShortcutEntry(shortcut: "hn", replacement: "Hà Nội"),
            ShortcutEntry(shortcut: "sg", replacement: "Sài Gòn"),
            ShortcutEntry(shortcut: "tks", replacement: "cảm ơn"),
            ShortcutEntry(shortcut: "ok", replacement: "đồng ý")
        ]

        shortcutsMap.removeAll()
        for item in defaultShortcuts {
            shortcutsMap[item.shortcut] = item.replacement
        }
        saveCurrentShortcutsLocked()
    }

    /// Lấy toàn bộ danh sách gõ tắt hiện tại
    public func getShortcuts() -> [ShortcutEntry] {
        lock.lock()
        defer { lock.unlock() }
        return shortcutsMap.map { ShortcutEntry(shortcut: $0.key, replacement: $0.value) }
            .sorted { $0.shortcut < $1.shortcut }
    }

    /// Tra cứu từ thay thế cho một từ viết tắt
    public func replacement(for shortcut: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return shortcutsMap[shortcut.lowercased()]
    }

    /// Thêm hoặc cập nhật một cặp gõ tắt
    public func addShortcut(shortcut: String, replacement: String) {
        let key = shortcut.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let val = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !val.isEmpty else { return }

        lock.lock()
        shortcutsMap[key] = val
        saveCurrentShortcutsLocked()
        lock.unlock()

        vBoardSettings.shared.notifySettingsChanged()
    }

    /// Xóa một phím tắt
    public func deleteShortcut(shortcut: String) {
        let key = shortcut.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        lock.lock()
        shortcutsMap.removeValue(forKey: key)
        saveCurrentShortcutsLocked()
        lock.unlock()

        vBoardSettings.shared.notifySettingsChanged()
    }

    /// Khôi phục về danh sách gõ tắt mặc định
    public func resetToDefaults() {
        lock.lock()
        shortcutsMap.removeAll()
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
        }
        lock.unlock()
        loadShortcuts()
        vBoardSettings.shared.notifySettingsChanged()
    }

    private func saveCurrentShortcutsLocked() {
        guard let url = fileURL else { return }
        let entries = shortcutsMap.map { ShortcutEntry(shortcut: $0.key, replacement: $0.value) }
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
