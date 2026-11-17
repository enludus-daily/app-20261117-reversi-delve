import Foundation

/// 決まった種で毎回同じ並びを作る乱数（今日の迷宮・撮影・テスト）
struct SeededRandom: RandomNumberGenerator, Sendable, Codable, Equatable {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    // 保存は文字列で（大きな整数を JSON の数にすると、読み戻すときに桁が丸められることがある）
    init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        state = UInt64(text) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(String(state))
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// 遺物（下りるあいだずっと効く、盤の力）
enum Relic: String, Codable, Sendable, CaseIterable, Hashable {
    /// 隅の礎石：あなたの隅の石は +2
    case cornerstone
    /// 光のプリズム：金のはめこみが ×3
    case prism
    /// 石袋：階の始めに、持っている石が 1 つ増える
    case quiver
    /// つるはし：穴が減る
    case pickaxe
    /// 金の鉱脈：金のはめこみが増える
    case goldVein
    /// 灯籠：ヒントが何度でも使える
    case lantern
    /// 残り火：10 点差以上で勝つと、石が 1 つ増える
    case embers
}

/// 階の帯（4 つ）。階ごとに盤の石材と灯りの色が変わる
enum Zone: Int, Codable, Sendable, CaseIterable {
    case moss = 0
    case crystal
    case magma
    case star

    static func of(floor: Int) -> Zone {
        switch floor {
        case ...3: .moss
        case 4...6: .crystal
        case 7...9: .magma
        default: .star
        }
    }
}

/// 相手（各階の番人）の打ち方
enum Style: String, Codable, Sendable {
    /// たくさん返す
    case greedy
    /// 隅と辺を好む
    case corner
    /// 少しだけ返す（相手の打てる所を減らす）
    case miser
    /// 盤の形を読む（1 手先）
    case shrewd
    /// 2 手先まで読む
    case deep
}

/// 番人（手で用意した 13 人）
struct Warden: Sendable, Identifiable {
    let id: Int
    let nameJa: String
    let nameEn: String
    let lineJa: String
    let lineEn: String
    let style: Style

    var name: String { Lang.isJapanese ? nameJa : nameEn }
    var line: String { Lang.isJapanese ? lineJa : lineEn }

    static let all: [Warden] = [
        Warden(id: 1, nameJa: "苔むした門番", nameEn: "Moss Gatekeeper", lineJa: "目の前の石を、ありったけ返したがる。", lineEn: "Grabs as many stones as it can, right now.", style: .greedy),
        Warden(id: 2, nameJa: "灯り守りのランタ", nameEn: "Lanta the Lamplighter", lineJa: "灯りの届く隅を、真っ先に取りにくる。", lineEn: "Goes for the lit corners first.", style: .corner),
        Warden(id: 3, nameJa: "ねむり蝙蝠", nameEn: "Drowsy Bat", lineJa: "少しずつ返して、あなたの置き場を減らす。", lineEn: "Flips little, starving you of moves.", style: .miser),
        Warden(id: 4, nameJa: "水晶の双子", nameEn: "Crystal Twins", lineJa: "ふたりで、多く返す手を探す。", lineEn: "Two minds, both hungry for big flips.", style: .greedy),
        Warden(id: 5, nameJa: "鏡面のミラ", nameEn: "Mira of Mirrors", lineJa: "隅と辺を映すように固めてくる。", lineEn: "Mirrors you into the edges and corners.", style: .corner),
        Warden(id: 6, nameJa: "しずくの賢者", nameEn: "The Drip Sage", lineJa: "1 手先の盤の形を読む。", lineEn: "Reads the board one move ahead.", style: .shrewd),
        Warden(id: 7, nameJa: "熔岩のゴロ", nameEn: "Golo of Magma", lineJa: "熱い辺を好み、隅をねらう。", lineEn: "Loves hot edges, hunts corners.", style: .corner),
        Warden(id: 8, nameJa: "灰の司書", nameEn: "The Ash Librarian", lineJa: "焼け残った定石で、形よく打つ。", lineEn: "Plays by the half-burnt book.", style: .shrewd),
        Warden(id: 9, nameJa: "火竜の番人", nameEn: "Ember Warden", lineJa: "2 手先まで読む。炉の底の主。", lineEn: "Thinks two moves deep. Lord of the forge.", style: .deep),
        Warden(id: 10, nameJa: "星読みのセレ", nameEn: "Sele the Stargazer", lineJa: "星の並びから、盤の形を読む。", lineEn: "Reads the board like constellations.", style: .shrewd),
        Warden(id: 11, nameJa: "黒曜の騎士", nameEn: "Obsidian Knight", lineJa: "錨の石を構え、2 手先まで読む。", lineEn: "Anchors down and thinks two ahead.", style: .deep),
        Warden(id: 12, nameJa: "底の王", nameEn: "The King Below", lineJa: "迷宮のいちばん底で、石を待つ。", lineEn: "Waits for your stones at the very bottom.", style: .deep),
        Warden(id: 13, nameJa: "深淵の影", nameEn: "Shade of the Abyss", lineJa: "底の先にも、まだ階段は続く。", lineEn: "Below the bottom, the stairs go on.", style: .deep),
    ]

    static func of(floor: Int) -> Warden { all[min(max(floor, 1), all.count) - 1] }
}

/// 1 階の作り（盤の大きさ・穴・金・相手の強さ）
struct FloorPlan: Codable, Sendable, Equatable {
    var floor: Int
    var size: Int
    var holes: Set<Pos>
    var gilded: Set<Pos>
    var wardenID: Int
    /// 相手がでたらめに打つ割合（深い階ほど小さい）
    var careless: Double
    /// 相手の錨の石の数
    var foeAnchors: Int

    var zone: Zone { Zone.of(floor: floor) }
    var warden: Warden { Warden.all[wardenID - 1] }
}

enum Dungeon {
    /// 無料で下りられる階（Pro は星の底 10〜12 階と、その先の深淵）
    static let freeDepth = 9
    /// 番人がそろう階（ここより下は深淵の影がくり返す）
    static let bottom = 12
    /// 1 回の探索の灯（負けると 1 つ消える）
    static let startTorches = 3
    static let maxTorches = 5

    /// 階ごとの決まり：盤の大きさ・穴の組の数・金の組の数・でたらめの割合・相手の錨
    static func spec(_ floor: Int) -> (size: Int, holePairs: Int, gildPairs: Int, careless: Double, anchors: Int) {
        switch floor {
        case 1: (6, 0, 1, 0.5, 0)
        case 2: (6, 1, 1, 0.45, 0)
        case 3: (6, 1, 2, 0.3, 0)
        case 4: (6, 1, 2, 0.25, 0)
        case 5: (6, 2, 2, 0.3, 0)
        case 6: (6, 2, 2, 0.35, 0)
        case 7: (8, 2, 2, 0.25, 0)
        case 8: (8, 3, 3, 0.3, 0)
        case 9: (8, 3, 3, 0.35, 1)
        case 10: (8, 3, 3, 0.25, 1)
        case 11: (8, 4, 3, 0.25, 2)
        case 12: (8, 4, 4, 0.15, 2)
        default: (8, 4, 4, max(0.05, 0.15 - Double(floor - 12) * 0.02), 3)
        }
    }

    /// 階を作る。穴と金は左右・上下に鏡のように並べる（作った盤に見えるように）
    static func plan(floor: Int, seed: UInt64, relics: Set<Relic> = []) -> FloorPlan {
        var rng = SeededRandom(seed: seed &+ UInt64(floor) &* 0x2545_F491_4F6C_DD1D)
        let s = spec(floor)
        let n = s.size
        let m = n / 2
        var holePairs = s.holePairs
        if relics.contains(.pickaxe) { holePairs = max(0, holePairs - 1) }
        var gildPairs = s.gildPairs
        if relics.contains(.goldVein) { gildPairs += 1 }

        // 左上の 4 分の 1 から選び、4 方向（または点対称の 2 つ）に写す
        let center: Set<Pos> = [Pos(m - 1, m - 1), Pos(m, m), Pos(m - 1, m), Pos(m, m - 1)]
        var quarter = (0..<m).flatMap { r in (0..<m).map { c in Pos(r, c) } }.filter { !center.contains($0) }
        quarter.shuffle(using: &rng)
        func mirrored(_ p: Pos, four: Bool) -> [Pos] {
            four ? [p, Pos(p.r, n - 1 - p.c), Pos(n - 1 - p.r, p.c), Pos(n - 1 - p.r, n - 1 - p.c)]
                : [p, Pos(n - 1 - p.r, n - 1 - p.c)]
        }
        let fourFold = Bool.random(using: &rng)
        var holes = Set<Pos>()
        var gilded = Set<Pos>()
        var pool = quarter.makeIterator()
        // 穴は隅に置かない（隅が消えると盤の形が読みにくくなる）
        var holeCount = 0
        var skipped: [Pos] = []
        while holeCount < holePairs, let p = pool.next() {
            if p == Pos(0, 0) { skipped.append(p); continue }
            for q in mirrored(p, four: fourFold) { holes.insert(q) }
            holeCount += 1
        }
        var rest = skipped + Array(IteratorSequence(pool))
        rest.shuffle(using: &rng)
        for p in rest.prefix(gildPairs) {
            for q in mirrored(p, four: !fourFold) where !holes.contains(q) { gilded.insert(q) }
        }
        let wardenID = min(floor, Warden.all.count)
        return FloorPlan(floor: floor, size: n, holes: holes, gilded: gilded, wardenID: wardenID, careless: s.careless, foeAnchors: s.anchors)
    }

    /// 今日の迷宮の種（日付から。だれが開いても同じ）
    static func dailySeed(_ date: Date, calendar: Calendar) -> UInt64 {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let v = (c.year ?? 2026) * 10000 + (c.month ?? 1) * 100 + (c.day ?? 1)
        return UInt64(v) &* 0x9E37_79B9 &+ 17
    }
}

/// 階を抜けたあとに 3 つから選ぶもの
enum Reward: Codable, Sendable, Equatable, Hashable {
    /// 特殊な石を 2 つ（錨・炎…）
    case stones(StoneKind, Int)
    /// 遺物
    case relic(Relic)
    /// 灯を 1 つ足す
    case torch

    /// 3 つを選ぶ。持っていない遺物・灯・石から、種で決める
    static func offer(floor: Int, seed: UInt64, owned: Set<Relic>, torches: Int, pro: Bool, trial: Bool) -> [Reward] {
        var rng = SeededRandom(seed: seed &+ UInt64(floor) &* 0x5851_F42D_4C95_7F2D &+ 7)
        var kinds = StoneKind.freeSpecials
        if pro { kinds += StoneKind.proSpecials }
        var stonePool: [Reward] = kinds.map { .stones($0, 2) }
        stonePool.shuffle(using: &rng)
        var relicPool: [Reward] = Relic.allCases.filter { !owned.contains($0) }.map { .relic($0) }
        relicPool.shuffle(using: &rng)
        var out: [Reward] = []
        // 1 つは必ず石、1 つは遺物（残っていれば）、もう 1 つは灯か石
        if let s = stonePool.first { out.append(s) }
        if let r = relicPool.first { out.append(r) }
        if torches < Dungeon.maxTorches && rng.next() % 3 == 0 {
            out.append(.torch)
        } else if stonePool.count > 1 {
            out.append(stonePool[1])
        }
        // Pro のお試し：最初の 1 回だけ、Pro の石を 1 つ混ぜる
        if trial && !pro {
            out[out.count - 1] = .stones(.echo, 1)
        }
        while out.count < 3 { out.append(.torch) }
        return out
    }
}
