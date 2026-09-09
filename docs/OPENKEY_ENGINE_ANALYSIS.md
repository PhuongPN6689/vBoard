# PHÂN TÍCH ĐẶC ĐIỂM KIẾN TRÚC & LUỒNG XỬ LÝ CỦA OPENKEYENGINE.SWIFT

Tài liệu này hệ thống hoá toàn bộ đặc điểm, cấu trúc dữ liệu và luồng xử lý ký tự của `OpenKeyEngine.swift`, phục vụ việc phát triển, kiểm thử độ phủ và tối ưu hoá các kiểu gõ tiếng Việt tự do (đặc biệt là gõ trễ mũ/dấu thanh sau phụ âm cuối: `motoj => một`).

---

## 1. Cấu Trúc Bộ Nhớ & Trạng Thái Ký Tự

1. **`typingWord: [UInt32]` (kích thước `MAX_BUFF = 64`)**:
   Mỗi phần tử lưu một ký tự trong từ hiện tại bằng kỹ thuật Bitmask:
   - `0x00FF` (`charMask`): Mã phím gốc ASCII (`OpenKeyCode.a`, `OpenKeyCode.o`,...).
   - `OpenKeyMask.tone` (`0x0001_0000`): Cờ biến đổi mũ (`â`, `ê`, `ô`) hoặc âm `đ`.
   - `OpenKeyMask.toneW` (`0x0002_0000`): Cờ biến đổi móc (`ă`, `ơ`, `ư`).
   - `OpenKeyMask.mark` (`0x00F0_0000`): Cờ 5 dấu thanh (sắc `mark1`, huyền `mark2`, hỏi `mark3`, ngã `mark4`, nặng `mark5`).
   - `OpenKeyMask.caps` (`0x8000_0000`): Ký tự viết hoa.

2. **`hookState: OpenKeyHookState`**:
   Gói dữ liệu trả về cho Adapter hoặc UI:
   - `code = .vWillProcess`: Cần xóa lùi `backspaceCount` ký tự và chèn chuỗi mới từ `charData` (`newCharCount` ký tự).
   - `code = .vRestore`: Hoàn tác dấu (Undo) về phím thô ban đầu.
   - `code = .vDoNothing`: Giữ nguyên phím vừa gõ, không thay thế.
   - `code = .vReplaceMaro`: Thay thế chuỗi gõ tắt macro.

---

## 2. Luồng Xử Lý Sự Kiện Ký Tự (`handleEvent` -> `handleMainKey`)

Mỗi khi người dùng gõ một phím Latinh:
1. `handleEvent` kiểm tra ký tự điều khiển (Space, Enter, Delete, dấu câu, số).
2. Nếu là chữ cái, chuyển vào `handleMainKey(data, isCaps)` theo thứ tự ưu tiên:
   - **Phím Z**: Gỡ dấu thanh (`removeMark()`).
   - **Phím Ngoặc vuông `[` và `]`**: Chèn trực tiếp `ơ` và `ư`.
   - **Phím D**: So khớp vần trong `consonantD`. Nếu đúng cấu trúc gõ trễ `đ` ở cuối từ (`did => đi`, `duowcdj => được`), gọi `insertD()`.
   - **Phím Dấu Thanh (`s, f, r, x, j`)**: Quét bảng `vowelForMark`. So khớp đuôi từ lùi dần với `checkCorrectVowel`. Nếu hợp lệ, gọi `insertMark(...)`.
   - **Phím Mũ / Móc (`a, e, o, w`)**: Quét bảng `OpenKeyVietnameseData.vowel[key]`. So khớp với `checkCorrectVowel`. Nếu đúng, gọi `insertAOE(...)` (mũ) hoặc `insertW(...)` (móc).
   - **Phím thường khác**: Chèn vào đuôi `typingWord` qua `insertKey(data)`.
3. Nếu `vFreeMark == 0` (tuân thủ luật ngữ âm), gọi `checkGrammar(...)` để tự động dời dấu thanh về vị trí chuẩn mới nhất nếu người dùng gõ thêm phụ âm cuối.

---

## 3. Cơ Chế Gõ Trễ Mũ & Dấu Thanh Sau Phụ Âm Cuối (Delayed Hat & Mark)

### Ví dụ điển hình: `motoj => một`
- `m - o - t`: Tạo từ đệm `mot` trong `typingWord`.
- Gõ thêm `o`:
  - Engine quét bảng `OpenKeyVietnameseData.vowel[KEY_O]`.
  - Bảng có chứa phần tử `[o, t]`.
  - `checkCorrectVowel` kiểm tra đuôi thấy khớp mẫu `o + t`.
  - Gọi `insertAOE(KEY_O)` $\to$ biến đổi ký tự `o` thành `ô` $\to$ Từ trở thành `môt`.
  - Gửi lệnh xóa lùi 2 ký tự và chèn lại `ôt`.
- Gõ tiếp `j`:
  - Engine quét bảng `OpenKeyVietnameseData.vowelForMark[KEY_O]`.
  - Bảng có chứa `[o, t]`.
  - Khớp luật, gọi `insertMark(mark5)` $\to$ đặt dấu nặng vào `ô` $\to$ Từ trở thành **`một`**.
  - Gửi lệnh xóa lùi 2 ký tự và chèn lại `ột`.

---

## 4. Bảng Tra Dữ Liệu Ngữ Âm Tiếng Việt (`OpenKeyVietnameseData`)

- `vowelCombine`: Các cụm nguyên âm đôi/ba hợp lệ và quy định có được phép có phụ âm cuối hay không.
- `vowel`: Bảng vần cho phép biến đổi mũ/móc khi đã có phụ âm cuối (`moto => môt`, `viet + e => viêt`, `bep + e => bêp`).
- `vowelForMark`: Bảng vần cho phép đặt dấu thanh khi đã có phụ âm cuối (`môt + j => một`, `viêt + j => việt`, `tieng + s => tiếng`).
- `consonantD`: Bảng các âm tiết cho phép gõ trễ phím `d` ở cuối từ (`did => đi`, `duowngdf => đường`, `duowcdj => được`).
