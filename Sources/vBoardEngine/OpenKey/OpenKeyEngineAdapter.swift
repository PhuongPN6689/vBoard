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

    /// Trích xuất từ hiện tại (cuối cùng) từ ngữ cảnh trước con trỏ
    public func extractCurrentWord(from context: String) -> String {
        guard !context.isEmpty else { return "" }
        let nfcContext = context.precomposedStringWithCanonicalMapping
        var word = ""
        for char in nfcContext.reversed() {
            if char.isWhitespace || char.isNewline || char.isPunctuation {
                break
            }
            word.insert(char, at: word.startIndex)
        }
        return word
    }

    /// Đồng bộ hoá từ trước con trỏ vào OpenKeyEngine khi phiên gõ mới bắt đầu trên một từ có sẵn
    public func syncContextWord(_ word: String) {
        guard engine.isEmpty, !word.isEmpty else { return }
        let keystrokes = wordToKeystrokes(word, inputType: engine.vInputType)
        for ch in keystrokes {
            guard let mapping = OpenKeyVietnameseData.characterToKeyCode(ch) else { continue }
            engine.handleEvent(
                event: .keyboard,
                state: .keyDown,
                data: mapping.keyCode,
                capsStatus: mapping.isCaps ? 1 : 0
            )
        }
    }

    /// Kiểm tra xem một từ/âm tiết có tuân thủ đúng quy tắc chính tả và ngữ âm tiếng Việt của OpenKey hay không
    public func isValidVietnameseSpelling(_ word: String) -> Bool {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        let tempEngine = OpenKeyEngine()
        tempEngine.vInputType = engine.vInputType
        tempEngine.vUseModernOrthography = engine.vUseModernOrthography
        tempEngine.vCheckSpelling = 1
        tempEngine.vRestoreIfWrongSpelling = 0
        tempEngine.vQuickStartConsonant = engine.vQuickStartConsonant
        tempEngine.vQuickEndConsonant = engine.vQuickEndConsonant
        tempEngine.vAllowConsonantZFWJ = engine.vAllowConsonantZFWJ
        let keystrokes = wordToKeystrokes(clean, inputType: tempEngine.vInputType)
        for ch in keystrokes {
            guard let mapping = OpenKeyVietnameseData.characterToKeyCode(ch) else { continue }
            tempEngine.handleEvent(
                event: .keyboard,
                state: .keyDown,
                data: mapping.keyCode,
                capsStatus: mapping.isCaps ? 1 : 0
            )
        }
        tempEngine.checkSpelling(forceCheckVowel: true)
        return tempEngine.spellingOK && tempEngine.spellingVowelOK
    }

    /// Phân rã từ tiếng Việt thành chuỗi phím gõ tương ứng của OpenKey
    private func wordToKeystrokes(_ word: String, inputType: OpenKeyInputType) -> String {
        var result = ""
        var tones = ""

        for ch in word {
            if ch == "đ" {
                result += (inputType == .vni) ? "d9" : "dd"
                continue
            } else if ch == "Đ" {
                result += (inputType == .vni) ? "D9" : "DD"
                continue
            }

            let decomposed = String(ch).decomposedStringWithCanonicalMapping
            var baseChar: Character? = nil

            for scalar in decomposed.unicodeScalars {
                switch scalar.value {
                case 0x0302: // circumflex (mũ: â, ê, ô)
                    if let base = baseChar {
                        if inputType == .vni {
                            result += "6"
                        } else {
                            result.append(base)
                        }
                    }
                case 0x0306: // breve (trăng: ă)
                    result += (inputType == .vni) ? "8" : "w"
                case 0x031B: // horn (móc: ơ, ư)
                    result += (inputType == .vni) ? "7" : "w"
                case 0x0301: // sắc
                    tones += (inputType == .vni) ? "1" : "s"
                case 0x0300: // huyền
                    tones += (inputType == .vni) ? "2" : "f"
                case 0x0309: // hỏi
                    tones += (inputType == .vni) ? "3" : "r"
                case 0x0303: // ngã
                    tones += (inputType == .vni) ? "4" : "x"
                case 0x0323: // nặng
                    tones += (inputType == .vni) ? "5" : "j"
                default:
                    if baseChar == nil {
                        baseChar = Character(scalar)
                        result.append(Character(scalar))
                    }
                }
            }
        }
        return result + tones
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
        case .vWillProcess:
            let replacement = decodeCharData(
                data: hook.charData,
                count: Int(hook.newCharCount),
                isReversed: true
            )
            return EngineAction(
                deleteCount: Int(hook.backspaceCount),
                textToInsert: replacement
            )

        case .vRestore:
            var replacement = decodeCharData(
                data: hook.charData,
                count: Int(hook.newCharCount),
                isReversed: true
            )
            replacement.append(char)
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
