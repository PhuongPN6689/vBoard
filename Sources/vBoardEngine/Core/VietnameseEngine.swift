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
    public var isQuickStartConsonantEnabled: Bool = false
    public var isQuickEndConsonantEnabled: Bool = false
    public var isSpellingCheckEnabled: Bool = true
    public var isRestoreIfWrongSpellingEnabled: Bool = true
    public var isAllowConsonantZFWJEnabled: Bool = false

    public init(
        inputMethod: InputMethod = .telex,
        diacriticStyle: DiacriticStyle = .newStyle,
        isQuickTelexEnabled: Bool = true,
        isBracketShortcutsEnabled: Bool = true,
        isZKeyRemoveToneEnabled: Bool = true,
        isWAtWordBeginningEnabled: Bool = true,
        isModernToneBalancingEnabled: Bool = true,
        isQuickStartConsonantEnabled: Bool = false,
        isQuickEndConsonantEnabled: Bool = false,
        isSpellingCheckEnabled: Bool = true,
        isRestoreIfWrongSpellingEnabled: Bool = true,
        isAllowConsonantZFWJEnabled: Bool = false
    ) {
        self.inputMethod = inputMethod
        self.diacriticStyle = diacriticStyle
        self.isQuickTelexEnabled = isQuickTelexEnabled
        self.isBracketShortcutsEnabled = isBracketShortcutsEnabled
        self.isZKeyRemoveToneEnabled = isZKeyRemoveToneEnabled
        self.isWAtWordBeginningEnabled = isWAtWordBeginningEnabled
        self.isModernToneBalancingEnabled = isModernToneBalancingEnabled
        self.isQuickStartConsonantEnabled = isQuickStartConsonantEnabled
        self.isQuickEndConsonantEnabled = isQuickEndConsonantEnabled
        self.isSpellingCheckEnabled = isSpellingCheckEnabled
        self.isRestoreIfWrongSpellingEnabled = isRestoreIfWrongSpellingEnabled
        self.isAllowConsonantZFWJEnabled = isAllowConsonantZFWJEnabled
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
    private var didRestoreW: Bool = false
    private var didRestoreJ: Bool = false
    private var didRestoreF: Bool = false

    // MARK: - Xử lý Telex

    private func processTelex(char: Character, currentWord: String) -> EngineAction {
        let lowerChar = Character(char.lowercased())
        let isUpper = char.isUppercase

        // Phím ngoặc vuông theo chuẩn OpenKey Telex: [ -> ơ, ] -> ư, { -> Ơ, } -> Ư (Gõ đúp để khôi phục [, ], {, })
        if isBracketShortcutsEnabled {
            if char == "[" {
                if currentWord.hasSuffix("ơ") {
                    return EngineAction(deleteCount: 1, textToInsert: "[")
                }
                return .insertOnly("ơ")
            }
            if char == "{" {
                if currentWord.hasSuffix("Ơ") {
                    return EngineAction(deleteCount: 1, textToInsert: "{")
                }
                return .insertOnly("Ơ")
            }
            if char == "]" {
                if currentWord.hasSuffix("ư") {
                    return EngineAction(deleteCount: 1, textToInsert: "]")
                }
                return .insertOnly("ư")
            }
            if char == "}" {
                if currentWord.hasSuffix("Ư") {
                    return EngineAction(deleteCount: 1, textToInsert: "}")
                }
                return .insertOnly("Ư")
            }
        }

        // Nếu từ hiện tại rỗng (bắt đầu từ mới)
        if currentWord.isEmpty {
            didRestoreW = false
            didRestoreJ = false
            didRestoreF = false
            // Trường hợp gõ phím 'w' ở đầu từ
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
            didRestoreW = true
            let replaced = char.isUppercase ? "W" : "w"
            return EngineAction(deleteCount: 1, textToInsert: replaced)
        }

        // Hoàn tác gõ đúp jj -> j và ff -> f để gõ các từ tiếng Anh (java, facebook, fan)
        if (currentWord == "j" || currentWord == "J") && lowerChar == "j" {
            didRestoreJ = true
            let replaced = char.isUppercase ? "J" : "j"
            return EngineAction(deleteCount: 1, textToInsert: replaced)
        }
        if (currentWord == "f" || currentWord == "F") && lowerChar == "f" {
            didRestoreF = true
            let replaced = char.isUppercase ? "F" : "f"
            return EngineAction(deleteCount: 1, textToInsert: replaced)
        }

        // 0. Kiểm tra gõ tắt phụ âm đầu OpenKey: f->ph, j->gi, w->qu (khi gõ tiếp nguyên âm)
        if let action = handleQuickStartConsonant(char: char, word: currentWord) {
            lastWasStandaloneW = false
            return action
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

        // 5. Kiểm tra gõ tắt phụ âm cuối OpenKey: g->ng, h->nh, k->ch (khi đứng sau nguyên âm hoặc hoàn tác gõ đúp)
        if let action = handleQuickEndConsonant(char: char, word: currentWord) {
            return action
        }

        // 6. Kiểm tra Quick Telex (cc->ch, gg->gi, kk->kh, nn->ng, qq->qu, pp->ph, tt->th, uu->ươ)
        if let action = handleQuickTelex(char: char, word: currentWord) {
            return action
        }

        // 6.5. Xử lý Simple Telex: tự động ie->iê, uo->uô khi gõ phụ âm cuối
        if inputMethod == .simpleTelex {
            var parsed = parseSyllable(from: currentWord)
            if parsed.suffix.isEmpty && parsed.vowels.count == 2 {
                let v0Base = parsed.vowels[0].base.lowercased()
                let v1Base = parsed.vowels[1].base.lowercased()
                let v1Shape = parsed.vowels[1].shape

                // ie -> iê (tieng -> tiêng, biet -> biêt, viet -> viêt)
                if v0Base == "i" && v1Base == "e" && v1Shape == .plain {
                    parsed.vowels[1].shape = .circumflex
                    parsed.suffix.append(char)
                    let rendered = parsed.render(style: diacriticStyle)
                    return EngineAction(deleteCount: currentWord.count, textToInsert: rendered)
                }
                // uo -> uô (muon -> muôn, buon -> buôn, cuoc -> cuôc)
                if v0Base == "u" && v1Base == "o" && v1Shape == .plain && parsed.vowels[0].shape == .plain {
                    parsed.vowels[1].shape = .circumflex
                    parsed.suffix.append(char)
                    let rendered = parsed.render(style: diacriticStyle)
                    return EngineAction(deleteCount: currentWord.count, textToInsert: rendered)
                }
            }
        }

        // 7. Nếu từ đã có dấu và người dùng gõ thêm phụ âm cuối -> Tự động cân bằng lại vị trí dấu thanh
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

        // Xử lý 'o' sau 'ư' -> 'ươ' (ví dụ: thw -> thư, gõ o -> thươ; nw -> nư, gõ o -> nươ; trw -> trư, gõ o -> trươ)
        if lowerChar == "o" && parsed.vowels.count == 1 && parsed.suffix.isEmpty {
            let v0 = parsed.vowels[0]
            if v0.base.lowercased() == "u" && v0.shape == .horn {
                parsed.vowels.append(VowelUnit(base: "o", shape: .horn, isUpper: char.isUppercase))
                let newWord = parsed.render(style: diacriticStyle)
                return EngineAction(deleteCount: word.count, textToInsert: newWord)
            }
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

        // Xử lý phím lặp nguyên âm: a+a -> â, e+e -> ê, o+o -> ô (kể cả gõ trễ sau phụ âm cuối như mot+o -> môt, viet+e -> viêt)
        if let targetIdx = parsed.vowels.indices.last(where: { Character(parsed.vowels[$0].base.lowercased()) == lowerChar }) {
            // Nếu đã có phụ âm cuối, chỉ cho phép gõ trễ mũ nếu phụ âm cuối đó là phụ âm cuối tiếng Việt hợp lệ
            if !parsed.suffix.isEmpty {
                let validFinals = ["c", "ch", "m", "n", "ng", "nh", "p", "t"]
                guard validFinals.contains(parsed.suffix.lowercased()) else {
                    return nil
                }
            }

            let v = parsed.vowels[targetIdx]
            let baseLower = Character(v.base.lowercased())

            if baseLower == "a" || baseLower == "e" || baseLower == "o" {
                if v.shape == .circumflex && isAutoUndoEnabled {
                    // Undo: â + a -> aa, ê + e -> ee, ô + o -> oo
                    parsed.vowels[targetIdx].shape = .plain
                    let newWord = parsed.render(style: diacriticStyle) + String(char)
                    return EngineAction(deleteCount: word.count, textToInsert: newWord)
                }

                parsed.vowels[targetIdx].shape = .circumflex
                let newWord = parsed.render(style: diacriticStyle)
                return EngineAction(deleteCount: word.count, textToInsert: newWord)
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
        let lowerWord = word.lowercased()

        // Hoàn tác gõ đúp Quick Telex: ch+c -> cc, gi+g -> gg, kh+k -> kk, ng+n -> nn, qu+q -> qq, ph+p -> pp, th+t -> tt, ươ+u -> uu
        if lowerWord.hasSuffix("ch") && lowerChar == "c" {
            return EngineAction(deleteCount: 2, textToInsert: isUpper ? "CC" : "cc")
        }
        if lowerWord.hasSuffix("gi") && lowerChar == "g" {
            return EngineAction(deleteCount: 2, textToInsert: isUpper ? "GG" : "gg")
        }
        if lowerWord.hasSuffix("kh") && lowerChar == "k" {
            return EngineAction(deleteCount: 2, textToInsert: isUpper ? "KK" : "kk")
        }
        if lowerWord.hasSuffix("ng") && lowerChar == "n" {
            return EngineAction(deleteCount: 2, textToInsert: isUpper ? "NN" : "nn")
        }
        if lowerWord.hasSuffix("qu") && lowerChar == "q" {
            return EngineAction(deleteCount: 2, textToInsert: isUpper ? "QQ" : "qq")
        }
        if lowerWord.hasSuffix("ph") && lowerChar == "p" {
            return EngineAction(deleteCount: 2, textToInsert: isUpper ? "PP" : "pp")
        }
        if lowerWord.hasSuffix("th") && lowerChar == "t" {
            return EngineAction(deleteCount: 2, textToInsert: isUpper ? "TT" : "tt")
        }

        guard let lastChar = word.last else { return nil }
        let lowerLast = Character(lastChar.lowercased())

        if lowerChar == lowerLast {
            switch lowerChar {
            case "c":
                let rep: Character = isUpper ? "H" : "h"
                return EngineAction(deleteCount: 0, textToInsert: String(rep))
            case "g":
                // Chỉ kích hoạt gg -> gi cho phụ âm đầu (khi từ chưa có nguyên âm)
                guard parseSyllable(from: word).vowels.isEmpty else { return nil }
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
            case "u":
                // uu -> ươ (theo chuẩn OpenKey Quick Telex)
                let rep: String = isUpper ? "Ơ" : "ơ"
                return EngineAction(deleteCount: 1, textToInsert: (word.last?.isUppercase == true ? "Ư" : "ư") + rep)
            default:
                break
            }
        }
        return nil
    }

    // MARK: - OpenKey Gõ tắt phụ âm đầu: f->ph, j->gi, w->qu
    private func handleQuickStartConsonant(char: Character, word: String) -> EngineAction? {
        guard isQuickStartConsonantEnabled else { return nil }
        let lowerChar = Character(char.lowercased())

        // Chỉ kích hoạt khi gõ nguyên âm sau phụ âm đầu đơn f, j, w (hoặc 'ư' tạo ra từ 'w' đầu từ)
        let isVowel = VietnameseChar.decompose(lowerChar) != nil || lowerChar == "a" || lowerChar == "e" || lowerChar == "i" || lowerChar == "o" || lowerChar == "u" || lowerChar == "y"
        guard isVowel else { return nil }

        if word.count == 1, let firstChar = word.first {
            if didRestoreW && (firstChar == "w" || firstChar == "W") {
                didRestoreW = false
                return nil
            }
            if didRestoreJ && (firstChar == "j" || firstChar == "J") {
                didRestoreJ = false
                return nil
            }
            if didRestoreF && (firstChar == "f" || firstChar == "F") {
                didRestoreF = false
                return nil
            }
            let isFirstUpper = firstChar.isUppercase
            let isCharUpper = char.isUppercase
            let isAllUpper = isFirstUpper && isCharUpper

            switch firstChar.lowercased() {
            case "f":
                let rep = isAllUpper ? "PH" : (isFirstUpper ? "Ph" : "ph")
                return EngineAction(deleteCount: 1, textToInsert: rep + String(char))
            case "j":
                let rep = isAllUpper ? "GI" : (isFirstUpper ? "Gi" : "gi")
                // Trong tiếng Việt, 'gi' kết hợp nguyên âm 'i' (gì, gí, giếng, gìn...) thì 'gi' đã chứa sẵn nguyên âm 'i'
                if lowerChar == "i" {
                    return EngineAction(deleteCount: 1, textToInsert: rep)
                }
                return EngineAction(deleteCount: 1, textToInsert: rep + String(char))
            case "w", "ư":
                let rep = isAllUpper ? "QU" : (isFirstUpper ? "Qu" : "qu")
                // 'qu' đã kết thúc bằng 'u', nếu gõ tiếp 'u' (như wuoocs -> quốc, wuyeens -> quyến) thì không lặp lại 'u'
                if lowerChar == "u" {
                    return EngineAction(deleteCount: 1, textToInsert: rep)
                }
                return EngineAction(deleteCount: 1, textToInsert: rep + String(char))
            default:
                break
            }
        }
        return nil
    }

    // MARK: - OpenKey Gõ tắt phụ âm cuối: g->ng, h->nh, k->ch
    private func handleQuickEndConsonant(char: Character, word: String) -> EngineAction? {
        guard isQuickEndConsonantEnabled, !word.isEmpty else { return nil }
        let lowerChar = Character(char.lowercased())
        let isUpper = char.isUppercase
        let lowerWord = word.lowercased()

        // Hoàn tác gõ đúp phụ âm cuối rút gọn: tag -> tang + g -> tag, tah -> tanh + h -> tah, tak -> tach + k -> tak
        if lowerWord.hasSuffix("ng") && lowerChar == "g" {
            return EngineAction(deleteCount: 2, textToInsert: isUpper ? "G" : "g")
        }
        if lowerWord.hasSuffix("nh") && lowerChar == "h" {
            return EngineAction(deleteCount: 2, textToInsert: isUpper ? "H" : "h")
        }
        if lowerWord.hasSuffix("ch") && lowerChar == "k" {
            return EngineAction(deleteCount: 2, textToInsert: isUpper ? "K" : "k")
        }

        // Phải là sau một nguyên âm tiếng Việt và chưa có phụ âm cuối
        var parsed = parseSyllable(from: word)
        guard !parsed.vowels.isEmpty && parsed.suffix.isEmpty else { return nil }

        let isAllWordUpper = word.allSatisfy { $0.isUppercase }
        let rep: String
        switch lowerChar {
        case "g":
            // g -> ng
            rep = (isUpper || isAllWordUpper) ? "NG" : "ng"
        case "h":
            // h -> nh
            rep = (isUpper || isAllWordUpper) ? "NH" : "nh"
        case "k":
            // k -> ch
            rep = (isUpper || isAllWordUpper) ? "CH" : "ch"
        default:
            return nil
        }

        // Nếu từ trước đó chưa có dấu thanh, chỉ cần chèn tiếp phụ âm cuối rút gọn
        if parsed.tone == .none {
            return EngineAction(deleteCount: 0, textToInsert: rep)
        }

        // Nếu từ trước đó đã có dấu thanh, cập nhật phụ âm cuối và render lại âm tiết hoàn chỉnh
        // Giúp tự động cân bằng lại dấu thanh theo đúng âm luật (ví dụ: tasg -> táng, toasg -> toáng)
        parsed.suffix = rep
        let rendered = parsed.render(style: diacriticStyle)
        return EngineAction(deleteCount: word.count, textToInsert: rendered)
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
        lastWasStandaloneW = false
        didRestoreW = false
        didRestoreJ = false
        didRestoreF = false
    }
}
