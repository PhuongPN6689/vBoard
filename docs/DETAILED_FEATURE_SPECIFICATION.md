# TÀI LIỆU ĐẶC TẢ THIẾT KẾ CHI TIẾT CÁC TÍNH NĂNG CHỌN LỌC vBoard
*(vBoard Selected Features Design Specification & Technical Blueprint)*

> **Phiên bản:** 1.2.0  
> **Nền tảng:** iOS 16.0+ (Swift 6 / UIKit Pure Frame Layout & SwiftUI NavigationStack)  
> **Mục tiêu cốt lõi:** Hiện thực hóa các tính năng tinh hoa từ Gboard với trải nghiệm mượt mà 60/120fps, duy trì nghiêm ngặt mức chiếm dụng RAM < 15MB, bảo mật dữ liệu tuyệt đối và không giật lag.

---

## PHẦN 1: BÁO CÁO KIỂM TRA TÍNH KHẢ THI KỸ THUẬT TRÊN NỀN TẢNG iOS

### 1.1. Cặp Nút Hoàn tác (Undo / "Hủy") & Làm lại (Redo / "Hoàn hủy"): CƠ CHẾ NGUYÊN TỬ VỚI OPENKEY

#### Vấn đề đặc thù cốt tử của OpenKey (Phân tích chuyên sâu):
1. **Bản chất hoạt động của bộ gõ OpenKey:**
   - Để bỏ dấu tiếng Việt mà không phụ thuộc vào bộ gạch chân `markedText`, OpenKey sử dụng kỹ thuật **xóa lùi nhiều ký tự và chèn lại từ hoàn chỉnh**:
     - *Ví dụ:* Người dùng đã gõ `t` $\to$ `o` $\to$ `a` $\to$ `n` (trên màn hình là `toan`).
     - Khi người dùng gõ tiếp phím `s` để thêm dấu sắc: OpenKey FSM tính toán và phát lệnh tới proxy: `deleteBackward()` 4 lần (xóa sạch `toan`), sau đó gọi `insertText("toán")`.
2. **Lỗi nghiêm trọng nếu thiết kế Undo ngây thơ (Naive Proxy-level Undo):**
   - Nếu bộ Undo chỉ đơn thuần ghi nhận từng lệnh proxy riêng rẽ (`deleteBackward` và `insertText` rời rạc):
     - Khi người dùng bấm Undo, hệ thống sẽ chỉ xóa từ `"toán"` hoặc điền lại 4 ký tự vụn vặt, biến văn bản thành `"toantoán"` hoặc mất trắng từ!
     - Nghiêm trọng hơn, khi người dùng bấm phím Xóa (Backspace) ngay sau đó, trạng thái bộ nhớ đệm âm tiết của OpenKey FSM và ký tự thực tế trên màn hình sẽ **bị lệch pha hoàn toàn (desynchronized)**, dẫn đến việc xóa sai ký tự hoặc kẹt bộ gõ.

#### Giải pháp thiết kế kiến trúc chuẩn: Giao dịch Nguyên tử (Atomic Transaction Engine)

```
[ NGƯỜI DÙNG THAO TÁC ] ───> [ ATOMIC TRANSACTION DISPATCHER ]
                                    │
                                    ├── 1. Ghi nhận Context Trước & Sau
                                    ├── 2. Đóng gói AtomicTransaction
                                    ├── 3. Cập nhật Undo Stack & Xóa Redo Stack
                                    └── 4. Đồng bộ State Machine OpenKey
```

1. **Cấu trúc Giao dịch Nguyên tử (`AtomicTransaction`):**
   ```swift
   public struct AtomicTransaction: Sendable {
       public enum TransactionKind: Sendable {
           // Gõ phím tiếng Việt (kể cả phím tạo dấu gây ra xóa/chèn của OpenKey)
           case typing(deletedString: String, insertedString: String)
           // Mở rộng từ viết tắt (Shortcuts: dc -> được)
           case shortcutExpansion(originalShortcut: String, expandedText: String)
           // Xóa từ bằng cử chỉ vuốt (Swipe-to-delete)
           case swipeDelete(deletedText: String)
           // Dán từ bảng tạm (Clipboard paste)
           case paste(pastedText: String)
           // Phím xóa lùi thông thường (Single Backspace)
           case backspace(deletedChar: Character)
       }

       public let kind: TransactionKind
       public let contextBefore: String
       public let timestamp: TimeInterval
   }
   ```

2. **Cặp Ngăn xếp Kép: `UndoStack` & `RedoStack`:**
   - Quản lý 2 ngăn xếp độc lập: `undoStack: [AtomicTransaction]` và `redoStack: [AtomicTransaction]`.
   - Giới hạn độ sâu: 30 transactions gần nhất (RAM tiêu tốn **< 25 KB**).
   - **Bất kỳ khi nào người dùng gõ ký tự mới bằng tay:** Lập tức xóa trắng `redoStack.removeAll()` (tuân thủ nguyên lý chuẩn của mọi hệ thống soạn thảo).

3. **Cơ chế hoạt động của Nút Hoàn tác (Undo - `arrow.uturn.backward`):**
   - Lấy transaction trên cùng của `undoStack`.
   - **Xử lý nghịch đảo (Reverse Mutation):**
     - Nếu là `typing(deletedString, insertedString)` (ví dụ `toan` $\to$ `toán`):
       - Gọi `deleteBackward()` đúng bằng độ dài `insertedString` ("toán" có 4 ký tự).
       - Gọi `insertText(deletedString)` (điền lại đúng "toan").
     - Nếu là `shortcutExpansion`: Xóa "được " và chèn lại "dc".
     - Nếu là `swipeDelete`: Chèn lại chuỗi văn bản đã bị xóa lướt.
     - Nếu là `paste`: Xóa lùi số ký tự của đoạn vừa paste.
   - **Đồng bộ hóa FSM của OpenKey (Crucial Step):**
     - Gọi `engine.reset()` và phân tích lại âm tiết từ `proxy.documentContextBeforeInput`. Đảm bảo khi người dùng gõ tiếp hoặc nhấn Backspace, bộ gõ hiểu chính xác 100% ngữ cảnh mới!
   - Đẩy transaction này sang `redoStack`.

4. **Cơ chế hoạt động của Nút Làm lại / Hoàn hủy (Redo - `arrow.uturn.forward`):**
   - Lấy transaction trên cùng của `redoStack`.
   - **Xử lý áp dụng lại (Forward Mutation):**
     - Thực thi lại thao tác nguyên bản trên proxy.
     - Đồng bộ lại OpenKey FSM.
   - Đẩy transaction này trở lại `undoStack`.

5. **Hiển thị trên giao diện Toolbar:**
   - Cặp nút xuất hiện cạnh nhau trên thanh Toolbar: `[ ↶ Undo ]` và `[ ↷ Redo ]`.
   - Trạng thái trực quan: Nếu `undoStack.isEmpty`, icon Undo mờ đi (disabled `alpha = 0.35`). Nếu `redoStack.isEmpty`, icon Redo mờ đi. Người dùng nhìn thấy rõ ràng trạng thái khả dụng.

---

### 1.2. Nút Chọn Tất Cả (Select All) & Cơ chế Bôi Đen Văn Bản: CÓ KHẢ THI KHÔNG?

#### Phân tích rào cản Sandbox của Apple:
- `UITextDocumentProxy` chỉ hỗ trợ:
  - `adjustTextPosition(byCharacterOffset:)`: Di chuyển vị trí con trỏ chèn (Caret).
  - `selectedText: String?`: Chỉ cho phép **ĐỌC (Read-only)** đoạn văn bản đang được bôi đen (từ iOS 11+).
- Apple **KHÔNG** cung cấp API `setSelectedTextRange:` hoặc `selectAll:` công khai cho bàn phím bên thứ ba.
- Thao tác bôi đen native và "Chọn tất cả" trên iOS chỉ có thể thực hiện thông qua cử chỉ chạm đúp/giữ ngón tay của người dùng hoặc menu native của hệ điều hành.

#### Quyết định thiết kế chuẩn xác:
- **LOẠI BỎ HOÀN TOÀN** màn hình "Chỉnh sửa văn bản" độc lập với các nút "Chọn" / "Chọn tất cả" giả lập không hoạt động thực chất.
- **TÍCH HỢP VÀ GỘP CỤM ĐIỀU HƯỚNG CON TRỎ VÀO DEV MODE:**
  - Di chuyển các phím di chuyển con trỏ chính xác: Lên, Xuống, Trái, Phải, Đầu dòng (`⇤`), Cuối dòng (`⇥`) tích hợp trực tiếp vào **Bàn phím Lập trình viên (Developer Mode)**.
  - Vừa phục vụ đúng mục đích điều hướng soạn thảo code, viết bài, vừa giải phóng 1 màn hình lớp phủ thừa, giảm đáng kể độ phức tạp của codebase.

---

## PHẦN 2: ĐẶC TẢ CHI TIẾT 21 TÍNH NĂNG CẦN LÀM

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│                           DANH MỤC 21 TÍNH NĂNG CHỌN LỌC                          │
├─────────────────────────────────────┬─────────────────────────────────────────────┤
│ 1. Chế độ gõ một tay (One-handed)   │ 12. Bộ Theme màu toàn diện (Full Themes)    │
│ 2. Cặp nút Hoàn tác & Làm lại       │ 13. Theme Gradient (Dốc nhẹ & Dốc đứng)     │
│    (Undo & Redo Atomic Transactions)│ 14. Công tắc Bật/Tắt viền phím (Key Border) │
│ 3. Tùy biến Toolbar trong Cài đặt   │ 15. Tự động viết hoa đầu câu (Auto-Cap)     │
│ 4. Tách các trang Cài đặt độc lập   │ 16. Dự đoán từ tiếp theo (n-gram)           │
│ 5. Hàng số thông minh cho mật khẩu  │ 17. Tách trang Glide & Toggle Vệt trượt     │
│ 6. Bật/Tắt phím phẩy và phím chấm   │ 18. Tinh chỉnh thuật toán Glide tiếng Việt  │
│ 7. Chọn Font & Slider Cỡ chữ        │ 19. Chuyển văn bản thành Emoji (Text-Emoji) │
│ 8. Vuốt phím xuống nhập ký hiệu     │ 20. Bong bóng vuốt nhanh (Swipe Callout)    │
│ 9. Dấu cách tự động sau dấu câu     │ 21. Phím < > ở hàng đáy điều hướng con trỏ  │
│ 10. Tự động về chữ cái sau nháy đơn │ + Tích hợp điều hướng con trỏ vào Dev Mode  │
│ 11. Âm thanh gõ phím & Slider volume│                                             │
└─────────────────────────────────────┴─────────────────────────────────────────────┘
```

---

### 1. Chế độ Bàn phím Gõ Một Tay (One-Handed Mode)

#### Mục tiêu UX:
Thu hẹp bề ngang bàn phím dạt sang cạnh trái hoặc phải màn hình, giúp người dùng dùng một ngón tay cái có thể với tới mọi ký tự trên các thiết bị màn hình lớn (iPhone Plus / Pro Max).

#### Thiết kế giao diện & Kích thước:
- **Tỷ lệ thu hẹp:** Bề ngang cụm phím chính chiếm **84%** chiều rộng màn hình.
- **Khoảng trống 16% còn lại:** Trở thành cột công cụ chuyên dụng (Side Control Column):
  - **Nút Đảo chiều (Swap Side):** Icon `arrow.left.and.right` / `chevron.left` hoặc `chevron.right` để lập tức chuyển bàn phím sang tay đối diện.
  - **Nút Thoát một tay (Expand):** Icon `arrow.up.left.and.arrow.down.right` để đưa bàn phím trở lại chế độ toàn màn hình 100%.
  - **Nút Đổi vị trí (Position/Settings):** Mở nhanh tùy chọn vị trí.
- **Lưu cấu hình:** Lưu trạng thái vào `vBoardSettings.oneHandedMode` (`enum OneHandedMode: String { case off, left, right }`).

```
[ Chế độ Một tay phải - Cột điều khiển nằm bên trái ]
+----+---------------------------------------------------+
|    | [q] [w] [e] [r] [t] [y] [u] [i] [o] [p]           |
| <  |  [a] [s] [d] [f] [g] [h] [j] [k] [l]              |
|    | [⇧]  [z] [x] [c] [v] [b] [n] [m]  [⌫]             |
| ⤢  | [?123] [,] [    Tiếng Việt    ] [.] [↵]           |
+----+---------------------------------------------------+
```

---

### 2. Cặp Nút Hoàn tác (Undo) & Làm lại (Redo) Trên Toolbar

#### Mục tiêu UX:
Cung cấp giải pháp an toàn tuyệt đối khi soạn thảo. Người dùng có thể lùi lại khi gõ sai hoặc phục hồi lại khi lỡ tay bấm Hoàn tác quá đà.

#### Thiết kế chi tiết:
- **Vị trí hiển thị:** Trên thanh Toolbar `SuggestionBarView`.
- **Icon chuẩn SF Symbols:**
  - Nút Hoàn tác: `UIImage(systemName: "arrow.uturn.backward")`
  - Nút Làm lại: `UIImage(systemName: "arrow.uturn.forward")`
- **Tương tác xúc giác:** Rung nhẹ Taptic Engine `HapticManager.shared.playSpecialKey()` khi bấm.
- **An toàn ngữ cảnh:** Tự động xóa lịch sử nếu phát hiện người dùng đã chạm tay đổi vị trí con trỏ trong văn bản để không bao giờ ghi đè sai dữ liệu.

---

### 3. Tùy biến Thanh Công cụ Trong Cài đặt (Toolbar Customization)

#### Mục tiêu UX:
Người dùng có thể bật/tắt và tự kéo thả sắp xếp thứ tự hiển thị của các icon trên thanh gợi ý/công cụ theo đúng thói quen cá nhân ngay trong Host App.

#### Thiết kế trong Settings:
- Xây dựng màn hình `ToolbarSettingsView` sử dụng SwiftUI `List` hỗ trợ `.onMove` và `Toggle`:
  ```
  DANH SÁCH CÔNG CỤ TRÊN THANH TOOLBAR (Kéo để xếp lại thứ tự)
  [ ≡ ]  [ Bảng tạm (Clipboard)        ]   [ BẬT ]
  [ ≡ ]  [ Bàn phím Dev (Code Mode)    ]   [ BẬT ]
  [ ≡ ]  [ Cặp nút Hoàn tác & Làm lại  ]   [ BẬT ]
  [ ≡ ]  [ Cài đặt nhanh (Quick Settings)] [ BẬT ]
  [ ≡ ]  [ Chế độ một tay (One-Handed) ]   [ TẮT ]
  ```
- Lưu mảng định danh: `vBoardSettings.toolbarItemsOrder: [String]`.
- Đồng bộ Darwin IPC: `SuggestionBarView` lập tức render lại thứ tự icon theo cấu hình mới.

---

### 4. Cấu trúc Lại Các Trang Cài Đặt Con Độc Lập

#### Kiến trúc cây thư mục màn hình mới:
```
Màn hình Chính (SettingsDashboardView)
├── 1. Khu vực gõ thử nghiệm (Playground)
├── 2. Bố cục & Phím (KeysLayoutSettingsView) [MỚI]
│      ├── Hàng phím số cố định & Hàng số cho mật khẩu
│      ├── Bật/Tắt phím dấu phẩy (,) và dấu chấm (.)
│      ├── Chọn Font chữ & Slider Cỡ chữ
│      └── Chế độ bàn phím một tay
├── 3. Chỉnh sửa & Đề xuất từ (TextCorrectionSettingsView) [MỚI]
│      ├── Tự động viết hoa đầu câu
│      ├── Dấu cách tự động sau dấu câu
│      ├── Tự động chuyển về chữ cái sau dấu nháy đơn
│      └── Dự đoán từ tiếp theo theo ngữ cảnh (n-gram)
├── 4. Nhập bằng cách lướt (GlideTypingSettingsView) [MỚI TÁCH RIÊNG]
│      ├── Bật/Tắt gõ lướt cử chỉ
│      ├── Toggle độc lập cho Vệt trượt ngón tay (Glide Trail)
│      ├── Lướt phím Space di chuyển con trỏ
│      └── Vuốt phím Xóa sang trái để xóa từ
├── 5. Cử chỉ & Phản hồi (GesturesFeedbackSettingsView)
│      ├── Rung phản hồi Taptic & Cường độ
│      ├── Âm thanh gõ phím & Slider âm lượng
│      ├── Vuốt phím xuống để nhập ký hiệu phụ (Flick down)
│      └── Thời gian chạm và giữ (Long-press delay)
├── 6. Giao diện & Chủ đề Màu sắc (ThemeSettingsView)
│      ├── Bộ theme màu toàn diện (Solid Themes)
│      ├── Theme Gradient (Dốc nhẹ & Dốc đứng)
│      ├── Công tắc Bật/Tắt viền phím
│      └── Màu nhấn phím Action
├── 7. Ngôn ngữ & Bộ gõ OpenKey (OpenKeySettingsView)
├── 8. Bàn phím Lập trình viên (DeveloperSettingsView)
├── 9. Bảng tạm & Từ điển (ClipboardDictionarySettingsView)
└── 10. Tùy biến Thanh công cụ Toolbar (ToolbarSettingsView) [MỚI]
```

---

### 5. Hàng Số Thông Minh Cho Mật Khẩu (Smart Number Row for Passwords)

#### Cơ chế hoạt động:
- Kiểm tra thuộc tính của trường văn bản qua `UITextDocumentProxy`:
  ```swift
  let isPassword = (proxy.keyboardType == .asciiCapable) || 
                   (textDocumentProxy.documentInputMode == nil && ... ) ||
                   (proxy.textContentType == .password || proxy.textContentType == .newPassword)
  ```
- Nếu `isNumberRowEnabled == false` (người dùng tắt hàng số trên bàn phím thường để tiết kiệm diện tích màn hình), nhưng bật `isNumberRowForPasswordEnabled == true`:
  - Khi con trỏ nhảy vào ô nhập mật khẩu: Hàng số `1 2 3 4 5 6 7 8 9 0` tự động xuất hiện.
  - Khi rời khỏi ô mật khẩu: Bàn phím tự động thu gọn về dạng 4 hàng chuẩn.

---

### 6. Bật/Tắt Phím Dấu Phẩy (`,`) và Dấu Chấm (`.`)

#### Mục tiêu UX:
Nhiều người dùng muốn phím Space thật dài để ngón tay cái gõ không bị chạm nhầm vào phím phẩy hoặc chấm.

#### Thiết kế:
- Thêm 2 toggle trong Cài đặt Bố cục:
  - `isCommaKeyEnabled: Bool` (Mặc định: Bật)
  - `isPeriodKeyEnabled: Bool` (Mặc định: Bật)
- Tính toán hình học:
  - Nếu tắt phím `,`: Phím Space tự động mở rộng về mép trái.
  - Nếu tắt phím `.`: Phím Space tự động mở rộng về mép phải.
  - Ký hiệu dấu phẩy và chấm vẫn có thể gõ nhanh bằng cách vuốt hoặc gõ trong trang `?123`.

---

### 7. Chọn Phông Chữ & Slider Cỡ Chữ (Font & Font Size)

#### Thiết kế:
- **Lựa chọn phông chữ:**
  1. `San Francisco` (Mặc định iOS - Hiện đại, rõ ràng).
  2. `SF Pro Rounded` (Bo tròn mềm mại chuẩn phong cách Gboard Material You).
  3. `SF Mono` (Monospace đậm chất kỹ thuật, cực hợp cho coder).
  4. `New York / Serif` (Cổ điển, thanh lịch).
- **Slider tỷ lệ cỡ chữ:**
  - Khoảng giá trị: `80%` đến `120%` (Bước nhảy: 5%).
  - Xem trước kích thước phông chữ thời gian thực ngay trong màn hình Cài đặt.

---

### 8. Vuốt Phím Xuống Để Nhập Ký Hiệu (Flick / Swipe Down for Symbol)

#### Mục tiêu UX:
Thay vì phải nhấn giữ phím trong 250ms để hiện popup ký hiệu phụ, người dùng chỉ cần vuốt nhẹ ngón tay từ trên mặt phím xuống dưới $\implies$ Ký hiệu phụ được chèn ngay tức khắc.

#### Thuật toán nhận diện trong `KeyView`:
1. Trong `touchesMoved`:
   $$\Delta y = \text{currentPoint.y} - \text{initialTouchPoint.y}$$
   $$\Delta x = |\text{currentPoint.x} - \text{initialTouchPoint.x}|$$
2. Điều kiện kích hoạt:
   $$\Delta y > 14.0 \quad \text{và} \quad \Delta y > 1.8 \times \Delta x$$
3. Xử lý:
   - Lập tức hủy bộ đếm thời gian long-press.
   - Ẩn preview phóng to.
   - Phát haptic nhẹ và chèn `key.secondaryLabel`.

---

### 9. Dấu Cách Tự Động Sau Dấu Câu (Auto-Space After Punctuation)

#### Cơ chế hoạt động:
- Khi người dùng bấm các phím dấu câu: `,`, `.`, `!`, `?`, `:`, `;`.
- Bộ lọc kiểm tra ký tự tiếp theo được gõ:
  - Nếu là một ký tự chữ cái (a..z): Bàn phím tự động chèn 1 khoảng trắng `" "` vào giữa dấu câu và ký tự đó.
  - Ngăn chặn lỗi người dùng quên gõ phím cách khiến các từ bị dính chùm vào dấu câu.

---

### 10. Tự Động Chuyển Về Chữ Cái Sau Dấu Nháy Đơn (`'`)

#### Cơ chế hoạt động:
- Trong tiếng Việt và tiếng Anh, dấu nháy đơn (`'`) thường dùng cho chữ rút gọn (ví dụ: *I'm*, *don't*, *it's*) hoặc đóng mở trích dẫn.
- Khi người dùng đang ở tầng ký hiệu `?123` và gõ phím `'`:
  - Bàn phím chèn ký tự `'`.
  - Tự động chuyển ngay lập tức về tầng chữ cái `ABC` để tiếp tục gõ từ tiếp theo mà không cần bấm nút quay về bằng tay.

---

### 11. Âm Thanh Gõ Phím & Slider Âm Lượng (Keypress Audio Click)

#### Thiết kế kỹ thuật:
- Sử dụng API âm thanh hệ thống iOS chuẩn của Apple:
  ```swift
  AudioServicesPlaySystemSound(1104) // Âm thanh gõ phím chuẩn iOS
  ```
- **Cài đặt:**
  - Toggle `isKeySoundEnabled: Bool`.
  - Slider `soundVolume: Float` (0.1 đến 1.0) hoặc chọn theo Âm lượng hệ thống.

---

### 12. Bộ Theme Màu Toàn Diện (Full Theme Colors) & Công Tắc Viền Phím

#### Thiết kế Theme:
Thay đổi toàn diện màu sắc của 4 thành phần: (1) Màu nền bàn phím, (2) Màu nền phím chữ, (3) Màu nền phím chức năng, (4) Màu chữ và ký hiệu.

```swift
struct KeyboardThemePalette {
    let canvasBg: UIColor
    let charKeyBg: UIColor
    let specialKeyBg: UIColor
    let textPrimary: UIColor
    let textSecondary: UIColor
    let accentColor: UIColor
    let keyBorderColor: UIColor
}
```

#### Danh mục theme sẵn có:
1. **Gboard Dark Slate** (Đen ghi xám chuẩn Material You).
2. **Pure Pitch Black** (Đen tuyền tuyệt đối cho màn hình OLED, tiết kiệm pin).
3. **Clean Paper White** (Trắng tinh tế tối giản).
4. **Deep Midnight Navy** (Xanh biển đêm sang trọng).
5. **Cyberpunk Slate** (Xám đậm phối phím Enter dạ quang neon).

#### Công tắc Bật/Tắt viền phím (Key Borders Toggle):
- **Bật viền phím:** Từng phím hiển thị dạng khối nổi (có bóng đổ nhẹ và viền bo mềm mại).
- **Tắt viền phím:** Các phím nằm phẳng trên nền không viền bo (Flat borderless Material design) giúp bàn phím cực kỳ thanh thoát.

---

### 13. Theme Gradient (Dốc Nhẹ & Dốc Đứng)

#### Thiết kế kỹ thuật thuần Vector (0MB RAM):
- Tuyệt đối không dùng ảnh bitmap PNG/JPEG tải từ mạng (vốn ngốn hàng chục MB RAM).
- Sử dụng `CAGradientLayer` render trực tiếp bằng phần cứng GPU:
  - **Dốc nhẹ (Light Gradients):**
    - Pastel Rose: `#FFE5EC` $\to$ `#F0E6FF`.
    - Sky Breeze: `#E0F2FE` $\to$ `#EDE9FE`.
    - Mint Whisper: `#E6FFFA` $\to$ `#EBF8FF`.
  - **Dốc đứng (Dark Gradients):**
    - Twilight Purple: `#1E1B4B` $\to$ `#312E81`.
    - Deep Ocean: `#0F172A` $\to$ `#1E293B`.
    - Sunset Glow: `#2D1B36` $\to$ `#4A154B`.

---

### 14. Tự Động Viết Hoa Đầu Câu (Auto-Capitalization)

#### Thuật toán kiểm tra ngữ cảnh:
- Đọc `proxy.documentContextBeforeInput`:
  - Nếu chuỗi trước đó rỗng (bắt đầu đoạn văn bản).
  - Hoặc kết thúc bằng một trong các cụm: `". "`, `"! "`, `"? "`, `"\n"`.
- Bàn phím tự động đặt `isShiftActive = true` và cập nhật phím thành chữ IN HOA.
- Sau khi gõ ký tự chữ cái đầu tiên, phím tự động chuyển về chữ thường.

---

### 15. Dự Đoán Từ Tiếp Theo Theo Ngữ Cảnh (Next-Word Prediction n-gram)

#### Giải pháp tối ưu bộ nhớ:
- Xây dựng bảng tần suất cặp từ tiếng Việt **Bi-gram Table** tinh gọn được trích xuất từ 19.047 từ phổ biến (`vietnamese_words.txt`):
  - Ví dụ:
    - `"xin"` $\to$ `["chào", "lỗi", "phép"]`
    - `"chúc"` $\to$ `["mừng", "ngủ", "bạn"]`
    - `"cảm"` $\to$ `["ơn", "xúc", "thấy"]`
    - `"báo"` $\to$ `["cáo", "chí", "động"]`
    - `"hẹn"` $\to$ `["gặp", "hò", "lại"]`
- Dung lượng bộ nhớ: **Chỉ ~650 KB RAM** (tra cứu trực tiếp dạng bảng băm hoặc mảng nhị phân phẳng).
- Hiển thị ngay 3 từ tiếp theo trên `SuggestionBarView` ngay khi vừa kết thúc từ trước bằng phím Space.

---

### 16. Trang Cài Đặt Riêng "Nhập Bằng Cách Lướt" & Toggle Vệt Trượt & Nâng Cấp Thuật Toán

#### Cấu trúc trang Cài đặt `GlideTypingSettingsView`:
- **Toggle 1:** Bật/Tắt cử chỉ gõ lướt (Glide Typing).
- **Toggle 2 [MỚI]:** Bật/Tắt hiển thị vệt trượt ngón tay (Glide Trail). Nếu tắt, người dùng vẫn lướt gõ bình thường nhưng màn hình không vẽ vệt mực.
- **Toggle 3:** Lướt phím Space di chuyển con trỏ.
- **Toggle 4:** Vuốt phím Xóa sang trái để xóa từ.

#### Nâng cấp thuật toán Glide tiếng Việt:
- Thuật toán trích xuất các điểm ngoặt (Turning Points) trên quỹ đạo vuốt của ngón tay (dựa vào góc lệch vector vận tốc $\vec{v}$).
- Khớp chuỗi điểm ngoặt với cây tiền tố `WordTrie` bằng giải thuật Dynamic Time Warping (DTW) rút gọn.
- Xử lý mượt mà các từ có âm tiết tiếng Việt nhiều nguyên âm (như `nghiêng`, `nguyễn`, `chuyển`).

---

### 17. Chuyển Văn Bản Thành Emoji (Text to Emoji)

#### Mục tiêu UX:
Khi người dùng gõ các từ chỉ cảm xúc hoặc sự vật thông dụng, thanh gợi ý tự động đưa ra Emoji tương ứng để chèn 1 chạm.

#### Bảng ánh xạ từ vựng tiếng Việt sang Emoji:
| Từ khóa gõ | Gợi ý Emoji xuất hiện trên thanh Suggestion |
| :--- | :--- |
| `cười`, `vui`, `haha` | `😄`, `🤣`, `😆` |
| `tim`, `yêu`, `thương` | `❤️`, `🥰`, `😍` |
| `khóc`, `buồn`, `huhu` | `😭`, `🥺`, `😢` |
| `thích`, `ok`, `tuyệt` | `👍`, `👌`, `💯` |
| `chó`, `mèo`, `heo` | `🐶`, `🐱`, `🐷` |
| `mặt trời`, `mưa`, `nắng`| `☀️`, `🌧️`, `🌤️` |
| `lửa`, `cháy`, `nóng` | `🔥`, `🥵`, `⚡` |
| `uống`, `bia`, `cà phê` | `🍻`, `☕`, `🧋` |

---

### 18. Bong Bóng Vuốt Nhanh (Swipe Callout) Chứa Cài Đặt & Một Tay

#### Cơ chế cử chỉ:
- Khi người dùng vuốt nhẹ từ phím `,` chếch lên trên sang phải:
  - Xuất hiện cụm 2 nút tròn nổi bo góc mềm:
    1. **Nút Bánh răng:** Mở nhanh giao diện Cài đặt vBoard.
    2. **Nút Bàn phím một tay:** Bật nhanh chế độ thu hẹp bàn phím.
- Nhả tay trên nút nào thì kích hoạt ngay tính năng đó.

---

### 19. Chip Gợi Ý Thông Minh Trên Toolbar (Smart Quick Chip)

#### Cơ chế hoạt động:
- Khi thanh gợi ý `SuggestionBarView` đang trống hoặc vừa sao chép văn bản mới:
  - Hiển thị một chip dạng viên thuốc bo tròn: `[📋] Dán: "Nội dung vừa copy..."`.
  - Người dùng bấm vào chip để dán tức thì nội dung bảng tạm vào ô nhập mà không cần mở toàn bộ bảng Clipboard.
  - Tự động nhận diện ngữ cảnh: Nếu trong clipboard là đường dẫn web (URL), hiển thị chip `[🔗] Mở liên kết`.

---

### 20. Chuyển Hai Phím `<` và `>` Ở Hàng Đáy Tầng Ký Hiệu Cấp 2 Thành Phím Mũi Tên `←` và `→`

#### Thiết kế điều chỉnh:
- Chuyển hẳn nhãn hiển thị và hành vi của hai phím sang biểu tượng mũi tên chuẩn: **`←`** và **`→`** (đồng nhất với Dev Mode và hình mẫu Gboard).
- Bổ sung điều kiện bắt phím trong `KeyboardViewController.swift`:
  ```swift
  if charStr == "←" || (keyboardView.isSymbolsLayerActive && charStr == "<") {
      proxyWrapper.adjustTextPosition(byCharacterOffset: -1)
  } else if charStr == "→" || (keyboardView.isSymbolsLayerActive && charStr == ">") {
      proxyWrapper.adjustTextPosition(byCharacterOffset: 1)
  }
  ```
- Mang lại khả năng vi điều chỉnh vị trí con trỏ cực kỳ tiện lợi và trực quan ngay trên bàn phím ký hiệu mà không cần giữ phím Space.
- Mang lại khả năng vi điều chỉnh vị trí con trỏ cực kỳ tiện lợi ngay trên bàn phím ký hiệu mà không cần giữ phím Space.

---

### 21. Tinh Giản & Tích Hợp Điều Hướng Con Trỏ Vào Bàn Phím Lập Trình Viên (Dev Mode)

#### Bố cục tích hợp vào Dev Mode:
Thay vì duy trì màn hình "Chỉnh sửa văn bản" với các nút bôi đen không khả dụng trên iOS, toàn bộ cụm điều hướng con trỏ chuyên sâu được tích hợp thẳng vào hàng đáy của **Bàn phím Lập trình viên**:
- Hàng 4 của Dev Mode:
  `[ ABC ]  [ ⇤ Đầu dòng ]  [ ← ]  [        Space        ]  [ → ]  [ ⇥ Cuối dòng ]  [ ↵ Enter ]`
- Kết hợp hoàn hảo với các nút Clipboard trên Toolbar, người lập trình viên hoặc người soạn thảo văn bản có thể:
  - Di chuyển về đầu dòng, cuối dòng, dịch con trỏ từng ký tự.
  - Thao tác gõ mã nguồn, ngoặc nhọn `{ } [ ]` với tốc độ cao nhất.
  - Hoàn toàn loại bỏ rác giao diện và lỗi thao tác.

---

### 23. Phân hệ Lõi Bộ Gõ OpenKey Swift Thuần (1-1 Core Engine Specification)

#### Mục tiêu Kỹ thuật & Trải nghiệm:
Chuyển đổi hoàn chỉnh cỗ máy gõ tiếng Việt OpenKey (tác giả Mai Vũ Tuyên) từ C++ sang Swift thuần 100%, bảo toàn tính tương thích và độ chính xác luật âm tiết tiếng Việt truyền thống với tốc độ thực thi cao kỷ lục (**~0.01ms / lần gõ**).

#### Các thành phần đặc tả chi tiết:

1. **Bộ đệm 32 ký tự và Máy trạng thái Bitmask:**
   - Mỗi ký tự trong từ đang gõ được biểu diễn bằng một `UInt32` kết hợp mặt nạ bit: `TONE_MASK` (`^`), `TONEW_MASK` (`w`), `MARK1..5` (Sắc, Huyền, Hỏi, Ngã, Nặng), `CAPS_MASK`, `STANDALONE_MASK` (w đầu từ, ngoặc `[` `]`).
   - Khả năng lưu trữ lịch sử hoàn tác qua `typingStates` cho phép khôi phục nguyên vẹn trạng thái từ trước khi biến đổi khi người dùng xóa lùi hoặc gõ phím ngắt từ.

2. **Quy tắc Kiểm tra Chính tả Thời gian Thực (`checkSpelling`):**
   - So khớp phụ âm đầu với 33 cụm phụ âm chuẩn (`ngh`, `ph`, `th`, `tr`, `gi`, `ch`...).
   - Kiểm tra tổ hợp nguyên âm qua bảng ma trận `vowelCombine`, nhận diện chính xác các nguyên âm không được đi kèm phụ âm cuối (`ai`, `ao`, `au`, `oi`, `eo`...).
   - **Luật âm trắc:** Các từ kết thúc bằng `c, ch, t, p` chỉ chấp nhận dấu Sắc hoặc Nặng. Mọi phím dấu Huyền, Hỏi, Ngã gõ vào sẽ bị vô hiệu hóa biến đổi ngay lập tức (`tempDisableKey = true`).

3. **Cơ chế Cân bằng Ngữ âm Tự động (`checkGrammar`):**
   - Tự động nhận biết các từ có cụm `uo` khi gõ thêm phụ âm cuối (`n, c, i, m, p, t`) để đồng bộ cả 2 nguyên âm thành `ươ` (ví dụ `thuon` $\to$ `thươn`, `buoc` $\to$ `bước`).
   - Tự động di chuyển dấu thanh sang vị trí đúng khi bổ sung phụ âm cuối (ví dụ đang là `hoà`, gõ thêm `n` lập tức nhấc dấu thành `hoàn`).

4. **Hệ thống Gõ tắt Macro với AutoCaps:**
   - Quản lý danh sách viết tắt cá nhân với thuật toán `autoCaps` 3 cấp độ:
     - Viết thường `btw ` $\to$ `"by the way "`.
     - Viết hoa đầu `Btw ` $\to$ `"By the way "`.
     - Viết hoa toàn bộ `BTW ` $\to$ `"BY THE WAY "`.

5. **Bộ chuyển đổi `OpenKeyEngineAdapter`:**
   - Kết nối với kiến trúc `EngineAction` (`deleteCount`, `textToInsert`) của iOS `UITextDocumentProxy`.
   - Tương thích 100% với chu trình gõ tuần tự và hỗ trợ hoàn tác nguyên tử.

---

## PHẦN 3: BẢNG THEO DÕI & LỘ TRÌNH TRIỂN KHAI

| Giai đoạn | Nội dung công việc chính | Trạng thái thực tế |
| :--- | :--- | :---: |
| **Sprint 1** | - Xây dựng Action History Stack cho cặp nút Hoàn tác (Undo) & Làm lại (Redo).<br>- Tinh chỉnh 2 phím `<` `>` thành nút di chuyển con trỏ.<br>- Chuyển đổi điều hướng con trỏ vào Dev Mode. | ✅ **Đã hoàn thành 100%**<br>*(Đạt chuẩn 18/18 Tests)* |
| **Sprint 2** | - Tách riêng các màn hình Cài đặt độc lập trong SwiftUI Host App.<br>- Bổ sung màn hình tùy biến thứ tự icon Toolbar.<br>- Bổ sung tính năng Bàn phím gõ một tay (One-handed mode). | ✅ **Đã hoàn thành 100%**<br>*(Đạt chuẩn 18/18 Tests)* |
| **Sprint 3** | - Tự động viết hoa đầu câu & Dấu cách sau dấu câu.<br>- Tự động về chữ cái sau dấu nháy đơn `'`.<br>- Hàng số thông minh cho mật khẩu & Toggle phím `,` `.`. | ✅ **Đã hoàn thành 100%**<br>*(Đạt chuẩn 18/18 Tests)* |
| **Sprint 4** | - Bảng dự đoán từ tiếp theo (Bi-gram table) & Text-to-Emoji.<br>- Vuốt phím xuống nhập ký hiệu (Flick-down).<br>- Âm thanh gõ phím & Smart Quick Chip trên toolbar. | ✅ **Đã hoàn thành 100%**<br>*(Đạt chuẩn 18/18 Tests)* |
| **Sprint 5** | - Bộ Full Themes màu sắc, Theme Gradient vector & Bật/Tắt viền phím.<br>- Tinh chỉnh thuật toán Glide tiếng Việt & Font/Font size slider.<br>- Kiểm tra và kết nối thông suốt 100% các tính năng runtime. | ✅ **Đã hoàn thành 100%**<br>*(Đạt chuẩn 18/18 Tests)* |
| **Sprint 6** | - Chuyển đổi 1-1 mã nguồn C++ lõi OpenKey (Mai Vũ Tuyên) sang Swift thuần.<br>- Hiện thực hóa `OpenKeyDataType`, `OpenKeyVietnameseData`, `OpenKeyEngine`, `OpenKeyMacro`, `OpenKeyEngineAdapter`.<br>- Kiểm định độc lập, phát hiện và khắc phục 4 lỗi cốt tử: vô hiệu hóa `checkGrammar` do `vFreeMark=1`, kích hoạt nhầm Quick Telex do `vQuickTelex=1`, lỗi Bitmask `handleModernMark` và đảo ngược quy ước dấu mới/cũ.<br>- Xây dựng bộ kiểm thử tự động mở rộng `OpenKeyEngineTests` (31 bài test đo hiệu năng & độ chính xác âm tiết thực tế). | ✅ **Đã hoàn thành 100%**<br>*(Đạt chuẩn 31/31 Tests)* |


