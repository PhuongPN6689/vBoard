//
//  OpenKeyMacro.swift
//  vBoardEngine
//
//  Chuyển đổi 1-1 từ Macro.h và Macro.cpp của OpenKey (tác giả Mai Vũ Tuyên).
//

import Foundation

public struct OpenKeyMacroItem: Sendable, Equatable {
    public var macroText: String        // vd: "ms"
    public var macroContent: String     // vd: "millisecond"
    public var macroContentCode: [UInt32]

    public init(macroText: String, macroContent: String, macroContentCode: [UInt32] = []) {
        self.macroText = macroText
        self.macroContent = macroContent
        self.macroContentCode = macroContentCode
    }
}

public final class OpenKeyMacroManager: @unchecked Sendable {
    public static let shared = OpenKeyMacroManager()

    public var macroMap: [[UInt32]: OpenKeyMacroItem] = [:]

    public init() {}

    // MARK: - Chuyển đổi chuỗi sang mã phím / ký tự của OpenKey
    public func convertToKeyCodes(_ text: String) -> [UInt32] {
        var result = [UInt32]()
        for char in text {
            if let mapping = OpenKeyVietnameseData.characterToKeyCode(char) {
                let code = UInt32(mapping.keyCode) | (mapping.isCaps ? OpenKeyMask.caps : 0)
                result.append(code)
            } else {
                // Unicode thuần
                let scalars = char.unicodeScalars
                if let first = scalars.first {
                    result.append(first.value | OpenKeyMask.pureCharacter)
                }
            }
        }
        return result
    }

    // MARK: - Thêm / Xóa Macro
    @discardableResult
    public func addMacro(text: String, content: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return false }

        let key = convertToKeyCodes(trimmedText)
        let contentCode = convertToKeyCodes(content)

        let item = OpenKeyMacroItem(macroText: trimmedText, macroContent: content, macroContentCode: contentCode)
        macroMap[key] = item
        return true
    }

    @discardableResult
    public func deleteMacro(text: String) -> Bool {
        let key = convertToKeyCodes(text.trimmingCharacters(in: .whitespacesAndNewlines))
        return macroMap.removeValue(forKey: key) != nil
    }

    public func hasMacro(_ text: String) -> Bool {
        let key = convertToKeyCodes(text.trimmingCharacters(in: .whitespacesAndNewlines))
        return macroMap[key] != nil
    }

    public func clearAll() {
        macroMap.removeAll()
    }

    // MARK: - Tìm kiếm Macro với Auto Caps (Chuyển đổi 1-1 từ Macro.cpp)
    /// key: mảng mã phím gõ vào (ví dụ mã của 'b', 't', 'w')
    /// outContent: mảng mã ký tự của nội dung thay thế
    public func findMacro(key: [UInt32], autoCaps: Bool = true) -> [UInt32]? {
        // 1. Kiểm tra khớp chính xác
        if let direct = macroMap[key] {
            return direct.macroContentCode
        }

        guard autoCaps else { return nil }

        // 2. Xử lý Auto Caps:
        // Nếu gõ hoa chữ cái đầu (Btw) -> Hoa chữ cái đầu (By the way)
        // Nếu gõ hoa toàn bộ (BTW) -> Hoa toàn bộ (BY THE WAY)
        var lowerKey = key
        var isAllUpper = true
        var isFirstUpper = false

        if let first = lowerKey.first {
            if (first & OpenKeyMask.caps) != 0 {
                isFirstUpper = true
            }
        }

        for i in 0..<lowerKey.count {
            if (lowerKey[i] & OpenKeyMask.caps) != 0 {
                lowerKey[i] &= ~OpenKeyMask.caps
            } else {
                isAllUpper = false
            }
        }

        if let matched = macroMap[lowerKey] {
            var transformed = matched.macroContentCode
            if isAllUpper {
                // Biến toàn bộ thành chữ hoa
                for i in 0..<transformed.count {
                    transformed[i] |= OpenKeyMask.caps
                }
            } else if isFirstUpper {
                // Biến ký tự đầu thành chữ hoa
                if !transformed.isEmpty {
                    transformed[0] |= OpenKeyMask.caps
                }
            }
            return transformed
        }

        return nil
    }

    // MARK: - Nạp từ chuỗi cấu hình (dạng dòng "key:value" hoặc tab-separated)
    public func loadFromString(_ content: String) {
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts: [String]
            if trimmed.contains("\t") {
                parts = trimmed.components(separatedBy: "\t")
            } else if trimmed.contains(":") {
                parts = trimmed.components(separatedBy: ":")
            } else {
                continue
            }
            if parts.count >= 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let val = parts[1...].joined(separator: ":").trimmingCharacters(in: .whitespaces)
                addMacro(text: key, content: val)
            }
        }
    }
}
