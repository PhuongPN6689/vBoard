//
//  OpenKeyEngine.swift
//  vBoardEngine
//
//  Chuyển đổi 1-1 từ Engine.h và Engine.cpp của OpenKey (tác giả Mai Vũ Tuyên).
//  Toàn bộ state machine, kiểm tra chính tả, đặt dấu và khôi phục từ tiếng Việt.
//

import Foundation

public final class OpenKeyEngine: @unchecked Sendable {

    // MARK: - Biến Cấu Hình Công Khai (Tương đương các biến extern trong Engine.h)
    public var vLanguage: Int = 1                 // 0: English, 1: Vietnamese
    public var vInputType: OpenKeyInputType = .telex // 0: Telex, 1: VNI, 2: SimpleTelex1, 3: SimpleTelex2
    public var vFreeMark: Int = 0                  // 0: Không bỏ dấu tự do (tuân thủ ngữ pháp), 1: Bỏ dấu tự do
    public var vCodeTable: Int = 0                 // 0: Unicode dựng sẵn, 1: TCVN3, 2: VNI, 3: Unicode tổ hợp
    public var vCheckSpelling: Int = 1             // 0: Không kiểm tra chính tả, 1: Kiểm tra chính tả
    public var vUseModernOrthography: Int = 0      // 0: òa, úy; 1: oà, uý
    public var vQuickTelex: Int = 0                // 0: Tắt (mặc định OpenKey), 1: Bật (cc=ch, gg=gi, kk=kh, nn=ng, qq=qu, pp=ph, tt=th, uu=ươ)
    public var vRestoreIfWrongSpelling: Int = 0    // 0: Không khôi phục, 1: Khôi phục phím gốc nếu sai chính tả
    public var vFixRecommendBrowser: Int = 1       // Sửa lỗi gợi ý URL trình duyệt
    public var vUseMacro: Int = 1                  // Gõ tắt bật/tắt
    public var vAutoCapsMacro: Int = 1             // Tự động viết hoa/thường theo từ khóa gõ tắt
    public var vUpperCaseFirstChar: Int = 0        // Tự động viết hoa chữ cái đầu câu
    public var vAllowConsonantZFWJ: Int = 0        // Cho phép từ chứa Z, F, W, J
    public var vQuickStartConsonant: Int = 0       // f->ph, j->gi, w->qu
    public var vQuickEndConsonant: Int = 0         // g->ng, h->nh, k->ch

    public var macroManager: OpenKeyMacroManager = .shared

    public var isEmpty: Bool { index == 0 }
    public var currentWordLength: Int { index }

    // MARK: - Tiện ích tương thích thuộc tính kiểu Bool
    public var isQuickTelexEnabled: Bool {
        get { vQuickTelex == 1 }
        set { vQuickTelex = newValue ? 1 : 0 }
    }
    public var isSpellingCheckEnabled: Bool {
        get { vCheckSpelling == 1 }
        set { vCheckSpelling = newValue ? 1 : 0 }
    }
    public var isRestoreIfWrongSpellingEnabled: Bool {
        get { vRestoreIfWrongSpelling == 1 }
        set { vRestoreIfWrongSpelling = newValue ? 1 : 0 }
    }
    public var isQuickStartConsonantEnabled: Bool {
        get { vQuickStartConsonant == 1 }
        set { vQuickStartConsonant = newValue ? 1 : 0 }
    }
    public var isQuickEndConsonantEnabled: Bool {
        get { vQuickEndConsonant == 1 }
        set { vQuickEndConsonant = newValue ? 1 : 0 }
    }
    public var isAllowConsonantZFWJEnabled: Bool {
        get { vAllowConsonantZFWJ == 1 }
        set { vAllowConsonantZFWJ = newValue ? 1 : 0 }
    }
    public var isModernToneBalancingEnabled: Bool {
        get { vUseModernOrthography == 0 }
        set { vUseModernOrthography = newValue ? 0 : 1 }
    }
    public var isZKeyRemoveToneEnabled: Bool = true
    public var isBracketShortcutsEnabled: Bool = true
    public var isWAtWordBeginningEnabled: Bool = true
    public var isAutoUndoEnabled: Bool = true

    // MARK: - Bộ đệm và Trạng thái Nội bộ
    public var hookState = OpenKeyHookState()

    private var typingWord: [UInt32] = Array(repeating: 0, count: MAX_BUFF)
    private var index: Int = 0
    private var longWordHelper: [UInt32] = []
    private var typingStates: [[UInt32]] = []
    private var typingStatesData: [UInt32] = []

    private var keyStates: [UInt32] = Array(repeating: 0, count: MAX_BUFF)
    private var stateIndex: Int = 0

    private var tempDisableKey: Bool = false
    private var isCorrect: Bool = false
    private var isChanged: Bool = false
    private var vowelCount: Int = 0
    private var vowelStartIndex: Int = 0   // VSI
    private var vowelEndIndex: Int = 0     // VEI
    private var vowelWillSetMark: Int = 0  // VWSM
    private var isRestoredW: Bool = false
    private var isCheckedGrammar: Bool = false
    private var isCaps: Bool = false
    private var spaceCount: Int = 0
    private var hasHandledMacro: Bool = false
    private var upperCaseStatus: UInt8 = 0 // 1: sau dấu chấm, 2: sau enter
    private var isCharKeyCode: Bool = false
    private var specialChar: [UInt32] = []
    private var useSpellCheckingBefore: Int = 1
    private var hasHandleQuickConsonant: Bool = false
    private var willTempOffEngine: Bool = false

    public private(set) var spellingOK: Bool = false
    private var spellingFlag: Bool = false
    public private(set) var spellingVowelOK: Bool = false
    private var spellingEndIndex: Int = 0

    // Bảng phím xử lý Telex / VNI / Simple Telex
    private let processingChar: [[UInt16]] = [
        [OpenKeyCode.s, OpenKeyCode.f, OpenKeyCode.r, OpenKeyCode.x, OpenKeyCode.j, OpenKeyCode.a, OpenKeyCode.o, OpenKeyCode.e, OpenKeyCode.w, OpenKeyCode.d, OpenKeyCode.z], // Telex
        [OpenKeyCode.num1, OpenKeyCode.num2, OpenKeyCode.num3, OpenKeyCode.num4, OpenKeyCode.num5, OpenKeyCode.num6, OpenKeyCode.num6, OpenKeyCode.num7, OpenKeyCode.num8, OpenKeyCode.num9, OpenKeyCode.num0], // VNI
        [OpenKeyCode.s, OpenKeyCode.f, OpenKeyCode.r, OpenKeyCode.x, OpenKeyCode.j, OpenKeyCode.a, OpenKeyCode.o, OpenKeyCode.e, OpenKeyCode.w, OpenKeyCode.d, OpenKeyCode.z], // Simple Telex 1
        [OpenKeyCode.s, OpenKeyCode.f, OpenKeyCode.r, OpenKeyCode.x, OpenKeyCode.j, OpenKeyCode.a, OpenKeyCode.o, OpenKeyCode.e, OpenKeyCode.w, OpenKeyCode.d, OpenKeyCode.z]  // Simple Telex 2
    ]

    private let charKeyCodes: [UInt16] = [
        OpenKeyCode.backquote, OpenKeyCode.num1, OpenKeyCode.num2, OpenKeyCode.num3, OpenKeyCode.num4,
        OpenKeyCode.num5, OpenKeyCode.num6, OpenKeyCode.num7, OpenKeyCode.num8, OpenKeyCode.num9,
        OpenKeyCode.num0, OpenKeyCode.minus, OpenKeyCode.equals, OpenKeyCode.leftBracket,
        OpenKeyCode.rightBracket, OpenKeyCode.backslash, OpenKeyCode.semicolon, OpenKeyCode.quote,
        OpenKeyCode.comma, OpenKeyCode.dot, OpenKeyCode.slash
    ]

    private let breakCodes: [UInt16] = [
        OpenKeyCode.esc, OpenKeyCode.tab, OpenKeyCode.enter, OpenKeyCode.return,
        OpenKeyCode.left, OpenKeyCode.right, OpenKeyCode.down, OpenKeyCode.up,
        OpenKeyCode.comma, OpenKeyCode.dot, OpenKeyCode.slash, OpenKeyCode.semicolon,
        OpenKeyCode.quote, OpenKeyCode.backslash, OpenKeyCode.minus, OpenKeyCode.equals,
        OpenKeyCode.backquote, OpenKeyCode.tab
    ]

    private let macroBreakCodes: [UInt16] = [
        OpenKeyCode.return, OpenKeyCode.comma, OpenKeyCode.dot, OpenKeyCode.slash,
        OpenKeyCode.semicolon, OpenKeyCode.quote, OpenKeyCode.backslash,
        OpenKeyCode.minus, OpenKeyCode.equals
    ]

    // MARK: - Khởi tạo
    public init() {
        useSpellCheckingBefore = vCheckSpelling
    }

    public func reset() {
        index = 0
        stateIndex = 0
        spaceCount = 0
        hasHandledMacro = false
        hasHandleQuickConsonant = false
        tempDisableKey = false
        willTempOffEngine = false
        upperCaseStatus = 0
        specialChar.removeAll()
        longWordHelper.removeAll()
        typingStates.removeAll()
        typingStatesData.removeAll()
        hookState = OpenKeyHookState()
    }

    /// Trích xuất từ hiện tại đang được lưu trong buffer typingWord
    public func getCurrentWord() -> String {
        guard index > 0 else { return "" }
        var result = ""
        for i in 0..<index {
            let code = getCharacterCode(typingWord[i])
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

    @inline(__always)
    private func chr(_ idx: Int) -> UInt16 {
        return UInt16(typingWord[idx] & OpenKeyMask.charMask)
    }

    @inline(__always)
    private func isKeyZ(_ key: UInt16) -> Bool {
        guard isZKeyRemoveToneEnabled else { return false }
        return processingChar[vInputType.rawValue][10] == key
    }

    @inline(__always)
    private func isKeyD(_ key: UInt16) -> Bool {
        return processingChar[vInputType.rawValue][9] == key
    }

    @inline(__always)
    private func isKeyW(_ key: UInt16) -> Bool {
        if vInputType != .vni {
            return processingChar[vInputType.rawValue][8] == key
        } else {
            return processingChar[vInputType.rawValue][8] == key || processingChar[vInputType.rawValue][7] == key
        }
    }

    @inline(__always)
    private func isKeyDouble(_ key: UInt16) -> Bool {
        if vInputType != .vni {
            return processingChar[vInputType.rawValue][5] == key ||
                   processingChar[vInputType.rawValue][6] == key ||
                   processingChar[vInputType.rawValue][7] == key
        } else {
            return processingChar[vInputType.rawValue][6] == key
        }
    }

    @inline(__always)
    private func isKeyS(_ key: UInt16) -> Bool { return processingChar[vInputType.rawValue][0] == key }
    @inline(__always)
    private func isKeyF(_ key: UInt16) -> Bool { return processingChar[vInputType.rawValue][1] == key }
    @inline(__always)
    private func isKeyR(_ key: UInt16) -> Bool { return processingChar[vInputType.rawValue][2] == key }
    @inline(__always)
    private func isKeyX(_ key: UInt16) -> Bool { return processingChar[vInputType.rawValue][3] == key }
    @inline(__always)
    private func isKeyJ(_ key: UInt16) -> Bool { return processingChar[vInputType.rawValue][4] == key }

    @inline(__always)
    private func isMarkKey(_ keyCode: UInt16) -> Bool {
        if vInputType != .vni {
            return keyCode == OpenKeyCode.s || keyCode == OpenKeyCode.f || keyCode == OpenKeyCode.r ||
                   keyCode == OpenKeyCode.j || keyCode == OpenKeyCode.x
        } else {
            return keyCode == OpenKeyCode.num1 || keyCode == OpenKeyCode.num2 || keyCode == OpenKeyCode.num3 ||
                   keyCode == OpenKeyCode.num5 || keyCode == OpenKeyCode.num4
        }
    }

    @inline(__always)
    private func isSpecialKey(_ keyCode: UInt16) -> Bool {
        switch vInputType {
        case .telex:
            return keyCode == OpenKeyCode.w || keyCode == OpenKeyCode.e || keyCode == OpenKeyCode.r ||
                   keyCode == OpenKeyCode.o || keyCode == OpenKeyCode.leftBracket || keyCode == OpenKeyCode.rightBracket ||
                   keyCode == OpenKeyCode.a || keyCode == OpenKeyCode.s || keyCode == OpenKeyCode.d ||
                   keyCode == OpenKeyCode.f || keyCode == OpenKeyCode.j || keyCode == OpenKeyCode.z ||
                   keyCode == OpenKeyCode.x
        case .vni:
            return OpenKeyCode.isNumberKey(keyCode)
        case .simpleTelex1, .simpleTelex2:
            return keyCode == OpenKeyCode.w || keyCode == OpenKeyCode.e || keyCode == OpenKeyCode.r ||
                   keyCode == OpenKeyCode.o || keyCode == OpenKeyCode.a || keyCode == OpenKeyCode.s ||
                   keyCode == OpenKeyCode.d || keyCode == OpenKeyCode.f || keyCode == OpenKeyCode.j ||
                   keyCode == OpenKeyCode.z || keyCode == OpenKeyCode.x
        }
    }

    @inline(__always)
    private func isWordBreak(_ event: OpenKeyEvent, _ state: OpenKeyEventState, _ data: UInt16) -> Bool {
        if event == .mouse { return true }
        return breakCodes.contains(data)
    }

    @inline(__always)
    private func isMacroBreakCode(_ data: UInt16) -> Bool {
        return macroBreakCodes.contains(data)
    }

    @inline(__always)
    private func isQuickTelexKey(_ code: UInt16) -> Bool {
        guard index > 0 else { return false }
        let prev = chr(index - 1)
        return (code == OpenKeyCode.c || code == OpenKeyCode.g || code == OpenKeyCode.k ||
                code == OpenKeyCode.n || code == OpenKeyCode.q || code == OpenKeyCode.p ||
                code == OpenKeyCode.t || code == OpenKeyCode.u) && prev == code
    }

    private func setKeyData(_ idx: Int, _ keyCode: UInt16, _ caps: Bool) {
        typingWord[idx] = UInt32(keyCode) | (caps ? OpenKeyMask.caps : 0)
    }

    // MARK: - Chuyển đổi mã ký tự thực tế getCharacterCode
    public func getCharacterCode(_ data: UInt32) -> UInt32 {
        let capsElem: Int = (data & OpenKeyMask.caps) != 0 ? 0 : 1
        var key = data & OpenKeyMask.charMask

        if (data & OpenKeyMask.mark) != 0 {
            var markElem = -2
            let markBit = data & OpenKeyMask.mark
            switch markBit {
            case OpenKeyMask.mark1: markElem = 0
            case OpenKeyMask.mark2: markElem = 2
            case OpenKeyMask.mark3: markElem = 4
            case OpenKeyMask.mark4: markElem = 6
            case OpenKeyMask.mark5: markElem = 8
            default: break
            }
            markElem += capsElem

            switch key {
            case UInt32(OpenKeyCode.a), UInt32(OpenKeyCode.o), UInt32(OpenKeyCode.u), UInt32(OpenKeyCode.e):
                if (data & OpenKeyMask.tone) == 0 && (data & OpenKeyMask.toneW) == 0 {
                    markElem += 4
                }
            default: break
            }

            if (data & OpenKeyMask.tone) != 0 {
                key |= OpenKeyMask.tone
            } else if (data & OpenKeyMask.toneW) != 0 {
                key |= OpenKeyMask.toneW
            }

            guard let row = OpenKeyVietnameseData.unicodeTable[key], markElem >= 0, markElem < row.count else {
                return data
            }
            return UInt32(row[markElem]) | OpenKeyMask.charCode
        } else {
            guard let row = OpenKeyVietnameseData.unicodeTable[key] else {
                return data
            }
            if (data & OpenKeyMask.tone) != 0 {
                guard capsElem < row.count else { return data }
                return UInt32(row[capsElem]) | OpenKeyMask.charCode
            } else if (data & OpenKeyMask.toneW) != 0 {
                guard (capsElem + 2) < row.count else { return data }
                return UInt32(row[capsElem + 2]) | OpenKeyMask.charCode
            } else {
                return data
            }
        }
    }

    // MARK: - Kiểm tra Chính Tả (checkSpelling - Chuyển đổi 1-1 từ Engine.cpp L176)
    public func checkSpelling(forceCheckVowel: Bool = false) {
        spellingOK = false
        spellingVowelOK = true
        spellingEndIndex = index

        if index > 0 && chr(index - 1) == OpenKeyCode.rightBracket {
            spellingEndIndex = index - 1
        }

        if spellingEndIndex > 0 {
            var j = 0
            // 1. Kiểm tra phụ âm đầu
            if OpenKeyCode.isConsonant(chr(0)) {
                for i in 0..<OpenKeyVietnameseData.consonantTable.count {
                    spellingFlag = false
                    let cons = OpenKeyVietnameseData.consonantTable[i]
                    if spellingEndIndex < cons.count {
                        spellingFlag = true
                    }
                    for jj in 0..<cons.count {
                        if spellingEndIndex > jj {
                            let expected = cons[jj]
                            let ch = chr(jj)
                            let cond1 = (expected & ~(vQuickStartConsonant != 0 ? OpenKeyMask.endConsonant : 0)) != ch
                            let cond2 = (expected & ~(vAllowConsonantZFWJ != 0 ? OpenKeyMask.consonantAllow : 0)) != ch
                            if cond1 && cond2 {
                                spellingFlag = true
                                break
                            }
                        }
                    }
                    if spellingFlag { continue }
                    j = cons.count
                    break
                }
            }

            if j == spellingEndIndex { // Trường hợp chỉ có phụ âm (ví dụ "d")
                spellingOK = true
            }

            // 2. Kiểm tra nguyên âm kế tiếp
            var k = j
            vowelStartIndex = k
            // Xử lý ngoại lệ "qu" trong "quét"
            if chr(vowelStartIndex) == OpenKeyCode.u && k > 0 && k < spellingEndIndex - 1 && chr(vowelStartIndex - 1) == OpenKeyCode.q {
                k += 1
                j = k
                vowelStartIndex = k
            } else if index >= 2 && chr(0) == OpenKeyCode.g && chr(1) == OpenKeyCode.i && OpenKeyCode.isConsonant(chr(2)) {
                vowelStartIndex = 1; k = 1; j = 1 // Ngoại lệ "gìn"
            }

            for _ in 0..<3 {
                if k < spellingEndIndex && !OpenKeyCode.isConsonant(chr(k)) {
                    k += 1
                    vowelEndIndex = k
                }
            }

            if k > j { // Có nguyên âm
                spellingVowelOK = false
                // Kiểm tra tổ hợp nguyên âm
                if (k - j) > 1 && forceCheckVowel {
                    if let vowelSet = OpenKeyVietnameseData.vowelCombine[chr(j)] {
                        for l in 0..<vowelSet.count {
                            spellingFlag = false
                            let vRow = vowelSet[l]
                            var ii = 1
                            while ii < vRow.count {
                                let curIdx = j + ii - 1
                                if curIdx < spellingEndIndex {
                                    let actualVal = UInt32(chr(curIdx)) | (typingWord[curIdx] & OpenKeyMask.toneW) | (typingWord[curIdx] & OpenKeyMask.tone)
                                    if vRow[ii] != actualVal {
                                        spellingFlag = true
                                        break
                                    }
                                }
                                ii += 1
                            }
                            if spellingFlag || (k < spellingEndIndex && vRow[0] == 0) || (j + ii - 1 < spellingEndIndex && !OpenKeyCode.isConsonant(chr(j + ii - 1))) {
                                continue
                            }
                            spellingVowelOK = true
                            break
                        }
                    }
                } else if !OpenKeyCode.isConsonant(chr(j)) {
                    spellingVowelOK = true
                }

                // 3. Kiểm tra phụ âm cuối
                if k == spellingEndIndex {
                    spellingOK = true
                } else {
                    for ii in 0..<OpenKeyVietnameseData.endConsonantTable.count {
                        spellingFlag = false
                        let eRow = OpenKeyVietnameseData.endConsonantTable[ii]
                        var jj = 0
                        while jj < eRow.count {
                            if spellingEndIndex > (k + jj) {
                                let expected = eRow[jj]
                                let ch = chr(k + jj)
                                if (expected & ~(vQuickEndConsonant != 0 ? OpenKeyMask.endConsonant : 0)) != ch {
                                    spellingFlag = true
                                    break
                                }
                            }
                            jj += 1
                        }
                        if spellingFlag { continue }
                        if (k + jj) >= spellingEndIndex {
                            spellingOK = true
                            break
                        }
                    }
                }

                // 4. Giới hạn dấu thanh với phụ âm cuối c, ch, t: không được dùng huyền, hỏi, ngã
                if spellingOK {
                    if index >= 3 && chr(index - 1) == OpenKeyCode.h && chr(index - 2) == OpenKeyCode.c {
                        let prevMark = typingWord[index - 3] & OpenKeyMask.mark
                        if prevMark != 0 && prevMark != OpenKeyMask.mark1 && prevMark != OpenKeyMask.mark5 {
                            spellingOK = false
                        }
                    } else if index >= 2 && chr(index - 1) == OpenKeyCode.t {
                        let prevMark = typingWord[index - 2] & OpenKeyMask.mark
                        if prevMark != 0 && prevMark != OpenKeyMask.mark1 && prevMark != OpenKeyMask.mark5 {
                            spellingOK = false
                        }
                    }
                }
            }
        } else {
            spellingOK = true
        }

        tempDisableKey = !(spellingOK && spellingVowelOK)
    }

    // MARK: - Tìm và Tính toán Nguyên Âm (findAndCalculateVowel - L560)
    private func findAndCalculateVowel() {
        vowelCount = 0
        vowelStartIndex = 0
        vowelEndIndex = 0

        if index > 0 {
            for iii in stride(from: index - 1, through: 0, by: -1) {
                if OpenKeyCode.isConsonant(chr(iii)) {
                    if vowelCount > 0 { break }
                } else { // Là nguyên âm
                    if vowelCount == 0 {
                        vowelEndIndex = iii
                    }
                    if vowelCount > 0 && iii - 1 >= 0 &&
                        ((chr(iii) == OpenKeyCode.i && chr(iii - 1) == OpenKeyCode.g) ||
                         (chr(iii) == OpenKeyCode.u && chr(iii - 1) == OpenKeyCode.q)) {
                        break
                    }
                    vowelStartIndex = iii
                    vowelCount += 1
                }
            }
        }
    }

    private func canHasEndConsonant() -> Bool {
        guard let vo = OpenKeyVietnameseData.vowelCombine[chr(vowelStartIndex)] else { return false }
        for ii in 0..<vo.count {
            var kk = vowelStartIndex
            var iii = 1
            while iii < vo[ii].count {
                if kk > vowelEndIndex || ((UInt32(chr(kk)) | (typingWord[kk] & OpenKeyMask.tone) | (typingWord[kk] & OpenKeyMask.toneW)) != vo[ii][iii]) {
                    break
                }
                kk += 1
                iii += 1
            }
            if iii >= vo[ii].count {
                return vo[ii][0] == 1
            }
        }
        return false
    }

    // MARK: - Vị trí Đặt Dấu Thanh Chuẩn Mới (handleModernMark - L629)
    private func handleModernMark() {
        vowelWillSetMark = vowelEndIndex
        hookState.backspaceCount = UInt8(index - vowelEndIndex)

        // Quy tắc 3 nguyên âm: oai, uyu, oeo, uya
        if vowelCount == 3 && ((chr(vowelStartIndex) == OpenKeyCode.o && chr(vowelStartIndex + 1) == OpenKeyCode.a && chr(vowelStartIndex + 2) == OpenKeyCode.i) ||
                               (chr(vowelStartIndex) == OpenKeyCode.u && chr(vowelStartIndex + 1) == OpenKeyCode.y && chr(vowelStartIndex + 2) == OpenKeyCode.u) ||
                               (chr(vowelStartIndex) == OpenKeyCode.o && chr(vowelStartIndex + 1) == OpenKeyCode.e && chr(vowelStartIndex + 2) == OpenKeyCode.o) ||
                               (chr(vowelStartIndex) == OpenKeyCode.u && chr(vowelStartIndex + 1) == OpenKeyCode.y && chr(vowelStartIndex + 2) == OpenKeyCode.a)) {
            vowelWillSetMark = vowelStartIndex + 1
            hookState.backspaceCount = UInt8(index - vowelWillSetMark)
        } else if (chr(vowelStartIndex) == OpenKeyCode.o && chr(vowelStartIndex + 1) == OpenKeyCode.i) ||
                  (chr(vowelStartIndex) == OpenKeyCode.a && chr(vowelStartIndex + 1) == OpenKeyCode.i) ||
                  (chr(vowelStartIndex) == OpenKeyCode.u && chr(vowelStartIndex + 1) == OpenKeyCode.i) {
            vowelWillSetMark = vowelStartIndex
            hookState.backspaceCount = UInt8(index - vowelWillSetMark)
        } else if vowelEndIndex > 0 && chr(vowelEndIndex - 1) == OpenKeyCode.a && chr(vowelEndIndex) == OpenKeyCode.y {
            vowelWillSetMark = vowelEndIndex - 1
            hookState.backspaceCount = UInt8((index - vowelEndIndex) + 1)
        } else if chr(vowelStartIndex) == OpenKeyCode.u && chr(vowelStartIndex + 1) == OpenKeyCode.o {
            vowelWillSetMark = vowelStartIndex + 1
            hookState.backspaceCount = UInt8(index - vowelWillSetMark)
        } else if chr(vowelStartIndex + 1) == OpenKeyCode.o || chr(vowelStartIndex + 1) == OpenKeyCode.u {
            vowelWillSetMark = vowelEndIndex - 1
            hookState.backspaceCount = UInt8((index - vowelEndIndex) + 1)
        } else if chr(vowelStartIndex) == OpenKeyCode.o || chr(vowelStartIndex) == OpenKeyCode.u {
            vowelWillSetMark = vowelEndIndex
            hookState.backspaceCount = UInt8(index - vowelEndIndex)
        }

        // Quy tắc 3.1
        let vsi = vowelStartIndex
        if (chr(vsi) == OpenKeyCode.i && (typingWord[vsi + 1] & (UInt32(OpenKeyCode.e) | OpenKeyMask.tone)) != 0) ||
           (chr(vsi) == OpenKeyCode.y && (typingWord[vsi + 1] & (UInt32(OpenKeyCode.e) | OpenKeyMask.tone)) != 0) ||
           (chr(vsi) == OpenKeyCode.u && (typingWord[vsi + 1] == (UInt32(OpenKeyCode.o) | OpenKeyMask.tone))) ||
           ((typingWord[vsi] == (UInt32(OpenKeyCode.u) | OpenKeyMask.toneW)) && (typingWord[vsi + 1] == (UInt32(OpenKeyCode.o) | OpenKeyMask.toneW))) {
            if vsi + 2 < index {
                let c2 = chr(vsi + 2)
                if c2 == OpenKeyCode.p || c2 == OpenKeyCode.t || c2 == OpenKeyCode.m || c2 == OpenKeyCode.n ||
                   c2 == OpenKeyCode.o || c2 == OpenKeyCode.u || c2 == OpenKeyCode.i || c2 == OpenKeyCode.c ||
                   (vsi + 3 < index && c2 == OpenKeyCode.c && chr(vsi + 3) == OpenKeyCode.h) ||
                   (vsi + 3 < index && c2 == OpenKeyCode.n && chr(vsi + 3) == OpenKeyCode.h) ||
                   (vsi + 3 < index && c2 == OpenKeyCode.n && chr(vsi + 3) == OpenKeyCode.g) {
                    vowelWillSetMark = vsi + 1
                    hookState.backspaceCount = UInt8(index - vowelWillSetMark)
                } else {
                    vowelWillSetMark = vsi
                    hookState.backspaceCount = UInt8(index - vowelWillSetMark)
                }
            } else {
                vowelWillSetMark = vsi
                hookState.backspaceCount = UInt8(index - vowelWillSetMark)
            }
        }
        // Quy tắc 4
        if vowelCount == 2 {
            if ((chr(vsi) == OpenKeyCode.i) && (chr(vsi + 1) == OpenKeyCode.a)) ||
               ((chr(vsi) == OpenKeyCode.i) && (chr(vsi + 1) == OpenKeyCode.u)) ||
               ((chr(vsi) == OpenKeyCode.i) && (chr(vsi + 1) == OpenKeyCode.o)) {
                if vsi == 0 || (chr(vsi - 1) != OpenKeyCode.g) {
                    vowelWillSetMark = vsi
                    hookState.backspaceCount = UInt8(index - vowelWillSetMark)
                } else {
                    vowelWillSetMark = vsi + 1
                    hookState.backspaceCount = UInt8(index - vowelWillSetMark)
                }
            } else if (chr(vsi) == OpenKeyCode.u) && (chr(vsi + 1) == OpenKeyCode.a) {
                if vsi == 0 || (chr(vsi - 1) != OpenKeyCode.q) {
                    if vowelEndIndex + 1 >= index || !canHasEndConsonant() {
                        vowelWillSetMark = vsi
                        hookState.backspaceCount = UInt8(index - vowelWillSetMark)
                    }
                } else {
                    vowelWillSetMark = vsi + 1
                    hookState.backspaceCount = UInt8(index - vowelWillSetMark)
                }
            } else if (chr(vsi) == OpenKeyCode.o) && (chr(vsi + 1) == OpenKeyCode.o) {
                vowelWillSetMark = vowelEndIndex
                hookState.backspaceCount = UInt8(index - vowelWillSetMark)
            }
        }
    }

    // MARK: - Vị trí Đặt Dấu Thanh Chuẩn Cũ (handleOldMark - L727)
    private func handleOldMark() {
        if vowelCount == 0 && chr(vowelEndIndex) == OpenKeyCode.i {
            vowelWillSetMark = vowelEndIndex
        } else {
            vowelWillSetMark = vowelStartIndex
        }
        hookState.backspaceCount = UInt8(index - vowelWillSetMark)

        // Quy tắc 2: có 3 nguyên âm hoặc có phụ âm cuối
        if vowelCount == 3 || (vowelEndIndex + 1 < index && OpenKeyCode.isConsonant(chr(vowelEndIndex + 1)) && canHasEndConsonant()) {
            vowelWillSetMark = vowelStartIndex + 1
            hookState.backspaceCount = UInt8(index - vowelWillSetMark)
        }

        // Quy tắc 3
        for ii in vowelStartIndex...vowelEndIndex {
            if (chr(ii) == OpenKeyCode.e && (typingWord[ii] & OpenKeyMask.tone) != 0) ||
               (chr(ii) == OpenKeyCode.o && (typingWord[ii] & OpenKeyMask.toneW) != 0) {
                vowelWillSetMark = ii
                hookState.backspaceCount = UInt8(index - vowelWillSetMark)
                break
            }
        }

        hookState.newCharCount = hookState.backspaceCount
    }

    // MARK: - Chèn Dấu Thanh (insertMark - L753)
    public func insertMark(_ markMask: UInt32, canModifyFlag: Bool = true) {
        let savedHookState = hookState
        vowelCount = 0
        if canModifyFlag {
            hookState.code = .vWillProcess
            hookState.backspaceCount = 0
            hookState.newCharCount = 0
        }

        findAndCalculateVowel()
        vowelWillSetMark = 0

        if vowelCount == 1 {
            vowelWillSetMark = vowelEndIndex
            if canModifyFlag {
                hookState.backspaceCount = UInt8(index - vowelEndIndex)
            }
        } else {
            if vUseModernOrthography == 0 {
                handleOldMark()
            } else {
                handleModernMark()
            }
            if (typingWord[vowelEndIndex] & OpenKeyMask.tone) != 0 || (typingWord[vowelEndIndex] & OpenKeyMask.toneW) != 0 {
                vowelWillSetMark = vowelEndIndex
            }
        }

        var kk = index - 1 - vowelStartIndex
        // Nếu gõ lặp lại cùng một dấu -> Hoàn tác gỡ dấu (Restore)
        if (typingWord[vowelWillSetMark] & markMask) != 0 {
            typingWord[vowelWillSetMark] &= ~OpenKeyMask.mark
            if canModifyFlag {
                hookState.code = .vRestore
                for ii in vowelStartIndex..<index {
                    typingWord[ii] &= ~OpenKeyMask.mark
                    hookState.charData[kk] = getCharacterCode(typingWord[ii])
                    kk -= 1
                }
                hookState.backspaceCount = UInt8(index - vowelStartIndex)
                hookState.newCharCount = hookState.backspaceCount
            }
            tempDisableKey = true
        } else {
            // Xóa dấu cũ và thêm dấu mới
            typingWord[vowelWillSetMark] &= ~OpenKeyMask.mark
            typingWord[vowelWillSetMark] |= markMask

            if canModifyFlag {
                for ii in vowelStartIndex..<index {
                    if ii != vowelWillSetMark {
                        typingWord[ii] &= ~OpenKeyMask.mark
                    }
                    hookState.charData[kk] = getCharacterCode(typingWord[ii])
                    kk -= 1
                }
                hookState.backspaceCount = UInt8(index - vowelStartIndex)
                hookState.newCharCount = hookState.backspaceCount
            }
        }

        if !canModifyFlag {
            hookState = savedHookState
        }
    }

    // MARK: - Chèn chữ Đ (insertD - L808)
    private func insertD(_ data: UInt16, _ isCaps: Bool) {
        hookState.code = .vWillProcess
        hookState.backspaceCount = 0

        for ii in stride(from: index - 1, through: 0, by: -1) {
            hookState.backspaceCount += 1
            if chr(ii) == OpenKeyCode.d {
                if (typingWord[ii] & OpenKeyMask.tone) != 0 {
                    // Phục hồi lại thành 'd'
                    hookState.code = .vRestore
                    typingWord[ii] &= ~OpenKeyMask.tone
                    hookState.charData[index - 1 - ii] = typingWord[ii]
                    tempDisableKey = true
                    break
                } else {
                    typingWord[ii] |= OpenKeyMask.tone
                    hookState.charData[index - 1 - ii] = getCharacterCode(typingWord[ii])
                }
                break
            } else {
                hookState.charData[index - 1 - ii] = getCharacterCode(typingWord[ii])
            }
        }
        hookState.newCharCount = hookState.backspaceCount
    }

    // MARK: - Chèn mũ A, O, E (insertAOE - L833)
    private func insertAOE(_ data: UInt16, _ isCaps: Bool) {
        findAndCalculateVowel()

        // Xóa móc W
        if vowelStartIndex <= vowelEndIndex && vowelEndIndex < index {
            for ii in vowelStartIndex...vowelEndIndex {
                typingWord[ii] &= ~OpenKeyMask.toneW
            }
        }

        hookState.code = .vWillProcess
        hookState.backspaceCount = 0

        for ii in stride(from: index - 1, through: 0, by: -1) {
            hookState.backspaceCount += 1
            if chr(ii) == data {
                if (typingWord[ii] & OpenKeyMask.tone) != 0 {
                    // Hoàn tác mũ về chữ ban đầu
                    hookState.code = .vRestore
                    typingWord[ii] &= ~OpenKeyMask.tone
                    hookState.charData[index - 1 - ii] = typingWord[ii]
                    if data != OpenKeyCode.o {
                        tempDisableKey = true
                    }
                    break
                } else {
                    typingWord[ii] |= OpenKeyMask.tone
                    if !isKeyD(data) {
                        typingWord[ii] &= ~OpenKeyMask.toneW
                    }
                    hookState.charData[index - 1 - ii] = getCharacterCode(typingWord[ii])
                }
                break
            } else {
                hookState.charData[index - 1 - ii] = getCharacterCode(typingWord[ii])
            }
        }
        hookState.newCharCount = hookState.backspaceCount
    }

    // MARK: - Chèn móc W (insertW - L871)
    private func insertW(_ data: UInt16, _ isCaps: Bool) {
        isRestoredW = false
        findAndCalculateVowel()

        if vowelStartIndex <= vowelEndIndex && vowelEndIndex < index {
            for ii in vowelStartIndex...vowelEndIndex {
                typingWord[ii] &= ~OpenKeyMask.tone
            }
        }

        if vowelCount > 1 {
            hookState.backspaceCount = UInt8(index - vowelStartIndex)
            hookState.newCharCount = hookState.backspaceCount

            let vsi = vowelStartIndex
            if ((typingWord[vsi] & OpenKeyMask.toneW) != 0 && (typingWord[vsi + 1] & OpenKeyMask.toneW) != 0) ||
               ((typingWord[vsi] & OpenKeyMask.toneW) != 0 && chr(vsi + 1) == OpenKeyCode.i) ||
               ((typingWord[vsi] & OpenKeyMask.toneW) != 0 && chr(vsi + 1) == OpenKeyCode.a) {
                // Hoàn tác móc
                hookState.code = .vRestore
                for ii in vsi..<index {
                    typingWord[ii] &= ~OpenKeyMask.toneW
                    hookState.charData[index - 1 - ii] = getCharacterCode(typingWord[ii]) & ~OpenKeyMask.standalone
                }
                isRestoredW = true
                tempDisableKey = true
            } else {
                hookState.code = .vWillProcess
                if (chr(vsi) == OpenKeyCode.u && chr(vsi + 1) == OpenKeyCode.o) {
                    if vsi - 2 >= 0 && chr(vsi - 2) == OpenKeyCode.t && chr(vsi - 1) == OpenKeyCode.h {
                        typingWord[vsi + 1] |= OpenKeyMask.toneW
                        if vsi + 2 < index && chr(vsi + 2) == OpenKeyCode.n {
                            typingWord[vsi] |= OpenKeyMask.toneW
                        }
                    } else if vsi - 1 >= 0 && chr(vsi - 1) == OpenKeyCode.q {
                        typingWord[vsi + 1] |= OpenKeyMask.toneW
                    } else {
                        typingWord[vsi] |= OpenKeyMask.toneW
                        typingWord[vsi + 1] |= OpenKeyMask.toneW
                    }
                } else if (chr(vsi) == OpenKeyCode.u && chr(vsi + 1) == OpenKeyCode.a) ||
                          (chr(vsi) == OpenKeyCode.u && chr(vsi + 1) == OpenKeyCode.i) ||
                          (chr(vsi) == OpenKeyCode.u && chr(vsi + 1) == OpenKeyCode.u) ||
                          (chr(vsi) == OpenKeyCode.o && chr(vsi + 1) == OpenKeyCode.i) {
                    typingWord[vsi] |= OpenKeyMask.toneW
                } else if (chr(vsi) == OpenKeyCode.i && chr(vsi + 1) == OpenKeyCode.o) ||
                          (chr(vsi) == OpenKeyCode.o && chr(vsi + 1) == OpenKeyCode.a) {
                    typingWord[vsi + 1] |= OpenKeyMask.toneW
                } else {
                    tempDisableKey = true
                    hookState.code = .vDoNothing
                }

                for ii in vsi..<index {
                    hookState.charData[index - 1 - ii] = getCharacterCode(typingWord[ii])
                }
            }
            return
        }

        hookState.code = .vWillProcess
        hookState.backspaceCount = 0

        for ii in stride(from: index - 1, through: 0, by: -1) {
            if ii < vowelStartIndex { break }
            hookState.backspaceCount += 1
            let ch = chr(ii)
            switch ch {
            case OpenKeyCode.a, OpenKeyCode.u, OpenKeyCode.o:
                if (typingWord[ii] & OpenKeyMask.toneW) != 0 {
                    if (typingWord[ii] & OpenKeyMask.standalone) != 0 {
                        hookState.code = .vWillProcess
                        if ch == OpenKeyCode.u {
                            typingWord[ii] = UInt32(OpenKeyCode.w) | ((typingWord[ii] & OpenKeyMask.caps) != 0 ? OpenKeyMask.caps : 0)
                        } else if ch == OpenKeyCode.o {
                            hookState.code = .vRestore
                            typingWord[ii] = UInt32(OpenKeyCode.o) | ((typingWord[ii] & OpenKeyMask.caps) != 0 ? OpenKeyMask.caps : 0)
                            isRestoredW = true
                        }
                        hookState.charData[index - 1 - ii] = typingWord[ii]
                    } else {
                        hookState.code = .vRestore
                        typingWord[ii] &= ~OpenKeyMask.toneW
                        hookState.charData[index - 1 - ii] = typingWord[ii]
                        isRestoredW = true
                    }
                    tempDisableKey = true
                } else {
                    typingWord[ii] |= OpenKeyMask.toneW
                    typingWord[ii] &= ~OpenKeyMask.tone
                    hookState.charData[index - 1 - ii] = getCharacterCode(typingWord[ii])
                }
            default:
                hookState.charData[index - 1 - ii] = getCharacterCode(typingWord[ii])
            }
        }
        hookState.newCharCount = hookState.backspaceCount
    }

    // MARK: - Gỡ Dấu (removeMark - L587)
    public func removeMark() {
        findAndCalculateVowel()
        isChanged = false
        if index > 0 && vowelStartIndex <= vowelEndIndex && vowelEndIndex < index {
            for i in vowelStartIndex...vowelEndIndex {
                if (typingWord[i] & OpenKeyMask.mark) != 0 {
                    typingWord[i] &= ~OpenKeyMask.mark
                    isChanged = true
                }
            }
        }
        if isChanged {
            hookState.code = .vWillProcess
            hookState.backspaceCount = 0
            for i in stride(from: index - 1, through: vowelStartIndex, by: -1) {
                hookState.backspaceCount += 1
                hookState.charData[index - 1 - i] = getCharacterCode(typingWord[i])
            }
            hookState.newCharCount = hookState.backspaceCount
        } else {
            hookState.code = .vDoNothing
        }
    }

    // MARK: - Kiểm Tra Ngữ Pháp (checkGrammar - L290)
    public func checkGrammar(deltaBackSpace: Int) {
        if index <= 1 || index >= MAX_BUFF { return }

        findAndCalculateVowel()
        if vowelCount == 0 { return }

        isCheckedGrammar = false
        let l = vowelStartIndex

        // Trường hợp thêm n, c, i, m, p, t, u sau "uo" -> đồng bộ cả 2 thành "ươ"
        if index >= 3 {
            for i in stride(from: index - 1, through: 0, by: -1) {
                let ch = chr(i)
                if ch == OpenKeyCode.n || ch == OpenKeyCode.c || ch == OpenKeyCode.i ||
                   ch == OpenKeyCode.m || ch == OpenKeyCode.p || ch == OpenKeyCode.t || ch == OpenKeyCode.u {
                    if i - 2 >= 0 && chr(i - 1) == OpenKeyCode.o && chr(i - 2) == OpenKeyCode.u {
                        let w1 = (typingWord[i - 1] & OpenKeyMask.toneW) != 0
                        let w2 = (typingWord[i - 2] & OpenKeyMask.toneW) != 0
                        if w1 != w2 {
                            typingWord[i - 2] |= OpenKeyMask.toneW
                            typingWord[i - 1] |= OpenKeyMask.toneW
                            isCheckedGrammar = true
                            break
                        }
                    }
                }
            }
        }

        // Simple Telex: tự động thêm mũ cho ie -> iê và uo -> uô khi có phụ âm cuối
        if (vInputType == .simpleTelex1 || vInputType == .simpleTelex2) && index >= 3 {
            for i in stride(from: index - 1, through: 2, by: -1) {
                let ch = chr(i)
                if OpenKeyCode.isConsonant(ch) {
                    if chr(i - 1) == OpenKeyCode.e && chr(i - 2) == OpenKeyCode.i {
                        if (typingWord[i - 1] & OpenKeyMask.tone) == 0 {
                            typingWord[i - 1] |= OpenKeyMask.tone
                            isCheckedGrammar = true
                            break
                        }
                    }
                    if chr(i - 1) == OpenKeyCode.o && chr(i - 2) == OpenKeyCode.u {
                        if (typingWord[i - 1] & (OpenKeyMask.tone | OpenKeyMask.toneW)) == 0 &&
                           (typingWord[i - 2] & (OpenKeyMask.tone | OpenKeyMask.toneW)) == 0 {
                            typingWord[i - 1] |= OpenKeyMask.tone
                            isCheckedGrammar = true
                            break
                        }
                    }
                }
            }
        }

        // Kiểm tra và dịch chuyển lại vị trí dấu thanh nếu cần
        if index >= 2 && l <= vowelEndIndex && vowelEndIndex < index {
            for i in l...vowelEndIndex {
                if (typingWord[i] & OpenKeyMask.mark) != 0 {
                    let mark = typingWord[i] & OpenKeyMask.mark
                    typingWord[i] &= ~OpenKeyMask.mark
                    insertMark(mark, canModifyFlag: false)
                    if i != vowelWillSetMark {
                        isCheckedGrammar = true
                    }
                    break
                }
            }
        }

        // Gửi lại dữ liệu nếu có sửa đổi
        if isCheckedGrammar {
            if hookState.code == .vDoNothing {
                hookState.code = .vWillProcess
            }
            hookState.backspaceCount = 0
            for i in stride(from: index - 1, through: l, by: -1) {
                hookState.backspaceCount += 1
                hookState.charData[index - 1 - i] = getCharacterCode(typingWord[i])
            }
            hookState.newCharCount = hookState.backspaceCount
            hookState.backspaceCount = UInt8(Int(hookState.backspaceCount) + deltaBackSpace)
            hookState.extCode = 4
        }
    }

    private func checkCorrectVowel(_ charset: [[UInt16]], _ i: Int, _ kIn: inout Int, _ markKey: UInt16) {
        if index >= 2 && chr(index - 1) == OpenKeyCode.u && chr(index - 2) == OpenKeyCode.q {
            isCorrect = false
            return
        }
        var k = index - 1
        let row = charset[i]
        for j in stride(from: row.count - 1, through: 0, by: -1) {
            let chExpected = row[j] & ~(vQuickEndConsonant != 0 ? OpenKeyMask.endConsonant : 0)
            if chExpected != chr(k) {
                isCorrect = false
                return
            }
            k -= 1
            if k < 0 { break }
        }

        if isCorrect && row.count > 1 && (isKeyF(markKey) || isKeyX(markKey) || isKeyR(markKey)) {
            if row[1] == OpenKeyCode.c || row[1] == OpenKeyCode.t {
                isCorrect = false
            } else if row.count > 2 && row[2] == OpenKeyCode.t {
                isCorrect = false
            }
        }

        if isCorrect && k >= 0 {
            if chr(k) == chr(k + 1) {
                isCorrect = false
            }
        }
    }

    private func reverseLastStandaloneChar(_ keyCode: UInt32, _ isCaps: Bool) {
        hookState.code = .vWillProcess
        hookState.backspaceCount = 0
        hookState.newCharCount = 1
        hookState.extCode = 4
        typingWord[index - 1] = (keyCode | OpenKeyMask.toneW | OpenKeyMask.standalone | (isCaps ? OpenKeyMask.caps : 0))
        hookState.charData[0] = getCharacterCode(typingWord[index - 1])
    }

    private func checkForStandaloneChar(_ data: UInt16, _ isCaps: Bool, _ keyWillReverse: UInt32) {
        if index > 0 && chr(index - 1) == UInt16(keyWillReverse) && (typingWord[index - 1] & OpenKeyMask.toneW) != 0 {
            hookState.code = .vWillProcess
            hookState.backspaceCount = 1
            hookState.newCharCount = 1
            typingWord[index - 1] = UInt32(data) | (isCaps ? OpenKeyMask.caps : 0)
            hookState.charData[0] = getCharacterCode(typingWord[index - 1])
            return
        }

        if index > 0 && chr(index - 1) == OpenKeyCode.u && keyWillReverse == UInt32(OpenKeyCode.o) {
            insertKey(UInt16(keyWillReverse), isCaps: isCaps)
            reverseLastStandaloneChar(keyWillReverse, isCaps)
            return
        }

        if index == 0 {
            insertKey(data, isCaps: isCaps, isCheckSpelling: false)
            reverseLastStandaloneChar(keyWillReverse, isCaps)
            return
        } else if index == 1 {
            if OpenKeyVietnameseData.standaloneWbad.contains(chr(0)) {
                insertKey(data, isCaps: isCaps)
                return
            }
            insertKey(data, isCaps: isCaps, isCheckSpelling: false)
            reverseLastStandaloneChar(keyWillReverse, isCaps)
            return
        } else if index == 2 {
            for row in OpenKeyVietnameseData.doubleWAllowed {
                if chr(0) == row[0] && chr(1) == row[1] {
                    insertKey(data, isCaps: isCaps, isCheckSpelling: false)
                    reverseLastStandaloneChar(keyWillReverse, isCaps)
                    return
                }
            }
            insertKey(data, isCaps: isCaps)
            return
        }

        insertKey(data, isCaps: isCaps)
    }

    private func handleQuickTelex(_ data: UInt16, _ isCaps: Bool) {
        if data == OpenKeyCode.u {
            typingWord[index - 1] = UInt32(OpenKeyCode.u) | OpenKeyMask.toneW | (isCaps ? OpenKeyMask.caps : 0)
            let secondChar = UInt32(OpenKeyCode.o) | OpenKeyMask.toneW | (isCaps ? OpenKeyMask.caps : 0)
            insertKey(OpenKeyCode.o, isCaps: isCaps, isCheckSpelling: false)
            typingWord[index - 1] = secondChar
            hookState.code = .vWillProcess
            hookState.backspaceCount = 1
            hookState.newCharCount = 2
            hookState.charData[1] = getCharacterCode(typingWord[index - 2])
            hookState.charData[0] = getCharacterCode(typingWord[index - 1])
            return
        }
        guard let mapping = OpenKeyVietnameseData.quickTelex[UInt32(data)] else { return }
        hookState.code = .vWillProcess
        hookState.backspaceCount = 1
        hookState.newCharCount = 2
        hookState.charData[1] = UInt32(mapping[0]) | (isCaps ? OpenKeyMask.caps : 0)
        hookState.charData[0] = UInt32(mapping[1]) | (isCaps ? OpenKeyMask.caps : 0)
        insertKey(mapping[1], isCaps: isCaps, isCheckSpelling: false)
    }

    public func checkRestoreIfWrongSpelling(handleCode: HookCodeState) -> Bool {
        for ii in 0..<index {
            if !OpenKeyCode.isConsonant(chr(ii)) &&
                ((typingWord[ii] & OpenKeyMask.mark) != 0 || (typingWord[ii] & OpenKeyMask.tone) != 0 || (typingWord[ii] & OpenKeyMask.toneW) != 0) {
                hookState.code = handleCode
                hookState.backspaceCount = UInt8(index)
                hookState.newCharCount = UInt8(stateIndex)
                for i in 0..<stateIndex {
                    typingWord[i] = keyStates[i]
                    hookState.charData[stateIndex - 1 - i] = typingWord[i]
                }
                index = stateIndex
                return true
            }
        }
        return false
    }

    public func insertKey(_ keyCode: UInt16, isCaps: Bool, isCheckSpelling: Bool = true) {
        if index >= MAX_BUFF {
            longWordHelper.append(typingWord[0])
            for iii in 0..<(MAX_BUFF - 1) {
                typingWord[iii] = typingWord[iii + 1]
            }
            setKeyData(index - 1, keyCode, isCaps)
        } else {
            setKeyData(index, keyCode, isCaps)
            index += 1
        }

        if vCheckSpelling != 0 && isCheckSpelling {
            checkSpelling()
        }

        if keyCode == OpenKeyCode.d && index - 2 >= 0 && OpenKeyCode.isConsonant(chr(index - 2)) {
            tempDisableKey = false
        }
    }

    private func insertState(_ keyCode: UInt16, _ isCaps: Bool) {
        if stateIndex >= MAX_BUFF {
            for iii in 0..<(MAX_BUFF - 1) {
                keyStates[iii] = keyStates[iii + 1]
            }
            keyStates[stateIndex - 1] = UInt32(keyCode) | (isCaps ? OpenKeyMask.caps : 0)
        } else {
            keyStates[stateIndex] = UInt32(keyCode) | (isCaps ? OpenKeyMask.caps : 0)
            stateIndex += 1
        }
    }

    private func saveWord() {
        if hookState.code != .vReplaceMaro {
            if index > 0 {
                if !longWordHelper.isEmpty {
                    typingStatesData.removeAll()
                    for i in 0..<longWordHelper.count {
                        if i != 0 && i % MAX_BUFF == 0 {
                            typingStates.append(typingStatesData)
                            typingStatesData.removeAll()
                        }
                        typingStatesData.append(longWordHelper[i])
                    }
                    typingStates.append(typingStatesData)
                    longWordHelper.removeAll()
                }

                typingStatesData.removeAll()
                for i in 0..<index {
                    typingStatesData.append(typingWord[i])
                }
                typingStates.append(typingStatesData)
            }
        } else {
            typingStatesData.removeAll()
            for i in 0..<hookState.macroData.count {
                if i != 0 && i % MAX_BUFF == 0 {
                    typingStates.append(typingStatesData)
                    typingStatesData.removeAll()
                }
                typingStatesData.append(hookState.macroData[i])
            }
            typingStates.append(typingStatesData)
        }
    }

    private func saveWord(keyCode: UInt32, count: Int) {
        typingStatesData.removeAll()
        for _ in 0..<count {
            typingStatesData.append(keyCode)
        }
        typingStates.append(typingStatesData)
    }

    private func saveSpecialChar() {
        typingStatesData.removeAll()
        for i in 0..<specialChar.count {
            typingStatesData.append(specialChar[i])
        }
        typingStates.append(typingStatesData)
        specialChar.removeAll()
    }

    private func restoreLastTypingState() {
        if !typingStates.isEmpty {
            typingStatesData = typingStates.removeLast()
            if !typingStatesData.isEmpty {
                if typingStatesData[0] == UInt32(OpenKeyCode.space) {
                    spaceCount = typingStatesData.count
                    index = 0
                } else if charKeyCodes.contains(UInt16(typingStatesData[0] & OpenKeyMask.charMask)) {
                    index = 0
                    specialChar = typingStatesData
                    checkSpelling()
                } else {
                    for i in 0..<typingStatesData.count {
                        typingWord[i] = typingStatesData[i]
                    }
                    index = typingStatesData.count
                }
            }
        }
    }

    public func startNewSession() {
        index = 0
        hookState.backspaceCount = 0
        hookState.newCharCount = 0
        tempDisableKey = false
        stateIndex = 0
        hasHandledMacro = false
        hasHandleQuickConsonant = false
        longWordHelper.removeAll()
    }

    private func handleMainKey(_ data: UInt16, _ isCaps: Bool) {
        // Phím Z: Gỡ dấu thanh
        if isKeyZ(data) {
            removeMark()
            if !isChanged {
                insertKey(data, isCaps: isCaps)
            }
            return
        }

        if data == OpenKeyCode.leftBracket {
            if isBracketShortcutsEnabled {
                checkForStandaloneChar(data, isCaps, UInt32(OpenKeyCode.o))
                return
            }
        }

        if data == OpenKeyCode.rightBracket {
            if isBracketShortcutsEnabled {
                checkForStandaloneChar(data, isCaps, UInt32(OpenKeyCode.u))
                return
            }
        }

        // Phím D
        if isKeyD(data) {
            isCorrect = false
            isChanged = false
            var k = index
            for i in 0..<OpenKeyVietnameseData.consonantD.count {
                if index < OpenKeyVietnameseData.consonantD[i].count { continue }
                isCorrect = true
                checkCorrectVowel(OpenKeyVietnameseData.consonantD, i, &k, data)

                if !isCorrect && index - 2 >= 0 && chr(index - 1) == OpenKeyCode.d && OpenKeyCode.isConsonant(chr(index - 2)) {
                    isCorrect = true
                }
                if isCorrect {
                    isChanged = true
                    insertD(data, isCaps)
                    break
                }
            }
            if !isChanged {
                insertKey(data, isCaps: isCaps)
            }
            return
        }

        // Phím Dấu Thanh
        if isMarkKey(data) {
            for (_, charset) in OpenKeyVietnameseData.vowelForMark {
                isCorrect = false
                isChanged = false
                var k = index
                for l in 0..<charset.count {
                    if index < charset[l].count { continue }
                    isCorrect = true
                    checkCorrectVowel(charset, l, &k, data)

                    if isCorrect {
                        isChanged = true
                        if isKeyS(data) {
                            insertMark(OpenKeyMask.mark1)
                        } else if isKeyF(data) {
                            insertMark(OpenKeyMask.mark2)
                        } else if isKeyR(data) {
                            insertMark(OpenKeyMask.mark3)
                        } else if isKeyX(data) {
                            insertMark(OpenKeyMask.mark4)
                        } else if isKeyJ(data) {
                            insertMark(OpenKeyMask.mark5)
                        }
                        break
                    }
                }
                if isCorrect { break }
            }

            if !isChanged {
                insertKey(data, isCaps: isCaps)
            }
            return
        }

        // Kiểm tra nguyên âm
        var keyForAEO = data
        if vInputType == .vni {
            var vei = index - 1
            for i in stride(from: index - 1, through: 0, by: -1) {
                if chr(i) == OpenKeyCode.o || chr(i) == OpenKeyCode.a || chr(i) == OpenKeyCode.e {
                    vei = i
                    break
                }
            }
            keyForAEO = (data == OpenKeyCode.num7 || data == OpenKeyCode.num8) ? OpenKeyCode.w :
                        (data == OpenKeyCode.num6 ? chr(vei) : data)
        }

        if let charset = OpenKeyVietnameseData.vowel[keyForAEO] {
            isCorrect = false
            isChanged = false
            var k = index
            for i in 0..<charset.count {
                if index < charset[i].count { continue }
                isCorrect = true
                checkCorrectVowel(charset, i, &k, data)

                if isCorrect {
                    isChanged = true
                    if isKeyDouble(data) {
                        insertAOE(keyForAEO, isCaps)
                    } else if isKeyW(data) {
                        if vInputType == .vni {
                            var vei = index - 1
                            for j in stride(from: index - 1, through: 0, by: -1) {
                                let c = chr(j)
                                if c == OpenKeyCode.o || c == OpenKeyCode.u || c == OpenKeyCode.a || c == OpenKeyCode.e {
                                    vei = j
                                    break
                                }
                            }
                            let cVei = chr(vei)
                            if (data == OpenKeyCode.num7 && cVei == OpenKeyCode.a && (vei - 1 >= 0 ? chr(vei - 1) != OpenKeyCode.u : true)) ||
                               (data == OpenKeyCode.num8 && (cVei == OpenKeyCode.o || cVei == OpenKeyCode.u)) {
                                break
                            }
                        }
                        insertW(keyForAEO, isCaps)
                    }
                    break
                }
            }
        }

        if !isChanged {
            if data == OpenKeyCode.w && vInputType != .simpleTelex1 {
                if isWAtWordBeginningEnabled || index > 0 {
                    checkForStandaloneChar(data, isCaps, UInt32(OpenKeyCode.u))
                } else {
                    insertKey(data, isCaps: isCaps)
                }
            } else {
                insertKey(data, isCaps: isCaps)
            }
        }

        if (vQuickStartConsonant != 0 || vQuickEndConsonant != 0) && !tempDisableKey {
            checkQuickConsonant()
        }
    }

    private let quickStartConsonantMap: [UInt16: [UInt16]] = [
        OpenKeyCode.f: [OpenKeyCode.p, OpenKeyCode.h],
        OpenKeyCode.j: [OpenKeyCode.g, OpenKeyCode.i],
        OpenKeyCode.w: [OpenKeyCode.q, OpenKeyCode.u]
    ]

    private let quickEndConsonantMap: [UInt16: [UInt16]] = [
        OpenKeyCode.g: [OpenKeyCode.n, OpenKeyCode.g],
        OpenKeyCode.h: [OpenKeyCode.n, OpenKeyCode.h],
        OpenKeyCode.k: [OpenKeyCode.c, OpenKeyCode.h]
    ]

    @discardableResult
    public func checkQuickConsonant() -> Bool {
        if index <= 1 { return false }
        var modified = false

        let firstChar: UInt16 = {
            let ch = chr(0)
            if ch == OpenKeyCode.u && (typingWord[0] & OpenKeyMask.standalone) != 0 {
                return OpenKeyCode.w
            }
            return ch
        }()

        if vQuickStartConsonant != 0,
           let replacement = quickStartConsonantMap[firstChar],
           index >= 2,
           !OpenKeyCode.isConsonant(chr(1)) {
            let origCount = index
            let isFirstCaps = (typingWord[0] & OpenKeyMask.caps) != 0
            let isSecondCaps = (typingWord[1] & OpenKeyMask.caps) != 0

            if (firstChar == OpenKeyCode.j && chr(1) == OpenKeyCode.i) ||
               (firstChar == OpenKeyCode.w && chr(1) == OpenKeyCode.u) {
                typingWord[0] = UInt32(replacement[0]) | (isFirstCaps ? OpenKeyMask.caps : 0)
                typingWord[1] = UInt32(replacement[1]) | ((isFirstCaps && isSecondCaps) ? OpenKeyMask.caps : 0)
                hookState.code = .vWillProcess
                hookState.backspaceCount = UInt8(origCount - 1)
                hookState.newCharCount = 2
                hookState.charData[1] = getCharacterCode(typingWord[0])
                hookState.charData[0] = getCharacterCode(typingWord[1])
                modified = true
            } else {
                if index < MAX_BUFF - 1 {
                    index += 1
                }
                for i in stride(from: index - 1, through: 2, by: -1) {
                    typingWord[i] = typingWord[i - 1]
                }
                typingWord[1] = UInt32(replacement[1]) | ((isFirstCaps && isSecondCaps) ? OpenKeyMask.caps : 0)
                typingWord[0] = UInt32(replacement[0]) | (isFirstCaps ? OpenKeyMask.caps : 0)

                hookState.code = .vWillProcess
                hookState.backspaceCount = UInt8(origCount - 1)
                hookState.newCharCount = UInt8(index)
                for i in 0..<index {
                    hookState.charData[index - 1 - i] = getCharacterCode(typingWord[i])
                }
                modified = true
            }
        }

        if vQuickEndConsonant != 0,
           index >= 2,
           !OpenKeyCode.isConsonant(chr(index - 2)),
           let replacement = quickEndConsonantMap[chr(index - 1)] {
            let isLastCaps = (typingWord[index - 1] & OpenKeyMask.caps) != 0

            if index < MAX_BUFF - 1 {
                index += 1
            }
            typingWord[index - 1] = UInt32(replacement[1]) | (isLastCaps ? OpenKeyMask.caps : 0)
            typingWord[index - 2] = UInt32(replacement[0]) | (isLastCaps ? OpenKeyMask.caps : 0)

            hookState.code = .vWillProcess
            hookState.backspaceCount = 0
            hookState.newCharCount = 2
            hookState.charData[1] = getCharacterCode(typingWord[index - 2])
            hookState.charData[0] = getCharacterCode(typingWord[index - 1])
            modified = true
        }

        if modified {
            hasHandleQuickConsonant = true
            return true
        }
        return false
    }

    // MARK: - Vòng Lặp Xử Lý Sự Kiện Chính (vKeyHandleEvent - L1314)
    public func handleEvent(
        event: OpenKeyEvent,
        state: OpenKeyEventState,
        data: UInt16,
        capsStatus: UInt8 = 0,
        otherControlKey: Bool = false
    ) {
        isCaps = (capsStatus == 1 || capsStatus == 2)

        if (OpenKeyCode.isNumberKey(data) && capsStatus == 1) ||
            otherControlKey || isWordBreak(event, state, data) || (index == 0 && OpenKeyCode.isNumberKey(data)) {

            hookState.code = .vDoNothing
            hookState.backspaceCount = 0
            hookState.newCharCount = 0
            hookState.extCode = 1 // Word break

            // Kiểm tra Macro
            if vUseMacro != 0 && isMacroBreakCode(data) && !hasHandledMacro,
               let macroContent = macroManager.findMacro(key: hookState.macroKey, autoCaps: vAutoCapsMacro != 0) {
                hookState.code = .vReplaceMaro
                hookState.backspaceCount = UInt8(hookState.macroKey.count)
                hookState.macroData = macroContent
                hasHandledMacro = true
            } else if vRestoreIfWrongSpelling != 0 && isWordBreak(event, state, data) {
                if !tempDisableKey && vCheckSpelling != 0 {
                    checkSpelling(forceCheckVowel: true)
                }
                if tempDisableKey && !checkRestoreIfWrongSpelling(handleCode: .vRestoreAndStartNewSession) {
                    hookState.code = .vDoNothing
                }
            }

            isCharKeyCode = (state == .keyDown && charKeyCodes.contains(data))
            if !isCharKeyCode {
                specialChar.removeAll()
                typingStates.removeAll()
            } else {
                if spaceCount > 0 {
                    saveWord(keyCode: UInt32(OpenKeyCode.space), count: spaceCount)
                    spaceCount = 0
                } else {
                    saveWord()
                }
                specialChar.append(UInt32(data) | (isCaps ? OpenKeyMask.caps : 0))
                hookState.extCode = 3
            }

            if hookState.code == .vDoNothing {
                startNewSession()
                vCheckSpelling = useSpellCheckingBefore
                willTempOffEngine = false
            } else if hookState.code == .vReplaceMaro || hasHandleQuickConsonant {
                index = 0
            }

            if vUseMacro != 0 {
                if isCharKeyCode {
                    hookState.macroKey.append(UInt32(data) | (isCaps ? OpenKeyMask.caps : 0))
                } else {
                    hookState.macroKey.removeAll()
                }
            }

            if vUpperCaseFirstChar != 0 {
                if data == OpenKeyCode.dot {
                    upperCaseStatus = 1
                } else if data == OpenKeyCode.enter || data == OpenKeyCode.return {
                    upperCaseStatus = 2
                } else {
                    upperCaseStatus = 0
                }
            }
        } else if data == OpenKeyCode.space {
            if !tempDisableKey && vCheckSpelling != 0 {
                checkSpelling(forceCheckVowel: true)
            }
            if vUseMacro != 0 && !hasHandledMacro,
               let macroContent = macroManager.findMacro(key: hookState.macroKey, autoCaps: vAutoCapsMacro != 0) {
                hookState.code = .vReplaceMaro
                hookState.backspaceCount = UInt8(hookState.macroKey.count)
                hookState.macroData = macroContent
                spaceCount += 1
                hasHandledMacro = true
            } else if vRestoreIfWrongSpelling != 0 && tempDisableKey && !hasHandledMacro {
                if !checkRestoreIfWrongSpelling(handleCode: .vRestore) {
                    hookState.code = .vDoNothing
                }
                spaceCount += 1
            } else {
                hookState.code = .vDoNothing
                spaceCount += 1
            }

            if vUseMacro != 0 {
                hookState.macroKey.removeAll()
            }
            if vUpperCaseFirstChar != 0 && upperCaseStatus == 1 {
                upperCaseStatus = 2
            }
            if spaceCount == 1 {
                if !specialChar.isEmpty {
                    saveSpecialChar()
                } else {
                    saveWord()
                }
            }
            vCheckSpelling = useSpellCheckingBefore
            willTempOffEngine = false
        } else if data == OpenKeyCode.delete {
            hookState.code = .vDoNothing
            hookState.extCode = 2

            if !specialChar.isEmpty {
                specialChar.removeLast()
                if specialChar.isEmpty {
                    restoreLastTypingState()
                }
            } else if spaceCount > 0 {
                spaceCount -= 1
                if spaceCount == 0 {
                    restoreLastTypingState()
                }
            } else {
                if stateIndex > 0 { stateIndex -= 1 }
                if index > 0 {
                    index -= 1
                    if !longWordHelper.isEmpty {
                        for i in stride(from: MAX_BUFF - 1, through: 1, by: -1) {
                            typingWord[i] = typingWord[i - 1]
                        }
                        typingWord[0] = longWordHelper.removeLast()
                        index += 1
                    }
                    if vCheckSpelling != 0 {
                        checkSpelling()
                    }
                }
                if vUseMacro != 0 && !hookState.macroKey.isEmpty {
                    hookState.macroKey.removeLast()
                }

                hookState.backspaceCount = 0
                hookState.newCharCount = 0
                hookState.extCode = 2
                if index == 0 {
                    startNewSession()
                    specialChar.removeAll()
                    restoreLastTypingState()
                } else {
                    checkGrammar(deltaBackSpace: 1)
                }
            }
        } else { // XỬ LÝ PHÍM CHỮ
            if willTempOffEngine {
                hookState.code = .vDoNothing
                hookState.extCode = 3
                return
            }
            if spaceCount > 0 {
                hookState.backspaceCount = 0
                hookState.newCharCount = 0
                hookState.extCode = 0
                startNewSession()
                saveWord(keyCode: UInt32(OpenKeyCode.space), count: spaceCount)
                spaceCount = 0
            } else if !specialChar.isEmpty {
                saveSpecialChar()
            }

            hasHandleQuickConsonant = false
            insertState(data, isCaps)

            if !isSpecialKey(data) || tempDisableKey {
                if vQuickTelex != 0 && isQuickTelexKey(data) {
                    handleQuickTelex(data, isCaps)
                    return
                } else {
                    hookState.code = .vDoNothing
                    hookState.backspaceCount = 0
                    hookState.newCharCount = 0
                    insertKey(data, isCaps: isCaps)
                    if (vQuickStartConsonant != 0 || vQuickEndConsonant != 0) && !tempDisableKey {
                        checkQuickConsonant()
                    }
                }
            } else {
                hookState.code = .vDoNothing
                hookState.extCode = 3
                handleMainKey(data, isCaps)
            }

            if vFreeMark == 0 && !isKeyD(data) {
                if hookState.code == .vDoNothing || hasHandleQuickConsonant {
                    checkGrammar(deltaBackSpace: -1)
                } else {
                    checkGrammar(deltaBackSpace: 0)
                }
            }

            if hookState.code == .vRestore {
                insertKey(data, isCaps: isCaps)
                if stateIndex > 0 { stateIndex -= 1 }
            }

            if vUseMacro != 0 {
                if hookState.code == .vDoNothing {
                    hookState.macroKey.append(UInt32(data) | (isCaps ? OpenKeyMask.caps : 0))
                } else if hookState.code == .vWillProcess || hookState.code == .vRestore {
                    let bpc = Int(hookState.backspaceCount)
                    for _ in 0..<bpc {
                        if !hookState.macroKey.isEmpty {
                            hookState.macroKey.removeLast()
                        }
                    }
                    let start = index - bpc
                    let end = Int(hookState.newCharCount) + start
                    if start >= 0 && end <= index {
                        for i in start..<end {
                            hookState.macroKey.append(typingWord[i])
                        }
                    }
                }
            }

            // Xử lý viết hoa chữ cái đầu câu
            if vUpperCaseFirstChar != 0 && index == 1 && upperCaseStatus == 2 {
                if (typingWord[0] & OpenKeyMask.caps) == 0 {
                    hookState.code = .vWillProcess
                    hookState.backspaceCount = 0
                    hookState.newCharCount = 1
                    typingWord[0] |= OpenKeyMask.caps
                    hookState.charData[0] = getCharacterCode(typingWord[0])
                    upperCaseStatus = 0
                    if vUseMacro != 0 && !hookState.macroKey.isEmpty {
                        hookState.macroKey[0] |= OpenKeyMask.caps
                    }
                }
                upperCaseStatus = 0
            }
        }
    }
}
