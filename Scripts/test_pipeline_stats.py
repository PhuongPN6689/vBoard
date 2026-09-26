import os, json, unicodedata, re, math
from collections import Counter, defaultdict

print("Kiểm tra dữ liệu có sẵn:")
for f in os.listdir("CorpusData"):
    path = os.path.join("CorpusData", f)
    print(f" - {f}: {os.path.getsize(path)/1024:.1f} KB")

