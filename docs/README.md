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

6. **[assets/](assets/) & [images/](images/) - Kho hình ảnh & Mockups thiết kế:**
   - 15 ảnh chụp màn hình phân tích chi tiết mọi khía cạnh của Gboard.
   - Các ảnh chụp giao diện thực tế đối chiếu chuẩn Gboard và bản vẽ Vector App Icon.
