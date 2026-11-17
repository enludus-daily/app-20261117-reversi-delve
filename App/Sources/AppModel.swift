import Foundation
import Observation
import SwiftUI

enum ActiveSheet: Identifiable, Equatable {
    case settings
    case paywall
    case codex
    case records
    case share
    var id: String {
        switch self {
        case .settings: "settings"
        case .paywall: "paywall"
        case .codex: "codex"
        case .records: "records"
        case .share: "share"
        }
    }
}

/// 盤の上に出す一言（パス・時の石・階の名前）
struct Banner: Equatable {
    var id = UUID()
    var text: String
    var sub: String = ""
}

@MainActor
@Observable
final class AppModel {
    // 保存する値
    var progress: Progress { didSet { save() } }
    var run: Run? { didSet { saveRun() } }
    var onboarded: Bool { didSet { store(onboarded, "onboarded") } }
    var soundOn: Bool { didSet { store(soundOn, "sound") } }
    var hapticsOn: Bool { didSet { store(hapticsOn, "haptics") } }
    /// 最初の探索が終わったあとの Pro の案内は 1 回だけ
    var paywallOffered: Bool { didSet { store(paywallOffered, "paywallOffered") } }

    // 画面の状態
    var inRun = false
    var selectedKind: StoneKind = .plain
    var hintPos: Pos?
    var lastEffect: Effect?
    /// 返る石ごとの遅れ（置いた所からの距離 × 55ms）
    var flipDelays: [Pos: Double] = [:]
    var burstCells: Set<Pos> = []
    var banner: Banner?
    var busy = false
    var shake = 0
    var showPause = false
    var activeSheet: ActiveSheet?
    var now: Date
    /// 撮影・デモでは時間を止める
    var still = false
    /// 今日の迷宮の 1 階を、見本の盤で始める（UI テスト）
    var useSample = false
    /// 終わった探索（まとめの画面・共有に使う）
    var finishedRun: Run?

    // 手応え（値が変わると振動）
    var pressTick = 0
    var placeTick = 0
    var chainTick = 0
    var failTick = 0
    var clearTick = 0
    var pickTick = 0

    let purchases: PurchaseStore
    var proOverride = false
    var isPro: Bool { proOverride || purchases.entitlements.isPro }

    private let persists: Bool
    let calendar = Calendar.current

    static let bundleID = Bundle.main.bundleIdentifier ?? "com.enludus.daily.012"
    static var proID: String { ProductID.pro(bundleID: bundleID) }

    init(persists: Bool = true, now: Date = Date()) {
        self.persists = persists
        self.now = now
        let d = UserDefaults.standard
        if persists, let data = d.data(forKey: "progress"), let p = try? JSONDecoder().decode(Progress.self, from: data) {
            progress = p
        } else {
            progress = Progress()
        }
        if persists, let data = d.data(forKey: "run"), let r = try? JSONDecoder().decode(Run.self, from: data), !r.isFinished {
            run = r
        } else {
            run = nil
        }
        onboarded = persists ? d.bool(forKey: "onboarded") : true
        soundOn = persists ? (d.object(forKey: "sound") as? Bool ?? true) : true
        hapticsOn = persists ? (d.object(forKey: "haptics") as? Bool ?? true) : true
        paywallOffered = persists ? d.bool(forKey: "paywallOffered") : true
        purchases = PurchaseStore(productIDs: [Self.proID], proProductIDs: [Self.proID])
    }

    private func save() {
        guard persists, let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: "progress")
    }

    private func saveRun() {
        guard persists else { return }
        if let run, !run.isFinished, let data = try? JSONEncoder().encode(run) {
            UserDefaults.standard.set(data, forKey: "run")
        } else {
            UserDefaults.standard.removeObject(forKey: "run")
        }
    }

    private func store(_ value: Bool, _ key: String) {
        guard persists else { return }
        UserDefaults.standard.set(value, forKey: key)
    }

    // MARK: - 読む値

    var todayKey: String { Progress.dayKey(now, calendar: calendar) }
    var dailyDone: Bool { progress.dailyDone(on: now, calendar: calendar) }
    var dailyBestToday: Int { progress.dailyBest[todayKey] ?? 0 }
    var streak: Int { progress.streak(today: now, calendar: calendar) }
    var palette: ZonePalette { ZonePalette.of(run?.zone ?? .moss) }
    var hasRunInProgress: Bool { run != nil && !(run?.isFinished ?? true) }
    var reduceMotion = false

    // MARK: - 探索を始める

    func startDaily() {
        press()
        guard !dailyDone else { return }
        var r = Run(seed: Dungeon.dailySeed(now, calendar: calendar), daily: true, dayKey: todayKey, trial: !progress.proTrialUsed && !isPro)
        if useSample { Samples.applyFinale(to: &r) }
        begin(r)
        // 今日の迷宮は 1 日 1 回（始めた時点で数える。引き返しても、その日の最深が残る）
        progress.dailyBest[todayKey] = max(progress.dailyBest[todayKey] ?? 0, 1)
    }

    func startDive() {
        press()
        let r = Run(seed: UInt64.random(in: 1...(1 << 52)), daily: false, dayKey: todayKey, trial: !progress.proTrialUsed && !isPro)
        begin(r)
    }

    func resume() {
        press()
        guard run != nil else { return }
        resetBoardState()
        inRun = true
        showFloorBanner()
    }

    private func begin(_ r: Run) {
        if r.trial { progress.proTrialUsed = true }
        run = r
        resetBoardState()
        finishedRun = nil
        inRun = true
        meet()
        showFloorBanner()
        play(.descend)
    }

    func resetBoardState() {
        selectedKind = .plain
        hintPos = nil
        lastEffect = nil
        flipDelays = [:]
        burstCells = []
        banner = nil
        busy = false
        showPause = false
    }

    private func meet() {
        guard let run else { return }
        progress.metWardens.insert(run.plan.wardenID)
        for k in run.heldKinds { progress.seenStones.insert(k) }
        for r in run.relics { progress.seenRelics.insert(r) }
    }

    private func showFloorBanner() {
        guard let run else { return }
        let sub = run.plan.room.map { run.warden.name + " · " + $0.name } ?? run.warden.name
        banner = Banner(text: trf("地下 %d 階", "Floor %d", run.floor), sub: sub)
        let id = banner?.id
        Task {
            await wait(still ? 60 : 1.6)
            if banner?.id == id { banner = nil }
        }
    }

    // MARK: - 盤の操作

    /// 袋の石を選ぶ（もう一度押すと、ふつうの石に戻す）
    func select(_ kind: StoneKind) {
        press()
        guard let run, run.charges(kind) > 0 else { return }
        selectedKind = selectedKind == kind ? .plain : kind
    }

    func useHint() {
        press()
        guard var r = run, r.turn == .you, !busy, r.hintsLeft > 0 else { return }
        hintPos = Mind.hint(r.board)
        if hintPos != nil && !r.relics.contains(.lantern) {
            r.hintsLeft -= 1
            run = r
        }
    }

    /// 置ける所（いま選んでいる石で）
    var legalCells: Set<Pos> {
        guard let run, run.turn == .you, run.phase == .playing, !run.floorOver, !busy else { return [] }
        return Set(run.board.legalMoves(.you, kind: selectedKind))
    }

    func tap(_ p: Pos) {
        guard var r = run, !busy, r.turn == .you else { return }
        let kind = selectedKind
        guard let effect = r.play(p, kind: kind) else { return }
        run = r
        if kind != .plain { progress.seenStones.insert(kind) }
        selectedKind = .plain
        hintPos = nil
        Task { await show(effect, mine: true); await advance() }
    }

    /// 1 手の動き：置く → 近い順に返る（55ms ずつ）。音と振動もここ
    private func show(_ effect: Effect, mine: Bool) async {
        var delays: [Pos: Double] = [:]
        for p in effect.flips { delays[p] = Double(max(1, distance(p, effect.move.pos))) * 0.055 }
        for (i, p) in effect.blast.enumerated() { delays[p] = 0.25 + Double(i) * 0.04 }
        flipDelays = delays
        lastEffect = effect
        placeTick += 1
        play(.place)
        if !effect.blast.isEmpty {
            play(.blast)
            shake += mine ? 0 : 1
        }
        let total = effect.all.count
        if total > 0 {
            let steps = min(total, 6)
            for i in 0..<steps {
                await wait(0.06)
                play(.flip(i + (mine ? 2 : 0)))
            }
        }
        if mine && total >= 5 { chainTick += 1 }
        if !mine, board(effect.move.pos) { failTick += 1 }
        await wait(still ? 0 : 0.35 + (delays.values.max() ?? 0))
    }

    private func board(_ p: Pos) -> Bool {
        run?.board.isCorner(p) ?? false
    }

    private func distance(_ a: Pos, _ b: Pos) -> Int { max(abs(a.r - b.r), abs(a.c - b.c)) }

    /// 番を進める：時の石・パス・番人の手・階の終わり
    func advance() async {
        busy = true
        defer { busy = false }
        var guardSteps = 0
        while guardSteps < 200 {
            guardSteps += 1
            guard var r = run, r.phase == .playing else { return }
            let events = r.beginTurn()
            run = r
            for e in events {
                switch e {
                case .burst(let side, let cells):
                    burstCells = Set(cells)
                    play(.blast)
                    if side == .you { chainTick += 1 } else { failTick += 1 }
                    await wait(still ? 0 : 0.7)
                    burstCells = []
                case .pass(let side):
                    banner = Banner(text: side == .you ? tr("あなたはパス", "You pass") : tr("番人はパス", "The warden passes"),
                                    sub: tr("置ける所がありません", "No place to move"))
                    await wait(still ? 0 : 1.1)
                    banner = nil
                case .floorOver:
                    break
                }
            }
            if r.floorOver {
                await wait(still ? 0 : 0.5)
                finishFloor()
                return
            }
            if r.turn == .you { return }
            await wait(still ? 0 : 0.55)
            guard var r2 = run else { return }
            let effect = r2.foeMove()
            run = r2
            if let effect { await show(effect, mine: false) }
        }
    }

    private func finishFloor() {
        guard var r = run else { return }
        r.finishFloor(pro: isPro)
        run = r
        lastEffect = nil
        switch r.phase {
        case .cleared, .summit:
            progress.beatenWardens.insert(r.plan.wardenID)
            clearTick += 1
            play(.chime)
        case .fallen, .over:
            failTick += 1
            shake += 1
            play(.thud)
        case .playing:
            break
        }
        if r.isFinished { record(r) }
    }

    private func record(_ r: Run) {
        progress.record(r, date: now)
        finishedRun = r
    }

    // MARK: - 階の間

    func take(_ reward: Reward) {
        guard var r = run else { return }
        pickTick += 1
        play(.pick)
        if case .relic(let relic) = reward { progress.seenRelics.insert(relic) }
        if case .stones(let kind, _) = reward { progress.seenStones.insert(kind) }
        r.take(reward)
        run = r
        resetBoardState()
        meet()
        Task {
            await wait(still ? 0 : 0.3)
            play(.descend)
            showFloorBanner()
        }
    }

    func retryFloor() {
        press()
        guard var r = run else { return }
        r.retry()
        run = r
        resetBoardState()
        showFloorBanner()
        play(.descend)
    }

    /// 引き返す（探索を終える。ここまでの最深が残る）
    func retreat() {
        press()
        guard var r = run, !r.isFinished else { return }
        r.retreat()
        run = r
        showPause = false
        record(r)
    }

    /// 盤を閉じてホームへ（探索は保存され、続きから遊べる）
    func leaveToHome() {
        press()
        showPause = false
        inRun = false
    }

    /// 探索のまとめからホームへ
    func finishAndGoHome() {
        press()
        run = nil
        inRun = false
        // 最初の探索のあとに 1 回だけ、Pro の案内
        if !paywallOffered && !isPro {
            paywallOffered = true
            Task {
                await wait(0.5)
                activeSheet = .paywall
            }
        }
    }

    // MARK: - 手応え

    func press() {
        pressTick += 1
        play(.tap)
    }

    func play(_ cue: SoundBox.Cue) {
        guard soundOn, !still else { return }
        SoundBox.shared.play(cue)
    }

    func wait(_ seconds: Double) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
    }
}
