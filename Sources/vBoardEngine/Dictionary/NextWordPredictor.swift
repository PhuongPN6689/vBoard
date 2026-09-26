//
//  NextWordPredictor.swift
//  vBoardEngine
//
//  Bộ dự đoán từ tiếp theo kết hợp:
//  1. Mô hình Trigram (ngữ cảnh 2 từ trước) + Bigram (1 từ trước) với Stupid Backoff
//  2. Dữ liệu tĩnh các cụm từ phổ biến tiếng Việt
//  3. Dữ liệu động cá nhân hóa từ UserAdaptiveLearningStore
//

import Foundation

public final class NextWordPredictor: @unchecked Sendable {
    public static let shared = NextWordPredictor()

    // MARK: - Mô hình Trigram tĩnh: (W_{i-2} W_{i-1}) -> [W_i]
    private let triGramMap: [String: [String]] = [
        "chúc bạn": ["ngủ ngon", "vui vẻ", "thành công", "may mắn", "hạnh phúc", "một ngày"],
        "chúc mừng": ["sinh nhật", "năm mới", "bạn", "ngày", "chiến thắng"],
        "cảm ơn": ["bạn", "anh", "chị", "nhiều", "rất nhiều", "em"],
        "hẹn gặp": ["lại", "nhau", "ngày mai", "sớm"],
        "công nghệ": ["thông tin", "mới", "cao", "số"],
        "thời gian": ["tới", "này", "qua", "biểu"],
        "thành phố": ["hồ chí minh", "hà nội", "đà nẵng", "lớn"],
        "việt nam": ["vô địch", "hôm nay", "đẹp", "hòa bình"],
        "chúng tôi": ["rất", "xin", "luôn", "sẽ", "đang"],
        "không có": ["gì", "thời gian", "tiền", "ai", "vấn đề"],
        "có thể": ["làm", "được", "giúp", "xảy ra", "nói"],
        "làm sao": ["được", "bây giờ", "biết", "đây"],
        "đi làm": ["về", "sớm", "ngay", "muộn"],
        "ăn cơm": ["chưa", "tối", "trưa", "với"],
        "uống cà": ["phê", "phê sữa"],
        "học sinh": ["sinh viên", "giỏi", "tiểu học"],
        "ngày mai": ["đi", "gặp", "làm", "sẽ"],
        "hôm nay": ["thế nào", "trời", "rất", "bận", "đi"]
    ]

    // MARK: - Mô hình Bigram tĩnh: (W_{i-1}) -> [W_i]
    private let biGramMap: [String: [String]] = [
        "xin": ["chào", "lỗi", "phép", "hỏi", "mời"],
        "chào": ["bạn", "anh", "chị", "em", "mọi người", "buổi sáng", "cả nhà"],
        "cảm": ["ơn", "xúc", "thấy", "nhận", "giác"],
        "chúc": ["mừng", "bạn", "ngủ ngon", "một ngày", "thành công"],
        "hẹn": ["gặp lại", "gặp", "hò", "ngày mai", "sớm", "nhau"],
        "báo": ["cáo", "chí", "động", "tin", "giá"],
        "làm": ["việc", "sao", "gì", "ơn", "quen", "được"],
        "đi": ["đâu", "làm", "chơi", "về", "ngay", "học"],
        "ăn": ["cơm", "tối", "trưa", "sáng", "uống", "gì"],
        "uống": ["cà phê", "nước", "trà", "bia", "rượu"],
        "học": ["tập", "sinh", "hành", "tiếng", "bài"],
        "công": ["việc", "nghệ", "ty", "tác", "cụ"],
        "thời": ["gian", "tiết", "khóa", "đại", "sự"],
        "việt": ["nam", "ngữ", "kiều", "hóa"],
        "hà": ["nội", "tĩnh", "giang", "nam"],
        "sài": ["gòn"],
        "thành": ["phố", "công", "lập", "viên"],
        "tất": ["cả", "nhiên", "thảy"],
        "rất": ["vui", "tốt", "đẹp", "nhiều", "thích", "nhanh"],
        "không": ["có", "biết", "sao", "được", "thể", "phải", "sao cả"],
        "được": ["rồi", "chưa", "không", "biết", "khen"],
        "người": ["yêu", "dùng", "lớn", "nhà", "bạn"],
        "đồng": ["ý", "chí", "nghiệp", "hồ", "tiền"],
        "anh": ["em", "trai", "ấy", "ơi", "yêu"],
        "em": ["gái", "yêu", "ơi", "ạ", "nhớ"],
        "bạn": ["bè", "thân", "ơi", "có", "gì"],
        "tôi": ["nghĩ", "muốn", "thấy", "sẽ", "đang", "cũng"],
        "quá": ["đẹp", "tuyệt", "nhanh", "hay", "buồn"],
        "bao": ["nhiêu", "giờ", "lâu", "tiền"]
    ]

    // MARK: - Mô hình N-gram động nạp từ từ điển tiếng Việt (vietnamese_words.txt)
    // Giúp lưu trữ ~13.840 cụm từ nhiều âm tiết mà không tốn bộ nhớ WordTrie
    private let lock = NSLock()
    private var lexiconBiGramMap: [String: [(word: String, freq: Int)]] = [:]
    private var lexiconTriGramMap: [String: [(word: String, freq: Int)]] = [:]

    private init() {}

    /// Đăng ký một cụm từ nhiều âm tiết từ từ điển ngữ liệu (vietnamese_words.txt)
    public func registerPhrase(phrase: String, frequency: Int) {
        let tokens = phrase.split(separator: " ").map { String($0).lowercased() }
        guard tokens.count >= 2 else { return }

        lock.lock()
        defer { lock.unlock() }

        if tokens.count == 2 {
            // Bigram: token[0] -> token[1]
            let w1 = tokens[0]
            let w2 = tokens[1]
            insertLexiconBiGram(context: w1, candidate: w2, freq: frequency)
        } else if tokens.count == 3 {
            // Trigram: "token[0] token[1]" -> token[2]
            let trigramContext = "\(tokens[0]) \(tokens[1])"
            let w3 = tokens[2]
            insertLexiconTriGram(context: trigramContext, candidate: w3, freq: frequency)

            // Đồng thời học thêm Bigram: token[1] -> token[2]
            insertLexiconBiGram(context: tokens[1], candidate: w3, freq: frequency)
        } else {
            // Cụm từ 4 từ trở lên (ví dụ: "công nghệ thông tin", "cộng hòa xã hội")
            // 1. Trigram theo 2 từ đầu -> cụm từ còn lại ("công nghệ" -> "thông tin")
            let triContext = "\(tokens[0]) \(tokens[1])"
            let remainder = tokens[2...].joined(separator: " ")
            insertLexiconTriGram(context: triContext, candidate: remainder, freq: frequency)

            // 2. Trigram từ đơn: "công nghệ" -> "thông" (với điểm số thấp hơn để ưu tiên cụm hoàn chỉnh)
            insertLexiconTriGram(context: triContext, candidate: tokens[2], freq: max(1, frequency - 30))

            // 3. N-gram trượt cho các từ kế tiếp
            for i in 1..<(tokens.count - 1) {
                let ctx = "\(tokens[i]) \(tokens[i+1])"
                if i + 2 < tokens.count {
                    insertLexiconTriGram(context: ctx, candidate: tokens[i+2], freq: frequency)
                }
                insertLexiconBiGram(context: tokens[i], candidate: tokens[i+1], freq: frequency)
            }
            insertLexiconBiGram(context: tokens[0], candidate: tokens[1], freq: frequency)
        }
    }

    private func insertLexiconBiGram(context: String, candidate: String, freq: Int) {
        var list = lexiconBiGramMap[context] ?? []
        if let idx = list.firstIndex(where: { $0.word == candidate }) {
            list[idx].freq = max(list[idx].freq, freq)
        } else {
            list.append((word: candidate, freq: freq))
        }
        // Giữ tối đa 12 ứng viên có tần suất cao nhất để tiết kiệm RAM trên iOS Keyboard Extension
        if list.count > 12 {
            list.sort { $0.freq > $1.freq }
            list = Array(list.prefix(12))
        }
        lexiconBiGramMap[context] = list
    }

    private func insertLexiconTriGram(context: String, candidate: String, freq: Int) {
        var list = lexiconTriGramMap[context] ?? []
        if let idx = list.firstIndex(where: { $0.word == candidate }) {
            list[idx].freq = max(list[idx].freq, freq)
        } else {
            list.append((word: candidate, freq: freq))
        }
        if list.count > 12 {
            list.sort { $0.freq > $1.freq }
            list = Array(list.prefix(12))
        }
        lexiconTriGramMap[context] = list
    }

    /// Reset bộ nhớ N-gram động khi tải lại từ điển
    public func resetLexiconPhrases() {
        lock.lock()
        defer { lock.unlock() }
        lexiconBiGramMap.removeAll()
        lexiconTriGramMap.removeAll()
    }

    /// Dự đoán các từ tiếp theo dựa trên từ vừa gõ (Bigram tương thích ngược)
    public func predictNextWords(after word: String, limit: Int = 3) -> [String] {
        return predictNextWords(previousWord: word, previousPreviousWord: nil, limit: limit)
    }

    /// Dự đoán các từ mở đầu câu (sau dấu chấm câu '.', '!', '?')
    public func predictSentenceStarters(limit: Int = 3) -> [String] {
        return UserAdaptiveLearningStore.shared.predictSentenceStarters(limit: limit)
    }

    /// Dự đoán từ tiếp theo phân cấp (Trigram -> Bigram -> Stupid Backoff kết hợp User Adaptive Learning)
    /// Công thức xếp hạng: Score(W) = Score_Base(W) + alpha * UserFrequency(W) (với alpha = 2.5)
    public func predictNextWords(previousWord: String?, previousPreviousWord: String? = nil, limit: Int = 3) -> [String] {
        // Đảm bảo từ điển ngữ liệu WordTrie đã được nạp nếu chưa khởi tạo
        _ = WordTrie.shared

        guard let prev = previousWord?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !prev.isEmpty else {
            return predictSentenceStarters(limit: limit)
        }
        if [".", "!", "?", "..."].contains(prev) {
            return predictSentenceStarters(limit: limit)
        }

        lock.lock()
        let triGramCopy = lexiconTriGramMap
        let biGramCopy = lexiconBiGramMap
        lock.unlock()

        let alpha: Double = 2.5 // Trọng số ưu tiên thói quen cá nhân của người dùng
        let beta: Double = 0.4  // Hệ số phạt Stupid Backoff khi lùi từ Trigram về Bigram

        var candidateScores: [String: Double] = [:]

        // 1. Thu thập ứng viên Trigram: (W_{i-2} W_{i-1} -> W_i)
        if let prevPrev = previousPreviousWord?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !prevPrev.isEmpty {
            let trigramKey = "\(prevPrev) \(prev)"

            // 1.1 Trigram tĩnh (Base score: 100.0)
            if let staticTri = triGramMap[trigramKey] {
                for (idx, w) in staticTri.enumerated() {
                    let base = max(20.0, 100.0 - Double(idx) * 8.0)
                    candidateScores[w, default: 0.0] = max(candidateScores[w] ?? 0.0, base)
                }
            }

            // 1.2 Trigram từ điển ngữ liệu (Base score theo corpus frequency)
            if let dynamicTri = triGramCopy[trigramKey] {
                for item in dynamicTri {
                    let base = Double(item.freq) * 0.5 + 20.0
                    candidateScores[item.word, default: 0.0] = max(candidateScores[item.word] ?? 0.0, base)
                }
            }

            // 1.3 Trigram cá nhân hóa của người dùng (Score += alpha * UserFrequency)
            let userTriMap = UserAdaptiveLearningStore.shared.getUserNGramFrequencies(context: trigramKey)
            for (w, freq) in userTriMap {
                let userBoost = Double(freq) * alpha * 15.0 + 50.0
                candidateScores[w, default: 0.0] += userBoost
            }
        }

        // 2. Thu thập ứng viên Bigram: (W_{i-1} -> W_i) áp dụng Stupid Backoff (nhân hệ số beta = 0.4)
        // 2.1 Bigram tĩnh (Base score: 100.0 tương tự Trigram)
        if let staticBi = biGramMap[prev] {
            for (idx, w) in staticBi.enumerated() {
                let base = max(20.0, 100.0 - Double(idx) * 8.0) * beta
                candidateScores[w, default: 0.0] = max(candidateScores[w] ?? 0.0, base)
            }
        }

        // 2.2 Bigram từ điển ngữ liệu (Base score tỷ lệ thuận theo corpus frequency)
        if let dynamicBi = biGramCopy[prev] {
            for item in dynamicBi {
                let base = (Double(item.freq) * 0.5 + 10.0) * beta
                candidateScores[item.word, default: 0.0] = max(candidateScores[item.word] ?? 0.0, base)
            }
        }

        // 2.3 Bigram cá nhân hóa của người dùng (Score += alpha * UserFrequency * beta)
        let userBiMap = UserAdaptiveLearningStore.shared.getUserNGramFrequencies(context: prev)
        for (w, freq) in userBiMap {
            let userBoost = (Double(freq) * alpha * 10.0 + 30.0) * beta
            candidateScores[w, default: 0.0] += userBoost
        }

        // 3. Cộng thêm điểm tần suất từ đơn người dùng (Unigram User Frequency)
        for (w, _) in candidateScores {
            let userSingleFreq = UserAdaptiveLearningStore.shared.getUserWordFrequency(for: w)
            if userSingleFreq > 0 {
                candidateScores[w, default: 0.0] += Double(userSingleFreq) * alpha
            }
        }

        guard !candidateScores.isEmpty else { return [] }

        // Sắp xếp các ứng viên theo Score giảm dần (ưu tiên cụm từ hoàn chỉnh hơn từ đơn dở dang khi bằng điểm)
        let sorted = candidateScores.sorted { (a, b) -> Bool in
            if a.value != b.value {
                return a.value > b.value
            }
            return a.key.count > b.key.count
        }

        var results: [String] = []
        var seen = Set<String>()
        for item in sorted {
            let low = item.key.lowercased()
            if !seen.contains(low) {
                seen.insert(low)
                results.append(item.key)
                if results.count >= limit {
                    break
                }
            }
        }

        return predictNextWordsScored(previousWord: previousWord, previousPreviousWord: previousPreviousWord, limit: limit).map { $0.word }
    }

    /// Dự đoán từ tiếp theo phân cấp trả về chi tiết cả từ và điểm số xếp hạng thực tế của mô hình
    public func predictNextWordsScored(previousWord: String?, previousPreviousWord: String? = nil, limit: Int = 3) -> [(word: String, score: Double)] {
        // Đảm bảo từ điển ngữ liệu WordTrie đã được nạp nếu chưa khởi tạo
        _ = WordTrie.shared

        guard let prev = previousWord?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !prev.isEmpty else {
            let starters = predictSentenceStarters(limit: limit)
            return starters.enumerated().map { (word: $0.element, score: Double(100 - $0.offset * 10)) }
        }
        if [".", "!", "?", "..."].contains(prev) {
            let starters = predictSentenceStarters(limit: limit)
            return starters.enumerated().map { (word: $0.element, score: Double(100 - $0.offset * 10)) }
        }

        lock.lock()
        let triGramCopy = lexiconTriGramMap
        let biGramCopy = lexiconBiGramMap
        lock.unlock()

        let alpha: Double = 2.5 // Trọng số ưu tiên thói quen cá nhân của người dùng
        let beta: Double = 0.4  // Hệ số phạt Stupid Backoff khi lùi từ Trigram về Bigram

        var candidateScores: [String: Double] = [:]

        // 1. Thu thập ứng viên Trigram: (W_{i-2} W_{i-1} -> W_i)
        if let prevPrev = previousPreviousWord?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !prevPrev.isEmpty {
            let trigramKey = "\(prevPrev) \(prev)"

            // 1.1 Trigram tĩnh (Base score: 100.0)
            if let staticTri = triGramMap[trigramKey] {
                for (idx, w) in staticTri.enumerated() {
                    let base = max(20.0, 100.0 - Double(idx) * 8.0)
                    candidateScores[w, default: 0.0] = max(candidateScores[w] ?? 0.0, base)
                }
            }

            // 1.2 Trigram từ điển ngữ liệu (Base score theo corpus frequency)
            if let dynamicTri = triGramCopy[trigramKey] {
                for item in dynamicTri {
                    let base = Double(item.freq) * 0.5 + 20.0
                    candidateScores[item.word, default: 0.0] = max(candidateScores[item.word] ?? 0.0, base)
                }
            }

            // 1.3 Trigram cá nhân hóa của người dùng (Score += alpha * UserFrequency)
            let userTriMap = UserAdaptiveLearningStore.shared.getUserNGramFrequencies(context: trigramKey)
            for (w, freq) in userTriMap {
                let userBoost = Double(freq) * alpha * 15.0 + 50.0
                candidateScores[w, default: 0.0] += userBoost
            }
        }

        // 2. Thu thập ứng viên Bigram: (W_{i-1} -> W_i) áp dụng Stupid Backoff (nhân hệ số beta = 0.4)
        // 2.1 Bigram tĩnh (Base score: 100.0 tương tự Trigram)
        if let staticBi = biGramMap[prev] {
            for (idx, w) in staticBi.enumerated() {
                let base = max(20.0, 100.0 - Double(idx) * 8.0) * beta
                candidateScores[w, default: 0.0] = max(candidateScores[w] ?? 0.0, base)
            }
        }

        // 2.2 Bigram từ điển ngữ liệu (Base score tỷ lệ thuận theo corpus frequency)
        if let dynamicBi = biGramCopy[prev] {
            for item in dynamicBi {
                let base = (Double(item.freq) * 0.5 + 10.0) * beta
                candidateScores[item.word, default: 0.0] = max(candidateScores[item.word] ?? 0.0, base)
            }
        }

        // 2.3 Bigram cá nhân hóa của người dùng (Score += alpha * UserFrequency * beta)
        let userBiMap = UserAdaptiveLearningStore.shared.getUserNGramFrequencies(context: prev)
        for (w, freq) in userBiMap {
            let userBoost = (Double(freq) * alpha * 10.0 + 30.0) * beta
            candidateScores[w, default: 0.0] += userBoost
        }

        // 3. Cộng thêm điểm tần suất từ đơn người dùng (Unigram User Frequency)
        for (w, _) in candidateScores {
            let userSingleFreq = UserAdaptiveLearningStore.shared.getUserWordFrequency(for: w)
            if userSingleFreq > 0 {
                candidateScores[w, default: 0.0] += Double(userSingleFreq) * alpha
            }
        }

        guard !candidateScores.isEmpty else { return [] }

        // Sắp xếp các ứng viên theo Score giảm dần (ưu tiên cụm từ hoàn chỉnh hơn từ đơn dở dang khi bằng điểm)
        let sorted = candidateScores.sorted { (a, b) -> Bool in
            if a.value != b.value {
                return a.value > b.value
            }
            return a.key.count > b.key.count
        }

        var results: [(word: String, score: Double)] = []
        var seen = Set<String>()
        for item in sorted {
            let low = item.key.lowercased()
            if !seen.contains(low) && !UserAdaptiveLearningStore.shared.isBlacklisted(low) {
                seen.insert(low)
                results.append((word: item.key, score: item.value))
                if results.count >= limit {
                    break
                }
            }
        }

        return results
    }

    // MARK: - API tra cứu dữ liệu điểm số N-gram phục vụ UI Explorer
    /// Trích xuất danh sách Bigram kèm điểm số phục vụ màn hình tra cứu
    public func getRankedBigrams(filter: String? = nil, limit: Int = 50) -> [(context: String, candidates: [(word: String, score: Double)])] {
        lock.lock()
        var allContexts = Set(biGramMap.keys)
        allContexts.formUnion(lexiconBiGramMap.keys)
        lock.unlock()

        let cleanFilter = filter?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filteredContexts: [String]
        if let query = cleanFilter, !query.isEmpty {
            filteredContexts = allContexts.filter { $0.contains(query) }.sorted()
        } else {
            filteredContexts = allContexts.sorted()
        }

        var result: [(context: String, candidates: [(word: String, score: Double)])] = []
        for ctx in filteredContexts.prefix(limit) {
            let scored = predictNextWordsScored(previousWord: ctx, limit: 10)
            result.append((context: ctx, candidates: scored))
        }
        return result
    }

    /// Trích xuất danh sách Trigram kèm điểm số phục vụ màn hình tra cứu
    public func getRankedTrigrams(filter: String? = nil, limit: Int = 50) -> [(context: String, candidates: [(word: String, score: Double)])] {
        lock.lock()
        var allContexts = Set(triGramMap.keys)
        allContexts.formUnion(lexiconTriGramMap.keys)
        lock.unlock()

        let cleanFilter = filter?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filteredContexts: [String]
        if let query = cleanFilter, !query.isEmpty {
            filteredContexts = allContexts.filter { $0.contains(query) }.sorted()
        } else {
            filteredContexts = allContexts.sorted()
        }

        var result: [(context: String, candidates: [(word: String, score: Double)])] = []
        for ctx in filteredContexts.prefix(limit) {
            let parts = ctx.split(separator: " ").map(String.init)
            let p1 = parts.first ?? ""
            let p2 = parts.count >= 2 ? parts[1] : ""
            let scored = predictNextWordsScored(previousWord: p2, previousPreviousWord: p1, limit: 10)
            result.append((context: ctx, candidates: scored))
        }
        return result
    }
}
