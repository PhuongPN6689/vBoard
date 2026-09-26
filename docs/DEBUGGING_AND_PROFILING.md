# Hướng Dẫn Debug, Đo Lường RAM & Profile Hiệu Năng Trên iOS
*(iOS Custom Keyboard Extension Debugging, Memory Profiling & Troubleshooting Guide)*

Tài liệu này hướng dẫn chi tiết cách các kỹ sư phát triển gỡ lỗi (debug), bắt log, đo lường bộ nhớ RAM và profile hiệu năng trên thiết bị iPhone thật hoặc Simulator đối với **vBoard**.

---

## 1. Bản Chất Kiến Trúc iOS Custom Keyboard Extension

Trên iOS, Custom Keyboard Extension không phải là một ứng dụng độc lập mà là một tiến trình con do hệ điều hành quản lý:
- Chạy trong **sandbox riêng** với giới hạn bộ nhớ rất gắt gao: **RAM tối đa 30MB - 45MB** (tùy dòng máy). Nếu vượt ngưỡng, hệ thống lập tức kill tiến trình mà không thông báo.
- **Không có Console output tiêu chuẩn** nếu không attach debugger trực tiếp vào process của Extension.
- Các giao tiếp giữa Host App và Extension phải thông qua **App Group Container** (`group.com.nguyenphuong.vBoard`) và hạt nhân **Darwin IPC**.

---

## 2. Cách Attach Debugger Vào Keyboard Extension Trên Xcode

Khi nhấn nút **Run** trong Xcode:
1. Chọn Scheme là `vBoardKeyboardExtension` (hoặc tên target Extension của bạn).
2. Khi Xcode hỏi *"Choose an app to run"*, chọn ứng dụng cần test (ví dụ: **Safari**, **Notes / Ghi chú**, hoặc **Messages / Tin nhắn**).
3. Sau khi ứng dụng mở ra, chạm vào một ô nhập liệu để bàn phím vBoard xuất hiện.
4. Kiểm tra trên Xcode Console:
   - Nếu debugger đã attach thành công, tiến trình `vBoardKeyboardExtension` sẽ hiển thị trong danh sách Debug Navigator bên trái Xcode.
5. **Debug thủ công (Manual Attach):**
   - Vào menu Xcode: `Debug > Attach to Process by PID or Name...`
   - Gõ `vBoardKeyboardExtension` và nhấn **Attach**.

---

## 3. Đo Lường Mức Chiếm Dụng Bộ Nhớ (Memory Profiling) Bằng Xcode Instruments

Để đảm bảo bàn phím luôn đạt mục tiêu **RAM < 15MB**:

### 3.1. Dùng Xcode Debug Navigator (Realtime Gauge)
- Trong lúc bàn phím đang hiển thị trên màn hình:
  - Mở tab **Debug Navigator** (`Cmd + 7`) trên Xcode.
  - Chọn mục **Memory**:
    - **Expected Target:** `~9.5 MB - 14.8 MB`.
    - **Cảnh báo (Warning Threshold):** Nếu vượt quá `25 MB`, cần kiểm tra ngay các thành phần nạp ảnh bitmap hoặc cache chuỗi.

### 3.2. Dùng Instruments Allocations & Leaks
1. Trong Xcode, chọn `Product > Profile` (`Cmd + I`).
2. Chọn công cụ template: **Allocations**.
3. Tại mục chọn Target: chọn thiết bị iPhone thật và chọn tiến trình `vBoardKeyboardExtension`.
4. Nhấn **Record**:
   - Thử gõ 100 từ tiếng Việt liên tục.
   - Thử vuốt Space di chuyển con trỏ 20 lần.
   - Thử vuốt lướt Glide typing.
   - Mở/đóng màn hình Emoji và Bảng tạm.
5. Quan sát biểu đồ **All Heap & Anonymous VM**:
   - Đảm bảo đồ thị là một đường nằm ngang (flat line), không dốc đứng theo thời gian (zero memory leaks).

---

## 4. Bắt Log Liên Tiến Trình (Cross-Process Logging)

Do `print()` thông thường trong Extension có thể bị ngắt khi không gắn debugger, hãy sử dụng **Apple Unified Logging (`os_log`)**:

```swift
import os.log

let logger = Logger(subsystem: "com.nguyenphuong.vBoard", category: "KeyboardExtension")

// Ghi log
logger.info("⚡️ Cold start completed in \(duration) ms")
logger.error("❌ Lỗi nạp từ điển: \(error.localizedDescription)")
```

### Cách xem log trực tiếp bằng Terminal trên Mac:
Mở Terminal và lọc log theo subsystem trong khi cắm iPhone vào máy Mac:
```bash
log stream --predicate 'subsystem == "com.nguyenphuong.vBoard"' --info --debug
```

---

## 5. Xử Lý Các Sự Cố Thường Gặp (Troubleshooting)

### 5.1. Bàn phím bị crash ngay khi vừa xuất hiện (Cold Start Crash)
- **Nguyên nhân phổ biến nhất:** Vượt ngưỡng RAM khởi động hoặc đụng chạm đệ quy trong `layoutSubviews()`.
- **Cách kiểm tra:**
  - Vào `Settings > Privacy & Security > Analytics & Improvements > Analytics Data` trên iPhone.
  - Tìm file log có tiền tố `vBoardKeyboardExtension-*.ips`.
  - Nếu thấy exception code `0xbaadca11` hoặc `EXC_RESOURCE (RESOURCE_TYPE_MEMORY)` $\rightarrow$ Tiến trình bị iOS kill do tràn RAM (Jetsam).

### 5.2. Cài đặt trong Host App không cập nhật sang bàn phím
- **Nguyên nhân:**
  1. Chưa cấu hình đúng App Group Identifier: cả Host App target và Extension target đều phải bật capability **App Groups** với cùng mã `group.com.nguyenphuong.vBoard`.
  2. Darwin IPC không bắn tín hiệu: Kiểm tra xem tên notification hạt nhân `com.nguyenphuong.vBoard.settingsChanged` có đồng nhất ở cả 2 bên hay không.

### 5.3. Bàn phím hiển thị khoảng trắng trống trơn (Blank View)
- Do hàm `viewDidLayoutSubviews()` hoặc `layoutSubviews()` chưa gọi tính toán kích thước phím khi nhận được kích thước frame từ hệ thống. Kiểm tra delegate `layoutSubviews()` của `KeyboardView`.
