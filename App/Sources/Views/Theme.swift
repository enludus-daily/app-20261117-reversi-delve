import SwiftUI

/// 地下へ下りる迷宮。石は宝石（月長石と黒曜石）、盤は彫った石の板、灯りは階の帯ごとに変わる。
/// 色・書体・形はここで決める（画面に 16 進を直に書かない）。
enum Theme {
    // 文字（暗い地の上）
    static let text = Color(hex: 0xEEE7D8)
    static let textSoft = Color(hex: 0xA9A192)
    static let textFaint = Color(hex: 0x6E685E)

    // 金（はめこみ・最深の記録）
    static let gold = Color(hex: 0xE8C35A)
    static let goldDeep = Color(hex: 0x9C7A26)
    static let goldSoft = Color(hex: 0xF7E3A6)

    // 月長石（あなた）
    static let moon = Color(hex: 0xEEF2F9)
    static let moonFacet = Color(hex: 0xC6D3EC)
    static let moonRim = Color(hex: 0x8193BA)
    // 黒曜石（番人）
    static let obsidian = Color(hex: 0x24212F)
    static let obsidianFacet = Color(hex: 0x3D3754)
    static let obsidianRim = Color(hex: 0x0D0B13)
    static let obsidianSheen = Color(hex: 0x9A8FCB)

    // 灯（どの帯でも同じ琥珀の炎）
    static let torch = Color(hex: 0xEE9C3E)

    // 失敗・危険（小さな印だけ）
    static let danger = Color(hex: 0xE0584A)

    // 書体：題字と数字は銅版の字（Copperplate。日本語は太いゴシックに落ちる）、本文はシステム
    static func carved(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("Copperplate-Bold", size: size, relativeTo: style)
    }

    static func label(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }

    // 角丸（彫った石の板なので小さめ。3 段階）
    static let radiusS: CGFloat = 4
    static let radiusM: CGFloat = 8
    static let radiusL: CGFloat = 14

    static let maxWidth: CGFloat = 560
}

/// 階の帯ごとの石材と灯り
struct ZonePalette {
    /// いちばん暗い地
    let deep: Color
    /// 一段明るい地（板・札）
    let raised: Color
    /// 盤のマスの石
    let slab: Color
    let slabEdge: Color
    let slabLight: Color
    /// 灯り（置ける印・強調）
    let glow: Color
    let glowSoft: Color
    /// 石材の筋（苔・水晶・熔岩・星）
    let vein: Color

    static func of(_ zone: Zone) -> ZonePalette {
        switch zone {
        case .moss:
            ZonePalette(deep: Color(hex: 0x111A16), raised: Color(hex: 0x1B2821), slab: Color(hex: 0x2F3E34), slabEdge: Color(hex: 0x17211B),
                        slabLight: Color(hex: 0x4C6152), glow: Color(hex: 0xE9A94B), glowSoft: Color(hex: 0xF6D9A2), vein: Color(hex: 0x7FAF6E))
        case .crystal:
            ZonePalette(deep: Color(hex: 0x0E1227), raised: Color(hex: 0x181D3B), slab: Color(hex: 0x2A3062), slabEdge: Color(hex: 0x141834),
                        slabLight: Color(hex: 0x48518E), glow: Color(hex: 0x7FDDF2), glowSoft: Color(hex: 0xCFF4FB), vein: Color(hex: 0xA18CF0))
        case .magma:
            ZonePalette(deep: Color(hex: 0x170E0C), raised: Color(hex: 0x25150F), slab: Color(hex: 0x3B2720), slabEdge: Color(hex: 0x1C110D),
                        slabLight: Color(hex: 0x5D3D31), glow: Color(hex: 0xFF8A3D), glowSoft: Color(hex: 0xFFCDA8), vein: Color(hex: 0xE8603A))
        case .star:
            ZonePalette(deep: Color(hex: 0x070A18), raised: Color(hex: 0x11162D), slab: Color(hex: 0x1F2544), slabEdge: Color(hex: 0x0C1024),
                        slabLight: Color(hex: 0x3A4370), glow: Color(hex: 0xF3D27A), glowSoft: Color(hex: 0xFBEFC6), vein: Color(hex: 0xC9D3F0))
        }
    }
}

extension StoneKind {
    /// 宝石の色（特殊な石の縁と印）
    var tint: Color {
        switch self {
        case .plain: Theme.moonFacet
        case .anchor: Color(hex: 0x5C8FD6)
        case .flame: Color(hex: 0xE2603F)
        case .hourglass: Color(hex: 0xE2B04A)
        case .gold: Color(hex: 0xF0C850)
        case .echo: Color(hex: 0x4FC48D)
        case .ghost: Color(hex: 0xD3CCEE)
        case .comet: Color(hex: 0xA274E6)
        }
    }

    var symbol: String {
        switch self {
        case .plain: "circle"
        case .anchor: "arrow.down.to.line"
        case .flame: "flame.fill"
        case .hourglass: "hourglass"
        case .gold: "crown.fill"
        case .echo: "arrow.triangle.2.circlepath"
        case .ghost: "circle.dashed"
        case .comet: "sparkle"
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}
