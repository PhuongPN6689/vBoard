# THƯ MỤC TÀI LIỆU DỰ ÁN vBoard

Thư mục này tập hợp đầy đủ toàn bộ tài liệu đặc tả yêu cầu, thiết kế kiến trúc, giao diện và hướng dẫn phát triển của dự án bàn phím tiếng Việt siêu tốc **vBoard**.

---

## 📑 Danh mục tài liệu:

1. **[REQUIREMENTS.md](REQUIREMENTS.md) - Tài liệu Đặc tả Yêu cầu Phần mềm (SRS):**
   - Định hướng mục tiêu cốt lõi: siêu tốc, không gạch chân, không nuốt từ, RAM < 15MB.
   - Các ràng buộc công nghệ (Pure UIKit, Swift 6 thuần, CoreGraphics/CALayer, không Flutter/React Native).
   - Chi tiết danh sách toàn bộ tính năng gõ tiếng Việt OpenKey, cử chỉ vuốt, thanh gợi ý, bảng tạm và từ điển.

2. **[DESIGN.md](DESIGN.md) - Tài liệu Thiết kế Kiến trúc & UI/UX:**
   - Sơ đồ kiến trúc phân tầng (Architecture Diagrams).
   - Công thức hình học tính toán kích thước phím chính xác từng pixel (`layoutSubviews`).
   - Bảng mã màu Material You (Light Mode & Dark Mode).
   - Thiết kế nhận diện App Icon từ file Vector SVG.
   - Cấu trúc cây tiền tố Trie và thuật toán gợi ý từ vựng / gõ lướt Glide.

3. **[SETTINGS_DESIGN.md](SETTINGS_DESIGN.md) - Tài liệu Thiết Kế Màn Hình Cài Đặt (Host App UI/UX):**
   - Sơ đồ điều hướng đa tầng (Navigation Hierarchy) và cơ chế đồng bộ thời gian thực Darwin IPC (< 0.1ms).
   - Chi tiết Wireframe 8 màn hình con: Bố cục, OpenKey, Bàn phím Developer, Cử chỉ, Giao diện, Bảng tạm, Giám sát RAM.
   - Khu vực gõ thử nghiệm trực tiếp (Interactive Keyboard Playground).
   - Data Model tập trung `vBoardSettings` chia sẻ qua App Group.

4. **[GBOARD_ANALYSIS_AND_DESIGN.md](GBOARD_ANALYSIS_AND_DESIGN.md) - Phân Tích Hình Ảnh Gboard & Đề Xuất Thiết Kế Siêu Tốc:**
   - Duyệt chi tiết 15 ảnh chụp thực tế tính năng Gboard trong thư mục `images/`.
   - Đánh giá toàn diện các ưu điểm xuất sắc cần giữ lại và các tính năng tốn RAM (> 30MB) cần cắt bỏ.
   - Đề xuất giải pháp kiến trúc loại bỏ độ trễ và giật lag trên iOS.
   - Khai thác tối đa thuật toán Finite State Machine (FSM) và quy tắc âm tiết của GitHub OpenKey.

5. **[assets/](assets/) & [images/](images/) - Kho hình ảnh & Mockups thiết kế:**
   - 15 ảnh chụp màn hình phân tích chi tiết mọi khía cạnh của Gboard.
   - Các ảnh chụp giao diện thực tế đối chiếu chuẩn Gboard và bản vẽ Vector App Icon.
