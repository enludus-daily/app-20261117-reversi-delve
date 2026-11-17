import Foundation
import Testing
@testable import ReversiDelve

struct BoardTests {
    @Test func startsWithFourStonesAndFourMoves() {
        let b = Board(size: 6)
        #expect(b.count(.you) == 2)
        #expect(b.count(.foe) == 2)
        #expect(b.legalMoves(.you).count == 4)
    }

    @Test func sandwichFlipsInOrderOfDistance() {
        var b = Board(rows: [
            "......",
            ".xxxo.",
            "......",
            "......",
            "......",
            "......",
        ])
        let e = b.apply(Move(pos: Pos(1, 0), kind: .plain, side: .you))
        #expect(e?.flips == [Pos(1, 1), Pos(1, 2), Pos(1, 3)])
        #expect(b.count(.foe) == 0)
    }

    @Test func anchorIsNeverFlipped() {
        var b = Board(rows: [
            "......",
            ".xao..",
            "......",
            "......",
            "......",
            "......",
        ])
        let e = b.apply(Move(pos: Pos(1, 0), kind: .plain, side: .you))
        #expect(e?.flips == [Pos(1, 1)])
        #expect(b.stone(at: Pos(1, 2))?.side == .foe)
    }

    @Test func pitsBreakTheLine() {
        let b = Board(rows: [
            "......",
            ".x#o..",
            "......",
            "......",
            "......",
            "......",
        ])
        #expect(!b.canPlace(.plain, at: Pos(1, 0), side: .you))
        #expect(!b.canPlace(.plain, at: Pos(1, 2), side: .you))
    }

    @Test func flameBurnsTheWholeRowButNotAnchors() {
        var b = Board(rows: [
            "......",
            ".xo.xa",
            "......",
            "......",
            "......",
            "......",
        ])
        let e = b.apply(Move(pos: Pos(1, 0), kind: .flame, side: .you))
        #expect(e?.flips == [Pos(1, 1)])
        #expect(e?.blast == [Pos(1, 4)])
        #expect(b.stone(at: Pos(1, 5))?.side == .foe)
        #expect(b.stone(at: Pos(1, 0))?.kind == .flame)
    }

    @Test func cometBurnsTheColumn() {
        var b = Board(rows: [
            ".x....",
            ".o....",
            "......",
            ".x....",
            ".x....",
            "......",
        ])
        // (0,0) から右へは挟めないので、下の (2,1) に置く：上へ挟んで (1,1) はもう自分、縦の列の (0,1)(3,1)(4,1) が焼ける
        b.set(Pos(2, 2), Stone(side: .foe, kind: .plain))
        b.set(Pos(2, 3), Stone(side: .you, kind: .plain))
        let e = b.apply(Move(pos: Pos(2, 1), kind: .comet, side: .you))
        #expect(e != nil)
        #expect(Set(e?.blast ?? []) == [Pos(0, 1), Pos(3, 1), Pos(4, 1)])
        #expect(b.count(.foe) == 0)
    }

    @Test func hourglassGoesAnywhereAndBurstsTwoTurnsLater() {
        var b = Board(rows: [
            "......",
            "......",
            "..x...",
            "......",
            "......",
            "......",
        ])
        #expect(!b.canPlace(.plain, at: Pos(3, 3), side: .you))
        #expect(b.canPlace(.hourglass, at: Pos(3, 3), side: .you))
        b.apply(Move(pos: Pos(3, 3), kind: .hourglass, side: .you))
        #expect(b.tickTimers(for: .you).isEmpty)
        #expect(b.stone(at: Pos(3, 3))?.timer == 1)
        #expect(b.tickTimers(for: .you) == [Pos(2, 2)])
        #expect(b.count(.foe) == 0)
    }

    @Test func flippedHourglassStops() {
        var b = Board(rows: [
            "......",
            "......",
            "......",
            "......",
            "......",
            "......",
        ])
        b.set(Pos(2, 2), Stone(side: .you, kind: .hourglass, timer: 2))
        b.set(Pos(2, 1), Stone(side: .foe, kind: .plain))
        b.apply(Move(pos: Pos(2, 3), kind: .plain, side: .foe))
        #expect(b.stone(at: Pos(2, 2))?.side == .foe)
        #expect(b.stone(at: Pos(2, 2))?.timer == 0)
    }

    @Test func ghostCanSitOnAPit() {
        let b = Board(rows: [
            "......",
            "#xo...",
            "......",
            "......",
            "......",
            "......",
        ])
        #expect(!b.canPlace(.plain, at: Pos(1, 0), side: .you))
        #expect(b.canPlace(.ghost, at: Pos(1, 0), side: .you))
    }

    @Test func scoringCountsGoldInlaysPrismAndCorners() {
        var b = Board(rows: [
            "G.....",
            "......",
            "......",
            "......",
            "......",
            ".....x",
        ])
        b.set(Pos(2, 2), Stone(side: .you, kind: .plain))
        #expect(b.score(.you) == 4)
        #expect(b.score(.you, relics: [.cornerstone]) == 6)
        #expect(b.score(.foe) == 1)
        var g = Board(rows: ["*....", ".....", ".....", ".....", "....."])
        g.set(Pos(0, 0), Stone(side: .you, kind: .plain))
        #expect(g.score(.you) == 2)
        #expect(g.score(.you, relics: [.prism]) == 3)
    }
}

struct DungeonTests {
    @Test func plansAreRepeatableAndSymmetric() {
        for floor in 1...14 {
            let a = Dungeon.plan(floor: floor, seed: 99)
            let b = Dungeon.plan(floor: floor, seed: 99)
            #expect(a == b)
            let n = a.size
            let m = n / 2
            for h in a.holes {
                #expect(a.holes.contains(Pos(n - 1 - h.r, n - 1 - h.c)))
                #expect(!(h.r >= m - 1 && h.r <= m && h.c >= m - 1 && h.c <= m))
                #expect(!Board(size: n).isCorner(h))
            }
            #expect(a.holes.isDisjoint(with: a.gilded))
        }
    }

    @Test func deeperFloorsAreBiggerAndStricter() {
        #expect(Dungeon.plan(floor: 1, seed: 1).size == 6)
        #expect(Dungeon.plan(floor: 8, seed: 1).size == 8)
        #expect(Dungeon.plan(floor: 12, seed: 1).careless < Dungeon.plan(floor: 1, seed: 1).careless)
        #expect(Dungeon.plan(floor: 12, seed: 1).foeAnchors > 0)
    }

    @Test func pickaxeRemovesPits() {
        let plain = Dungeon.plan(floor: 8, seed: 5)
        let dug = Dungeon.plan(floor: 8, seed: 5, relics: [.pickaxe])
        #expect(dug.holes.count < plain.holes.count)
    }

    @Test func dailySeedIsTheSameAllDay() {
        let cal = Calendar(identifier: .gregorian)
        let morning = cal.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 6))!
        let night = cal.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 23))!
        let tomorrow = cal.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 6))!
        #expect(Dungeon.dailySeed(morning, calendar: cal) == Dungeon.dailySeed(night, calendar: cal))
        #expect(Dungeon.dailySeed(morning, calendar: cal) != Dungeon.dailySeed(tomorrow, calendar: cal))
    }

    @Test func rewardsAreThreeAndTheTrialOffersAProStone() {
        let offer = Reward.offer(floor: 1, seed: 3, owned: [], torches: 3, pro: false, trial: false)
        #expect(offer.count == 3)
        #expect(Set(offer).count == 3)
        #expect(!offer.contains { if case .stones(let k, _) = $0 { return k.isPro } else { return false } })
        let trial = Reward.offer(floor: 1, seed: 3, owned: [], torches: 3, pro: false, trial: true)
        #expect(trial.contains(.stones(.echo, 1)))
        let all = Reward.offer(floor: 2, seed: 3, owned: Set(Relic.allCases), torches: 5, pro: true, trial: false)
        #expect(all.count == 3)
    }

    @Test func wardensFollowTheFloors() {
        #expect(Warden.all.count == 13)
        #expect(Dungeon.plan(floor: 1, seed: 1).warden.style == .greedy)
        #expect(Dungeon.plan(floor: 20, seed: 1).wardenID == 13)
    }
}

struct MindTests {
    @Test func everyStylePicksALegalMove() {
        let styles: [Style] = [.greedy, .corner, .miser, .shrewd, .deep]
        let board = Board(size: 8, holes: [Pos(0, 3), Pos(7, 4)], gilded: [Pos(2, 2)])
        for style in styles {
            var rng = SeededRandom(seed: 1)
            let p = Mind.choose(board, side: .foe, style: style, careless: 0, rng: &rng)
            #expect(p.map { board.canPlace(.plain, at: $0, side: .foe) } == true)
        }
    }

    @Test func cornerLoverTakesTheCorner() {
        let b = Board(rows: [
            "......",
            ".o....",
            "..x...",
            "...o..",
            "......",
            "......",
        ])
        var rng = SeededRandom(seed: 2)
        // 番人（x）は (0,0) で (1,1) を挟める
        #expect(Mind.choose(b, side: .foe, style: .corner, careless: 0, rng: &rng) == Pos(0, 0))
    }

    @Test func noMoveMeansNil() {
        let b = Board(rows: ["oo", "oo"])
        var rng = SeededRandom(seed: 1)
        #expect(Mind.choose(b, side: .foe, style: .greedy, careless: 0, rng: &rng) == nil)
        #expect(Mind.hint(b) == nil)
    }
}

struct RunTests {
    func finale(trial: Bool = false) -> Run {
        var r = Run(seed: 11, daily: true, dayKey: "2026-11-17", trial: trial)
        Samples.applyFinale(to: &r)
        return r
    }

    @Test func theSampleFinaleEndsInTwoOfYourMoves() {
        var r = finale()
        #expect(r.board.legalMoves(.you).sorted() == [Pos(0, 0), Pos(0, 5)])
        #expect(r.play(Pos(0, 0), kind: .plain) != nil)
        let events = r.beginTurn()
        #expect(events.contains(.pass(.foe)))
        #expect(r.turn == .you)
        #expect(r.play(Pos(0, 5), kind: .plain) != nil)
        #expect(r.beginTurn().contains(.floorOver))
        r.finishFloor(pro: false)
        guard case .cleared(let offer) = r.phase else {
            Issue.record("階を抜けていない")
            return
        }
        #expect(offer.count == 3)
        #expect(r.lastResult?.won == true)
    }

    @Test func flameFromTheSatchelIsSpent() {
        var r = finale()
        #expect(r.charges(.flame) == 1)
        let e = r.play(Pos(0, 0), kind: .flame)
        #expect(e != nil)
        #expect(r.charges(.flame) == 0)
        #expect(r.specialsUsed == 1)
        #expect(r.play(Pos(0, 5), kind: .flame) == nil)
    }

    @Test func echoKeepsYourTurn() {
        var r = finale()
        r.satchel[StoneKind.echo.rawValue] = 1
        _ = r.play(Pos(0, 0), kind: .echo)
        #expect(r.turn == .you)
    }

    @Test func takingARewardGoesDownAFloor() {
        var r = finale()
        _ = r.play(Pos(0, 0), kind: .plain)
        _ = r.beginTurn()
        _ = r.play(Pos(0, 5), kind: .plain)
        _ = r.beginTurn()
        r.finishFloor(pro: false)
        guard case .cleared(let offer) = r.phase else {
            Issue.record("階を抜けていない")
            return
        }
        r.take(offer[0])
        #expect(r.floor == 2)
        #expect(r.phase == .playing)
        #expect(r.deepest == 2)
        #expect(r.board.count(.you) == 2)
    }

    @Test func losingCostsATorchAndTheLastTorchEndsTheDelve() {
        var r = Run(seed: 4, daily: false, dayKey: "x")
        r.board = Board(rows: ["xx", "xo"])
        r.floorOver = true
        r.finishFloor(pro: false)
        #expect(r.phase == .fallen)
        #expect(r.torches == 2)
        r.retry()
        #expect(r.phase == .playing)
        #expect(r.attempt == 1)
        r.torches = 1
        r.board = Board(rows: ["xx", "xo"])
        r.floorOver = true
        r.finishFloor(pro: false)
        #expect(r.phase == .over)
    }

    @Test func freeDelvesStopAtTheMagmaForge() {
        var r = Run(seed: 4, daily: false, dayKey: "x")
        r.floor = Dungeon.freeDepth
        r.board = Board(rows: ["oo", "ox"])
        r.floorOver = true
        r.finishFloor(pro: false)
        #expect(r.phase == .summit)
        var p = Run(seed: 4, daily: false, dayKey: "x")
        p.floor = Dungeon.freeDepth
        p.board = Board(rows: ["oo", "ox"])
        p.floorOver = true
        p.finishFloor(pro: true)
        if case .cleared = p.phase {} else { Issue.record("Pro なら先へ進める") }
    }

    @Test func runsSurviveSaving() throws {
        let r = finale()
        let data = try JSONEncoder().encode(r)
        let back = try JSONDecoder().decode(Run.self, from: data)
        #expect(back == r)
    }

    @Test func aWholeFloorAgainstEveryWardenFinishes() {
        for floor in [1, 5, 9, 12] {
            var r = Run(seed: UInt64(floor), daily: false, dayKey: "x")
            r.floor = floor
            r.setupFloor()
            var rng = SeededRandom(seed: 9)
            var steps = 0
            while !r.floorOver && steps < 300 {
                steps += 1
                _ = r.beginTurn()
                if r.floorOver { break }
                if r.turn == .you {
                    guard let p = Mind.choose(r.board, side: .you, style: .shrewd, careless: 0, rng: &rng) else { break }
                    _ = r.play(p, kind: .plain)
                } else {
                    _ = r.foeMove()
                }
            }
            #expect(r.floorOver)
            r.finishFloor(pro: true)
            #expect(r.phase != .playing)
        }
    }
}

struct ProgressTests {
    @Test func streakCountsBackFromToday() {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 12))!
        var p = Progress()
        for d in 1...3 {
            let day = cal.date(byAdding: .day, value: -d, to: today)!
            p.dailyBest[Progress.dayKey(day, calendar: cal)] = 3
        }
        #expect(p.streak(today: today, calendar: cal) == 3)
        p.dailyBest[Progress.dayKey(today, calendar: cal)] = 5
        #expect(p.streak(today: today, calendar: cal) == 4)
    }

    @Test func recordingKeepsTheDeepest() {
        var p = Progress()
        var r = Run(seed: 1, daily: true, dayKey: "2026-11-17")
        r.deepest = 6
        r.flipsTotal = 120
        r.retreat()
        p.record(r, date: Date())
        #expect(p.bestDepth == 6)
        #expect(p.dailyBest["2026-11-17"] == 6)
        #expect(p.totalFlips == 120)
        #expect(p.runs.count == 1)
    }
}
