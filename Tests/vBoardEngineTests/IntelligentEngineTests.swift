import Testing
import Foundation
@testable import vBoardEngine

@Suite("Bộ kiểm thử AI Dự đoán & Sửa lỗi Thông minh (Intelligent Engine Tests)")
struct IntelligentEngineTests {

    @Test("Kiểm tra Sửa lỗi gõ đảo phím Telex và viết tắt (nhwung -> nhưng, haowcj -> hoặc, ko -> không)")
    func testTypoCorrectionTelexInversion() {
        let trie = WordTrie.shared

        // 1. Kiểm tra sửa lỗi phím w bị gõ trước nguyên âm
        let suggestNhwung = trie.suggest(prefix: "nhwung", limit: 3)
        #expect(suggestNhwung.contains("nhưng"), "Gõ 'nhwung' phải tự động sửa và gợi ý 'nhưng', kết quả: \(suggestNhwung)")

        let suggestNhuwng = trie.suggest(prefix: "nhuwng", limit: 3)
        #expect(suggestNhuwng.contains("nhưng"), "Gõ 'nhuwng' phải tự động sửa và gợi ý 'nhưng', kết quả: \(suggestNhuwng)")

        // 2. Kiểm tra sửa lỗi đảo nguyên âm + dấu Telex
        let suggestHaowcj = trie.suggest(prefix: "haowcj", limit: 3)
        #expect(suggestHaowcj.contains("hoặc"), "Gõ 'haowcj' phải tự động sửa và gợi ý 'hoặc', kết quả: \(suggestHaowcj)")

        let suggestDduowcj = trie.suggest(prefix: "dduowcj", limit: 3)
        #expect(suggestDduowcj.contains("được"), "Gõ 'dduowcj' phải tự động sửa và gợi ý 'được', kết quả: \(suggestDduowcj)")

        // 3. Kiểm tra viết tắt và slang phổ biến
        let suggestKo = trie.suggest(prefix: "ko", limit: 3)
        #expect(suggestKo.contains("không"), "Gõ 'ko' phải gợi ý 'không', kết quả: \(suggestKo)")

        let suggestBik = trie.suggest(prefix: "bik", limit: 3)
        #expect(suggestBik.contains("biết"), "Gõ 'bik' phải gợi ý 'biết', kết quả: \(suggestBik)")
    }

    @Test("Kiểm tra Dự đoán Từ tiếp theo Trigram và Bigram phân cấp")
    func testNextWordPredictorTrigramAndDynamic() {
        let predictor = NextWordPredictor.shared

        // 1. Kiểm tra Trigram: (chúc bạn) -> ngủ ngon, vui vẻ, thành công
        let triResults = predictor.predictNextWords(previousWord: "bạn", previousPreviousWord: "chúc", limit: 3)
        #expect(triResults.contains("ngủ ngon") || triResults.contains("vui vẻ") || triResults.contains("thành công"),
                "Ngữ cảnh 'chúc bạn' phải dự đoán đúng Trigram, kết quả: \(triResults)")

        // 2. Kiểm tra Trigram: (công nghệ) -> thông tin
        let techResults = predictor.predictNextWords(previousWord: "nghệ", previousPreviousWord: "công", limit: 3)
        #expect(techResults.contains("thông tin"), "Ngữ cảnh 'công nghệ' phải dự đoán 'thông tin', kết quả: \(techResults)")

        // 3. Kiểm tra Trigram: (hẹn gặp) -> lại
        let meetResults = predictor.predictNextWords(previousWord: "gặp", previousPreviousWord: "hẹn", limit: 3)
        #expect(meetResults.contains("lại"), "Ngữ cảnh 'hẹn gặp' phải dự đoán 'lại', kết quả: \(meetResults)")

        // 4. Kiểm tra Backoff về Bigram khi không có từ thứ 2 trước đó
        let biResults = predictor.predictNextWords(previousWord: "xin", limit: 3)
        #expect(biResults.contains("chào") || biResults.contains("lỗi"), "Bigram 'xin' phải dự đoán 'chào'/'lỗi', kết quả: \(biResults)")

        // 5. Kiểm tra N-gram động được nạp trực tiếp từ vietnamese_words.txt (ví dụ: "chúng" -> "ta", "bác" -> "sĩ")
        let bacResults = predictor.predictNextWords(previousWord: "bác", limit: 3)
        #expect(bacResults.contains("sĩ"), "Từ điển tách đôi phải nạp Bigram 'bác' -> 'sĩ' từ vietnamese_words.txt, kết quả: \(bacResults)")

        let chungResults = predictor.predictNextWords(previousWord: "chúng", limit: 3)
        #expect(chungResults.contains("ta"), "Từ điển tách đôi phải nạp Bigram 'chúng' -> 'ta' từ vietnamese_words.txt, kết quả: \(chungResults)")
    }

    @Test("Kiểm tra Cơ chế Học Thích Ứng (Promotion Threshold = 2 và Dynamic Lexicon)")
    func testUserAdaptiveLearningPromotion() {
        let store = UserAdaptiveLearningStore.shared
        let trie = WordTrie.shared
        let testWord = "DeepSeeker"

        // Lần 1: Chưa đạt ngưỡng kết nạp
        store.recordWordInput(testWord)
        #expect(store.getAllUserWords()[testWord.lowercased()] == nil, "Gõ 1 lần từ lạ chưa được lưu vào từ điển người dùng")

        // Lần 2: Đạt ngưỡng kết nạp (>= 2 lần/ngày)
        store.recordWordInput(testWord)
        #expect(store.getAllUserWords()[testWord.lowercased()] != nil, "Gõ 2 lần phải được kết nạp chính thức vào User Lexicon")

        // Kiểm tra từ đã xuất hiện trên gợi ý Trie
        let suggestions = trie.suggest(prefix: "deepseek", limit: 3)
        #expect(suggestions.contains(testWord), "Từ sau khi kết nạp phải xuất hiện trong gợi ý Trie")
    }

    @Test("Kiểm tra Thêm từ trực tiếp và Chặn/Xoá từ khỏi Từ điển (Direct Add & Blacklist)")
    func testDirectAddAndBlacklistWord() {
        let store = UserAdaptiveLearningStore.shared
        let trie = WordTrie.shared
        let newCustomWord = "AntigravityLab"

        // 1. Thêm từ trực tiếp vào từ điển cá nhân
        store.addUserWordDirectly(newCustomWord, frequency: 20)
        #expect(store.getAllUserWords()[newCustomWord.lowercased()] != nil, "Từ phải được thêm trực tiếp vào User Lexicon")
        #expect(trie.containsExactWord(newCustomWord), "Trie phải xác nhận có từ mới thêm")

        let suggestBeforeBlacklist = trie.suggest(prefix: "Antigrav", limit: 3)
        #expect(suggestBeforeBlacklist.contains(newCustomWord), "Trie suggest phải chứa từ vừa thêm")

        // 2. Chặn / Xoá từ khỏi gợi ý từ điển
        store.blacklistWord(newCustomWord)
        #expect(store.isBlacklisted(newCustomWord), "Từ phải nằm trong danh sách đen")
        #expect(store.getAllUserWords()[newCustomWord.lowercased()] == nil, "Từ phải bị loại khỏi User Lexicon")
        #expect(!trie.containsExactWord(newCustomWord), "containsExactWord phải trả về false với từ bị chặn")

        let suggestAfterBlacklist = trie.suggest(prefix: "Antigrav", limit: 3)
        #expect(!suggestAfterBlacklist.contains(newCustomWord), "Trie suggest không được chứa từ đã bị chặn")

        // 3. Khôi phục từ khi thêm lại trực tiếp
        store.addUserWordDirectly(newCustomWord, frequency: 15)
        #expect(!store.isBlacklisted(newCustomWord), "Thêm lại từ phải tự động un-blacklist")
        #expect(trie.containsExactWord(newCustomWord), "Trie phải nhận diện lại từ sau khi thêm lại")

        // Dọn dẹp
        store.deleteUserWord(newCustomWord)
    }

    @Test("Kiểm tra Động học Vuốt phím (Glide Kinematics): Phím thẳng hàng k -> h -> a (khá)")
    func testGlideKinematicsCollinearKeys() {
        let tracker = GlideKinematicsTracker.shared
        tracker.reset()

        // Giả lập cử chỉ vuốt từ 'k' qua 'h' rồi quét nhanh qua 'g', 'f', 'd', 's' tới 'a'
        // 1. Phím bắt đầu 'k' (dwell time ban đầu)
        tracker.addSample(point: CGPoint(x: 260, y: 100), timestamp: 0.00, keyChar: "k")
        tracker.addSample(point: CGPoint(x: 258, y: 100), timestamp: 0.03, keyChar: "k")

        // 2. Chuyển động tới 'h' và có độ dừng / giảm tốc (velocity dip / dwell time)
        tracker.addSample(point: CGPoint(x: 200, y: 100), timestamp: 0.08, keyChar: "h")
        tracker.addSample(point: CGPoint(x: 198, y: 100), timestamp: 0.11, keyChar: "h")
        tracker.addSample(point: CGPoint(x: 197, y: 100), timestamp: 0.14, keyChar: "h")

        // 3. Quét nhanh lướt qua các phím giữa g, f, d, s (vận tốc cực cao, dwell time mỗi phím chỉ vài ms)
        tracker.addSample(point: CGPoint(x: 170, y: 100), timestamp: 0.145, keyChar: "g")
        tracker.addSample(point: CGPoint(x: 140, y: 100), timestamp: 0.150, keyChar: "f")
        tracker.addSample(point: CGPoint(x: 110, y: 100), timestamp: 0.155, keyChar: "d")
        tracker.addSample(point: CGPoint(x: 80, y: 100), timestamp: 0.160, keyChar: "s")

        // 4. Đến phím kết thúc 'a' và dừng lại trước khi nhấc tay (dwell time kết thúc)
        tracker.addSample(point: CGPoint(x: 30, y: 100), timestamp: 0.20, keyChar: "a")
        tracker.addSample(point: CGPoint(x: 30, y: 100), timestamp: 0.25, keyChar: "a")

        let (primary, full) = tracker.extractTargetKeySequence()
        print("🎯 Glide Kinematics Primary: \(primary), Full: \(full)")

        // Chuỗi chính (primary) phải nhận diện 'k', 'h', 'a' và loại bỏ các phím lướt qua 'g', 'f', 'd', 's'
        #expect(primary.contains("k") && primary.contains("h") && primary.contains("a"),
                "Primary key sequence phải chứa k, h, a; thực tế: \(primary)")
        #expect(!primary.contains("f") && !primary.contains("d"),
                "Primary key sequence phải lọc bỏ các phím lướt qua f, d; thực tế: \(primary)")

        // So khớp với WordTrie
        let matches = WordTrie.shared.matchGlide(keySequence: primary, limit: 3)
        #expect(matches.contains("khá") || matches.contains("khe") || matches.contains("khoá"),
                "Từ điển phải khớp từ có nghĩa từ chuỗi k-h-a, kết quả: \(matches)")
    }

    @Test("Kiểm tra Sửa dấu/sửa âm hậu kỳ sau khi vuốt hoặc gợi ý (mõi + j -> mọi, mốt + j -> một, bóc tách âm tiết)")
    func testPostCommitDiacriticTuning() {
        let adapter = OpenKeyEngineAdapter()
        let initialWord = "mõi"

        // Mô phỏng người dùng vừa vuốt ra từ 'mõi', sau đó bấm phím 'j'
        adapter.reset()
        adapter.syncContextWord(initialWord)

        let action = adapter.processKeystroke("j")
        #expect(action.deleteCount > 0, "Phải xóa hậu tố cũ để thay bằng hậu tố đã đổi dấu")
        let prefixKept = String(initialWord.dropLast(action.deleteCount))
        let fullNewWord = prefixKept + action.textToInsert
        #expect(fullNewWord == "mọi", "Gõ 'j' sau 'mõi' phải đổi thành 'mọi', thực tế: \(fullNewWord)")

        // Kiểm tra đổi dấu trên 'mốt' + 'j' -> 'một'
        adapter.reset()
        adapter.syncContextWord("mốt")
        let actionMot = adapter.processKeystroke("j")
        #expect(actionMot.deleteCount > 0)
        let newMot = String("mốt".dropLast(actionMot.deleteCount)) + actionMot.textToInsert
        #expect(newMot == "một", "Gõ 'j' sau 'mốt' phải đổi thành 'một', thực tế: \(newMot)")
    }

    @Test("Kiểm tra Gợi ý sửa lỗi khi ĐANG GÕ DỞ DANG (Prefix-Aware Typo Correction)")
    func testTypoCorrectionPartialPrefixWhileTyping() {
        let trie = WordTrie.shared

        // 1. Gõ dở 'nhwu' (tiền tố của 'nhưng', 'như')
        let suggestNhwu = trie.suggest(prefix: "nhwu", limit: 3)
        #expect(suggestNhwu.contains("nhưng") || suggestNhwu.contains("như"),
                "Gõ dở 'nhwu' phải gợi ý 'nhưng' hoặc 'như', kết quả: \(suggestNhwu)")

        // 2. Gõ dở 'nhwun' (tiền tố sát nút của 'nhưng')
        let suggestNhwun = trie.suggest(prefix: "nhwun", limit: 3)
        #expect(suggestNhwun.contains("nhưng"),
                "Gõ dở 'nhwun' phải gợi ý 'nhưng', kết quả: \(suggestNhwun)")

        // 3. Gõ dở 'haowc' (tiền tố của 'hoặc')
        let suggestHaowc = trie.suggest(prefix: "haowc", limit: 3)
        #expect(suggestHaowc.contains("hoặc"),
                "Gõ dở 'haowc' phải gợi ý 'hoặc', kết quả: \(suggestHaowc)")

        // 4. Gõ dở 'dduowc' (tiền tố của 'được')
        let suggestDduowc = trie.suggest(prefix: "dduowc", limit: 3)
        #expect(suggestDduowc.contains("được"),
                "Gõ dở 'dduowc' phải gợi ý 'được', kết quả: \(suggestDduowc)")
    }

    @Test("Kiểm tra Thuật toán Glide: 'khi' luôn xếp trên 'khui' khi lướt qua phím trung gian 'u'")
    func testGlideAccuracyKhiOverKhui() {
        let trie = WordTrie.shared

        // Khi người dùng vuốt từ k -> h -> i nhưng lướt ngang qua phím u
        let matches = trie.matchGlide(keySequence: ["k", "h", "u", "i"], limit: 3)
        print("🎯 Glide 'k-h-u-i' candidates: \(matches)")

        #expect(matches.contains("khi"), "Kết quả phải chứa từ cao tần 'khi', thực tế: \(matches)")
        if let khiIdx = matches.firstIndex(of: "khi"), let khuiIdx = matches.firstIndex(of: "khui") {
            #expect(khiIdx < khuiIdx, "'khi' (tần suất ~74) phải xếp TRÊN 'khui' (tần suất ~1)")
        } else {
            #expect(matches.first == "khi", "'khi' phải là ứng viên số 1 cho chuỗi vuốt 'k-h-u-i'")
        }
    }

    @Test("Kiểm tra Thuật toán Glide: Vuốt 'vợ' (v -> h -> o) phải luôn gợi ý 'vợ' và TUYỆT ĐỐI không bị 'họ' đè bẹp")
    func testGlideAccuracyVoOverHo() {
        let trie = WordTrie.shared

        // Khi người dùng vuốt từ 'v' qua 'h' tới 'o'
        let matches = trie.matchGlide(keySequence: ["v", "h", "o"], limit: 3)
        print("🎯 Glide 'v-h-o' candidates: \(matches)")

        #expect(matches.contains("vợ"), "Kết quả phải chứa từ 'vợ', thực tế: \(matches)")
        #expect(!matches.contains("họ"), "Tuyệt đối không được chứa từ 'họ' vì người dùng bắt đầu vuốt ở phím 'v', thực tế: \(matches)")
        #expect(matches.first == "vợ", "'vợ' phải là ứng viên số 1 khi vuốt từ v tới o")
    }

    @Test("Kiểm tra Thuật toán Glide: Vuốt 'ơi' (o -> i)")
    func testGlideAccuracyOi() {
        let trie = WordTrie.shared
        let matches = trie.matchGlide(keySequence: ["o", "i"], limit: 3)
        print("🎯 Glide 'o-i' candidates: \(matches)")
        #expect(matches.contains("ơi"), "Vuốt o -> i phải gợi ý 'ơi', thực tế: \(matches)")
    }

    @Test("Kiểm tra Tự động Benchmark Vuốt phím với Đa Vận tốc (Automated Multi-Velocity Benchmark)")
    func testGlideAutomatedBenchmarkAcrossVelocities() {
        let simulator = GlideTrajectorySimulator.shared
        let challengeWords = ["khá", "vợ", "khi", "ơi", "con", "cho", "về", "mẹ", "lá", "dạ", "không", "được", "người", "nhưng", "tôi", "yêu", "vui", "nói", "học", "trước"]
        let profiles: [GlideSpeedProfile] = [.slow, .normal, .fast]

        print("\n=======================================================")
        print("🚀 BẮT ĐẦU CHẠY AUTO BENCHMARK VUỐT VỚI ĐẦU VÀO VẬN TỐC:")

        for profile in profiles {
            var passCount = 0
            for word in challengeWords {
                let (isMatch, topCandidates, recWord, _) = simulator.simulateAndEvaluate(
                    targetWord: word,
                    profile: profile,
                    matchUnaccented: true
                )
                if isMatch {
                    passCount += 1
                } else {
                    print("  ⚠️ Lệch ở profile [\(profile.rawValue)]: Mục tiêu '\(word)' -> Ra '\(recWord)', Candidates: \(topCandidates)")
                }
            }
            let accuracy = (Double(passCount) / Double(challengeWords.count)) * 100.0
            print("  📊 Profile: \(profile.rawValue) -> Độ chính xác: \(passCount)/\(challengeWords.count) (\(String(format: "%.1f%%", accuracy)))")
            #expect(accuracy >= 80.0, "Độ chính xác ở profile \(profile.rawValue) phải đạt ít nhất 80%, thực tế: \(accuracy)%")
        }
        print("=======================================================\n")
    }

    @Test("Kiểm tra Kịch bản chính xác người dùng mô tả: Điểm V bắt đầu, điểm H nhanh, điểm I nhanh, điểm O chậm")
    func testGlideExactUserScenarioPerKeyVelocity() {
        let simulator = GlideTrajectorySimulator.shared

        // Kịch bản của bạn:
        // Ngón tay chạm ở phím 'v' (bắt đầu) -> bay lướt cực nhanh qua 'h' và 'i' -> dừng/chậm lại ở phím 'o' (kết thúc)
        // Mục tiêu từ là 'vợ' (dạng ASCII: 'vo'). Thuật toán PHẢI loại bỏ 'h' và 'i' vì chúng chỉ là phím lướt nhanh!
        let waypoints: [(char: Character, state: KeyKinematicState)] = [
            ("v", .startPoint),
            ("h", .fastTransit(speedPxPerSec: 1600.0)),
            ("i", .fastTransit(speedPxPerSec: 1600.0)),
            ("o", .endPoint)
        ]

        let (isMatch, topCandidates, recWord, extractedPrimary, stats) = simulator.simulateCustomKinematics(
            targetWord: "vợ",
            waypoints: waypoints,
            matchUnaccented: true
        )

        print("\n-------------------------------------------------------")
        print("🎯 KỊCH BẢN NGƯỜI DÙNG: v (bắt đầu) -> h (nhanh) -> i (nhanh) -> o (chậm)")
        print("  Chuỗi phím mục tiêu sau khi lọc động học (Primary): \(extractedPrimary)")
        print("  Từ điển gợi ý: \(topCandidates)")
        print("  Từ số 1 nhận diện: '\(recWord)'")
        if let st = stats {
            print("  Thời gian: \(String(format: "%.0fms", st.durationMs)) | Vận tốc TB: \(String(format: "%.0f px/s", st.avgVelocityPxPerSec))")
        }
        print("-------------------------------------------------------\n")

        // 1. Phải bóc tách được phím v và o, LOẠI BỎ h và i
        #expect(extractedPrimary.first == "v", "Phím đầu tiên phải là 'v'")
        #expect(extractedPrimary.last == "o", "Phím cuối cùng phải là 'o'")
        #expect(!extractedPrimary.contains("h"), "Phím 'h' có vận tốc quá cao (1600px/s) nên phải bị loại bỏ")
        #expect(!extractedPrimary.contains("i"), "Phím 'i' có vận tốc quá cao (1600px/s) nên phải bị loại bỏ")

        // 2. Kết quả nhận diện PHẢI là 'vợ' (hoặc dạng unaccented 'vo') và TUYỆT ĐỐI không phải là 'họ'
        #expect(isMatch, "Phải nhận diện đúng từ 'vợ', thực tế ra: '\(recWord)'")
        #expect(topCandidates.contains("vợ"), "Candidates phải chứa 'vợ', thực tế: \(topCandidates)")
        #expect(!topCandidates.contains("họ"), "Tuyệt đối không được ra 'họ'")
    }

    @Test("Kiểm tra Công thức Xếp hạng Stupid Backoff: Score = Base + alpha * UserFrequency (alpha = 2.5)")
    func testNextWordPredictorScoringWithAlpha() {
        let predictor = NextWordPredictor.shared
        let store = UserAdaptiveLearningStore.shared

        // Người dùng lặp lại cụm từ "chúc bạn" -> "may mắn" 10 lần
        for _ in 0..<10 {
            store.recordWordInput("may mắn", previousWord: "bạn", previousPreviousWord: "chúc")
        }

        let predictions = predictor.predictNextWords(previousWord: "bạn", previousPreviousWord: "chúc", limit: 3)
        #expect(predictions.first == "may mắn", "Từ được người dùng dùng nhiều lần với alpha = 2.5 phải được đẩy lên vị trí số 1, kết quả: \(predictions)")
    }

    @Test("Kiểm tra Dự đoán Từ mở đầu câu sau dấu câu ('.', '!', '?')")
    func testSentenceStartersPrediction() {
        let predictor = NextWordPredictor.shared
        let starters = predictor.predictSentenceStarters(limit: 3)
        #expect(!starters.isEmpty, "Gợi ý mở đầu câu không được rỗng")
        #expect(starters.contains("Tôi") || starters.contains("Em") || starters.contains("Dạ"), "Phải chứa các từ mở đầu câu ưa thích tiếng Việt, kết quả: \(starters)")

        // Người dùng thường xuyên mở đầu câu bằng "Vâng"
        let store = UserAdaptiveLearningStore.shared
        for _ in 0..<5 {
            store.recordSentenceStartWord("Vâng")
        }

        let updatedStarters = predictor.predictSentenceStarters(limit: 3)
        #expect(updatedStarters.contains("Vâng"), "Sau khi học thói quen, 'Vâng' phải xuất hiện trong gợi ý đầu câu, kết quả: \(updatedStarters)")
    }

    @Test("Kiểm tra Sửa lỗi Typo có ký tự đặc biệt (đuowcj -> được, dduowcj -> được)")
    func testTypoCorrectionAccentedInput() {
        let trie = WordTrie.shared

        // Kiểm tra từ có chứa ký tự đ ('đuowcj') mà trước đây bị bug bỏ sót
        let results = trie.suggest(prefix: "đuowcj", limit: 3)
        #expect(results.contains("được"), "Gõ 'đuowcj' phải sửa thành 'được', kết quả: \(results)")

        let resultsDduowc = trie.suggest(prefix: "đuowc", limit: 3)
        #expect(resultsDduowc.contains("được"), "Gõ 'đuowc' phải sửa thành 'được', kết quả: \(resultsDduowc)")
    }

    @Test("Kiểm tra Lớp 3: Spatial QWERTY Fuzzy Match khi bấm nhầm phím cạnh bên")
    func testSpatialQWERTYFuzzyMatch() {
        let typoManager = TypoCorrectionManager.shared
        let trie = WordTrie.shared

        // Người dùng muốn gõ "viet" nhưng ngón tay bấm nhầm phím 'i' sang phím lân cận 'u' -> "vuet"
        let fuzzyMatches = typoManager.spatialFuzzyMatch(query: "vuet", trie: trie, limit: 3)
        #expect(fuzzyMatches.contains("Việt") || fuzzyMatches.contains("viết") || fuzzyMatches.contains("vượt"),
                "Spatial Fuzzy Match phải gợi ý từ từ phím kề cận, kết quả: \(fuzzyMatches)")
    }

    @Test("Kiểm tra Xuất (Export) và Nhập (Import) Sao lưu Từ điển cá nhân JSON")
    func testPersonalDictionaryJSONBackup() {
        let store = UserAdaptiveLearningStore.shared
        store.addUserWordDirectly("vBoardTestWord", frequency: 45)

        // Xuất JSON
        guard let jsonString = store.exportJSON() else {
            Issue.record("Không thể xuất JSON từ điển người dùng")
            return
        }
        #expect(jsonString.localizedCaseInsensitiveContains("vBoardTestWord"), "JSON xuất ra phải chứa từ vừa thêm")

        // Xóa từ
        store.deleteUserWord("vBoardTestWord")
        #expect(store.getAllUserWords()["vboardtestword"] == nil, "Từ phải bị xóa")

        // Nhập lại từ JSON sao lưu
        let importSuccess = store.importJSON(jsonString)
        #expect(importSuccess, "Nhập JSON phải thành công")
        #expect(store.getAllUserWords()["vboardtestword"] != nil, "Từ sau khi khôi phục phải xuất hiện lại trong từ điển")
    }

    @Test("Kiểm tra Hậu kiểm Âm tiết Tiếng Việt sau khi Vuốt (Vietnamese Syllable Continuation)")
    func testVietnameseSyllableContinuationRules() {
        let trie = WordTrie.shared

        // 1. Các trường hợp ghép hợp lệ:
        // 'vợ' + 'i' -> 'vợi'
        #expect(trie.isValidVietnameseSyllable("vợi"), "'vợi' phải là âm tiết tiếng Việt hợp lệ")
        // 'học' + 'o' -> 'hộc'
        #expect(trie.isValidVietnameseSyllable("hộc"), "'hộc' phải là âm tiết tiếng Việt hợp lệ")
        // 'nha' + 's' -> 'nhá'
        #expect(trie.isValidVietnameseSyllable("nhá"), "'nhá' phải là âm tiết tiếng Việt hợp lệ")
        // 'to' + 'i' -> 'toi'
        #expect(trie.isValidVietnameseSyllable("toi"), "'toi' phải là âm tiết hợp lệ")

        // 2. Các trường hợp KHÔNG thể ghép (buộc phải tách từ tự động):
        // 'vợ' + 'g' -> 'vợg' không hợp lệ
        #expect(!trie.isValidVietnameseSyllable("vợg"), "'vợg' không được là âm tiết tiếng Việt hợp lệ")
        // 'học' + 's' -> 'họcs' không hợp lệ
        #expect(!trie.isValidVietnameseSyllable("họcs"), "'họcs' không được là âm tiết tiếng Việt hợp lệ")
        // 'nhà' + 'x' -> 'nhàx' không hợp lệ
        #expect(!trie.isValidVietnameseSyllable("nhàx"), "'nhàx' không được là âm tiết tiếng Việt hợp lệ")
        // 'anh' + 'y' -> 'anhy' không hợp lệ
        #expect(!trie.isValidVietnameseSyllable("anhy"), "'anhy' không được là âm tiết tiếng Việt hợp lệ")
    }

    @Test("Kiểm tra Tra cứu Điểm số Bigram và Trigram phục vụ UI Explorer")
    func testRankedNGramsExplorer() {
        let predictor = NextWordPredictor.shared

        // Tra cứu Bigram gốc "chúc"
        let bigrams = predictor.getRankedBigrams(filter: "chúc", limit: 5)
        #expect(!bigrams.isEmpty, "Phải tìm thấy Bigram cho 'chúc'")
        if let first = bigrams.first {
            #expect(!first.candidates.isEmpty, "Ứng viên đi sau 'chúc' không được rỗng")
            #expect(first.candidates.contains { $0.word == "bạn" || $0.word == "mừng" }, "Phải có 'bạn' hoặc 'mừng'")
        }

        // Tra cứu Trigram ngữ cảnh "chúc bạn"
        let trigrams = predictor.getRankedTrigrams(filter: "chúc bạn", limit: 5)
        #expect(!trigrams.isEmpty, "Phải tìm thấy Trigram cho 'chúc bạn'")
        if let first = trigrams.first {
            #expect(!first.candidates.isEmpty, "Ứng viên đi sau 'chúc bạn' không được rỗng")
            #expect(first.candidates.contains { $0.word.contains("ngon") || $0.word.contains("vui") }, "Phải có 'ngủ ngon' hoặc 'vui vẻ'")
        }
    }

    @Test("Kiểm tra Thuật toán Ngữ âm OpenKey isValidVietnameseSpelling trên các âm tiết hợp lệ và bất hợp lệ")
    func testOpenKeyPhonotacticsValidation() {
        let adapter = OpenKeyEngineAdapter()

        // Các âm tiết tiếng Việt hợp lệ
        let validWords = ["người", "việt", "vợi", "thương", "tó", "mẹ", "xoang", "quở", "nghỉ", "chuyển"]
        for w in validWords {
            let isValid = adapter.isValidVietnameseSpelling(w)
            #expect(isValid, "'\(w)' phải là âm tiết tiếng Việt hợp lệ theo chuẩn OpenKey")
        }

        // Các âm tiết sai quy tắc ngữ âm tiếng Việt
        let invalidWords = ["vợg", "thươngk", "bámk", "ngườid", "tós", "hhoc", "jjk"]
        for w in invalidWords {
            let isValid = adapter.isValidVietnameseSpelling(w)
            #expect(!isValid, "'\(w)' phải bị từ chối vì vi phạm quy tắc chính tả/ngữ âm tiếng Việt")
        }
    }

    @Test("Kiểm tra Tính điểm Toán học predictNextWordsScored: Xếp hạng giảm dần và Hệ số phạt Stupid Backoff")
    func testPredictNextWordsScoredOrdering() {
        let predictor = NextWordPredictor.shared

        // 1. Trigram scoring cho "chúc bạn"
        let scoredTri = predictor.predictNextWordsScored(previousWord: "bạn", previousPreviousWord: "chúc", limit: 5)
        #expect(!scoredTri.isEmpty, "Dự đoán điểm Trigram không được rỗng")
        for i in 0..<(scoredTri.count - 1) {
            #expect(scoredTri[i].score >= scoredTri[i + 1].score,
                    "Danh sách ứng viên phải được sắp xếp điểm số giảm dần: \(scoredTri[i].score) >= \(scoredTri[i+1].score)")
        }

        // 2. Bigram scoring cho "xin"
        let scoredBi = predictor.predictNextWordsScored(previousWord: "xin", limit: 5)
        #expect(!scoredBi.isEmpty, "Dự đoán điểm Bigram không được rỗng")
        for i in 0..<(scoredBi.count - 1) {
            #expect(scoredBi[i].score >= scoredBi[i + 1].score,
                    "Danh sách Bigram phải được sắp xếp điểm số giảm dần")
        }
    }

    @Test("Kiểm tra Cơ chế Chuyển tiếp Gõ dở -> Vuốt (Giữ và hoàn thiện từ đang gõ thay vì xóa mất)")
    func testAutocompleteTypedWordOnGlideTransition() {
        let trie = WordTrie.shared

        // 1. Khi đang gõ dở 'nguo' chưa có dấu cách, gợi ý số 1 phải là 'người'
        let topNguo = trie.suggest(prefix: "nguo", limit: 1).first
        #expect(topNguo?.lowercased() == "người", "Gõ dở 'nguo' phải gợi ý 'người' để chốt khi người dùng vuốt từ tiếp theo")

        // 2. Khi đang gõ dở 'viet', gợi ý số 1 phải là 'Việt' hoặc 'viết'
        let topViet = trie.suggest(prefix: "viet", limit: 1).first
        #expect(topViet?.lowercased() == "việt" || topViet?.lowercased() == "viết", "Gõ dở 'viet' phải gợi ý 'việt'/'viết'")

        // 3. Khi đã gõ hoàn chỉnh 'học', top gợi ý là chính nó (không bị biến dạng)
        let topHoc = trie.suggest(prefix: "học", limit: 1).first
        #expect(topHoc?.lowercased() == "học", "Từ đã hoàn chỉnh phải giữ nguyên chính nó")
    }
}
