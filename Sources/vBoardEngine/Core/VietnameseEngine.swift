import Foundation

/// Bộ phân tích và xử lý chuỗi tiếng Việt theo thời gian thực
public final class VietnameseEngine: @unchecked Sendable {
    public var inputMethod: InputMethod
    public var diacriticStyle: DiacriticStyle
    public var isAutoUndoEnabled: Bool = true
    public var isQuickTelexEnabled: Bool = true
    public var isBracketShortcutsEnabled: Bool = true
    public var isZKeyRemoveToneEnabled: Bool = true
    public var isWAtWordBeginningEnabled: Bool = true
    public var isModernToneBalancingEnabled: Bool = true

    public init(
        inputMethod: InputMethod = .telex,
        diacriticStyle: DiacriticStyle = .newStyle,
        isQuickTelexEnabled: Bool = true,
        isBracketShortcutsEnabled: Bool = true,
        isZKeyRemoveToneEnabled: Bool = true,
        isWAtWordBeginningEnabled: Bool = true,
        isModernToneBalancingEnabled: Bool = true
    ) {
        self.inputMethod = inputMethod
        self.diacriticStyle = diacriticStyle
        self.isQuickTelexEnabled = isQuickTelexEnabled
        self.isBracketShortcutsEnabled = isBracketShortcutsEnabled
        self.isZKeyRemoveToneEnabled = isZKeyRemoveToneEnabled
        self.isWAtWordBeginningEnabled = isWAtWordBeginningEnabled
        self.isModernToneBalancingEnabled = isModernToneBalancingEnabled
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

    /// Hàm xử lý chính: Nhận ký tự gõ vào và ngữ cảnh văn bản hiện tại
    /// Trả về `EngineAction`: số ký tự cần xóa lùi và chuỗi cần chèn vào
    public func processKeystroke(_ char: Character, contextBefore: String) -> EngineAction {
        // Nếu là ký tự trắng hoặc dấu câu (ngoại trừ dấu ngoặc [ ] { } dùng trong OpenKey Telex khi được bật)
        let isBracket = isBracketShortcutsEnabled && (char == "[" || char == "]" || char == "{" || char == "}")
        if char.isWhitespace || char.isNewline || (char.isPunctuation && !isBracket) {
            return .insertOnly(String(char))
        }

        let currentWord = extractCurrentWord(from: contextBefore)

        switch inputMethod {
        case .telex, .simpleTelex:
            return processTelex(char: char, currentWord: currentWord)
        case .vni:
            return processVni(char: char, currentWord: currentWord)
        }
    }

    private var lastWasStandaloneW: Bool = false

    // MARK: - Xử lý Telex

    private func processTelex(char: Character, currentWord: String) -> EngineAction {
        let lowerChar = Character(char.lowercased())
        let isUpper = char.isUppercase

        // Phím ngoặc vuông theo chuẩn OpenKey Telex: [ -> ơ, ] -> ư, { -> Ơ, } -> Ư
        if isBracketShortcutsEnabled {
            if char == "[" { return .insertOnly("ơ") }
            if char == "{" { return .insertOnly("Ơ") }
            if char == "]" { return .insertOnly("ư") }
            if char == "}" { return .insertOnly("Ư") }
        }

        // Nếu từ hiện tại rỗng (bắt đầu từ mới)
        if currentWord.isEmpty {
            // Trường hợp gõ phím 'w' ở đầu từ -> chuyển thành 'ư' / 'Ư'
            if isWAtWordBeginningEnabled && lowerChar == "w" {
                lastWasStandaloneW = true
                let replaced = isUpper ? "Ư" : "ư"
                return EngineAction(deleteCount: 0, textToInsert: replaced)
            }
            lastWasStandaloneW = false
            return .insertOnly(String(char))
        }

        // Trường hợp từ hiện tại là "ư" hoặc "Ư" từ phím 'w' đầu từ và gõ tiếp "w" -> khôi phục về "w" / "W"
        if lastWasStandaloneW && (currentWord == "ư" || currentWord == "Ư") && lowerChar == "w" {
            lastWasStandaloneW = false
            let replaced = char.isUppercase ? "W" : "w"
            return EngineAction(deleteCount: 1, textToInsert: replaced)
        }
        lastWasStandaloneW = false

        // 1. Kiểm tra xử lý phím 'd' / 'dd' -> 'đ'
        if lowerChar == "d" {
            if let action = handleDKeystroke(char: char, word: currentWord) {
                return action
            }
        }

        // 2. Kiểm tra xử lý biến đổi nguyên âm mũ/móc (aa->â, ee->ê, oo->ô, aw->ă, ow->ơ, uw->ư, uow->ươ)
        if let action = handleVowelModificationTelex(char: char, word: currentWord) {
            return action
        }

        // 3. Kiểm tra xử lý dấu thanh (s, f, r, x, j)
        if let tone = toneForTelexChar(lowerChar) {
            if let action = handleToneKeystroke(tone: tone, toneChar: char, word: currentWord) {
                return action
            }
        }

        // 4. Kiểm tra phím 'z' gỡ bỏ dấu thanh (OpenKey Telex rule)
        if isZKeyRemoveToneEnabled && lowerChar == "z" {
            var parsed = parseSyllable(from: currentWord)
            if parsed.tone != .none {
                parsed.tone = .none
                let newWord = parsed.render(style: diacriticStyle)
                return EngineAction(deleteCount: currentWord.count, textToInsert: newWord)
            }
        }

        // 5. Kiểm tra Quick Telex (cc->ch, gg->gi, kk->kh, nn->ng, qq->qu, pp->ph, tt->th)
        if let action = handleQuickTelex(char: char, word: currentWord) {
            return action
        }

        // 6. Nếu từ đã có dấu và người dùng gõ thêm phụ âm cuối -> Tự động cân bằng lại vị trí dấu thanh
        if isModernToneBalancingEnabled {
            let parsed = parseSyllable(from: currentWord)
            if parsed.tone != .none && !parsed.vowels.isEmpty {
                var updated = parsed
                updated.suffix.append(char)
                let rebalanced = updated.render(style: diacriticStyle)
                if rebalanced != (currentWord + String(char)) {
                    return EngineAction(deleteCount: currentWord.count, textToInsert: rebalanced)
                }
            }
        }

        // Mặc định: Chèn ký tự vào cuối từ
        return .insertOnly(String(char))
    }

    // MARK: - Xử lý 'd' / 'đ'
    private func handleDKeystroke(char: Character, word: String) -> EngineAction? {
        let lowerWord = word.lowercased()
        let isUpper = char.isUppercase

        // Trường hợp từ kết thúc bằng "d": ví dụ "d" + "d" -> "đ"
        if lowerWord.hasSuffix("d") {
            let lastChar = word.last!
            let replaced: Character = (lastChar.isUppercase && isUpper) ? "Đ" : (lastChar.isUppercase ? "Đ" : "đ")
            return EngineAction(deleteCount: 1, textToInsert: String(replaced))
        }

        // Trường hợp đã là "đ" mà bấm tiếp "d" -> khôi phục về "dd" (Undo)
        if isAutoUndoEnabled && lowerWord.hasSuffix("đ") {
            let lastChar = word.last!
            let restored = lastChar.isUppercase ? "Dd" : "dd"
            return EngineAction(deleteCount: 1, textToInsert: restored)
        }

        return nil
    }

    // MARK: - Xử lý nguyên âm mũ và móc (Telex)
    private func handleVowelModificationTelex(char: Character, word: String) -> EngineAction? {
        let lowerChar = Character(char.lowercased())
        var parsed = parseSyllable(from: word)

        guard !parsed.vowels.isEmpty else {
            // Chưa có nguyên âm, nhưng nếu là 'w'
            if lowerChar == "w" {
                // Ví dụ "tw" -> "tư"
                let isUpper = char.isUppercase
                let replaced = isUpper ? "Ư" : "ư"
                return EngineAction(deleteCount: 0, textToInsert: replaced)
            }
            return nil
        }

        // Nếu từ đã có phụ âm cuối và phím bấm không phải 'w', không biến đổi nguyên âm nữa
        if !parsed.suffix.isEmpty && lowerChar != "w" {
            return nil
        }

        // Xử lý 'w': biến a->ă, o->ơ, u->ư, uo->ươ, ua->ưa
        if lowerChar == "w" {
            let vCount = parsed.vowels.count

            // 1. Trường hợp "uo" + "w" -> "ươ" (kể cả khi đã có phụ âm cuối: duong+w -> đương, muoowns -> mướn)
            if vCount >= 2 {
                let v0 = parsed.vowels[vCount - 2]
                let v1 = parsed.vowels[vCount - 1]
                if v0.base.lowercased() == "u" && v1.base.lowercased() == "o" {
                    if v0.shape == .horn && v1.shape == .horn && isAutoUndoEnabled {
                        // Undo: ươ + w -> uow
                        parsed.vowels[vCount - 2].shape = .plain
                        parsed.vowels[vCount - 1].shape = .plain
                        let newWord = parsed.render(style: diacriticStyle) + (char.isUppercase ? "W" : "w")
                        return EngineAction(deleteCount: word.count, textToInsert: newWord)
                    }
                    parsed.vowels[vCount - 2].shape = .horn
                    parsed.vowels[vCount - 1].shape = .horn
                    let newWord = parsed.render(style: diacriticStyle)
                    return EngineAction(deleteCount: word.count, textToInsert: newWord)
                }
            }

            // 2. Trường hợp "ua" + "w" -> "ưa" (ví dụ: mua+w -> mưa, chua+w -> chưa)
            if vCount >= 2 {
                let v0 = parsed.vowels[vCount - 2]
                let v1 = parsed.vowels[vCount - 1]
                if v0.base.lowercased() == "u" && v1.base.lowercased() == "a" && v1.shape != .circumflex && v1.shape != .breve {
                    if v0.shape == .horn && isAutoUndoEnabled {
                        parsed.vowels[vCount - 2].shape = .plain
                        let newWord = parsed.render(style: diacriticStyle) + (char.isUppercase ? "W" : "w")
                        return EngineAction(deleteCount: word.count, textToInsert: newWord)
                    }
                    parsed.vowels[vCount - 2].shape = .horn
                    let newWord = parsed.render(style: diacriticStyle)
                    return EngineAction(deleteCount: word.count, textToInsert: newWord)
                }
            }

            // 3. Biến đổi nguyên âm cuối cùng
            if let lastIdx = parsed.vowels.indices.last {
                let v = parsed.vowels[lastIdx]
                let baseLower = Character(v.base.lowercased())

                if baseLower == "a" {
                    if v.shape == .breve && isAutoUndoEnabled {
                        // Undo: ă + w -> aw
                        parsed.vowels[lastIdx].shape = .plain
                        let newWord = parsed.render(style: diacriticStyle) + (char.isUppercase ? "W" : "w")
                        return EngineAction(deleteCount: word.count, textToInsert: newWord)
                    }
                    parsed.vowels[lastIdx].shape = .breve
                    let newWord = parsed.render(style: diacriticStyle)
                    return EngineAction(deleteCount: word.count, textToInsert: newWord)
                } else if baseLower == "o" {
                    if v.shape == .horn && isAutoUndoEnabled {
                        // Undo: ơ + w -> ow
                        parsed.vowels[lastIdx].shape = .plain
                        let newWord = parsed.render(style: diacriticStyle) + (char.isUppercase ? "W" : "w")
                        return EngineAction(deleteCount: word.count, textToInsert: newWord)
                    }
                    parsed.vowels[lastIdx].shape = .horn
                    let newWord = parsed.render(style: diacriticStyle)
                    return EngineAction(deleteCount: word.count, textToInsert: newWord)
                } else if baseLower == "u" {
                    if v.shape == .horn && isAutoUndoEnabled {
                        // Undo: ư + w -> uw
                        parsed.vowels[lastIdx].shape = .plain
                        let newWord = parsed.render(style: diacriticStyle) + (char.isUppercase ? "W" : "w")
                        return EngineAction(deleteCount: word.count, textToInsert: newWord)
                    }
                    parsed.vowels[lastIdx].shape = .horn
                    let newWord = parsed.render(style: diacriticStyle)
                    return EngineAction(deleteCount: word.count, textToInsert: newWord)
                }
            }
        }

        // Xử lý phím lặp nguyên âm: a+a -> â, e+e -> ê, o+o -> ô
        if let lastIdx = parsed.vowels.indices.last {
            let v = parsed.vowels[lastIdx]
            let baseLower = Character(v.base.lowercased())

            if lowerChar == baseLower {
                if (baseLower == "a" || baseLower == "e" || baseLower == "o") {
                    if v.shape == .circumflex && isAutoUndoEnabled {
                        // Undo: â + a -> aa, ê + e -> ee, ô + o -> oo
                        parsed.vowels[lastIdx].shape = .plain
                        let newWord = parsed.render(style: diacriticStyle) + String(char)
                        return EngineAction(deleteCount: word.count, textToInsert: newWord)
                    }

                    parsed.vowels[lastIdx].shape = .circumflex
                    let newWord = parsed.render(style: diacriticStyle)
                    return EngineAction(deleteCount: word.count, textToInsert: newWord)
                }
            }
        }

        return nil
    }

    // MARK: - Xử lý Dấu thanh
    private func toneForTelexChar(_ char: Character) -> ToneMark? {
        switch char {
        case "s": return .acute
        case "f": return .grave
        case "r": return .hook
        case "x": return .tilde
        case "j": return .dot
        default: return nil
        }
    }

    private func handleToneKeystroke(tone: ToneMark, toneChar: Character, word: String) -> EngineAction? {
        var parsed = parseSyllable(from: word)

        // Phải có nguyên âm mới bỏ dấu được
        guard !parsed.vowels.isEmpty else {
            return nil
        }

        // Nếu từ hiện tại đã có cùng dấu này và bật autoUndo -> Gỡ dấu và chèn ký tự đó (Undo)
        if parsed.tone == tone && isAutoUndoEnabled {
            parsed.tone = .none
            let newWord = parsed.render(style: diacriticStyle) + String(toneChar)
            return EngineAction(deleteCount: word.count, textToInsert: newWord)
        }

        // Áp dụng dấu thanh mới
        parsed.tone = tone
        let newWord = parsed.render(style: diacriticStyle)
        return EngineAction(deleteCount: word.count, textToInsert: newWord)
    }

    // MARK: - Xử lý VNI
    private func processVni(char: Character, currentWord: String) -> EngineAction {
        // Hỗ trợ VNI: 1-sắc, 2-huyền, 3-hỏi, 4-ngã, 5-nặng, 6-mũ(â,ê,ô), 7-móc(ơ,ư), 8-trăng(ă), 9-đ
        guard let digit = Int(String(char)), !currentWord.isEmpty else {
            return .insertOnly(String(char))
        }

        var parsed = parseSyllable(from: currentWord)

        switch digit {
        case 1: parsed.tone = (parsed.tone == .acute && isAutoUndoEnabled) ? .none : .acute
        case 2: parsed.tone = (parsed.tone == .grave && isAutoUndoEnabled) ? .none : .grave
        case 3: parsed.tone = (parsed.tone == .hook && isAutoUndoEnabled) ? .none : .hook
        case 4: parsed.tone = (parsed.tone == .tilde && isAutoUndoEnabled) ? .none : .tilde
        case 5: parsed.tone = (parsed.tone == .dot && isAutoUndoEnabled) ? .none : .dot
        case 6: // Mũ â, ê, ô
            if let idx = parsed.vowels.indices.last {
                parsed.vowels[idx].shape = (parsed.vowels[idx].shape == .circumflex && isAutoUndoEnabled) ? .plain : .circumflex
            }
        case 7: // Móc ơ, ư
            if let idx = parsed.vowels.indices.last {
                parsed.vowels[idx].shape = (parsed.vowels[idx].shape == .horn && isAutoUndoEnabled) ? .plain : .horn
            }
        case 8: // Trăng ă
            if let idx = parsed.vowels.indices.last {
                parsed.vowels[idx].shape = (parsed.vowels[idx].shape == .breve && isAutoUndoEnabled) ? .plain : .breve
            }
        case 9: // đ
            let lower = currentWord.lowercased()
            if lower.hasPrefix("d") {
                let firstChar = currentWord.first!
                let rep: Character = firstChar.isUppercase ? "Đ" : "đ"
                var rest = currentWord
                rest.removeFirst()
                return EngineAction(deleteCount: currentWord.count, textToInsert: String(rep) + rest)
            }
            return .insertOnly(String(char))
        default:
            return .insertOnly(String(char))
        }

        let newWord = parsed.render(style: diacriticStyle)
        return EngineAction(deleteCount: currentWord.count, textToInsert: newWord)
    }

    // MARK: - Quick Telex (OpenKey chuẩn: cc->ch, gg->gi, kk->kh, nn->ng, qq->qu, pp->ph, tt->th)
    private func handleQuickTelex(char: Character, word: String) -> EngineAction? {
        guard isQuickTelexEnabled, !word.isEmpty else { return nil }
        let lowerChar = Character(char.lowercased())
        let isUpper = char.isUppercase
        guard let lastChar = word.last else { return nil }
        let lowerLast = Character(lastChar.lowercased())

        if lowerChar == lowerLast {
            switch lowerChar {
            case "c":
                let rep: Character = isUpper ? "H" : "h"
                return EngineAction(deleteCount: 0, textToInsert: String(rep))
            case "g":
                let rep: Character = isUpper ? "I" : "i"
                return EngineAction(deleteCount: 0, textToInsert: String(rep))
            case "k":
                let rep: Character = isUpper ? "H" : "h"
                return EngineAction(deleteCount: 0, textToInsert: String(rep))
            case "n":
                let rep: Character = isUpper ? "G" : "g"
                return EngineAction(deleteCount: 0, textToInsert: String(rep))
            case "q":
                let rep: Character = isUpper ? "U" : "u"
                return EngineAction(deleteCount: 0, textToInsert: String(rep))
            case "p":
                let rep: Character = isUpper ? "H" : "h"
                return EngineAction(deleteCount: 0, textToInsert: String(rep))
            case "t":
                let rep: Character = isUpper ? "H" : "h"
                return EngineAction(deleteCount: 0, textToInsert: String(rep))
            default:
                break
            }
        }
        return nil
    }

    // MARK: - Phân tích chuỗi thành Syllable theo chuẩn OpenKey
    public func parseSyllable(from word: String) -> VietnameseSyllable {
        var syllable = VietnameseSyllable()
        guard !word.isEmpty else { return syllable }

        let nfcWord = word.precomposedStringWithCanonicalMapping
        let chars = Array(nfcWord)
        var startIndex = 0
        let lowerWord = nfcWord.lowercased()

        // 1. Nhận diện phụ âm đầu đặc biệt qu- (quán, quá, quốc, quen, quy...)
        if lowerWord.hasPrefix("qu") && chars.count > 2 {
            syllable.prefix = String(chars[0...1])
            startIndex = 2
        }
        // 2. Nhận diện phụ âm đầu đặc biệt gi- (giá, gió, giúp, giếng, giày...)
        else if lowerWord.hasPrefix("gi") && chars.count > 2 && VietnameseChar.decompose(chars[2]) != nil {
            syllable.prefix = String(chars[0...1])
            startIndex = 2
        }

        var state: Int = 0 // 0: prefix (nếu chưa có), 1: vowels, 2: suffix

        for i in startIndex..<chars.count {
            let char = chars[i]
            if let decomposed = VietnameseChar.decompose(char) {
                // Gặp nguyên âm
                if state == 0 {
                    state = 1
                }
                if state == 1 {
                    syllable.vowels.append(VowelUnit(base: decomposed.base, shape: decomposed.shape, isUpper: decomposed.isUppercase))
                    if decomposed.tone != .none {
                        syllable.tone = decomposed.tone
                    }
                } else {
                    syllable.suffix.append(char)
                }
            } else {
                // Phụ âm
                if state == 0 {
                    syllable.prefix.append(char)
                } else if state == 1 {
                    state = 2
                    syllable.suffix.append(char)
                } else {
                    syllable.suffix.append(char)
                }
            }
        }

        return syllable
    }

    /// Đặt lại trạng thái bộ gõ về ban đầu
    public func reset() {
        // VietnameseEngine hiện tại là stateless context-based,
        // nhưng hàm này đóng vai trò giao diện chuẩn để xóa sạch bộ đệm ngữ âm
    }
}
