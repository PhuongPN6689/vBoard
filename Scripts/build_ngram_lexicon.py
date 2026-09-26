#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
build_ngram_lexicon.py - vBoard Corpus & N-gram Processing Pipeline

Pipeline xử lý ngữ liệu tiếng Việt:
1. Đọc corpus dạng text (từng dòng hoặc file lớn stream).
2. Chuẩn hoá văn bản (Unicode NFC, hạ chữ thường, tách câu, lọc ký tự đặc biệt).
3. Đếm tần suất thống kê:
   - Unigram (từ đơn): Count(w)
   - Bigram: Count(w1, w2)
   - Trigram: Count(w1, w2, w3)
4. Lọc ngưỡng (Thresholding) & Chuẩn hoá điểm (1 - 255).
5. Xuất ra định dạng vietnamese_words.txt cho vBoardEngine:
   - Từ đơn -> nạp vào WordTrie (tự sinh không dấu)
   - Cụm từ -> nạp vào NextWordPredictor (N-gram)
"""

import sys
import os
import re
import math
import unicodedata
from collections import Counter, defaultdict

VIETNAMESE_VOWELS_REGEX = r"[a-zA-ZàáảãạăắằẳẵặâấầẩẫậèéẻẽẹêếềểễệìíỉĩịòóỏõọôốồổỗộơớờởỡợùúủũụưứừửữựỳýỷỹỵđĐ]"
WORD_REGEX = re.compile(r"^[a-zA-ZàáảãạăắằẳẵặâấầẩẫậèéẻẽẹêếềểễệìíỉĩịòóỏõọôốồổỗộơớờởỡợùúủũụưứừửữựỳýỷỹỵđĐ]+$")
SENTENCE_SPLIT_REGEX = re.compile(r"[\.\?!;\n\r\t]+")

def normalize_text(text: str) -> str:
    """Chuẩn hóa chuỗi về Unicode NFC và chữ thường."""
    return unicodedata.normalize("NFC", text).strip()

def tokenize_line(line: str):
    """Tách câu thành các tokens âm tiết hợp lệ."""
    sentences = SENTENCE_SPLIT_REGEX.split(line)
    for sent in sentences:
        sent = normalize_text(sent)
        if not sent:
            continue
        raw_tokens = sent.split()
        valid_tokens = []
        for tok in raw_tokens:
            tok_clean = tok.strip(" ,:\"'“”‘’()[]{}<>-–—/\\@#$%^&*+=~`").lower()
            if tok_clean and WORD_REGEX.match(tok_clean) and len(tok_clean) <= 15:
                valid_tokens.append(tok_clean)
        if valid_tokens:
            yield valid_tokens

def extract_ngrams(corpus_filepaths, min_unigram_count=2, min_bigram_count=2, min_trigram_count=2):
    """Trích xuất và đếm số lần xuất hiện của Unigram, Bigram, Trigram từ danh sách file."""
    unigram_counter = Counter()
    bigram_counter = Counter()
    trigram_counter = Counter()

    print(f"📖 Bắt đầu đọc và phân tích ngữ liệu...")
    total_tokens = 0
    total_lines = 0

    for filepath in corpus_filepaths:
        if not os.path.exists(filepath):
            print(f"⚠️ Không tìm thấy file: {filepath}")
            continue
        
        print(f"   -> Đang xử lý: {filepath}")
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                total_lines += 1
                for tokens in tokenize_line(line):
                    n = len(tokens)
                    total_tokens += n
                    
                    # 1. Unigram
                    for tok in tokens:
                        unigram_counter[tok] += 1
                    
                    # 2. Bigram
                    for i in range(n - 1):
                        bigram_counter[(tokens[i], tokens[i+1])] += 1
                        
                    # 3. Trigram
                    for i in range(n - 2):
                        trigram_counter[(tokens[i], tokens[i+1], tokens[i+2])] += 1
                
                if total_lines % 100000 == 0:
                    print(f"      Đã xử lý {total_lines:,} dòng, {total_tokens:,} tokens...")

    print(f"✅ Hoàn tất đếm N-gram. Tổng cộng: {total_lines:,} dòng, {total_tokens:,} tokens.")
    print(f"   - Unigrams thô: {len(unigram_counter):,}")
    print(f"   - Bigrams thô:  {len(bigram_counter):,}")
    print(f"   - Trigrams thô: {len(trigram_counter):,}")

    return unigram_counter, bigram_counter, trigram_counter

def build_vboard_lexicon(
    unigram_counter, 
    bigram_counter, 
    trigram_counter,
    max_unigrams=25000,
    top_bigrams_per_word=10,
    top_trigrams_per_context=6,
    output_filepath="Sources/vBoardEngine/Resources/vietnamese_words.txt"
):
    """
    Chuẩn hoá tần suất theo phân phối Logarithmic (1 - 255) và xuất ra file vBoard.
    """
    print(f"\n⚙️ Đang chọn lọc và chuẩn hoá tần suất cho vBoard...")

    # 1. Xử lý Unigrams (Top N từ phổ biến nhất)
    top_unigrams = unigram_counter.most_common(max_unigrams)
    if not top_unigrams:
        print("❌ Không có Unigram nào hợp lệ!")
        return

    max_u_count = top_unigrams[0][1]
    min_u_count = top_unigrams[-1][1]
    log_max_u = math.log(max_u_count + 1)
    log_min_u = math.log(min_u_count + 1)
    diff_u = log_max_u - log_min_u if log_max_u > log_min_u else 1.0

    unigram_scores = {}
    for word, count in top_unigrams:
        norm = (math.log(count + 1) - log_min_u) / diff_u
        score = int(30 + norm * 225)
        unigram_scores[word] = score

    # 2. Xử lý Bigrams theo context (w1 -> w2)
    bigrams_by_context = defaultdict(list)
    for (w1, w2), count in bigram_counter.items():
        if w1 in unigram_scores and w2 in unigram_scores:
            bigrams_by_context[w1].append((w2, count))

    filtered_bigrams = {}
    for w1, candidates in bigrams_by_context.items():
        candidates.sort(key=lambda x: x[1], reverse=True)
        top_candidates = candidates[:top_bigrams_per_word]
        if not top_candidates:
            continue
        max_c = top_candidates[0][1]
        for w2, count in top_candidates:
            ratio = count / max_c
            score = int(40 + ratio * 210)
            phrase = f"{w1} {w2}"
            filtered_bigrams[phrase] = score

    # 3. Xử lý Trigrams theo context (w1 w2 -> w3)
    trigrams_by_context = defaultdict(list)
    for (w1, w2, w3), count in trigram_counter.items():
        if w1 in unigram_scores and w2 in unigram_scores and w3 in unigram_scores:
            ctx = f"{w1} {w2}"
            trigrams_by_context[ctx].append((w3, count))

    filtered_trigrams = {}
    for ctx, candidates in trigrams_by_context.items():
        candidates.sort(key=lambda x: x[1], reverse=True)
        top_candidates = candidates[:top_trigrams_per_context]
        if not top_candidates:
            continue
        max_c = top_candidates[0][1]
        for w3, count in top_candidates:
            ratio = count / max_c
            score = int(50 + ratio * 205)
            phrase = f"{ctx} {w3}"
            filtered_trigrams[phrase] = score

    # 4. Gộp tất cả các bản ghi
    final_records = []
    
    for word, score in unigram_scores.items():
        final_records.append((word, score))
        
    for phrase, score in filtered_bigrams.items():
        final_records.append((phrase, score))
        
    for phrase, score in filtered_trigrams.items():
        final_records.append((phrase, score))

    final_records.sort(key=lambda x: x[1], reverse=True)

    print(f"📊 Thống kê bộ từ điển mới:")
    print(f"   - Số lượng Unigrams: {len(unigram_scores):,}")
    print(f"   - Số lượng Bigrams:  {len(filtered_bigrams):,}")
    print(f"   - Số lượng Trigrams: {len(filtered_trigrams):,}")
    print(f"   - Tổng số bản ghi:   {len(final_records):,}")

    os.makedirs(os.path.dirname(output_filepath), exist_ok=True)
    with open(output_filepath, "w", encoding="utf-8") as f:
        f.write("# vBoard Vietnamese Lexicon & N-gram Model\n")
        f.write(f"# Unigrams: {len(unigram_scores)}, Bigrams: {len(filtered_bigrams)}, Trigrams: {len(filtered_trigrams)}\n")
        for word, score in final_records:
            f.write(f"{word},{score}\n")

    file_size_kb = os.path.getsize(output_filepath) / 1024
    print(f"💾 Đã ghi file thành công: {output_filepath} ({file_size_kb:.1f} KB)")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Sử dụng: python3 build_ngram_lexicon.py <path_to_corpus_file_1> [<path_to_corpus_file_2> ...]")
        print("Ví dụ: python3 build_ngram_lexicon.py data/sample_corpus.txt")
        sys.exit(1)

    corpus_files = sys.argv[1:]
    u_counts, b_counts, t_counts = extract_ngrams(corpus_files)
    build_vboard_lexicon(u_counts, b_counts, t_counts)
