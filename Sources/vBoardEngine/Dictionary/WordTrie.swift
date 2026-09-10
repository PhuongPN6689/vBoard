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

        let candidates: [(word: String, ascii: String, freq: Int)]

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
            guard uFound, !uCurrent.topCandidates.isEmpty else { return [] }
            candidates = uCurrent.topCandidates
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
            guard !mergedDict.isEmpty else { return [] }
            candidates = mergedDict.map { (word: $0.key, ascii: $0.value.ascii, freq: $0.value.freq) }
        }

        // Hệ thống tính điểm xếp hạng mềm (Soft Ranking)
        let isSingleWordPrefix = !lowerPrefix.contains(" ")
        var scoredCandidates: [(word: String, score: Double)] = []
        scoredCandidates.reserveCapacity(candidates.count)

        for item in candidates {
            let lowWord = item.word.lowercased()
            let lowAsciiWord = item.ascii

            // Điểm cơ bản dựa vào tần suất ngữ liệu
            var score: Double = Double(item.freq) * 2.0

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

        return finalWords
    }

    /// Gợi ý từ theo quỹ đạo vuốt (Glide / Swipe Typing)
    /// Hỗ trợ hoàn hảo tiếng Việt có dấu khi vuốt trên bàn phím QWERTY chuẩn ASCII
    public func matchGlide(keySequence: [Character], limit: Int = 3) -> [String] {
        guard keySequence.count >= 2 else { return [] }
        let lowerSeq = keySequence.map { Character($0.lowercased()) }
        guard let firstChar = lowerSeq.first, let lastChar = lowerSeq.last else { return [] }

        var bucketKeys: [GlideBucketKey] = [
            GlideBucketKey(first: firstChar, last: lastChar)
        ]

        // Dự phòng khi ngón tay trượt quá mép phím cuối hoặc đầu
        if lowerSeq.count >= 3 {
            let secondLast = lowerSeq[lowerSeq.count - 2]
            if secondLast != lastChar {
                bucketKeys.append(GlideBucketKey(first: firstChar, last: secondLast))
            }
            let secondFirst = lowerSeq[1]
            if secondFirst != firstChar {
                bucketKeys.append(GlideBucketKey(first: secondFirst, last: lastChar))
            }
        }

        var candidates: [(word: String, score: Int)] = []
        var seen = Set<String>()

        for key in bucketKeys {
            guard let entries = glideBuckets[key] else { continue }
            for entry in entries {
                let lowWord = entry.word.lowercased()
                if seen.contains(lowWord) { continue }

                // Kiểm tra xem entry.asciiChars có phải là dãy con (subsequence) của lowerSeq không
                var sIdx = 0
                var matched = 0
                for ch in entry.asciiChars {
                    while sIdx < lowerSeq.count && lowerSeq[sIdx] != ch {
                        sIdx += 1
                    }
                    if sIdx < lowerSeq.count && lowerSeq[sIdx] == ch {
                        matched += 1
                        sIdx += 1
                    } else {
                        break
                    }
                }

                if matched == entry.length {
                    // Trọng số điểm (thích ứng tối ưu với dải tần suất 1 - 300):
                    // 1. Độ dài từ: từ khớp nhiều điểm mốc ký tự trên quỹ đạo hơn được ưu tiên
                    // 2. Thưởng lớn khi độ dài từ khớp chính xác số lượng phím được vuốt
                    // 3. Tần suất xuất hiện (frequency) trong kho ngữ liệu tiếng Việt (1 - 300)
                    // 4. Khớp chính xác điểm đầu và điểm kết thúc ngón tay
                    var score = entry.frequency + entry.length * 80
                    if entry.length == lowerSeq.count {
                        score += 150
                    }
                    if entry.asciiChars.last == lastChar {
                        score += 15
                    }
                    if entry.asciiChars.first == firstChar {
                        score += 15
                    }
                    candidates.append((word: entry.word, score: score))
                    seen.insert(lowWord)
                }
            }
        }

        candidates.sort { $0.score > $1.score }
        return Array(candidates.prefix(limit).map { $0.word })
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
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
            if parts.count == 2 {
                let word = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let freq = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 50
                insert(word: word, frequency: freq)
            } else if parts.count == 1 {
                let word = String(parts[0]).trimmingCharacters(in: .whitespaces)
                insert(word: word, frequency: 50)
            }
        }
    }
}
