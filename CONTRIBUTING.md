# Hướng Dẫn Đóng Góp Phát Triển Cho Dự Án vBoard
*(vBoard Contributing & Engineering Guidelines)*

Cảm ơn bạn đã quan tâm đến việc đóng góp cho **vBoard** - dự án bàn phím iOS siêu tốc độ dành cho người Việt. Tài liệu này quy định các tiêu chuẩn kỹ thuật, quy trình phát triển và kiểm thử bắt buộc trước khi gửi Pull Request.

---

## 1. Triết Lý Phát Triển Bất Khả Xâm Phạm

Mọi thay đổi mã nguồn hoặc đề xuất tính năng mới phải tuân thủ nghiêm ngặt 4 nguyên tắc:

1. **Zero AutoLayout trên Bàn phím:** Mọi phím bấm và thanh công cụ phải được tính toán tọa độ hình học `CGRect` thủ công trong `layoutSubviews()`. Tuyệt đối không đưa `NSLayoutConstraint` vào `KeyboardView` hoặc `KeyView`.
2. **Ngưỡng RAM Nghiêm Ngặt:** Bàn phím phải duy trì mức tiêu thụ RAM **< 15MB - 18MB**. Bất kỳ tính năng nào làm tăng RAM đột biến đều sẽ bị từ chối.
3. **Decoupled Architecture:** Tầng lõi `vBoardEngine` phải hoàn toàn độc lập khỏi `UIKit`. Mọi tương tác văn bản phải đi qua giao thức trừu tượng `TextDocumentProxyProtocol`.
4. **Không Bloatware:** Không tích hợp trình duyệt nhúng (Webview), thư viện mạng bên ngoài, hay các tính năng hiển thị ảnh động/GIF nặng nề làm giảm tốc độ khởi động.

---

## 2. Quy Chuẩn Code (Coding Standards)

- **Ngôn ngữ:** Swift 6 thuần chủng (`strict concurrency checking`).
- **An toàn luồng:** Mọi thao tác truy cập chia sẻ từ điển hoặc bộ đệm gõ phím phải được bảo vệ bằng `NSLock` hoặc triển khai an toàn theo chuẩn `Sendable`.
- **Định danh & Đặt tên:**
  - Tên class / struct: `UpperCamelCase` (ví dụ: `OpenKeyEngine`, `WordTrie`).
  - Biến & hàm: `lowerCamelCase` (ví dụ: `stripDiacritics`, `suggestWords`).
  - Hằng số cấu hình: Bắt đầu bằng tiền tố rõ ràng.
- **Bình luận mã nguồn:** Viết chú thích bằng tiếng Việt chuẩn ngữ nghĩa hoặc tiếng Anh, giải thích rõ lý do kỹ thuật (Rationale) thay vì chỉ mô tả lại dòng lệnh.

---

## 3. Quy Trình Kiểm Thử Bắt Buộc (Testing Workflow)

Trước khi commit mã nguồn hoặc tạo Pull Request, bạn **bắt buộc** phải chạy thành công 100% bộ kiểm thử tự động:

```bash
swift test
```

### Các tiêu chí nghiệm thu:
- Toàn bộ **7 Test Suites** và **> 90 Test Cases** phải có kết quả **PASSED** (0 failures).
- Tốc độ xử lý ký tự gõ phím phải đạt mức **< 0.05ms**.
- Tốc độ tra cứu cây từ điển `WordTrie` phải đạt mức **< 0.1ms**.

---

## 4. Quy Chuẩn Commit Git & Pull Request

### 4.1. Tiêu đề Commit (Conventional Commits):
- `feat: <mô tả>` - Bổ sung tính năng mới (ví dụ: `feat: thêm bàn phím số chuyên dụng cho OTP`).
- `fix: <mô tả>` - Sửa lỗi bộ gõ hoặc giao diện (ví dụ: `fix: sửa lỗi trễ dấu mũ khi gõ chuỗi ươ`).
- `perf: <mô tả>` - Tối ưu hóa hiệu năng, giảm RAM hoặc tăng tốc độ gõ.
- `docs: <mô tả>` - Bổ sung, chỉnh sửa tài liệu.
- `test: <mô tả>` - Thêm test cases mới.

### 4.2. Danh sách kiểm tra (PR Checklist):
- [ ] Mã nguồn đã được format sạch sẽ, không có cảnh báo (warnings) của trình biên dịch.
- [ ] Đã chạy `swift test` và tất cả các test case đều vượt qua.
- [ ] Đã kiểm tra mức chiếm dụng RAM trên Xcode Instruments (đối với các thay đổi liên quan đến UI hoặc Từ điển).
- [ ] Đã cập nhật tài liệu tương ứng trong thư mục `docs/` nếu có thay đổi về kiến trúc hoặc cấu hình.
