//
//  GlideBenchmarkStore.swift
//  vBoardEngine
//
//  Kho dữ liệu và lưu trữ các phiên vuốt phím thực tế (Trajectory Recording Store):
//  - Quản lý bộ 50 từ tiếng Việt tiêu biểu
//  - Lưu trữ toạ độ thô, chuỗi phím, vận tốc, kết quả kiểm thử
//  - Cho phép xuất / nhập định dạng JSON để chia sẻ và tái hiện
//  - Hỗ trợ chạy lại kiểm thử (Re-evaluation) khi cập nhật thuật toán
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Cấu trúc cho một từ thử nghiệm vuốt phím
public struct GlideChallengeWord: Identifiable, Codable, Sendable {
    public let id: UUID
    public let targetWord: String
    public let hintPath: String
    public let category: String
    public let note: String

    public init(id: UUID = UUID(), targetWord: String, hintPath: String, category: String, note: String) {
        self.id = id
        self.targetWord = targetWord
        self.hintPath = hintPath
        self.category = category
        self.note = note
    }
}

/// Dữ liệu một phiên vuốt phím thực tế của người dùng được lưu trữ
public struct GlideRecordedSession: Identifiable, Codable, Sendable {
    public let id: UUID
    public let targetWord: String
    public let category: String
    public let samples: [GlideSample]
    public let primarySeq: String
    public let fullSeq: String
    public let recognizedWord: String
    public let topCandidates: [String]
    public let durationMs: Double
    public let totalDistancePx: Double
    public let avgVelocityPxPerSec: Double
    public let peakVelocityPxPerSec: Double
    public let isMatch: Bool
    public let createdAt: Date
    public let keyboardWidth: Double
    public let keyboardHeight: Double

    public var primaryChars: [Character] { Array(primarySeq) }
    public var fullChars: [Character] { Array(fullSeq) }

    public init(
        id: UUID = UUID(),
        targetWord: String,
        category: String,
        samples: [GlideSample],
        primarySeq: String,
        fullSeq: String,
        recognizedWord: String,
        topCandidates: [String],
        durationMs: Double,
        totalDistancePx: Double,
        avgVelocityPxPerSec: Double,
        peakVelocityPxPerSec: Double,
        isMatch: Bool,
        createdAt: Date = Date(),
        keyboardWidth: Double = 390,
        keyboardHeight: Double = 260
    ) {
        self.id = id
        self.targetWord = targetWord
        self.category = category
        self.samples = samples
        self.primarySeq = primarySeq
        self.fullSeq = fullSeq
        self.recognizedWord = recognizedWord
        self.topCandidates = topCandidates
        self.durationMs = durationMs
        self.totalDistancePx = totalDistancePx
        self.avgVelocityPxPerSec = avgVelocityPxPerSec
        self.peakVelocityPxPerSec = peakVelocityPxPerSec
        self.isMatch = isMatch
        self.createdAt = createdAt
        self.keyboardWidth = keyboardWidth
        self.keyboardHeight = keyboardHeight
    }

    public init(
        id: UUID = UUID(),
        targetWord: String,
        category: String,
        samples: [GlideSample],
        primarySeqChars: [Character],
        fullSeqChars: [Character],
        recognizedWord: String,
        topCandidates: [String],
        durationMs: Double,
        totalDistancePx: Double,
        avgVelocityPxPerSec: Double,
        peakVelocityPxPerSec: Double,
        isMatch: Bool,
        createdAt: Date = Date(),
        keyboardWidth: Double = 390,
        keyboardHeight: Double = 260
    ) {
        self.init(
            id: id,
            targetWord: targetWord,
            category: category,
            samples: samples,
            primarySeq: String(primarySeqChars),
            fullSeq: String(fullSeqChars),
            recognizedWord: recognizedWord,
            topCandidates: topCandidates,
            durationMs: durationMs,
            totalDistancePx: totalDistancePx,
            avgVelocityPxPerSec: avgVelocityPxPerSec,
            peakVelocityPxPerSec: peakVelocityPxPerSec,
            isMatch: isMatch,
            createdAt: createdAt,
            keyboardWidth: keyboardWidth,
            keyboardHeight: keyboardHeight
        )
    }
}

/// Kho quản lý và lưu trữ dữ liệu kiểm thử cử chỉ vuốt phím
public final class GlideBenchmarkStore: @unchecked Sendable {
    public static let shared = GlideBenchmarkStore()

    // Bộ 50 từ tiếng Việt tiêu biểu được cân bằng độ dài từ 2 đến 7 ký tự:
    // 2 ký tự (11 từ), 3 ký tự (11 từ), 4 ký tự (11 từ), 5 ký tự (8 từ), 6 ký tự (5 từ), 7 ký tự (4 từ)
    public static let default50Words: [GlideChallengeWord] = [
        // 1. Nhóm từ 2 ký tự (11 từ)
        GlideChallengeWord(targetWord: "đi", hintPath: "d - i", category: "Từ 2 ký tự", note: "d sang i"),
        GlideChallengeWord(targetWord: "có", hintPath: "c - o", category: "Từ 2 ký tự", note: "c sang o"),
        GlideChallengeWord(targetWord: "là", hintPath: "l - a", category: "Từ 2 ký tự", note: "l sang a cùng hàng ASDF"),
        GlideChallengeWord(targetWord: "và", hintPath: "v - a", category: "Từ 2 ký tự", note: "v sang a"),
        GlideChallengeWord(targetWord: "ra", hintPath: "r - a", category: "Từ 2 ký tự", note: "r sang a"),
        GlideChallengeWord(targetWord: "về", hintPath: "v - e", category: "Từ 2 ký tự", note: "v chéo lên e"),
        GlideChallengeWord(targetWord: "mẹ", hintPath: "m - e", category: "Từ 2 ký tự", note: "m chéo lên e"),
        GlideChallengeWord(targetWord: "ăn", hintPath: "a - n", category: "Từ 2 ký tự", note: "a chéo xuống n"),
        GlideChallengeWord(targetWord: "bố", hintPath: "b - o", category: "Từ 2 ký tự", note: "b chéo lên o"),
        GlideChallengeWord(targetWord: "ơi", hintPath: "o - i", category: "Từ 2 ký tự", note: "o sang i"),
        GlideChallengeWord(targetWord: "vợ", hintPath: "v - o", category: "Từ 2 ký tự", note: "v lướt lên o (tránh nhầm họ)"),

        // 2. Nhóm từ 3 ký tự (11 từ)
        GlideChallengeWord(targetWord: "tôi", hintPath: "t - o - i", category: "Từ 3 ký tự", note: "t sang o sang i"),
        GlideChallengeWord(targetWord: "làm", hintPath: "l - a - m", category: "Từ 3 ký tự", note: "l sang a sang m"),
        GlideChallengeWord(targetWord: "yêu", hintPath: "y - e - u", category: "Từ 3 ký tự", note: "y, e, u hàng trên cùng"),
        GlideChallengeWord(targetWord: "con", hintPath: "c - o - n", category: "Từ 3 ký tự", note: "c qua hàng giữa lên o, xuống n"),
        GlideChallengeWord(targetWord: "khi", hintPath: "k - h - i", category: "Từ 3 ký tự", note: "k qua h tới i"),
        GlideChallengeWord(targetWord: "vui", hintPath: "v - u - i", category: "Từ 3 ký tự", note: "v lên u sang i"),
        GlideChallengeWord(targetWord: "nói", hintPath: "n - o - i", category: "Từ 3 ký tự", note: "n lên o sang i"),
        GlideChallengeWord(targetWord: "học", hintPath: "h - o - c", category: "Từ 3 ký tự", note: "h lên o xuống c"),
        GlideChallengeWord(targetWord: "hoa", hintPath: "h - o - a", category: "Từ 3 ký tự", note: "h lên o sang a"),
        GlideChallengeWord(targetWord: "nhà", hintPath: "n - h - a", category: "Từ 3 ký tự", note: "n lên h sang a"),
        GlideChallengeWord(targetWord: "rất", hintPath: "r - a - t", category: "Từ 3 ký tự", note: "r xuống a lên t"),

        // 3. Nhóm từ 4 ký tự (11 từ)
        GlideChallengeWord(targetWord: "được", hintPath: "d - u - o - c", category: "Từ 4 ký tự", note: "d -> u -> o -> c"),
        GlideChallengeWord(targetWord: "phải", hintPath: "p - h - a - i", category: "Từ 4 ký tự", note: "p -> h -> a -> i"),
        GlideChallengeWord(targetWord: "mình", hintPath: "m - i - n - h", category: "Từ 4 ký tự", note: "m -> i -> n -> h"),
        GlideChallengeWord(targetWord: "biết", hintPath: "b - i - e - t", category: "Từ 4 ký tự", note: "b -> i -> e -> t"),
        GlideChallengeWord(targetWord: "muốn", hintPath: "m - u - o - n", category: "Từ 4 ký tự", note: "m -> u -> o -> n"),
        GlideChallengeWord(targetWord: "cuộc", hintPath: "c - u - o - c", category: "Từ 4 ký tự", note: "c -> u -> o -> c"),
        GlideChallengeWord(targetWord: "buồn", hintPath: "b - u - o - n", category: "Từ 4 ký tự", note: "b -> u -> o -> n"),
        GlideChallengeWord(targetWord: "nghĩ", hintPath: "n - g - h - i", category: "Từ 4 ký tự", note: "n -> g -> h -> i"),
        GlideChallengeWord(targetWord: "chào", hintPath: "c - h - a - o", category: "Từ 4 ký tự", note: "c -> h -> a -> o"),
        GlideChallengeWord(targetWord: "vàng", hintPath: "v - a - n - g", category: "Từ 4 ký tự", note: "v -> a -> n -> g"),
        GlideChallengeWord(targetWord: "rượu", hintPath: "r - u - o - u", category: "Từ 4 ký tự", note: "r -> u -> o -> u"),

        // 4. Nhóm từ 5 ký tự (8 từ)
        GlideChallengeWord(targetWord: "không", hintPath: "k - h - o - n - g", category: "Từ 5 ký tự", note: "k -> h -> o -> n -> g"),
        GlideChallengeWord(targetWord: "người", hintPath: "n - g - u - o - i", category: "Từ 5 ký tự", note: "n -> g -> u -> o -> i"),
        GlideChallengeWord(targetWord: "nhưng", hintPath: "n - h - u - n - g", category: "Từ 5 ký tự", note: "n -> h -> u -> n -> g"),
        GlideChallengeWord(targetWord: "chúng", hintPath: "c - h - u - n - g", category: "Từ 5 ký tự", note: "c -> h -> u -> n -> g"),
        GlideChallengeWord(targetWord: "nhiều", hintPath: "n - h - i - e - u", category: "Từ 5 ký tự", note: "n -> h -> i -> e -> u"),
        GlideChallengeWord(targetWord: "trong", hintPath: "t - r - o - n - g", category: "Từ 5 ký tự", note: "t -> r -> o -> n -> g"),
        GlideChallengeWord(targetWord: "trước", hintPath: "t - r - u - o - c", category: "Từ 5 ký tự", note: "t -> r -> u -> o -> c"),
        GlideChallengeWord(targetWord: "nhanh", hintPath: "n - h - a - n - h", category: "Từ 5 ký tự", note: "n -> h -> a -> n -> h"),

        // 5. Nhóm từ 6 ký tự (5 từ)
        GlideChallengeWord(targetWord: "thương", hintPath: "t - h - u - o - n - g", category: "Từ 6 ký tự", note: "t -> h -> u -> o -> n -> g"),
        GlideChallengeWord(targetWord: "trường", hintPath: "t - r - u - o - n - g", category: "Từ 6 ký tự", note: "t -> r -> u -> o -> n -> g"),
        GlideChallengeWord(targetWord: "chuyện", hintPath: "c - h - u - y - e - n", category: "Từ 6 ký tự", note: "c -> h -> u -> y -> e -> n"),
        GlideChallengeWord(targetWord: "khoảng", hintPath: "k - h - o - a - n - g", category: "Từ 6 ký tự", note: "k -> h -> o -> a -> n -> g"),
        GlideChallengeWord(targetWord: "phương", hintPath: "p - h - u - o - n - g", category: "Từ 6 ký tự", note: "p -> h -> u -> o -> n -> g"),

        // 6. Nhóm từ 6 - 7 ký tự thuần Việt (4 từ)
        GlideChallengeWord(targetWord: "nghiêng", hintPath: "n - g - h - i - e - n - g", category: "Từ 7 ký tự", note: "Từ thuần Việt 7 ký tự"),
        GlideChallengeWord(targetWord: "thuyền", hintPath: "t - h - u - y - e - n", category: "Từ 6 ký tự", note: "Từ thuần Việt 6 ký tự"),
        GlideChallengeWord(targetWord: "khuyên", hintPath: "k - h - u - y - e - n", category: "Từ 6 ký tự", note: "Từ thuần Việt 6 ký tự"),
        GlideChallengeWord(targetWord: "nguyện", hintPath: "n - g - u - y - e - n", category: "Từ 6 ký tự", note: "Từ thuần Việt 6 ký tự")
    ]

    // MARK: - Bộ 100 từ ngẫu nhiên cân bằng từ từ điển tiếng Việt
    public static func generateRandom100Words() -> [GlideChallengeWord] {
        let pool2 = [
            "là", "có", "đi", "và", "ra", "về", "ăn", "ơi", "mẹ", "bố",
            "vợ", "con", "ai", "ta", "do", "lo", "nó", "họ", "xa", "bé",
            "cả", "em", "ba", "má", "gì"
        ]
        let pool3 = [
            "tôi", "làm", "yêu", "vui", "nói", "học", "hoa", "nhà", "rất", "khi",
            "cho", "tay", "mắt", "cây", "mưa", "gió", "tim", "cơm", "đất", "mặt",
            "bạn", "xe", "bàn", "sao", "tiền", "mai", "đêm", "đầu", "chân", "tin"
        ]
        let pool4 = [
            "được", "phải", "mình", "biết", "muốn", "cuộc", "buồn", "nghĩ", "chào", "vàng",
            "rượu", "sách", "nước", "bước", "thời", "gian", "sống", "lòng", "nắng", "trời",
            "tiếng", "bóng", "sông", "ngày", "màu", "thần", "sáng", "chim", "trăng", "xanh"
        ]
        let pool5 = [
            "không", "người", "nhưng", "chúng", "nhiều", "trong", "trước", "nhanh", "thành", "hoàng",
            "chiếc", "nghĩa", "chiều", "tháng", "quanh", "ngang", "ngoài", "chuẩn", "trắng", "nghèo",
            "thẳng", "hướng", "trang", "đường", "thương"
        ]
        let pool6 = [
            "thương", "trường", "chuyện", "khoảng", "phương", "thuyền", "khuyên", "nguyện", "chuyển", "nghiệp",
            "khuyến", "truyền", "chuyên", "thường", "nghiệm", "khoáng", "nguyên", "nguyễn", "nghiêm", "khuynh"
        ]
        let pool7 = ["nghiêng"]

        func makeChallenge(word: String, category: String, note: String) -> GlideChallengeWord {
            let ascii = WordTrie.stripDiacritics(word).lowercased()
            let path = ascii.map { String($0) }.joined(separator: " - ")
            return GlideChallengeWord(targetWord: word, hintPath: path, category: category, note: note)
        }

        var results: [GlideChallengeWord] = []

        // 1. 15 từ 2 ký tự
        for w in pool2.shuffled().prefix(15) {
            results.append(makeChallenge(word: w, category: "Từ 2 ký tự", note: "Từ ngẫu nhiên 2 ký tự"))
        }
        // 2. 20 từ 3 ký tự
        for w in pool3.shuffled().prefix(20) {
            results.append(makeChallenge(word: w, category: "Từ 3 ký tự", note: "Từ ngẫu nhiên 3 ký tự"))
        }
        // 3. 25 từ 4 ký tự
        for w in pool4.shuffled().prefix(25) {
            results.append(makeChallenge(word: w, category: "Từ 4 ký tự", note: "Từ ngẫu nhiên 4 ký tự"))
        }
        // 4. 22 từ 5 ký tự
        for w in pool5.shuffled().prefix(22) {
            results.append(makeChallenge(word: w, category: "Từ 5 ký tự", note: "Từ ngẫu nhiên 5 ký tự"))
        }
        // 5. 17 từ 6 ký tự
        for w in pool6.shuffled().prefix(17) {
            results.append(makeChallenge(word: w, category: "Từ 6 ký tự", note: "Từ ngẫu nhiên 6 ký tự"))
        }
        // 6. 1 từ 7 ký tự
        for w in pool7 {
            results.append(makeChallenge(word: w, category: "Từ 7 ký tự", note: "Từ ngẫu nhiên 7 ký tự"))
        }

        return results
    }

    private var recordedSessions: [String: GlideRecordedSession] = [:] // key: targetWord
    private let lock = NSLock()
    private let fileName = "vboard_glide_50_recordings.json"

    private var storageURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fileName)
    }

    public init() {
        loadFromDisk()
    }

    /// Lấy tất cả phiên vuốt đã ghi nhận
    public func getAllSessions() -> [String: GlideRecordedSession] {
        lock.lock()
        defer { lock.unlock() }
        return recordedSessions
    }

    /// Lấy phiên vuốt của một từ
    public func getSession(for targetWord: String) -> GlideRecordedSession? {
        lock.lock()
        defer { lock.unlock() }
        return recordedSessions[targetWord.lowercased()]
    }

    /// Lưu lại phiên vuốt của một từ
    public func saveSession(_ session: GlideRecordedSession) {
        lock.lock()
        recordedSessions[session.targetWord.lowercased()] = session
        lock.unlock()
        saveToDisk()
    }

    /// Xóa phiên vuốt của một từ
    public func deleteSession(for targetWord: String) {
        lock.lock()
        recordedSessions.removeValue(forKey: targetWord.lowercased())
        lock.unlock()
        saveToDisk()
    }

    /// Xóa toàn bộ dữ liệu đã thu thập
    public func clearAll() {
        lock.lock()
        recordedSessions.removeAll()
        lock.unlock()
        saveToDisk()
    }

    /// Xuất toàn bộ bộ dữ liệu dưới dạng JSON
    public func exportJSON() -> String? {
        lock.lock()
        let sessions = Array(recordedSessions.values)
        lock.unlock()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(sessions),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }

    /// Nhập dữ liệu từ chuỗi JSON
    public func importJSON(_ jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else { return false }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let list = try? decoder.decode([GlideRecordedSession].self, from: data) else {
            return false
        }

        lock.lock()
        for session in list {
            recordedSessions[session.targetWord.lowercased()] = session
        }
        lock.unlock()
        saveToDisk()
        return true
    }

    /// Chạy lại toàn bộ kiểm thử các quỹ đạo đã lưu với thuật toán Engine hiện thời
    public func reevaluateAll(matchUnaccented: Bool = true) -> [GlideReevaluationResult] {
        lock.lock()
        let sessions = Array(recordedSessions.values)
        lock.unlock()

        var results: [GlideReevaluationResult] = []

        for session in sessions {
            let eval = GlideKinematicsTracker.evaluateTrajectory(
                samples: session.samples,
                targetWord: session.targetWord,
                matchUnaccented: matchUnaccented
            )

            let res = GlideReevaluationResult(
                targetWord: session.targetWord,
                category: session.category,
                oldMatch: session.isMatch,
                newMatch: eval.isMatch,
                oldRecognizedWord: session.recognizedWord,
                newRecognizedWord: eval.recognizedWord,
                newTopCandidates: eval.topCandidates,
                newExtractedKeySeq: String(eval.primarySeq)
            )
            results.append(res)
        }

        return results
    }

    // MARK: - Disk Persistence

    private func saveToDisk() {
        guard let url = storageURL else { return }
        lock.lock()
        let list = Array(recordedSessions.values)
        lock.unlock()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(list) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func loadFromDisk() {
        guard let url = storageURL, FileManager.default.fileExists(atPath: url.path) else { return }
        guard let data = try? Data(contentsOf: url) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let list = try? decoder.decode([GlideRecordedSession].self, from: data) {
            lock.lock()
            for s in list {
                recordedSessions[s.targetWord.lowercased()] = s
            }
            lock.unlock()
        }
    }
}

/// Kết quả so sánh khi tái đánh giá thuật toán
public struct GlideReevaluationResult: Identifiable, Sendable {
    public var id: String { targetWord }
    public let targetWord: String
    public let category: String
    public let oldMatch: Bool
    public let newMatch: Bool
    public let oldRecognizedWord: String
    public let newRecognizedWord: String
    public let newTopCandidates: [String]
    public let newExtractedKeySeq: String

    public var statusChange: String {
        if !oldMatch && newMatch {
            return "CẢI THIỆN (FAIL ➔ PASS)"
        } else if oldMatch && !newMatch {
            return "THỤT LÙI (PASS ➔ FAIL)"
        } else if newMatch {
            return "DUY TRÌ ĐẠT (PASS)"
        } else {
            return "VẪN LỖI (FAIL)"
        }
    }
}
