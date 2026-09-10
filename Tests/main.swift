import Foundation

// MARK: - Mock Text Document Proxy
final class MockProxy: TextDocumentProxyProtocol {
    var buffer: String = ""
    var cursorPosition: Int = 0

    var documentContextBeforeInput: String? {
        if cursorPosition <= 0 { return "" }
        let index = buffer.index(buffer.startIndex, offsetBy: cursorPosition)
        return String(buffer[..<index])
    }

    var documentContextAfterInput: String? {
        if cursorPosition >= buffer.count { return "" }
        let index = buffer.index(buffer.startIndex, offsetBy: cursorPosition)
        return String(buffer[index...])
    }

    func deleteBackward() {
        guard cursorPosition > 0 else { return }
        let removeIndex = buffer.index(buffer.startIndex, offsetBy: cursorPosition - 1)
        buffer.remove(at: removeIndex)
        cursorPosition -= 1
    }

    func insertText(_ text: String) {
        let insertIndex = buffer.index(buffer.startIndex, offsetBy: cursorPosition)
        buffer.insert(contentsOf: text, at: insertIndex)
        cursorPosition += text.count
    }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        cursorPosition = max(0, min(buffer.count, cursorPosition + offset))
    }

    func typeSequence(_ sequence: String, adapter: TextProxyAdapter) {
        for char in sequence {
            if char == " " {
                adapter.handleSpace(proxy: self)
            } else {
                adapter.handleKeyInput(char, proxy: self)
            }
        }
    }
}

// MARK: - Main Test Execution
print("==================================================")
print("🚀 ĐANG CHẠY BỘ KIỂM THỬ vBoardEngine (Cực Tốc)")
print("==================================================")

var passedCount = 0
var failedCount = 0

func assertTest(_ condition: Bool, name: String, actual: String = "", expected: String = "") {
    if condition {
        passedCount += 1
        print("  ✅ [PASS] \(name)")
    } else {
        failedCount += 1
        print("  ❌ [FAIL] \(name): KỲ VỌNG: '\(expected)', THỰC TẾ: '\(actual)'")
    }
}

let adapter = TextProxyAdapter()

// 1. Kiểm tra dấu thanh cơ bản (Telex)
print("\n[1] Kiểm tra Dấu thanh Telex (s, f, r, x, j):")
let toneCases = [
    ("as", "á"), ("af", "à"), ("ar", "ả"), ("ax", "ã"), ("aj", "ạ"),
    ("tos", "tó"), ("toof", "tồ"), ("mej", "mẹ")
]
for (input, expected) in toneCases {
    let p = MockProxy()
    p.typeSequence(input, adapter: adapter)
    assertTest(p.buffer == expected, name: "Gõ '\(input)' -> '\(expected)'", actual: p.buffer, expected: expected)
}

// 2. Kiểm tra biến đổi nguyên âm mũ và móc
print("\n[2] Kiểm tra Nguyên âm Mũ & Móc (aa, ee, oo, aw, ow, uw, uow, dd, w):")
let vowelCases = [
    ("aa", "â"), ("ee", "ê"), ("oo", "ô"),
    ("aw", "ă"), ("ow", "ơ"), ("uw", "ư"),
    ("uow", "ươ"), ("dd", "đ"), ("w", "ư"), ("DD", "Đ")
]
for (input, expected) in vowelCases {
    let p = MockProxy()
    p.typeSequence(input, adapter: adapter)
    assertTest(p.buffer == expected, name: "Gõ '\(input)' -> '\(expected)'", actual: p.buffer, expected: expected)
}

// 3. Kiểm tra vị trí đặt dấu thanh chuẩn mới
print("\n[3] Kiểm tra Quy tắc đặt dấu thanh chuẩn mới:")
let placementCases = [
    ("hoaf", "hòa"), ("thuyr", "thủy"), ("toasn", "toán"),
    ("tieens", "tiến"), ("muoons", "muốn"), ("muowns", "mướn"), ("nguowif", "người"),
    ("ddasnh", "đánh")
]
for (input, expected) in placementCases {
    let p = MockProxy()
    p.typeSequence(input, adapter: adapter)
    assertTest(p.buffer == expected, name: "Gõ '\(input)' -> '\(expected)'", actual: p.buffer, expected: expected)
}

// 4. Kiểm tra hoàn tác Undo
print("\n[4] Kiểm tra Hoàn tác (Undo / Double key):")
let undoCases = [
    ("ass", "as"), ("aaa", "aa"), ("ddd", "dd"),
    ("aww", "aw"), ("oww", "ow"), ("uww", "uw")
]
for (input, expected) in undoCases {
    let p = MockProxy()
    p.typeSequence(input, adapter: adapter)
    assertTest(p.buffer == expected, name: "Gõ '\(input)' -> '\(expected)'", actual: p.buffer, expected: expected)
}

// 5. Kiểm tra gõ trọn vẹn cả câu
print("\n[5] Kiểm tra Gõ câu hoàn chỉnh:")
let sentenceProxy = MockProxy()
sentenceProxy.typeSequence("vieetj nam ddaats nuowsc quee huowng tooi", adapter: adapter)
let expectedSentence = "việt nam đất nước quê hương tôi"
assertTest(sentenceProxy.buffer == expectedSentence, name: "Gõ câu tiếng Việt", actual: sentenceProxy.buffer, expected: expectedSentence)

// 6. Kiểm tra cử chỉ di chuyển con trỏ phím Space
print("\n[6] Kiểm tra Di chuyển con trỏ phím Space:")
let spaceProxy = MockProxy()
spaceProxy.typeSequence("xin chao", adapter: adapter)
adapter.moveCursor(by: -4, proxy: spaceProxy)
spaceProxy.insertText("-")
assertTest(spaceProxy.buffer == "xin -chao", name: "Trượt Space lùi 4 ký tự và chèn dấu -", actual: spaceProxy.buffer, expected: "xin -chao")

// 7. Đo lường hiệu năng (Benchmark)
print("\n[7] Benchmark Tốc độ xử lý Keystroke:")
let benchmarkAdapter = OpenKeyEngineAdapter()
let sampleContexts = ["", "t", "to", "tô", "viet", "nguo", "truong"]
let chars: [Character] = ["s", "f", "r", "x", "j", "a", "w", "e", "o", "n", "h", "c"]
let iterations = 20_000
let startTime = CFAbsoluteTimeGetCurrent()

for i in 0..<iterations {
    let ctx = sampleContexts[i % sampleContexts.count]
    let ch = chars[i % chars.count]
    _ = benchmarkAdapter.processKeystroke(ch, contextBefore: ctx)
}

let elapsed = CFAbsoluteTimeGetCurrent() - startTime
let timePerKeystrokeMs = (elapsed / Double(iterations)) * 1000.0
let timePerKeystrokeUs = timePerKeystrokeMs * 1000.0

print("  ⚡️ Đã gõ thử \(iterations) ký tự trong: \(String(format: "%.3f", elapsed)) giây")
print("  ⚡️ Thời gian trung bình mỗi ký tự: \(String(format: "%.4f", timePerKeystrokeMs)) ms (\(String(format: "%.1f", timePerKeystrokeUs)) microsecond)")
assertTest(timePerKeystrokeMs < 0.05, name: "Đạt chuẩn siêu tốc (< 0.05ms / ký tự)")

print("\n==================================================")
print("TỔNG KẾT: \(passedCount) passed, \(failedCount) failed")
print("==================================================")
if failedCount > 0 {
    exit(1)
}
