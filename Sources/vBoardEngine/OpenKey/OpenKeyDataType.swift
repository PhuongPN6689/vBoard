//
//  OpenKeyDataType.swift
//  vBoardEngine
//
//  Chuyển đổi 1-1 từ DataType.h và mac.h của OpenKey (tác giả Mai Vũ Tuyên).
//

import Foundation

public let MAX_BUFF: Int = 32

public enum OpenKeyEvent: Sendable {
    case keyboard
    case mouse
}

public enum OpenKeyEventState: Sendable {
    case keyDown
    case keyUp
    case mouseDown
    case mouseUp
}

public enum OpenKeyInputType: Int, Sendable {
    case telex = 0
    case vni = 1
    case simpleTelex1 = 2
    case simpleTelex2 = 3
}

public enum HookCodeState: UInt8, Sendable {
    case vDoNothing = 0                   // Không làm gì
    case vWillProcess = 1                 // Có xử lý thay đổi ký tự
    case vBreakWord = 2                   // Ngắt từ
    case vRestore = 3                     // Hoàn tác ký tự về dạng ban đầu
    case vReplaceMaro = 4                 // Thay thế bằng gõ tắt (Macro)
    case vRestoreAndStartNewSession = 5   // Hoàn tác từ và bắt đầu từ mới
}

public struct OpenKeyHookState: Sendable {
    public var code: HookCodeState = .vDoNothing
    public var backspaceCount: UInt8 = 0
    public var newCharCount: UInt8 = 0
    public var extCode: UInt8 = 0
    public var charData: [UInt32] = Array(repeating: 0, count: MAX_BUFF)
    public var macroKey: [UInt32] = []
    public var macroData: [UInt32] = []

    public init() {}
}

// MARK: - Mã Bitmask nội bộ của OpenKey Engine
public enum OpenKeyMask {
    public static let caps: UInt32                = 0x10000
    public static let tone: UInt32                = 0x20000   // ^, đ
    public static let toneW: UInt32               = 0x40000   // ă, ơ, ư

    // Dấu thanh (Mark)
    public static let mark1: UInt32               = 0x80000   // Dấu Sắc (á)
    public static let mark2: UInt32               = 0x100000  // Dấu Huyền (à)
    public static let mark3: UInt32               = 0x200000  // Dấu Hỏi (ả)
    public static let mark4: UInt32               = 0x400000  // Dấu Ngã (ã)
    public static let mark5: UInt32               = 0x800000  // Dấu Nặng (ạ)
    public static let mark: UInt32                = 0xF80000  // Mặt nạ kiểm tra có dấu thanh

    public static let charMask: UInt32            = 0xFFFF    // Mặt nạ lấy 16-bit mã ký tự/keycode gốc
    public static let standalone: UInt32          = 0x1000000 // Ký tự độc lập (W)
    public static let charCode: UInt32            = 0x2000000 // Đánh dấu là mã ký tự Unicode thực tế
    public static let pureCharacter: UInt32       = 0x80000000

    public static let endConsonant: UInt16        = 0x4000    // Tính năng phụ âm cuối
    public static let consonantAllow: UInt16      = 0x8000    // Phụ âm Z, F, W, J được phép
}

// MARK: - Keycodes chuẩn macOS được OpenKey sử dụng
public enum OpenKeyCode {
    public static let esc: UInt16                 = 53
    public static let delete: UInt16              = 51
    public static let tab: UInt16                 = 48
    public static let enter: UInt16               = 76
    public static let `return`: UInt16            = 36
    public static let space: UInt16               = 49
    public static let left: UInt16                = 123
    public static let right: UInt16               = 124
    public static let down: UInt16                = 125
    public static let up: UInt16                  = 126

    public static let empty: UInt16               = 256
    public static let a: UInt16                   = 0
    public static let b: UInt16                   = 11
    public static let c: UInt16                   = 8
    public static let d: UInt16                   = 2
    public static let e: UInt16                   = 14
    public static let f: UInt16                   = 3
    public static let g: UInt16                   = 5
    public static let h: UInt16                   = 4
    public static let i: UInt16                   = 34
    public static let j: UInt16                   = 38
    public static let k: UInt16                   = 40
    public static let l: UInt16                   = 37
    public static let m: UInt16                   = 46
    public static let n: UInt16                   = 45
    public static let o: UInt16                   = 31
    public static let p: UInt16                   = 35
    public static let q: UInt16                   = 12
    public static let r: UInt16                   = 15
    public static let s: UInt16                   = 1
    public static let t: UInt16                   = 17
    public static let u: UInt16                   = 32
    public static let v: UInt16                   = 9
    public static let w: UInt16                   = 13
    public static let x: UInt16                   = 7
    public static let y: UInt16                   = 16
    public static let z: UInt16                   = 6

    public static let num1: UInt16                = 18
    public static let num2: UInt16                = 19
    public static let num3: UInt16                = 20
    public static let num4: UInt16                = 21
    public static let num5: UInt16                = 23
    public static let num6: UInt16                = 22
    public static let num7: UInt16                = 26
    public static let num8: UInt16                = 28
    public static let num9: UInt16                = 25
    public static let num0: UInt16                = 29

    public static let leftBracket: UInt16         = 33   // [
    public static let rightBracket: UInt16        = 30   // ]
    public static let dot: UInt16                 = 47   // .
    public static let backquote: UInt16           = 50   // `
    public static let minus: UInt16               = 27   // -
    public static let equals: UInt16              = 24   // =
    public static let backslash: UInt16           = 42   // \
    public static let semicolon: UInt16           = 41   // ;
    public static let quote: UInt16               = 39   // '
    public static let comma: UInt16               = 43   // ,
    public static let slash: UInt16               = 44   // /

    @inline(__always)
    public static func isConsonant(_ code: UInt16) -> Bool {
        return !(code == a || code == e || code == u || code == y || code == i || code == o)
    }

    @inline(__always)
    public static func isNumberKey(_ code: UInt16) -> Bool {
        return code == num1 || code == num2 || code == num3 || code == num4 || code == num5 ||
               code == num6 || code == num7 || code == num8 || code == num9 || code == num0
    }
}
