//
//  ComprehensiveDictionaryPermutationTests.swift
//  vBoardEngineTests
//
//  Bộ sinh Test Case tự động (Typing Test Suite Generator) và thực thi kiểm thử độ phủ toàn diện.
//

import Testing
import Foundation
@testable import vBoardEngine

// MARK: - Mô hình Test Case
public struct TypingTestCase: Sendable, Codable {
    public let expectedWord: String
    public let inputSequence: String
    public let inputMethod: String
    public let styleDescription: String
}

// MARK: - Báo cáo Kết quả Kiểm thử
public struct TypingTestReport: Sendable {
    public let totalCases: Int
    public let passedCases: Int
    public let failedCases: [(expected: String, input: String, actual: String, style: String)]

    public var passRate: Double {
        guard totalCases > 0 else { return 100.0 }
        return Double(passedCases) / Double(totalCases) * 100.0
    }
}

// MARK: - Công cụ Sinh Test Case Tự Động (Typing Test Suite Generator)
public struct TypingTestSuiteGenerator {

    /// Bỏ qua các từ mượn / từ tiếng nước ngoài có trong từ điển
    public static func isPureVietnameseWord(_ word: String) -> Bool {
        let lower = word.lowercased()
        if lower.contains("w") || lower.contains("f") || lower.contains("z") || lower.contains("j") {
            return false
        }
        // Kiểm tra nguyên âm phải có ít nhất 1 âm tiếng Việt
        let vietnameseChars = "aàáảãạăằắẳẵặâầấẩẫậeèéẻẽẹêềếểễệiìíỉĩịoòóỏõọôồốổỗộơờớởỡợuùúủũụưừứửữựyỳýỷỹỵdđ"
        for ch in lower {
            if !vietnameseChars.contains(ch) && !"bcdfghklmnpqrstvx".contains(ch) {
                return false
            }
        }
        return true
    }

    /// Sinh toàn bộ test cases cho một từ đơn
    public static func generateTestCases(for word: String) -> [TypingTestCase] {
        var cases: [TypingTestCase] = []
        let rawWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !rawWord.isEmpty, !rawWord.contains(" ") else { return [] }

        // 1. Tổ hợp Telex
        let telexPerms = KeystrokePermutationGenerator.generateTelexPermutations(for: rawWord)
        for (idx, seq) in telexPerms.enumerated() {
            let desc: String
            switch idx {
            case 0: desc = "Telex Chuẩn (Dấu thanh ở cuối từ)"
            case 1: desc = "Telex Dấu thanh ngay sau nguyên âm"
            case 2: desc = "Telex Biến thể móc kép uo (uwo/uwow)"
            case 3: desc = "Telex Đảo thứ tự Thanh trước Mũ sau"
            case 4: desc = "Telex Gõ trễ phím Đ ở cuối từ"
            case 5: desc = "Telex Gõ trễ Mũ/Móc sau phụ âm cuối (motoj -> một)"
            case 6: desc = "Telex Gõ trễ Mũ sau Dấu thanh (motjo -> một)"
            default: desc = "Telex Biến thể tổ hợp #\(idx + 1)"
            }
            cases.append(TypingTestCase(
                expectedWord: rawWord,
                inputSequence: seq,
                inputMethod: "telex",
                styleDescription: desc
            ))
        }

        // 2. Tổ hợp VNI
        let vniPerms = KeystrokePermutationGenerator.generateVNIPermutations(for: rawWord)
        for (idx, seq) in vniPerms.enumerated() {
            let desc = idx == 0 ? "VNI Chuẩn (Số thanh ở cuối từ)" : "VNI Số thanh ngay sau nguyên âm"
            cases.append(TypingTestCase(
                expectedWord: rawWord,
                inputSequence: seq,
                inputMethod: "vni",
                styleDescription: desc
            ))
        }

        return cases
    }

    /// Sinh bộ test case từ tệp từ điển vietnamese_words.txt
    public static func generateSuiteFromDictionary(limit: Int? = nil, onlyPureVietnamese: Bool = true) -> [TypingTestCase] {
        guard let url = Bundle.module.url(forResource: "vietnamese_words", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        let lines = content.components(separatedBy: .newlines)
        var testCases: [TypingTestCase] = []
        var processedCount = 0

        for line in lines {
            let parts = line.split(separator: ",")
            guard let first = parts.first else { continue }
            let rawWord = String(first).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !rawWord.isEmpty, !rawWord.contains(" ") else { continue }

            if onlyPureVietnamese && !isPureVietnameseWord(rawWord) {
                continue
            }

            let wordCases = generateTestCases(for: rawWord)
            testCases.append(contentsOf: wordCases)

            processedCount += 1
            if let maxLimit = limit, processedCount >= maxLimit {
                break
            }
        }

        return testCases
    }

    /// Xuất danh sách test cases ra định dạng JSON
    public static func exportToJSON(_ testCases: [TypingTestCase]) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(testCases) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Thực thi kiểm thử tự động một tập Test Case
    public static func executeSuite(_ testCases: [TypingTestCase]) -> TypingTestReport {
        let adapter = OpenKeyEngineAdapter()
        var passed = 0
        var failures: [(expected: String, input: String, actual: String, style: String)] = []

        for tc in testCases {
            adapter.engine.vInputType = (tc.inputMethod == "vni") ? .vni : .telex
            adapter.engine.vUseModernOrthography = 1
            adapter.reset()

            var buffer = ""
            for char in tc.inputSequence {
                let action = adapter.processKeystroke(char, contextBefore: buffer)
                if action.deleteCount > 0 {
                    let deleteCount = min(buffer.count, action.deleteCount)
                    let startIndex = buffer.index(buffer.endIndex, offsetBy: -deleteCount)
                    buffer.removeSubrange(startIndex..<buffer.endIndex)
                }
                buffer += action.textToInsert
            }

            if buffer == tc.expectedWord {
                passed += 1
            } else {
                // Thử chế độ chuẩn cũ (hoà/thuỷ) nếu từ chứa âm đệm oa/oe/uy
                adapter.engine.vUseModernOrthography = 0
                adapter.reset()
                var bufferAlt = ""
                for char in tc.inputSequence {
                    let action = adapter.processKeystroke(char, contextBefore: bufferAlt)
                    if action.deleteCount > 0 {
                        let deleteCount = min(bufferAlt.count, action.deleteCount)
                        let startIndex = bufferAlt.index(bufferAlt.endIndex, offsetBy: -deleteCount)
                        bufferAlt.removeSubrange(startIndex..<bufferAlt.endIndex)
                    }
                    bufferAlt += action.textToInsert
                }
                adapter.engine.vUseModernOrthography = 1

                if bufferAlt == tc.expectedWord {
                    passed += 1
                } else {
                    failures.append((expected: tc.expectedWord, input: tc.inputSequence, actual: buffer, style: tc.styleDescription))
                }
            }
        }

        return TypingTestReport(totalCases: testCases.count, passedCases: passed, failedCases: failures)
    }
}

// MARK: - Test Suite Thực Thi
@Suite("Bộ sinh và thực thi Test Case tự động (Typing Test Suite Generator & Runner)")
struct ComprehensiveDictionaryPermutationTests {

    @Test("Kiểm tra khả năng sinh Test Case tự động và xuất JSON")
    func testGeneratorAndJSONExport() {
        let sampleCases = TypingTestSuiteGenerator.generateTestCases(for: "thương")
        #expect(sampleCases.count >= 4, "Từ 'thương' phải sinh được ít nhất 4 kịch bản gõ Telex + VNI")

        let json = TypingTestSuiteGenerator.exportToJSON(sampleCases)
        #expect(json != nil && !json!.isEmpty, "Phải xuất được test case sang chuỗi JSON")
    }

    @Test("Sinh và chạy tự động bộ test case trên 500 từ cao tần thuần Việt (~2000 kịch bản)")
    func testExecuteGeneratedSuiteOnHighFrequencyDictionary() {
        let testCases = TypingTestSuiteGenerator.generateSuiteFromDictionary(limit: 500, onlyPureVietnamese: true)
        #expect(!testCases.isEmpty, "Không được để trống bộ test case sinh từ từ điển")

        let report = TypingTestSuiteGenerator.executeSuite(testCases)

        print("\n=======================================================")
        print("📊 BÁO CÁO KIỂM THỬ BỘ TEST CASE TỰ ĐỘNG SINH:")
        print("  - Tổng số kịch bản gõ sinh ra: \(report.totalCases) test cases")
        print("  - Số ca vượt qua (Pass): \(report.passedCases)")
        print("  - Số ca thất bại (Fail): \(report.failedCases.count)")
        print("  - Tỷ lệ chính xác: \(String(format: "%.2f", report.passRate))%")
        print("=======================================================")

        if !report.failedCases.isEmpty {
            print("\n❌ CÁC TRƯỜNG HỢP GÕ BỊ SAI:")
            for f in report.failedCases.prefix(15) {
                print("  - Từ '\(f.expected)' [\(f.style)]: Gõ '\(f.input)' ra '\(f.actual)'")
            }
        }

        #expect(report.failedCases.isEmpty, "Toàn bộ 500 từ cốt lõi với mọi tổ hợp gõ phải đạt 100% Pass!")
    }
}
