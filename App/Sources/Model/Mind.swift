import Foundation

/// 番人の打ち方（決まった簡単な規則）と、あなたへのヒント
enum Mind {
    /// マスの重み：隅 30・隅の隣 -8・辺 6・ほか 1（穴の隣の辺は、隅のように強い）
    static func weight(_ board: Board, _ p: Pos) -> Int {
        let e = board.size - 1
        if board.isCorner(p) { return 30 }
        let nearR = p.r <= 1 || p.r >= e - 1
        let nearC = p.c <= 1 || p.c >= e - 1
        if nearR && nearC { return -8 }
        if board.isEdge(p) { return 6 }
        return 1
    }

    static func positional(_ board: Board, for side: Side) -> Int {
        var v = 0
        for p in board.positions {
            guard let s = board.stone(at: p) else { continue }
            var w = weight(board, p)
            if board.tile(at: p) == .gilded { w += 2 }
            if s.kind == .gold { w += 2 }
            v += s.side == side ? w : -w
        }
        return v
    }

    /// 番人の 1 手（打てなければ nil）
    static func choose(_ board: Board, side: Side, style: Style, careless: Double, rng: inout SeededRandom) -> Pos? {
        let moves = board.legalMoves(side)
        guard !moves.isEmpty else { return nil }
        let roll = Double(rng.next() % 10_000) / 10_000
        if roll < careless {
            return moves[Int(rng.next() % UInt64(moves.count))]
        }
        let scored = moves.map { ($0, value(of: $0, board: board, side: side, style: style)) }
        let best = scored.map(\.1).max() ?? 0
        let top = scored.filter { $0.1 == best }.map(\.0)
        return top[Int(rng.next() % UInt64(top.count))]
    }

    static func value(of p: Pos, board: Board, side: Side, style: Style) -> Int {
        let flips = board.captures(at: p, side: side).count
        switch style {
        case .greedy:
            return flips
        case .corner:
            return weight(board, p) * 3 + flips
        case .miser:
            return -flips
        case .shrewd:
            var next = board
            next.apply(Move(pos: p, kind: .plain, side: side))
            return positional(next, for: side) - 2 * next.legalMoves(side.other).count
        case .deep:
            var next = board
            next.apply(Move(pos: p, kind: .plain, side: side))
            let replies = next.legalMoves(side.other)
            if replies.isEmpty { return positional(next, for: side) + 20 }
            var worst = Int.max
            for q in replies {
                var after = next
                after.apply(Move(pos: q, kind: .plain, side: side.other))
                worst = min(worst, positional(after, for: side) + after.legalMoves(side).count)
            }
            return worst
        }
    }

    /// あなたへのヒント：ふつうの石で、盤の形がいちばん良くなる所
    static func hint(_ board: Board) -> Pos? {
        let moves = board.legalMoves(.you)
        return moves.max { a, b in
            let va = value(of: a, board: board, side: .you, style: .shrewd)
            let vb = value(of: b, board: board, side: .you, style: .shrewd)
            return va != vb ? va < vb : b < a
        }
    }

    /// 番人が錨の石を使うか（隅か辺に置くときだけ）
    static func wantsAnchor(_ board: Board, at p: Pos) -> Bool {
        board.isCorner(p) || board.isEdge(p)
    }
}
