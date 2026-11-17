import Foundation


/// 探索の場面
enum RunPhase: Codable, Sendable, Equatable {
    /// 盤で打っている
    case playing
    /// 階を抜けた。3 つから選ぶ
    case cleared([Reward])
    /// 負けた。灯が残っているので、同じ階をやり直せる
    case fallen
    /// 灯が尽きた（または引き返した）
    case over
    /// 無料で下りられるいちばん下（9 階）まで抜けた
    case summit
}

struct FloorResult: Codable, Sendable, Equatable {
    var yours: Int
    var foes: Int
    var won: Bool { yours >= foes }
    var margin: Int { yours - foes }
}

/// 番の始めに起きたこと
enum TurnEvent: Sendable, Equatable {
    case burst(Side, [Pos])
    case pass(Side)
    case floorOver
}

/// 1 回の探索（階・灯・石の袋・遺物・いまの盤）。保存して、続きから遊べる
struct Run: Codable, Sendable, Equatable {
    var seed: UInt64
    var daily: Bool
    var dayKey: String
    var floor = 1
    var attempt = 0
    var torches = Dungeon.startTorches
    /// 特殊な石の数（StoneKind の rawValue → 数）
    var satchel: [String: Int] = [StoneKind.anchor.rawValue: 1, StoneKind.flame.rawValue: 1]
    var relics: [Relic] = []
    var plan: FloorPlan
    var board: Board
    var turn: Side = .you
    var foeAnchors = 0
    var hintsLeft = 3
    var phase: RunPhase = .playing
    var floorOver = false
    var lastResult: FloorResult?
    var flipsTotal = 0
    var specialsUsed = 0
    var deepest = 1
    /// Pro のお試し（最初の探索で、Pro の石を 1 回だけ選べる）
    var trial = false
    var rng: SeededRandom

    init(seed: UInt64, daily: Bool, dayKey: String, trial: Bool = false) {
        self.seed = seed
        self.daily = daily
        self.dayKey = dayKey
        self.trial = trial
        plan = Dungeon.plan(floor: 1, seed: seed)
        board = Board(size: plan.size, holes: plan.holes, gilded: plan.gilded)
        rng = SeededRandom(seed: seed ^ 0xD1B5_4A32_D192_ED03)
        setupFloor()
    }

    var relicSet: Set<Relic> { Set(relics) }
    var warden: Warden { plan.warden }
    var zone: Zone { plan.zone }

    func charges(_ kind: StoneKind) -> Int {
        kind == .plain ? Int.max : (satchel[kind.rawValue] ?? 0)
    }

    /// 袋にある石（数が 1 以上）
    var heldKinds: [StoneKind] { StoneKind.specials.filter { charges($0) > 0 } }

    var yourScore: Int { board.score(.you, relics: relicSet) }
    var foeScore: Int { board.score(.foe) }

    // MARK: - 階

    mutating func setupFloor() {
        plan = Dungeon.plan(floor: floor, seed: seed &+ UInt64(attempt) &* 7919, relics: relicSet)
        board = Board(size: plan.size, holes: plan.holes, gilded: plan.gilded)
        turn = .you
        foeAnchors = plan.foeAnchors
        hintsLeft = relics.contains(.lantern) ? 99 : 3
        floorOver = false
        lastResult = nil
        phase = .playing
        deepest = max(deepest, floor)
        if relics.contains(.quiver) && floor > 1 {
            addRandomStone()
        }
    }

    mutating func addRandomStone() {
        let kinds = heldKinds.isEmpty ? [StoneKind.anchor] : heldKinds
        let k = kinds[Int(rng.next() % UInt64(kinds.count))]
        satchel[k.rawValue, default: 0] += 1
    }

    // MARK: - 打つ

    /// side が打てる手があるか（あなたは袋の石も数える）
    func canMove(_ side: Side) -> Bool {
        if !board.legalMoves(side).isEmpty { return true }
        guard side == .you else { return false }
        if charges(.hourglass) > 0 && !board.legalMoves(.you, kind: .hourglass).isEmpty { return true }
        if charges(.ghost) > 0 && !board.legalMoves(.you, kind: .ghost).isEmpty { return true }
        return false
    }

    func canYouPlace(_ kind: StoneKind, at p: Pos) -> Bool {
        phase == .playing && !floorOver && turn == .you && charges(kind) > 0 && board.canPlace(kind, at: p, side: .you)
    }

    /// あなたの 1 手
    mutating func play(_ p: Pos, kind: StoneKind) -> Effect? {
        guard canYouPlace(kind, at: p) else { return nil }
        guard let effect = board.apply(Move(pos: p, kind: kind, side: .you)) else { return nil }
        if kind != .plain {
            satchel[kind.rawValue, default: 1] -= 1
            specialsUsed += 1
        }
        flipsTotal += effect.all.count
        // こだまの石は、もう 1 手
        if kind != .echo { turn = .foe }
        return effect
    }

    /// 番人の 1 手
    mutating func foeMove() -> Effect? {
        guard turn == .foe, !floorOver, phase == .playing else { return nil }
        guard let p = Mind.choose(board, side: .foe, style: plan.warden.style, careless: plan.careless, rng: &rng) else {
            turn = .you
            return nil
        }
        var kind = StoneKind.plain
        if foeAnchors > 0 && Mind.wantsAnchor(board, at: p) {
            kind = .anchor
            foeAnchors -= 1
        }
        let effect = board.apply(Move(pos: p, kind: kind, side: .foe))
        turn = .you
        return effect
    }

    /// 番の始め：時の石を進め、打てなければパス。どちらも打てなければ階の終わり
    mutating func beginTurn() -> [TurnEvent] {
        guard !floorOver, phase == .playing else { return [] }
        var events: [TurnEvent] = []
        for _ in 0..<2 {
            let burst = board.tickTimers(for: turn)
            if !burst.isEmpty {
                events.append(.burst(turn, burst))
                if turn == .you { flipsTotal += burst.count }
            }
            if canMove(turn) { return events }
            events.append(.pass(turn))
            turn = turn.other
        }
        floorOver = true
        events.append(.floorOver)
        return events
    }

    /// 階の終わりの判定。勝てば 3 つから選ぶ、負ければ灯が 1 つ消える
    mutating func finishFloor(pro: Bool) {
        guard floorOver, phase == .playing else { return }
        let result = FloorResult(yours: yourScore, foes: foeScore)
        lastResult = result
        if result.won {
            if relics.contains(.embers) && result.margin >= 10 { addRandomStone() }
            if !pro && floor >= Dungeon.freeDepth {
                phase = .summit
                return
            }
            let offer = Reward.offer(floor: floor, seed: seed, owned: relicSet, torches: torches, pro: pro, trial: trial && floor == 1)
            phase = .cleared(offer)
        } else {
            torches -= 1
            phase = torches > 0 ? .fallen : .over
        }
    }

    /// 選んで、次の階へ
    mutating func take(_ reward: Reward) {
        guard case .cleared(let offer) = phase, offer.contains(reward) else { return }
        switch reward {
        case .stones(let kind, let n): satchel[kind.rawValue, default: 0] += n
        case .relic(let r): if !relics.contains(r) { relics.append(r) }
        case .torch: torches = min(Dungeon.maxTorches, torches + 1)
        }
        if trial { trial = false }
        floor += 1
        attempt = 0
        setupFloor()
    }

    /// 負けた階を、灯を 1 つ使ってやり直す
    mutating func retry() {
        guard phase == .fallen else { return }
        attempt += 1
        setupFloor()
    }

    /// 引き返す（探索を終える）
    mutating func retreat() {
        phase = .over
    }

    var isFinished: Bool { phase == .over || phase == .summit }
}

// MARK: - 記録

struct RunRecord: Codable, Sendable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var depth: Int
    var daily: Bool
    var summit: Bool
    var relics: [Relic]
    var flips: Int
    var specials: Int
}

/// 端末に残す記録
struct Progress: Codable, Sendable, Equatable {
    var bestDepth = 0
    var runs: [RunRecord] = []
    /// 今日の迷宮の最深（日付 → 階）
    var dailyBest: [String: Int] = [:]
    var seenStones: Set<StoneKind> = [.anchor, .flame]
    var seenRelics: Set<Relic> = []
    var metWardens: Set<Int> = []
    var beatenWardens: Set<Int> = []
    var totalFlips = 0
    var proTrialUsed = false

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func dailyDone(on date: Date, calendar: Calendar) -> Bool {
        dailyBest[Self.dayKey(date, calendar: calendar)] != nil
    }

    /// 続けて今日の迷宮に潜った日数（今日まだなら、きのうまでで数える）
    func streak(today: Date, calendar: Calendar) -> Int {
        var day = today
        if !dailyDone(on: day, calendar: calendar) {
            guard let y = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        var n = 0
        while dailyDone(on: day, calendar: calendar) {
            n += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return n
    }

    /// 探索を記録に残す
    mutating func record(_ run: Run, date: Date) {
        let summit = run.phase == .summit
        let depth = run.deepest
        bestDepth = max(bestDepth, depth)
        if run.daily {
            dailyBest[run.dayKey] = max(dailyBest[run.dayKey] ?? 0, depth)
        }
        runs.insert(RunRecord(date: date, depth: depth, daily: run.daily, summit: summit, relics: run.relics, flips: run.flipsTotal, specials: run.specialsUsed), at: 0)
        totalFlips += run.flipsTotal
    }
}
