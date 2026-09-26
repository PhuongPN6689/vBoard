//
//  TypoCorrectionManager.swift
//  vBoardEngine
//
//  Bộ quản lý sửa lỗi chính tả thông minh:
//  1. Fast Typo Cache (O(1)): Danh mục lỗi gõ sai Telex/viết tắt phổ biến nhất.
//  2. Telex Phonotactics Normalizer: Tự động gom và tái cấu trúc các phím Telex bị gõ đảo thứ tự (ví dụ: nhwung -> nhưng, haowcj -> hoặc).
//

import Foundation

public final class TypoCorrectionManager: @unchecked Sendable {
    public static let shared = TypoCorrectionManager()

    // MARK: - 1. Top Common Typo & Slang Cache (O(1)) (250+ từ viết tắt, đảo phím và teencode)
    private let commonTypoCache: [String: String] = [
        // --- 1. Nhóm đảo phím w (mũ/móc) phổ biến nhất ---
        "nhwung": "nhưng", "nhuwng": "nhưng", "nhunwg": "nhưng", "nhwu": "như", "nhwun": "nhưng",
        "thwong": "thương", "thuwong": "thương", "thuwog": "thương", "thwơng": "thương", "thuwng": "thương",
        "trwocs": "trước", "truowcs": "trước", "trwoc": "trước", "truocs": "trước", "trwowcs": "trước",
        "ngwowi": "người", "nguwowi": "người", "nguowfi": "người", "ngwơi": "người", "nguoif": "người", "nguwoif": "người",
        "dduowcj": "được", "duowcj": "được", "dduowc": "được", "duowc": "được", "đuowcj": "được", "đuowc": "được", "đuwocj": "được", "duwocj": "được", "dduojc": "được",
        "nuowcs": "nước", "nwocs": "nước", "nuwocs": "nước", "nưocs": "nước",
        "bwoocs": "bước", "buowcs": "bước", "bwowcs": "bước", "buwocs": "bước",
        "dwowi": "dưới", "duowis": "dưới", "dwơi": "dưới", "duwois": "dưới", "dwois": "dưới",
        "rwong": "rừng", "ruowng": "rường", "rwưng": "rừng", "ruwng": "rừng",
        "phwong": "phương", "phuwong": "phương", "phuwog": "phương",
        "lwong": "lương", "luowng": "lương", "luongw": "lương",
        "twong": "tương", "tuowng": "tương", "tuongw": "tương",
        "gwong": "gương", "guowng": "gương", "guongw": "gương",
        "chwong": "chương", "chuwong": "chương", "chuongw": "chương",
        "vwong": "vương", "vuowng": "vương",
        "xwong": "xương", "xuowng": "xương",
        "mwong": "mương", "muowng": "mương",
        "đwong": "đường", "dduowng": "đường", "duowng": "đường", "đuwong": "đường",

        // --- 2. Nhóm đảo phím nguyên âm + phím dấu Telex ---
        "haowcj": "hoặc", "hoawcj": "hoặc", "hoajc": "hoặc", "haowc": "hoặc", "hoajck": "hoặc",
        "khoong": "không", "khong": "không", "khoogn": "không", "khoon": "không", "khôgn": "không",
        "trogn": "trong", "trnog": "trong", "torng": "trong", "tronf": "tròng",
        "tooi": "tôi", "tio": "tôi", "toio": "tôi", "toii": "tôi",
        "bieets": "biết", "beit": "biết", "beits": "biết", "bietes": "biết", "biet": "biết",
        "vieejt": "Việt", "veejt": "Việt", "vieetj": "Việt", "veit": "Việt", "viet": "Việt",
        "chieecs": "chiếc", "cehiec": "chiếc", "chiesc": "chiếc", "chiec": "chiếc",
        "cuoocs": "cuộc", "couc": "cuộc", "cuocj": "cuộc", "cuoc": "cuộc",
        "tuyệt": "tuyệt", "tuyeetj": "tuyệt", "tuyetj": "tuyệt", "tyueetj": "tuyệt", "tuyet": "tuyệt",
        "chuyeenj": "chuyện", "chuyenj": "chuyện", "chyueenj": "chuyện", "chuyen": "chuyện",
        "khuyeens": "khuyến", "khuyens": "khuyến",
        "ngheej": "nghệ", "ngehj": "nghệ", "nghej": "nghệ", "nghe": "nghe",
        "nghiej": "nghiệp", "nghieepj": "nghiệp", "nghiep": "nghiệp", "ngehip": "nghiệp",
        "tieens": "tiến", "tiens": "tiến", "tien": "tiền",
        "tieengs": "tiếng", "tinegs": "tiếng", "tiengs": "tiếng", "tieng": "tiếng",
        "thieets": "thiết", "thiets": "thiết", "thiet": "thiết",
        "dieens": "diễn", "dieexn": "diễn", "dien": "điện",
        "khieens": "khiến", "khiens": "khiến",
        "bieens": "biến", "biens": "biến",
        "chieens": "chiến", "chiens": "chiến",
        "mieens": "miễn", "mieexn": "miễn",
        "nhiieeu": "nhiều", "nhieeu": "nhiều", "nhieeuf": "nhiều", "nhieuf": "nhiều", "nhieu": "nhiều",
        "ddieeuf": "điều", "dieeuf": "điều", "dieuf": "điều", "đieeuf": "điều", "dieu": "điều",
        "hieeu": "hiểu", "hieeuj": "hiệu", "hieeur": "hiểu", "hieeus": "hiếu", "hieu": "hiểu",
        "yeue": "yêu", "yeu": "yêu", "yeueu": "yêu",
        "ngoaif": "ngoài", "ngoai": "ngoài", "ngaoif": "ngoài",
        "toaif": "toài", "toanf": "toàn", "toans": "toán",
        "hoaif": "hoài", "hoanf": "hoàn", "hoangf": "hoàng",
        "quans": "quán", "quanf": "quàn", "quaj": "quạ",

        // --- 3. Nhóm viết tắt, chat slang, teencode người Việt dùng hàng ngày ---
        "ko": "không", "kô": "không", "hok": "không", "hổng": "không", "khg": "không", "k": "không", "kg": "không", "kh": "không",
        "dc": "được", "đc": "được", "dk": "được", "đk": "được", "duc": "được",
        "bik": "biết", "bit": "biết", "pít": "biết", "pit": "biết",
        "ntn": "như thế nào", "theenao": "thế nào",
        "ms": "mới", "moi": "mới", "mowis": "mới",
        "cx": "cũng", "cug": "cũng", "cugx": "cũng",
        "vs": "với", "voi": "với", "vois": "với",
        "j": "gì", "gi": "gì", "ji": "gì", "z": "gì",
        "r": "rồi", "rùi": "rồi", "roi": "rồi", "oy": "rồi", "rooi": "rồi",
        "wa": "quá", "woa": "quá", "qua": "quá",
        "bun": "buồn", "poon": "buồn", "buon": "buồn",
        "chx": "chưa", "chua": "chưa", "chwa": "chưa",
        "thui": "thôi", "thoii": "thôi", "thoi": "thôi",
        "lun": "luôn", "luon": "luôn", "luonw": "luôn",
        "ty": "tình yêu", "ny": "người yêu", "cr": "crush", "ex": "người yêu cũ",
        "tks": "cảm ơn", "tks u": "cảm ơn bạn", "cảm ơn": "cảm ơn", "camon": "cảm ơn", "cmon": "cảm ơn", "thank": "cảm ơn", "thanks": "cảm ơn", "thx": "cảm ơn",
        "h": "giờ", "gio": "giờ", "h`": "giờ",
        "ae": "anh em", "ace": "anh chị em", "e": "em", "a": "anh",
        "mn": "mọi người", "moi nguoi": "mọi người", "mng": "mọi người",
        "đt": "điện thoại", "dt": "điện thoại", "dthoai": "điện thoại",
        "nv": "nhân viên", "nvien": "nhân viên",
        "cv": "công việc", "ccong viec": "công việc",
        "ib": "nhắn tin", "inbox": "nhắn tin",
        "rep": "trả lời", "tl": "trả lời", "tlời": "trả lời",
        "acc": "tài khoản", "tk": "tài khoản", "acount": "tài khoản",
        "pass": "mật khẩu", "mk": "mật khẩu", "pwd": "mật khẩu",
        "stk": "số tài khoản",
        "kb": "kết bạn", "fb": "Facebook", "zl": "Zalo", "ytb": "YouTube", "tt": "TikTok", "gg": "Google",
        "ns": "nói", "ngta": "người ta", "kta": "chúng ta", "m": "mình", "mik": "mình", "minh": "mình",
        "uk": "ừ", "uhm": "ừ", "um": "ừ", "uh": "ừ", "oke": "ok", "oki": "ok", "okie": "ok",
        "chcs": "chúc", "chuc": "chúc", "snvv": "sinh nhật vui vẻ", "hpbd": "chúc mừng sinh nhật", "cmsn": "chúc mừng sinh nhật",
        "gđ": "gia đình", "gd": "gia đình", "bv": "bệnh viện", "ks": "khách sạn", "tp": "thành phố",
        "hn": "hôm nay", "hnay": "hôm nay", "t2": "thứ hai", "t3": "thứ ba", "t4": "thứ tư", "t5": "thứ năm", "t6": "thứ sáu", "t7": "thứ bảy", "cn": "chủ nhật",
        "qtqđ": "quá trời quá đất", "clgt": "cái gì thế", "vch": "vãi chưởng", "vc": "vãi chưởng", "vl": "vãi",
        "hcm": "Hồ Chí Minh", "sg": "Sài Gòn", "hnoi": "Hà Nội", "dn": "Đà Nẵng", "vn": "Việt Nam",
        "cntt": "công nghệ thông tin", "ai": "trí tuệ nhân tạo",
        "cty": "công ty", "tnhh": "trách nhiệm hữu hạn", "cp": "cổ phần"
    ]

    private init() {}

    /// Tra cứu nhanh lỗi gõ sai trong bảng Cache O(1)
    public func lookupCache(for text: String) -> String? {
        let key = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return commonTypoCache[key]
    }

    // MARK: - 2. Universal Telex Phonotactics Normalizer (Tự động phục hồi thứ tự gõ Telex bị đảo)
    private let toneKeys: Set<Character> = ["s", "f", "r", "x", "j"]
    private let onsetConsonants: Set<Character> = ["b","c","d","đ","g","h","k","l","m","n","p","q","r","s","t","v","x"]
    private let codaConsonants: Set<Character> = ["c","m","n","p","t","g","h"]

    /// Phục hồi các ứng viên từ tiếng Việt có dấu hợp lệ từ chuỗi gõ lỗi Telex
    /// Hỗ trợ cả khi người dùng đang gõ dở dang (Prefix-aware) và khi đã gõ xong từ
    public func normalizeTelexDisorder(input: String, trie: WordTrie) -> [String] {
        let lower = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard lower.count >= 2 else { return [] }

        // 1. Kiểm tra nhanh trong cache O(1)
        if let cached = lookupCache(for: lower) {
            return [cached]
        }

        var results: [String] = []
        var seen = Set<String>()

        let chars = Array(lower)

        // 2. Trích xuất Phụ âm đầu (Onset)
        var i = 0
        var onset = ""
        while i < chars.count && onsetConsonants.contains(chars[i]) {
            // Không nhận 'w' làm onset
            onset.append(chars[i])
            i += 1
            // Phụ âm đầu tiếng Việt tối đa 3 ký tự (ngh, nghi...)
            if onset.count >= 3 { break }
        }

        // 3. Trích xuất Dấu thanh (Tone) xuất hiện sau Onset
        var remainingAfterOnset: [Character] = []
        var toneSuffix = ""
        for idx in i..<chars.count {
            let ch = chars[idx]
            if toneKeys.contains(ch) {
                toneSuffix.append(ch)
            } else {
                remainingAfterOnset.append(ch)
            }
        }

        // 4. Trích xuất Phụ âm cuối (Coda) từ cuối mảng remainingAfterOnset
        var codaSuffix = ""
        var remIdx = remainingAfterOnset.count - 1
        while remIdx >= 0 && codaConsonants.contains(remainingAfterOnset[remIdx]) {
            codaSuffix.insert(remainingAfterOnset[remIdx], at: codaSuffix.startIndex)
            remIdx -= 1
            // Coda tiếng Việt tối đa 2 ký tự (ng, nh, ch)
            if codaSuffix.count >= 2 { break }
        }

        let middleEnd = remIdx
        guard middleEnd >= 0 else {
            // Trường hợp không có nguyên âm ở giữa (ví dụ gõ nhầm toàn phụ âm)
            return results
        }

        // 5. Trích xuất khối Vần + Modifiers (Nucleus: a, e, i, o, u, y, w, aa, ee, oo, dd...)
        let middle = Array(remainingAfterOnset[0...middleEnd])
        guard middle.count <= 5 else { return results } // Giới hạn tối đa 5 ký tự để tránh bùng nổ hoán vị (5! = 120)

        let perms = generatePermutations(middle)
        var seenTest = Set<String>()

        // 6. Hoán vị vần, mô phỏng OpenKey và kiểm tra Prefix trong Trie
        for perm in perms {
            let testStr = onset + String(perm) + codaSuffix + toneSuffix
            if seenTest.contains(testStr) { continue }
            seenTest.insert(testStr)

            let evaluated = evaluateTelexKeystrokes(testStr)
            guard !evaluated.isEmpty && !seen.contains(evaluated) else { continue }

            // Tra cứu tiền tố trực tiếp không đệ quy vào Trie
            let matches = trie.lookupDirectPrefix(evaluated, limit: 3)
            if !matches.isEmpty {
                seen.insert(evaluated)
                for match in matches {
                    if !results.contains(match) {
                        results.append(match)
                    }
                }
            }
        }

        return results
    }

    /// Thuật toán sinh hoán vị mảng ký tự
    private func generatePermutations(_ array: [Character]) -> [[Character]] {
        guard array.count > 1 else { return [array] }
        var result: [[Character]] = []
        for (idx, element) in array.enumerated() {
            var remaining = array
            remaining.remove(at: idx)
            for p in generatePermutations(remaining) {
                result.append([element] + p)
            }
        }
        return result
    }

    /// Giả lập chuyển đổi chuỗi phím Telex thành từ tiếng Việt có dấu qua OpenKeyEngineAdapter
    public func evaluateTelexKeystrokes(_ keystrokes: String) -> String {
        let adapter = OpenKeyEngineAdapter()
        var accumulated = ""
        for ch in keystrokes {
            let action = adapter.processKeystroke(ch)
            if action.deleteCount > 0 {
                let dropCount = min(action.deleteCount, accumulated.count)
                accumulated.removeLast(dropCount)
            }
            accumulated.append(action.textToInsert)
        }
        return accumulated
    }

    // MARK: - 3. Spatial QWERTY Fuzzy Match (Lớp 3: Sửa lỗi bấm nhầm phím lân cận)
    // Bảng tra các phím kề cận nhau trên layout QWERTY chuẩn (Key Adjacency Matrix)
    private static let qwertyAdjacentKeys: [Character: [Character]] = [
        "q": ["w", "a", "s"],
        "w": ["q", "e", "s", "a", "d"],
        "e": ["w", "r", "d", "s", "f"],
        "r": ["e", "t", "f", "d", "g"],
        "t": ["r", "y", "g", "f", "h"],
        "y": ["t", "u", "h", "g", "j"],
        "u": ["y", "i", "j", "h", "k"],
        "i": ["u", "o", "k", "j", "l"],
        "o": ["i", "p", "l", "k"],
        "p": ["o", "l"],
        "a": ["q", "w", "s", "z"],
        "s": ["a", "w", "e", "d", "x", "z"],
        "d": ["s", "e", "r", "f", "c", "x"],
        "f": ["d", "r", "t", "g", "v", "c"],
        "g": ["f", "t", "y", "h", "b", "v"],
        "h": ["g", "y", "u", "j", "n", "b"],
        "j": ["h", "u", "i", "k", "m", "n"],
        "k": ["j", "i", "o", "l", "m"],
        "l": ["k", "o", "p"],
        "z": ["a", "s", "x"],
        "x": ["z", "s", "d", "c"],
        "c": ["x", "d", "f", "v"],
        "v": ["c", "f", "g", "b"],
        "b": ["v", "g", "h", "n"],
        "n": ["b", "h", "j", "m"],
        "m": ["n", "j", "k"]
    ]

    /// Sửa lỗi bấm nhầm phím cạnh bên trên bàn phím QWERTY (Spatial Fuzzy Match)
    /// Chỉ được kích hoạt khi Lớp 1 (Cache) và Lớp 2 (Phonotactics Normalizer) không tìm thấy từ trong Trie
    public func spatialFuzzyMatch(query: String, trie: WordTrie, limit: Int = 3) -> [String] {
        let cleanQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanQuery.count >= 2, cleanQuery.count <= 10 else { return [] }

        var candidates: [(word: String, score: Double)] = []
        var bestScores: [String: Double] = [:]

        let chars = Array(cleanQuery)

        // Helper tra cứu và chấm điểm ứng viên
        func evaluateAndCollect(testStr: String, distancePenalty: Double) {
            // Tra cứu trực tiếp chuỗi đột biến
            let directMatches = trie.lookupDirectEntries(testStr, limit: limit * 2)
            for (m, freq) in directMatches {
                let lowM = m.lowercased()
                let lengthDiff = abs(m.count - cleanQuery.count)
                let score = Double(freq) * 2.0 - distancePenalty * 30.0 - Double(lengthDiff) * 15.0 + UserAdaptiveLearningStore.shared.userBoost(for: m)
                if let existing = bestScores[lowM] {
                    if score > existing {
                        bestScores[lowM] = score
                    }
                } else {
                    bestScores[lowM] = score
                    candidates.append((word: m, score: score))
                }
            }

            // Nếu đột biến là Telex hợp lệ, đánh giá và tra cứu
            let telexEvaluated = evaluateTelexKeystrokes(testStr)
            if !telexEvaluated.isEmpty && telexEvaluated != testStr {
                let telexMatches = trie.lookupDirectEntries(telexEvaluated, limit: limit * 2)
                for (m, freq) in telexMatches {
                    let lowM = m.lowercased()
                    let lengthDiff = abs(m.count - cleanQuery.count)
                    let score = Double(freq) * 2.0 - distancePenalty * 30.0 - Double(lengthDiff) * 15.0 + UserAdaptiveLearningStore.shared.userBoost(for: m)
                    if let existing = bestScores[lowM] {
                        if score > existing {
                            bestScores[lowM] = score
                        }
                    } else {
                        bestScores[lowM] = score
                        candidates.append((word: m, score: score))
                    }
                }
            }
        }

        // 1. Sinh các biến thể thay thế 1 phím kề cận (phạt khoảng cách 0.5 điểm)
        for i in 0..<chars.count {
            let originalChar = chars[i]
            guard let adjacents = Self.qwertyAdjacentKeys[originalChar] else { continue }

            for adjChar in adjacents {
                var mutatedChars = chars
                mutatedChars[i] = adjChar
                let mutatedStr = String(mutatedChars)
                evaluateAndCollect(testStr: mutatedStr, distancePenalty: 0.5)
            }
        }

        // 2. Thử nghiệm hoán đổi 2 ký tự liền kề (Transposition: phạt khoảng cách 0.6)
        if chars.count >= 3 {
            for i in 0..<(chars.count - 1) {
                var swapped = chars
                swapped.swapAt(i, i + 1)
                let swappedStr = String(swapped)
                evaluateAndCollect(testStr: swappedStr, distancePenalty: 0.6)
            }
        }

        guard !candidates.isEmpty else { return [] }

        // Cập nhật lại score tốt nhất cho từng candidate
        let scoredCandidates = candidates.map { (word: $0.word, score: bestScores[$0.word.lowercased()] ?? $0.score) }

        // Sắp xếp các ứng viên theo điểm số giảm dần
        let sorted = scoredCandidates.sorted {
            if $0.score != $1.score {
                return $0.score > $1.score
            }
            return $0.word.count < $1.word.count
        }

        return Array(sorted.prefix(limit).map { $0.word })
    }
}
