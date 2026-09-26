#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
download_corpus.py - Tải và giải nén ngữ liệu mẫu tiếng Việt từ Leipzig Corpora Collection
(Tập hợp các câu văn bản tiếng Việt thực tế từ báo chí và web)
"""

import os
import sys
import urllib.request
import tarfile

# Leipzig Vietnamese 2020 News (100K hoặc 300K câu sạch)
CORPUS_URL = "https://downloads.leipzig-corpora.de/corpora/vie_news_2020_100K.tar.gz"
TARGET_DIR = "CorpusData"
TAR_FILE = os.path.join(TARGET_DIR, "vie_news_2020_100K.tar.gz")

def download_and_extract():
    os.makedirs(TARGET_DIR, exist_ok=True)
    
    sentences_file = os.path.join(TARGET_DIR, "vie_news_2020_100K", "vie_news_2020_100K-sentences.txt")
    if os.path.exists(sentences_file):
        print(f"✅ Đã có sẵn file ngữ liệu tại: {sentences_file}")
        return sentences_file

    print(f"📥 Đang tải tập ngữ liệu Leipzig Vietnamese News (100K câu)...")
    print(f"   URL: {CORPUS_URL}")
    
    try:
        urllib.request.urlretrieve(CORPUS_URL, TAR_FILE)
        print(f"📦 Đang giải nén tập tin...")
        with tarfile.open(TAR_FILE, "r:gz") as tar:
            tar.extractall(path=TARGET_DIR)
        print(f"✅ Đã giải nén thành công vào {TARGET_DIR}")
        return sentences_file
    except Exception as e:
        print(f"⚠️ Không thể tự động tải qua URL (lỗi mạng hoặc chặn kết nối): {e}")
        print("💡 Bạn có thể đặt file text ngữ liệu bất kỳ vào thư mục và chạy build_ngram_lexicon.py trực tiếp.")
        return None

if __name__ == "__main__":
    download_and_extract()
