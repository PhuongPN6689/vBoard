//
//  GlideTrajectorySimulator.swift
//  vBoardEngine
//
//  Bộ mô phỏng chuyển động ngón tay khi vuốt (Kinematic Trajectory Generator):
//  Nhận vào: Từ mục tiêu (Word) + Vận tốc vuốt (Velocity: Slow / Normal / Fast)
//  Sinh ra: Tập mẫu toạ độ thực (x, y, timestamp, key) theo mô hình động học thực tế:
//    - Dwell time (chậm lại / dừng) tại các phím mục tiêu
//    - Lướt nhanh qua các phím trung gian (Transit keys)
//    - Điểm cực tiểu vận tốc (Velocity dip) trên các phím thẳng hàng
//    - Biến thiên góc (Angular deflection) tại các khúc bẻ cua
//

import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public enum GlideSpeedProfile: String, CaseIterable, Sendable {
    case slow = "Chậm (Cẩn thận, ~400 px/s)"
    case normal = "Bình thường (~850 px/s)"
    case fast = "Vuốt lướt nhanh (~1400 px/s)"

    public var speedPxPerSec: CGFloat {
        switch self {
        case .slow: return 400.0
        case .normal: return 850.0
        case .fast: return 1400.0
        }
    }

    public var targetDwellTimeSec: CFTimeInterval {
        switch self {
        case .slow: return 0.090 // 90ms dừng ở phím mục tiêu
        case .normal: return 0.065 // 65ms
        case .fast: return 0.040 // 40ms
        }
    }
}

/// Trạng thái động học riêng tại từng điểm phím trên quỹ đạo vuốt
public enum KeyKinematicState: Sendable {
    case startPoint               // Điểm bắt đầu vuốt: Chạm xuống, dừng cẩn thận (dwell 70-100ms, v -> 0)
    case endPoint                 // Điểm kết thúc vuốt: Giảm tốc, dừng lại trước khi nhấc tay (dwell 60-90ms, v -> 0)
    case fastTransit(speedPxPerSec: CGFloat) // Điểm lướt ngang qua rất nhanh: Vận tốc cao (1200-2000 px/s), dwell cực ngắn (5-10ms)
    case slowTarget(dwellMs: Double)         // Điểm mục tiêu có chủ ý (như phím thẳng hàng): Giảm tốc rõ rệt (velocity dip), dwell lâu (60-90ms)
}

public final class GlideTrajectorySimulator: Sendable {
    public static let shared = GlideTrajectorySimulator()

    // Toạ độ giả định chuẩn hoá màn hình bàn phím (Width: 390pt, Height: 220pt)
    // Row 0 (Q..P): y = 35
    // Row 1 (A..L): y = 95
    // Row 2 (Z..M): y = 155
    public static let keyCenters: [Character: CGPoint] = [
        "q": CGPoint(x: 19.5, y: 35), "w": CGPoint(x: 58.5, y: 35), "e": CGPoint(x: 97.5, y: 35),
        "r": CGPoint(x: 136.5, y: 35), "t": CGPoint(x: 175.5, y: 35), "y": CGPoint(x: 214.5, y: 35),
        "u": CGPoint(x: 253.5, y: 35), "i": CGPoint(x: 292.5, y: 35), "o": CGPoint(x: 331.5, y: 35),
        "p": CGPoint(x: 370.5, y: 35),

        "a": CGPoint(x: 39.0, y: 95), "s": CGPoint(x: 78.0, y: 95), "d": CGPoint(x: 117.0, y: 95),
        "f": CGPoint(x: 156.0, y: 95), "g": CGPoint(x: 195.0, y: 95), "h": CGPoint(x: 234.0, y: 95),
        "j": CGPoint(x: 273.0, y: 95), "k": CGPoint(x: 312.0, y: 95), "l": CGPoint(x: 351.0, y: 95),

        "z": CGPoint(x: 78.0, y: 155), "x": CGPoint(x: 117.0, y: 155), "c": CGPoint(x: 156.0, y: 155),
        "v": CGPoint(x: 195.0, y: 155), "b": CGPoint(x: 234.0, y: 155), "n": CGPoint(x: 273.0, y: 155),
        "m": CGPoint(x: 312.0, y: 155)
    ]

    public init() {}

    /// Tìm phím gần nhất với một toạ độ (x, y)
    public static func nearestKey(to point: CGPoint) -> Character {
        var bestChar: Character = " "
        var bestDist: CGFloat = CGFloat.greatestFiniteMagnitude
        for (char, center) in keyCenters {
            let dist = hypot(point.x - center.x, point.y - center.y)
            if dist < bestDist {
                bestDist = dist
                bestChar = char
            }
        }
        return bestChar
    }

    /// Tự động sinh chuỗi mẫu GlideSample từ chuỗi phím mục tiêu (đã bóc tách ASCII)
    /// theo profile vận tốc chỉ định
    public func generateSamples(
        targetWord: String,
        profile: GlideSpeedProfile = .normal
    ) -> [GlideSample] {
        let ascii = WordTrie.stripDiacritics(targetWord).lowercased()
        let chars = Array(ascii).filter { Self.keyCenters[$0] != nil }
        guard chars.count >= 2 else { return [] }

        var samples: [GlideSample] = []
        var currentTime: CFTimeInterval = 0.0

        for i in 0..<chars.count {
            let targetChar = chars[i]
            let center = Self.keyCenters[targetChar]!

            // 1. Giai đoạn Dwell (Dừng / giảm tốc) tại phím mục tiêu
            let dwellDuration = profile.targetDwellTimeSec
            let dwellSteps = max(2, Int(dwellDuration / 0.016)) // 60Hz lấy mẫu (~16ms mỗi sample)
            for d in 0..<dwellSteps {
                let jitterX = center.x + CGFloat((d % 3) - 1) * 1.5
                let jitterY = center.y + CGFloat((d % 2) - 1) * 1.5
                samples.append(GlideSample(
                    point: CGPoint(x: jitterX, y: jitterY),
                    timestamp: currentTime,
                    keyChar: targetChar
                ))
                currentTime += dwellDuration / Double(dwellSteps)
            }

            // 2. Giai đoạn bay lướt (Transit flight) sang phím tiếp theo
            if i < chars.count - 1 {
                let nextChar = chars[i + 1]
                let nextCenter = Self.keyCenters[nextChar]!

                let distance = hypot(nextCenter.x - center.x, nextCenter.y - center.y)
                let transitDuration = distance / profile.speedPxPerSec
                let flightSteps = max(2, Int(transitDuration / 0.016))
                let dtFlight = transitDuration / Double(flightSteps + 1)

                for f in 1...flightSteps {
                    let progress = CGFloat(f) / CGFloat(flightSteps + 1)
                    let interpX = center.x + (nextCenter.x - center.x) * progress
                    let interpY = center.y + (nextCenter.y - center.y) * progress
                    let currentPt = CGPoint(x: interpX, y: interpY)
                    let hitChar = Self.nearestKey(to: currentPt)

                    currentTime += dtFlight
                    samples.append(GlideSample(
                        point: currentPt,
                        timestamp: currentTime,
                        keyChar: hitChar
                    ))
                }
                currentTime += dtFlight
            }
        }

        return samples
    }

    /// Tự động sinh quỹ đạo với cấu hình vận tốc chi tiết cho TỪNG PHÍM (Per-Key Kinematic Profile):
    /// Ví dụ cho từ 'vợ' khi ngón tay lướt v -> h -> o:
    ///   - Điểm 'v': bắt đầu chạm xuống (startPoint)
    ///   - Điểm 'h': bay qua cực nhanh (fastTransit, speed: 1600 px/s, không dwell)
    ///   - Điểm 'o': kết thúc, giảm tốc dừng lại (endPoint, dwell 80ms)
    public func generatePerKeyTrajectory(
        waypoints: [(char: Character, state: KeyKinematicState)]
    ) -> [GlideSample] {
        guard waypoints.count >= 2 else { return [] }

        var samples: [GlideSample] = []
        var currentTime: CFTimeInterval = 0.0

        for i in 0..<waypoints.count {
            let (targetChar, state) = waypoints[i]
            guard let center = Self.keyCenters[Character(targetChar.lowercased())] else { continue }

            // 1. Dwell time tại điểm này tuỳ theo trạng thái động học
            let dwellDuration: CFTimeInterval
            switch state {
            case .startPoint:
                dwellDuration = 0.080 // 80ms
            case .endPoint:
                dwellDuration = 0.085 // 85ms
            case .slowTarget(let dwellMs):
                dwellDuration = dwellMs / 1000.0
            case .fastTransit:
                dwellDuration = 0.0 // Phím lướt ngang tuyệt đối KHÔNG có dwell time!
            }

            if dwellDuration > 0.001 {
                let dwellSteps = max(1, Int(dwellDuration / 0.016))
                for d in 0..<dwellSteps {
                    let jitterX = center.x + CGFloat((d % 3) - 1) * 1.0
                    let jitterY = center.y + CGFloat((d % 2) - 1) * 1.0
                    samples.append(GlideSample(
                        point: CGPoint(x: jitterX, y: jitterY),
                        timestamp: currentTime,
                        keyChar: targetChar
                    ))
                    currentTime += dwellDuration / Double(dwellSteps)
                }
            }

            // 2. Di chuyển sang điểm kế tiếp
            if i < waypoints.count - 1 {
                let next = waypoints[i + 1]
                guard let nextCenter = Self.keyCenters[Character(next.char.lowercased())] else { continue }

                let distance = hypot(nextCenter.x - center.x, nextCenter.y - center.y)

                // Vận tốc đoạn di chuyển: Nếu điểm đi HOẶC điểm đến là lướt nhanh thì đoạn bay sẽ giữ tốc độ cao
                let transitSpeed: CGFloat
                if case .fastTransit(let spd) = state {
                    transitSpeed = spd
                } else if case .fastTransit(let spd) = next.state {
                    transitSpeed = spd
                } else {
                    transitSpeed = 750.0
                }

                let transitDuration = max(0.010, distance / transitSpeed)
                let flightSteps = max(2, Int(transitDuration / 0.016))
                let dtFlight = transitDuration / Double(flightSteps + 1)

                for f in 1...flightSteps {
                    let progress = CGFloat(f) / CGFloat(flightSteps + 1)
                    let interpX = center.x + (nextCenter.x - center.x) * progress
                    let interpY = center.y + (nextCenter.y - center.y) * progress
                    let currentPt = CGPoint(x: interpX, y: interpY)
                    let hitChar = Self.nearestKey(to: currentPt)

                    currentTime += dtFlight
                    samples.append(GlideSample(
                        point: currentPt,
                        timestamp: currentTime,
                        keyChar: hitChar
                    ))
                }
                currentTime += dtFlight
            }
        }

        return samples
    }

    /// Đánh giá mô phỏng theo kịch bản vận tốc từng phím tự định nghĩa
    public func simulateCustomKinematics(
        targetWord: String,
        waypoints: [(char: Character, state: KeyKinematicState)],
        matchUnaccented: Bool = true
    ) -> (isMatch: Bool, topCandidates: [String], recognizedWord: String, extractedPrimary: [Character], stats: GlideSessionStats?) {
        let samples = generatePerKeyTrajectory(waypoints: waypoints)
        guard !samples.isEmpty else {
            return (false, [], "", [], nil)
        }

        let tracker = GlideKinematicsTracker()
        for sample in samples {
            tracker.addSample(point: sample.point, timestamp: sample.timestamp, keyChar: sample.keyChar)
        }

        let (primary, full) = tracker.extractTargetKeySequence()
        let rawMatches = WordTrie.shared.matchGlide(keySequence: primary, fullSequence: full, limit: 3)

        let topWord = rawMatches.first ?? ""
        let isMatch: Bool
        if matchUnaccented {
            let recAscii = WordTrie.stripDiacritics(topWord).lowercased()
            let targetAscii = WordTrie.stripDiacritics(targetWord).lowercased()
            isMatch = (!topWord.isEmpty && recAscii == targetAscii)
        } else {
            isMatch = (!topWord.isEmpty && topWord.lowercased() == targetWord.lowercased())
        }

        return (isMatch, rawMatches, topWord, primary, tracker.lastSessionStats)
    }

    /// Chạy kiểm thử tự động một từ với vận tốc đầu vào cho trước
    /// Trả về: (isMatch, topCandidates, stats, recognizedWord)
    public func simulateAndEvaluate(
        targetWord: String,
        profile: GlideSpeedProfile = .normal,
        matchUnaccented: Bool = true
    ) -> (isMatch: Bool, topCandidates: [String], recognizedWord: String, stats: GlideSessionStats?) {
        let samples = generateSamples(targetWord: targetWord, profile: profile)
        guard !samples.isEmpty else {
            return (false, [], "", nil)
        }

        let tracker = GlideKinematicsTracker()
        for sample in samples {
            tracker.addSample(point: sample.point, timestamp: sample.timestamp, keyChar: sample.keyChar)
        }

        let (primary, full) = tracker.extractTargetKeySequence()
        let rawMatches = WordTrie.shared.matchGlide(keySequence: primary, fullSequence: full, limit: 3)

        let topWord = rawMatches.first ?? ""
        let isMatch: Bool
        if matchUnaccented {
            let recAscii = WordTrie.stripDiacritics(topWord).lowercased()
            let targetAscii = WordTrie.stripDiacritics(targetWord).lowercased()
            isMatch = (!topWord.isEmpty && recAscii == targetAscii)
        } else {
            isMatch = (!topWord.isEmpty && topWord.lowercased() == targetWord.lowercased())
        }

        return (isMatch, rawMatches, topWord, tracker.lastSessionStats)
    }
}
