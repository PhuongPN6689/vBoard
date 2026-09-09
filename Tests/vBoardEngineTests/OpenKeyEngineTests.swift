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
            ("vieetj", "việt"),
            ("nam", "nam"),
            ("tieengs", "tiếng"),
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
        adapter.engine.vUseModernOrthography = 1 // Kiểu mới: dấu đặt ở nguyên âm chính (hoá, thuý)

        let testCases: [(input: String, expected: String)] = [
            ("hoas", "hoá"),
            ("thuys", "thuý"),
            ("toans", "toán"),
            ("tieens", "tiến"),
            ("hoangf", "hoàng"),
            ("khuyeern", "khuyển")
        ]

        for test in testCases {
            let result = typeString(test.input, adapter: adapter)
            #expect(result == test.expected, "Chuẩn mới: gõ '\(test.input)' kỳ vọng '\(test.expected)', thực tế '\(result)'")
        }
    }

    @Test("Kiểm tra vị trí đặt dấu thanh chuẩn cũ (Classic Orthography)")
    func testClassicOrthographyTonePlacement() {
        let adapter = OpenKeyEngineAdapter()
        adapter.engine.vUseModernOrthography = 0 // Kiểu cũ: dấu đặt ở âm đệm (hóa, thúy)

        let testCases: [(input: String, expected: String)] = [
            ("hoas", "hóa"),
            ("thuys", "thúy")
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
            ("hoangff", "hoangf"),
            ("tieengss", "tiêngs"),
            ("nguowiff", "ngươif"),
            ("ddd", "dd")
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

    @Test("Kiểm tra toàn diện kho từ vựng tiếng Việt thực tế")
    func testExtensiveVietnameseWords() {
        let adapter = OpenKeyEngineAdapter()

        let testCases: [(input: String, expected: String)] = [
            // Các từ với qu
            ("qua", "qua"), ("quas", "quá"), ("quaf", "quà"), ("quar", "quả"),
            ("quan", "quan"), ("quans", "quán"), ("quanf", "quàn"), ("quanr", "quản"), ("quang", "quang"),
            ("quangs", "quáng"), ("quangr", "quảng"), ("quaan", "quân"), ("quaans", "quấn"), ("quaanf", "quần"),
            ("quaanj", "quận"), ("quoocs", "quốc"), ("quyeets", "quyết"), ("quyeenf", "quyền"),
            ("quys", "quý"), ("quyf", "quỳ"), ("quyr", "quỷ"), ("queetj", "quệt"), ("quets", "quét"),
            ("queets", "quết"), ("queen", "quên"), ("quanh", "quanh"), ("quyeenr", "quyển"),

            // Các từ với gi
            ("gia", "gia"), ("gias", "giá"), ("giaf", "già"), ("giarm", "giảm"), ("gianr", "giản"),
            ("gians", "gián"), ("giao", "giao"), ("giaos", "giáo"), ("giayf", "giày"), ("giaays", "giấy"),
            ("gio", "gio"), ("gios", "gió"), ("giojt", "giọt"), ("gioongs", "giống"), ("giups", "giúp"),
            ("giuwxa", "giữa"), ("giuwx", "giữ"), ("giuowngf", "giường"), ("gieengs", "giếng"),
            ("ginf", "gìn"), ("giawcj", "giặc"), ("giawtj", "giặt"),

            // Các từ với d / đ
            ("dda", "đa"), ("ddas", "đá"), ("ddax", "đã"), ("dduowcj", "được"), ("dduowngf", "đường"),
            ("ddoanf", "đoàn"), ("ddoans", "đoán"), ("ddaafu", "đầu"), ("ddaayf", "đầy"), ("ddeem", "đêm"),
            ("ddieemr", "điểm"), ("ddieeuf", "điều"), ("ddieeur", "điểu"), ("ddoanj", "đoạn"), ("ddepj", "đẹp"),
            ("ddeens", "đến"), ("ddaay", "đây"), ("ddoos", "đố"),

            // Diphthongs và nguyên âm ghép
            ("nguowif", "người"), ("nuowsc", "nước"), ("buowsc", "bước"), ("muownj", "mượn"),
            ("huowng", "hương"), ("thuowng", "thương"), ("ruowuj", "rượu"), ("vuowfn", "vườn"),
            ("tieenf", "tiền"), ("tieens", "tiến"), ("tieengs", "tiếng"), ("bieets", "biết"),
            ("vieets", "viết"), ("kieemr", "kiểm"), ("mieenf", "miền"), ("bieenr", "biển"),
            ("chieens", "chiến"), ("rieeng", "riêng"), ("hieenj", "hiện"), ("ddieenj", "điện"),
            ("yeu", "yeu"), ("yeems", "yếm"), ("yeens", "yến"), ("chuyeens", "chuyến"),
            ("chuyeenj", "chuyện"), ("thuyeenf", "thuyền"), ("khuyen", "khuyen"), ("khuyeens", "khuyến"),
            ("tuyeets", "tuyết"), ("duyeetj", "duyệt"), ("khuyeets", "khuyết"),
            ("muoons", "muốn"), ("cuoons", "cuốn"), ("uoongs", "uống"), ("buoonf", "buồn"),
            ("chuoojt", "chuột"), ("luoon", "luôn"), ("ruoongj", "ruộng"), ("thuoocj", "thuộc"),
            ("nguoonf", "nguồn"),
            ("mias", "mía"), ("tias", "tía"), ("chia", "chia"), ("chias", "chía"),
            ("khuya", "khuya"), ("chua", "chua"), ("muas", "múa"), ("mua", "mua"),
            ("cuwar", "cửa"), ("muwa", "mưa"), ("chuwa", "chưa"), ("luwar", "lửa"), ("suwax", "sữa"),
            ("khuyru", "khuỷu"), ("thuowr", "thuở"),
            ("khoai", "khoai"), ("loaij", "loại"), ("thoair", "thoải"), ("xoaif", "xoài"),
            ("tuowi", "tươi"), ("cuowif", "cười"), ("muowif", "mười"), ("duowis", "dưới"), ("buowir", "bưởi"),
            ("bawts", "bắt"), ("chawtj", "chặt"), ("nawngs", "nắng"), ("mawts", "mắt"), ("tawms", "tắm"),
            ("trawngs", "trắng"), ("lawnj", "lặn"),
            ("maast", "mất"), ("thaatj", "thật"), ("caan", "cân"), ("chaan", "chân"), ("saan", "sân"),
            ("ddaast", "đất"), ("taast", "tất"), ("nhaast", "nhất"), ("caasp", "cấp")
        ]

        var failedList: [(input: String, expected: String, actual: String)] = []
        for test in testCases {
            let result = typeString(test.input, adapter: adapter)
            if result != test.expected {
                failedList.append((test.input, test.expected, result))
            }
        }

        if !failedList.isEmpty {
            var msg = "Các từ gõ sai (\(failedList.count) từ):\n"
            for fail in failedList {
                msg += "- Gõ '\(fail.input)' -> Kỳ vọng: '\(fail.expected)', Thực tế: '\(fail.actual)'\n"
            }
            print(msg)
            #expect(failedList.isEmpty, "Có từ gõ không ra đúng")
        }
    }

    @Test("Kiểm tra các trường hợp biên nâng cao về âm tiết và ngữ âm tiếng Việt")
    func testAdvancedEdgeCases() {
        let adapter = OpenKeyEngineAdapter()

        let testCases: [(input: String, expected: String)] = [
            // 1. Phím W đứng một mình hoặc đầu từ
            ("w", "ư"),
            ("W", "Ư"),
            ("wa", "ưa"), // w -> ư, thêm a thành ưa
            ("uw", "ư"),
            ("ow", "ơ"),
            ("aw", "ă"),
            ("uow", "ươ"),
            ("uowng", "ương"),
            ("uowsc", "ước"),
            ("uowi", "ươi"),

            // 2. Bỏ dấu ở giữa từ (Mid-word tone placement)
            ("toasn", "toán"),
            ("toafn", "toàn"),
            ("vieejt", "việt"),
            ("bieest", "biết"),

            // 3. Chuỗi có chữ hoa, dấu câu và số
            ("Vieetj Nam", "Việt Nam"),
            ("Haf Nooij", "Hà Nội"),
            ("Ddaf Nawxng", "Đà Nẵng"),
            ("COVID-19", "COVID-19"),

            // 4. Nguyên âm uy / uya / uye
            ("chuyeens", "chuyến"),
            ("thuyeenf", "thuyền"),
            ("khuyeens", "khuyến"),
            ("tuyeets", "tuyết"),
            ("duyeetj", "duyệt"),
            ("khuyeets", "khuyết"),
            ("khuya", "khuya"),
            ("huyts", "huýt"),

            // 5. Khôi phục phím z và gỡ dấu
            ("toansz", "toan"),
            ("casz", "ca"),
            ("vieetjz", "viêt"), // z chỉ gỡ dấu thanh, giữ nguyên mũ

            // 6. Cụm phụ âm gi và qu với các nguyên âm đặc biệt
            ("quowr", "quở"),
            ("quoor", "quổ"),
            ("gieengs", "giếng"),
            ("gieets", "giết"),
            ("giair", "giải")
        ]

        var failedList: [(input: String, expected: String, actual: String)] = []
        for test in testCases {
            let result = typeString(test.input, adapter: adapter)
            if result != test.expected {
                failedList.append((test.input, test.expected, result))
            }
        }

        if !failedList.isEmpty {
            var msg = "Trường hợp biên nâng cao bị sai (\(failedList.count) từ):\n"
            for fail in failedList {
                msg += "- Gõ '\(fail.input)' -> Kỳ vọng: '\(fail.expected)', Thực tế: '\(fail.actual)'\n"
            }
            print(msg)
            #expect(failedList.isEmpty, "Có từ gõ biên không ra đúng")
        }
    }

    @Test("Kiểm tra kiểu gõ VNI cơ bản và dấu thanh số (1-9)")
    func testVNIBasic() {
        let adapter = OpenKeyEngineAdapter()
        adapter.engine.vInputType = .vni

        let testCases: [(input: String, expected: String)] = [
            ("a1", "á"),
            ("a2", "à"),
            ("a3", "ả"),
            ("a4", "ã"),
            ("a5", "ạ"),
            ("a6", "â"),
            ("a8", "ă"),
            ("e6", "ê"),
            ("o6", "ô"),
            ("o7", "ơ"),
            ("u7", "ư"),
            ("d9", "đ"),
            ("toan1", "toán"),
            ("viet65", "việt"),
            ("tie6ng1", "tiếng")
        ]

        var failedList: [(input: String, expected: String, actual: String)] = []
        for test in testCases {
            let result = typeString(test.input, adapter: adapter)
            if result != test.expected {
                failedList.append((test.input, test.expected, result))
            }
        }

        if !failedList.isEmpty {
            var msg = "VNI bị sai (\(failedList.count) từ):\n"
            for fail in failedList {
                msg += "- Gõ '\(fail.input)' -> Kỳ vọng: '\(fail.expected)', Thực tế: '\(fail.actual)'\n"
            }
            print(msg)
            #expect(failedList.isEmpty, "Có từ gõ VNI không ra đúng")
        }
    }
}

