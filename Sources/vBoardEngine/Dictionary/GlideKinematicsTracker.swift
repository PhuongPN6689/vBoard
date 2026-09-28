//
//  GlideKinematicsTracker.swift
//  vBoardKeyboard
//
//  Bộ phân tích động học quỹ đạo vuốt phím (Kinematics & Spatial-Temporal Tracking):
//  1. Ghi nhận mẫu chạm toạ độ + timestamp
//  2. Tính toán Profile vận tốc (Velocity) và Thời gian dừng (Dwell Time)
//  3. Nhận diện cực tiểu vận tốc (Local Velocity Dip) cho các phím thẳng hàng (ví dụ: 'khá' k -> h -> a)
//  4. Nhận diện góc bẻ cua (Angular Deflection) cho các từ đổi hướng (ví dụ: 'khi' cua lên i)
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

#if canImport(UIKit)
import UIKit
#endif

public struct GlideSample: Codable, Sendable {
    public let point: CGPoint
    public let timestamp: CFTimeInterval
    public let keyChar: Character

    public init(point: CGPoint, timestamp: CFTimeInterval, keyChar: Character) {
        self.point = point
        self.timestamp = timestamp
        self.keyChar = keyChar
    }

    enum CodingKeys: String, CodingKey {
        case x, y, timestamp, keyChar
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Double.self, forKey: .x)
        let y = try container.decode(Double.self, forKey: .y)
        self.point = CGPoint(x: x, y: y)
        self.timestamp = try container.decode(Double.self, forKey: .timestamp)
        let charStr = try container.decode(String.self, forKey: .keyChar)
        self.keyChar = charStr.first ?? " "
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Double(point.x), forKey: .x)
        try container.encode(Double(point.y), forKey: .y)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(String(keyChar), forKey: .keyChar)
    }
}

public struct GlideSessionStats: Codable, Sendable {
    public let durationMs: Double
    public let totalDistancePx: Double
    public let avgVelocityPxPerSec: Double
    public let peakVelocityPxPerSec: Double
    public let sampleCount: Int

    public init(durationMs: Double, totalDistancePx: Double, avgVelocityPxPerSec: Double, peakVelocityPxPerSec: Double, sampleCount: Int) {
        self.durationMs = durationMs
        self.totalDistancePx = totalDistancePx
        self.avgVelocityPxPerSec = avgVelocityPxPerSec
        self.peakVelocityPxPerSec = peakVelocityPxPerSec
        self.sampleCount = sampleCount
    }
}

public final class GlideKinematicsTracker: @unchecked Sendable {
    public static let shared = GlideKinematicsTracker()

    private var samples: [GlideSample] = []
    private let lock = NSLock()
    public private(set) var lastSessionStats: GlideSessionStats?

    public var recordedSamples: [GlideSample] {
        lock.lock()
        defer { lock.unlock() }
        return samples
    }

    public init() {}

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        samples.removeAll()
    }

    public func addSample(point: CGPoint, timestamp: CFTimeInterval, keyChar: Character) {
        lock.lock()
        defer { lock.unlock() }
        let sample = GlideSample(point: point, timestamp: timestamp, keyChar: keyChar)
        samples.append(sample)
    }

    /// Trích xuất danh sách phím mục tiêu đã lọc bỏ các phím lướt qua (Transit keys)
    public func extractTargetKeySequence() -> (primarySequence: [Character], fullSequence: [Character]) {
        lock.lock()
        defer { lock.unlock() }

        guard samples.count >= 2 else {
            let chars = samples.map { $0.keyChar }
            return (chars, chars)
        }

        let fullRaw = deduplicateConsecutive(samples.map { $0.keyChar })
        guard samples.count >= 4 else {
            return (fullRaw, fullRaw)
        }

        // 1. Tính vận tốc tức thời của từng mẫu
        var velocities: [CGFloat] = [0.0]
        velocities.reserveCapacity(samples.count)

        var totalDistance: CGFloat = 0.0
        for i in 1..<samples.count {
            let prev = samples[i - 1]
            let curr = samples[i]
            let dt = max(0.001, curr.timestamp - prev.timestamp)
            let dist = hypot(curr.point.x - prev.point.x, curr.point.y - prev.point.y)
            totalDistance += dist
            let v = dist / CGFloat(dt)
            velocities.append(v)
        }

        let avgVelocity = velocities.reduce(0, +) / CGFloat(velocities.count)
        let peakVelocity = velocities.max() ?? 0.0
        let totalDuration = max(0.001, (samples.last?.timestamp ?? 0) - (samples.first?.timestamp ?? 0))

        self.lastSessionStats = GlideSessionStats(
            durationMs: totalDuration * 1000.0,
            totalDistancePx: Double(totalDistance),
            avgVelocityPxPerSec: Double(avgVelocity),
            peakVelocityPxPerSec: Double(peakVelocity),
            sampleCount: samples.count
        )

        // 2. Gom nhóm các mẫu theo từng phím được ghé thăm (Key Visit)
        struct KeyVisitGroup {
            let char: Character
            var points: [CGPoint]
            var duration: CFTimeInterval
            var minVelocity: CGFloat
            var avgVelocity: CGFloat
            var sampleIndices: [Int]
        }

        var visits: [KeyVisitGroup] = []
        var currentGroupIndices: [Int] = [0]
        var currentChar = samples[0].keyChar

        for i in 1..<samples.count {
            if samples[i].keyChar == currentChar {
                currentGroupIndices.append(i)
            } else {
                // Đóng nhóm trước
                let duration = samples[currentGroupIndices.last!].timestamp - samples[currentGroupIndices.first!].timestamp
                let groupVelocities = currentGroupIndices.map { velocities[$0] }
                let minV = groupVelocities.min() ?? 0
                let avgV = groupVelocities.reduce(0, +) / CGFloat(groupVelocities.count)
                let pts = currentGroupIndices.map { samples[$0].point }

                visits.append(KeyVisitGroup(
                    char: currentChar,
                    points: pts,
                    duration: duration,
                    minVelocity: minV,
                    avgVelocity: avgV,
                    sampleIndices: currentGroupIndices
                ))

                // Mở nhóm mới
                currentChar = samples[i].keyChar
                currentGroupIndices = [i]
            }
        }

        // Đóng nhóm cuối cùng
        if !currentGroupIndices.isEmpty {
            let duration = samples[currentGroupIndices.last!].timestamp - samples[currentGroupIndices.first!].timestamp
            let groupVelocities = currentGroupIndices.map { velocities[$0] }
            let minV = groupVelocities.min() ?? 0
            let avgV = groupVelocities.reduce(0, +) / CGFloat(groupVelocities.count)
            let pts = currentGroupIndices.map { samples[$0].point }

            visits.append(KeyVisitGroup(
                char: currentChar,
                points: pts,
                duration: duration,
                minVelocity: minV,
                avgVelocity: avgV,
                sampleIndices: currentGroupIndices
            ))
        }

        guard visits.count >= 2 else {
            return (fullRaw, fullRaw)
        }

        // 3. Phân loại Phím Mục Tiêu (Target Key) vs Phím Lướt Qua (Transit Key)
        var targetChars: [Character] = []

        for (idx, visit) in visits.enumerated() {
            // Phím đầu và phím cuối luôn là mục tiêu chắc chắn 100%
            if idx == 0 || idx == visits.count - 1 {
                targetChars.append(visit.char)
                continue
            }

            // Phân biệt phiên vuốt nhanh (Peak > 1000 px/s hoặc Avg > 550 px/s) hay bình thường
            let isFastSession = peakVelocity > 1000.0 || avgVelocity > 550.0
            let dwellThreshold: CFTimeInterval = isFastSession ? 0.018 : 0.050
            let dwellVelFactor: CGFloat = isFastSession ? 0.85 : 0.75
            let dipVelFactor: CGFloat = isFastSession ? 0.68 : 0.55

            // Tiêu chí A: Thời gian dừng (Dwell Time) tại phím đủ lớn VÀ vận tốc tương đối thấp
            let isDwell = visit.duration >= dwellThreshold && visit.avgVelocity < (avgVelocity * dwellVelFactor)

            // Tiêu chí B: Điểm cực tiểu vận tốc (Local Velocity Dip)
            // Ngón tay giảm tốc rõ rệt khi đến phím mục tiêu (như 'h' trong từ 'khá' k -> h -> a)
            let isVelocityDip = visit.minVelocity < (avgVelocity * dipVelFactor)

            // Tiêu chí C: Góc bẻ cua (Angular Deflection)
            var hasAngleDeflection = false
            if idx > 0 && idx < visits.count - 1 {
                let pPrev = visits[idx - 1].points.last ?? .zero
                let pCurr = visit.points.first ?? .zero
                let pNext = visits[idx + 1].points.first ?? .zero

                let v1 = CGPoint(x: pCurr.x - pPrev.x, y: pCurr.y - pPrev.y)
                let v2 = CGPoint(x: pNext.x - pCurr.x, y: pNext.y - pCurr.y)

                let dot = v1.x * v2.x + v1.y * v2.y
                let mag1 = hypot(v1.x, v1.y)
                let mag2 = hypot(v2.x, v2.y)

                if mag1 > 5.0 && mag2 > 5.0 {
                    let cosAngle = max(-1.0, min(1.0, dot / (mag1 * mag2)))
                    let angleDeg = acos(cosAngle) * 180.0 / .pi
                    if angleDeg > 30.0 {
                        hasAngleDeflection = true
                    }
                }
            }

            // Nếu phím lướt qua với vận tốc rất cao và thời gian dừng cực ngắn (chỉ 1 mẫu duy nhất),
            // thì đây là phím lướt qua (Transit Key), không thể là phím mục tiêu!
            let blatantDuration: CFTimeInterval = isFastSession ? 0.012 : 0.028
            let isBlatantTransit = visit.duration < blatantDuration && visit.avgVelocity > (avgVelocity * 1.15)

            // Điều kiện chấp nhận phím mục tiêu trung gian:
            // 1. Phải dừng đủ lâu (Dwell) HOẶC có cực tiểu vận tốc rõ rệt (Velocity Dip)
            // 2. HOẶC bẻ cua rõ rệt (> 30 độ) NHƯNG vận tốc không được ở mức lướt bay qua (isBlatantTransit = false)
            let minDeflectionDuration: CFTimeInterval = isFastSession ? 0.010 : 0.025
            let isTargetKey = !isBlatantTransit && (isDwell || isVelocityDip || (hasAngleDeflection && visit.duration >= minDeflectionDuration))

            if isTargetKey {
                if targetChars.last != visit.char {
                    targetChars.append(visit.char)
                }
            }
        }

        // Đảm bảo kết quả lọc có ít nhất 2 phím (đầu và cuối)
        let primary = targetChars.count >= 2 ? targetChars : fullRaw
        return (primary, fullRaw)
    }

    private func deduplicateConsecutive(_ chars: [Character]) -> [Character] {
        var result: [Character] = []
        for ch in chars {
            if result.last != ch {
                result.append(ch)
            }
        }
        return result
    }

    /// Đánh giá chuỗi mẫu toạ độ vuốt và đối chiếu với từ mục tiêu
    public static func evaluateTrajectory(
        samples: [GlideSample],
        targetWord: String,
        matchUnaccented: Bool = true
    ) -> (isMatch: Bool, topCandidates: [String], recognizedWord: String, primarySeq: [Character], fullSeq: [Character], stats: GlideSessionStats?) {
        guard samples.count >= 2 else {
            return (false, [], "", [], [], nil)
        }

        let tracker = GlideKinematicsTracker()
        for s in samples {
            tracker.addSample(point: s.point, timestamp: s.timestamp, keyChar: s.keyChar)
        }

        let (primary, full) = tracker.extractTargetKeySequence()
        let rawMatches = WordTrie.shared.matchGlide(keySequence: primary, fullSequence: full, limit: 5)

        let topWord = rawMatches.first ?? ""
        let isMatch: Bool
        if matchUnaccented {
            let recAscii = WordTrie.stripDiacritics(topWord).lowercased()
            let targetAscii = WordTrie.stripDiacritics(targetWord).lowercased()
            isMatch = (!topWord.isEmpty && recAscii == targetAscii)
        } else {
            isMatch = (!topWord.isEmpty && topWord.lowercased() == targetWord.lowercased())
        }

        return (isMatch, rawMatches, topWord, primary, full, tracker.lastSessionStats)
    }
}
