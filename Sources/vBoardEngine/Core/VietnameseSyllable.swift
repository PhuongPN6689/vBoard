import Foundation

/// Đại diện cho 1 ký tự nguyên âm đang được xử lý trong âm tiết
public struct VowelUnit: Equatable, Sendable {
    public var base: Character
    public var shape: VowelShape
    public var isUpper: Bool

    public init(base: Character, shape: VowelShape = .plain, isUpper: Bool = false) {
        self.base = base
        self.shape = shape
        self.isUpper = isUpper
    }
}

/// Lõi xử lý âm tiết tiếng Việt
public struct VietnameseSyllable: Equatable, Sendable {
    public var prefix: String = ""
    public var vowels: [VowelUnit] = []
    public var suffix: String = ""
    public var tone: ToneMark = .none

    public init() {}

    public var isEmpty: Bool {
        return prefix.isEmpty && vowels.isEmpty && suffix.isEmpty
    }

    /// Xuất chuỗi hoàn chỉnh của âm tiết dựa trên quy tắc đặt dấu
    public func render(style: DiacriticStyle = .newStyle) -> String {
        if vowels.isEmpty {
            return prefix + suffix
        }

        let toneIndex = determineTonePosition(style: style)

        var vowelStr = ""
        for (i, v) in vowels.enumerated() {
            let currentTone = (i == toneIndex) ? self.tone : .none
            if let composed = VietnameseChar.compose(base: v.base, shape: v.shape, tone: currentTone, isUppercase: v.isUpper) {
                vowelStr.append(composed)
            } else {
                vowelStr.append(v.base)
            }
        }

        return prefix + vowelStr + suffix
    }

    /// Xác định chỉ số của nguyên âm sẽ nhận dấu thanh
    public func determineTonePosition(style: DiacriticStyle) -> Int {
        let count = vowels.count
        if count == 0 { return 0 }
        if count == 1 { return 0 }

        let baseVowels = String(vowels.map { Character($0.base.lowercased()) })
        let lowerPrefix = prefix.lowercased()
        let hasSuffix = !suffix.isEmpty

        // Trường hợp 3 nguyên âm:
        if count == 3 {
            // Tổ hợp "uyê" / "uye" (chuyển, chuyến, thuyền, khuyên, duyệt, tuyết...):
            // Dấu luôn nằm ở nguyên âm 'ê' / 'e' (chỉ số 2), tuyệt đối không bao giờ rơi vào 'y'
            if baseVowels == "uye" || vowels[2].shape == .circumflex || vowels[2].base.lowercased() == "e" {
                return 2
            }
            // Các tổ hợp 3 nguyên âm khác (oai, oay, uay, uôi, ươi, iêu, yêu, uyu...):
            // Dấu luôn nằm ở nguyên âm giữa (chỉ số 1)
            return 1
        }

        // Trường hợp 2 nguyên âm:
        if count == 2 {
            // Nếu có phụ âm cuối: dấu luôn nằm ở nguyên âm thứ 2
            // ví dụ: hoàn, toàn, tiến, muốn, mượn
            if hasSuffix {
                return 1
            }

            // Nếu không có phụ âm cuối:
            // 1. Nếu là nguyên âm đôi có mũ/móc (iê, uô, ươ) -> dấu ở nguyên âm thứ 2
            if vowels[0].shape == .circumflex || vowels[1].shape == .circumflex ||
               vowels[0].shape == .horn || vowels[1].shape == .horn {
                // Ví dụ ươ -> cười (có suffix), mưa (chỉ có ư, không phải ươ)
                // trong uơ (thuở): dấu ở ơ (thứ 2)
                if baseVowels == "uo" && (vowels[0].shape == .horn || vowels[1].shape == .horn) {
                    return 1
                }
                if baseVowels == "ie" && vowels[1].shape == .circumflex {
                    return 1
                }
                if baseVowels == "uo" && vowels[1].shape == .circumflex {
                    return 1
                }
            }

            // 2. Diphthongs ia, ua, ưa -> dấu luôn ở nguyên âm đầu: mía, múa, chửa
            if baseVowels == "ia" || baseVowels == "ua" || (baseVowels == "ua" && vowels[0].shape == .horn) {
                return 0
            }

            // 3. oa, oe, uy:
            if baseVowels == "oa" || baseVowels == "oe" || baseVowels == "uy" {
                if lowerPrefix.hasSuffix("q") {
                    return 1
                }
                // Chuẩn mới (Modern style): hòa, khỏe, thủy (dấu ở âm đệm, index 0: 'ò', 'ủ')
                // Chuẩn cũ (Traditional style): hoà, khoẻ, thuỷ (dấu ở âm chính, index 1: 'à', 'ỷ')
                return (style == .newStyle) ? 0 : 1
            }

            // 4. Các nguyên âm đôi kết thúc bằng bán nguyên âm (ai, oi, ui, ay, au, ao, eo, iu...):
            // Dấu luôn nằm ở nguyên âm chính đầu tiên (index 0): gái, nói, núi, máy, sáu, báo, khéo, dịu
            if baseVowels == "ai" || baseVowels == "oi" || baseVowels == "ui" ||
               baseVowels == "ay" || baseVowels == "au" || baseVowels == "ao" ||
               baseVowels == "eo" || baseVowels == "iu" || baseVowels == "eu" {
                return 0
            }

            // Mặc định cho 2 nguyên âm không có phụ âm cuối
            return 0
        }

        return 0
    }
}
