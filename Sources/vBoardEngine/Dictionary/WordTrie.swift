import Foundation

/// Node trong cây tiền tố (Trie) cho từ điển tiếng Việt
public final class WordTrieNode: @unchecked Sendable {
    public var children: [Character: WordTrieNode] = [:]
    public var word: String?
    public var asciiWord: String?
    public var frequency: Int = 0
    public var topCandidates: [(word: String, ascii: String, freq: Int)] = []

    public init() {}

    public func updateTopCandidate(word: String, ascii: String, frequency: Int, maxCapacity: Int = 30) {
        let lowWord = word.lowercased()
        if let idx = topCandidates.firstIndex(where: { $0.word.lowercased() == lowWord }) {
            if frequency > topCandidates[idx].freq {
                topCandidates[idx].freq = frequency
                topCandidates.sort { $0.freq > $1.freq }
            }
            return
        }
        if topCandidates.count >= maxCapacity, let lastFreq = topCandidates.last?.freq, frequency <= lastFreq {
            return
        }
        topCandidates.append((word: word, ascii: ascii, freq: frequency))
        topCandidates.sort { $0.freq > $1.freq }
        if topCandidates.count > maxCapacity {
            topCandidates.removeLast()
        }
    }
}

/// Cây từ điển tiếng Việt nén siêu nhẹ, tra cứu tiền tố O(k) trong < 0.005ms
public final class WordTrie: @unchecked Sendable {
    public static let shared = WordTrie()

    private let root = WordTrieNode()
    private let unaccentedRoot = WordTrieNode()
    private var isLoaded: Bool = false
    private let lock = NSLock()
    public private(set) var totalWordsCount: Int = 0

    public init() {
        loadCommonVietnameseWords()
    }

    private struct GlideBucketKey: Hashable {
        let first: Character
        let last: Character
    }

    private struct GlideWordEntry: Sendable {
        let word: String
        let asciiChars: [Character]
        let frequency: Int
        let length: Int
    }

    private var glideBuckets: [GlideBucketKey: [GlideWordEntry]] = [:]

    /// Loại bỏ dấu tiếng Việt chuyển thành ký tự ASCII thuần (để so khớp quỹ đạo vuốt và gợi ý mềm)
    public static func stripDiacritics(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for ch in text {
            switch ch {
            case "a", "á", "à", "ả", "ã", "ạ",
                 "ă", "ắ", "ằ", "ẳ", "ẵ", "ặ",
                 "â", "ấ", "ầ", "ẩ", "ẫ", "ậ",
                 "A", "Á", "À", "Ả", "Ã", "Ạ",
                 "Ă", "Ắ", "Ằ", "Ẳ", "Ẵ", "Ặ",
                 "Â", "Ấ", "Ầ", "Ẩ", "Ẫ", "Ậ":
                result.append("a")
            case "e", "é", "è", "ẻ", "ẽ", "ẹ",
                 "ê", "ế", "ề", "ể", "ễ", "ệ",
                 "E", "É", "È", "Ẻ", "Ẽ", "Ẹ",
                 "Ê", "Ế", "Ề", "Ể", "Ễ", "Ệ":
                result.append("e")
            case "i", "í", "ì", "ỉ", "ĩ", "ị",
                 "I", "Í", "Ì", "Ỉ", "Ĩ", "Ị":
                result.append("i")
            case "o", "ó", "ò", "ỏ", "õ", "ọ",
                 "ô", "ố", "ồ", "ổ", "ỗ", "ộ",
                 "ơ", "ớ", "ờ", "ở", "ỡ", "ợ",
                 "O", "Ó", "Ò", "Ỏ", "Õ", "Ọ",
                 "Ô", "Ố", "Ồ", "Ổ", "Ỗ", "Ộ",
                 "Ơ", "Ớ", "Ờ", "Ở", "Ỡ", "Ợ":
                result.append("o")
            case "u", "ú", "ù", "ủ", "ũ", "ụ",
                 "ư", "ứ", "ừ", "ử", "ữ", "ự",
                 "U", "Ú", "Ù", "Ủ", "Ũ", "Ụ",
                 "Ư", "Ứ", "Ừ", "Ử", "Ữ", "Ự":
                result.append("u")
            case "y", "ý", "ỳ", "ỷ", "ỹ", "ỵ",
                 "Y", "Ý", "Ỳ", "Ỷ", "Ỹ", "Ỵ":
                result.append("y")
            case "d", "đ", "D", "Đ":
                result.append("d")
            case "A"..."Z":
                result.append(ch.lowercased())
            default:
                result.append(ch)
            }
        }
        return result
    }

    /// Tải lại từ điển từ file hoặc reset
    public func reloadLexicon(fromFilePath customPath: String? = nil) {
        lock.lock()
        defer { lock.unlock() }
        root.children.removeAll()
        unaccentedRoot.children.removeAll()
        glideBuckets.removeAll()
        totalWordsCount = 0
        isLoaded = false
        NextWordPredictor.shared.resetLexiconPhrases()
        _ = loadFromLexiconFile(customFilePath: customPath)
    }

    /// Chèn một từ vào cây Trie kèm mức độ phổ biến (frequency càng cao càng ưu tiên)
    public func insert(word: String, frequency: Int = 1) {
        let lower = word.lowercased()
        let ascii = WordTrie.stripDiacritics(word)

        // 1. Chèn vào cây có dấu chính xác
        var current = root
        for char in lower {
            if let next = current.children[char] {
                current = next
            } else {
                let newNode = WordTrieNode()
                current.children[char] = newNode
                current = newNode
            }
            current.updateTopCandidate(word: word, ascii: ascii, frequency: frequency, maxCapacity: 30)
        }
        if current.word == nil {
            totalWordsCount += 1
        }
        current.word = word
        current.asciiWord = ascii
        current.frequency = max(current.frequency, frequency)

        // 2. Chèn vào cây không dấu để gợi ý mềm (Soft / Diacritic-agnostic Suggestions)
        if !ascii.isEmpty {
            var uCurrent = unaccentedRoot
            for char in ascii {
                if let next = uCurrent.children[char] {
                    uCurrent = next
                } else {
                    let newNode = WordTrieNode()
                    uCurrent.children[char] = newNode
                    uCurrent = newNode
                }
                uCurrent.updateTopCandidate(word: word, ascii: ascii, frequency: frequency, maxCapacity: 30)
            }
        }

        // 3. Đồng thời thêm vào chỉ mục vuốt phím Glide (theo chuỗi ASCII không dấu)
        if !ascii.contains(" ") && ascii.count >= 2, let first = ascii.first, let last = ascii.last {
            let key = GlideBucketKey(first: first, last: last)
            let entry = GlideWordEntry(
                word: word,
                asciiChars: Array(ascii),
                frequency: frequency,
                length: ascii.count
            )
            glideBuckets[key, default: []].append(entry)
        }
    }

    /// Gợi ý các từ phù hợp nhất theo tiền tố đang gõ (hỗ trợ gợi ý mềm không dấu và xếp hạng thông minh)
    public func suggest(prefix: String, limit: Int = 3) -> [String] {
        guard !prefix.isEmpty else { return [] }
        let lowerPrefix = prefix.lowercased()
        let asciiPrefix = WordTrie.stripDiacritics(lowerPrefix)

        // 0. Kiểm tra ngay trong bảng Typo Cache O(1) cho các lỗi gõ sai và viết tắt kinh điển (nhwung, ko, bik, haowcj, đuowcj,...)
        let cachedTypo = TypoCorrectionManager.shared.lookupCache(for: lowerPrefix) ??
            (lowerPrefix != asciiPrefix ? TypoCorrectionManager.shared.lookupCache(for: asciiPrefix) : nil)

        var candidates: [(word: String, ascii: String, freq: Int)] = []

        if lowerPrefix == asciiPrefix {
            // Trường hợp gõ không dấu (ví dụ: 'nhu', 'vi', 'viet'):
            // Tra cứu trực tiếp O(k) từ cây không dấu, không cấp phát Dictionary!
            var uCurrent = unaccentedRoot
            var uFound = true
            for char in asciiPrefix {
                if let next = uCurrent.children[char] {
                    uCurrent = next
                } else {
                    uFound = false
                    break
                }
            }
            if uFound && !uCurrent.topCandidates.isEmpty {
                candidates = uCurrent.topCandidates
            }
        } else {
            // Trường hợp gõ có dấu (ví dụ: 'như', 'việt'):
            // Kết hợp kết quả từ cây có dấu chính xác và cây không dấu
            var mergedDict: [String: (ascii: String, freq: Int)] = [:]
            var exactCurrent = root
            var exactFound = true
            for char in lowerPrefix {
                if let next = exactCurrent.children[char] {
                    exactCurrent = next
                } else {
                    exactFound = false
                    break
                }
            }
            if exactFound {
                for item in exactCurrent.topCandidates {
                    mergedDict[item.word] = (ascii: item.ascii, freq: item.freq)
                }
            }

            var uCurrent = unaccentedRoot
            var uFound = true
            for char in asciiPrefix {
                if let next = uCurrent.children[char] {
                    uCurrent = next
                } else {
                    uFound = false
                    break
                }
            }
            if uFound {
                for item in uCurrent.topCandidates {
                    let existingFreq = mergedDict[item.word]?.freq ?? 0
                    mergedDict[item.word] = (ascii: item.ascii, freq: max(existingFreq, item.freq))
                }
            }
            candidates = mergedDict.map { (word: $0.key, ascii: $0.value.ascii, freq: $0.value.freq) }
        }

        // Bổ sung từ trong Typo Cache vào danh sách nếu có
        if let cached = cachedTypo {
            if !candidates.contains(where: { $0.word.lowercased() == cached.lowercased() }) {
                candidates.insert((word: cached, ascii: WordTrie.stripDiacritics(cached), freq: 350), at: 0)
            }
        }

        // Nếu cả cây có dấu và không dấu đều không tìm thấy ứng viên:
        // KÍCH HOẠT 3 LỚP BẢO VỆ (3-LAYER PIPELINE)
        if candidates.isEmpty {
            // Lớp 1: Fast Typo Cache O(1)
            if let cached = cachedTypo {
                return [cached]
            }

            // Lớp 1.5: Cắt nhiễu đuôi (Tail Truncation) — người dùng gõ thừa ký tự
            // (ví dụ 'nhưngx' cho 'những'): thử dần các tiền tố ngắn hơn từ cuối lên
            let trimmed = Array(lowerPrefix)
            if trimmed.count >= 3 {
                for cut in 1...min(3, trimmed.count - 2) {
                    let shorter = String(trimmed.dropLast(cut))
                    let shorterResults = lookupDirectPrefix(shorter, limit: limit)
                    if !shorterResults.isEmpty {
                        return shorterResults
                    }
                }
            }

            // Lớp 2: Telex Phonotactics Normalizer (Tái cấu trúc ngữ âm Telex đảo vị trí)
            let normalized = TypoCorrectionManager.shared.normalizeTelexDisorder(input: lowerPrefix, trie: self)
            if !normalized.isEmpty {
                return Array(normalized.prefix(limit))
            }

            // Lớp 3: Spatial QWERTY Fuzzy Match (Sửa lỗi bấm nhầm phím kề cận trên bàn phím QWERTY)
            let spatialMatches = TypoCorrectionManager.shared.spatialFuzzyMatch(query: lowerPrefix, trie: self, limit: limit)
            if !spatialMatches.isEmpty {
                return spatialMatches
            }

            return []
        }

        // Hệ thống tính điểm xếp hạng mềm (Soft Ranking)
        let isSingleWordPrefix = !lowerPrefix.contains(" ")
        var scoredCandidates: [(word: String, score: Double)] = []
        scoredCandidates.reserveCapacity(candidates.count)

        for item in candidates {
            let lowWord = item.word.lowercased()
            let lowAsciiWord = item.ascii

            // Điểm cơ bản dựa vào tần suất ngữ liệu + điểm ưu tiên cá nhân hóa của người dùng
            var score: Double = Double(item.freq) * 2.0 + UserAdaptiveLearningStore.shared.userBoost(for: item.word)

            // Thưởng khớp chính xác hoàn toàn từ có dấu
            if lowWord == lowerPrefix {
                score += 200.0
            } else if lowWord.hasPrefix(lowerPrefix) {
                score += 60.0
            }

            // Thưởng khớp từ không dấu (ví dụ: gõ 'nhu' khớp trọn vẹn với dạng không dấu của 'như', 'nhu')
            if lowAsciiWord == asciiPrefix {
                score += 100.0
            } else if lowAsciiWord.hasPrefix(asciiPrefix) {
                score += 40.0
            }

            // Phạt khoảng cách độ dài (từ gần với độ dài đang gõ hơn thì ưu tiên hơn)
            let lengthDiff = abs(lowWord.count - lowerPrefix.count)
            score += max(0.0, 30.0 - Double(lengthDiff) * 5.0)

            // Ưu tiên từ đơn âm tiết nếu tiền tố người dùng gõ là từ đơn âm tiết
            if isSingleWordPrefix && !lowWord.contains(" ") {
                score += 25.0
            }

            scoredCandidates.append((word: item.word, score: score))
        }

        // Sắp xếp theo score giảm dần
        scoredCandidates.sort {
            if $0.score != $1.score {
                return $0.score > $1.score
            }
            return $0.word.count < $1.word.count
        }

        // Trích xuất danh sách duy nhất theo giới hạn
        var finalWords: [String] = []
        var seen = Set<String>()
        for item in scoredCandidates {
            let low = item.word.lowercased()
            if !seen.contains(low) {
                seen.insert(low)
                finalWords.append(item.word)
                if finalWords.count >= limit {
                    break
                }
            }
        }

        // Ưu tiên từ trong Typo Cache lên vị trí số 1 (ví dụ 'ko' -> 'không')
        if let cached = cachedTypo {
            if !finalWords.contains(where: { $0.lowercased() == cached.lowercased() }) {
                finalWords.insert(cached, at: 0)
                if finalWords.count > limit {
                    finalWords.removeLast()
                }
            } else if let idx = finalWords.firstIndex(where: { $0.lowercased() == cached.lowercased() }), idx != 0 {
                finalWords.remove(at: idx)
                finalWords.insert(cached, at: 0)
            }
        }

        // Fallback sửa lỗi chính tả & đảo phím Telex thông minh nếu không tìm thấy từ
        if finalWords.isEmpty {
            if let cached = cachedTypo {
                return [cached]
            }
            let normalized = TypoCorrectionManager.shared.normalizeTelexDisorder(input: lowerPrefix, trie: self)
            if !normalized.isEmpty {
                return Array(normalized.prefix(limit))
            }
            let spatial = TypoCorrectionManager.shared.spatialFuzzyMatch(query: lowerPrefix, trie: self, limit: limit)
            if !spatial.isEmpty {
                return spatial
            }
        }
        return finalWords.filter { !UserAdaptiveLearningStore.shared.isBlacklisted($0) }
    }

    /// Tra cứu tiền tố trực tiếp trên cây Trie (không gọi đệ quy sang TypoCorrectionManager)
    public func lookupDirectPrefix(_ prefix: String, limit: Int = 3) -> [String] {
        guard !prefix.isEmpty else { return [] }
        let lowerPrefix = prefix.lowercased()
        let asciiPrefix = WordTrie.stripDiacritics(lowerPrefix)

        var mergedDict: [String: (ascii: String, freq: Int)] = [:]

        // Tra cứu trên cây có dấu
        var exactCurrent = root
        var exactFound = true
        for char in lowerPrefix {
            if let next = exactCurrent.children[char] {
                exactCurrent = next
            } else {
                exactFound = false
                break
            }
        }
        if exactFound {
            for item in exactCurrent.topCandidates {
                mergedDict[item.word] = (ascii: item.ascii, freq: item.freq)
            }
        }

        // Tra cứu trên cây không dấu
        var uCurrent = unaccentedRoot
        var uFound = true
        for char in asciiPrefix {
            if let next = uCurrent.children[char] {
                uCurrent = next
            } else {
                uFound = false
                break
            }
        }
        if uFound {
            for item in uCurrent.topCandidates {
                let existingFreq = mergedDict[item.word]?.freq ?? 0
                mergedDict[item.word] = (ascii: item.ascii, freq: max(existingFreq, item.freq))
            }
        }

        guard !mergedDict.isEmpty else { return [] }
        let sorted = mergedDict.sorted {
            let s0 = Double($0.value.freq) * 2.0 + UserAdaptiveLearningStore.shared.userBoost(for: $0.key)
            let s1 = Double($1.value.freq) * 2.0 + UserAdaptiveLearningStore.shared.userBoost(for: $1.key)
            if s0 != s1 { return s0 > s1 }
            return $0.value.freq > $1.value.freq
        }
        let filtered = sorted.filter { !UserAdaptiveLearningStore.shared.isBlacklisted($0.key) }
        return Array(filtered.prefix(limit).map { $0.key })
    }

    /// Tra cứu tiền tố trực tiếp trả về mảng tuple kèm tần suất (word, freq)
    public func lookupDirectEntries(_ prefix: String, limit: Int = 5) -> [(word: String, freq: Int)] {
        guard !prefix.isEmpty else { return [] }
        let lowerPrefix = prefix.lowercased()
        let asciiPrefix = WordTrie.stripDiacritics(lowerPrefix)

        var mergedDict: [String: Int] = [:]

        // Tra cứu trên cây có dấu
        var exactCurrent = root
        var exactFound = true
        for char in lowerPrefix {
            if let next = exactCurrent.children[char] {
                exactCurrent = next
            } else {
                exactFound = false
                break
            }
        }
        if exactFound {
            for item in exactCurrent.topCandidates {
                mergedDict[item.word] = item.freq
            }
        }

        // Tra cứu trên cây không dấu
        var uCurrent = unaccentedRoot
        var uFound = true
        for char in asciiPrefix {
            if let next = uCurrent.children[char] {
                uCurrent = next
            } else {
                uFound = false
                break
            }
        }
        if uFound {
            for item in uCurrent.topCandidates {
                mergedDict[item.word] = max(mergedDict[item.word] ?? 0, item.freq)
            }
        }

        guard !mergedDict.isEmpty else { return [] }
        let sorted = mergedDict.sorted { $0.value > $1.value }
        return Array(sorted.prefix(limit).map { ($0.key, $0.value) })
    }

    /// Kiểm tra xem một từ có tồn tại chính xác trong từ điển có dấu hay không
    public func containsExactWord(_ word: String) -> Bool {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return false }
        if UserAdaptiveLearningStore.shared.isBlacklisted(clean) {
            return false
        }
        var current = root
        for char in clean {
            guard let next = current.children[char] else { return false }
            current = next
        }
        return current.word != nil
    }

    /// Kiểm tra xem một từ có phải là từ/âm tiết tiếng Việt hợp lệ hay không (hoặc là tiền tố hợp lệ)
    public func isValidVietnameseSyllable(_ word: String) -> Bool {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return false }

        // 1. Có chính xác trong từ điển ngữ liệu hoặc từ điển cá nhân
        if containsExactWord(clean) || UserAdaptiveLearningStore.shared.getUserWordFrequency(for: clean) > 0 {
            return true
        }

        // 2. Tra cứu tiền tố chính xác trên cây có dấu (Exact Tree)
        var exactCurrent = root
        for char in clean {
            guard let next = exactCurrent.children[char] else {
                return false
            }
            exactCurrent = next
        }
        return exactCurrent.word != nil || !exactCurrent.topCandidates.isEmpty
    }

    /// Tra cứu từ điển 1 chữ kèm điểm tần suất phục vụ UI Explorer
    public func searchUnigramWords(filter: String? = nil, limit: Int = 50) -> [(word: String, freq: Int)] {
        let cleanFilter = filter?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let query = cleanFilter, !query.isEmpty {
            return lookupDirectEntries(query, limit: limit)
        } else {
            let results = root.topCandidates.map { ($0.word, $0.freq) }
            return Array(results.prefix(limit))
        }
    }

    // MARK: - Toạ độ chuẩn hoá của bàn phím QWERTY (Row, Column)
    private static let qwertyCoords: [Character: (row: Double, col: Double)] = [
        "q": (0.0, 0.0), "w": (0.0, 1.0), "e": (0.0, 2.0), "r": (0.0, 3.0), "t": (0.0, 4.0),
        "y": (0.0, 5.0), "u": (0.0, 6.0), "i": (0.0, 7.0), "o": (0.0, 8.0), "p": (0.0, 9.0),
        "a": (1.0, 0.5), "s": (1.0, 1.5), "d": (1.0, 2.5), "f": (1.0, 3.5), "g": (1.0, 4.5),
        "h": (1.0, 5.5), "j": (1.0, 6.5), "k": (1.0, 7.5), "l": (1.0, 8.5),
        "z": (2.0, 1.5), "x": (2.0, 2.5), "c": (2.0, 3.5), "v": (2.0, 4.5), "b": (2.0, 5.5),
        "n": (2.0, 6.5), "m": (2.0, 7.5)
    ]

    /// Đo khoảng cách hình học giữa 2 phím trên bàn phím QWERTY chuẩn
    public static func qwertyKeyDistance(_ c1: Character, _ c2: Character) -> Double {
        guard let p1 = qwertyCoords[Character(c1.lowercased())],
              let p2 = qwertyCoords[Character(c2.lowercased())] else {
            return 2.5
        }
        let dr = p1.row - p2.row
        let dc = p1.col - p2.col
        return sqrt(dr * dr + dc * dc)
    }

    /// Tìm các phím lân cận trên bàn phím QWERTY chuẩn (khoảng cách <= maxDistance)
    public static func qwertyNeighbors(of char: Character, maxDistance: Double = 1.25) -> [Character] {
        let lower = Character(char.lowercased())
        guard qwertyCoords[lower] != nil else { return [] }
        return qwertyCoords.keys.filter { other in
            other != lower && qwertyKeyDistance(lower, other) <= maxDistance
        }
    }

    /// Gợi ý từ theo quỹ đạo vuốt (Glide / Swipe Typing)
    /// Hỗ trợ cả primarySequence (chuỗi phím chính đã lọc) và fullSequence (chuỗi phím đầy đủ)
    /// để kết hợp độ chính xác của lọc nhiễu với khả năng phục hồi ký tự lướt nhanh.
    public func matchGlide(
        keySequence: [Character],
        fullSequence: [Character] = [],
        limit: Int = 3
    ) -> [String] {
        guard keySequence.count >= 2 else { return [] }

        // Nếu không có fullSequence hoặc 2 chuỗi giống nhau, tra cứu đơn lẻ
        if fullSequence.isEmpty || fullSequence == keySequence {
            let matches = matchGlideSingle(keySequence: keySequence, limit: limit)
            return matches.map { $0.word }
        }

        // Kết hợp cả primary và full sequence: mỗi chuỗi tìm các ứng viên tiềm năng,
        // sau đó gộp lại lấy điểm số cao nhất cho từng từ
        let primaryMatches = matchGlideSingle(keySequence: keySequence, limit: limit * 2)
        let fullMatches = matchGlideSingle(keySequence: fullSequence, limit: limit * 2)

        var mergedScores: [String: Double] = [:]
        for item in primaryMatches {
            mergedScores[item.word] = item.score
        }
        for item in fullMatches {
            if let existing = mergedScores[item.word] {
                mergedScores[item.word] = max(existing, item.score)
            } else {
                mergedScores[item.word] = item.score
            }
        }

        let sorted = mergedScores.sorted {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.key.count < $1.key.count
        }
        return Array(sorted.prefix(limit).map { $0.key })
    }

    /// Khối tra cứu vuốt phím đơn lẻ cho một chuỗi ký tự
    private func matchGlideSingle(keySequence: [Character], limit: Int = 3) -> [(word: String, score: Double)] {
        guard keySequence.count >= 2 else { return [] }
        let lowerSeq = keySequence.map { Character($0.lowercased()) }
        guard let firstChar = lowerSeq.first, let lastChar = lowerSeq.last else { return [] }

        // Gộp bucket chính (đầu + cuối) với các bucket dự phòng:
        // 1. Phím áp chót (secondLast) và phím thứ 2 (secondFirst)
        // 2. Các phím lân cận của phím kết thúc (nhấc tay lệch 1 phím, ví dụ 'r' cạnh 'e' trong karaoke)
        // 3. Các phím lân cận của phím bắt đầu (chạm tay lệch 1 phím)
        var bucketKeys: [GlideBucketKey] = [GlideBucketKey(first: firstChar, last: lastChar)]
        var addedKeys = Set<GlideBucketKey>([bucketKeys[0]])

        func addKey(_ k: GlideBucketKey) {
            if addedKeys.insert(k).inserted {
                bucketKeys.append(k)
            }
        }

        if lowerSeq.count >= 3 {
            let secondLast = lowerSeq[lowerSeq.count - 2]
            if secondLast != lastChar {
                addKey(GlideBucketKey(first: firstChar, last: secondLast))
            }
            let secondFirst = lowerSeq[1]
            if secondFirst != firstChar {
                addKey(GlideBucketKey(first: secondFirst, last: lastChar))
            }
        }

        // Bổ sung các bucket lân cận của phím kết thúc và bắt đầu
        for neighbor in Self.qwertyNeighbors(of: lastChar, maxDistance: 1.25) {
            addKey(GlideBucketKey(first: firstChar, last: neighbor))
        }
        for neighbor in Self.qwertyNeighbors(of: firstChar, maxDistance: 1.25) {
            addKey(GlideBucketKey(first: neighbor, last: lastChar))
        }

        let candidates = scoreGlideEntries(
            in: bucketKeys,
            lowerSeq: lowerSeq,
            targetFirst: firstChar,
            targetLast: lastChar
        )
        let sortedBuckets = candidates.sorted { $0.score > $1.score }

        // Nếu bucket đã có ứng viên, trả về danh sách có điểm số
        guard sortedBuckets.isEmpty else {
            return Array(sortedBuckets.prefix(limit))
        }

        // Lớp dự phòng: so khớp mềm kiểu "túi phím" (Bag-of-Keys / Anagram).
        let seqCounts = Dictionary(lowerSeq.map { ($0, 1) }, uniquingKeysWith: +)
        var soft: [(word: String, score: Double)] = []
        var seen = Set<String>()

        var scanKeys: [GlideBucketKey] = []
        for (key, _) in glideBuckets {
            if key.first == firstChar || key.last == lastChar {
                scanKeys.append(key)
            }
        }

        for key in scanKeys {
            guard let entries = glideBuckets[key] else { continue }
            for entry in entries {
                let lowWord = entry.word.lowercased()
                if seen.contains(lowWord) || UserAdaptiveLearningStore.shared.isBlacklisted(lowWord) { continue }

                // Yêu cầu TỪ phải "viết được" từ các ký tự trong quỹ đạo:
                // mỗi ký tự của từ phải xuất hiện đủ số lần trong quỹ đạo
                let wordCounts = Dictionary(entry.asciiChars.map { ($0, 1) }, uniquingKeysWith: +)
                var fullySpellable = true
                for (ch, cnt) in wordCounts {
                    guard (seqCounts[ch] ?? 0) >= cnt else {
                        fullySpellable = false
                        break
                    }
                }
                guard fullySpellable else { continue }

                // Từ không được quá ngắn so với quỹ đạo (tránh từ 3 ký tự đoạt chỗ quỹ đạo 8 ký tự)
                guard entry.length >= max(3, Int(Double(lowerSeq.count) * 0.5)) else { continue }
                // Từ không được dài hơn quỹ đạo (thiếu ký tự là sai chắc chắn)
                guard entry.length <= lowerSeq.count else { continue }

                // Số ký tự nhiễu = ký tự quỹ đạo không được từ sử dụng
                var missing = 0
                for (ch, cnt) in seqCounts {
                    missing += max(0, cnt - (wordCounts[ch] ?? 0))
                }

                let freq = max(1, entry.frequency)
                let logFreq = log10(Double(freq))
                let coverage = Double(entry.length) / Double(lowerSeq.count)
                let noisePenalty = Double(missing) * 9.0

                var score = logFreq * 30.0 + coverage * 110.0 - noisePenalty
                + UserAdaptiveLearningStore.shared.userBoost(for: entry.word)
                if let firstCh = entry.asciiChars.first, firstCh == firstChar { score += 15.0 }
                if let lastCh = entry.asciiChars.last, lastCh == lastChar { score += 15.0 }

                soft.append((word: entry.word, score: score))
                seen.insert(lowWord)
            }
        }

        let final = soft.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.word.count < $1.word.count
        }
        return Array(final.prefix(limit))
    }

    /// Chấm điểm các ứng viên trong các bucket được chỉ định
    private func scoreGlideEntries(
        in bucketKeys: [GlideBucketKey],
        lowerSeq: [Character],
        targetFirst: Character,
        targetLast: Character
    ) -> [(word: String, score: Double)] {
        var candidates: [(word: String, score: Double)] = []
        var seen = Set<String>()

        for key in bucketKeys {
            guard let entries = glideBuckets[key] else { continue }
            for entry in entries {
                let lowWord = entry.word.lowercased()
                if seen.contains(lowWord) || UserAdaptiveLearningStore.shared.isBlacklisted(lowWord) { continue }

                // Kiểm tra xem entry.asciiChars có phải là dãy con (subsequence) của lowerSeq không.
                // Hỗ trợ:
                // 1. Phụ âm/nguyên âm đôi lướt qua 1 lần (ví dụ 'comment').
                // 2. Tối đa 1 ký tự fuzzy lân cận nếu ngón tay rẽ không tới hẳn phím đó
                //    (ví dụ 'chào' vuốt tới 's' kề 'a', hoặc 'karaoke' nhấc tay ở 'r' kề 'e').
                var sIdx = 0
                var matched = 0
                var matchedIndices: [Int] = []
                var fuzzyPenalty: Double = 0.0

                for (cIdx, ch) in entry.asciiChars.enumerated() {
                    var foundIdx = -1
                    var tempIdx = sIdx
                    while tempIdx < lowerSeq.count {
                        if lowerSeq[tempIdx] == ch {
                            foundIdx = tempIdx
                            break
                        }
                        tempIdx += 1
                    }
                    if foundIdx != -1 {
                        matched += 1
                        matchedIndices.append(foundIdx)
                        sIdx = foundIdx + 1
                    } else if cIdx > 0 && ch == entry.asciiChars[cIdx - 1] {
                        matched += 1
                    } else if fuzzyPenalty == 0.0 {
                        // Tìm ký tự lân cận gần nhất trong phần còn lại của quỹ đạo
                        var bestNeighborIdx = -1
                        var bestDist = 1.2
                        var nIdx = sIdx
                        while nIdx < lowerSeq.count {
                            let dist = Self.qwertyKeyDistance(lowerSeq[nIdx], ch)
                            if dist <= 1.15 && dist < bestDist {
                                bestDist = dist
                                bestNeighborIdx = nIdx
                                break
                            }
                            nIdx += 1
                        }
                        if bestNeighborIdx != -1 {
                            matched += 1
                            matchedIndices.append(bestNeighborIdx)
                            sIdx = bestNeighborIdx + 1
                            fuzzyPenalty = 22.0
                        } else {
                            break
                        }
                    } else {
                        break
                    }
                }

                // Xử lý ca biên: Quẹt nhanh bỏ sót 1 phím nằm thẳng hàng trên đường vuốt (ví dụ 'ka' cho 'khá')
                var isInterpolatedTransit = false
                if matched != entry.length && lowerSeq.count == 2 && entry.length == 3 {
                    if let f = entry.asciiChars.first, let l = entry.asciiChars.last, f == targetFirst && l == targetLast {
                        let mid = entry.asciiChars[1]
                        let d1 = Self.qwertyKeyDistance(targetFirst, mid)
                        let d2 = Self.qwertyKeyDistance(mid, targetLast)
                        let totalD = Self.qwertyKeyDistance(targetFirst, targetLast)
                        if d1 + d2 <= totalD + 1.2 {
                            matched = entry.length
                            isInterpolatedTransit = true
                        }
                    }
                }

                // Lớp dự phòng trong bucket: khi so khớp nghiêm ngặt thất bại do quỹ đạo
                // nhiễu làm ĐẢO THỨ TỰ ký tự (ví dụ 'njugwoif' cho 'người' — u đứng
                // trước g), chấp nhận từ nếu MỌI ký tự của từ đều xuất hiện đủ số lần
                // trong quỹ đạo. Phạt điểm theo số ký tự bị lệch trật tự thay vì loại trắng.
                if matched != entry.length {
                    // Chỉ áp dụng cho từ đủ dài so với quỹ đạo (tránh từ ngắn đoạt chỗ quỹ đạo dài)
                    guard entry.length >= 3, entry.length >= Int(Double(lowerSeq.count) * 0.5) else { continue }
                    // Nén các ký tự lặp liên tiếp trong từ trước khi kiểm tra số lượng
                    let collapsedChars = entry.asciiChars.enumerated().compactMap { i, c in (i > 0 && c == entry.asciiChars[i-1]) ? nil : c }
                    let wordCounts = Dictionary(collapsedChars.map { ($0, 1) }, uniquingKeysWith: +)
                    let seqCounts = Dictionary(lowerSeq.map { ($0, 1) }, uniquingKeysWith: +)
                    guard wordCounts.allSatisfy({ (seqCounts[$0.key] ?? 0) >= $0.value }) else { continue }

                    let freq = max(1, entry.frequency)
                    let logFreq = log10(Double(freq))
                    let freqBonus = Double(freq) * 0.40
                    let coverage = Double(entry.length) / Double(lowerSeq.count)
                    let excessChars = Double(max(0, lowerSeq.count - entry.length))
                    // Phạt lệch trật tự: từ không đúng thứ tự vuốt phải chịu phạt nặng
                    let disorderPenalty = 45.0 + Double(entry.length - matched) * 15.0

                    var score = logFreq * 30.0 + freqBonus + coverage * 80.0 - excessChars * 5.0 - disorderPenalty
                    + UserAdaptiveLearningStore.shared.userBoost(for: entry.word)
                    if let firstCh = entry.asciiChars.first {
                        let startDist = Self.qwertyKeyDistance(firstCh, targetFirst)
                        if firstCh == targetFirst {
                            score += 25.0
                        } else if lowerSeq.count >= 2 && lowerSeq[1] == firstCh {
                            score -= startDist * 15.0
                        } else {
                            score -= startDist * 45.0
                        }
                    }
                    if let lastCh = entry.asciiChars.last {
                        let endDist = Self.qwertyKeyDistance(lastCh, targetLast)
                        if lastCh == targetLast {
                            score += 25.0
                        } else if lowerSeq.count >= 2 && lowerSeq[lowerSeq.count - 2] == lastCh {
                            score -= endDist * 15.0
                        } else {
                            score -= endDist * 40.0
                        }
                    }
                    if !seen.contains(lowWord) {
                        candidates.append((word: entry.word, score: score))
                        seen.insert(lowWord)
                    }
                    continue
                }

                if matched == entry.length {
                    let freq = max(1, entry.frequency)
                    let logFreq = log10(Double(freq))
                    let freqBonus = Double(freq) * 0.40
                    let coverage = Double(entry.length) / Double(lowerSeq.count)
                    let excessChars = Double(max(0, lowerSeq.count - entry.length))
                    let matchLengthBonus = Double(entry.length) * 12.0

                    // Phạt bỏ sót phím ngoặt lớn (Detour Deviation Penalty):
                    // Tính độ lệch (đoạn rẽ) của các ký tự không khớp so với đường đi giữa các ký tự đã khớp.
                    // Nếu ký tự nằm trên đường thẳng nối 2 phím khớp (ví dụ lướt qua phím hàng giữa từ 'l' đến 'a'),
                    // độ lệch tam giác d(p, j) + d(j, q) - d(p, q) gần bằng 0 -> Không bị phạt!
                    // Nhưng nếu người dùng rẽ ngón tay sang vùng phím khác (như phím 'a' trong 'kjhoang'),
                    // độ lệch sẽ rất lớn -> Phạt nặng từ ứng viên bỏ qua khúc rẽ này.
                    var detourMissPenalty: Double = 0.0
                    if !matchedIndices.isEmpty && lowerSeq.count > entry.length {
                        let sortedMatched = matchedIndices.sorted()
                        let matchedSet = Set(sortedMatched)
                        for j in 0..<lowerSeq.count {
                            if !matchedSet.contains(j) {
                                let ch = lowerSeq[j]
                                let prevIdx = sortedMatched.last(where: { $0 < j })
                                let nextIdx = sortedMatched.first(where: { $0 > j })

                                var deviation = 0.0
                                if let p = prevIdx, let q = nextIdx {
                                    let d1 = Self.qwertyKeyDistance(lowerSeq[p], ch)
                                    let d2 = Self.qwertyKeyDistance(ch, lowerSeq[q])
                                    let dDirect = Self.qwertyKeyDistance(lowerSeq[p], lowerSeq[q])
                                    deviation = d1 + d2 - dDirect
                                } else if let p = prevIdx {
                                    deviation = Self.qwertyKeyDistance(lowerSeq[p], ch)
                                } else if let q = nextIdx {
                                    deviation = Self.qwertyKeyDistance(ch, lowerSeq[q])
                                }

                                if deviation > 1.8 {
                                    detourMissPenalty += (deviation - 1.8) * 12.0
                                }
                            }
                        }
                    }

                    // Với các từ 2 chữ cực cao tần (core từ điển như 'là', 'và', 'có', 'đi'),
                    // giảm nhẹ phạt ký tự thừa và cộng thưởng ưu tiên cốt lõi
                    let excessPenaltyFactor = (entry.length == 2 && entry.frequency >= 250) ? 2.5 : 5.0
                    let coreWordBonus = (entry.frequency >= 250) ? 25.0 : 0.0

                    // Điểm xác suất ngôn ngữ + tần suất thực tế + độ phủ cử chỉ + thưởng độ dài từ - phạt ký tự thừa & phím ngoặt
                    var score = logFreq * 30.0 + freqBonus + coverage * 80.0 + matchLengthBonus + coreWordBonus - excessChars * excessPenaltyFactor - detourMissPenalty - fuzzyPenalty + UserAdaptiveLearningStore.shared.userBoost(for: entry.word)
                    if isInterpolatedTransit {
                        score -= 20.0
                    }

                    // Phạt khoảng cách không gian (Spatial Distance Penalty) tới phím bắt đầu và kết thúc
                    if let firstCh = entry.asciiChars.first {
                        let startDist = Self.qwertyKeyDistance(firstCh, targetFirst)
                        if firstCh == targetFirst {
                            score += 25.0
                        } else if lowerSeq.count >= 2 && lowerSeq[1] == firstCh {
                            score -= startDist * 15.0
                        } else {
                            score -= startDist * 45.0
                        }
                    }
                    if let lastCh = entry.asciiChars.last {
                        let endDist = Self.qwertyKeyDistance(lastCh, targetLast)
                        if lastCh == targetLast {
                            score += 25.0
                        } else if lowerSeq.count >= 2 && lowerSeq[lowerSeq.count - 2] == lastCh {
                            score -= endDist * 15.0
                        } else {
                            score -= endDist * 40.0
                        }
                    }

                    candidates.append((word: entry.word, score: score))
                    seen.insert(lowWord)
                }
            }
        }
        return candidates
    }

    // MARK: - Bộ từ vựng tiếng Việt tần suất cao
    private func loadCommonVietnameseWords() {
        lock.lock()
        defer { lock.unlock() }
        guard !isLoaded else { return }
        isLoaded = true

        // 1. Thử nạp từ tệp từ điển vietnamese_words.txt trong Bundle hoặc App Group
        if loadFromLexiconFile() {
            return
        }

        // 2. Dự phòng danh sách nhúng cứng sẵn nếu không tìm thấy tệp
        let highFreq: [(String, Int)] = [
            ("và", 100), ("là", 98), ("của", 96), ("có", 95), ("được", 94), ("trong", 93),
            ("một", 92), ("cho", 91), ("với", 90), ("không", 89), ("nhưng", 88), ("các", 88), ("những", 87),
            ("người", 86), ("khi", 85), ("này", 84), ("đã", 83), ("đến", 82), ("từ", 81),
            ("về", 80), ("sẽ", 79), ("như", 78), ("để", 77), ("ra", 76), ("ở", 75),
            ("lại", 74), ("làm", 73), ("thì", 72), ("nhiều", 71), ("vào", 70), ("theo", 69),
            ("trên", 68), ("sau", 67), ("cũng", 66), ("phải", 65), ("ngày", 64), ("việc", 63),
            ("năm", 62), ("con", 61), ("hơn", 60), ("chỉ", 59), ("tại", 58), ("đang", 57),
            ("thấy", 56), ("thể", 55), ("đi", 54), ("biết", 53), ("mới", 52), ("rất", 51),
            ("cùng", 50), ("lớn", 49), ("đó", 48), ("qua", 47), ("nói", 46), ("mà", 45),
            ("nào", 44), ("thời", 43), ("gian", 42), ("chúng", 41), ("tôi", 40), ("anh", 39),
            ("em", 38), ("bạn", 37), ("mình", 36), ("ông", 35), ("bà", 34), ("cô", 33),
            ("chú", 32), ("bác", 31), ("Việt", 95), ("Nam", 90), ("Hà", 70), ("Nội", 65),
            ("Sài", 60), ("Gòn", 55), ("thành", 54), ("phố", 53), ("hôm", 60), ("nay", 65),
            ("mai", 50), ("tuần", 45), ("tháng", 48), ("tiếng", 70), ("bàn", 65), ("phím", 65),
            ("công", 60), ("nghệ", 58), ("điện", 55), ("thoại", 55), ("thông", 52), ("tin", 52),
            ("dữ", 50), ("liệu", 50), ("hệ", 48), ("thống", 48), ("ứng", 45), ("dụng", 45),
            ("phát", 42), ("triển", 42), ("hoàn", 40), ("tuyệt", 45), ("vời", 45), ("nhanh", 65),
            ("chóng", 40), ("chính", 45), ("xác", 45), ("cảm", 70), ("ơn", 70), ("xin", 75),
            ("chào", 75), ("tạm", 60), ("biệt", 60), ("đồng", 55), ("ý", 55), ("hủy", 50),
            ("bỏ", 50), ("xác", 48), ("nhận", 48), ("thành", 50), ("công", 50), ("tài", 52),
            ("khoản", 52), ("mật", 50), ("khẩu", 50), ("tiền", 55), ("ngân", 45), ("hàng", 55),
            ("thanh", 45), ("toán", 45), ("nhắn", 50), ("gửi", 50), ("xem", 52), ("đọc", 50),
            ("viết", 55), ("nghe", 50), ("nhìn", 48), ("yêu", 60), ("thương", 50), ("vui", 55),
            ("buồn", 40), ("khỏe", 55), ("mạnh", 50), ("chúc", 60), ("mừng", 60), ("sinh", 50),
            ("nhật", 50), ("tốt", 60), ("đẹp", 60), ("hay", 55), ("dễ", 52), ("khó", 48),
            ("ăn", 58), ("uống", 50), ("ngủ", 48), ("nghỉ", 45), ("chơi", 52), ("học", 60),
            ("tập", 50), ("mua", 55), ("bán", 52), ("nhà", 60), ("cửa", 48), ("xe", 50),
            ("đường", 55), ("sách", 48), ("báo", 45), ("trường", 50), ("lớp", 45), ("thầy", 45),
            ("giáo", 45), ("viên", 45), ("học", 55), ("sinh", 50), ("công", 55), ("việc", 65),
            ("bận", 48), ("rảnh", 45), ("gặp", 50), ("nhau", 50), ("đâu", 55), ("sao", 55),
            ("ai", 55), ("gì", 60), ("thế", 60), ("nào", 55), ("chứ", 50), ("nhỉ", 48),
            ("nhé", 55), ("nha", 55), ("luôn", 52), ("ngay", 55), ("rồi", 65), ("chưa", 60),
            ("xong", 55), ("hết", 50), ("còn", 55), ("được", 70), ("mất", 45), ("tìm", 50),
            ("kiếm", 48), ("chọn", 48), ("lưu", 48), ("xóa", 52), ("sửa", 50), ("thêm", 50),
            ("bớt", 42), ("trước", 55), ("giữa", 45), ("dưới", 48), ("bên", 50), ("cạnh", 45),
            ("trong", 65), ("ngoài", 50), ("xa", 45), ("gần", 48), ("cao", 48), ("thấp", 42),
            ("dài", 45), ("ngắn", 42), ("nặng", 42), ("nhẹ", 48), ("mạnh", 45), ("yếu", 40),
            ("trắng", 45), ("đen", 45), ("đỏ", 45), ("xanh", 48), ("vàng", 45), ("nắng", 45),
            ("mưa", 50), ("gió", 45), ("mát", 45), ("lạnh", 45), ("nóng", 45), ("ấm", 45),
            ("nghĩ", 55), ("hiểu", 55), ("nhớ", 55), ("quên", 45), ("chờ", 50), ("đợi", 50),
            ("mong", 50), ("ước", 45), ("thích", 60), ("ghét", 40), ("chạy", 50), ("cười", 50),
            ("khóc", 45), ("hỏi", 52), ("giúp", 55), ("thử", 52), ("chuẩn", 55), ("sai", 50),
            ("đúng", 65), ("thú", 48), ("vị", 50), ("tự", 55), ("tin", 55), ("bình", 50),
            ("tĩnh", 45), ("hạnh", 55), ("phúc", 55), ("may", 50), ("mắn", 50), ("thông", 55),
            ("báo", 50), ("cài", 55), ("đặt", 55), ("đăng", 55), ("nhập", 60), ("xuất", 50),
            ("bảo", 50), ("mật", 52), ("mạng", 50), ("thiết", 50), ("bị", 55), ("máy", 55),
            ("tính", 55), ("màn", 50), ("hình", 55), ("Hải", 45), ("Phòng", 45), ("Đà", 50),
            ("Nẵng", 50), ("Cần", 45), ("Thơ", 45), ("Huế", 45), ("Nha", 45), ("Trang", 45),
            ("Lạt", 45), ("Vũng", 45), ("Tàu", 45), ("sáng", 55), ("trưa", 50), ("chiều", 55),
            ("tối", 55), ("đêm", 50), ("tuy", 50), ("nhiên", 50), ("bởi", 50), ("vì", 65),
            ("cho", 70), ("nên", 65), ("mặc", 50), ("dù", 50), ("chắc", 55), ("chắn", 55),
            ("hình", 50), ("như", 60), ("đặc", 50), ("biệt", 55), ("đồng", 55), ("thời", 55),
            ("thật", 60), ("sự", 60), ("tất", 55), ("nhiên", 55), ("cảm", 65), ("ơn", 65),
            ("xin", 70), ("lỗi", 60), ("phiền", 45), ("hoan", 45), ("nghênh", 45), ("bắt", 50),
            ("đầu", 55), ("kết", 50), ("thúc", 50), ("tiếp", 55), ("tục", 55), ("dừng", 48),
            ("bước", 50), ("chân", 50), ("tay", 55), ("mắt", 55), ("mũi", 45), ("miệng", 45),
            ("tai", 45), ("tóc", 45), ("lưng", 45), ("bụng", 45), ("tim", 50)
        ]

        for (w, f) in highFreq {
            insert(word: w, frequency: f)
        }
    }

    /// Đọc từ tệp vietnamese_words.txt từ Swift Package Bundle hoặc App Group Container
    public func loadFromLexiconFile(customFilePath: String? = nil) -> Bool {
        // 1. Kiểm tra custom file path truyền vào
        if let customPath = customFilePath,
           let content = try? String(contentsOfFile: customPath, encoding: .utf8) {
            parseAndInsertLines(content)
            return true
        }

        // 2. Thử đọc từ App Group Container (chia sẻ giữa Host App và Keyboard Extension)
        let fileManager = FileManager.default
        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.nguyenphuong.vBoard") {
            let customLexiconURL = groupURL.appendingPathComponent("vietnamese_words.txt")
            if fileManager.fileExists(atPath: customLexiconURL.path),
               let content = try? String(contentsOf: customLexiconURL, encoding: .utf8) {
                parseAndInsertLines(content)
                return true
            }
        }

        // 3. Thử đọc từ Bundle Resource của Swift Package (Bundle.module)
        #if SWIFT_PACKAGE
        if let resourceURL = Bundle.module.url(forResource: "vietnamese_words", withExtension: "txt"),
           let content = try? String(contentsOf: resourceURL, encoding: .utf8) {
            parseAndInsertLines(content)
            saveToAppGroupIfNeeded(content: content)
            return true
        }
        #endif

        // 4. Thử đọc từ tất cả các bundle (Main Bundle, Extension Bundle, Frameworks)
        var bundlesToCheck: [Bundle] = [Bundle.main]
        bundlesToCheck.append(contentsOf: Bundle.allBundles)
        bundlesToCheck.append(contentsOf: Bundle.allFrameworks)

        for bundle in bundlesToCheck {
            if let path = bundle.path(forResource: "vietnamese_words", ofType: "txt"),
               let content = try? String(contentsOfFile: path, encoding: .utf8) {
                parseAndInsertLines(content)
                saveToAppGroupIfNeeded(content: content)
                return true
            }
        }

        return false
    }

    private func saveToAppGroupIfNeeded(content: String) {
        let fileManager = FileManager.default
        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.nguyenphuong.vBoard") {
            let targetURL = groupURL.appendingPathComponent("vietnamese_words.txt")
            if !fileManager.fileExists(atPath: targetURL.path) {
                try? content.write(to: targetURL, atomically: true, encoding: .utf8)
            }
        }
    }

    private func parseAndInsertLines(_ content: String) {
        var unigramLines: [(String, Int)] = []
        var phraseLines: [(String, Int)] = []
        unigramLines.reserveCapacity(10000)
        phraseLines.reserveCapacity(90000)

        content.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return }
            let parts = trimmed.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
            let word: String
            let freq: Int
            if parts.count == 2 {
                word = String(parts[0]).trimmingCharacters(in: .whitespaces)
                freq = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 50
            } else if parts.count == 1 {
                word = String(parts[0]).trimmingCharacters(in: .whitespaces)
                freq = 50
            } else {
                return
            }

            // KIẾN TRÚC TÁCH ĐÔI TỪ ĐIỂN:
            // 1. Nếu là từ đơn (1 âm tiết, không chứa khoảng trắng): Nạp đồng bộ vào WordTrie để gõ phím & Glide (< 5ms)
            // 2. Nếu là cụm từ (nhiều âm tiết): Nạp vào NextWordPredictor ở Background Thread để tránh chặn Main Thread & Jetsam crash
            if !word.contains(" ") {
                unigramLines.append((word, freq))
            } else {
                phraseLines.append((word, freq))
            }
        }

        // 1. Nạp đồng bộ các từ đơn (7.741 từ) và cụm từ tần suất cao (>= 200) để bàn phím sẵn sàng ngay (< 5ms)
        for item in unigramLines {
            self.insert(word: item.0, frequency: item.1)
        }
        var backgroundPhrases: [(String, Int)] = []
        backgroundPhrases.reserveCapacity(phraseLines.count)
        for item in phraseLines {
            if item.1 >= 200 {
                NextWordPredictor.shared.registerPhrase(phrase: item.0, frequency: item.1)
            } else {
                backgroundPhrases.append(item)
            }
        }
        self.totalWordsCount += phraseLines.count

        // 2. Nạp bất đồng bộ hơn 81.000 cụm từ N-gram còn lại trong nền để giải phóng Main Thread và giảm RAM spike
        let phrasesToLoad = backgroundPhrases
        DispatchQueue.global(qos: .utility).async {
            for item in phrasesToLoad {
                NextWordPredictor.shared.registerPhrase(phrase: item.0, frequency: item.1)
            }
        }
    }
}
