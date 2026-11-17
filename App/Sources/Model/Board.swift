import Foundation

/// どちらの石か。あなた＝月長石（白い宝石）、迷宮の番人＝黒曜石（黒い宝石）
enum Side: Int, Codable, Sendable, Hashable {
    case you = 1
    case foe = -1

    var other: Side { self == .you ? .foe : .you }
}

/// 石の種類。ふつうの石と、袋から出して置く特殊な石
enum StoneKind: String, Codable, Sendable, CaseIterable, Hashable {
    case plain
    /// 錨の石：ひっくり返されない
    case anchor
    /// 炎の石：置いた横の列の相手の石を、すべて返す
    case flame
    /// 時の石：どこにでも置ける。2 手後に、まわりの相手の石を返す
    case hourglass
    /// 金の石：終わったときに 3 つぶん数える
    case gold
    /// こだまの石（Pro）：置いたあと、もう 1 手打てる
    case echo
    /// 幽霊の石（Pro）：穴の上にも置ける
    case ghost
    /// 彗星の石（Pro）：置いた縦の列の相手の石を、すべて返す
    case comet

    static let specials: [StoneKind] = [.anchor, .flame, .hourglass, .gold, .echo, .ghost, .comet]
    static let freeSpecials: [StoneKind] = [.anchor, .flame, .hourglass, .gold]
    static let proSpecials: [StoneKind] = [.echo, .ghost, .comet]

    var isPro: Bool { Self.proSpecials.contains(self) }
}

struct Stone: Codable, Sendable, Equatable, Hashable {
    var side: Side
    var kind: StoneKind
    /// 時の石が弾けるまでの、持ち主の番の数（0 は弾けたあと・止まっている）
    var timer: Int = 0
}

/// 盤のマス
enum Tile: Int, Codable, Sendable {
    case floor
    /// 穴：石を置けない。列もここで途切れる（幽霊の石だけ置ける）
    case hole
    /// 金のはめこみ：ここにある石は 2 つぶん数える
    case gilded
}

struct Pos: Hashable, Codable, Sendable, Comparable {
    var r: Int
    var c: Int

    init(_ r: Int, _ c: Int) {
        self.r = r
        self.c = c
    }

    static func < (a: Pos, b: Pos) -> Bool { a.r != b.r ? a.r < b.r : a.c < b.c }

    func moved(_ d: (Int, Int), by k: Int = 1) -> Pos { Pos(r + d.0 * k, c + d.1 * k) }
}

/// 1 手
struct Move: Codable, Sendable, Equatable {
    var pos: Pos
    var kind: StoneKind
    var side: Side
}

/// 1 手で起きたこと（動きと音に使う）
struct Effect: Sendable, Equatable {
    var move: Move
    /// 挟んで返った石（置いた所から近い順）
    var flips: [Pos]
    /// 炎・彗星で返った石
    var blast: [Pos]

    var all: [Pos] { flips + blast }
}

/// 盤。ルールはすべてここ（画面から切り離してテストする）
struct Board: Codable, Sendable, Equatable {
    let size: Int
    private(set) var tiles: [Tile]
    private(set) var stones: [Stone?]

    static let directions: [(Int, Int)] = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]

    /// 真ん中の 4 つに、ふつうの石を斜めに置いて始める
    init(size: Int, holes: Set<Pos> = [], gilded: Set<Pos> = []) {
        self.size = size
        tiles = Array(repeating: .floor, count: size * size)
        stones = Array(repeating: nil, count: size * size)
        let m = size / 2
        let center: Set<Pos> = [Pos(m - 1, m - 1), Pos(m, m), Pos(m - 1, m), Pos(m, m - 1)]
        for p in gilded where inBounds(p) && !center.contains(p) { tiles[index(p)] = .gilded }
        for p in holes where inBounds(p) && !center.contains(p) { tiles[index(p)] = .hole }
        stones[index(Pos(m - 1, m - 1))] = Stone(side: .you, kind: .plain)
        stones[index(Pos(m, m))] = Stone(side: .you, kind: .plain)
        stones[index(Pos(m - 1, m))] = Stone(side: .foe, kind: .plain)
        stones[index(Pos(m, m - 1))] = Stone(side: .foe, kind: .plain)
    }

    /// 決まった並びから作る（テスト・見本）。"." 空き、"#" 穴、"*" 金、"o" あなた、"x" 相手、"A" あなたの錨、"a" 相手の錨、"G" あなたの金の石
    init(rows: [String]) {
        size = rows.count
        tiles = Array(repeating: .floor, count: size * size)
        stones = Array(repeating: nil, count: size * size)
        for (r, row) in rows.enumerated() {
            for (c, ch) in row.enumerated() where c < size {
                let i = r * size + c
                switch ch {
                case "#": tiles[i] = .hole
                case "*": tiles[i] = .gilded
                case "o": stones[i] = Stone(side: .you, kind: .plain)
                case "x": stones[i] = Stone(side: .foe, kind: .plain)
                case "A": stones[i] = Stone(side: .you, kind: .anchor)
                case "a": stones[i] = Stone(side: .foe, kind: .anchor)
                case "G": stones[i] = Stone(side: .you, kind: .gold)
                default: break
                }
            }
        }
    }

    func index(_ p: Pos) -> Int { p.r * size + p.c }
    func inBounds(_ p: Pos) -> Bool { p.r >= 0 && p.c >= 0 && p.r < size && p.c < size }
    func stone(at p: Pos) -> Stone? { inBounds(p) ? stones[index(p)] : nil }
    func tile(at p: Pos) -> Tile { inBounds(p) ? tiles[index(p)] : .hole }

    var positions: [Pos] {
        (0..<size).flatMap { r in (0..<size).map { c in Pos(r, c) } }
    }

    func isCorner(_ p: Pos) -> Bool {
        (p.r == 0 || p.r == size - 1) && (p.c == 0 || p.c == size - 1)
    }

    func isEdge(_ p: Pos) -> Bool {
        p.r == 0 || p.c == 0 || p.r == size - 1 || p.c == size - 1
    }

    /// 置けるマスの数（穴を除く）
    var playableCells: Int { tiles.filter { $0 != .hole }.count + positions.filter { tile(at: $0) == .hole && stone(at: $0) != nil }.count }

    var isFull: Bool { positions.allSatisfy { stone(at: $0) != nil || tile(at: $0) == .hole } }

    // MARK: - ルール

    /// side が p に置いたとき、挟んで返る石（錨の石は返らない。穴と空きで列は途切れる）
    func captures(at p: Pos, side: Side) -> [Pos] {
        guard inBounds(p), stone(at: p) == nil else { return [] }
        var out: [Pos] = []
        for d in Self.directions {
            var line: [Pos] = []
            var q = p.moved(d)
            while inBounds(q), let s = stone(at: q), s.side == side.other {
                line.append(q)
                q = q.moved(d)
            }
            if !line.isEmpty, let s = stone(at: q), s.side == side {
                out += line.filter { stone(at: $0)?.kind != .anchor }
            }
        }
        return out.sorted { distance($0, p) < distance($1, p) }
    }

    func distance(_ a: Pos, _ b: Pos) -> Int { max(abs(a.r - b.r), abs(a.c - b.c)) }

    /// その石を p に置けるか
    func canPlace(_ kind: StoneKind, at p: Pos, side: Side) -> Bool {
        guard inBounds(p), stone(at: p) == nil else { return false }
        switch tile(at: p) {
        case .hole:
            return kind == .ghost && !captures(at: p, side: side).isEmpty
        case .floor, .gilded:
            if kind == .hourglass { return true }
            return !captures(at: p, side: side).isEmpty
        }
    }

    func legalMoves(_ side: Side, kind: StoneKind = .plain) -> [Pos] {
        positions.filter { canPlace(kind, at: $0, side: side) }
    }

    /// 置く。返った石を返す（置けない所なら nil）
    @discardableResult
    mutating func apply(_ move: Move) -> Effect? {
        guard canPlace(move.kind, at: move.pos, side: move.side) else { return nil }
        let flips = captures(at: move.pos, side: move.side)
        stones[index(move.pos)] = Stone(side: move.side, kind: move.kind, timer: move.kind == .hourglass ? 2 : 0)
        for f in flips { flip(f, to: move.side) }
        var blast: [Pos] = []
        if move.kind == .flame || move.kind == .comet {
            let line: [Pos] = move.kind == .flame
                ? (0..<size).map { Pos(move.pos.r, $0) }
                : (0..<size).map { Pos($0, move.pos.c) }
            for q in line.sorted(by: { distance($0, move.pos) < distance($1, move.pos) }) {
                if let s = stone(at: q), s.side == move.side.other, s.kind != .anchor {
                    flip(q, to: move.side)
                    blast.append(q)
                }
            }
        }
        return Effect(move: move, flips: flips, blast: blast)
    }

    /// 返す。時の石は相手の手に渡ると止まる
    private mutating func flip(_ p: Pos, to side: Side) {
        guard var s = stones[index(p)], s.kind != .anchor else { return }
        s.side = side
        if s.kind == .hourglass { s.timer = 0 }
        stones[index(p)] = s
    }

    /// side の番の始めに、side の時の石を 1 つ進める。弾けた石のまわりで返った石を返す
    mutating func tickTimers(for side: Side) -> [Pos] {
        var burst: [Pos] = []
        for p in positions {
            guard var s = stone(at: p), s.side == side, s.kind == .hourglass, s.timer > 0 else { continue }
            s.timer -= 1
            stones[index(p)] = s
            if s.timer == 0 {
                for d in Self.directions {
                    let q = p.moved(d)
                    if let n = stone(at: q), n.side == side.other, n.kind != .anchor {
                        flip(q, to: side)
                        burst.append(q)
                    }
                }
            }
        }
        return burst
    }

    // MARK: - 数える

    func count(_ side: Side) -> Int { stones.compactMap { $0 }.filter { $0.side == side }.count }

    /// 点：ふつうの石 1・金の石 3、金のはめこみの上は ×2（プリズムの遺物で ×3）、礎石の遺物で隅 +2
    func score(_ side: Side, relics: Set<Relic> = []) -> Int {
        var total = 0
        for p in positions {
            guard let s = stone(at: p), s.side == side else { continue }
            var v = s.kind == .gold ? 3 : 1
            if tile(at: p) == .gilded { v *= relics.contains(.prism) ? 3 : 2 }
            if relics.contains(.cornerstone) && isCorner(p) { v += 2 }
            total += v
        }
        return total
    }

    // MARK: - 見本・テスト用

    mutating func set(_ p: Pos, _ stone: Stone?) {
        guard inBounds(p) else { return }
        stones[index(p)] = stone
    }
}
