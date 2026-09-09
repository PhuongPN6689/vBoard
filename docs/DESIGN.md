# TÀI LIỆU THIẾT KẾ KIẾN TRÚC & GIAO DIỆN BÀN PHÍM vBoard
*(Software Architecture & UI/UX Design Specification)*

---

## 1. TỔNG QUAN KIẾN TRÚC HỆ THỐNG (SYSTEM ARCHITECTURE)

Dự án được phân rã thành **2 tầng cốt lõi (Core Modules)** nhằm đảm bảo tính độc lập, dễ kiểm thử và tải siêu nhanh:

```
                      +------------------------------------------+
                      |         Host Application (vBoard)        |
                      |   (SwiftUI - Cài đặt, Test, Bộ từ điển)  |
                      +--------------------+---------------------+
                                           |
                              App Group: group.com.nguyenphuong.vBoard
                                           |
                      +--------------------+---------------------+
                      |       vBoardKeyboardExtension            |
                      |       (UIInputViewController)            |
                      +--------------------+---------------------+
                                           |
                      +--------------------+---------------------+
                      |           vBoardKeyboard                 |
                      |   (Pure UIKit UI Layer - CGRect layout)   |
                      +--------------------+---------------------+
                                           |
                      +--------------------+---------------------+
                      |            vBoardEngine                  |
                      | (OpenKey Engine, WordTrie, Clipboard)   |
                      +------------------------------------------+
```

### Chi tiết các module:
1. **`vBoardEngine` (Lõi xử lý độc lập):**
   - Hoàn toàn không phụ thuộc vào UIKit của bàn phím.
   - Chứa máy trạng thái gõ tiếng Việt OpenKey (`VietnameseEngine`), âm tiết (`VietnameseSyllable`), ký tự (`VietnameseChar`).
   - Quản lý từ điển cây tiền tố Trie 19.047 từ (`WordTrie`).
   - Quản lý lịch sử bảng tạm (`ClipboardManager`).
   - Cầu nối giao tiếp đệm với iOS qua `TextProxyAdapter`.
   - Cấu hình chia sẻ toàn cục `vBoardSettings`.
2. **`vBoardKeyboard` (Tầng hiển thị giao diện thuần UIKit):**
   - Điều khiển bàn phím `KeyboardViewController`, `KeyboardView`, `KeyView`.
   - Tính toán toạ độ hình học `CGRect` thủ công trong `layoutSubviews()`, loại bỏ 100% overhead của AutoLayout constraints.
   - Vẽ phím và hiệu ứng bằng `CALayer`, `CoreGraphics`, `CAShapeLayer` (vệt sáng gõ lướt Glide).
   - Xử lý cử chỉ: `SpaceCursorHandler`, `BackspaceSwipeHandler`.
   - Thanh gợi ý từ `SuggestionBarView` & menu cài đặt nhanh `QuickSettingsView`.
3. **`KeyboardExtension` (Mở rộng bàn phím iOS):**
   - Kế thừa trực tiếp `KeyboardViewController`.
   - Khai báo quyền `RequestsOpenAccess: true` để chia sẻ dữ liệu Clipboard với Host App.

---

## 2. THIẾT KẾ BỐ CỤC HÌNH HỌC (LAYOUT GEOMETRY SPECIFICATION)

### 2.1. Hàng phím chữ chuẩn QWERTY & Tính toán toạ độ

![Gboard Reference Mockup](assets/media_1788851780382.png)

- **Hàng 1 (`q .. p` - 10 phím):**
  $$\text{stdKeyWidth} = \frac{\text{bounds.width} - 2 \times \text{sideMargin} - 9 \times \text{keySpacing}}{10}$$
- **Hàng 2 (`a .. l` - 9 phím):**
  $$\text{row2Width} = 9 \times \text{stdKeyWidth} + 8 \times \text{keySpacing}$$
  $$\text{currentX} = \frac{\text{bounds.width} - \text{row2Width}}{2} \quad (\text{Thụt đều 0.5 đơn vị phím hai bên})$$
- **Hàng 3 (`Shift` + `z .. m` + `⌫` - 9 phím):**
  - Để 2 bên thẳng hàng tuyệt đối với Hàng 4, độ rộng phím Shift và phím Delete được tính trực tiếp:
  $$\text{sideFunctionKeyWidth} = \frac{\text{bounds.width} - 2 \times \text{sideMargin} - 8 \times \text{keySpacing} - 7 \times \text{stdKeyWidth}}{2}$$
  - Phím Shift (trái) và Xóa (phải) nhận đúng $\text{sideFunctionKeyWidth}$ ($\approx 1.57 \times \text{stdKeyWidth}$).
  - 7 phím chữ ở giữa nhận đúng $\text{stdKeyWidth}$.
- **Hàng 4 (Hàng đáy - 6 phím):**
  - Phím `?123` (trái) có độ rộng $= \text{sideFunctionKeyWidth}$ $\implies$ **thẳng hàng dọc tuyệt đối với Shift**.
  - Phím `↵` (phải) có độ rộng $= \text{sideFunctionKeyWidth}$ $\implies$ **thẳng hàng dọc tuyệt đối với Delete**.
  - Phím `,` (kèm phụ `☺`), `🌐 / ☺`, `.` có độ rộng $= \text{stdKeyWidth}$.
  - Phím `Space` tự động co dãn lấp đầy toàn bộ khoảng trống còn lại ở giữa.

### 2.2. Bàn phím số chuyên dụng (Dedicated Number Pad)
Thiết kế lưới 4x4 hoàn mỹ:
$$\begin{matrix} 
[1] & [2] & [3] & [-] \\
[4] & [5] & [6] & [+] \\
[7] & [8] & [9] & [⌫] \\
[ABC] & [0] & [.] & [↵] 
\end{matrix}$$

### 2.3. Bàn phím Lập trình viên Chuyên dụng (Developer Keyboard Mode)
Chế độ tối ưu hóa cho viết mã nguồn, Markdown, Regex, Terminal SSH (Termius, Blink, iSH), và SQL:
- **Kích hoạt:** Nút biểu tượng mã `</>` trên thanh Toolbar hoặc nhấn giữ phím `?123`.
- **Cơ chế vận hành:**
  - Tự động ngắt (bypass) máy trạng thái tiếng Việt OpenKey và bộ gợi ý từ Trie $\to$ Chuyển sang chế độ nhập ASCII thuần túy, triệt tiêu 100% lỗi dính dấu tiếng Việt khi gõ code (ví dụ `for` không bị thành `fỏ`, `as` không bị thành `ás`).
  - **Tài nguyên tiêu thụ:** Thêm **< 2 KB** RAM (chỉ là mảng dữ liệu phím tĩnh), tốc độ chuyển layer **< 0.01 ms** (tính toán `CGRect` tức thì).
  - Tải CPU giảm đi do không chạy phân tích ngữ âm hay duyệt cây Trie.
- **Bố cục hình học 4 hàng phím Developer:**
  - **Hàng 1 (11 phím):**
    `[ Tab ]  [ { ]  [ } ]  [ [ ]  [ ] ]  [ ( ]  [ ) ]  [ < ]  [ > ]  [ / ]  [ \ ]`
  - **Hàng 2 (11 phím):**
    `[ = ]    [ + ]  [ - ]  [ * ]  [ & ]  [ | ]  [ ! ]  [ ~ ]  [ ^ ]  [ % ]  [ $ ]`
  - **Hàng 3 (10 phím):**
    `[ Shift] [ _ ]  [ : ]  [ ; ]  [ ' ]  [ " ]  [ ` ]  [ ? ]  [ # ]  [ ⌫ Xóa ]`
  - **Hàng 4 (Hàng đáy - 7 phím):**
    `[ ABC ]  [ -> ] [ => ] [        Space        ]  [ ← ]  [ → ]  [ ↵ Enter ]`
- **Các phím tiện ích cao cấp:**
  - **Phím `Tab`:** Thụt lề nhanh (cấu hình `\t`, `2 spaces` hoặc `4 spaces`).
  - **Phím toán tử ghép 1 chạm:** `->`, `=>`, `==`, `!=`, `&&`, `||`.
  - **Phím điều hướng:** `←` và `→` di chuyển con trỏ trong dòng code cực kỳ chính xác.
  - **Đóng ngoặc tự động (Pair Auto-completion - Tuỳ chọn):** Nhấn `{`, `[`, `(` tự động chèn cặp ngoặc đóng và đặt con trỏ ở giữa.

---

## 3. THIẾT KẾ BẢNG MÀU GBOARD MATERIAL YOU (COLOR SYSTEM)

| Phần tử UI | Light Mode | Dark Mode |
| :--- | :--- | :--- |
| **Nền bàn phím** | `#f1f3f4` (Light Slate Gray) | `#1e1f22` (Dark Charcoal) |
| **Phím chữ thông thường** | `#ffffff` (Pure White, shadow nhẹ) | `#36383d` (Soft Dark Gray) |
| **Phím chức năng (`Shift`, `⌫`, `?123`)** | `#d3e3fd` (Soft Material Blue) | `#28292d` (Deep Slate Gray) |
| **Phím Return / Action** | `#c2e7ff` hoặc Xanh Dương `#1a73e8` | Đỏ cam nhấn `#e2553f` hoặc Xanh `#1a73e8` |
| **Vệt sáng gõ lướt (Glide Trail)** | Gradient Cyan -> Blue | Gradient Cyan -> Magenta |
| **Màu chữ chính** | `#1f1f1f` | `#ffffff` |
| **Nhãn phụ góc trên phải** | `#5f6368` (Kích thước 9pt, căn góc phải) | `#9aa0a6` |

---

## 4. THIẾT KẾ BIỂU TƯỢNG ỨNG DỤNG (APP ICON DESIGN)

![App Icon Preview](assets/app_icon_preview.png)

- **Ngôn ngữ hình học:** Khối phím nổi 3D (`Floating Keycap`) bo góc lớn (`rx="146"`).
- **Ý nghĩa biểu tượng:**
  - Chữ `V` monogram cách điệu 3 nhánh thể hiện: **vBoard**, **Vietnamese** và **Velocity** (Tốc độ).
  - Cánh trái dải màu Cyan sang Blue (`#22D3EE` -> `#2563EB`).
  - Cánh phải dải màu Magenta sang Violet (`#F43F5E` -> `#8B5CF6`).
  - **Dấu sắc cách điệu (Tone Mark):** Vàng hổ phách phát sáng (`#F59E0B` -> `#FDE68A`) tượng trưng cho bàn phím tiếng Việt.
- **Tệp nguồn:**
  - `HostApp/Assets.xcassets/AppIcon.appiconset/AppIcon.svg` (Bản gốc Vector).
  - Đầy đủ các kích thước iOS chuẩn từ `40x40` đến `1024x1024`.

---

## 5. THIẾT KẾ CẤU TRÚC DỮ LIỆU TỪ ĐIỂN (WORD TRIE SPECIFICATION)

- **Cấu trúc dữ liệu:** Cây tiền tố (Prefix Trie) kết hợp trọng số tần suất.
- **Node definition:**
  ```swift
  public final class WordTrieNode: @unchecked Sendable {
      public var children: [Character: WordTrieNode] = [:]
      public var word: String?
      public var frequency: Int = 0
  }
  ```
- **Tập dữ liệu:** 19.047 từ trích xuất từ `tabidots/vn-freqs`.
- **Thang điểm logarit chuẩn hóa:**
  $$\text{score} = \max\left(1, \min\left(100, \left\lfloor \frac{\ln(\text{count})}{\ln(\text{max\_count})} \times 99 \right\rfloor + 1 \right)\right)$$
- **Nạp dữ liệu:**
  - Tự động nạp từ `Sources/vBoardEngine/Resources/vietnamese_words.txt` (~247 KB).
  - Thứ tự tìm kiếm: Custom Path -> App Group -> Swift Package Bundle (`Bundle.module`) -> Main Bundle -> Static fallback.
