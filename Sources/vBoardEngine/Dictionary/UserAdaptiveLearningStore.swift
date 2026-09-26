//
//  UserAdaptiveLearningStore.swift
//  vBoardEngine
//
//  Quản lý việc tự học thích ứng (Lifelong Adaptive Learning):
//  1. Vùng đệm Ứng viên (Staging Buffer): Chỉ lưu từ lạ khi người dùng gõ lặp lại >= 3 lần (Promotion Threshold).
//  2. Bảng tần suất người dùng (User Lexicon & N-Gram): Tăng điểm cho các từ/cụm từ hay dùng.
//  3. Cơ chế đào thải tự nhiên (Exponential Aging/Decay): Tự động giảm tần suất và dọn dẹp các từ ít dùng.
//

import Foundation

public final class UserAdaptiveLearningStore: @unchecked Sendable {
    public static let shared = UserAdaptiveLearningStore()

    private let lock = NSLock()
    private let appGroupID = "group.com.nguyenphuong.vBoard"
    private let storageFileName = "user_dynamic_lexicon.json"

    // Ngưỡng kết nạp từ mới vào từ điển chính thức của người dùng (ít nhất 2 lần trong vòng 24 giờ)
    public static let promotionThreshold: Int = 2
    public static let promotionWindowSeconds: TimeInterval = 86400 // 24 giờ
    // Giới hạn số lượng từ đơn và n-gram cá nhân để bảo toàn RAM & Disk (< 300KB)
    public static let maxUserWordsCapacity: Int = 2000
    public static let maxUserNGramsCapacity: Int = 3000

    // Vùng nhớ tạm lưu các từ mới xuất hiện
    private var stagingWords: [String: (count: Int, lastTime: TimeInterval)] = [:]
    // Danh sách từ đơn người dùng đã được kết nạp chính thức kèm tần suất
    private var userWords: [String: Int] = [:]
    // Bảng chuyển tiếp N-gram cá nhân: Context -> [NextWord: Frequency]
    private var userNGrams: [String: [String: Int]] = [:]
    // Danh sách các từ người dùng đã chọn xoá / chặn gợi ý khỏi bàn phím
    private var blacklistedWords: Set<String> = []

    private var totalRecordedInputs: Int = 0
    private var lastDecayTime: TimeInterval = Date().timeIntervalSince1970

    public init() {
        loadFromDisk()
    }

    // MARK: - Ghi nhận đầu vào người dùng
    /// Ghi nhận khi người dùng vừa hoàn thành một từ (gõ xong hoặc chọn từ thanh gợi ý)
    public func recordWordInput(_ word: String, previousWord: String? = nil, previousPreviousWord: String? = nil) {
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanWord.isEmpty, cleanWord.count <= 35 else { return }

        lock.lock()
        defer { lock.unlock() }

        totalRecordedInputs += 1
        let now = Date().timeIntervalSince1970
        let lowWord = cleanWord.lowercased()

        // 1. Phân biệt từ đơn và cụm từ ngữ cảnh:
        if cleanWord.contains(" ") {
            // Cụm từ (2-3 chữ trở lên): Lưu vào bảng N-gram người dùng (userNGrams), KHÔNG thêm cụm từ vào bảng từ đơn (userWords) hay WordTrie làm nặng cây tìm kiếm
            let tokens = cleanWord.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if tokens.count >= 2 {
                let w1 = tokens[0].lowercased()
                let w2 = tokens[1].lowercased()
                var nextMap = userNGrams[w1, default: [:]]
                nextMap[tokens[1], default: 0] += 1
                userNGrams[w1] = nextMap

                if tokens.count >= 3 {
                    let triCtx = "\(w1) \(w2)"
                    var triMap = userNGrams[triCtx, default: [:]]
                    triMap[tokens[2], default: 0] += 1
                    userNGrams[triCtx] = triMap
                }
            }
        } else {
            // Từ đơn (1 chữ): Cần qua Vùng đệm Staging >= 2 lần / 24h mới được đưa vào Từ điển cá nhân chính thức
            if let currentFreq = userWords[lowWord] {
                userWords[lowWord] = currentFreq + 1
            } else {
                // Kiểm tra trong vùng nhớ tạm (Staging Buffer)
                var currentStaging = stagingWords[lowWord] ?? (count: 0, lastTime: now)
                if (now - currentStaging.lastTime) > Self.promotionWindowSeconds {
                    // Quá 24 giờ kể từ lần gõ trước -> Bắt đầu đếm lại cho ngày mới
                    currentStaging.count = 1
                } else {
                    currentStaging.count += 1
                }
                currentStaging.lastTime = now

                if currentStaging.count >= Self.promotionThreshold {
                    // Đạt ngưỡng kết nạp (>= 2 lần / 24h) -> Đưa lên từ điển người dùng
                    userWords[lowWord] = currentStaging.count
                    stagingWords.removeValue(forKey: lowWord)
                    WordTrie.shared.insert(word: cleanWord, frequency: 150)
                } else {
                    stagingWords[lowWord] = currentStaging
                }
            }
        }

        // 2. Cập nhật mô hình Bigram cá nhân: (W_{i-1} -> W_i)
        if let prev = previousWord?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !prev.isEmpty {
            var nextMap = userNGrams[prev, default: [:]]
            nextMap[cleanWord, default: 0] += 1
            userNGrams[prev] = nextMap

            // 3. Cập nhật mô hình Trigram cá nhân: (W_{i-2} W_{i-1} -> W_i)
            if let prevPrev = previousPreviousWord?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !prevPrev.isEmpty {
                let trigramContext = "\(prevPrev) \(prev)"
                var triNextMap = userNGrams[trigramContext, default: [:]]
                triNextMap[cleanWord, default: 0] += 1
                userNGrams[trigramContext] = triNextMap
            }
        }

        // Kiểm tra và thực hiện đào thải định kỳ sau mỗi 300 từ gõ
        if totalRecordedInputs % 300 == 0 {
            performDecayAndPurgeLocked()
            saveToDiskLocked()
        }
    }

    /// Ghi nhận từ mở đầu câu (sau dấu câu hoặc đầu văn bản)
    public func recordSentenceStartWord(_ word: String) {
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanWord.isEmpty, cleanWord.count <= 35 else { return }

        lock.lock()
        defer { lock.unlock() }

        let formatted = cleanWord.prefix(1).uppercased() + cleanWord.dropFirst()
        var nextMap = userNGrams["<sentence_start>", default: [:]]
        nextMap[formatted, default: 0] += 1
        userNGrams["<sentence_start>"] = nextMap
    }

    // MARK: - Tra cứu điểm và dự đoán
    /// Lấy điểm ưu tiên người dùng cho từ đang xét
    public func userBoost(for word: String) -> Double {
        lock.lock()
        defer { lock.unlock() }
        let low = word.lowercased()
        if let freq = userWords[low] {
            return Double(freq) * 3.0
        }
        return 0.0
    }

    /// Lấy tần suất người dùng cho từ đơn
    public func getUserWordFrequency(for word: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return userWords[word.lowercased()] ?? 0
    }

    /// Lấy bảng tần suất N-gram của người dùng theo ngữ cảnh
    public func getUserNGramFrequencies(context: String) -> [String: Int] {
        lock.lock()
        defer { lock.unlock() }
        let lowContext = context.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return userNGrams[lowContext] ?? [:]
    }

    /// Dự đoán từ tiếp theo dựa trên mô hình cá nhân hóa của người dùng
    public func predictUserNextWords(context: String, limit: Int = 3) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        let lowContext = context.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let map = userNGrams[lowContext], !map.isEmpty else { return [] }

        let sorted = map.sorted { $0.value > $1.value }
        return Array(sorted.prefix(limit).map { $0.key })
    }

    /// Dự đoán các từ mở đầu câu dựa trên thói quen người dùng
    public func predictSentenceStarters(limit: Int = 3) -> [String] {
        lock.lock()
        defer { lock.unlock() }

        let defaultStarters = ["Tôi", "Em", "Dạ", "Anh", "Hiện tại", "Vâng", "Bạn"]
        guard let map = userNGrams["<sentence_start>"], !map.isEmpty else {
            return Array(defaultStarters.prefix(limit))
        }

        var results: [String] = []
        var seen = Set<String>()

        // 1. Lấy từ người dùng dùng nhiều nhất
        let sorted = map.sorted { $0.value > $1.value }
        for item in sorted {
            let key = item.key
            if !seen.contains(key.lowercased()) {
                seen.insert(key.lowercased())
                results.append(key)
            }
        }

        // 2. Bổ sung từ mặc định nếu chưa đủ
        for def in defaultStarters {
            if !seen.contains(def.lowercased()) {
                seen.insert(def.lowercased())
                results.append(def)
            }
        }

        return Array(results.prefix(limit))
    }

    /// Lấy danh sách tất cả từ đơn người dùng đã học
    public func getAllUserWords() -> [String: Int] {
        lock.lock()
        defer { lock.unlock() }
        return userWords
    }

    /// Lấy danh sách chi tiết các từ trong Vùng đệm tạm thời (Staging Buffer)
    public func getStagingWordsDetails() -> [(word: String, count: Int, lastTime: Date)] {
        lock.lock()
        defer { lock.unlock() }
        return stagingWords.map { (word: $0.key, count: $0.value.count, lastTime: Date(timeIntervalSince1970: $0.value.lastTime)) }
            .sorted { $0.count > $1.count }
    }

    /// Lấy danh sách từ cá nhân người dùng kèm điểm số xếp hạng
    public func getUserWordsWithScores() -> [(word: String, score: Int)] {
        lock.lock()
        defer { lock.unlock() }
        return userWords.map { (word: $0.key, score: $0.value) }
            .sorted { $0.score > $1.score }
    }

    /// Lấy danh sách các N-gram cá nhân kèm tần suất
    public func getUserNGramsWithScores() -> [String: [(nextWord: String, count: Int)]] {
        lock.lock()
        defer { lock.unlock() }
        var result: [String: [(nextWord: String, count: Int)]] = [:]
        for (ctx, map) in userNGrams {
            let sorted = map.map { (nextWord: $0.key, count: $0.value) }
                .sorted { $0.count > $1.count }
            result[ctx] = sorted
        }
        return result
    }

    /// Xóa một từ khỏi từ điển cá nhân của người dùng
    public func deleteUserWord(_ word: String) {
        lock.lock()
        defer { lock.unlock() }
        let low = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        userWords.removeValue(forKey: low)
        stagingWords.removeValue(forKey: low)
        saveToDiskLocked()
    }

    /// Chặn / Xóa bỏ vĩnh viễn một từ khỏi toàn bộ hệ thống gợi ý từ điển của người dùng
    public func blacklistWord(_ word: String) {
        lock.lock()
        defer { lock.unlock() }
        let low = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !low.isEmpty else { return }
        userWords.removeValue(forKey: low)
        stagingWords.removeValue(forKey: low)
        blacklistedWords.insert(low)
        saveToDiskLocked()
    }

    /// Khôi phục một từ đã từng bị xóa / chặn
    public func unblacklistWord(_ word: String) {
        lock.lock()
        defer { lock.unlock() }
        let low = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        blacklistedWords.remove(low)
        saveToDiskLocked()
    }

    /// Kiểm tra xem một từ có nằm trong danh sách đen bị chặn hay không
    public func isBlacklisted(_ word: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let low = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return blacklistedWords.contains(low)
    }

    /// Lấy danh sách toàn bộ các từ đã bị chặn gợi ý
    public func getBlacklistedWords() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(blacklistedWords).sorted()
    }

    /// Cập nhật tần suất cho một từ trong từ điển cá nhân
    public func updateUserWord(_ word: String, frequency: Int) {
        lock.lock()
        defer { lock.unlock() }
        let low = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !low.isEmpty else { return }
        userWords[low] = max(1, frequency)
        WordTrie.shared.insert(word: word, frequency: max(100, frequency * 10))
        saveToDiskLocked()
    }

    /// Thêm trực tiếp một từ vào từ điển người dùng (bỏ qua Staging Buffer)
    public func addUserWordDirectly(_ word: String, frequency: Int = 10) {
        lock.lock()
        defer { lock.unlock() }
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let low = clean.lowercased()
        blacklistedWords.remove(low)
        userWords[low] = frequency
        WordTrie.shared.insert(word: clean, frequency: max(100, frequency * 10))
        saveToDiskLocked()
    }

    /// Xuất dữ liệu từ điển người dùng ra chuỗi JSON để sao lưu
    public func exportJSON() -> String? {
        lock.lock()
        defer { lock.unlock() }
        let payload: [String: Any] = [
            "userWords": userWords,
            "userNGrams": userNGrams,
            "blacklistedWords": Array(blacklistedWords),
            "version": 1.0,
            "exportDate": Date().timeIntervalSince1970
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    /// Nhập dữ liệu sao lưu từ điển từ chuỗi JSON
    public func importJSON(_ jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8),
              let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
            return false
        }

        lock.lock()
        defer { lock.unlock() }

        if let words = json["userWords"] as? [String: Int] {
            for (w, f) in words {
                self.userWords[w] = max(self.userWords[w] ?? 0, f)
                WordTrie.shared.insert(word: w, frequency: max(100, f * 10))
            }
        }
        if let ngrams = json["userNGrams"] as? [String: [String: Int]] {
            for (ctx, nextMap) in ngrams {
                var current = self.userNGrams[ctx] ?? [:]
                for (nw, f) in nextMap {
                    current[nw] = max(current[nw] ?? 0, f)
                }
                self.userNGrams[ctx] = current
            }
        }
        if let blacklisted = json["blacklistedWords"] as? [String] {
            for w in blacklisted {
                self.blacklistedWords.insert(w.lowercased())
            }
        }
        saveToDiskLocked()
        return true
    }

    // MARK: - Cơ chế Đào thải (Aging / Exponential Decay)
    private func performDecayAndPurgeLocked() {
        let now = Date().timeIntervalSince1970
        let elapsed = now - lastDecayTime
        guard elapsed > 86400 || userWords.count > Self.maxUserWordsCapacity else { return }
        lastDecayTime = now

        // Mô hình Half-Life Decay theo thời gian thực: Score = Count * e^(-lambda * delta_t)
        // Hệ số suy giảm ~0.85 sau mỗi 24 giờ (lambda ≈ 0.1625 / ngày)
        let daysPassed = elapsed / 86400.0
        let decayRatio = pow(0.85, daysPassed)

        var decayedWords: [String: Int] = [:]
        for (w, f) in userWords {
            let newFreq = max(1, Int(round(Double(f) * decayRatio)))
            if newFreq > 1 || f >= Self.promotionThreshold {
                decayedWords[w] = newFreq
            }
        }
        userWords = decayedWords

        // Cắt tỉa danh sách nếu vượt quá dung lượng trần
        if userWords.count > Self.maxUserWordsCapacity {
            let sorted = userWords.sorted { $0.value > $1.value }
            userWords = Dictionary(uniqueKeysWithValues: sorted.prefix(Self.maxUserWordsCapacity).map { ($0.key, $0.value) })
        }

        // Dọn dẹp vùng staging những từ gõ quá 24 tiếng trước (86.400s) mà không đạt ngưỡng
        stagingWords = stagingWords.filter { (now - $0.value.lastTime) < 86400 }

        // Cắt tỉa N-gram
        if userNGrams.count > Self.maxUserNGramsCapacity {
            let sortedContexts = userNGrams.sorted { $0.value.values.reduce(0, +) > $1.value.values.reduce(0, +) }
            userNGrams = Dictionary(uniqueKeysWithValues: sortedContexts.prefix(Self.maxUserNGramsCapacity).map { ($0.key, $0.value) })
        }
    }

    // MARK: - Lưu & Nạp dữ liệu vào App Group
    private func getStorageURL() -> URL? {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return containerURL.appendingPathComponent(storageFileName)
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return docs?.appendingPathComponent(storageFileName)
    }

    public func saveToDisk() {
        lock.lock()
        defer { lock.unlock() }
        saveToDiskLocked()
    }

    private func saveToDiskLocked() {
        guard let url = getStorageURL() else { return }
        let payload: [String: Any] = [
            "userWords": userWords,
            "userNGrams": userNGrams,
            "blacklistedWords": Array(blacklistedWords),
            "lastDecayTime": lastDecayTime
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: []) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func loadFromDisk() {
        lock.lock()
        defer { lock.unlock() }
        guard let url = getStorageURL(),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
            return
        }

        if let words = json["userWords"] as? [String: Int] {
            self.userWords = words
            for (w, f) in words {
                WordTrie.shared.insert(word: w, frequency: max(100, f * 10))
            }
        }
        if let ngrams = json["userNGrams"] as? [String: [String: Int]] {
            self.userNGrams = ngrams
        }
        if let blacklisted = json["blacklistedWords"] as? [String] {
            self.blacklistedWords = Set(blacklisted.map { $0.lowercased() })
        }
        if let decay = json["lastDecayTime"] as? TimeInterval {
            self.lastDecayTime = decay
        }
        performDecayAndPurgeLocked()
    }
}
