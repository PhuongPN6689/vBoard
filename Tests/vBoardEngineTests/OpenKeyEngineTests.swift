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

    @Test("Kiểm tra gõ tắt phụ âm đầu OpenKey (f->ph, j->gi, w->qu)")
    func testQuickStartConsonants() {
        let engine = VietnameseEngine()
        engine.isQuickStartConsonantEnabled = true

        // f + a -> pha
        let a1 = engine.processKeystroke("f", contextBefore: "")
        #expect(a1.textToInsert == "f")
        let a2 = engine.processKeystroke("a", contextBefore: "f")
        #expect(a2.deleteCount == 1)
        #expect(a2.textToInsert == "pha")

        // F + a -> Pha
        let b1 = engine.processKeystroke("a", contextBefore: "F")
        #expect(b1.deleteCount == 1)
        #expect(b1.textToInsert == "Pha")

        // j + o -> gio
        let c1 = engine.processKeystroke("o", contextBefore: "j")
        #expect(c1.deleteCount == 1)
        #expect(c1.textToInsert == "gio")

        // w + a -> qua
        let d1 = engine.processKeystroke("a", contextBefore: "w")
        #expect(d1.deleteCount == 1)
        #expect(d1.textToInsert == "qua")
    }

    @Test("Kiểm tra gõ tắt phụ âm cuối OpenKey (g->ng, h->nh, k->ch)")
    func testQuickEndConsonants() {
        let engine = VietnameseEngine()
        engine.isQuickEndConsonantEnabled = true

        // ta + g -> tang
        let a1 = engine.processKeystroke("g", contextBefore: "ta")
        #expect(a1.deleteCount == 0)
        #expect(a1.textToInsert == "ng")

        // ta + h -> tanh
        let b1 = engine.processKeystroke("h", contextBefore: "ta")
        #expect(b1.deleteCount == 0)
        #expect(b1.textToInsert == "nh")

        // ta + k -> tach
        let c1 = engine.processKeystroke("k", contextBefore: "ta")
        #expect(c1.deleteCount == 0)
        #expect(c1.textToInsert == "ch")
    }

    @Test("Kiểm tra Macro Auto Caps trong TextProxyAdapter")
    @MainActor
    func testMacroAutoCaps() {
        let adapter = TextProxyAdapter()
        ShortcutManager.shared.addShortcut(shortcut: "dc", replacement: "được")

        // 1. Viết thường: dc -> được
        let proxy1 = MockTextDocumentProxy()
        proxy1.insertText("dc")
        adapter.handleSpace(proxy: proxy1)
        #expect(proxy1.buffer == "được ")

        // 2. Viết hoa chữ đầu: Dc -> Được
        let proxy2 = MockTextDocumentProxy()
        proxy2.insertText("Dc")
        adapter.handleSpace(proxy: proxy2)
        #expect(proxy2.buffer == "Được ")

        // 3. Viết hoa toàn bộ: DC -> ĐƯỢC
        let proxy3 = MockTextDocumentProxy()
        proxy3.insertText("DC")
        adapter.handleSpace(proxy: proxy3)
        #expect(proxy3.buffer == "ĐƯỢC ")
    }

    @Test("Kiểm tra các cờ cấu hình mới trong vBoardSettings")
    func testNewSettingsStorage() {
        let settings = vBoardSettings.shared

        settings.isSpellingCheckEnabled = false
        #expect(settings.isSpellingCheckEnabled == false)
        settings.isSpellingCheckEnabled = true
        #expect(settings.isSpellingCheckEnabled == true)

        settings.isQuickStartConsonantEnabled = true
        #expect(settings.isQuickStartConsonantEnabled == true)
        settings.isQuickStartConsonantEnabled = false
        #expect(settings.isQuickStartConsonantEnabled == false)

        settings.isQuickEndConsonantEnabled = true
        #expect(settings.isQuickEndConsonantEnabled == true)
        settings.isQuickEndConsonantEnabled = false
        #expect(settings.isQuickEndConsonantEnabled == false)

        settings.isMacroEvenWhenOffEnabled = true
        #expect(settings.isMacroEvenWhenOffEnabled == true)
        settings.isMacroEvenWhenOffEnabled = false
        #expect(settings.isMacroEvenWhenOffEnabled == false)
    }

    // MARK: - Ma trận Gõ tắt Phụ âm đầu (f->ph, j->gi, w->qu)
    @Test("Ma trận Gõ tắt phụ âm đầu (f->ph, j->gi, w->qu) với đầy đủ nguyên âm và chữ hoa/thường")
    @MainActor
    func testQuickStartConsonantMatrix() {
        let engine = VietnameseEngine()
        engine.isQuickStartConsonantEnabled = true

        let matrixCases: [(prefix: String, vowel: String, expected: String)] = [
            // f -> ph (thường)
            ("f", "a", "pha"),
            ("f", "e", "phe"),
            ("f", "i", "phi"),
            ("f", "o", "pho"),
            ("f", "u", "phu"),
            ("f", "y", "phy"),
            // F -> Ph (hoa)
            ("F", "a", "Pha"),
            ("F", "e", "Phe"),
            ("F", "o", "Pho"),
            ("F", "u", "Phu"),
            // j -> gi (thường)
            ("j", "a", "gia"),
            ("j", "e", "gie"),
            ("j", "i", "gi"),
            ("j", "o", "gio"),
            ("j", "u", "giu"),
            // J -> Gi (hoa)
            ("J", "a", "Gia"),
            ("J", "o", "Gio"),
            ("J", "u", "Giu"),
            // w -> qu (thường)
            ("w", "a", "qua"),
            ("w", "e", "que"),
            ("w", "i", "qui"),
            ("w", "o", "quo"),
            ("w", "y", "quy"),
            // W -> Qu (hoa)
            ("W", "a", "Qua"),
            ("W", "e", "Que"),
            ("W", "y", "Quy")
        ]

        for item in matrixCases {
            let adapter = TextProxyAdapter(engine: engine)
            let proxy = MockTextDocumentProxy()
            proxy.typeSequence(item.prefix + item.vowel, adapter: adapter)
            #expect(proxy.buffer == item.expected, "Gõ '\(item.prefix)\(item.vowel)' phải ra '\(item.expected)', thực tế: '\(proxy.buffer)'")
        }
    }

    // MARK: - Ma trận Gõ tắt Phụ âm cuối (g->ng, h->nh, k->ch)
    @Test("Ma trận Gõ tắt phụ âm cuối (g->ng, h->nh, k->ch) sau mọi nguyên âm")
    @MainActor
    func testQuickEndConsonantMatrix() {
        let engine = VietnameseEngine()
        engine.isQuickEndConsonantEnabled = true

        let matrixCases: [(base: String, endKey: String, expected: String)] = [
            // g -> ng
            ("ta", "g", "tang"),
            ("ba", "g", "bang"),
            ("to", "g", "tong"),
            ("du", "g", "dung"),
            ("co", "g", "cong"),
            ("le", "g", "leng"),
            ("luo", "g", "luong"),
            ("tie", "g", "tieng"),
            // h -> nh
            ("ta", "h", "tanh"),
            ("ba", "h", "banh"),
            ("ca", "h", "canh"),
            ("da", "h", "danh"),
            ("ti", "h", "tinh"),
            ("mi", "h", "minh"),
            ("xi", "h", "xinh"),
            // k -> ch
            ("ta", "k", "tach"),
            ("ba", "k", "bach"),
            ("ca", "k", "cach"),
            ("ti", "k", "tich"),
            ("li", "k", "lich"),
            ("e", "k", "ech")
        ]

        for item in matrixCases {
            let adapter = TextProxyAdapter(engine: engine)
            let proxy = MockTextDocumentProxy()
            proxy.typeSequence(item.base + item.endKey, adapter: adapter)
            #expect(proxy.buffer == item.expected, "Gõ '\(item.base)\(item.endKey)' phải ra '\(item.expected)', thực tế: '\(proxy.buffer)'")
        }
    }

    // MARK: - Kết hợp Phụ âm đầu và Phụ âm cuối trong cùng một từ
    @Test("Kiểm tra gõ kết hợp cả phụ âm đầu rút gọn và phụ âm cuối rút gọn trong 1 từ")
    @MainActor
    func testCombinedStartAndEndConsonants() {
        let engine = VietnameseEngine()
        engine.isQuickStartConsonantEnabled = true
        engine.isQuickEndConsonantEnabled = true

        let cases: [(input: String, expected: String)] = [
            ("fag", "phang"), // f->ph, a, g->ng
            ("fah", "phanh"), // f->ph, a, h->nh
            ("fak", "phach"), // f->ph, a, k->ch
            ("jag", "giang"), // j->gi, a, g->ng
            ("wah", "quanh"), // w->qu, a, h->nh
            ("wag", "quang")  // w->qu, a, g->ng
        ]

        for item in cases {
            let adapter = TextProxyAdapter(engine: engine)
            let proxy = MockTextDocumentProxy()
            proxy.typeSequence(item.input, adapter: adapter)
            #expect(proxy.buffer == item.expected, "Gõ '\(item.input)' phải ra '\(item.expected)', thực tế: '\(proxy.buffer)'")
        }
    }

    // MARK: - Kiểm tra Toàn diện Đặt Dấu Thanh: Chuẩn Cũ (oà, uý) vs Chuẩn Mới (òa, úy)
    @Test("Kiểm tra chi tiết quy tắc đặt dấu Chuẩn Cũ (oà, uý) vs Chuẩn Mới (òa, úy)")
    @MainActor
    func testDiacriticStyleSwitchingMatrix() {
        let engine = VietnameseEngine()

        let wordPairs: [(input: String, modern: String, classic: String)] = [
            ("hoaf", "hòa", "hoà"),
            ("hoas", "hóa", "hoá"),
            ("hoar", "hỏa", "hoả"),
            ("hoax", "hõa", "hoã"),
            ("hoaj", "họa", "hoạ"),
            ("khoer", "khỏe", "khoẻ"),
            ("thuyf", "thùy", "thuỳ"),
            ("thuys", "thúy", "thuý"),
            ("thuyr", "thủy", "thuỷ"),
            ("thuyx", "thũy", "thuỹ"),
            ("thuyj", "thụy", "thuỵ"),
            ("xoaf", "xòa", "xoà"),
            ("loaj", "lọa", "loạ")
        ]

        for item in wordPairs {
            // 1. Kiểm tra Chuẩn Mới
            engine.diacriticStyle = .newStyle
            let adapterModern = TextProxyAdapter(engine: engine)
            let proxyModern = MockTextDocumentProxy()
            proxyModern.typeSequence(item.input, adapter: adapterModern)
            #expect(proxyModern.buffer == item.modern, "Chuẩn mới gõ '\(item.input)' phải ra '\(item.modern)', thực tế: '\(proxyModern.buffer)'")

            // 2. Kiểm tra Chuẩn Cũ
            engine.diacriticStyle = .oldStyle
            let adapterClassic = TextProxyAdapter(engine: engine)
            let proxyClassic = MockTextDocumentProxy()
            proxyClassic.typeSequence(item.input, adapter: adapterClassic)
            #expect(proxyClassic.buffer == item.classic, "Chuẩn cũ gõ '\(item.input)' phải ra '\(item.classic)', thực tế: '\(proxyClassic.buffer)'")
        }
    }

    // MARK: - Kiểm tra Tắt Gõ tắt (Disable Shortcut Expansion)
    @Test("Kiểm tra khi tắt gõ tắt thì nhấn Space không bị thay thế")
    @MainActor
    func testMacroDisabledDoesNotExpand() {
        let adapter = TextProxyAdapter()
        ShortcutManager.shared.addShortcut(shortcut: "dc", replacement: "được")

        vBoardSettings.shared.isShortcutExpansionEnabled = false

        let proxy = MockTextDocumentProxy()
        proxy.insertText("dc")
        adapter.handleSpace(proxy: proxy)
        #expect(proxy.buffer == "dc ", "Khi tắt gõ tắt, 'dc' + space phải giữ nguyên 'dc '")

        // Khôi phục lại trạng thái bật
        vBoardSettings.shared.isShortcutExpansionEnabled = true
    }

    // MARK: - Kiểm tra CRUD ShortcutManager (Thêm, Sửa, Xóa, Reset)
    @Test("Kiểm tra CRUD toàn diện trên ShortcutManager")
    func testShortcutManagerCRUD() {
        let manager = ShortcutManager.shared

        // Thêm mới
        manager.addShortcut(shortcut: "testkey", replacement: "giá trị thử nghiệm")
        #expect(manager.replacement(for: "testkey") == "giá trị thử nghiệm")
        #expect(manager.replacement(for: "TESTKEY") == "giá trị thử nghiệm") // case-insensitive

        // Xóa
        manager.deleteShortcut(shortcut: "testkey")
        #expect(manager.replacement(for: "testkey") == nil)

        // Reset về mặc định
        manager.resetToDefaults()
        let defaultsList = manager.getShortcuts()
        #expect(defaultsList.contains { $0.shortcut == "dc" })
        #expect(defaultsList.contains { $0.shortcut == "vn" })
    }

    // MARK: - Kiểm tra Gõ tắt Phụ âm kết hợp Bỏ dấu (vd: fair => phải)
    @Test("Kiểm tra gõ tắt phụ âm kết hợp bỏ dấu thanh và nhiều nguyên âm (fair -> phải, fangs -> phóng/phẳng, jair -> giải)")
    @MainActor
    func testQuickConsonantsWithTonesAndComplexWords() {
        let engine = VietnameseEngine()
        engine.isQuickStartConsonantEnabled = true
        engine.isQuickEndConsonantEnabled = true
        let adapter = TextProxyAdapter(engine: engine)

        let testCases: [(input: String, expected: String)] = [
            // f -> ph kết hợp các dấu thanh (s, f, r, x, j)
            ("fair", "phải"),
            ("fais", "phái"),
            ("faif", "phài"),
            ("faix", "phãi"),
            ("faij", "phại"),
            ("fas", "phá"),
            ("faf", "phà"),
            ("far", "phả"),
            ("fax", "phã"),
            ("faj", "phạ"),
            ("fats", "phát"),
            ("fans", "phán"),
            ("fongf", "phòng"),
            ("fongs", "phóng"),
            ("Fair", "Phải"),
            ("FAIR", "PHẢI"),

            // j -> gi kết hợp bỏ dấu
            ("jair", "giải"),
            ("jais", "giái"),
            ("jaif", "giài"),
            ("jaix", "giãi"),
            ("jaij", "giại"),
            ("jas", "giá"),
            ("jaf", "già"),
            ("jar", "giả"),
            ("jax", "giã"),
            ("jaj", "giạ"),
            ("Jair", "Giải"),

            // w -> qu kết hợp bỏ dấu
            ("wair", "quải"),
            ("wais", "quái"),
            ("waif", "quài"),
            ("waix", "quãi"),
            ("waij", "quại"),
            ("was", "quá"),
            ("waf", "quà"),
            ("war", "quả"),
            ("wax", "quã"),
            ("waj", "quạ"),
            ("Wair", "Quải"),

            // f + nguyên âm + phụ âm cuối rút gọn g->ng, h->nh + dấu thanh
            ("fags", "pháng"),
            ("fagf", "phàng"),
            ("fagr", "phảng"),
            ("fahs", "phánh"),
            ("faks", "phách"),
            ("fakt", "phacht")
        ]

        for item in testCases {
            let proxy = MockTextDocumentProxy()
            proxy.typeSequence(item.input, adapter: adapter)
            #expect(proxy.buffer == item.expected, "Gõ '\(item.input)' phải ra '\(item.expected)', thực tế: '\(proxy.buffer)'")
        }
    }

    // MARK: - Kiểm tra Toàn diện các Ca biên lai ghép và Tổ hợp Nuance sâu sắc
    @Test("Kiểm tra toàn diện các ca biên lai ghép (j+i, w+u, dấu thanh trước phụ âm cuối rút gọn, đổi dấu trực tiếp, hoàn tác w)")
    @MainActor
    func testAdvancedEdgeCasesAndNuancedCombinations() {
        let engine = VietnameseEngine()
        engine.isQuickStartConsonantEnabled = true
        engine.isQuickEndConsonantEnabled = true
        engine.isWAtWordBeginningEnabled = true
        engine.isAutoUndoEnabled = true
        engine.isModernToneBalancingEnabled = true
        let adapter = TextProxyAdapter(engine: engine)

        let testCases: [(input: String, expected: String)] = [
            // 1. Phụ âm 'j' kết hợp âm bắt đầu bằng 'i' (giếng, gì, gí, gỉ, gĩ, gị, gìn)
            ("jif", "gì"),
            ("jis", "gí"),
            ("jir", "gỉ"),
            ("jix", "gĩ"),
            ("jij", "gị"),
            ("jieengs", "giếng"),
            ("jieengf", "giềng"),
            ("jinf", "gìn"),
            ("jins", "gín"),
            ("Jif", "Gì"),
            ("JIEENGS", "GIẾNG"),

            // 2. Phụ âm 'w' kết hợp 'u' và các vần (quốc, quyền, quắn, quơ, quờng)
            ("wuoocs", "quốc"),
            ("wuoocj", "quộc"),
            ("wuyeens", "quyến"),
            ("wuyeenf", "quyền"),
            ("wuyeenr", "quyển"),
            ("waws", "quắ"),
            ("wawns", "quắn"),
            ("wawf", "quằ"),
            ("wawnf", "quằn"),
            ("wows", "quớ"),
            ("wowf", "quờ"),
            ("wowngf", "quờng"),
            ("WUOOCS", "QUỐC"),
            ("WUYEENS", "QUYẾN"),

            // 3. Gõ DẤU THANH TRƯỚC phụ âm cuối rút gọn (tasg -> táng, tash -> tánh, task -> tách)
            ("tasg", "táng"),
            ("tafg", "tàng"),
            ("targ", "tảng"),
            ("taxg", "tãng"),
            ("tajg", "tạng"),
            ("tash", "tánh"),
            ("tafh", "tành"),
            ("tarh", "tảnh"),
            ("taxh", "tãnh"),
            ("tajh", "tạnh"),
            ("task", "tách"),
            ("tajk", "tạch"),

            // Kết hợp cả phụ âm đầu rút gọn + dấu thanh trước phụ âm cuối rút gọn
            ("fasg", "pháng"),
            ("fash", "phánh"),
            ("fask", "phách"),
            ("fajk", "phạch"),
            ("wasg", "quáng"),
            ("wash", "quánh"),
            ("wask", "quách"),
            ("wajk", "quạch"),
            ("jasg", "giáng"),
            ("jash", "giánh"),
            ("jask", "giách"),
            ("jajk", "giạch"),

            // 4. Phụ âm đầu rút gọn kết hợp nguyên âm phức tạp
            ("foong", "phông"),
            ("foongs", "phống"),
            ("foongf", "phồng"),
            ("fongf", "phòng"),
            ("fongs", "phóng"),
            ("fuowng", "phương"),
            ("fuowngf", "phường"),
            ("fuowngs", "phướng"),
            ("feens", "phến"),
            ("juowngf", "giường"),
            ("juoongj", "giuộng"),
            ("jups", "giúp"),

            // 5. Đổi dấu thanh trực tiếp giữa các phím dấu (Tone replacement)
            ("cafs", "cá"),
            ("casf", "cà"),
            ("cars", "cá"),
            ("toansf", "toàn"),
            ("toanfr", "toản"),

            // 6. Phím 'w' độc lập ở đầu từ & các dấu thanh
            ("ws", "ứ"),
            ("wf", "ừ"),
            ("wr", "ử"),
            ("wx", "ữ"),
            ("wj", "ự"),
            ("ww", "w"),
            ("wweb", "web"),

            // 7. Từ chứa phụ âm ngoại lai z, j, f, w kết hợp cơ chế hoàn tác gõ đúp tiếng Anh
            ("zalo", "zalo"),
            ("zooom", "zoom"),
            ("jjava", "java"),
            ("ffan", "fan")
        ]

        for item in testCases {
            let proxy = MockTextDocumentProxy()
            proxy.typeSequence(item.input, adapter: adapter)
            #expect(proxy.buffer == item.expected, "Gõ '\(item.input)' phải ra '\(item.expected)', thực tế: '\(proxy.buffer)'")
        }
    }

    // MARK: - Kiểm tra Siêu Toàn Diện: Ngoặc Vuông, Hoàn Tác Gõ Đúp, Tổ hợp w+o, Simple Telex
    @Test("Kiểm tra Siêu Toàn Diện: Ngoặc vuông [[/]], Hoàn tác gõ đúp Quick Telex và phụ âm cuối, Tổ hợp w+o->ươ, Simple Telex")
    @MainActor
    func testUltraComprehensiveTypingNuancesAndRestores() {
        let engine = VietnameseEngine()
        engine.isQuickStartConsonantEnabled = true
        engine.isQuickEndConsonantEnabled = true
        engine.isQuickTelexEnabled = true
        engine.isBracketShortcutsEnabled = true
        engine.isWAtWordBeginningEnabled = true
        engine.isAutoUndoEnabled = true
        engine.isModernToneBalancingEnabled = true
        let adapter = TextProxyAdapter(engine: engine)

        // 1. Kiểm tra gõ đúp ngoặc vuông để khôi phục ký tự gốc: [[ -> [, ]] -> ], {{ -> {, }} -> }
        let bracketCases: [(input: String, expected: String)] = [
            ("[[", "["),
            ("]]", "]"),
            ("{{", "{"),
            ("}}", "}"),
            ("t[", "tơ"),
            ("t[[", "t["),
            ("t]", "tư"),
            ("t]]", "t]")
        ]
        for item in bracketCases {
            let proxy = MockTextDocumentProxy()
            proxy.typeSequence(item.input, adapter: adapter)
            #expect(proxy.buffer == item.expected, "Gõ ngoặc '\(item.input)' phải ra '\(item.expected)', thực tế: '\(proxy.buffer)'")
        }

        // 2. Kiểm tra gõ đúp phụ âm cuối rút gọn để khôi phục từ tiếng Anh: tagg -> tag, ahh -> ah, okk -> ok
        let endConsonantUndoCases: [(input: String, expected: String)] = [
            ("tagg", "tag"),
            ("dogg", "dog"),
            ("blogg", "blog"),
            ("tahh", "tah"),
            ("ahh", "ah"),
            ("ohh", "oh"),
            ("takk", "tak"),
            ("okk", "ok"),
            ("boookk", "book")
        ]
        for item in endConsonantUndoCases {
            let proxy = MockTextDocumentProxy()
            proxy.typeSequence(item.input, adapter: adapter)
            #expect(proxy.buffer == item.expected, "Gõ đúp phụ âm cuối '\(item.input)' phải ra '\(item.expected)', thực tế: '\(proxy.buffer)'")
        }

        // 3. Kiểm tra gõ lặp 3 lần Quick Telex để khôi phục từ tiếng Anh: accc -> acc, appp -> app, connn -> conn, httt -> htt
        let quickTelexUndoCases: [(input: String, expected: String)] = [
            ("accc", "acc"),
            ("appp", "app"),
            ("connn", "conn"),
            ("httt", "htt")
        ]
        for item in quickTelexUndoCases {
            let proxy = MockTextDocumentProxy()
            proxy.typeSequence(item.input, adapter: adapter)
            #expect(proxy.buffer == item.expected, "Gõ đúp Quick Telex '\(item.input)' phải ra '\(item.expected)', thực tế: '\(proxy.buffer)'")
        }

        // 4. Kiểm tra tổ hợp gõ tắt w sau phụ âm + o -> ươ (thwong -> thương, nwocs -> nước, trwongf -> trường)
        let wPlusOCases: [(input: String, expected: String)] = [
            ("thwong", "thương"),
            ("thwongs", "thướng"),
            ("nwoc", "nươc"),
            ("nwocs", "nước"),
            ("trwong", "trương"),
            ("trwongf", "trường"),
            ("ddwocj", "được"),
            ("ddwongf", "đường"),
            ("xwong", "xương"),
            ("rwouj", "rượu"),
            ("chwa", "chưa"),
            ("cwar", "cửa"),
            ("mwas", "mứa"),
            ("mwaj", "mựa")
        ]
        for item in wPlusOCases {
            let proxy = MockTextDocumentProxy()
            proxy.typeSequence(item.input, adapter: adapter)
            #expect(proxy.buffer == item.expected, "Tổ hợp w+o '\(item.input)' phải ra '\(item.expected)', thực tế: '\(proxy.buffer)'")
        }

        // 5. Kiểm tra Simple Telex (tự động ie->iê, uo->uô khi có phụ âm cuối)
        let simpleEngine = VietnameseEngine(inputMethod: .simpleTelex)
        let simpleAdapter = TextProxyAdapter(engine: simpleEngine)
        let simpleCases: [(input: String, expected: String)] = [
            ("tieng", "tiêng"),
            ("tiengs", "tiếng"),
            ("biets", "biết"),
            ("viets", "viết"),
            ("muons", "muốn"),
            ("buonf", "buồn"),
            ("cuocj", "cuộc")
        ]
        for item in simpleCases {
            let proxy = MockTextDocumentProxy()
            proxy.typeSequence(item.input, adapter: simpleAdapter)
            #expect(proxy.buffer == item.expected, "Simple Telex '\(item.input)' phải ra '\(item.expected)', thực tế: '\(proxy.buffer)'")
        }
    }
}

