import Foundation

/// Dấu thanh trong tiếng Việt
public enum ToneMark: Int, CaseIterable, Sendable {
    case none = 0
    case acute = 1  // Sắc (s)
    case grave = 2  // Huyền (f)
    case hook = 3   // Hỏi (r)
    case tilde = 4  // Ngã (x)
    case dot = 5    // Nặng (j)
}

/// Dấu mũ / móc nguyên âm
public enum VowelShape: Int, CaseIterable, Sendable {
    case plain = 0        // a, e, i, o, u, y
    case circumflex = 1   // â, ê, ô (aa, ee, oo)
    case breve = 2        // ă (aw)
    case horn = 3         // ơ, ư (ow, uw)
}

public enum VietnameseChar {
    // Bảng nguyên âm đầy đủ: [BaseChar: [VowelShape: [ToneMark: Character]]]
    // Cấu trúc phẳng được tối ưu hóa để lookup tức thì O(1)
    
    private static let vowelTable: [Character: [VowelShape: [ToneMark: Character]]] = [
        "a": [
            .plain: [.none: "a", .acute: "á", .grave: "à", .hook: "ả", .tilde: "ã", .dot: "ạ"],
            .circumflex: [.none: "â", .acute: "ấ", .grave: "ầ", .hook: "ẩ", .tilde: "ẫ", .dot: "ậ"],
            .breve: [.none: "ă", .acute: "ắ", .grave: "ằ", .hook: "ẳ", .tilde: "ẵ", .dot: "ặ"]
        ],
        "e": [
            .plain: [.none: "e", .acute: "é", .grave: "è", .hook: "ẻ", .tilde: "ẽ", .dot: "ẹ"],
            .circumflex: [.none: "ê", .acute: "ế", .grave: "ề", .hook: "ể", .tilde: "ễ", .dot: "ệ"]
        ],
        "i": [
            .plain: [.none: "i", .acute: "í", .grave: "ì", .hook: "ỉ", .tilde: "ĩ", .dot: "ị"]
        ],
        "o": [
            .plain: [.none: "o", .acute: "ó", .grave: "ò", .hook: "ỏ", .tilde: "õ", .dot: "ọ"],
            .circumflex: [.none: "ô", .acute: "ố", .grave: "ồ", .hook: "ổ", .tilde: "ỗ", .dot: "ộ"],
            .horn: [.none: "ơ", .acute: "ớ", .grave: "ờ", .hook: "ở", .tilde: "ỡ", .dot: "ợ"]
        ],
        "u": [
            .plain: [.none: "u", .acute: "ú", .grave: "ù", .hook: "ủ", .tilde: "ũ", .dot: "ụ"],
            .horn: [.none: "ư", .acute: "ứ", .grave: "ừ", .hook: "ử", .tilde: "ữ", .dot: "ự"]
        ],
        "y": [
            .plain: [.none: "y", .acute: "ý", .grave: "ỳ", .hook: "ỷ", .tilde: "ỹ", .dot: "ỵ"]
        ]
    ]

    /// Phân tích một ký tự tiếng Việt ra (Ký tự gốc, Hình dạng mũ/móc, Dấu thanh)
    public static func decompose(_ char: Character) -> (base: Character, shape: VowelShape, tone: ToneMark, isUppercase: Bool)? {
        let nfcString = String(char).precomposedStringWithCanonicalMapping
        guard let normalizedChar = nfcString.first else { return nil }
        let isUpper = normalizedChar.isUppercase
        let lowerChar = Character(normalizedChar.lowercased())

        for (base, shapeDict) in vowelTable {
            for (shape, toneDict) in shapeDict {
                for (tone, c) in toneDict {
                    if c == lowerChar {
                        return (base, shape, tone, isUpper)
                    }
                }
            }
        }
        return nil
    }

    /// Tổng hợp lại ký tự tiếng Việt từ (Ký tự gốc, Hình dạng, Dấu thanh)
    public static func compose(base: Character, shape: VowelShape, tone: ToneMark, isUppercase: Bool) -> Character? {
        let lowerBase = Character(base.lowercased())
        guard let shapeDict = vowelTable[lowerBase],
              let toneDict = shapeDict[shape],
              let char = toneDict[tone] else {
            return nil
        }
        return isUppercase ? Character(char.uppercased()) : char
    }

    /// Kiểm tra xem một ký tự có phải là nguyên âm tiếng Việt (có dấu hoặc không dấu)
    public static func isVowel(_ char: Character) -> Bool {
        return decompose(char) != nil
    }

    /// Kiểm tra ký tự d / đ
    public static func isD(_ char: Character) -> Bool {
        let lower = char.lowercased()
        return lower == "d" || lower == "đ"
    }
}
