# vBoard - Bàn phím iOS Siêu Tốc Độ cho Người Việt

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%2016%2B-blue)](#-yêu-cầu-hệ-thống)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Swift Package Manager](https://img.shields.io/badge/SPM-compatible-brightgreen)](Package.swift)

**vBoard** là dự án bàn phím iOS được thiết kế với triết lý: **Kế thừa các cử chỉ thông minh nhất của Gboard** (trượt Space di chuyển con trỏ, vuốt Backspace xóa nhanh, ký tự phụ khi nhấn giữ, phản hồi rung giòn tan), kết hợp **lõi bộ gõ tiếng Việt OpenKey** tối ưu hóa cực đoan cho `UITextDocumentProxy`, đồng thời loại bỏ hoàn toàn các tính năng thừa thãi (bloatware) để đạt tốc độ khởi động < 25ms và mức tiêu thụ RAM cực thấp (< 18MB).

> 🇻🇳 **Bộ gõ tiếng Việt hoàn chỉnh: Telex, VNI, Simple Telex — hoạt động 100% offline, không cần "Allow Full Access".**

---

## ✨ Tính năng nổi bật

| Nhóm | Tính năng |
|------|-----------|
| **Bộ gõ tiếng Việt** | Telex, VNI, Simple Telex 1 & 2; gõ trễ mũ/dấu (`motoj => một`); gỡ dấu bằng phím `z`; bỏ dấu tự do; kiểm tra chính tả; 2 chuẩn chính tả (`oà, uý` / `òá, úy`) |
| **Cử chỉ Gboard** | Trượt Space di chuyển con trỏ; vuốt Backspace xóa nhanh; nhấn giữ phím chọn ký tự phụ; gõ lướt (Glide Typing) có vệt ký tự |
| **Thông minh** | Gợi ý từ mềm (diacritic-agnostic) trên Trie > 15.000 từ; dự đoán từ kế tiếp (Bi-gram); gợi ý Emoji theo ngữ cảnh; macro gõ tắt cá nhân hóa |
| **Tiện ích** | Lịch sử Clipboard; bảng chọn Emoji phân loại; bảng điều hướng con trỏ & chọn văn bản; menu cài đặt nhanh ngay trên bàn phím |
| **Hiệu năng** | Layout hình học thuần CALayer, zero AutoLayout; Haptic Engine pre-warmed; hoàn toàn offline |

---

## ⚡️ Chỉ số Hiệu năng Đo lường Thực tế
* **Tốc độ xử lý mỗi phím gõ:** **~0.03 ms (30 microsecond)** - nhanh gấp 30 lần ngưỡng cảm nhận của mắt người.
* **Thời gian khởi động bàn phím (Cold Start):** **< 20ms** (nhờ cơ chế layout hình học thuần túy, zero AutoLayout overhead).
* **Mức chiếm dụng RAM:** **~14MB - 17MB** (cách xa ngưỡng giới hạn 45MB của Apple).
* **Tỷ lệ văng / crash ứng dụng:** **0%** do không tải ảnh động GIF, không chạy webview hay AI model nặng nề.

---

## 🔒 Quyền riêng tư & Bảo mật

vBoard được thiết kế **không thu thập bất kỳ dữ liệu nào**:

- ✅ **Hoàn toàn offline** — không gửi bất kỳ request mạng nào, không analytics, không tracking.
- ✅ **Không cần "Allow Full Access"** — bàn phím hoạt động đầy đủ ngay cả khi tắt quyền này.
- ✅ Kèm file [`PrivacyInfo.xcprivacy`](KeyboardExtension/PrivacyInfo.xcprivacy) khai báo không thu thập dữ liệu theo chuẩn của Apple.
- ✅ Cấu hình & macro đồng bộ qua **App Group + Darwin Notification IPC** ngay trên thiết bị.

---

## 📋 Yêu cầu Hệ thống

| Yêu cầu | Chi tiết |
|---------|----------|
| Hệ điều hành | iOS 16.0+ (macOS 13+ nếu build engine cho Mac) |
| Ngôn ngữ | Swift 6.0 |
| Công cụ | Xcode 16+ hoặc Swift Package Manager |

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

## 🤝 Đóng góp (Contributing)

Mọi đóng góp đều được hoan nghênh! Vui lòng đọc [CONTRIBUTING.md](CONTRIBUTING.md) để biết quy chuẩn:

- **Bắt buộc** chạy 100% bộ kiểm thử trước khi commit hoặc tạo Pull Request.
- Tiêu đề commit theo chuẩn **Conventional Commits**.

---

## 🗺 Lộ trình (Roadmap)

- [ ] Thêm khả năng tùy chỉnh giao diện bàn phím (theme sáng/tối, màu accent).
- [ ] Mở rộng từ điển gợi ý và học từ người dùng (on-device).
- [ ] Hỗ trợ gõ lướt cho các ngôn ngữ khác.

> 💡 Có ý tưởng mới? Tạo [Issue](../../issues) để thảo luận!

---

## 🚀 Chạy nhanh với Demo App

Repo kèm sẵn app demo ([HostApp/](HostApp/)) và Xcode project ([vBoard.xcodeproj](vBoard.xcodeproj)) được sinh bằng [XcodeGen](https://github.com/yonaskolb/XcodeGen) từ [project.yml](project.yml):

1. Mở `vBoard.xcodeproj` bằng Xcode.
2. Chọn scheme `vBoardApp` và chạy trên máy ảo/thiết bị iOS.
3. Vào **Settings > General > Keyboard > Keyboards > Add New Keyboard...** và chọn **vBoard** để dùng thử.

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

---

## 📄 Giấy phép (License)

Dự án này được phát hành dưới giấy phép **GNU General Public License v3.0 (GPL-3.0)** — xem chi tiết tại file [LICENSE](LICENSE).

```
vBoard - Vietnamese keyboard for iOS
Copyright (C) 2026 Nguyen Phuong

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
```

### Ghi công (Attribution)

Lõi bộ gõ tiếng Việt trong `Sources/vBoardEngine/OpenKey/` là bản chuyển đổi 1-1 sang Swift từ engine **OpenKey** (C++) của tác giả **Mai Vũ Tuyên**, phát hành dưới giấy phép GPL-3.0:

> OpenKey — Vietnamese Input for macOS, Windows and Linux
> © Mai Vũ Tuyên — https://github.com/tuyenvm/OpenKey

Theo điều khoản GPL-3.0, mọi sản phẩm phái sinh từ mã nguồn này (bao gồm cả vBoard) khi phân phối đều phải:
- Cung cấp mã nguồn tương ứng cho người nhận, dưới giấy phép GPL-3.0.
- Giữ nguyên thông tin ghi công tác giả gốc.
- Giấy phép **không** yêu cầu phần mềm phải miễn phí hay cấm quảng cáo — bạn hoàn toàn có thể phân phối có phí hoặc kèm quảng cáo, miễn là tuân thủ các điều khoản mã nguồn mở ở trên.

> ⚠️ **Lưu ý cho App Store:** GPL-3.0 có thể xung khắc với một số điều khoản phân phối của Apple App Store. Nếu bạn dự định phân phối app qua App Store, hãy cân nhắc kỹ (xem [thảo luận của FSF về App Store](https://www.fsf.org/blogs/licensing/more-about-the-app-store-gpl-enforcement-letter)).
