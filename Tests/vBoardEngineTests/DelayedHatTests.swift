import Testing
import Foundation
@testable import vBoardEngine

@Suite("Kiểm tra chuyên biệt các kiểu gõ trễ mũ và thanh (Delayed Hat & Tone)")
struct DelayedHatTests {
    private func typeString(_ str: String, adapter: OpenKeyEngineAdapter) -> String {
        adapter.reset()
        var buffer = ""
        for char in str {
            let action = adapter.processKeystroke(char, contextBefore: buffer)
            if action.deleteCount > 0 {
                let deleteCount = min(buffer.count, action.deleteCount)
                let startIndex = buffer.index(buffer.endIndex, offsetBy: -deleteCount)
                buffer.removeSubrange(startIndex..<buffer.endIndex)
            }
            buffer += action.textToInsert
        }
        return buffer
    }

    @Test("Kiểm tra motoj ra một và các trường hợp tương tự")
    func testDelayedHatCases() {
        let adapter = OpenKeyEngineAdapter()
        adapter.engine.vInputType = .telex

        let testCases: [(word: String, seq: String)] = [
            ("một", "motoj"),
            ("một", "motjo"),
            ("mốt", "motos"),
            ("mốt", "motso"),
            ("tiếng", "tienges"),
            ("tiếng", "tiengse"),
            ("việt", "vietej"),
            ("việt", "vietje"),
            ("cảnh", "canhr"),
            ("nắm", "namws"),
            ("nắm", "namsw"),
            ("hộc", "hocoj"),
            ("hộc", "hocjo"),
            ("bếp", "bepes"),
            ("bếp", "bepse"),
            ("công", "congo"),
            ("đông", "ddongo"),
            ("đường", "duowngdf"),
            ("được", "dduocwj"),
            ("được", "duowcdj")
        ]

        var failures: [String] = []
        for tc in testCases {
            let actual = typeString(tc.seq, adapter: adapter)
            if actual != tc.word {
                failures.append("Gõ '\(tc.seq)': kỳ vọng '\(tc.word)', thực tế ra '\(actual)'")
            }
        }

        if !failures.isEmpty {
            print("\n❌ THẤT BẠI DELAYED HAT:")
            for f in failures { print("  - \(f)") }
        }
        #expect(failures.isEmpty)
    }
}
