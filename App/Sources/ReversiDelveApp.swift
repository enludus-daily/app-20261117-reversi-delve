import SwiftUI

@main
struct ReversiDelveApp: App {
    /// アプリ全体で 1 つだけ（App の init は何度も呼ばれることがあるので、ここで作り直さない）
    private let model = Launch.shared

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}

struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var model = model
        ZStack {
            if model.onboarded {
                HomeView()
                    .accessibilityHidden(model.inRun || model.activeSheet != nil)
            } else {
                OnboardingView()
            }
            // 盤はホームの上に重ねる層（全画面の表示の仕組みは使わない）
            if model.inRun, model.run != nil {
                FloorView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityHidden(model.activeSheet != nil)
                    .zIndex(1)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.86), value: model.inRun)
        .environment(model)
        // 地下の迷宮が世界。灯りの色が主役なので、画面はダークに固定する
        .preferredColorScheme(.dark)
        .sheet(item: $model.activeSheet) { sheet in
            SheetContent(sheet: sheet).environment(model).environment(\.locale, Lang.locale).preferredColorScheme(.dark)
        }
        // 手応えの表（README）：押す・置く・連鎖・失敗・階を抜けた・選んだ
        .sensoryFeedback(trigger: model.pressTick) { _, _ in model.hapticsOn ? .selection : nil }
        .sensoryFeedback(trigger: model.placeTick) { _, _ in model.hapticsOn ? .impact(weight: .light) : nil }
        .sensoryFeedback(trigger: model.chainTick) { _, _ in model.hapticsOn ? .impact(weight: .heavy) : nil }
        .sensoryFeedback(trigger: model.failTick) { _, _ in model.hapticsOn ? .error : nil }
        .sensoryFeedback(trigger: model.clearTick) { _, _ in model.hapticsOn ? .success : nil }
        .sensoryFeedback(trigger: model.pickTick) { _, _ in model.hapticsOn ? .impact(weight: .medium) : nil }
        .task { await Launch.run(model) }
        .task { await model.purchases.load() }
        .onAppear { model.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, v in model.reduceMotion = v }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !model.still { model.now = Date() }
        }
        .environment(\.locale, Lang.locale)
    }
}

struct SheetContent: View {
    let sheet: ActiveSheet
    var body: some View {
        switch sheet {
        case .settings: SettingsView()
        case .paywall: PaywallView()
        case .codex: CodexView()
        case .records: RecordsView()
        case .share: ShareCardSheet()
        }
    }
}

/// 見本の盤（撮影・デモ・UI テスト）
enum Samples {
    /// 1 階の終わり近く：空きは上の 2 つの隅だけ。どちらに置いても、番人はパスし、もう 1 つに置くと階を抜ける
    static let finaleRows = [
        ".xxox.",
        "ooxooo",
        "oxoooo",
        "ooooxo",
        "oooxoo",
        "ooxooo",
    ]

    static func applyFinale(to run: inout Run) {
        run.board = Board(rows: finaleRows)
        run.plan.holes = []
        run.plan.gilded = []
        run.turn = .you
    }

    /// 見本の探索：floor 階まで下りてきた形（袋の石・遺物・灯）
    static func run(floor: Int, plies: Int, seed: UInt64 = 20261117) -> Run {
        var r = Run(seed: seed, daily: true, dayKey: "2026-11-17")
        r.floor = floor
        r.relics = [.cornerstone, .lantern]
        r.satchel = [StoneKind.anchor.rawValue: 1, StoneKind.flame.rawValue: 2, StoneKind.hourglass.rawValue: 1, StoneKind.gold.rawValue: 1]
        r.torches = 2
        r.deepest = floor
        r.flipsTotal = 41 * floor
        r.specialsUsed = floor
        r.setupFloor()
        // 両方とも盤の形を読む打ち方で、plies 手まで進める（毎回同じ）
        var rng = SeededRandom(seed: seed)
        for i in 0..<plies {
            _ = r.beginTurn()
            if r.floorOver { break }
            if r.turn == .you {
                guard let p = Mind.choose(r.board, side: .you, style: .shrewd, careless: 0, rng: &rng) else { break }
                _ = r.play(p, kind: i == 4 ? .anchor : .plain)
            } else {
                _ = r.foeMove()
            }
        }
        _ = r.beginTurn()
        return r
    }
}

/// 起動の仕方：ふつう・撮影（-screenshotScene <名前>）・デモ（-demo）・UI テスト（-uiTestFresh）。
/// 撮影とデモは見本のデータで動かし、保存されたデータを書き換えない
@MainActor
enum Launch {
    /// 撮る画面の名前。後ろに _ja を付けると日本語で撮る（CI のシミュレータは英語のため）
    static var scene: String? {
        var value = UserDefaults.standard.string(forKey: "screenshotScene") ?? ""
        if value.hasSuffix("_ja") { value = String(value.dropLast(3)) }
        return value.isEmpty || value == "launch" ? nil : value
    }

    static var forcesJapanese: Bool {
        UserDefaults.standard.string(forKey: "screenshotScene")?.hasSuffix("_ja") ?? false
    }

    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }
    static var isFreshUITest: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestFresh") }

    static let shared: AppModel = makeModel()

    /// 撮影の日（決まった日にして、連続日数などが毎回同じになるように）
    static func stageDate() -> Date {
        var c = DateComponents()
        c.year = 2026
        c.month = 11
        c.day = 17
        c.hour = 22
        return Calendar.current.date(from: c) ?? Date()
    }

    static func makeModel() -> AppModel {
        Lang.forcedJapanese = forcesJapanese
        if isFreshUITest {
            for key in ["progress", "run", "onboarded", "sound", "haptics", "paywallOffered"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
            let model = AppModel()
            model.useSample = true
            model.soundOn = false
            return model
        }
        guard isDemo || scene != nil else { return AppModel() }
        let now = stageDate()
        let model = AppModel(persists: false, now: now)
        model.still = scene != nil
        model.useSample = true
        model.onboarded = scene != "onboarding"
        if scene != "fresh" && scene != "onboarding" {
            model.progress = samples(now: now, calendar: model.calendar)
        }
        return model
    }

    /// 見本の記録：きのうまで 5 日続けて今日の迷宮に潜り、最深は 8 階
    static func samples(now: Date, calendar: Calendar) -> Progress {
        var p = Progress()
        let depths = [6, 8, 5, 7, 4]
        for (i, d) in depths.enumerated() {
            let date = calendar.date(byAdding: .day, value: -(i + 1), to: now) ?? now
            p.dailyBest[Progress.dayKey(date, calendar: calendar)] = d
            p.runs.append(RunRecord(date: date, depth: d, daily: true, summit: false,
                                    relics: Array(Relic.allCases.prefix(i % 3 + 1)), flips: 38 * d, specials: d / 2 + 1))
            if i == 1 {
                p.runs.append(RunRecord(date: date, depth: 9, daily: false, summit: true, relics: [.prism, .quiver, .embers], flips: 402, specials: 7))
            }
        }
        p.bestDepth = 9
        p.seenStones = [.anchor, .flame, .hourglass, .gold, .echo]
        p.seenRelics = [.cornerstone, .prism, .quiver, .lantern, .embers]
        p.metWardens = Set(1...9)
        p.beatenWardens = Set(1...8)
        p.totalFlips = p.runs.map(\.flips).reduce(0, +)
        p.proTrialUsed = true
        return p
    }

    static func run(_ model: AppModel) async {
        if isDemo {
            await Demo.play(model)
            return
        }
        guard let scene else { return }
        try? await Task.sleep(for: .milliseconds(200))
        switch scene {
        case "floor", "select", "hint":
            model.run = Samples.run(floor: 5, plies: 14)
            model.inRun = true
            if scene == "select" { model.selectedKind = .flame }
            if scene == "hint" { model.hintPos = model.run.flatMap { Mind.hint($0.board) } }
        case "magma":
            model.run = Samples.run(floor: 8, plies: 22)
            model.inRun = true
        case "star":
            model.proOverride = true
            model.run = Samples.run(floor: 11, plies: 26)
            model.inRun = true
        case "reward":
            var r = Samples.run(floor: 4, plies: 0)
            r.lastResult = FloorResult(yours: 24, foes: 12)
            r.phase = .cleared([.stones(.hourglass, 2), .relic(.prism), .torch])
            model.run = r
            model.inRun = true
        case "fallen":
            var r = Samples.run(floor: 6, plies: 30)
            r.lastResult = FloorResult(yours: 14, foes: 22)
            r.phase = .fallen
            model.run = r
            model.inRun = true
        case "over", "summit", "share":
            var r = Samples.run(floor: scene == "over" ? 7 : 9, plies: 24)
            r.lastResult = scene == "over" ? FloorResult(yours: 15, foes: 26) : FloorResult(yours: 38, foes: 21)
            r.phase = scene == "over" ? .over : .summit
            r.torches = scene == "over" ? 0 : 1
            model.run = r
            model.finishedRun = r
            model.inRun = true
            if scene == "share" { model.activeSheet = .share }
        case "pause":
            model.run = Samples.run(floor: 5, plies: 14)
            model.inRun = true
            model.showPause = true
        case "resume":
            model.run = Samples.run(floor: 3, plies: 8)
        case "codex": model.activeSheet = .codex
        case "records": model.activeSheet = .records
        case "settings": model.activeSheet = .settings
        case "paywall": model.activeSheet = .paywall
        default: break
        }
    }
}

/// デモの再生（YouTube の録画用。人の操作なしで約 18 秒）
/// ホーム → 今日の迷宮 → 炎の石で横一列を返す → 番人はパス → 最後の隅 → 階を抜ける → 3 つから選ぶ → 次の階へ
@MainActor
enum Demo {
    static func play(_ model: AppModel) async {
        func wait(_ seconds: Double) async { try? await Task.sleep(for: .milliseconds(Int(seconds * 1000))) }
        await wait(2.2)
        model.startDaily()
        await wait(2.2)
        model.select(.flame)
        await wait(1.0)
        model.tap(Pos(0, 0))
        await wait(3.2)
        model.useHint()
        await wait(0.9)
        if let p = model.hintPos { model.tap(p) }
        await wait(3.6)
        if let r = model.run, case .cleared(let offer) = r.phase, let first = offer.first {
            model.take(first)
        }
    }
}
