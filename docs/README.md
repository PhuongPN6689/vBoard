# THƯ MỤC TÀI LIỆU DỰ ÁN vBoard

Thư mục này tập hợp đầy đủ toàn bộ tài liệu đặc tả yêu cầu, thiết kế kiến trúc, giao diện và hướng dẫn phát triển của dự án bàn phím tiếng Việt siêu tốc **vBoard**.

---

## 📑 Danh mục tài liệu:

1. **[REQUIREMENTS.md](REQUIREMENTS.md) - Tài liệu Đặc tả Yêu cầu Phần mềm (SRS):**
   - Định hướng mục tiêu cốt lõi: siêu tốc, không gạch chân, không nuốt từ, RAM < 15MB.
   - Các ràng buộc công nghệ (Pure UIKit, Swift 6 thuần, CoreGraphics/CALayer, không Flutter/React Native).
   - Chi tiết danh sách toàn bộ tính năng gõ tiếng Việt OpenKey, cử chỉ vuốt, thanh gợi ý, bảng tạm và từ điển.

2. **[DESIGN.md](DESIGN.md) - Tài liệu Thiết kế Kiến trúc, Tổ chức Mã nguồn & UI/UX (v2.0):**
   - Sơ đồ kiến trúc phân tầng toàn diện (System & Module Architecture Diagrams).
   - Cây thư mục và bảng phân tích chi tiết vai trò, lớp/struct, giao thức của từng file mã nguồn.
   - Máy trạng thái ngữ âm OpenKey FSM thuần Swift (`OpenKeyEngine`, `OpenKeyEngineAdapter`), quy tắc đặt dấu mới/cũ, Quick Telex và gõ tắt phụ âm.
   - Công thức hình học tính toán kích thước phím chính xác từng pixel (`layoutSubviews`) và thuật toán chống trượt phím mép viền (Extended Edge Hit-Testing).
   - Cấu trúc cây tiền tố Trie > 15.000 từ, gợi ý từ mềm (diacritic-agnostic), thuật toán so khớp gõ lướt Glide qua Bucket và Macro gõ tắt cá nhân (`ShortcutManager`).
   - Hệ thống màn hình lớp phủ (Overlays), cơ chế đồng bộ liên tiến trình Darwin IPC (< 0.1ms) và bộ 6 Suite kiểm thử toàn diện (`ConfigurationMatrixTests`, `ComprehensiveDictionaryPermutationTests` 1700+ cases).

3. **[DETAILED_FEATURE_SPECIFICATION.md](DETAILED_FEATURE_SPECIFICATION.md) - Đặc tả Kỹ thuật Chi tiết các Tính năng Chọn lọc:**
   - Phân tích tính khả thi kỹ thuật trên iOS (Cơ chế Undo/Redo nguyên tử với FSM OpenKey, rào cản Sandbox chọn văn bản).
   - Đặc tả kiến trúc phím Tab và các tiện ích Dev Mode.
   - Thiết kế hệ thống bảng tạm an toàn và phân tích độ trễ.

4. **[SETTINGS_DESIGN.md](SETTINGS_DESIGN.md) - Tài liệu Thiết Kế Màn Hình Cài Đặt (Host App UI/UX):**
   - Sơ đồ điều hướng đa tầng (Navigation Hierarchy) và cơ chế đồng bộ thời gian thực Darwin IPC (< 0.1ms).
   - Chi tiết Wireframe 8 màn hình con: Bố cục, OpenKey, Bàn phím Developer, Cử chỉ, Giao diện, Bảng tạm, Giám sát RAM.
   - Khu vực gõ thử nghiệm trực tiếp (Interactive Keyboard Playground).
   - Data Model tập trung `vBoardSettings` chia sẻ qua App Group.

5. **[GBOARD_ANALYSIS_AND_DESIGN.md](GBOARD_ANALYSIS_AND_DESIGN.md) - Phân Tích Hình Ảnh Gboard & Đề Xuất Thiết Kế Siêu Tốc:**
   - Duyệt chi tiết 15 ảnh chụp thực tế tính năng Gboard trong thư mục `images/`.
   - Đánh giá toàn diện các ưu điểm xuất sắc cần giữ lại và các tính năng tốn RAM (> 30MB) cần cắt bỏ.
   - Đề xuất giải pháp kiến trúc loại bỏ độ trễ và giật lag trên iOS.
   - Khai thác tối đa thuật toán Finite State Machine (FSM) và quy tắc âm tiết của GitHub OpenKey.

6. **[DICTIONARY_AND_NGRAM_PIPELINE.md](DICTIONARY_AND_NGRAM_PIPELINE.md) - Kiến Trúc Bộ Từ Điển & Pipeline N-gram:**
   - Triết lý gộp ký tự không dấu vào Unigram và bỏ khái niệm "từ ghép" tách rời để thống nhất vào Bigram/Trigram.
   - Luồng dữ liệu và sơ đồ xử lý ngữ liệu văn bản thực tế (Corpus-driven).
   - Hướng dẫn vận hành các script Python (`build_ngram_lexicon.py`, `download_corpus.py`) và chỉ số hiệu năng đạt được.

7. **[assets/](assets/) & [images/](images/) - Kho hình ảnh & Mockups thiết kế:**
   - 15 ảnh chụp màn hình phân tích chi tiết mọi khía cạnh của Gboard.
   - Các ảnh chụp giao diện thực tế đối chiếu chuẩn Gboard và bản vẽ Vector App Icon.

8. **[GLIDE_COMPOSING_AND_INTELLIGENT_SUGGESTION_SPEC.md](GLIDE_COMPOSING_AND_INTELLIGENT_SUGGESTION_SPEC.md) - Đặc Tả Kỹ Thuật Vuốt (Glide), Trạng Thái Soạn Thảo (Composing) & Gợi Ý Từ Thông Minh:**
   - Máy trạng thái Soạn thảo (Composing FSM) chuẩn Gboard: Phân tách `Composing` vs `Committed`, giải quyết tận gốc lỗi nuốt chữ/sửa dấu hậu kỳ OpenKey.
   - Cơ chế bảo vệ và hoàn tất từ gõ dở khi chuyển sang vuốt (`Typed-to-Glide Transition`).

9. **[VIETNAMESE_ORTHOGRAPHY_SPEC.md](VIETNAMESE_ORTHOGRAPHY_SPEC.md) - Quy Chuẩn Ngữ Âm & Ma Trận Gõ Tiếng Việt:**
   - Bảng mã nguyên âm/phụ âm, so sánh chuẩn đặt dấu Mới (`hòa, thủy`) vs Cũ (`hoà, thuỳ`).
   - Ma trận 3 kiểu gõ (Telex, VNI, Simple Telex), các quy tắc gõ tắt OpenKey và 12 nhóm âm tiết kiểm thử chuẩn mực.

10. **[DEBUGGING_AND_PROFILING.md](DEBUGGING_AND_PROFILING.md) - Hướng Dẫn Debug, Đo Lường RAM & Profile Hiệu Năng:**
   - Hướng dẫn attach Xcode Debugger vào Keyboard Extension sandbox trên thiết bị thật.
   - Kỹ thuật đo RAM và rò rỉ bộ nhớ (Allocations/Leaks Instruments) để giữ RAM < 15MB.
   - Xem unified logs hạt nhân (`os_log`) và khắc phục sự cố Jetsam crash.
   - Thẩm định âm tiết 2 tầng: OpenKey FSM Syllable Validation + WordTrie Dictionary.
   - Mô hình suy diễn N-gram Stupid Backoff ($\beta = 0.4$, $\alpha_{\text{personal}} = 2.5$) và luật học thích nghi ($\ge 2$ lần/24h).
   - Bộ công cụ trực quan hóa 4 tab Bảng điểm Từ điển (Dictionary Scores Explorer) trong Host App.

