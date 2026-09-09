//
//  OpenKeyEngineAdapter.swift
//  vBoardEngine
//
//  Bộ chuyển đổi kết nối OpenKeyEngine với kiến trúc bàn phím vBoard.
//  Tuân thủ giao diện EngineAction (deleteCount: Int, textToInsert: String).
//

import Foundation

public final class OpenKeyEngineAdapter: @unchecked Sendable {
    public let engine: OpenKeyEngine

    public init(engine: OpenKeyEngine = OpenKeyEngine()) {
        self.engine = engine
    }

    /// Reset bộ nhớ từ đang gõ
    public func reset() {
        engine.reset()
    }

    /// Chuyển đổi mã trong charData thành chuỗi ký tự hiển thị
    private func decodeCharData(data: [UInt32], count: Int, isReversed: Bool = true) -> String {
        guard count > 0 else { return "" }
        var result = ""

        let indices: [Int] = isReversed ? Array((0..<count).reversed()) : Array(0..<count)

        for k in indices {
            guard k < data.count else { continue }
            let code = data[k]
            if (code & OpenKeyMask.pureCharacter) != 0 {
                let scalarVal = code & ~OpenKeyMask.pureCharacter
                if let scalar = UnicodeScalar(scalarVal) {
                    result.append(Character(scalar))
                }
            } else if (code & OpenKeyMask.charCode) != 0 {
                let scalarVal = code & 0xFFFF
                if let scalar = UnicodeScalar(scalarVal) {
                    result.append(Character(scalar))
                }
            } else {
                if let ch = OpenKeyVietnameseData.keyCodeToCharacter(code) {
                    result.append(ch)
                }
            }
        }
        return result
    }

    /// Xử lý một ký tự gõ vào và trả về EngineAction cho vBoard
    public func processKeystroke(_ char: Character, contextBefore: String = "") -> EngineAction {
        // Dấu cách
        if char == " " {
            engine.handleEvent(event: .keyboard, state: .keyDown, data: OpenKeyCode.space)
            if engine.hookState.code == .vReplaceMaro {
                let text = decodeCharData(data: engine.hookState.macroData, count: engine.hookState.macroData.count, isReversed: false) + " "
                return EngineAction(deleteCount: Int(engine.hookState.backspaceCount), textToInsert: text)
            } else if engine.hookState.code == .vRestore {
                let text = decodeCharData(data: engine.hookState.charData, count: Int(engine.hookState.newCharCount), isReversed: true) + " "
                return EngineAction(deleteCount: Int(engine.hookState.backspaceCount), textToInsert: text)
            }
            return .insertOnly(" ")
        }

        // Xuống dòng
        if char == "\n" {
            engine.handleEvent(event: .keyboard, state: .keyDown, data: OpenKeyCode.return)
            return .insertOnly("\n")
        }

        // Tìm mã phím tương ứng
        guard let mapping = OpenKeyVietnameseData.characterToKeyCode(char) else {
            // Không phải phím Latinh/ASCII thông thường (ví dụ Emoji hoặc ký tự đặc biệt) -> Chèn thô và ngắt từ
            engine.handleEvent(event: .keyboard, state: .keyDown, data: OpenKeyCode.dot)
            return .insertOnly(String(char))
        }

        let capsStatus: UInt8 = mapping.isCaps ? 1 : 0
        engine.handleEvent(
            event: .keyboard,
            state: .keyDown,
            data: mapping.keyCode,
            capsStatus: capsStatus
        )

        let hook = engine.hookState
        switch hook.code {
        case .vWillProcess, .vRestore:
            let replacement = decodeCharData(
                data: hook.charData,
                count: Int(hook.newCharCount),
                isReversed: true
            )
            return EngineAction(
                deleteCount: Int(hook.backspaceCount),
                textToInsert: replacement
            )

        case .vReplaceMaro:
            let replacement = decodeCharData(
                data: hook.macroData,
                count: hook.macroData.count,
                isReversed: false
            )
            return EngineAction(
                deleteCount: Int(hook.backspaceCount),
                textToInsert: replacement
            )

        case .vRestoreAndStartNewSession:
            let replacement = decodeCharData(
                data: hook.charData,
                count: Int(hook.newCharCount),
                isReversed: true
            ) + String(char)
            return EngineAction(
                deleteCount: Int(hook.backspaceCount),
                textToInsert: replacement
            )

        case .vDoNothing, .vBreakWord:
            return .insertOnly(String(char))
        }
    }

    /// Xử lý phím Delete / Backspace
    public func processBackspace() -> EngineAction? {
        engine.handleEvent(event: .keyboard, state: .keyDown, data: OpenKeyCode.delete)
        let hook = engine.hookState
        if hook.code == .vWillProcess {
            let replacement = decodeCharData(
                data: hook.charData,
                count: Int(hook.newCharCount),
                isReversed: true
            )
            return EngineAction(
                deleteCount: Int(hook.backspaceCount),
                textToInsert: replacement
            )
        }
        return nil
    }
}
