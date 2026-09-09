//
//  OpenKeyEngineTests.swift
//  vBoardEngineTests
//
//  Bộ kiểm thử toàn diện cho OpenKeyEngine và OpenKeyEngineAdapter (Swift thuần).
//

import Testing
import Foundation
@testable import vBoardEngine

@Suite("Bộ kiểm thử OpenKey Core Engine (Swift thuần)")
struct OpenKeyEngineTests {

    /// Tiện ích gõ một chuỗi liên tục qua OpenKeyEngineAdapter
    private func typeString(_ str: String, adapter: OpenKeyEngineAdapter = OpenKeyEngineAdapter()) -> String {
        adapter.reset()
        var buffer = ""
        for char in str {
            let action = adapter.processKeystroke(char, contextBefore: buffer)
            if action.deleteCount > 0 {
                let deleteCount = min(buffer.count, action.deleteCount)
                let startIndex = buffer.index(buffer.endIndex, offsetBy: -deleteCount)
                buffer.removeSubrange(startIndex..<buffer.endIndex)
            }
            buffer += action.textToInsert
        }
        return buffer
    }

    @Test("Kiểm tra biến đổi nguyên âm mũ và móc (Telex cơ bản)")
    func testVowelTonesTelex() {
        let adapter = OpenKeyEngineAdapter()

        let testCases: [(input: String, expected: String)] = [
            ("aa", "â"),
            ("ee", "ê"),
            ("oo", "ô"),
            ("dd", "đ"),
            ("aw", "ă"),
            ("ow", "ơ"),
            ("uw", "ư"),
            ("AA", "Â"),
            ("EE", "Ê"),
            ("OO", "Ô"),
            ("DD", "Đ"),
            ("AW", "Ă"),
            ("OW", "Ơ"),
            ("UW", "Ư")
        ]

        for test in testCases {
            let result = typeString(test.input, adapter: adapter)
            #expect(result == test.expected, "Gõ '\(test.input)' kỳ vọng '\(test.expected)', thực tế ra '\(result)'")
        }
    }

    @Test("Kiểm tra 5 dấu thanh cơ bản (s, f, r, x, j)")
    func testFiveTonesTelex() {
        let adapter = OpenKeyEngineAdapter()

        let testCases: [(input: String, expected: String)] = [
            ("as", "á"),
            ("af", "à"),
            ("ar", "ả"),
            ("ax", "ã"),
            ("aj", "ạ"),
            ("vietj", "việt"),
            ("nam", "nam"),
            ("tiengs", "tiếng"),
            ("yeu", "yeu")
        ]

        for test in testCases {
            let result = typeString(test.input, adapter: adapter)
            #expect(result == test.expected, "Gõ '\(test.input)' kỳ vọng '\(test.expected)', thực tế ra '\(result)'")
        }
    }

    @Test("Kiểm tra vị trí đặt dấu thanh chuẩn mới (Modern Orthography)")
    func testModernOrthographyTonePlacement() {
        let adapter = OpenKeyEngineAdapter()
        adapter.engine.vUseModernOrthography = 1

        let testCases: [(input: String, expected: String)] = [
            ("hoas", "hóa"),
            ("thuys", "thúy"),
            ("toans", "toán"),
            ("tiens", "tiến"),
            ("hoangf", "hoàng"),
            ("khuyenr", "khuyển")
        ]

        for test in testCases {
            let result = typeString(test.input, adapter: adapter)
            #expect(result == test.expected, "Chuẩn mới: gõ '\(test.input)' kỳ vọng '\(test.expected)', thực tế '\(result)'")
        }
    }

    @Test("Kiểm tra vị trí đặt dấu thanh chuẩn cũ (Classic Orthography)")
    func testClassicOrthographyTonePlacement() {
        let adapter = OpenKeyEngineAdapter()
        adapter.engine.vUseModernOrthography = 0 // Kiểu cũ

        let testCases: [(input: String, expected: String)] = [
            ("hoas", "hoá"),
            ("thuys", "thuý")
        ]

        for test in testCases {
            let result = typeString(test.input, adapter: adapter)
            #expect(result == test.expected, "Chuẩn cũ: gõ '\(test.input)' kỳ vọng '\(test.expected)', thực tế '\(result)'")
        }
    }

    @Test("Kiểm tra khôi phục phím khi gõ đúp phím dấu (Restore / Undo)")
    func testDoubleToneRestore() {
        let adapter = OpenKeyEngineAdapter()

        let testCases: [(input: String, expected: String)] = [
            ("ass", "as"),
            ("aff", "af"),
            ("arr", "ar"),
            ("axx", "ax"),
            ("ajj", "aj"),
            ("toanss", "toans"),
            ("dddd", "dd")
        ]

        for test in testCases {
            let result = typeString(test.input, adapter: adapter)
            #expect(result == test.expected, "Khôi phục đúp phím: gõ '\(test.input)' kỳ vọng '\(test.expected)', thực tế '\(result)'")
        }
    }

    @Test("Kiểm tra phím Z gỡ dấu thanh")
    func testZKeyRemoveTone() {
        let adapter = OpenKeyEngineAdapter()

        let testCases: [(input: String, expected: String)] = [
            ("asz", "a"),
            ("toansz", "toan"),
            ("vietjz", "viet")
        ]

        for test in testCases {
            let result = typeString(test.input, adapter: adapter)
            #expect(result == test.expected, "Phím Z gỡ dấu: gõ '\(test.input)' kỳ vọng '\(test.expected)', thực tế '\(result)'")
        }
    }

    @Test("Kiểm tra phím ngoặc vuông [ và ] trong OpenKey")
    func testBracketKeys() {
        let adapter = OpenKeyEngineAdapter()

        #expect(typeString("[", adapter: adapter) == "ơ")
        #expect(typeString("]", adapter: adapter) == "ư")
    }

    @Test("Kiểm tra gõ tắt Macro và Auto Caps của OpenKey")
    func testMacroWithAutoCaps() {
        let adapter = OpenKeyEngineAdapter()
        adapter.engine.macroManager.clearAll()
        adapter.engine.macroManager.addMacro(text: "btw", content: "by the way")
        adapter.engine.macroManager.addMacro(text: "vn", content: "Việt Nam")

        // 1. Chữ thường
        #expect(typeString("btw ", adapter: adapter) == "by the way ")
        // 2. Chữ hoa đầu từ (Btw) -> Hoa đầu cụm (By the way)
        #expect(typeString("Btw ", adapter: adapter) == "By the way ")
        // 3. Chữ hoa toàn bộ (BTW) -> Hoa toàn bộ cụm (BY THE WAY)
        #expect(typeString("BTW ", adapter: adapter) == "BY THE WAY ")
        // 4. Macro tiếng Việt
        #expect(typeString("vn ", adapter: adapter) == "Việt Nam ")
    }

    @Test("Kiểm tra gõ câu hoàn chỉnh có khoảng trắng")
    func testFullSentenceTyping() {
        let adapter = OpenKeyEngineAdapter()
        let sentence = "tooi ddang gox tieengs vieetj vooiws openkey "
        let result = typeString(sentence, adapter: adapter)
        #expect(result == "tôi đang gõ tiếng việt với openkey ", "Kỳ vọng câu đúng dấu, thực tế: '\(result)'")
    }

    @Test("Đo lường hiệu năng xử lý ký tự OpenKeyEngine (< 0.05ms)")
    func testPerformanceOpenKey() {
        let adapter = OpenKeyEngineAdapter()
        let testText = "con caos naauf nhaary qua con chos luowif bieengs vBoard OpenKey 2026"

        let iterations = 10_000
        let start = DispatchTime.now()

        for _ in 0..<iterations {
            _ = adapter.processKeystroke("a", contextBefore: "to")
        }

        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let timePerKeystrokeMs = Double(nanoTime) / Double(iterations) / 1_000_000.0

        print("\n⚡️ TỐC ĐỘ XỬ LÝ OPENKEY SWIFT: \(String(format: "%.4f", timePerKeystrokeMs)) ms / ký tự (\(iterations) lần gõ)")
        #expect(timePerKeystrokeMs < 0.05, "Tốc độ xử lý OpenKeyEngine phải dưới 0.05ms/lần gõ")
    }
}
