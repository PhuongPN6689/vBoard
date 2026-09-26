# vBoard Dictionary & N-gram Model Pipeline

Công cụ xử lý và huấn luyện dữ liệu từ điển cho bàn phím **vBoard**.

---

## 1. Triết Lý Thiết Kế

1. **Gộp Unigram & Ký tự không dấu:**
   - Chỉ lưu các cặp `(word, frequency)`.
   - Lõi bàn phím (`WordTrie`) tự động bóc tách dấu sang ký tự ASCII thuần và ánh xạ $O(1)$ trong bộ nhớ RAM khi nạp, không tốn thêm dung lượng lưu trữ tĩnh.

2. **Dự Đoán Từ Kế Tiếp Bằng N-gram (Bigram & Trigram):**
   - Không chia thành danh mục "từ ghép" riêng biệt.
   - Mọi cụm 2 từ (Bigram) và 3 từ (Trigram) người dùng hay gõ được học theo xác suất có điều kiện $P(w_2 \mid w_1)$ và $P(w_3 \mid w_1, w_2)$, tự động tích hợp vào `NextWordPredictor`.

3. **Tính Toán Từ Ngữ Liệu Thực Tế (Corpus):**
   - Tần suất được tính toán trực tiếp từ các kho văn bản tiếng Việt giao tiếp / báo chí.

---

## 2. Hướng Dẫn Sử Dụng

### Bước 1: Chuẩn bị file ngữ liệu
Bạn có thể dùng file văn bản bất kỳ (`.txt`) chứa các câu tiếng Việt hoặc tải ngữ liệu mẫu Leipzig:
```bash
python3 Scripts/download_corpus.py
```

### Bước 2: Chạy Pipeline Trích Xuất & Xây Dựng Từ Điển
Chạy script để phân tích N-gram và tự động ghi vào `Sources/vBoardEngine/Resources/vietnamese_words.txt`:
```bash
python3 Scripts/build_ngram_lexicon.py CorpusData/vie_news_2020_100K/vie_news_2020_100K-sentences.txt
```
*(Bạn có thể truyền nhiều file cùng lúc: `python3 Scripts/build_ngram_lexicon.py file1.txt file2.txt ...`)*

### Bước 3: Kiểm thử lại trên vBoard
```bash
swift test
```
