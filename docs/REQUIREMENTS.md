# TÀI LIỆU YÊU CẦU DỰ ÁN BÀN PHÍM TIẾNG VIỆT SIÊU TỐC - vBoard
*(Software Requirements Specification - SRS)*

---

## 1. TỔNG QUAN DỰ ÁN & MỤC TIÊU CỐT LÕI

**vBoard** là bàn phím tiếng Việt dành cho hệ điều hành iOS, được nghiên cứu và phát triển với mục tiêu hàng đầu: **TỐC ĐỘ GÕ CỰC NHANH, ĐỘ TRỄ GẦN NHƯ BẰNG 0, TỐI ƯU BỘ NHỚ RAM TRIỆT ĐỂ VÀ TRẢI NGHIỆM GÕ THUẦN CHUẨN GBOARD/APPLE**.

### Mục tiêu kỹ thuật then chốt:
1. **Khắc phục triệt để lỗi của Gboard & bàn phím mặc định:**
   - Không bị gạch chân khó chịu khi đang gõ.
   - Không bị nuốt từ, mất ký tự khi gõ nhanh hoặc khi chuyển trường nhập liệu.
   - Hoạt động mượt mà ở tất cả mọi nơi: Ứng dụng, Safari, Spotlight tìm kiếm và App Library.
2. **Siêu nhẹ & Tiết kiệm bộ nhớ (RAM < 15MB, giới hạn iOS là 30MB):**
   - Không bao giờ bị hệ điều hành buộc đóng (kill process/crash) vì tràn bộ nhớ.
3. **Độ trễ xử lý phím bấm:**
   - Thời gian phản hồi: **< 0.05ms** cho mỗi ký tự được gõ.
   - Thời gian gợi ý từ: **< 0.05ms** cho mỗi lần tra cứu tiền tố.

---

## 2. QUY CHUẨN CÔNG NGHỆ (TECH STACK CONSTRAINTS)

| Tiêu chuẩn | Quy định bắt buộc | Lý do kỹ thuật |
| :--- | :--- | :--- |
| **Framework cấm** | ❌ Tuyệt đối **KHÔNG dùng Flutter / React Native** | Gánh nặng runtime lớn, hao tốn 40-70MB RAM, khởi động chậm, vi phạm giới hạn RAM 30MB của iOS Extension. |
| **Ngôn ngữ lõi** | ✅ **Swift 6 thuần chủng** kết hợp C/C++ | Tối ưu hóa compile native binary, không overhead, kiểm soát an toàn luồng tuyệt đối. |
| **UI Layer** | ✅ **Pure UIKit** (Tính toán toạ độ hình học `CGRect` thủ công trong `layoutSubviews()`) | Tránh AutoLayout với hàng chục constraints gây tốn CPU & giật khung hình (drop frames) khi bàn phím xuất hiện. Không dùng SwiftUI cho Keyboard Extension chính. |
| **Đồ họa phím** | ✅ **CoreGraphics / Vector / CALayer** trực tiếp bằng code | Không dùng file ảnh bitmap (PNG/JPEG) cho từng phím. Vẽ bo góc, đổ bóng, màu sắc hoàn toàn bằng code giúp giảm bộ nhớ GPU/RAM xuống gần bằng 0. |
| **Kiến trúc mã nguồn** | ✅ **Modular Architecture** tách biệt: `vBoardEngine` (Lõi gõ tiếng Việt độc lập) và `vBoardKeyboard` (Giao diện UIKit). | Tái sử dụng, dễ viết Unit Test, biên dịch độc lập siêu tốc. |

---

## 3. CÁC TÍNH NĂNG CHI TIẾT ĐƯỢC YÊU CẦU

### 3.1. Bộ gõ Tiếng Việt Siêu tốc (Vietnamese Engine Core)
- **Thuật toán OpenKey State Machine (100% Pure Swift):**
  - Máy trạng thái hữu hạn xử lý trực tiếp trên chuỗi ký tự đệm (buffer-based).
  - Can thiệp thông minh qua `UITextDocumentProxy` bằng cơ chế `deleteBackward()` và `insertText()` chuẩn xác với tốc độ < 0.015ms.
- **Phương pháp gõ:**
  - Hỗ trợ đầy đủ **Telex**, **Simple Telex** và **VNI**.
  - **Tùy chọn phong cách đặt dấu thanh:**
    - **Chuẩn mới (Khuyên dùng):** `hòa`, `thủy`, `toán`, `tiến` (`vUseModernOrthography = 0`).
    - **Chuẩn cũ:** `hoà`, `thuỳ`, `toán`, `tiến` (`vUseModernOrthography = 1`).
- **Các tính năng OpenKey nâng cao:**
  - **Gõ chuẩn xác từ thực tế:** Xử lý hoàn hảo các chuỗi gõ như `moiws` $\to$ `mới`. Mặc định tắt Quick Telex để gõ chính xác các từ thương hiệu như `viettel` không bị biến dạng thành `viethel`.
  - **Phím `z` gỡ dấu:** Nhấn `z` ở cuối từ để trả từ về dạng không dấu (`toán` + `z` -> `toan`).
  - **Quick Telex (Tùy chọn):** Gõ tắt `cc` -> `ch`, `gg` -> `gi`, `kk` -> `kh`, `nn` -> `ng`, `qq` -> `qu`, `pp` -> `ph`, `tt` -> `th`.
  - **Gõ tắt phụ âm đầu (Tùy chọn):** `f` -> `ph`, `j` -> `gi`, `w` -> `qu` (`fair -> phải`, `jair -> giải`, `wa -> qua`).
  - **Gõ tắt phụ âm cuối (Tùy chọn):** `g` -> `ng`, `h` -> `nh`, `k` -> `ch` (`tog -> tong`, `tih -> tinh`, `tik -> tich`).
  - **Gõ tắt dấu ngoặc `[` và `]`:** Bấm `[` ra `ơ`, `]` ra `ư`, `[[` ra `[`, `]]` ra `]`.
  - **Tự động biến đổi `w` đầu từ:** Nhấn `w` ở đầu từ tự động ra `ư` (`w` -> `ư`).
  - **Cơ chế hoàn tác (Undo):** Nhấn đúp phím dấu để khôi phục ký tự gốc (`aa` -> `â`, nhấn thêm `a` -> `aa`).

### 3.2. Bố cục Bàn phím & Trải nghiệm Chuẩn Gboard
- **Hàng 1 (`q .. p`):** 10 phím kèm ký tự số phụ góc trên phải `1 2 3 4 5 6 7 8 9 0`.
- **Hàng 2 (`a .. l`):** 9 phím thụt vào 0.5 đơn vị phím ở 2 bên, căn giữa chuẩn xác, nhãn phụ `@ # $ _ & - + ( )`.
- **Hàng 3 (`Shift` + `z .. m` + `⌫`):**
  - 7 phím chữ kèm nhãn phụ `* " ' : ; ! ?`.
  - **Phím Shift và phím Xóa (⌫):** Thiết kế kích thước mở rộng, **độ rộng bằng đúng phím `?123` và phím `↵` (Action Key)** ở Hàng 4, căn lề thẳng hàng dọc 100%.
- **Hàng 4 (Hàng đáy hoàn thiện & Tinh gọn):**
  - Bố cục: `[ ?123 ]  [ , (☺ vector) ]  [   Tiếng Việt (Space rộng rãi 4.8 weight)   ]  [ . ]  [ ↵ / 🔍 ]`
  - Đầy đủ phím phẩy `,` và phím chấm `.` hai bên Space.
  - Phím phẩy có nhãn phụ icon vector `☺` (nhấn giữ hiển thị menu bong bóng chọn Emoji hoặc mở thẳng App Cài đặt `vboard://settings`).
  - Loại bỏ các phím quả cầu `🌐` và phím mặt cười `☺` riêng lẻ ở hàng đáy để dành tối đa không gian cho phím Space, gõ thoải mái và hạn chế bấm nhầm.
  - Phím Space có nhãn mờ `Tiếng Việt`.
  - Phím Hành động / Enter: bo hình viên thuốc (pill shape), tự đổi biểu tượng (`🔍` khi tìm kiếm, `↵` khi xuống dòng thông thường, máy bay `✈` khi gửi tin nhắn).
- **Phím Dán (Paste) Đa Năng & Lịch Sử Bảng Tạm:** Đặt cố định ở mạn phải thanh Toolbar. Chạm để dán trực tiếp từ clipboard, nhấn giữ để chuyển sang chế độ mở danh sách lịch sử bảng tạm.
- **Chế độ Một tay Thông minh (One-Handed Mode):** Thu hẹp bàn phím còn 84%, có cột công cụ đảo bên và phóng to, tự động ghi nhớ hướng lệch gần nhất (trái hoặc phải) để khôi phục chính xác khi bật lại.
- **Hàng phím số trên cùng (Number Row - Tuỳ chọn):** Bật/tắt trong cài đặt, hiển thị thanh mảnh ngay dưới thanh gợi ý.
- **Bàn phím số chuyên dụng (Dedicated Number Pad):** Bố cục dạng lưới 4x4 thanh thoát, gọn gàng, tự kích hoạt khi nhập OTP / số điện thoại.
- **Bàn phím Lập trình viên Chuyên dụng (Developer Mode):** Bố cục 4 hàng tối ưu cho lập trình (SSH, Termius, Markdown, SQL), cung cấp phím `Tab`, dấu ngoặc `{ } [ ] ( ) < > / \`, toán tử `->`, `=>`, `==`, `!=` và phím mũi tên `←` `→`. Tự động khóa bộ gõ tiếng Việt về ASCII chuẩn để chống gõ nhầm dấu khi viết code.

### 3.3. Tương tác & Cử chỉ Thông minh
- **Di chuyển con trỏ bằng phím Space:** Nhấn giữ và trượt ngón tay trên thanh Space để di chuyển con trỏ văn bản chính xác từng ký tự.
- **Xóa trượt nhanh (Backspace Swipe-to-Delete):** Vuốt từ phím Backspace sang trái để chọn và xóa nhanh một hoặc nhiều từ liên tục.
- **Nhấn đúp Space thành dấu chấm câu (`. `):** Tự động thêm dấu chấm kèm dấu cách khi bấm đúp phím Space.
- **Phản hồi xúc giác (Haptic Feedback):** Rung nhẹ chuẩn iOS khi nhấn phím (có công tắc bật/tắt).
- **Xem trước phím (Key Preview Popover):** Hiển thị popup bong bóng phóng to ký tự khi ngón tay chạm phím.
- **Nút thu nhỏ/gập bàn phím `▼`:** Đặt ở góc dưới thanh Home Indicator để đóng bàn phím ngay lập tức.

### 3.4. Gợi ý từ thông minh & Gõ lướt (Glide / Swipe Typing)
- **Thanh gợi ý từ (Suggestion Bar):**
  - Hiển thị 3 từ tiếng Việt gợi ý phù hợp nhất theo thời gian thực.
  - **Gợi ý mềm không dấu (Soft Suggestions / Diacritic-Agnostic):** Khi người dùng gõ chuỗi chưa có dấu (ví dụ: `nhu`), thanh gợi ý vẫn chủ động đề xuất các từ có dấu đầy đủ (`nhưng`, `như`, `những`, `nhu`) giúp chọn từ nhanh chóng.
  - Nút 4 ô vuông (`square.grid.2x2.fill`) bên trái mở nhanh Cài đặt và Bảng tạm.
  - Vạch ngăn cách dọc tinh tế giữa các từ.
- **Gõ lướt cử chỉ (Glide Typing):**
  - Vẽ vệt sáng chuyển màu (gradient trail) theo quỹ đạo lướt của ngón tay bằng `CAShapeLayer`.
  - So khớp cử chỉ vuốt với cây tiền tố `WordTrie`, tự động nhận diện từ chính xác.
- **Lịch sử Bảng tạm (Clipboard History):**
  - Tự động lưu 20 đoạn văn bản copy gần nhất vào App Group Container an toàn.
  - Cho phép chọn dán nhanh văn bản hoặc dọn dẹp lịch sử.

### 3.5. Kho Từ điển Tiếng Việt Tần suất cao
- Sử dụng trọn bộ **19.047 từ vựng** từ dự án uy tín `tabidots/vn-freqs`.
- Định dạng nạp từ tệp văn bản `vietnamese_words.txt` cực nhẹ (~247 KB).
- Cấu trúc cây tiền tố Trie đa luồng nạp trong < 90ms và tra cứu < 0.05ms.
- Tự động fallback danh sách tĩnh nếu tệp gặp sự cố.

### 3.6. Cấu hình & Khả năng Tuỳ biến (Settings)
- Hỗ trợ tuỳ chỉnh chiều cao bàn phím: **Rất nhỏ, Nhỏ, Trung bình (mặc định), Lớn, Rất lớn**.
- Toàn bộ cài đặt được đồng bộ thời gian thực qua **App Group** (`group.com.nguyenphuong.vBoard`).
