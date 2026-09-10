# TÀI LIỆU THIẾT KẾ MÀN HÌNH CÀI ĐẶT ỨNG DỤNG vBoard
*(Host App Settings Architecture & UI/UX Design Specification)*

> **Phiên bản:** 1.0.0  
> **Nền tảng:** iOS 16.0+ (SwiftUI 5 / NavigationStack)  
> **Mục tiêu:** Thiết kế ứng dụng cài đặt trực quan, mượt mà chuẩn iOS HIG kết hợp triết lý tối giản Material You, đồng bộ dữ liệu thời gian thực (Zero-latency) với Keyboard Extension qua App Group.

---

## 1. TỔNG QUAN KIẾN TRÚC & CƠ CHẾ ĐỒNG BỘ DỮ LIỆU (DATA SYNC ARCHITECTURE)

```
 +-------------------------------------------------------------------------+
 |                       Host App (SwiftUI Settings)                       |
 |             - Form / List / NavigationStack đa tầng                     |
 |             - Interactive Playground (Khu vực gõ thử trực tiếp)         |
 +------------------------------------+------------------------------------+
                                      |
                         Ghi dữ liệu (Write)
                                      |
                                      v
 +-------------------------------------------------------------------------+
 |             Shared App Group: group.com.nguyenphuong.vBoard             |
 |             - UserDefaults(suiteName: ...)                              |
 |             - File Container: vietnamese_words.txt, clipboard.json      |
 +------------------------------------+------------------------------------+
                                      |
                         Darwin Notification Trigger
                 ("com.nguyenphuong.vBoard.settingsChanged")
                                      |
                                      v
 +-------------------------------------------------------------------------+
 |                    Keyboard Extension (UIKit Engine)                    |
 |             - Lắng nghe CFNotificationCenter.darwinNotify               |
 |             - Cập nhật vBoardSettings.shared trong < 0.1ms              |
 |             - Redraw CGRect Layout ngay lập tức                         |
 +-------------------------------------------------------------------------+
```

### Điểm nổi bật về hiệu năng:
1. **Đồng bộ Zero-latency (< 0.1ms):** Mỗi khi người dùng gạt công tắc hoặc đổi kích thước trong Settings, một tín hiệu Darwin IPC được phát ra. Bàn phím đang mở bên ngoài (ở bất kỳ app nào) sẽ lập tức cập nhật giao diện mà không cần tắt/bật lại bàn phím.
2. **Không tốn RAM của Extension:** Toàn bộ code giao diện SwiftUI phức tạp nằm 100% trong Host App. Extension chỉ đọc các cờ Bool/Int nguyên bản, giữ bộ nhớ Extension luôn **< 12MB RAM**.

---

## 2. SƠ ĐỒ ĐIỀU HƯỚNG MÀN HÌNH (NAVIGATION HIERARCHY)

```
Root Dashboard (Màn hình chính)
├── 1. Khu vực Gõ Thử Nghiệm Trực Tiếp (Interactive Keyboard Playground)
├── 2. Bố cục & Kích thước (Layout & Dimensions)
├── 3. Ngôn ngữ & Bộ gõ OpenKey (Input Engine & Vietnamese Rules)
├── 4. Bàn phím Lập trình viên (Developer Keyboard Mode) [MỚI]
├── 5. Cử chỉ & Phản hồi Xúc giác (Gestures & Haptics)
├── 6. Giao diện & Chủ đề Màu sắc (Themes & Appearance)
├── 7. Bảng tạm & Từ điển Cá nhân (Clipboard & Dictionary)
└── 8. Hướng dẫn kích hoạt & Giám sát RAM (Guide & Memory Monitor)
```

---

## 3. CHI TIẾT THIẾT KẾ TỪNG MÀN HÌNH CON

### 3.1. Màn hình Chính (Root Dashboard)
Màn hình trung tâm dạng danh mục thẻ bo tròn (Inset Grouped Form), tích hợp ô gõ thử ngay trên đầu để kiểm tra kết quả cài đặt tức thì.

#### Wireframe giao diện:
```
+-------------------------------------------------------------+
|  [v] Cài đặt vBoard                            (i) Trợ giúp |
+-------------------------------------------------------------+
|  KHU VỰC GÕ THỬ NGHIỆM                                      |
|  +-------------------------------------------------------+  |
|  | [Bàn phím ảo] Gõ thử tiếng Việt hoặc code vào đây...  |  |
|  +-------------------------------------------------------+  |
|  | [123 OTP] Thử nghiệm bàn phím số chuyên dụng...       |  |
|  +-------------------------------------------------------+  |
|                                                             |
|  CẤU HÌNH BÀN PHÍM                                          |
|  > [ 📐 ] Bố cục & Kích thước                    Trung bình |
|  > [ 🇻🇳 ] Ngôn ngữ & Bộ gõ OpenKey              Telex Mới  |
|  > [ </> ] Bàn phím Lập trình viên (Dev Mode)    Đang Bật   |
|  > [ 👆 ] Cử chỉ & Phản hồi Xúc giác             Rung nhẹ   |
|  > [ 🎨 ] Giao diện & Màu sắc                    Tự động    |
|  > [ 📋 ] Bảng tạm & Từ điển                     19.047 từ  |
|                                                             |
|  THÔNG TIN & TRẠNG THÁI                                     |
|  > [ ℹ️ ] Hướng dẫn cài đặt bàn phím             Đã bật     |
|  > [ ⚡ ] Hiệu năng: RAM 9.8 MB / Tốc độ: 0.016ms           |
+-------------------------------------------------------------+
```

---

### 3.2. Màn hình Bố cục & Kích thước (Layout & Dimensions)
*(Tham chiếu từ ảnh thực tế `docs/images/1788887442960_...jpg`)*

#### Các trường điều khiển:
1. **Kích thước bàn phím (Keyboard Height Scale):**
   - Điều khiển: `Picker / Segmented Control` gồm 5 nấc:
     - `Rất nhỏ (85%)` | `Nhỏ (92%)` | `Trung bình (100% - Mặc định)` | `Lớn (108%)` | `Rất lớn (115%)`
   - Mô tả: Tăng giảm chiều cao phím để vừa vặn với kích thước bàn tay người dùng.
2. **Hàng phím số trên cùng (Number Row):**
   - Điều khiển: `Toggle (Bật/Tắt)`.
   - Mô tả: Hiển thị thêm 1 hàng cố định các phím `1 2 3 4 5 6 7 8 9 0` ngay trên hàng `q..p`.
3. **Ký hiệu phụ trên phím chữ (Hint Symbols):**
   - Điều khiển: `Toggle (Mặc định: Bật)`.
   - Mô tả: Hiển thị ký tự phụ nhỏ ở góc trên bên phải của phím (chạm giữ để gõ nhanh).
4. **Phím Quả cầu 🌐 (Chuyển bàn phím):**
   - Điều khiển: `Toggle (Ẩn/Hiện)`.
   - Mô tả: Nếu ẩn, phím Space sẽ dài hơn 20%. Trên iPhone có Face ID, nút quả cầu hệ thống đã có sẵn ở góc dưới cùng màn hình.
5. **Tự động mở Bàn phím số dạng lưới (Auto Number Pad):**
   - Điều khiển: `Toggle (Mặc định: Bật)`.
   - Mô tả: Tự động chuyển sang bàn phím số 4x4 khi con trỏ chạm vào ô nhập OTP, thẻ ngân hàng hoặc số điện thoại.

---

### 3.3. Màn hình Ngôn ngữ & Bộ gõ OpenKey
*(Tham chiếu từ thuật toán OpenKey & ảnh `docs/images/1788887442846_...jpg`, `..._526532ee...jpg`)*

#### Các trường điều khiển:
1. **Kiểu gõ chính (Input Method):**
   - Điều khiển: `Picker` gồm: **Telex** (phổ biến nhất), **VNI**, **Simple Telex**.
2. **Quy tắc bỏ dấu thanh (Diacritic Tone Balancing):**
   - Điều khiển: `Picker`:
     - **Kiểu mới (Khuyên dùng):** `hóa`, `thủy`, `toán`, `hoàn` (chuẩn chính tả hiện đại).
     - **Kiểu cũ:** `hoá`, `thuỷ`, `toán`, `hoàn`.
3. **Phím `z` gỡ dấu:**
   - Điều khiển: `Toggle (Mặc định: Bật)`.
   - Mô tả: Nhấn phím `z` ở cuối từ để xóa dấu thanh (`toán` + `z` $\to$ `toan`).
4. **Biến đổi `w` đầu từ:**
   - Điều khiển: `Toggle (Mặc định: Bật)`.
   - Mô tả: Nhấn `w` ở đầu từ tự động thành `ư` (`w` $\to$ `ư`, `W` $\to$ `Ư`).
5. **Gõ tắt ngoặc vuông `[` và `]`:**
   - Điều khiển: `Toggle (Mặc định: Bật)`.
   - Mô tả: Phím tắt chuẩn OpenKey: `[` $\to$ `ơ`, `]` $\to$ `ư`, `{` $\to$ `Ơ`, `}` $\to$ `Ư`.
6. **Quick Telex (Gõ tắt phụ âm kép):**
   - Điều khiển: `Toggle (Mặc định: TẮT)`.
   - Mô tả: Mặc định tắt để gõ các từ như `viettel`, `camera` không bị đổi sai phụ âm kép. Khi bật: `cc` $\to$ `ch`, `gg` $\to$ `gi`, `kk` $\to$ `kh`, `nn` $\to$ `ng`, `qq` $\to$ `qu`, `pp` $\to$ `ph`, `tt` $\to$ `th`.
7. **Gõ tắt phụ âm đầu (`f, j, w`):**
   - Điều khiển: `Toggle (Mặc định: TẮT)`.
   - Mô tả: Gõ `f` $\to$ `ph`, `j` $\to$ `gi`, `w` $\to$ `qu` (`fair` $\to$ `phải`, `jair` $\to$ `giải`, `wa` $\to$ `qua`).
8. **Gõ tắt phụ âm cuối (`g, h, k`):**
   - Điều khiển: `Toggle (Mặc định: TẮT)`.
   - Mô tả: Gõ `g` $\to$ `ng`, `h` $\to$ `nh`, `k` $\to$ `ch` (`tog` $\to$ `tong`, `tih` $\to$ `tinh`, `tik` $\to$ `tich`).
9. **Tự động hoàn tác khi gõ đúp phím dấu (Auto Undo):**
   - Điều khiển: `Toggle (Mặc định: BẬT)`.
   - Mô tả: Ví dụ gõ `aa` $\to$ `â`, nếu gõ thêm `a` nữa sẽ hoàn tác thành `aa`.
10. **Kiểm tra chính tả (Spelling Check):**
    - Điều khiển: `Toggle (Mặc định: BẬT)`.
    - Mô tả: Ngăn chặn các tổ hợp âm tiết không tồn tại trong tiếng Việt theo luật OpenKey.
11. **Sửa gợi ý URL trình duyệt (Fix Browser Suggestion):**
    - Điều khiển: `Toggle (Mặc định: BẬT)`.
    - Mô tả: Không tự động bỏ dấu khi con trỏ đang nhập URL hoặc thanh tìm kiếm web.

---

### 3.4. Màn hình Bàn phím Lập trình viên (Developer Keyboard Mode) [ĐẶC BIỆT]

#### Wireframe giao diện:
```
+-------------------------------------------------------------+
|  < Cài đặt      Bàn phím Lập trình viên (Dev Mode)          |
+-------------------------------------------------------------+
|  KÍCH HOẠT CHẾ ĐỘ DEV                                       |
|  [✓] Bật nút Developer trên bàn phím                        |
|      (Hiện biểu tượng </> trên thanh công cụ Toolbar)       |
|  [✓] Nhấn giữ phím ?123 để mở nhanh chế độ Dev              |
|                                                             |
|  QUY TẮC NHẬP LIỆU LẬP TRÌNH                                |
|  [✓] Khóa cứng tiếng Anh (Strict ASCII)                     |
|      Tự ngắt gõ tiếng Việt để chống dính dấu (for, as, in)  |
|                                                             |
|  CẤU HÌNH PHÍM TAB                                          |
|  Hành vi phím Tab:                     [ 4 Khoảng trắng (v) ]|
|  (Tùy chọn: Ký tự \t, 2 Spaces, 4 Spaces)                   |
|                                                             |
|  TÍNH NĂNG THÔNG MINH                                       |
|  [✓] Tự động đóng cặp ngoặc (Pair Auto-complete)            |
|      Gõ { tự ra {}, gõ [ tự ra [], đưa con trỏ vào giữa     |
|  [✓] Bật hàng phím toán tử 1 chạm                           |
|      Bổ sung phím ->, =>, ==, !=, &&, ||                    |
|  [✓] Cặp phím mũi tên điều hướng (← và →)                   |
+-------------------------------------------------------------+
```

---

### 3.5. Màn hình Cử chỉ & Phản hồi Xúc giác (Gestures & Haptics)
*(Tham chiếu từ ảnh `docs/images/1788887586819_...jpg` & `..._44094752...jpg`)*

#### Các trường điều khiển:
1. **Rung phản hồi xúc giác (Haptic Feedback):**
   - Điều khiển: `Toggle` kèm `Picker cường độ` (Nhẹ, Vừa, Mạnh).
   - Sử dụng: `UIImpactFeedbackGenerator` chuẩn iOS Taptic Engine, trễ < 1ms.
2. **Lướt phím Space điều khiển con trỏ (Space Cursor Trackpad):**
   - Điều khiển: `Toggle (Mặc định: Bật)`.
   - Tần số: 120Hz ProMotion trên iPhone 13 Pro trở lên.
3. **Vuốt phím Xóa để xóa nhanh (Swipe-to-Delete):**
   - Điều khiển: `Toggle (Mặc định: Bật)`.
   - Mô tả: Vuốt từ phím Backspace sang trái để chọn và xóa nguyên từ cực nhanh.
4. **Bong bóng phóng to phím (Key Preview Popover):**
   - Điều khiển: `Toggle (Mặc định: Bật)`.
   - Mô tả: Hiển thị ô phóng to ký tự trên đầu ngón tay khi chạm phím.
5. **Thời gian nhấn giữ (Long-press Delay):**
   - Điều khiển: `Slider` từ `150ms` đến `400ms` (Mặc định: `250ms`).
6. **Nhấn đúp phím Space thành dấu chấm câu (`. `):**
   - Điều khiển: `Toggle (Mặc định: Bật)`.

---

### 3.6. Màn hình Giao diện & Chủ đề Màu sắc (Themes)
*(Tham chiếu từ ảnh `docs/images/1788887443071_...jpg`)*

#### Các trường điều khiển:
1. **Chế độ màu chủ đạo:**
   - `Tự động theo hệ thống (Mặc định)`: Sáng khi ban ngày, Tối khi ban đêm.
   - `Luôn luôn Sáng (Light Mode Material You)`.
   - `Luôn luôn Tối (Dark Charcoal OLED)`.
2. **Bảng màu nhấn (Accent Color):**
   - Bộ sưu tập màu nút Action/Enter:
     - `Google Material Blue (#1a73e8)`
     - `Cyan Gradient (#22D3EE)`
     - `Apple Orange (#FF9500)`
     - `Emerald Green (#10B981)`
     - `Crimson Red (#EF4444)`
3. **Hiển thị viền phím (Key Border Outlines):**
   - Điều khiển: `Toggle (Bật/Tắt viền khối nổi 3D)`.

---

### 3.7. Màn hình Bảng tạm & Từ điển Cá nhân (Clipboard & Dictionary)

#### Các trường điều khiển:
1. **Lịch sử Bảng tạm (Clipboard History):**
   - Điều khiển: `Toggle (Bật/Tắt tính năng lưu lịch sử sao chép)`.
   - Giới hạn lưu trữ: 20 mục gần nhất.
   - Nút `Xóa toàn bộ lịch sử bảng tạm`.
2. **Thanh gợi ý từ (Suggestion Bar):**
   - Điều khiển: `Toggle (Bật/Tắt thanh gợi ý 3 từ trên đỉnh bàn phím)`.
3. **Từ điển tiếng Việt tích hợp:**
   - Trạng thái: Hiển thị quy mô từ điển `19.047 từ` (nguồn `vn-freqs`).
   - Tùy chọn: Thêm từ viết tắt cá nhân (Shortcut Macro - ví dụ `dc` $\to$ `được`, `ko` $\to$ `không`).

---

### 3.8. Màn hình Giám sát Hiệu năng & Hướng dẫn (Performance & About)

#### Nội dung hiển thị:
- **Trạng thái quyền bàn phím:** Kiểm tra xem người dùng đã cấp quyền `Allow Full Access` (để dùng Clipboard) hay chưa.
- **Thước đo tài nguyên thời gian thực (Live Diagnostics):**
  - Mức chiếm RAM ước tính: **~9.8 MB** (Màu xanh lá - An toàn tuyệt đối, dưới xa mức 30MB trần).
  - Tốc độ xử lý ký tự trung bình: **~0.016 ms**.
  - Tốc độ tra cứu tiền tố Trie: **~0.015 ms**.
- **Hướng dẫn 3 bước kích hoạt bàn phím trong iOS Settings:**
  1. Mở *Cài đặt hệ thống* $\to$ *Cài đặt chung* $\to$ *Bàn phím*.
  2. Chọn *Thêm bàn phím mới* $\to$ Chọn **vBoard**.
  3. Bật *Cho phép truy cập đầy đủ* để đồng bộ Bảng tạm.

---

## 4. TỔNG HỢP DATA MODEL CỦA BỘ CÀI ĐẶT (`vBoardSettings`)

Toàn bộ các tùy chọn trên được quản lý tập trung trong struct `vBoardSettings` với cơ chế lưu trữ tự động vào App Group:

```swift
public final class vBoardSettings: @unchecked Sendable {
    public static let shared = vBoardSettings()
    
    // Bố cục & Kích thước
    public var keyboardHeightScale: KeyboardHeightScale // medium (100% - Mặc định)
    public var isNumberRowEnabled: Bool                 // false (Mặc định)
    public var isHintSymbolsEnabled: Bool               // true (Mặc định)
    public var isGlobeKeyHidden: Bool                   // false (Mặc định)
    public var isAutoNumberPadEnabled: Bool             // true (Mặc định)
    public var isKeyBorderEnabled: Bool                 // true (Mặc định)
    
    // Bộ gõ OpenKey
    public var inputMethod: InputMethod                 // .telex (Mặc định)
    public var diacriticStyle: DiacriticStyle           // .newStyle (òa, úy, hòa, thủy - Mặc định)
    public var isSpellingCheckEnabled: Bool             // true (Mặc định BẬT)
    public var isRestoreIfWrongSpellingEnabled: Bool    // false (Mặc định TẮT)
    public var isFixBrowserSuggestionEnabled: Bool      // true (Mặc định BẬT)
    public var isQuickTelexEnabled: Bool                // false (Mặc định TẮT chuẩn OpenKey, tránh lỗi viettel)
    public var isQuickStartConsonantEnabled: Bool       // false (f->ph, j->gi, w->qu - Mặc định TẮT)
    public var isQuickEndConsonantEnabled: Bool         // false (g->ng, h->nh, k->ch - Mặc định TẮT)
    public var isAllowConsonantZFWJEnabled: Bool        // false (Mặc định TẮT)
    public var isBracketShortcutsEnabled: Bool          // true ([ -> ơ, ] -> ư - Mặc định BẬT)
    public var isZKeyRemoveToneEnabled: Bool            // true (phím z gỡ dấu - Mặc định BẬT)
    public var isWAtWordBeginningEnabled: Bool          // true (w đầu từ thành ư - Mặc định BẬT)
    public var isAutoUndoEnabled: Bool                  // true (hoàn tác phím lặp - Mặc định BẬT)
    public var isSmartSwitchModeEnabled: Bool           // true (chuyển đổi thông minh - Mặc định BẬT)
    
    // Gõ tắt & Macro
    public var isShortcutExpansionEnabled: Bool         // true (Mặc định BẬT)
    public var isAutoCapsMacroEnabled: Bool             // true (Mặc định BẬT)
    public var isMacroEvenWhenOffEnabled: Bool          // false (Mặc định TẮT)
    
    // Developer Keyboard Mode
    public var isDeveloperModeButtonEnabled: Bool       // false (Mặc định)
    public var developerTabBehavior: DevTabBehavior     // fourSpaces (Mặc định)
    public var isPairAutoCompleteEnabled: Bool          // true (Mặc định)
    
    // Cử chỉ & Phản hồi
    public var isHapticEnabled: Bool                    // true (Mặc định)
    public var hapticIntensity: HapticIntensity         // medium (Mặc định)
    public var isSoundEnabled: Bool                     // false (Mặc định)
    public var isKeyPreviewEnabled: Bool                // true (Mặc định)
    public var isSpaceCursorTrackpadEnabled: Bool       // true (Mặc định)
    public var isSwipeToDeleteEnabled: Bool             // true (Mặc định)
    public var isSpaceDoubleTapPeriodEnabled: Bool      // true (Mặc định)
    public var isAutoCapitalizationEnabled: Bool        // true (Mặc định)
    public var longPressDelayMs: Int                    // 250 (Mặc định)
    
    // Giao diện & Chủ đề
    public var themeMode: ThemeMode                     // system (Mặc định)
    public var accentColorHex: String                   // "#1a73e8" (Mặc định)
    
    // Bảng tạm & Gợi ý
    public var isSuggestionBarEnabled: Bool             // true (Mặc định)
    public var isSoftSuggestionEnabled: Bool            // true (Gợi ý mềm không dấu - Mặc định)
    public var isClipboardEnabled: Bool                 // true (Mặc định)
    public var isGlideTypingEnabled: Bool               // true (Mặc định)
    public var pasteButtonMode: String                  // "paste" (Chạm dán / Nhấn giữ xem lịch sử - Mặc định)
    public var lastOneHandedSide: OneHandedMode         // .right (Ghi nhớ bên lệch một tay gần nhất)
}
```

---

### 4.2. Cơ chế Deep Link Mở Cài Đặt (`vboard://settings`)
Host App đăng ký Custom URL Scheme `vboard` trong `project.pbxproj` (`CFBundleURLTypes`). Khi người dùng chọn biểu tượng Cài đặt ⚙️ trên bàn phím (hoặc trong menu bong bóng phím `,`), hệ thống gửi URL `vboard://settings` thông qua `extensionContext?.open(url)` để kích hoạt Host App hiển thị màn hình cấu hình. Nếu quyền Full Access chưa được cấp, bàn phím tự động fallback hiển thị `QuickSettingsView` nội bộ.

---

## 5. KẾT LUẬN & ĐÁNH GIÁ ĐỘ KHẢ THI

1. **Giao diện trực quan:** Phân chia 8 màn hình con rõ ràng, không làm người dùng bị ngợp.
2. **Khu vực gõ thử (Playground) độc đáo:** Người dùng có thể chỉnh cài đặt và thử nghiệm ngay lập tức trên cùng một màn hình mà không cần thoát ra ứng dụng khác để kiểm tra.
3. **Tối ưu RAM triệt để:** Bằng cách giữ toàn bộ giao diện quản trị trong Host App và chỉ chia sẻ các cờ cấu hình thô (primitive types) sang Extension, bộ nhớ của bàn phím luôn duy trì ở trạng thái siêu nhẹ (< 12MB RAM), không bao giờ có nguy cơ bị iOS tắt ngang.
