import Testing
import Foundation
@testable import vBoardEngine

/// Bộ kiểm thử Ma trận Cấu hình Toàn diện (Comprehensive Configuration Matrix Tests)
/// Kiểm tra từ giá trị mặc định khi khởi tạo đến từng hoán vị cấu hình độc lập và kết hợp đa cấu hình
@Suite("Bộ kiểm thử Ma trận Cấu hình và Giá trị Mặc định vBoardEngine")
@MainActor
struct ConfigurationMatrixTests {

    // MARK: - 1. Kiểm tra Giá trị Mặc định khi Khởi tạo (Default Configuration Values)

    @Test("Kiểm tra giá trị mặc định của vBoardSettings khi vừa khởi tạo")
    func testVBoardSettingsDefaultValues() {
        let settings = vBoardSettings.shared

        // Giá trị mặc định của kiểu gõ và dấu thanh
        #expect(settings.inputMethod == .telex, "Mặc định kiểu gõ phải là Telex")
        #expect(settings.diacriticStyle == .newStyle, "Mặc định kiểu bỏ dấu phải là Chuẩn mới (òa, úy)")

        // Kiểm tra chính tả & khôi phục
        #expect(settings.isSpellingCheckEnabled == true, "Mặc định kiểm tra chính tả phải BẬT")
        #expect(settings.isRestoreIfWrongSpellingEnabled == false, "Mặc định khôi phục phím khi sai chính tả phải TẮT")
        #expect(settings.isFixBrowserSuggestionEnabled == true, "Mặc định sửa gợi ý URL trình duyệt phải BẬT")

        // Quick Telex & Viết tắt phụ âm
        #expect(settings.isQuickTelexEnabled == false, "Mặc định Quick Telex phải TẮT theo chuẩn OpenKey C++")
        #expect(settings.isQuickStartConsonantEnabled == false, "Mặc định gõ tắt phụ âm đầu (f->ph, j->gi, w->qu) phải TẮT")
        #expect(settings.isQuickEndConsonantEnabled == false, "Mặc định gõ tắt phụ âm cuối (g->ng, h->nh, k->ch) phải TẮT")
        #expect(settings.isAllowConsonantZFWJEnabled == false, "Mặc định cho phép phụ âm ngoại lai Z, F, W, J phải TẮT")

        // Tính năng nâng cao OpenKey
        #expect(settings.isSmartSwitchModeEnabled == true, "Mặc định chuyển đổi thông minh phải BẬT")
        #expect(settings.isMacroEvenWhenOffEnabled == false, "Mặc định gõ tắt khi tắt tiếng Việt phải TẮT")
        #expect(settings.isShortcutExpansionEnabled == true, "Mặc định mở rộng gõ tắt cá nhân phải BẬT")
        #expect(settings.isAutoCapsMacroEnabled == true, "Mặc định AutoCaps macro phải BẬT")
        #expect(settings.isBracketShortcutsEnabled == true, "Mặc định phím ngoặc vuông [ ] gõ nhanh ơ, ư phải BẬT")
        #expect(settings.isZKeyRemoveToneEnabled == true, "Mặc định phím Z gỡ dấu phải BẬT")
        #expect(settings.isWAtWordBeginningEnabled == true, "Mặc định phím W đầu từ thành Ư phải BẬT")
        #expect(settings.isAutoUndoEnabled == true, "Mặc định hoàn tác tự động FSM phải BẬT")

        // Bàn phím & Trợ năng
        #expect(settings.isAutoCapitalizationEnabled == true, "Mặc định tự động viết hoa đầu câu phải BẬT")
        #expect(settings.isSpaceDoubleTapPeriodEnabled == true, "Mặc định nhấn đúp Space thành dấu chấm phải BẬT")
    }

    @Test("Kiểm tra giá trị mặc định của lõi OpenKeyEngine khi vừa khởi tạo")
    func testOpenKeyEngineDefaultValues() {
        let engine = OpenKeyEngine()

        #expect(engine.vInputType == .telex, "Mặc định vInputType phải là Telex")
        #expect(engine.vUseModernOrthography == 0, "Mặc định vUseModernOrthography phải là 0 (Chuẩn mới òa, úy)")
        #expect(engine.vCheckSpelling == 1, "Mặc định vCheckSpelling phải là 1 (Bật)")
        #expect(engine.vQuickTelex == 0, "Mặc định vQuickTelex phải là 0 (Tắt)")
        #expect(engine.vQuickStartConsonant == 0, "Mặc định vQuickStartConsonant phải là 0 (Tắt)")
        #expect(engine.vQuickEndConsonant == 0, "Mặc định vQuickEndConsonant phải là 0 (Tắt)")
        #expect(engine.vRestoreIfWrongSpelling == 0, "Mặc định vRestoreIfWrongSpelling phải là 0 (Tắt)")
        #expect(engine.vAllowConsonantZFWJ == 0, "Mặc định vAllowConsonantZFWJ phải là 0 (Tắt)")
        #expect(engine.vUseMacro == 1, "Mặc định vUseMacro phải là 1 (Bật)")
        #expect(engine.vAutoCapsMacro == 1, "Mặc định vAutoCapsMacro phải là 1 (Bật)")
        #expect(engine.isBracketShortcutsEnabled == true, "Mặc định isBracketShortcutsEnabled phải là true")
        #expect(engine.isZKeyRemoveToneEnabled == true, "Mặc định isZKeyRemoveToneEnabled phải là true")
        #expect(engine.isWAtWordBeginningEnabled == true, "Mặc định isWAtWordBeginningEnabled phải là true")
        #expect(engine.isAutoUndoEnabled == true, "Mặc định isAutoUndoEnabled phải là true")
    }

    @Test("Kiểm tra hành vi gõ thực tế với toàn bộ cấu hình Mặc định (Default Behavior)")
    func testDefaultTypingBehavior() {
        // Khởi tạo Adapter với toàn bộ cấu hình mặc định
        let adapter = TextProxyAdapter()

        let defaultCases: [(input: String, expected: String, description: String)] = [
            // viettel không bị thành viethel (do Quick Telex mặc định tắt)
            ("viettel", "viettel", "viettel phải giữ nguyên viettel"),
            ("letter", "letter", "letter phải giữ nguyên letter"),
            ("cc", "cc", "cc phải giữ nguyên cc"),
            ("tt", "tt", "tt phải giữ nguyên tt"),

            // moiws ra mới (chuẩn Telex cơ bản)
            ("moiws", "mới", "moiws phải ra mới"),

            // Đặt dấu thanh chuẩn mới mặc định: hòa (thay vì hoà), thủy (thay vì thuỳ)
            ("hoaf", "hòa", "hoaf mặc định phải ra hòa (chuẩn mới)"),
            ("hoas", "hóa", "hoas mặc định phải ra hóa (chuẩn mới)"),
            ("thuyf", "thùy", "thuyf mặc định phải ra thùy (chuẩn mới)"),
            ("thuys", "thúy", "thuys mặc định phải ra thúy (chuẩn mới)"),
            ("thuyr", "thủy", "thuyr mặc định phải ra thủy (chuẩn mới)"),
            ("toans", "toán", "toans phải ra toán"),

            // Phụ âm đầu rút gọn mặc định TẮT -> không tự đổi fair thành phải
            ("fair", "fair", "fair không bị đổi thành phải khi gõ tắt tắt"),

            // Phụ âm cuối rút gọn mặc định TẮT -> không tự đổi tag thành tang
            ("tag", "tag", "tag không bị đổi thành tang khi gõ tắt tắt"),

            // Phím Z gỡ dấu mặc định BẬT
            ("toansz", "toan", "Phím z mặc định gỡ dấu thành toan"),
            ("casz", "ca", "Phím z mặc định gỡ dấu thành ca"),

            // Phím ngoặc vuông mặc định BẬT
            ("[", "ơ", "Phím [ mặc định ra ơ"),
            ("]", "ư", "Phím ] mặc định ra ư"),

            // Phím W đầu từ mặc định BẬT
            ("w", "ư", "Phím w đầu từ mặc định ra ư"),
            ("ws", "ứ", "Phím ws mặc định ra ứ")
        ]

        for item in defaultCases {
            let proxy = MockTextDocumentProxy()
            proxy.typeSequence(item.input, adapter: adapter)
            #expect(proxy.buffer == item.expected, "\(item.description): Kỳ vọng '\(item.expected)', thực tế: '\(proxy.buffer)'")
        }
    }

    // MARK: - 2. Ma trận Kiểu Gõ (Input Method: Telex, VNI, Simple Telex)

    @Test("Ma trận chuyển đổi qua lại giữa các Kiểu gõ (Telex, VNI, Simple Telex)")
    func testInputMethodMatrix() {
        let testMatrix: [(telex: String, vni: String, simple: String, expected: String)] = [
            ("tieengs", "tie6ng1", "tiengs", "tiếng"),
            ("Vieetj", "Vie6t5", "Vietj", "Việt"),
            ("dduowngf", "d9u7o7ng2", "dduowngf", "đường"),
            ("hoaf", "hoa2", "hoaf", "hòa"),
            ("toans", "toan1", "toans", "toán"),
            ("nguowif", "ngu7o7i2", "nguowif", "người"),
            ("dduowcj", "d9u7o7c5", "dduowcj", "được")
        ]

        for item in testMatrix {
            // 1. Kiểm tra Telex
            let engineTelex = OpenKeyEngine()
            engineTelex.vInputType = .telex
            let adapterTelex = TextProxyAdapter(engine: engineTelex)
            let proxyTelex = MockTextDocumentProxy()
            proxyTelex.typeSequence(item.telex, adapter: adapterTelex)
            #expect(proxyTelex.buffer == item.expected, "Telex '\(item.telex)' phải ra '\(item.expected)', thực tế: '\(proxyTelex.buffer)'")

            // 2. Kiểm tra VNI
            let engineVNI = OpenKeyEngine()
            engineVNI.vInputType = .vni
            let adapterVNI = TextProxyAdapter(engine: engineVNI)
            let proxyVNI = MockTextDocumentProxy()
            proxyVNI.typeSequence(item.vni, adapter: adapterVNI)
            #expect(proxyVNI.buffer == item.expected, "VNI '\(item.vni)' phải ra '\(item.expected)', thực tế: '\(proxyVNI.buffer)'")

            // 3. Kiểm tra Simple Telex
            let engineSimple = OpenKeyEngine()
            engineSimple.vInputType = .simpleTelex1
            let adapterSimple = TextProxyAdapter(engine: engineSimple)
            let proxySimple = MockTextDocumentProxy()
            proxySimple.typeSequence(item.simple, adapter: adapterSimple)
            #expect(proxySimple.buffer == item.expected, "Simple Telex '\(item.simple)' phải ra '\(item.expected)', thực tế: '\(proxySimple.buffer)'")
        }
    }

    // MARK: - 3. Ma trận Phong cách Đặt dấu (Diacritic Style: Chuẩn Mới vs Chuẩn Cũ)

    @Test("Ma trận Phong cách Đặt dấu (Chuẩn mới òa, úy vs Chuẩn cũ oà, uý) trên cả Telex và VNI")
    func testDiacriticStyleMatrixOnTelexAndVNI() {
        let pairs: [(telex: String, vni: String, modern: String, classic: String)] = [
            ("hoaf", "hoa2", "hòa", "hoà"),
            ("hoas", "hoa1", "hóa", "hoá"),
            ("hoar", "hoa3", "hỏa", "hoả"),
            ("hoax", "hoa4", "hõa", "hoã"),
            ("hoaj", "hoa5", "họa", "hoạ"),
            ("khoer", "khoe3", "khỏe", "khoẻ"),
            ("thuyf", "thuy2", "thùy", "thuỳ"),
            ("thuys", "thuy1", "thúy", "thuý"),
            ("thuyr", "thuy3", "thủy", "thuỷ"),
            ("thuyx", "thuy4", "thũy", "thuỹ"),
            ("thuyj", "thuy5", "thụy", "thuỵ"),
            ("xoaf", "xoa2", "xòa", "xoà"),
            ("loaj", "loa5", "lọa", "loạ"),
            ("toans", "toan1", "toán", "toán"), // Có phụ âm cuối -> cả 2 chuẩn đều đặt ở 'a'
            ("toanf", "toan2", "toàn", "toàn"),
            ("tieengs", "tie6ng1", "tiếng", "tiếng")
        ]

        let engine = OpenKeyEngine()
        let adapter = TextProxyAdapter(engine: engine)

        for item in pairs {
            // A. Chuẩn Mới (vUseModernOrthography = 0)
            engine.vUseModernOrthography = 0

            // Telex Chuẩn Mới
            engine.vInputType = .telex
            let pTelexMod = MockTextDocumentProxy()
            pTelexMod.typeSequence(item.telex, adapter: adapter)
            #expect(pTelexMod.buffer == item.modern, "Telex Chuẩn Mới '\(item.telex)' -> '\(item.modern)', thực tế: '\(pTelexMod.buffer)'")

            // VNI Chuẩn Mới
            engine.vInputType = .vni
            let pVniMod = MockTextDocumentProxy()
            pVniMod.typeSequence(item.vni, adapter: adapter)
            #expect(pVniMod.buffer == item.modern, "VNI Chuẩn Mới '\(item.vni)' -> '\(item.modern)', thực tế: '\(pVniMod.buffer)'")

            // B. Chuẩn Cũ (vUseModernOrthography = 1)
            engine.vUseModernOrthography = 1

            // Telex Chuẩn Cũ
            engine.vInputType = .telex
            let pTelexCla = MockTextDocumentProxy()
            pTelexCla.typeSequence(item.telex, adapter: adapter)
            #expect(pTelexCla.buffer == item.classic, "Telex Chuẩn Cũ '\(item.telex)' -> '\(item.classic)', thực tế: '\(pTelexCla.buffer)'")

            // VNI Chuẩn Cũ
            engine.vInputType = .vni
            let pVniCla = MockTextDocumentProxy()
            pVniCla.typeSequence(item.vni, adapter: adapter)
            #expect(pVniCla.buffer == item.classic, "VNI Chuẩn Cũ '\(item.vni)' -> '\(item.classic)', thực tế: '\(pVniCla.buffer)'")
        }
    }

    // MARK: - 4. Ma trận Quick Telex (Bật vs Tắt)

    @Test("Ma trận Quick Telex: Bật vs Tắt")
    func testQuickTelexToggleMatrix() {
        let engine = OpenKeyEngine()
        let adapter = TextProxyAdapter(engine: engine)

        let cases: [(input: String, whenOff: String, whenOn: String)] = [
            ("viettel", "viettel", "viethel"),
            ("letter", "letter", "lether"),
            ("cc", "cc", "ch"),
            ("tt", "tt", "th"),
            ("pp", "pp", "ph"),
            ("kk", "kk", "kh"),
            ("nn", "nn", "ng"),
            ("tuuj", "tụu", "tượ")
        ]

        for item in cases {
            // Khi TẮT Quick Telex
            engine.isQuickTelexEnabled = false
            let proxyOff = MockTextDocumentProxy()
            proxyOff.typeSequence(item.input, adapter: adapter)
            #expect(proxyOff.buffer == item.whenOff, "Quick Telex TẮT: '\(item.input)' phải ra '\(item.whenOff)', thực tế: '\(proxyOff.buffer)'")

            // Khi BẬT Quick Telex
            engine.isQuickTelexEnabled = true
            let proxyOn = MockTextDocumentProxy()
            proxyOn.typeSequence(item.input, adapter: adapter)
            #expect(proxyOn.buffer == item.whenOn, "Quick Telex BẬT: '\(item.input)' phải ra '\(item.whenOn)', thực tế: '\(proxyOn.buffer)'")
        }
    }

    // MARK: - 5. Ma trận Viết Tắt Phụ Âm Đầu & Cuối (Quick Start & End Consonants)

    @Test("Ma trận Viết tắt phụ âm đầu (f, j, w) và phụ âm cuối (g, h, k)")
    func testQuickConsonantsMatrix() {
        let engine = OpenKeyEngine()
        let adapter = TextProxyAdapter(engine: engine)

        // Phụ âm đầu: f->ph, j->gi, w->qu
        let startCases: [(input: String, whenOff: String, whenOn: String)] = [
            ("fair", "fair", "phải"),
            ("feens", "feens", "phến"),
            ("jair", "jair", "giải"),
            ("jif", "jif", "gì"),
            ("was", "ứa", "quá"),
            ("wa", "ưa", "qua")
        ]

        for item in startCases {
            engine.isQuickStartConsonantEnabled = false
            let pOff = MockTextDocumentProxy()
            pOff.typeSequence(item.input, adapter: adapter)
            #expect(pOff.buffer == item.whenOff, "Gõ tắt đầu TẮT: '\(item.input)' -> '\(item.whenOff)', thực tế: '\(pOff.buffer)'")

            engine.isQuickStartConsonantEnabled = true
            let pOn = MockTextDocumentProxy()
            pOn.typeSequence(item.input, adapter: adapter)
            #expect(pOn.buffer == item.whenOn, "Gõ tắt đầu BẬT: '\(item.input)' -> '\(item.whenOn)', thực tế: '\(pOn.buffer)'")
        }

        // Phụ âm cuối: g->ng, h->nh, k->ch
        let endCases: [(input: String, whenOff: String, whenOn: String)] = [
            ("tag", "tag", "tang"),
            ("tah", "tah", "tanh"),
            ("tak", "tak", "tach"),
            ("tasg", "tág", "táng"),
            ("tash", "táh", "tánh"),
            ("task", "ták", "tách")
        ]

        for item in endCases {
            engine.isQuickStartConsonantEnabled = false
            engine.isQuickEndConsonantEnabled = false
            let pOff = MockTextDocumentProxy()
            pOff.typeSequence(item.input, adapter: adapter)
            #expect(pOff.buffer == item.whenOff, "Gõ tắt cuối TẮT: '\(item.input)' -> '\(item.whenOff)', thực tế: '\(pOff.buffer)'")

            engine.isQuickEndConsonantEnabled = true
            let pOn = MockTextDocumentProxy()
            pOn.typeSequence(item.input, adapter: adapter)
            #expect(pOn.buffer == item.whenOn, "Gõ tắt cuối BẬT: '\(item.input)' -> '\(item.whenOn)', thực tế: '\(pOn.buffer)'")
        }

        // Kết hợp CẢ phụ âm đầu và phụ âm cuối
        engine.isQuickStartConsonantEnabled = true
        engine.isQuickEndConsonantEnabled = true
        let combinedCases: [(input: String, expected: String)] = [
            ("fag", "phang"),
            ("fah", "phanh"),
            ("fak", "phach"),
            ("jag", "giang"),
            ("wah", "quanh"),
            ("wag", "quang"),
            ("fasg", "pháng"),
            ("wasg", "quáng"),
            ("jask", "giách")
        ]
        for item in combinedCases {
            let pComb = MockTextDocumentProxy()
            pComb.typeSequence(item.input, adapter: adapter)
            #expect(pComb.buffer == item.expected, "Kết hợp cả đầu & cuối: '\(item.input)' -> '\(item.expected)', thực tế: '\(pComb.buffer)'")
        }
    }

    // MARK: - 6. Ma trận Phím Z gỡ dấu & Phím Ngoặc vuông & Phím W đầu từ

    @Test("Ma trận Phím Z gỡ dấu, Phím Ngoặc vuông [ ] và Phím W đầu từ")
    func testSpecialKeyShortcutsMatrix() {
        let engine = OpenKeyEngine()
        let adapter = TextProxyAdapter(engine: engine)

        // 1. Phím Z gỡ dấu
        engine.isZKeyRemoveToneEnabled = false
        let pZOff = MockTextDocumentProxy()
        pZOff.typeSequence("toansz", adapter: adapter)
        #expect(pZOff.buffer == "toánz", "Z gỡ dấu TẮT -> không gỡ dấu")

        engine.isZKeyRemoveToneEnabled = true
        let pZOn = MockTextDocumentProxy()
        pZOn.typeSequence("toansz", adapter: adapter)
        #expect(pZOn.buffer == "toan", "Z gỡ dấu BẬT -> gỡ thành toan")

        // 2. Phím ngoặc vuông [ ]
        engine.isBracketShortcutsEnabled = false
        let pBrOff = MockTextDocumentProxy()
        pBrOff.typeSequence("[", adapter: adapter)
        #expect(pBrOff.buffer == "[", "Ngoặc vuông TẮT -> giữ nguyên [")

        engine.isBracketShortcutsEnabled = true
        let pBrOn1 = MockTextDocumentProxy()
        pBrOn1.typeSequence("[", adapter: adapter)
        #expect(pBrOn1.buffer == "ơ", "Ngoặc vuông BẬT -> [ thành ơ")

        let pBrOn2 = MockTextDocumentProxy()
        pBrOn2.typeSequence("]", adapter: adapter)
        #expect(pBrOn2.buffer == "ư", "Ngoặc vuông BẬT -> ] thành ư")

        let pBrOn3 = MockTextDocumentProxy()
        pBrOn3.typeSequence("[[", adapter: adapter)
        #expect(pBrOn3.buffer == "[", "Gõ đúp [[ khôi phục [")

        // 3. Phím W đầu từ
        engine.isWAtWordBeginningEnabled = false
        let pWOff = MockTextDocumentProxy()
        pWOff.typeSequence("w", adapter: adapter)
        #expect(pWOff.buffer == "w", "W đầu từ TẮT -> giữ nguyên w")

        engine.isWAtWordBeginningEnabled = true
        let pWOn = MockTextDocumentProxy()
        pWOn.typeSequence("w", adapter: adapter)
        #expect(pWOn.buffer == "ư", "W đầu từ BẬT -> w thành ư")
    }

    // MARK: - 7. Ma trận Phím tắt Cá nhân & Auto Caps Macro

    @Test("Ma trận Phím tắt Cá nhân hóa (Personal Text Replacement) và AutoCaps")
    func testShortcutExpansionMatrix() {
        let adapter = TextProxyAdapter()

        // Thêm phím tắt test
        ShortcutManager.shared.addShortcut(shortcut: "dc", replacement: "được")

        // Khi bật mở rộng gõ tắt
        let proxy1 = MockTextDocumentProxy()
        proxy1.typeSequence("dc ", adapter: adapter)
        #expect(proxy1.buffer == "được ", "dc + space -> được")

        // AutoCaps: Viết hoa chữ đầu
        let proxy2 = MockTextDocumentProxy()
        proxy2.typeSequence("Dc ", adapter: adapter)
        #expect(proxy2.buffer == "Được ", "Dc + space -> Được")

        // AutoCaps: Viết hoa toàn bộ
        let proxy3 = MockTextDocumentProxy()
        proxy3.typeSequence("DC ", adapter: adapter)
        #expect(proxy3.buffer == "ĐƯỢC ", "DC + space -> ĐƯỢC")

        // Dọn dẹp
        ShortcutManager.shared.deleteShortcut(shortcut: "dc")
    }

    // MARK: - 8. Ma trận Tổ hợp Đa Cấu hình Đồng thời (Permutations of Multi-Configs)

    @Test("Tổ hợp Đa Cấu hình phức tạp 1: VNI + Chuẩn Cũ + Gõ tắt phụ âm cuối")
    func testMultiConfigCombo1() {
        let engine = OpenKeyEngine()
        engine.vInputType = .vni
        engine.vUseModernOrthography = 1 // Chuẩn cũ
        engine.isQuickEndConsonantEnabled = true

        let adapter = TextProxyAdapter(engine: engine)
        let proxy = MockTextDocumentProxy()

        // hoa2 -> hoà (chuẩn cũ)
        proxy.typeSequence("hoa2 ", adapter: adapter)
        #expect(proxy.buffer == "hoà ")

        // thuy2 -> thuỳ (chuẩn cũ)
        proxy.typeSequence("thuy2 ", adapter: adapter)
        #expect(proxy.buffer == "hoà thuỳ ")

        // tag -> tang (gõ tắt cuối)
        proxy.typeSequence("tag", adapter: adapter)
        #expect(proxy.buffer == "hoà thuỳ tang")
    }

    @Test("Tổ hợp Đa Cấu hình phức tạp 2: Simple Telex + Chuẩn Mới + Gõ tắt phụ âm đầu + Phím Z gỡ dấu")
    func testMultiConfigCombo2() {
        let engine = OpenKeyEngine()
        engine.vInputType = .simpleTelex1
        engine.vUseModernOrthography = 0 // Chuẩn mới
        engine.isQuickStartConsonantEnabled = true
        engine.isZKeyRemoveToneEnabled = true

        let adapter = TextProxyAdapter(engine: engine)

        // 1. Simple Telex tiengs -> tiếng
        let p1 = MockTextDocumentProxy()
        p1.typeSequence("tiengs", adapter: adapter)
        #expect(p1.buffer == "tiếng")

        // 2. Chuẩn mới hoaf -> hòa
        let p2 = MockTextDocumentProxy()
        p2.typeSequence("hoaf", adapter: adapter)
        #expect(p2.buffer == "hòa")

        // 3. Phụ âm đầu rút gọn fair -> phải
        let p3 = MockTextDocumentProxy()
        p3.typeSequence("fair", adapter: adapter)
        #expect(p3.buffer == "phải")

        // 4. Phím z gỡ dấu: phaisz -> phai
        let p4 = MockTextDocumentProxy()
        p4.typeSequence("phaisz", adapter: adapter)
        #expect(p4.buffer == "phai")
    }

    @Test("Tổ hợp Đa Cấu hình phức tạp 3: Telex Chuẩn + Mọi tính năng nâng cao BẬT")
    func testMultiConfigCombo3AllEnhancedFeaturesOn() {
        let engine = OpenKeyEngine()
        engine.vInputType = .telex
        engine.vUseModernOrthography = 0 // Chuẩn mới
        engine.isQuickTelexEnabled = true
        engine.isQuickStartConsonantEnabled = true
        engine.isQuickEndConsonantEnabled = true
        engine.isBracketShortcutsEnabled = true
        engine.isZKeyRemoveToneEnabled = true
        engine.isWAtWordBeginningEnabled = true
        engine.isAutoUndoEnabled = true

        let adapter = TextProxyAdapter(engine: engine)

        let cases: [(input: String, expected: String)] = [
            ("cc", "ch"),
            ("tt", "th"),
            ("fair", "phải"),
            ("jair", "giải"),
            ("tag", "tang"),
            ("fag", "phang"),
            ("hoaf", "hòa"),
            ("thuyr", "thủy"),
            ("toansz", "toan"),
            ("[", "ơ"),
            ("]", "ư"),
            ("w", "ư"),
            ("ws", "ứ")
        ]

        for item in cases {
            let proxy = MockTextDocumentProxy()
            proxy.typeSequence(item.input, adapter: adapter)
            #expect(proxy.buffer == item.expected, "All Features ON: '\(item.input)' -> '\(item.expected)', thực tế: '\(proxy.buffer)'")
        }
    }

    @Test("Kiểm tra cấu hình cử chỉ vuốt và khớp từ Glide Typing")
    func testGlideAndSwipeGestureSettings() {
        let settings = vBoardSettings.shared
        #expect(settings.isSwipeDeleteEnabled == true, "Mặc định Swipe to delete phải bật")
        #expect(settings.isSpaceCursorGlideEnabled == true, "Mặc định Space cursor glide phải bật")

        // Kiểm tra bật tắt Glide Typing
        let oldGlide = settings.isGlideTypingEnabled
        settings.isGlideTypingEnabled = true
        #expect(settings.isGlideTypingEnabled == true)
        settings.isGlideTypingEnabled = oldGlide

        // Kiểm tra matchGlide
        let vietMatches = WordTrie.shared.matchGlide(keySequence: ["v", "i", "e", "t"], limit: 3)
        #expect(!vietMatches.isEmpty, "Khớp vuốt 'viet' phải trả về kết quả")
        #expect(vietMatches.contains("viết") || vietMatches.contains("Việt"), "Khớp vuốt 'viet' phải chứa 'viết' hoặc 'Việt'")

        let nguoiMatches = WordTrie.shared.matchGlide(keySequence: ["n", "g", "u", "o", "i"], limit: 3)
        #expect(!nguoiMatches.isEmpty, "Khớp vuốt 'nguoi' phải trả về kết quả")
        #expect(nguoiMatches.contains("người"), "Khớp vuốt 'nguoi' phải chứa 'người'")
    }
}
