import Foundation

/// Bộ dự đoán từ tiếp theo dựa trên mô hình n-gram (Bi-gram) tiếng Việt siêu nhẹ (< 650 KB RAM)
public final class NextWordPredictor: @unchecked Sendable {
    public static let shared = NextWordPredictor()

    private let biGramMap: [String: [String]] = [
        "xin": ["chào", "lỗi", "phép", "hỏi", "mời"],
        "chào": ["bạn", "anh", "chị", "em", "mọi người", "buổi sáng"],
        "cảm": ["ơn", "xúc", "thấy", "nhận", "giác"],
        "chúc": ["mừng", "ngủ ngon", "bạn", "một ngày", "thành công"],
        "hẹn": ["gặp lại", "hò", "ngày mai", "sớm", "nhau"],
        "báo": ["cáo", "chí", "động", "tin", "giá"],
        "làm": ["việc", "sao", "gì", "ơn", "quen", "được"],
        "đi": ["đâu", "làm", "chơi", "về", "ngay", "học"],
        "ăn": ["cơm", "tối", "trưa", "sáng", "uống", "gì"],
        "uống": ["cà phê", "nước", "trà", "bia", "rượu"],
        "học": ["tập", "sinh", "hành", "tiếng", "bài"],
        "công": ["việc", "ty", "nghệ", "tác", "cụ"],
        "thời": ["gian", "tiết", "khóa", "đại", "sự"],
        "việt": ["nam", "ngữ", "kiều", "hóa"],
        "hà": ["nội", "tĩnh", "giang", "nam"],
        "sài": ["gòn"],
        "thành": ["phố", "công", "lập", "viên"],
        "tất": ["cả", "nhiên", "thảy"],
        "rất": ["vui", "tốt", "đẹp", "nhiều", "thích", "nhanh"],
        "không": ["có", "biết", "sao", "được", "thể", "phải"],
        "được": ["rồi", "chưa", "không", "biết", "khen"],
        "người": ["yêu", "dùng", "lớn", "nhà", "bạn"],
        "đồng": ["ý", "chí", "nghiệp", "hồ", "tiền"],
        "anh": ["em", "trai", "ấy", "ơi", "yêu"],
        "em": ["gái", "yêu", "ơi", "ạ", "nhớ"],
        "bạn": ["bè", "thân", "ơi", "có", "gì"]
    ]

    private init() {}

    /// Dự đoán các từ tiếp theo dựa trên từ vừa gõ
    public func predictNextWords(after word: String, limit: Int = 3) -> [String] {
        let key = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let matches = biGramMap[key] else { return [] }
        return Array(matches.prefix(limit))
    }
}
