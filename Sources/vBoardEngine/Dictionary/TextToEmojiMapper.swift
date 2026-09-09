import Foundation

/// Bộ chuyển đổi từ vựng cảm xúc và sự vật tiếng Việt sang Emoji (Text to Emoji)
public final class TextToEmojiMapper: @unchecked Sendable {
    public static let shared = TextToEmojiMapper()

    private let emojiMap: [String: [String]] = [
        "cười": ["😄", "😆", "🤣"],
        "vui": ["😊", "🥳", "🎉"],
        "haha": ["😂", "🤣", "😆"],
        "hihi": ["🤭", "☺️", "😁"],
        "tim": ["❤️", "💖", "💕"],
        "yêu": ["🥰", "😍", "😘"],
        "thương": ["🥺", "🫂", "❤️"],
        "khóc": ["😭", "😢", "🥺"],
        "buồn": ["😔", "😢", "🙁"],
        "huhu": ["😭", "😿", "🥺"],
        "thích": ["👍", "👌", "🥰"],
        "ok": ["👌", "👍", "✅"],
        "tuyệt": ["💯", "✨", "🔥"],
        "đồng ý": ["🤝", "✅", "👌"],
        "cảm ơn": ["🙏", "💐", "💖"],
        "chúc mừng": ["🎉", "🎊", "🥂"],
        "chó": ["🐶", "🐕", "🐩"],
        "mèo": ["🐱", "🐈", "🐾"],
        "heo": ["🐷", "🐖", "🐽"],
        "lợn": ["🐷", "🐖"],
        "gà": ["🐔", "🐤", "🐣"],
        "mặt trời": ["☀️", "🌞"],
        "nắng": ["🌤️", "☀️", "😎"],
        "mưa": ["🌧️", "🌦️", "☔"],
        "bão": ["⛈️", "🌪️", "🌊"],
        "lửa": ["🔥", "⚡", "💥"],
        "cháy": ["🔥", "🚒"],
        "nóng": ["🥵", "🔥", "☀️"],
        "lạnh": ["🥶", "❄️", "☃️"],
        "uống": ["🍻", "🥤", "☕"],
        "bia": ["🍺", "🍻", "🥂"],
        "cà phê": ["☕", "🧋", "🫖"],
        "rượu": ["🍷", "🍾", "🥂"],
        "tiền": ["💵", "💰", "💸"],
        "xe": ["🚗", "🛵", "🏎️"],
        "nhà": ["🏠", "🏡", "🏢"],
        "sao": ["⭐", "🌟", "✨"],
        "hoa": ["🌸", "🌹", "🌻"]
    ]

    private init() {}

    /// Tra cứu Emoji tương ứng cho từ khóa
    public func emojis(for word: String) -> [String] {
        let key = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return emojiMap[key] ?? []
    }
}
