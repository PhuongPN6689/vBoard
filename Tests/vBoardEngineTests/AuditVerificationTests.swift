import Testing
import Foundation
@testable import vBoardEngine

@Suite("Bộ Kiểm Thử Độc Lập - Bóc Tách Ca Biên Thực Tế (Independent Audit Tests)")
struct AuditVerificationTests {

    @MainActor
    final class AuditProxy: TextDocumentProxyProtocol {
        var buffer: String = ""
        var cursorPosition: Int = 0

        var documentContextBeforeInput: String? {
            if cursorPosition <= 0 { return "" }
            let index = buffer.index(buffer.startIndex, offsetBy: cursorPosition)
            return String(buffer[..<index])
        }

        var documentContextAfterInput: String? {
            if cursorPosition >= buffer.count { return "" }
            let index = buffer.index(buffer.startIndex, offsetBy: cursorPosition)
            return String(buffer[index...])
        }

        func deleteBackward() {
            guard cursorPosition > 0 else { return }
            let removeIndex = buffer.index(buffer.startIndex, offsetBy: cursorPosition - 1)
            buffer.remove(at: removeIndex)
            cursorPosition -= 1
        }

        func insertText(_ text: String) {
            let insertIndex = buffer.index(buffer.startIndex, offsetBy: cursorPosition)
            buffer.insert(contentsOf: text, at: insertIndex)
            cursorPosition += text.count
        }

        func adjustTextPosition(byCharacterOffset offset: Int) {
            cursorPosition = max(0, min(buffer.count, cursorPosition + offset))
        }

        func type(_ sequence: String, adapter: TextProxyAdapter) {
            for ch in sequence {
                if ch == " " {
                    adapter.handleSpace(proxy: self)
                } else {
                    adapter.handleKeyInput(ch, proxy: self)
                }
            }
        }

        func backspace(adapter: TextProxyAdapter) {
            adapter.handleBackspace(proxy: self)
        }
    }

    @Test("Kiểm tra gõ từ tiếng Anh thông dụng (English Words Typing)")
    @MainActor
    func testEnglishTyping() {
        let adapter = TextProxyAdapter()
        let englishWords = [
            "code", "apple", "google", "facebook", "online", 
            "game", "system", "test", "post", "email", 
            "website", "free", "view", "server", "pass"
        ]
        print("\n================== KẾT QUẢ GÕ TIẾNG ANH ==================")
        for word in englishWords {
            let proxy = AuditProxy()
            proxy.type(word, adapter: adapter)
            print("Gõ '\(word)' -> Thực tế ra: '\(proxy.buffer)'")
            #expect(proxy.buffer == word, "Từ tiếng Anh '\(word)' phải được bảo tồn chính xác, thực tế ra: '\(proxy.buffer)'")
        }
    }

    @Test("Kiểm tra gõ Email và URL (URL and Email Preservation)")
    @MainActor
    func testUrlAndEmailTyping() {
        let adapter = TextProxyAdapter()
        let urls = [
            "admin@gmail.com",
            "https://google.com/test",
            "user_name@domain.vn"
        ]
        print("\n================== KẾT QUẢ GÕ URL & EMAIL ==================")
        for url in urls {
            let proxy = AuditProxy()
            proxy.type(url, adapter: adapter)
            print("Gõ '\(url)' -> Thực tế ra: '\(proxy.buffer)'")
            #expect(proxy.buffer == url, "URL hoặc Email '\(url)' phải được bảo tồn chính xác, thực tế ra: '\(proxy.buffer)'")
        }
    }

    @Test("Kiểm tra thao tác Backspace trên từ tiếng Việt có dấu")
    @MainActor
    func testBackspaceVietnamese() {
        let adapter = TextProxyAdapter()

        let proxy1 = AuditProxy()
        proxy1.type("vieejt", adapter: adapter)
        let beforeBs1 = proxy1.buffer
        proxy1.backspace(adapter: adapter)
        let afterBs1 = proxy1.buffer
        print("\n================== KẾT QUẢ BACKSPACE ==================")
        print("1. 'vieejt' ra '\(beforeBs1)' -> Backspace 1 lần -> ra '\(afterBs1)'")

        let proxy2 = AuditProxy()
        proxy2.type("duowngf", adapter: adapter)
        let beforeBs2 = proxy2.buffer
        proxy2.backspace(adapter: adapter)
        let afterBs2 = proxy2.buffer
        print("2. 'duowngf' ra '\(beforeBs2)' -> Backspace 1 lần -> ra '\(afterBs2)'")

        let proxy3 = AuditProxy()
        proxy3.type("toasn", adapter: adapter)
        let beforeBs3 = proxy3.buffer
        proxy3.backspace(adapter: adapter)
        let afterBs3 = proxy3.buffer
        print("3. 'toasn' ra '\(beforeBs3)' -> Backspace 1 lần -> ra '\(afterBs3)'")
    }

    @Test("Kiểm tra di chuyển con trỏ giữa câu và sửa từ (Cursor Navigation Sync)")
    @MainActor
    func testCursorNavigationEdit() {
        let adapter = TextProxyAdapter()
        let proxy = AuditProxy()
        proxy.type("hom nay", adapter: adapter)
        print("\n================== KẾT QUẢ SỬA GIỮA CÂU ==================")
        print("Văn bản ban đầu: '\(proxy.buffer)'")
        // Di chuyển con trỏ về sau chữ "hom" (offset = -4, nhảy qua " nay")
        proxy.adjustTextPosition(byCharacterOffset: -4)
        print("Context trước con trỏ: '\(proxy.documentContextBeforeInput ?? "")'")
        // Gõ thêm "o" để biến "hom" thành "hôm"
        proxy.type("o", adapter: adapter)
        print("Sau khi gõ thêm 'o': '\(proxy.buffer)' (Kỳ vọng: 'hôm nay')")
    }

    @Test("Kiểm tra khớp từ vuốt phím có phụ âm lặp và ca biên (Double letters & Collinear)")
    func testGlideAdvancedEdgeCases() {
        // 1. Từ có phụ âm lặp (ví dụ 'comment' -> người dùng chỉ lướt qua 'm' 1 lần)
        let commentCands = WordTrie.shared.matchGlide(keySequence: Array("cvokmrebnt"), limit: 3)
        #expect(commentCands.contains("comment"), "Phải gợi ý được 'comment' từ chuỗi cvokmrebnt")

        // 2. Từ 2 ký tự cao tần có phím lướt nhiễu (ví dụ 'đi' qua 'dfyui', 'ăn' qua 'adcvbn')
        let diCands = WordTrie.shared.matchGlide(keySequence: Array("dfyui"), limit: 3)
        #expect(diCands.first?.lowercased() == "đi", "Chuỗi 'dfyui' phải ưu tiên từ cao tần 'đi'")

        let anCands = WordTrie.shared.matchGlide(keySequence: Array("adcvbn"), limit: 3)
        #expect(anCands.first?.lowercased() == "ăn", "Chuỗi 'adcvbn' phải ưu tiên từ cao tần 'ăn'")

        // 3. Quẹt nhanh lướt phím thẳng hàng (ví dụ 'ka' cho 'khá')
        let khaCands = WordTrie.shared.matchGlide(keySequence: Array("ka"), limit: 3)
        #expect(khaCands.contains("khá"), "Chuỗi thẳng hàng 'ka' phải gợi ý 'khá'")
    }

    @Test("Phân tích dữ liệu thực tế từ file người dùng (nếu có)")
    func testUserRealRecording() throws {
        let path = "/Users/nguyenphuong/Downloads/văn bản-82381E99C24D-1.txt"
        guard FileManager.default.fileExists(atPath: path) else { return }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        struct RecItem: Codable {
            let targetWord: String
            let primarySeq: String
            let fullSeq: String
            let recognizedWord: String
            let isMatch: Bool
            let topCandidates: [String]?
        }
        let items = try JSONDecoder().decode([RecItem].self, from: data)
        var passCount = 0
        for item in items {
            let target = item.targetWord.lowercased()
            let targetAscii = WordTrie.stripDiacritics(target)
            let primaryChars = Array(item.primarySeq)
            let cands = WordTrie.shared.matchGlide(keySequence: primaryChars, limit: 5)
            let top = cands.first?.lowercased() ?? ""
            let topAscii = WordTrie.stripDiacritics(top)
            if !top.isEmpty && topAscii == targetAscii {
                passCount += 1
            }
        }
        #expect(passCount >= 50, "Tỷ lệ nhận diện từ file thực tế phải đạt ít nhất 50/59 mẫu (hiện tại: \(passCount)/\(items.count))")
    }
}
