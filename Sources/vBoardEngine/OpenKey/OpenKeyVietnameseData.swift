//
//  OpenKeyVietnameseData.swift
//  vBoardEngine
//
//  Chuyển đổi 1-1 từ Vietnamese.h và Vietnamese.cpp của OpenKey (tác giả Mai Vũ Tuyên).
//

import Foundation

public enum OpenKeyVietnameseData {

    // MARK: - Double Key (aa -> â, ee -> ê)
    public static let douKey: [[UInt16]] = [
        [OpenKeyCode.a, 0x00E2], // a -> â
        [OpenKeyCode.e, 0x00EA]  // e -> ê
    ]

    // MARK: - Vowel Endings
    public static let vowel: [UInt16: [[UInt16]]] = [
        OpenKeyCode.a: [
            [OpenKeyCode.a, OpenKeyCode.n, OpenKeyCode.g],
            [OpenKeyCode.a, OpenKeyCode.g | OpenKeyMask.endConsonant],
            [OpenKeyCode.a, OpenKeyCode.n],
            [OpenKeyCode.a, OpenKeyCode.m],
            [OpenKeyCode.a, OpenKeyCode.u],
            [OpenKeyCode.a, OpenKeyCode.y],
            [OpenKeyCode.a, OpenKeyCode.t],
            [OpenKeyCode.a, OpenKeyCode.p],
            [OpenKeyCode.a],
            [OpenKeyCode.a, OpenKeyCode.c]
        ],
        OpenKeyCode.o: [
            [OpenKeyCode.o, OpenKeyCode.n, OpenKeyCode.g],
            [OpenKeyCode.o, OpenKeyCode.g | OpenKeyMask.endConsonant],
            [OpenKeyCode.o, OpenKeyCode.n],
            [OpenKeyCode.o, OpenKeyCode.m],
            [OpenKeyCode.o, OpenKeyCode.i],
            [OpenKeyCode.o, OpenKeyCode.c],
            [OpenKeyCode.o, OpenKeyCode.t],
            [OpenKeyCode.o, OpenKeyCode.p],
            [OpenKeyCode.o]
        ],
        OpenKeyCode.e: [
            [OpenKeyCode.e, OpenKeyCode.n, OpenKeyCode.h],
            [OpenKeyCode.e, OpenKeyCode.h | OpenKeyMask.endConsonant],
            [OpenKeyCode.e, OpenKeyCode.n, OpenKeyCode.g],
            [OpenKeyCode.e, OpenKeyCode.g | OpenKeyMask.endConsonant],
            [OpenKeyCode.e, OpenKeyCode.c, OpenKeyCode.h],
            [OpenKeyCode.e, OpenKeyCode.k | OpenKeyMask.endConsonant],
            [OpenKeyCode.e, OpenKeyCode.c],
            [OpenKeyCode.e, OpenKeyCode.t],
            [OpenKeyCode.e, OpenKeyCode.y],
            [OpenKeyCode.e, OpenKeyCode.u],
            [OpenKeyCode.e, OpenKeyCode.p],
            [OpenKeyCode.e, OpenKeyCode.c],
            [OpenKeyCode.e, OpenKeyCode.n],
            [OpenKeyCode.e, OpenKeyCode.m],
            [OpenKeyCode.e]
        ],
        OpenKeyCode.w: [
            [OpenKeyCode.o, OpenKeyCode.n],
            [OpenKeyCode.u, OpenKeyCode.o, OpenKeyCode.n, OpenKeyCode.g],
            [OpenKeyCode.u, OpenKeyCode.o, OpenKeyCode.g | OpenKeyMask.endConsonant],
            [OpenKeyCode.u, OpenKeyCode.o, OpenKeyCode.n],
            [OpenKeyCode.u, OpenKeyCode.o, OpenKeyCode.i],
            [OpenKeyCode.u, OpenKeyCode.o, OpenKeyCode.c],
            [OpenKeyCode.o, OpenKeyCode.i],
            [OpenKeyCode.o, OpenKeyCode.p],
            [OpenKeyCode.o, OpenKeyCode.m],
            [OpenKeyCode.o, OpenKeyCode.a],
            [OpenKeyCode.o, OpenKeyCode.t],
            [OpenKeyCode.u, OpenKeyCode.n, OpenKeyCode.g],
            [OpenKeyCode.u, OpenKeyCode.g | OpenKeyMask.endConsonant],
            [OpenKeyCode.a, OpenKeyCode.n, OpenKeyCode.g],
            [OpenKeyCode.a, OpenKeyCode.g | OpenKeyMask.endConsonant],
            [OpenKeyCode.u, OpenKeyCode.n],
            [OpenKeyCode.u, OpenKeyCode.m],
            [OpenKeyCode.u, OpenKeyCode.c],
            [OpenKeyCode.u, OpenKeyCode.a],
            [OpenKeyCode.u, OpenKeyCode.i],
            [OpenKeyCode.u, OpenKeyCode.t],
            [OpenKeyCode.u],
            [OpenKeyCode.a, OpenKeyCode.p],
            [OpenKeyCode.a, OpenKeyCode.t],
            [OpenKeyCode.a, OpenKeyCode.m],
            [OpenKeyCode.a, OpenKeyCode.n],
            [OpenKeyCode.a],
            [OpenKeyCode.a, OpenKeyCode.c],
            [OpenKeyCode.a, OpenKeyCode.c, OpenKeyCode.h],
            [OpenKeyCode.a, OpenKeyCode.k | OpenKeyMask.endConsonant],
            [OpenKeyCode.o],
            [OpenKeyCode.u, OpenKeyCode.u]
        ]
    ]

    // MARK: - Combined Vowels (Phần tử đầu tiên: 0: không có phụ âm cuối, 1: được có phụ âm cuối)
    public static let vowelCombine: [UInt16: [[UInt32]]] = [
        OpenKeyCode.a: [
            [0, UInt32(OpenKeyCode.a), UInt32(OpenKeyCode.i)],
            [0, UInt32(OpenKeyCode.a), UInt32(OpenKeyCode.o)],
            [0, UInt32(OpenKeyCode.a), UInt32(OpenKeyCode.u)],
            [0, UInt32(OpenKeyCode.a) | OpenKeyMask.tone, UInt32(OpenKeyCode.u)],
            [0, UInt32(OpenKeyCode.a), UInt32(OpenKeyCode.y)],
            [0, UInt32(OpenKeyCode.a) | OpenKeyMask.tone, UInt32(OpenKeyCode.y)],
        ],
        OpenKeyCode.e: [
            [0, UInt32(OpenKeyCode.e), UInt32(OpenKeyCode.o)],
            [0, UInt32(OpenKeyCode.e) | OpenKeyMask.tone, UInt32(OpenKeyCode.u)],
        ],
        OpenKeyCode.i: [
            [1, UInt32(OpenKeyCode.i), UInt32(OpenKeyCode.e) | OpenKeyMask.tone, UInt32(OpenKeyCode.u)],
            [0, UInt32(OpenKeyCode.i), UInt32(OpenKeyCode.a)],
            [1, UInt32(OpenKeyCode.i), UInt32(OpenKeyCode.e) | OpenKeyMask.tone],
            [0, UInt32(OpenKeyCode.i), UInt32(OpenKeyCode.u)],
        ],
        OpenKeyCode.o: [
            [0, UInt32(OpenKeyCode.o), UInt32(OpenKeyCode.a), UInt32(OpenKeyCode.i)],
            [0, UInt32(OpenKeyCode.o), UInt32(OpenKeyCode.a), UInt32(OpenKeyCode.o)],
            [0, UInt32(OpenKeyCode.o), UInt32(OpenKeyCode.a), UInt32(OpenKeyCode.y)],
            [0, UInt32(OpenKeyCode.o), UInt32(OpenKeyCode.e), UInt32(OpenKeyCode.o)],
            [1, UInt32(OpenKeyCode.o), UInt32(OpenKeyCode.a)],
            [1, UInt32(OpenKeyCode.o), UInt32(OpenKeyCode.a) | OpenKeyMask.toneW],
            [1, UInt32(OpenKeyCode.o), UInt32(OpenKeyCode.e)],
            [0, UInt32(OpenKeyCode.o), UInt32(OpenKeyCode.i)],
            [0, UInt32(OpenKeyCode.o) | OpenKeyMask.tone, UInt32(OpenKeyCode.i)],
            [0, UInt32(OpenKeyCode.o) | OpenKeyMask.toneW, UInt32(OpenKeyCode.i)],
            [1, UInt32(OpenKeyCode.o), UInt32(OpenKeyCode.o)],
            [1, UInt32(OpenKeyCode.o) | OpenKeyMask.tone, UInt32(OpenKeyCode.o) | OpenKeyMask.tone],
        ],
        OpenKeyCode.u: [
            [0, UInt32(OpenKeyCode.u), UInt32(OpenKeyCode.y), UInt32(OpenKeyCode.u)],
            [1, UInt32(OpenKeyCode.u), UInt32(OpenKeyCode.y), UInt32(OpenKeyCode.e) | OpenKeyMask.tone],
            [0, UInt32(OpenKeyCode.u), UInt32(OpenKeyCode.y), UInt32(OpenKeyCode.a)],
            [0, UInt32(OpenKeyCode.u) | OpenKeyMask.toneW, UInt32(OpenKeyCode.o) | OpenKeyMask.toneW, UInt32(OpenKeyCode.u)],
            [0, UInt32(OpenKeyCode.u) | OpenKeyMask.toneW, UInt32(OpenKeyCode.o) | OpenKeyMask.toneW, UInt32(OpenKeyCode.i)],
            [0, UInt32(OpenKeyCode.u), UInt32(OpenKeyCode.o) | OpenKeyMask.tone, UInt32(OpenKeyCode.i)],
            [0, UInt32(OpenKeyCode.u), UInt32(OpenKeyCode.a) | OpenKeyMask.tone, UInt32(OpenKeyCode.y)],
            [1, UInt32(OpenKeyCode.u), UInt32(OpenKeyCode.a), UInt32(OpenKeyCode.o)],
            [1, UInt32(OpenKeyCode.u), UInt32(OpenKeyCode.a)],
            [1, UInt32(OpenKeyCode.u), UInt32(OpenKeyCode.a) | OpenKeyMask.toneW],
            [1, UInt32(OpenKeyCode.u), UInt32(OpenKeyCode.a) | OpenKeyMask.tone],
            [0, UInt32(OpenKeyCode.u) | OpenKeyMask.toneW, UInt32(OpenKeyCode.a)],
            [1, UInt32(OpenKeyCode.u), UInt32(OpenKeyCode.e) | OpenKeyMask.tone],
            [0, UInt32(OpenKeyCode.u), UInt32(OpenKeyCode.i)],
            [0, UInt32(OpenKeyCode.u) | OpenKeyMask.toneW, UInt32(OpenKeyCode.i)],
            [1, UInt32(OpenKeyCode.u), UInt32(OpenKeyCode.o)],
            [1, UInt32(OpenKeyCode.u), UInt32(OpenKeyCode.o) | OpenKeyMask.tone],
            [0, UInt32(OpenKeyCode.u), UInt32(OpenKeyCode.o) | OpenKeyMask.toneW],
            [1, UInt32(OpenKeyCode.u) | OpenKeyMask.toneW, UInt32(OpenKeyCode.o) | OpenKeyMask.toneW],
            [0, UInt32(OpenKeyCode.u) | OpenKeyMask.toneW, UInt32(OpenKeyCode.u)],
            [1, UInt32(OpenKeyCode.u), UInt32(OpenKeyCode.y)],
        ],
        OpenKeyCode.y: [
            [0, UInt32(OpenKeyCode.y), UInt32(OpenKeyCode.e) | OpenKeyMask.tone, UInt32(OpenKeyCode.u)],
            [1, UInt32(OpenKeyCode.y), UInt32(OpenKeyCode.e) | OpenKeyMask.tone],
        ]
    ]

    // MARK: - Consonant D Table (Từ hợp lệ bắt đầu bằng D/Đ)
    public static let consonantD: [[UInt16]] = [
        [OpenKeyCode.d, OpenKeyCode.e, OpenKeyCode.n, OpenKeyCode.h],
        [OpenKeyCode.d, OpenKeyCode.e, OpenKeyCode.h | OpenKeyMask.endConsonant],
        [OpenKeyCode.d, OpenKeyCode.e, OpenKeyCode.n, OpenKeyCode.g],
        [OpenKeyCode.d, OpenKeyCode.e, OpenKeyCode.g | OpenKeyMask.endConsonant],
        [OpenKeyCode.d, OpenKeyCode.e, OpenKeyCode.c, OpenKeyCode.h],
        [OpenKeyCode.d, OpenKeyCode.e, OpenKeyCode.k | OpenKeyMask.endConsonant],
        [OpenKeyCode.d, OpenKeyCode.e, OpenKeyCode.n],
        [OpenKeyCode.d, OpenKeyCode.e, OpenKeyCode.c],
        [OpenKeyCode.d, OpenKeyCode.e, OpenKeyCode.m],
        [OpenKeyCode.d, OpenKeyCode.e],
        [OpenKeyCode.d, OpenKeyCode.e, OpenKeyCode.t],
        [OpenKeyCode.d, OpenKeyCode.e, OpenKeyCode.u],
        [OpenKeyCode.d, OpenKeyCode.e, OpenKeyCode.o],
        [OpenKeyCode.d, OpenKeyCode.e, OpenKeyCode.p],

        [OpenKeyCode.d, OpenKeyCode.u, OpenKeyCode.n, OpenKeyCode.g],
        [OpenKeyCode.d, OpenKeyCode.u, OpenKeyCode.g | OpenKeyMask.endConsonant],
        [OpenKeyCode.d, OpenKeyCode.u, OpenKeyCode.n],
        [OpenKeyCode.d, OpenKeyCode.u, OpenKeyCode.m],
        [OpenKeyCode.d, OpenKeyCode.u, OpenKeyCode.c],
        [OpenKeyCode.d, OpenKeyCode.u, OpenKeyCode.o],
        [OpenKeyCode.d, OpenKeyCode.u, OpenKeyCode.a],
        [OpenKeyCode.d, OpenKeyCode.u, OpenKeyCode.o, OpenKeyCode.i],
        [OpenKeyCode.d, OpenKeyCode.u, OpenKeyCode.o, OpenKeyCode.c],
        [OpenKeyCode.d, OpenKeyCode.u, OpenKeyCode.o, OpenKeyCode.n],
        [OpenKeyCode.d, OpenKeyCode.u, OpenKeyCode.o, OpenKeyCode.n, OpenKeyCode.g],
        [OpenKeyCode.d, OpenKeyCode.u, OpenKeyCode.o, OpenKeyCode.g | OpenKeyMask.endConsonant],
        [OpenKeyCode.d, OpenKeyCode.u],
        [OpenKeyCode.d, OpenKeyCode.u, OpenKeyCode.p],
        [OpenKeyCode.d, OpenKeyCode.u, OpenKeyCode.t],
        [OpenKeyCode.d, OpenKeyCode.u, OpenKeyCode.i],
        [OpenKeyCode.d, OpenKeyCode.u, OpenKeyCode.y],
        [OpenKeyCode.d, OpenKeyCode.u, OpenKeyCode.o, OpenKeyCode.m],

        [OpenKeyCode.d, OpenKeyCode.i, OpenKeyCode.c, OpenKeyCode.h],
        [OpenKeyCode.d, OpenKeyCode.i, OpenKeyCode.k | OpenKeyMask.endConsonant],
        [OpenKeyCode.d, OpenKeyCode.i, OpenKeyCode.c],
        [OpenKeyCode.d, OpenKeyCode.i, OpenKeyCode.n, OpenKeyCode.h],
        [OpenKeyCode.d, OpenKeyCode.i, OpenKeyCode.h | OpenKeyMask.endConsonant],
        [OpenKeyCode.d, OpenKeyCode.i, OpenKeyCode.n],
        [OpenKeyCode.d, OpenKeyCode.i],
        [OpenKeyCode.d, OpenKeyCode.i, OpenKeyCode.u],
        [OpenKeyCode.d, OpenKeyCode.i, OpenKeyCode.a],
        [OpenKeyCode.d, OpenKeyCode.i, OpenKeyCode.e],
        [OpenKeyCode.d, OpenKeyCode.i, OpenKeyCode.e, OpenKeyCode.c],
        [OpenKeyCode.d, OpenKeyCode.i, OpenKeyCode.e, OpenKeyCode.u],
        [OpenKeyCode.d, OpenKeyCode.i, OpenKeyCode.e, OpenKeyCode.n],
        [OpenKeyCode.d, OpenKeyCode.i, OpenKeyCode.e, OpenKeyCode.n, OpenKeyCode.g],
        [OpenKeyCode.d, OpenKeyCode.i, OpenKeyCode.e, OpenKeyCode.g | OpenKeyMask.endConsonant],
        [OpenKeyCode.d, OpenKeyCode.i, OpenKeyCode.e, OpenKeyCode.m],
        [OpenKeyCode.d, OpenKeyCode.i, OpenKeyCode.e, OpenKeyCode.p],
        [OpenKeyCode.d, OpenKeyCode.i, OpenKeyCode.t],

        [OpenKeyCode.d, OpenKeyCode.o],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.a],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.a, OpenKeyCode.n],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.a, OpenKeyCode.n, OpenKeyCode.g],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.a, OpenKeyCode.g | OpenKeyMask.endConsonant],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.a, OpenKeyCode.n, OpenKeyCode.h],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.a, OpenKeyCode.h | OpenKeyMask.endConsonant],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.a, OpenKeyCode.m],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.a, OpenKeyCode.t],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.a, OpenKeyCode.c],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.a, OpenKeyCode.i],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.e],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.i],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.p],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.c],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.n],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.n, OpenKeyCode.g],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.g | OpenKeyMask.endConsonant],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.m],
        [OpenKeyCode.d, OpenKeyCode.o, OpenKeyCode.t],

        [OpenKeyCode.d, OpenKeyCode.a],
        [OpenKeyCode.d, OpenKeyCode.a, OpenKeyCode.t],
        [OpenKeyCode.d, OpenKeyCode.a, OpenKeyCode.y],
        [OpenKeyCode.d, OpenKeyCode.a, OpenKeyCode.u],
        [OpenKeyCode.d, OpenKeyCode.a, OpenKeyCode.i],
        [OpenKeyCode.d, OpenKeyCode.a, OpenKeyCode.o],
        [OpenKeyCode.d, OpenKeyCode.a, OpenKeyCode.p],
        [OpenKeyCode.d, OpenKeyCode.a, OpenKeyCode.c],
        [OpenKeyCode.d, OpenKeyCode.a, OpenKeyCode.c, OpenKeyCode.h],
        [OpenKeyCode.d, OpenKeyCode.a, OpenKeyCode.k | OpenKeyMask.endConsonant],
        [OpenKeyCode.d, OpenKeyCode.a, OpenKeyCode.n],
        [OpenKeyCode.d, OpenKeyCode.a, OpenKeyCode.n, OpenKeyCode.h],
        [OpenKeyCode.d, OpenKeyCode.a, OpenKeyCode.h | OpenKeyMask.endConsonant],
        [OpenKeyCode.d, OpenKeyCode.a, OpenKeyCode.n, OpenKeyCode.g],
        [OpenKeyCode.d, OpenKeyCode.a, OpenKeyCode.g | OpenKeyMask.endConsonant],
        [OpenKeyCode.d, OpenKeyCode.a, OpenKeyCode.m],

        [OpenKeyCode.d]
    ]

    // MARK: - Vowel For Mark (Điều kiện bỏ dấu thanh)
    public static let vowelForMark: [UInt16: [[UInt16]]] = [
        OpenKeyCode.a: [
            [OpenKeyCode.a, OpenKeyCode.n, OpenKeyCode.g],
            [OpenKeyCode.a, OpenKeyCode.g | OpenKeyMask.endConsonant],
            [OpenKeyCode.a, OpenKeyCode.n],
            [OpenKeyCode.a, OpenKeyCode.n, OpenKeyCode.h],
            [OpenKeyCode.a, OpenKeyCode.h | OpenKeyMask.endConsonant],
            [OpenKeyCode.a, OpenKeyCode.m],
            [OpenKeyCode.a, OpenKeyCode.u],
            [OpenKeyCode.a, OpenKeyCode.y],
            [OpenKeyCode.a, OpenKeyCode.t],
            [OpenKeyCode.a, OpenKeyCode.p],
            [OpenKeyCode.a],
            [OpenKeyCode.a, OpenKeyCode.c],
            [OpenKeyCode.a, OpenKeyCode.i],
            [OpenKeyCode.a, OpenKeyCode.o],
            [OpenKeyCode.a, OpenKeyCode.c, OpenKeyCode.h],
            [OpenKeyCode.a, OpenKeyCode.k | OpenKeyMask.endConsonant],
        ],
        OpenKeyCode.o: [
            [OpenKeyCode.o, OpenKeyCode.o, OpenKeyCode.n, OpenKeyCode.g],
            [OpenKeyCode.o, OpenKeyCode.o, OpenKeyCode.g | OpenKeyMask.endConsonant],
            [OpenKeyCode.o, OpenKeyCode.n, OpenKeyCode.g],
            [OpenKeyCode.o, OpenKeyCode.g | OpenKeyMask.endConsonant],
            [OpenKeyCode.o, OpenKeyCode.o, OpenKeyCode.n],
            [OpenKeyCode.o, OpenKeyCode.o, OpenKeyCode.c],
            [OpenKeyCode.o, OpenKeyCode.o],
            [OpenKeyCode.o, OpenKeyCode.n],
            [OpenKeyCode.o, OpenKeyCode.m],
            [OpenKeyCode.o, OpenKeyCode.i],
            [OpenKeyCode.o, OpenKeyCode.c],
            [OpenKeyCode.o, OpenKeyCode.t],
            [OpenKeyCode.o, OpenKeyCode.p],
            [OpenKeyCode.o]
        ],
        OpenKeyCode.e: [
            [OpenKeyCode.e, OpenKeyCode.n, OpenKeyCode.h],
            [OpenKeyCode.e, OpenKeyCode.h | OpenKeyMask.endConsonant],
            [OpenKeyCode.e, OpenKeyCode.n, OpenKeyCode.g],
            [OpenKeyCode.e, OpenKeyCode.g | OpenKeyMask.endConsonant],
            [OpenKeyCode.e, OpenKeyCode.c, OpenKeyCode.h],
            [OpenKeyCode.e, OpenKeyCode.k | OpenKeyMask.endConsonant],
            [OpenKeyCode.e, OpenKeyCode.c],
            [OpenKeyCode.e, OpenKeyCode.t],
            [OpenKeyCode.e, OpenKeyCode.y],
            [OpenKeyCode.e, OpenKeyCode.u],
            [OpenKeyCode.e, OpenKeyCode.p],
            [OpenKeyCode.e, OpenKeyCode.c],
            [OpenKeyCode.e, OpenKeyCode.n],
            [OpenKeyCode.e, OpenKeyCode.m],
            [OpenKeyCode.e]
        ],
        OpenKeyCode.i: [
            [OpenKeyCode.i, OpenKeyCode.n, OpenKeyCode.h],
            [OpenKeyCode.i, OpenKeyCode.h | OpenKeyMask.endConsonant],
            [OpenKeyCode.i, OpenKeyCode.c, OpenKeyCode.h],
            [OpenKeyCode.i, OpenKeyCode.k | OpenKeyMask.endConsonant],
            [OpenKeyCode.i, OpenKeyCode.n],
            [OpenKeyCode.i, OpenKeyCode.t],
            [OpenKeyCode.i, OpenKeyCode.u],
            [OpenKeyCode.i, OpenKeyCode.u, OpenKeyCode.p],
            [OpenKeyCode.i, OpenKeyCode.n],
            [OpenKeyCode.i, OpenKeyCode.m],
            [OpenKeyCode.i, OpenKeyCode.p],
            [OpenKeyCode.i, OpenKeyCode.a],
            [OpenKeyCode.i, OpenKeyCode.c],
            [OpenKeyCode.i],
        ],
        OpenKeyCode.u: [
            [OpenKeyCode.u, OpenKeyCode.n, OpenKeyCode.g],
            [OpenKeyCode.u, OpenKeyCode.g | OpenKeyMask.endConsonant],
            [OpenKeyCode.u, OpenKeyCode.i],
            [OpenKeyCode.u, OpenKeyCode.o],
            [OpenKeyCode.u, OpenKeyCode.y],
            [OpenKeyCode.u, OpenKeyCode.y, OpenKeyCode.n],
            [OpenKeyCode.u, OpenKeyCode.y, OpenKeyCode.t],
            [OpenKeyCode.u, OpenKeyCode.y, OpenKeyCode.p],
            [OpenKeyCode.u, OpenKeyCode.y, OpenKeyCode.c, OpenKeyCode.h],
            [OpenKeyCode.u, OpenKeyCode.y, OpenKeyCode.k | OpenKeyMask.endConsonant],
            [OpenKeyCode.u, OpenKeyCode.y, OpenKeyCode.n, OpenKeyCode.h],
            [OpenKeyCode.u, OpenKeyCode.y, OpenKeyCode.h | OpenKeyMask.endConsonant],
            [OpenKeyCode.u, OpenKeyCode.t],
            [OpenKeyCode.u, OpenKeyCode.u],
            [OpenKeyCode.u, OpenKeyCode.a],
            [OpenKeyCode.u, OpenKeyCode.i],
            [OpenKeyCode.u, OpenKeyCode.c],
            [OpenKeyCode.u, OpenKeyCode.n],
            [OpenKeyCode.u, OpenKeyCode.m],
            [OpenKeyCode.u, OpenKeyCode.p],
            [OpenKeyCode.u]
        ],
        OpenKeyCode.y: [
            [OpenKeyCode.y]
        ]
    ]

    // MARK: - Starting Consonants (33 phụ âm đầu hợp lệ)
    public static let consonantTable: [[UInt16]] = [
        [OpenKeyCode.n, OpenKeyCode.g, OpenKeyCode.h],
        [OpenKeyCode.p, OpenKeyCode.h],
        [OpenKeyCode.t, OpenKeyCode.h],
        [OpenKeyCode.t, OpenKeyCode.r],
        [OpenKeyCode.g, OpenKeyCode.i],
        [OpenKeyCode.c, OpenKeyCode.h],
        [OpenKeyCode.n, OpenKeyCode.h],
        [OpenKeyCode.n, OpenKeyCode.g],
        [OpenKeyCode.k, OpenKeyCode.h],
        [OpenKeyCode.g, OpenKeyCode.h],
        [OpenKeyCode.g],
        [OpenKeyCode.c],
        [OpenKeyCode.q],
        [OpenKeyCode.k],
        [OpenKeyCode.t],
        [OpenKeyCode.r],
        [OpenKeyCode.h],
        [OpenKeyCode.b],
        [OpenKeyCode.m],
        [OpenKeyCode.v],
        [OpenKeyCode.n],
        [OpenKeyCode.l],
        [OpenKeyCode.x],
        [OpenKeyCode.p],
        [OpenKeyCode.s],
        [OpenKeyCode.d],
        [OpenKeyCode.f | OpenKeyMask.consonantAllow],
        [OpenKeyCode.w | OpenKeyMask.consonantAllow],
        [OpenKeyCode.z | OpenKeyMask.consonantAllow],
        [OpenKeyCode.j | OpenKeyMask.consonantAllow],
        [OpenKeyCode.f | OpenKeyMask.endConsonant],
        [OpenKeyCode.w | OpenKeyMask.endConsonant],
        [OpenKeyCode.j | OpenKeyMask.endConsonant],
    ]

    // MARK: - Ending Consonants (Phụ âm cuối hợp lệ)
    public static let endConsonantTable: [[UInt16]] = [
        [OpenKeyCode.t], [OpenKeyCode.p], [OpenKeyCode.c], [OpenKeyCode.n], [OpenKeyCode.m],
        [OpenKeyCode.g | OpenKeyMask.endConsonant],
        [OpenKeyCode.k | OpenKeyMask.endConsonant],
        [OpenKeyCode.h | OpenKeyMask.endConsonant],
        [OpenKeyCode.c, OpenKeyCode.h],
        [OpenKeyCode.n, OpenKeyCode.h],
        [OpenKeyCode.n, OpenKeyCode.g],
    ]

    public static let standaloneWbad: [UInt16] = [
        OpenKeyCode.w, OpenKeyCode.e, OpenKeyCode.y, OpenKeyCode.f, OpenKeyCode.j, OpenKeyCode.k, OpenKeyCode.z
    ]

    public static let doubleWAllowed: [[UInt16]] = [
        [OpenKeyCode.t, OpenKeyCode.r],
        [OpenKeyCode.t, OpenKeyCode.h],
        [OpenKeyCode.c, OpenKeyCode.h],
        [OpenKeyCode.n, OpenKeyCode.h],
        [OpenKeyCode.n, OpenKeyCode.g],
        [OpenKeyCode.k, OpenKeyCode.h],
        [OpenKeyCode.g, OpenKeyCode.i],
        [OpenKeyCode.p, OpenKeyCode.h],
        [OpenKeyCode.g, OpenKeyCode.h],
    ]

    // MARK: - Quick Consonants
    public static let quickStartConsonant: [UInt16: [UInt16]] = [
        OpenKeyCode.f: [OpenKeyCode.p, OpenKeyCode.h],
        OpenKeyCode.j: [OpenKeyCode.g, OpenKeyCode.i],
        OpenKeyCode.w: [OpenKeyCode.q, OpenKeyCode.u],
    ]

    public static let quickEndConsonant: [UInt16: [UInt16]] = [
        OpenKeyCode.g: [OpenKeyCode.n, OpenKeyCode.g],
        OpenKeyCode.h: [OpenKeyCode.n, OpenKeyCode.h],
        OpenKeyCode.k: [OpenKeyCode.c, OpenKeyCode.h],
    ]

    // MARK: - Quick Telex (cc -> ch, gg -> gi, kk -> kh...)
    public static let quickTelex: [UInt32: [UInt16]] = [
        UInt32(OpenKeyCode.c): [OpenKeyCode.c, OpenKeyCode.h],
        UInt32(OpenKeyCode.g): [OpenKeyCode.g, OpenKeyCode.i],
        UInt32(OpenKeyCode.k): [OpenKeyCode.k, OpenKeyCode.h],
        UInt32(OpenKeyCode.n): [OpenKeyCode.n, OpenKeyCode.g],
        UInt32(OpenKeyCode.q): [OpenKeyCode.q, OpenKeyCode.u],
        UInt32(OpenKeyCode.p): [OpenKeyCode.p, OpenKeyCode.h],
        UInt32(OpenKeyCode.t): [OpenKeyCode.t, OpenKeyCode.h],
        UInt32(OpenKeyCode.u): [OpenKeyCode.u, OpenKeyCode.u],
    ]

    // MARK: - Bảng mã Unicode Dựng Sẵn (Index 0 trong _codeTable)
    // Cấu trúc: [Key: [Â, â, Ă, ă, Á, á, À, à, Ả, ả, Ã, ã, Ạ, ạ]]
    public static let unicodeTable: [UInt32: [UInt16]] = [
        UInt32(OpenKeyCode.a): [
            0x00C2, 0x00E2, 0x0102, 0x0103, 0x00C1, 0x00E1, 0x00C0, 0x00E0, 0x1EA2, 0x1EA3, 0x00C3, 0x00E3, 0x1EA0, 0x1EA1
        ],
        UInt32(OpenKeyCode.o): [
            0x00D4, 0x00F4, 0x01A0, 0x01A1, 0x00D3, 0x00F3, 0x00D2, 0x00F2, 0x1ECE, 0x1ECF, 0x00D5, 0x00F5, 0x1ECC, 0x1ECD
        ],
        UInt32(OpenKeyCode.u): [
            0x0000, 0x0000, 0x01AF, 0x01B0, 0x00DA, 0x00FA, 0x00D9, 0x00F9, 0x1EE6, 0x1EE7, 0x0168, 0x0169, 0x1EE4, 0x1EE5
        ],
        UInt32(OpenKeyCode.e): [
            0x00CA, 0x00EA, 0x0000, 0x0000, 0x00C9, 0x00E9, 0x00C8, 0x00E8, 0x1EBA, 0x1EBB, 0x1EBC, 0x1EBD, 0x1EB8, 0x1EB9
        ],
        UInt32(OpenKeyCode.d): [
            0x0110, 0x0111
        ],
        // Ấ, ấ, Ầ, ầ, Ẩ, ẩ, Ẫ, ẫ, Ậ, ậ
        UInt32(OpenKeyCode.a) | OpenKeyMask.tone: [
            0x1EA4, 0x1EA5, 0x1EA6, 0x1EA7, 0x1EA8, 0x1EA9, 0x1EAA, 0x1EAB, 0x1EAC, 0x1EAD
        ],
        // Ắ, ắ, Ằ, ằ, Ẳ, ẳ, Ẵ, ẵ, Ặ, ặ
        UInt32(OpenKeyCode.a) | OpenKeyMask.toneW: [
            0x1EAE, 0x1EAF, 0x1EB0, 0x1EB1, 0x1EB2, 0x1EB3, 0x1EB4, 0x1EB5, 0x1EB6, 0x1EB7
        ],
        // Ố, ố, Ồ, ồ, Ổ, ổ, Ỗ, ỗ, Ộ, ộ
        UInt32(OpenKeyCode.o) | OpenKeyMask.tone: [
            0x1ED0, 0x1ED1, 0x1ED2, 0x1ED3, 0x1ED4, 0x1ED5, 0x1ED6, 0x1ED7, 0x1ED8, 0x1ED9
        ],
        // Ớ, ớ,精神 Ờ, ờ, Ở, ở, Ỡ, ỡ, Ợ, ợ
        UInt32(OpenKeyCode.o) | OpenKeyMask.toneW: [
            0x1EDA, 0x1EDB, 0x1EDC, 0x1EDD, 0x1EDE, 0x1EDF, 0x1EE0, 0x1EE1, 0x1EE2, 0x1EE3
        ],
        // Ứ, ứng, Ừ, ừ, Sử, ử, Ữ, ữ, Ự, ự
        UInt32(OpenKeyCode.u) | OpenKeyMask.toneW: [
            0x1EE8, 0x1EE9, 0x1EEA, 0x1EEB, 0x1EEC, 0x1EED, 0x1EEE, 0x1EEF, 0x1EF0, 0x1EF1
        ],
        // Ế, ế, Ề, ề, Ể, ể, Ễ, ễ, Ệ, ệ
        UInt32(OpenKeyCode.e) | OpenKeyMask.tone: [
            0x1EBE, 0x1EBF, 0x1EC0, 0x1EC1, 0x1EC2, 0x1EC3, 0x1EC4, 0x1EC5, 0x1EC6, 0x1EC7
        ],
        // Í, í, Ì, ì, Ỉ, ỉ, Ĩ, ĩ, Ị, ị
        UInt32(OpenKeyCode.i): [
            0x00CD, 0x00ED, 0x00CC, 0x00EC, 0x1EC8, 0x1EC9, 0x0128, 0x0129, 0x1ECA, 0x1ECB
        ],
        // Ý, ý, Ỳ, ỳ, Ỷ, ỷ, Ỹ, ỹ, Ỵ, ỵ
        UInt32(OpenKeyCode.y): [
            0x00DD, 0x00FD, 0x1EF2, 0x1EF3, 0x1EF6, 0x1EF7, 0x1EF8, 0x1EF9, 0x1EF4, 0x1EF5
        ]
    ]

    // MARK: - Character Map & KeyCode Mapping
    public static let characterMap: [Character: UInt32] = [
        "a": UInt32(OpenKeyCode.a), "A": UInt32(OpenKeyCode.a) | OpenKeyMask.caps,
        "b": UInt32(OpenKeyCode.b), "B": UInt32(OpenKeyCode.b) | OpenKeyMask.caps,
        "c": UInt32(OpenKeyCode.c), "C": UInt32(OpenKeyCode.c) | OpenKeyMask.caps,
        "d": UInt32(OpenKeyCode.d), "D": UInt32(OpenKeyCode.d) | OpenKeyMask.caps,
        "e": UInt32(OpenKeyCode.e), "E": UInt32(OpenKeyCode.e) | OpenKeyMask.caps,
        "f": UInt32(OpenKeyCode.f), "F": UInt32(OpenKeyCode.f) | OpenKeyMask.caps,
        "g": UInt32(OpenKeyCode.g), "G": UInt32(OpenKeyCode.g) | OpenKeyMask.caps,
        "h": UInt32(OpenKeyCode.h), "H": UInt32(OpenKeyCode.h) | OpenKeyMask.caps,
        "i": UInt32(OpenKeyCode.i), "I": UInt32(OpenKeyCode.i) | OpenKeyMask.caps,
        "j": UInt32(OpenKeyCode.j), "J": UInt32(OpenKeyCode.j) | OpenKeyMask.caps,
        "k": UInt32(OpenKeyCode.k), "K": UInt32(OpenKeyCode.k) | OpenKeyMask.caps,
        "l": UInt32(OpenKeyCode.l), "L": UInt32(OpenKeyCode.l) | OpenKeyMask.caps,
        "m": UInt32(OpenKeyCode.m), "M": UInt32(OpenKeyCode.m) | OpenKeyMask.caps,
        "n": UInt32(OpenKeyCode.n), "N": UInt32(OpenKeyCode.n) | OpenKeyMask.caps,
        "o": UInt32(OpenKeyCode.o), "O": UInt32(OpenKeyCode.o) | OpenKeyMask.caps,
        "p": UInt32(OpenKeyCode.p), "P": UInt32(OpenKeyCode.p) | OpenKeyMask.caps,
        "q": UInt32(OpenKeyCode.q), "Q": UInt32(OpenKeyCode.q) | OpenKeyMask.caps,
        "r": UInt32(OpenKeyCode.r), "R": UInt32(OpenKeyCode.r) | OpenKeyMask.caps,
        "s": UInt32(OpenKeyCode.s), "S": UInt32(OpenKeyCode.s) | OpenKeyMask.caps,
        "t": UInt32(OpenKeyCode.t), "T": UInt32(OpenKeyCode.t) | OpenKeyMask.caps,
        "u": UInt32(OpenKeyCode.u), "U": UInt32(OpenKeyCode.u) | OpenKeyMask.caps,
        "v": UInt32(OpenKeyCode.v), "V": UInt32(OpenKeyCode.v) | OpenKeyMask.caps,
        "w": UInt32(OpenKeyCode.w), "W": UInt32(OpenKeyCode.w) | OpenKeyMask.caps,
        "x": UInt32(OpenKeyCode.x), "X": UInt32(OpenKeyCode.x) | OpenKeyMask.caps,
        "y": UInt32(OpenKeyCode.y), "Y": UInt32(OpenKeyCode.y) | OpenKeyMask.caps,
        "z": UInt32(OpenKeyCode.z), "Z": UInt32(OpenKeyCode.z) | OpenKeyMask.caps,
        "1": UInt32(OpenKeyCode.num1), "!": UInt32(OpenKeyCode.num1) | OpenKeyMask.caps,
        "2": UInt32(OpenKeyCode.num2), "@": UInt32(OpenKeyCode.num2) | OpenKeyMask.caps,
        "3": UInt32(OpenKeyCode.num3), "#": UInt32(OpenKeyCode.num3) | OpenKeyMask.caps,
        "4": UInt32(OpenKeyCode.num4), "$": UInt32(OpenKeyCode.num4) | OpenKeyMask.caps,
        "5": UInt32(OpenKeyCode.num5), "%": UInt32(OpenKeyCode.num5) | OpenKeyMask.caps,
        "6": UInt32(OpenKeyCode.num6), "^": UInt32(OpenKeyCode.num6) | OpenKeyMask.caps,
        "7": UInt32(OpenKeyCode.num7), "&": UInt32(OpenKeyCode.num7) | OpenKeyMask.caps,
        "8": UInt32(OpenKeyCode.num8), "*": UInt32(OpenKeyCode.num8) | OpenKeyMask.caps,
        "9": UInt32(OpenKeyCode.num9), "(": UInt32(OpenKeyCode.num9) | OpenKeyMask.caps,
        "0": UInt32(OpenKeyCode.num0), ")": UInt32(OpenKeyCode.num0) | OpenKeyMask.caps,
        "`": UInt32(OpenKeyCode.backquote), "~": UInt32(OpenKeyCode.backquote) | OpenKeyMask.caps,
        "-": UInt32(OpenKeyCode.minus), "_": UInt32(OpenKeyCode.minus) | OpenKeyMask.caps,
        "=": UInt32(OpenKeyCode.equals), "+": UInt32(OpenKeyCode.equals) | OpenKeyMask.caps,
        "[": UInt32(OpenKeyCode.leftBracket), "{": UInt32(OpenKeyCode.leftBracket) | OpenKeyMask.caps,
        "]": UInt32(OpenKeyCode.rightBracket), "}": UInt32(OpenKeyCode.rightBracket) | OpenKeyMask.caps,
        "\\": UInt32(OpenKeyCode.backslash), "|": UInt32(OpenKeyCode.backslash) | OpenKeyMask.caps,
        ";": UInt32(OpenKeyCode.semicolon), ":": UInt32(OpenKeyCode.semicolon) | OpenKeyMask.caps,
        "'": UInt32(OpenKeyCode.quote), "\"": UInt32(OpenKeyCode.quote) | OpenKeyMask.caps,
        ",": UInt32(OpenKeyCode.comma), "<": UInt32(OpenKeyCode.comma) | OpenKeyMask.caps,
        ".": UInt32(OpenKeyCode.dot), ">": UInt32(OpenKeyCode.dot) | OpenKeyMask.caps,
        "/": UInt32(OpenKeyCode.slash), "?": UInt32(OpenKeyCode.slash) | OpenKeyMask.caps,
        " ": UInt32(OpenKeyCode.space)
    ]

    private static let keyCodeToCharMap: [UInt32: Character] = {
        var map = [UInt32: Character]()
        for (char, code) in characterMap {
            map[code] = char
        }
        return map
    }()

    public static func keyCodeToCharacter(_ keyCode: UInt32) -> Character? {
        return keyCodeToCharMap[keyCode]
    }

    public static func characterToKeyCode(_ char: Character) -> (keyCode: UInt16, isCaps: Bool)? {
        guard let code = characterMap[char] else { return nil }
        let key = UInt16(code & OpenKeyMask.charMask)
        let isCaps = (code & OpenKeyMask.caps) != 0
        return (key, isCaps)
    }
}
