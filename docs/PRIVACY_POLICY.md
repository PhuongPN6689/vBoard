# Chính Sách Bảo Mật vBoard (vBoard Privacy Policy)

**Ngày có hiệu lực: 26/09/2026**  
**Ứng dụng:** vBoard – Bàn phím tiếng Việt thông minh cho iOS  
**Nhà phát triển:** Nguyen Phuong  

---

## 1. Cam Kết Bảo Mật Cốt Lõi (Core Privacy Commitment)

vBoard được xây dựng theo triết lý **Privacy by Design (Bảo mật ngay từ thiết kế)**:
1. **100% Không ghi nhận phím gõ (Zero Keylogging):** vBoard tuyệt đối không ghi nhận, không theo dõi và không lưu trữ lịch sử những gì bạn gõ (bao gồm tài khoản, mật khẩu, tin nhắn, số thẻ tín dụng hoặc bất kỳ thông tin nhạy cảm nào).
2. **Hoạt động Ngoại tuyến Hoàn toàn (Zero Network Access):** Ứng dụng và Keyboard Extension của vBoard không chứa bất kỳ mã nguồn kết nối Internet, máy chủ từ xa, thư viện theo dõi (Tracker) hoặc SDK phân tích (Analytics SDK) nào. Toàn bộ thuật toán gõ tiếng Việt OpenKey và thuật toán vuốt phím (Glide Typing) chạy 100% On-Device trực tiếp trên chip xử lý của thiết bị.
3. **Lưu trữ Cục bộ An toàn (100% On-Device Local Storage):** Từ điển cá nhân, từ viết tắt và các từ ngữ người dùng chủ động lưu trữ chỉ được ghi vào bộ nhớ an toàn (App Group Container) cục bộ trên máy và không bao giờ rời khỏi thiết bị.

---

## 2. Giải Thích Quyền Truy Cập Đầy Đủ (Allow Full Access)

Hệ điều hành iOS của Apple hiển thị một thông báo cảnh báo tiêu chuẩn mỗi khi người dùng kích hoạt "Cho phép Truy cập Đầy đủ" (Allow Full Access) cho bất kỳ bàn phím bên thứ ba nào.

Đối với bàn phím **vBoard**, quyền này chỉ được yêu cầu và sử dụng cho 2 mục đích duy nhất:
1. **Phản hồi Rung Xúc giác (Haptic Feedback):** Cho phép kích hoạt bộ rung Taptic Engine (`UIImpactFeedbackGenerator`) để tạo cảm giác gõ chân thực, êm ái khi bạn chạm vào từng phím.
2. **Nút Dán Văn Bản (Paste Button):** Cho phép người dùng chạm nút Dán trên thanh công cụ để đưa nội dung văn bản trong bảng tạm (`UIPasteboard`) vào ô nhập liệu khi có thao tác người dùng chủ động.

> **Lưu ý quan trọng:**  
> Nếu bạn **KHÔNG** bật "Allow Full Access", vBoard vẫn hoạt động hoàn toàn bình thường cho tất cả các tính năng gõ tiếng Việt Telex, VNI, gõ tắt và gợi ý từ.

---

## 3. Thu Thập và Chia Sẻ Dữ Liệu (Data Collection & Sharing)

- **Dữ liệu cá nhân:** Chúng tôi **KHÔNG** thu thập, lưu trữ hoặc truyền tải bất kỳ thông tin nhận dạng cá nhân nào.
- **Chia sẻ với bên thứ ba:** Chúng tôi **KHÔNG** chia sẻ, bán hoặc chuyển giao bất kỳ dữ liệu nào cho bất kỳ bên thứ ba nào vì không có dữ liệu nào được thu thập.
- **Quyền riêng tư của trẻ em:** Ứng dụng không thu thập bất kỳ thông tin nào từ bất kỳ ai, bao gồm cả trẻ em dưới 13 tuổi.

---

## 4. Liên Hệ (Contact)

Nếu bạn có bất kỳ câu hỏi hoặc đóng góp ý kiến nào về Chính sách Bảo mật của vBoard, vui lòng liên hệ:
- **Email:** support@vboard.app / nguyenphuong.ios@gmail.com
- **Dự án mã nguồn:** [GitHub - vBoard](https://github.com/nguyenphuong/vBoard)
