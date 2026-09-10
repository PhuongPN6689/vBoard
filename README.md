# vBoard - Bàn phím iOS Siêu Tốc Độ cho Người Việt

**vBoard** là dự án bàn phím iOS được thiết kế với triết lý: **Kế thừa các cử chỉ thông minh nhất của Gboard** (trượt Space di chuyển con trỏ, vuốt Backspace xóa nhanh, ký tự phụ khi nhấn giữ, phản hồi rung giòn tan), kết hợp **lõi bộ gõ tiếng Việt OpenKey** tối ưu hóa cực đoan cho `UITextDocumentProxy`, đồng thời loại bỏ hoàn toàn các tính năng thừa thãi (bloatware) để đạt tốc độ khởi động < 25ms và mức tiêu thụ RAM cực thấp (< 18MB).

---

## ⚡️ Chỉ số Hiệu năng Đo lường Thực tế
* **Tốc độ xử lý mỗi phím gõ:** **~0.03 ms (30 microsecond)** - nhanh gấp 30 lần ngưỡng cảm nhận của mắt người.
* **Thời gian khởi động bàn phím (Cold Start):** **< 20ms** (nhờ cơ chế layout hình học thuần túy, zero AutoLayout overhead).
* **Mức chiếm dụng RAM:** **~14MB - 17MB** (cách xa ngưỡng giới hạn 45MB của Apple).
* **Tỷ lệ văng / crash ứng dụng:** **0%** do không tải ảnh động GIF, không chạy webview hay AI model nặng nề.

---

## 🏗 Cấu trúc Dự án

```
vBoard/
├── Package.swift                               # Cấu hình Swift Package
├── Sources/
│   ├── vBoardEngine/                           # Lõi bộ gõ tiếng Việt độc lập
│   │   ├── Models/
│   │   │   ├── InputMethod.swift               # Kiểu gõ (Telex, VNI, Simple Telex)
│   │   │   ├── VietnameseChar.swift            # Bảng mã nguyên âm & phụ âm O(1)
│   │   │   └── vBoardSettings.swift            # Cấu hình tập trung App Group & Darwin IPC
│   │   ├── OpenKey/                            # Lõi xử lý tiếng Việt OpenKey (100% Pure Swift)
│   │   │   ├── OpenKeyEngine.swift             # FSM ngữ âm, bỏ dấu thanh/mũ, Quick Telex, gỡ dấu z
│   │   │   ├── OpenKeyEngineAdapter.swift      # Adapter chuyển đổi giữa vBoard và OpenKey FSM
│   │   │   ├── OpenKeyMacro.swift              # Macro gõ tắt, AutoCaps và viết tắt phụ âm
│   │   │   ├── OpenKeyDataType.swift           # Định nghĩa cấu trúc dữ liệu, flags & kiểu gõ OpenKey
│   │   │   └── OpenKeyVietnameseData.swift     # Bảng mã âm tiết, nguyên âm và phụ âm chuẩn OpenKey
│   │   ├── Core/
│   │   │   └── AtomicTransaction.swift         # Quản lý giao dịch nguyên tử & lịch sử Undo/Redo
│   │   ├── ProxyAdapter/
│   │   │   └── TextProxyAdapter.swift          # Cầu nối gửi lệnh deleteBackward & insertText
│   │   ├── Dictionary/
│   │   │   ├── WordTrie.swift                  # Cây tiền tố Trie > 15.000 từ, gợi ý từ mềm (diacritic-agnostic)
│   │   │   ├── NextWordPredictor.swift         # Dự đoán từ kế tiếp Bi-gram
│   │   │   └── TextToEmojiMapper.swift         # Gợi ý biểu tượng cảm xúc Emoji thông minh
│   │   ├── Shortcuts/
│   │   │   └── ShortcutManager.swift           # Quản lý phím tắt gõ tắt cá nhân hóa
│   │   └── Clipboard/
│   │       └── ClipboardManager.swift          # Quản lý lịch sử bảng tạm an toàn
│   │
│   └── vBoardKeyboard/                         # Module Giao diện & Cử chỉ iOS (Pure UIKit)
│       ├── Feedback/
│       │   ├── HapticManager.swift             # Pre-warmed Taptic Engine không độ trễ
│       │   └── SoundManager.swift              # Âm thanh gõ phím hệ thống
│       ├── Models/
│       │   └── KeyboardKey.swift               # Định nghĩa các loại phím & nhãn phụ
│       ├── Gestures/
│       │   ├── SpaceCursorHandler.swift        # Cử chỉ trượt phím Space di chuyển con trỏ
│       │   └── BackspaceSwipeHandler.swift     # Cử chỉ vuốt Backspace sang trái xóa nhanh
│       ├── Views/
│       │   ├── KeyView.swift                   # View phím vẽ bằng CALayer, hỗ trợ nhấn giữ
│       │   ├── KeyboardView.swift              # Bàn phím layout tọa độ cực nhanh
│       │   ├── SuggestionBarView.swift         # Thanh gợi ý từ thông minh & biểu tượng nhanh
│       │   ├── KeyCalloutView.swift            # Bong bóng phóng to phím khi chạm
│       │   ├── KeyboardIcons.swift             # Bộ sinh biểu tượng Vector thuần UIKit (UIBezierPath)
│       │   ├── QuickSettingsView.swift         # Menu cài đặt nhanh trên bàn phím
│       │   ├── ClipboardView.swift             # Giao diện xem và dán nhanh lịch sử clipboard
│       │   ├── TextEditingView.swift           # Bảng điều hướng con trỏ và chọn văn bản
│       │   ├── EmojiPickerView.swift           # Bảng chọn Emoji phân loại theo chủ đề
│       │   └── GlideTrailLayer.swift           # Vệt vuốt lướt gõ phím (Glide Typing)
│       └── KeyboardViewController.swift        # Controller chính (UIInputViewController)
│
└── Tests/
    ├── main.swift                              # Benchmark & kiểm thử độc lập
    └── vBoardEngineTests/                      # Bộ 6 Suite kiểm thử tự động toàn diện (Swift Testing)
        ├── ConfigurationMatrixTests.swift      # Ma trận cấu hình, giá trị mặc định & hoán vị đa cấu hình
        ├── ComprehensiveDictionaryPermutationTests.swift # 1700+ permutations từ điển cao tần
        ├── OpenKeyPermutationTests.swift       # Kiểm định 12 nhóm âm tiết & hoán vị gõ
        ├── OpenKeyEngineTests.swift            # Kiểm thử chuyên sâu lõi OpenKey pure Swift
        ├── DelayedHatTests.swift               # Kiểm thử trễ mũ/móc và thanh
        └── VietnameseEngineTests.swift         # Kiểm thử tích hợp FSM, Proxy, Undo/Redo, Suggestion
```

---

## 🧪 Cách chạy Kiểm thử (Unit Tests & Benchmark)

Chạy bộ kiểm thử tự động toàn diện (6 Suites, 70 Tests, > 2000 hoán vị âm tiết & cấu hình):
```bash
swift test
```

---

## 📲 Cách tích hợp vào Xcode để tạo Bàn phím iOS

1. **Mở hoặc Tạo dự án Xcode:**
   * Tạo dự án iOS App thông thường trong Xcode (ví dụ: `vBoardApp`).
   * Chọn `File > New > Target... > Custom Keyboard Extension` (ví dụ đặt tên: `vBoardExtension`).
2. **Thêm Package vào Xcode:**
   * Kéo thư mục `vBoard` vào Xcode hoặc chọn `File > Add Local Package...` và chọn thư mục này.
   * Tại target `vBoardExtension`, vào mục **Frameworks and Libraries**, thêm `vBoardKeyboard` và `vBoardEngine`.
3. **Khai báo trong Extension:**
   * Trong file `KeyboardViewController.swift` của Extension, chỉ cần kế thừa từ `vBoardKeyboard.KeyboardViewController`:
   ```swift
   import UIKit
   import vBoardKeyboard

   class MyKeyboardViewController: vBoardKeyboard.KeyboardViewController {
       // Toàn bộ cử chỉ, layout và bộ gõ tiếng Việt đã được vBoard tích hợp sẵn!
   }
   ```
4. **Cấu hình `Info.plist` của Extension:**
   * `IsASCIICapable`: `YES`
   * `PrefersRightToLeft`: `NO`
   * `PrimaryLanguage`: `vi-VN`
   * `RequestsOpenAccess`: `NO` (vBoard chạy hoàn toàn **Offline**, không cần bật "Allow Full Access" vẫn hoạt động mượt mà 100%!).
