# Quy Chuẩn Ngữ Âm & Bảng Ma Trận Quy Tắc Gõ Tiếng Việt vBoard
*(Vietnamese Orthography, Syllable Permutations & Tone Placement Specification)*

Tài liệu này đóng vai trò là **Đặc tả Quy chuẩn Ngữ âm (Reference Standard)** của bộ gõ `vBoardEngine`, mô tả chi tiết:
1. Bảng mã nguyên âm và phụ âm tiếng Việt.
2. Quy tắc đặt dấu thanh Chuẩn Mới vs Chuẩn Cũ.
3. Ma trận chuyển đổi 3 phương thức gõ: **Telex**, **VNI**, và **Simple Telex**.
4. Các quy tắc gõ tắt, biến đổi nâng cao OpenKey (Quick Telex, phụ âm đầu/cuối, phím z gỡ dấu, phím ngoặc vuông).
5. 12 nhóm âm tiết tiêu biểu và các hoán vị gõ phím thực tế.

---

## 1. Bảng Ký Tự Cơ Bản & Phân Loại Âm Tiết

Tiếng Việt là ngôn ngữ đơn lập, mỗi âm tiết thường có cấu trúc ngữ âm:
$$\text{Âm tiết} = [\text{Phụ âm đầu}] + [\text{Âm đệm}] + \text{Nguyên âm chính} + [\text{Âm cuối}] + \text{Dấu thanh}$$

### 1.1. Bảng Dấu Thanh (Tone Diacritics)
| Dấu thanh | Tên gọi | Ký hiệu Telex | Ký hiệu VNI | Mã Unicode Tổ hợp |
| :--- | :--- | :---: | :---: | :---: |
| **Không dấu** | Ngang (Thanh 0) | *(Không)* | *(Không)* | *(Không)* |
| **Huyền** | Trầm (Thanh 1) | `f` | `2` | `\u{0300}` |
| **Sắc** | Cao (Thanh 2) | `s` | `1` | `\u{0301}` |
| **Hỏi** | Trầm-bổng (Thanh 3) | `r` | `3` | `\u{0309}` |
| **Ngã** | Gãy (Thanh 4) | `x` | `4` | `\u{0303}` |
| **Nặng** | Thấp (Thanh 5) | `j` | `5` | `\u{0303}` |

### 1.2. Bảng Nguyên Âm Có Mũ / Móc & Chữ Đ
| Ký tự gốc | Ký tự biến đổi | Telex | Simple Telex | VNI |
| :---: | :---: | :---: | :---: | :---: |
| `a` | `â` | `aa` | `aa` | `a6` |
| `a` | `ă` | `aw` | `aw` | `a8` |
| `e` | `ê` | `ee` | `ee` | `e6` |
| `o` | `ô` | `oo` | `oo` | `o6` |
| `o` | `ơ` | `ow` | `ow` | `o7` |
| `u` | `ư` | `uw` / `w` | `w` | `u7` |
| `uo` | `ươ` | `uow` / `w` / `uwow` | `w` / `uow` | `u7o7` |
| `d` | `đ` | `dd` | `dd` | `d9` |

---

## 2. Quy Tắc Đặt Dấu Thanh: Chuẩn Mới vs Chuẩn Cũ

`vBoard` cho phép người dùng tùy chọn linh hoạt 2 phong cách đặt dấu thanh:

| Cụm nguyên âm | Ngữ cảnh từ | Chuẩn Mới (`vUseModernOrthography = 0` - Khuyên dùng) | Chuẩn Cũ (`vUseModernOrthography = 1`) |
| :--- | :--- | :---: | :---: |
| `oa` | Không có âm cuối | **hòa, tỏa, xòa, lòa** | **hoà, toả, xoà, loà** |
| `oe` | Không có âm cuối | **khỏe, lóe, khóe** | **khoẻ, loé, khoé** |
| `uy` | Không có âm cuối | **thủy, túy, quỹ, lũy** | **thuỳ, tuý, quỹ, luỹ** |
| `oai, oay, uan, oat...` | Có âm cuối | **toán, hoán, loạt, khoai** | **toán, hoán, loạt, khoai** *(Trùng nhau)* |
| `ua, ia, ưa` | Không có âm cuối | **múa, mía, mưa** | **múa, mía, mưa** *(Trùng nhau)* |

- **Nguyên tắc Chuẩn Mới:** Dấu thanh đặt vào nguyên âm có độ mở vòm miệng lớn hơn khi âm tiết không có âm cuối (`o` hẹp hơn `a`, nên đặt dấu trên `a` $\rightarrow$ `hòa`; `u` hẹp hơn `y`, nên đặt trên `y` $\rightarrow$ `thủy`).
- **Nguyên tắc Chuẩn Cũ:** Dấu thanh đặt vào nguyên âm đứng trước (`hoà`, `thuỳ`).

---

## 3. Các Tính Năng Gõ Tắt & Nâng Cao OpenKey

### 3.1. Phím `z` Gỡ Dấu
- Gõ phím `z` ở cuối bất kỳ từ nào đã có dấu để xóa dấu thanh và đưa về trạng thái gốc.
- Ví dụ: `toán` + `z` $\rightarrow$ `toan`; `đường` + `z` $\rightarrow$ `đương`; `những` + `z` $\rightarrow$ `nhưng`.

### 3.2. Phím Biến Đổi `w` Đầu Từ & Dấu Ngoặc `[` `]`
- **`w` đầu từ:** Bấm `w` khi bắt đầu một từ tự động chuyển thành `ư` (ví dụ: `w` + `n` + `g` $\rightarrow$ `ưng`).
- **Phím ngoặc vuông:**
  - Nhấn `[` $\rightarrow$ ra `ơ`. Nhấn `[[` $\rightarrow$ ra ký tự `[`.
  - Nhấn `]` $\rightarrow$ ra `ư`. Nhấn `]]` $\rightarrow$ ra ký tự `]`.

### 3.3. Viết Tắt Phụ Âm Đầu (Tùy chọn Bật/Tắt)
| Ký tự nhập | Chuyển thành | Ví dụ gõ | Kết quả hiển thị |
| :---: | :---: | :--- | :--- |
| `f` | `ph` | `fair` | **phải** |
| `j` | `gi` | `jair` | **giải** |
| `w` | `qu` | `wa` | **qua** |

### 3.4. Viết Tắt Phụ Âm Cuối (Tùy chọn Bật/Tắt)
| Ký tự nhập | Chuyển thành | Ví dụ gõ | Kết quả hiển thị |
| :---: | :---: | :--- | :--- |
| `g` | `ng` | `tog` | **tong** (hoặc `toog` $\rightarrow$ **tông**) |
| `h` | `nh` | `tih` | **tinh** (hoặc `tiehs` $\rightarrow$ **tiến**) |
| `k` | `ch` | `tik` | **tich** (hoặc `teeks` $\rightarrow$ **tếch**) |

### 3.5. Quick Telex (Tùy chọn Bật/Tắt)
- Gõ nhanh 2 phụ âm giống nhau:
  - `cc` $\rightarrow$ `ch`, `gg` $\rightarrow$ `gi`, `kk` $\rightarrow$ `kh`, `nn` $\rightarrow$ `ng`, `qq` $\rightarrow$ `qu`, `pp` $\rightarrow$ `ph`, `tt` $\rightarrow$ `th`.
- *Lưu ý:* Mặc định **TẮT** để người dùng có thể gõ mượt mà các từ tiếng Anh và thương hiệu (ví dụ: `viettel`, `facebook`, `caffe`).

---

## 4. Ma Trận 12 Nhóm Âm Tiết Tiêu Biểu (Permutation Matrix)

Dưới đây là 12 nhóm kiểm thử ngữ âm kinh điển được tích hợp trong bộ test tự động [`OpenKeyPermutationTests.swift`](file:///Users/nguyenphuong/Projects/phuong/ios/vBoard/Tests/vBoardEngineTests/OpenKeyPermutationTests.swift):

| Nhóm | Đặc điểm ngữ âm | Từ đại diện | Các chuỗi gõ hợp lệ |
| :---: | :--- | :---: | :--- |
| **1** | Nguyên âm đơn + thanh | `cá, mà, nẻ, đi` | `cas`, `maf`, `ner`, `dij` |
| **2** | Nguyên âm mũ (`â, ê, ô`) | `cấp, lên, một` | `caasp`, `leen`, `moojt` |
| **3** | Nguyên âm móc (`ă, ơ, ư`) | `cắt, bớt, mực` | `cawtjs`, `bowts`, `muwjc` |
| **4** | Cặp `ươ` có âm cuối | `thương, được, nước` | `thuowng`, `duowjc`, `nuowsc`, `thuwowng` |
| **5** | Cụm `oa, oe, uy` (Chuẩn mới) | `hòa, khỏe, thủy` | `hoaf`, `khoer`, `thuys` |
| **6** | Cụm `ia, ya, ua, ưa` | `mía, khuya, mùa, xưa` | `mias`, `khuya`, `muaf`, `xuwa` |
| **7** | Âm đệm `u` + nguyên âm | `toán, loan, xuân` | `toans`, `loan`, `xuaan` |
| **8** | Phụ âm kép (`ngh, ngh, ch, ph`) | `nghiêng, chuyện` | `nghieeng`, `chuyenej` |
| **9** | Đổi dấu trực tiếp | `toán -> toàn` | `toans` + `f` $\rightarrow$ `toàn` |
| **10**| Hoàn tác dấu (Undo) | `má -> mas` | `mas` + `s` $\rightarrow$ `mas` |
| **11**| Gõ trễ dấu (Delayed tone) | `vietnam -> việt nam` | Gõ hết từ rồi bỏ dấu ở cuối từ |
| **12**| Ngoại lai & Thương hiệu | `viettel, pass, call` | Giữ nguyên khi gõ từ tiếng Anh |
