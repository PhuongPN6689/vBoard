//
//  OpenKeyPermutationTests.swift
//  vBoardEngineTests
//
//  Bộ kiểm thử ma trận tổ hợp toàn diện các phong cách gõ tiếng Việt (Telex & VNI).
//  Đánh giá độ phủ và độ chính xác của OpenKeyEngine trên các cấu trúc âm tiết thực tế.
//

import Testing
import Foundation
@testable import vBoardEngine

/// Công cụ phân tích âm tiết và sinh các tổ hợp chuỗi gõ tiếng Việt
struct KeystrokePermutationGenerator {

    /// Mô hình phân rã một từ tiếng Việt
    struct WordStructure {
        let original: String
        let initialConsonant: String       // e.g. "th", "qu", "gi", "đ", "ngh"
        let isInitialD: Bool               // Có phải âm đ/Đ
        let vowels: [(base: Character, shape: VowelShape, tone: ToneMark)]
        let finalConsonant: String         // e.g. "ng", "c", "nh", ""
        let tone: ToneMark                 // Dấu thanh tổng thể của từ
    }

    /// Phân rã từ tiếng Việt thành cấu trúc âm tiết
    static func analyzeWord(_ word: String) -> WordStructure? {
        guard !word.isEmpty else { return nil }

        var initial = ""
        var vowelList: [(base: Character, shape: VowelShape, tone: ToneMark)] = []
        var final = ""
        var detectedTone: ToneMark = .none
        var isD = false

        let chars = Array(word)
        var i = 0

        // 1. Phụ âm đầu
        while i < chars.count {
            let ch = chars[i]
            let lower = Character(ch.lowercased())
            if lower == "đ" {
                isD = true
                initial.append("d")
                i += 1
                break
            }

            if VietnameseChar.decompose(ch) != nil {
                // Đã chạm vào nguyên âm
                break
            } else if "bcdfghjklmnpqrstvwxz".contains(lower) {
                initial.append(lower)
                i += 1
            } else {
                break
            }
        }

        // 2. Cụm nguyên âm
        while i < chars.count {
            let ch = chars[i]
            if let decomp = VietnameseChar.decompose(ch) {
                if decomp.tone != .none {
                    detectedTone = decomp.tone
                }
                vowelList.append((decomp.base, decomp.shape, decomp.tone))
                i += 1
            } else {
                break
            }
        }

        // 3. Phụ âm cuối
        while i < chars.count {
            let ch = chars[i]
            final.append(Character(ch.lowercased()))
            i += 1
        }

        guard !vowelList.isEmpty else { return nil }

        return WordStructure(
            original: word,
            initialConsonant: initial,
            isInitialD: isD,
            vowels: vowelList,
            finalConsonant: final,
            tone: detectedTone
        )
    }

    /// Ánh xạ dấu thanh sang phím Telex
    static func toneToTelex(_ tone: ToneMark) -> String {
        switch tone {
        case .none: return ""
        case .acute: return "s"
        case .grave: return "f"
        case .hook: return "r"
        case .tilde: return "x"
        case .dot: return "j"
        }
    }

    /// Ánh xạ dấu thanh sang phím VNI
    static func toneToVNI(_ tone: ToneMark) -> String {
        switch tone {
        case .none: return ""
        case .acute: return "1"
        case .grave: return "2"
        case .hook: return "3"
        case .tilde: return "4"
        case .dot: return "5"
        }
    }

    /// Ánh xạ hình dạng nguyên âm sang phím Telex
    static func shapeToTelex(_ base: Character, _ shape: VowelShape) -> String {
        switch shape {
        case .plain: return ""
        case .circumflex:
            return String(base) // e.g. a->a (aa), e->e (ee), o->o (oo)
        case .breve:
            return "w"          // a + w -> ă
        case .horn:
            return "w"          // o + w -> ơ, u + w -> ư
        }
    }

    /// Ánh xạ hình dạng nguyên âm sang phím VNI
    static func shapeToVNI(_ base: Character, _ shape: VowelShape) -> String {
        switch shape {
        case .plain: return ""
        case .circumflex: return "6"  // â, ê, ô
        case .breve: return "8"       // ă
        case .horn: return "7"        // ơ, ư
        }
    }

    /// Sinh các tổ hợp gõ Telex khác nhau cho cùng một từ tiếng Việt
    static func generateTelexPermutations(for word: String) -> [String] {
        guard let s = analyzeWord(word) else { return [word] }

        var permutations: [String] = []
        var seen = Set<String>()
        func addPerm(_ str: String) {
            if !seen.contains(str) {
                seen.insert(str)
                permutations.append(str)
            }
        }

        let toneStr = toneToTelex(s.tone)
        let initStr = s.isInitialD ? "dd" : s.initialConsonant
        let baseVowelStr = String(s.vowels.map { $0.base })

        // =========================================================================
        // PHONG CÁCH 1: Gõ Telex Chuẩn (Immediate Diacritic, Deferred Tone ở cuối)
        // Ví dụ: tiếng -> t - i - e - e - n - g - s
        // =========================================================================
        var style1 = initStr
        // Xử lý cụm uo có móc (ươ)
        if baseVowelStr == "uo" && s.vowels[0].shape == .horn && s.vowels[1].shape == .horn {
            style1 += "uow"
        } else {
            for v in s.vowels {
                style1.append(v.base)
                style1.append(shapeToTelex(v.base, v.shape))
            }
        }
        style1 += s.finalConsonant
        style1 += toneStr
        addPerm(style1)

        // =========================================================================
        // PHONG CÁCH 2: Gõ Dấu Thanh Ngay Sau Nguyên Âm (Immediate Tone)
        // Ví dụ: tiếng -> t - i - e - e - s - n - g
        // =========================================================================
        if !s.finalConsonant.isEmpty && !toneStr.isEmpty {
            var style2 = initStr
            if baseVowelStr == "uo" && s.vowels[0].shape == .horn && s.vowels[1].shape == .horn {
                style2 += "uow"
            } else {
                for v in s.vowels {
                    style2.append(v.base)
                    style2.append(shapeToTelex(v.base, v.shape))
                }
            }
            style2 += toneStr
            style2 += s.finalConsonant
            addPerm(style2)
        }

        // =========================================================================
        // PHONG CÁCH 3: Các biến thể của cụm nguyên âm móc kép ươ
        // Ví dụ: thương -> thuowng, thuwong, thuongw
        // =========================================================================
        if baseVowelStr == "uo" && s.vowels[0].shape == .horn && s.vowels[1].shape == .horn {
            // Biến thể 3a: w ngay sau u (thuwong)
            addPerm(initStr + "uwo" + s.finalConsonant + toneStr)
            // Biến thể 3b: w lặp sau từng âm (thuwowng)
            addPerm(initStr + "uwow" + s.finalConsonant + toneStr)
            // Biến thể 3c: w dồn về cuối từ (thuongw)
            if !s.finalConsonant.isEmpty {
                addPerm(initStr + "uo" + s.finalConsonant + "w" + toneStr)
            }
        }

        // =========================================================================
        // PHONG CÁCH 4: Đảo thứ tự Thanh trước, Mũ/Móc sau (Tone before Diacritic)
        // Ví dụ: ế -> e - s - e; ấ -> a - s - a; ố -> o - s - o; ắ -> a - s - w
        // =========================================================================
        if s.vowels.count == 1 && s.vowels[0].shape != .plain && !toneStr.isEmpty {
            let v = s.vowels[0]
            let diacritic = shapeToTelex(v.base, v.shape)
            let style4 = initStr + String(v.base) + toneStr + diacritic + s.finalConsonant
            addPerm(style4)
        }

        // =========================================================================
        // PHONG CÁCH 5: Dấu đ ở cuối từ (d thô đầu từ, d biến đổi ở cuối)
        // Ví dụ: được -> d - u - o - w - c - d - j hoặc đi -> d - i - d
        // =========================================================================
        if s.isInitialD {
            var vPart = ""
            if baseVowelStr == "uo" && s.vowels[0].shape == .horn && s.vowels[1].shape == .horn {
                vPart = "uow"
            } else {
                for v in s.vowels {
                    vPart.append(v.base)
                    vPart.append(shapeToTelex(v.base, v.shape))
                }
            }
            addPerm("d" + vPart + s.finalConsonant + "d" + toneStr)
        }

        // =========================================================================
        // PHONG CÁCH 6: Gõ trễ Mũ/Móc sau phụ âm cuối (Delayed Hat & Mark)
        // Ví dụ: một -> m-o-t-o-j hoặc m-o-t-j-o; việt -> v-i-e-t-e-j
        // =========================================================================
        if !s.finalConsonant.isEmpty {
            // Trường hợp từ có mũ (â, ê, ô) hoặc móc (ă):
            if s.vowels.count == 1 {
                let v = s.vowels[0]
                if v.shape == .circumflex || v.shape == .breve {
                    let rawWord = initStr + String(v.base) + s.finalConsonant
                    let hatKey = shapeToTelex(v.base, v.shape)
                    if !hatKey.isEmpty {
                        // 6a: [raw] + [hat] + [tone] (ví dụ: motoj -> một, bepes -> bếp)
                        addPerm(rawWord + hatKey + toneStr)
                        // 6b: [raw] + [tone] + [hat] (ví dụ: motjo -> một, bepse -> bếp)
                        if !toneStr.isEmpty {
                            addPerm(rawWord + toneStr + hatKey)
                        }
                    }
                }
            } else if s.vowels.count == 2 {
                // Ví dụ: tiếng (t-i-e-n-g-e-s), việt (v-i-e-t-e-j)
                let v0 = s.vowels[0]
                let v1 = s.vowels[1]
                if v0.base == "i" && v1.shape == .circumflex && v1.base == "e" {
                    let rawWord = initStr + "ie" + s.finalConsonant
                    addPerm(rawWord + "e" + toneStr)
                    if !toneStr.isEmpty {
                        addPerm(rawWord + toneStr + "e")
                    }
                }
            }
        }

        return permutations
    }

    /// Sinh các tổ hợp gõ VNI cho cùng một từ tiếng Việt
    static func generateVNIPermutations(for word: String) -> [String] {
        guard let s = analyzeWord(word) else { return [word] }

        var permutations = Set<String>()
        let toneStr = toneToVNI(s.tone)
        let initStr = s.isInitialD ? "d9" : s.initialConsonant
        let baseVowelStr = String(s.vowels.map { $0.base })

        // 1. VNI chuẩn: số mũ/móc ngay sau nguyên âm, dấu thanh ở cuối
        var style1 = initStr
        if baseVowelStr == "uo" && s.vowels[0].shape == .horn && s.vowels[1].shape == .horn {
            style1 += "u7o7"
        } else {
            for v in s.vowels {
                style1.append(v.base)
                style1.append(shapeToVNI(v.base, v.shape))
            }
        }
        style1 += s.finalConsonant
        style1 += toneStr
        permutations.insert(style1)

        // 2. VNI dấu thanh ngay sau nguyên âm
        if !s.finalConsonant.isEmpty && !toneStr.isEmpty {
            var style2 = initStr
            if baseVowelStr == "uo" && s.vowels[0].shape == .horn && s.vowels[1].shape == .horn {
                style2 += "u7o7"
            } else {
                for v in s.vowels {
                    style2.append(v.base)
                    style2.append(shapeToVNI(v.base, v.shape))
                }
            }
            style2 += toneStr
            style2 += s.finalConsonant
            permutations.insert(style2)
        }

        return Array(permutations)
    }
}

// MARK: - Bộ Kiểm Thử Ma Trận Đa Phong Cách Gõ
@Suite("Bộ kiểm thử Ma trận Tổ hợp Phong cách gõ Tiếng Việt Toàn diện")
struct OpenKeyPermutationTests {

    /// Tiện ích gõ chuỗi qua adapter
    private func typeString(_ str: String, adapter: OpenKeyEngineAdapter) -> String {
        adapter.reset()
        var buffer = ""
        for char in str {
            let action = adapter.processKeystroke(char, contextBefore: buffer)
            if action.deleteCount > 0 {
                let deleteCount = min(buffer.count, action.deleteCount)
                let startIndex = buffer.index(buffer.endIndex, offsetBy: -deleteCount)
                buffer.removeSubrange(startIndex..<buffer.endIndex)
            }
            buffer += action.textToInsert
        }
        return buffer
    }

    @Test("Kiểm tra phân tích cấu trúc âm tiết tiếng Việt tự động")
    func testWordStructureAnalysis() {
        let sample = "tiếng"
        let structure = KeystrokePermutationGenerator.analyzeWord(sample)
        #expect(structure != nil)
        #expect(structure?.initialConsonant == "t")
        #expect(structure?.vowels.count == 2)
        #expect(structure?.vowels[1].shape == .circumflex) // e -> ê
        #expect(structure?.finalConsonant == "ng")
        #expect(structure?.tone == .acute) // sắc
    }

    @Test("Kiểm tra toàn diện các tổ hợp gõ Telex phong phú cho cụm từ chứa ươ (thương, được, nước, người)")
    func testUoPermutationsTelex() {
        let adapter = OpenKeyEngineAdapter()
        adapter.engine.vInputType = .telex

        let testWords = ["thương", "được", "nước", "người", "bước", "mượn"]

        for word in testWords {
            let permutations = KeystrokePermutationGenerator.generateTelexPermutations(for: word)
            for seq in permutations {
                let result = typeString(seq, adapter: adapter)
                #expect(result == word, "Tổ hợp gõ '\(seq)' kỳ vọng ra '\(word)', nhưng thực tế ra '\(result)'")
            }
        }
    }

    @Test("Kiểm tra tổ hợp gõ thanh trước mũ sau (Reverse Tone-Diacritic Order)")
    func testReverseToneDiacriticOrder() {
        let adapter = OpenKeyEngineAdapter()
        adapter.engine.vInputType = .telex

        let testCases: [(input: String, expected: String)] = [
            ("ese", "ế"),
            ("efe", "ề"),
            ("ere", "ể"),
            ("exe", "ễ"),
            ("eje", "ệ"),
            ("asa", "ấ"),
            ("afa", "ầ"),
            ("ara", "ẩ"),
            ("axa", "ẫ"),
            ("aja", "ậ"),
            ("oso", "ố"),
            ("ofo", "ồ"),
            ("oro", "ổ"),
            ("oxo", "ỗ"),
            ("ojo", "ộ"),
            ("asw", "ắ"),
            ("afw", "ằ"),
            ("arw", "ẳ"),
            ("axw", "ẵ"),
            ("ajw", "ặ")
        ]

        for test in testCases {
            let result = typeString(test.input, adapter: adapter)
            #expect(result == test.expected, "Gõ ngược thanh-mũ: '\(test.input)' kỳ vọng '\(test.expected)', thực tế '\(result)'")
        }
    }

    @Test("Kiểm tra gõ dấu thanh ngay sau nguyên âm (Immediate Tone)")
    func testImmediateTonePlacement() {
        let adapter = OpenKeyEngineAdapter()
        adapter.engine.vInputType = .telex

        let testCases: [(input: String, expected: String)] = [
            ("toasn", "toán"),
            ("toafn", "toàn"),
            ("toarn", "toản"),
            ("toaxn", "toãn"),
            ("toajn", "toạn"),
            ("tieesng", "tiếng"),
            ("tieefng", "tiềng"),
            ("vieejt", "việt"),
            ("bieest", "biết"),
            ("chieens", "chiến"),
            ("muoosn", "muốn"),
            ("baats", "bất"),
            ("caasp", "cấp")
        ]

        for test in testCases {
            let result = typeString(test.input, adapter: adapter)
            #expect(result == test.expected, "Dấu thanh ngay sau nguyên âm: '\(test.input)' kỳ vọng '\(test.expected)', thực tế '\(result)'")
        }
    }

    @Test("Kiểm tra gõ trễ ký tự Đ ở cuối từ (Deferred D)")
    func testDeferredDKey() {
        let adapter = OpenKeyEngineAdapter()
        adapter.engine.vInputType = .telex

        let testCases: [(input: String, expected: String)] = [
            ("did", "đi"),
            ("dad", "đa"),
            ("duowcdj", "được"),
            ("duowngdf", "đường"),
            ("daud", "đau")
        ]

        for test in testCases {
            let result = typeString(test.input, adapter: adapter)
            #expect(result == test.expected, "Phím D ở cuối từ: '\(test.input)' kỳ vọng '\(test.expected)', thực tế '\(result)'")
        }
    }

    @Test("Kiểm tra toàn diện 12 nhóm âm tiết tiếng Việt thực tế với hàng trăm tổ hợp gõ")
    func testTwelveVietnamesePhonologicalCategories() {
        let adapter = OpenKeyEngineAdapter()
        adapter.engine.vInputType = .telex
        adapter.engine.vUseModernOrthography = 1 // Kiểu 1: thuỷ, tuỳ, hoà

        let categoryWords: [String: [String]] = [
            "1. Nguyên âm đơn & thanh cơ bản": ["má", "cà", "lá", "bà", "cá", "tạ", "mẹ", "bé", "bố"],
            "2. Âm có đ/Đ": ["đi", "được", "đã", "đang", "đầu", "đến", "đất", "đoàn", "đẹp"],
            "3. Âm có mũ (â, ê, ô)": ["tôi", "không", "lên", "một", "trên", "nên", "về", "sân"],
            "4. Âm có móc (ă, ơ, ư)": ["ăn", "nhưng", "năm", "mắt", "mặt", "tắm", "cắt", "chặt"],
            "5. Cụm ươ": ["người", "nước", "trước", "thương", "trường", "bước", "mượn", "vườn"],
            "6. Cụm uô": ["muốn", "cuộc", "buồn", "luôn", "xuống", "nguồn", "ruộng", "thuộc"],
            "7. Cụm iê/yê": ["tiếng", "việc", "biết", "nhiều", "riêng", "chuyện", "yêu", "tiền"],
            "8. Cụm qu": ["qua", "quá", "quả", "quan", "quốc", "quyết", "quyền", "quanh", "quần"],
            "9. Cụm gi": ["giờ", "giữ", "giúp", "giữa", "giá", "giáo", "giấy", "giống", "gìn"],
            "10. Cụm uy/uya/uye": ["thuỷ", "tuỳ", "khuya", "chuyến", "thuyền", "khuyên", "duyệt"],
            "11. Nguyên âm ba oai/uyu/oeo": ["loại", "ngoài", "khoai", "khuỷu", "ngoẹo", "thoải"],
            "12. Âm trắc kết thúc c/ch/p/t": ["rất", "thật", "xuất", "sách", "sạch", "hát", "hạt"]
        ]

        var totalTested = 0
        var totalPermutations = 0
        var failureLog: [String] = []

        for (_, words) in categoryWords {
            for word in words {
                totalTested += 1
                let permutations = KeystrokePermutationGenerator.generateTelexPermutations(for: word)
                for seq in permutations {
                    totalPermutations += 1
                    let result = typeString(seq, adapter: adapter)
                    if result != word {
                        failureLog.append("Từ gốc: '\(word)' -> Gõ chuỗi '\(seq)' ra '\(result)'")
                    }
                }
            }
        }

        if !failureLog.isEmpty {
            print("\n❌ CÁC TỔ HỢP GÕ BỊ SAI (\(failureLog.count)/\(totalPermutations)):")
            for f in failureLog.prefix(20) {
                print("  - \(f)")
            }
        }

        print("\n📊 BÁO CÁO ĐỘ PHỦ MA TRẬN 12 NHÓM ÂM TIẾT:")
        print("  - Tổng số từ vựng đại diện: \(totalTested) từ")
        print("  - Tổng số chuỗi tổ hợp gõ đã kiểm định: \(totalPermutations) chuỗi")
        print("  - Tỷ lệ chính xác: \(String(format: "%.2f", Double(totalPermutations - failureLog.count) / Double(totalPermutations) * 100))%")

        #expect(failureLog.isEmpty, "Tất cả tổ hợp gõ hợp lệ phải cho ra từ tiếng Việt chính xác 100%")
    }

    @Test("Kiểm tra ma trận tổ hợp gõ theo phương pháp VNI")
    func testVNIPermutationsMatrix() {
        let adapter = OpenKeyEngineAdapter()
        adapter.engine.vInputType = .vni
        adapter.engine.vUseModernOrthography = 1

        let testWords = ["tiếng", "việt", "nam", "được", "người", "toán", "thuỷ", "hoà"]

        for word in testWords {
            let permutations = KeystrokePermutationGenerator.generateVNIPermutations(for: word)
            for seq in permutations {
                let result = typeString(seq, adapter: adapter)
                #expect(result == word, "VNI: Gõ '\(seq)' kỳ vọng '\(word)', thực tế '\(result)'")
            }
        }
    }

    @Test("Kiểm tra bộ từ điển thực tế vietnamese_words.txt (Top 200 từ thông dụng nhất)")
    func testTopHighFrequencyWordsFromDictionary() {
        guard let url = Bundle.module.url(forResource: "vietnamese_words", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            #expect(Bool(false), "Không tìm thấy file vietnamese_words.txt")
            return
        }

        let lines = content.components(separatedBy: .newlines)
        var testedWords = 0
        var totalSequences = 0
        var failedCases: [String] = []

        let adapter = OpenKeyEngineAdapter()
        adapter.engine.vInputType = .telex

        for line in lines {
            let parts = line.split(separator: ",")
            guard let first = parts.first else { continue }
            let word = String(first).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty, !word.contains(" ") else { continue }

            testedWords += 1
            if testedWords > 200 { break }

            let permutations = KeystrokePermutationGenerator.generateTelexPermutations(for: word)
            for seq in permutations {
                totalSequences += 1
                let result = typeString(seq, adapter: adapter)
                if result != word {
                    // Thử với kiểu dấu thay thế nếu từ thuộc cụm âm đệm oa/oe/uy
                    adapter.engine.vUseModernOrthography = 0
                    let resultAlt = typeString(seq, adapter: adapter)
                    adapter.engine.vUseModernOrthography = 1
                    if resultAlt != word {
                        failedCases.append("Từ gốc: '\(word)' -> Gõ '\(seq)' ra '\(result)'")
                    }
                }
            }
        }

        print("\n📊 BÁO CÁO ĐỘ PHỦ TỪ ĐIỂN THỰC TẾ (TOP 200 TỪ CAO TẦN):")
        print("  - Tổng số từ kiểm thử: \(testedWords) từ")
        print("  - Tổng số chuỗi tổ hợp gõ: \(totalSequences) chuỗi")
        print("  - Tỷ lệ chính xác: \(String(format: "%.2f", Double(totalSequences - failedCases.count) / Double(totalSequences) * 100))%")

        if !failedCases.isEmpty {
            print("\n❌ CÁC TỪ GÕ TỪ ĐIỂN BỊ SAI (\(failedCases.count)/\(totalSequences)):")
            for f in failedCases.prefix(10) {
                print("  - \(f)")
            }
        }

        #expect(failedCases.isEmpty, "Top 200 từ ngữ thông dụng nhất phải gõ chính xác 100%")
    }
}

