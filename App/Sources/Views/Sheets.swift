import StoreKit
import SwiftUI

/// シートの共通の枠：迷宮の背景・題字・閉じるボタン
struct SheetFrame<Content: View>: View {
    @Environment(AppModel.self) private var model
    let title: String
    let zone: Zone
    let closeID: String
    @ViewBuilder let content: Content

    var body: some View {
        let pal = ZonePalette.of(zone)
        ZStack {
            DungeonBackdrop(palette: pal)
            VStack(spacing: 0) {
                HStack {
                    Text(title).font(Theme.carved(24)).foregroundStyle(Theme.text)
                    Spacer()
                    RuneIconButton(symbol: "xmark", label: tr("閉じる", "Close"), palette: pal) {
                        model.press()
                        model.activeSheet = nil
                    }
                    .accessibilityIdentifier(closeID)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
                ScrollView {
                    VStack(spacing: 14) { content }
                        .padding(16)
                        .frame(maxWidth: Theme.maxWidth)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - 図鑑

struct CodexView: View {
    @Environment(AppModel.self) private var model
    @State private var tab = 0

    var body: some View {
        let pal = ZonePalette.of(.crystal)
        SheetFrame(title: tr("図鑑", "Codex"), zone: .crystal, closeID: "main.closeCodex") {
            HStack(spacing: 6) {
                tabButton(0, tr("宝石", "Gems"), pal)
                tabButton(1, tr("遺物", "Relics"), pal)
                tabButton(2, tr("番人", "Wardens"), pal)
            }
            switch tab {
            case 0: gems(pal)
            case 1: relics(pal)
            default: wardens(pal)
            }
        }
    }

    private func tabButton(_ i: Int, _ label: String, _ pal: ZonePalette) -> some View {
        Button {
            model.press()
            tab = i
        } label: {
            Text(label)
                .font(Theme.label(14, weight: .bold))
                .foregroundStyle(tab == i ? pal.deep : Theme.text)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: Theme.radiusS).fill(tab == i ? pal.glow : pal.slab))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(tab == i ? .isSelected : [])
    }

    private func gems(_ pal: ZonePalette) -> some View {
        let seen = model.progress.seenStones
        return VStack(spacing: 10) {
            Text(trf("見つけた宝石 %d / %d", "Gems found %d / %d", seen.count, StoneKind.specials.count))
                .font(Theme.label(12, weight: .regular)).foregroundStyle(Theme.textSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(StoneKind.specials, id: \.self) { k in
                let known = seen.contains(k)
                HStack(spacing: 12) {
                    GemView(side: .you, kind: known ? k : .plain, size: 40).opacity(known ? 1 : 0.35)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(known ? k.name : "？？？").font(Theme.label(15, weight: .bold)).foregroundStyle(Theme.text)
                            if k.isPro { proTag(pal) }
                        }
                        Text(known ? k.detail : tr("まだ見つけていない。深い階で出会える。", "Not found yet. Look deeper."))
                            .font(Theme.label(12, weight: .regular)).foregroundStyle(Theme.textSoft)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(CarvedPanel(palette: pal))
            }
        }
    }

    private func relics(_ pal: ZonePalette) -> some View {
        let seen = model.progress.seenRelics
        return VStack(spacing: 10) {
            Text(trf("見つけた遺物 %d / %d", "Relics found %d / %d", seen.count, Relic.allCases.count))
                .font(Theme.label(12, weight: .regular)).foregroundStyle(Theme.textSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Relic.allCases, id: \.self) { r in
                let known = seen.contains(r)
                HStack(spacing: 12) {
                    Image(systemName: known ? r.symbol : "questionmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(known ? Theme.gold : Theme.textFaint)
                        .frame(width: 40, height: 40)
                        .background(Octagon().fill(pal.slab).overlay(Octagon().stroke(known ? Theme.gold : pal.slabLight, lineWidth: 1)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(known ? r.name : "？？？").font(Theme.label(15, weight: .bold)).foregroundStyle(Theme.text)
                        Text(known ? r.detail : tr("階を抜けたときに、選べることがある。", "Sometimes offered after a floor."))
                            .font(Theme.label(12, weight: .regular)).foregroundStyle(Theme.textSoft)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(CarvedPanel(palette: pal))
            }
        }
    }

    private func wardens(_ pal: ZonePalette) -> some View {
        let met = model.progress.metWardens
        let beaten = model.progress.beatenWardens
        return VStack(spacing: 10) {
            Text(trf("倒した番人 %d / %d", "Wardens beaten %d / %d", beaten.count, Warden.all.count))
                .font(Theme.label(12, weight: .regular)).foregroundStyle(Theme.textSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Warden.all) { w in
                let zp = ZonePalette.of(Zone.of(floor: w.id))
                let known = met.contains(w.id)
                HStack(spacing: 12) {
                    Text("B\(w.id)")
                        .font(Theme.carved(16)).monospacedDigit()
                        .foregroundStyle(zp.glow)
                        .frame(width: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(known ? w.name : "？？？").font(Theme.label(15, weight: .bold)).foregroundStyle(Theme.text)
                            if w.id > Dungeon.freeDepth { proTag(pal) }
                        }
                        Text(known ? w.line : Zone.of(floor: w.id).name)
                            .font(Theme.label(12, weight: .regular)).foregroundStyle(Theme.textSoft)
                    }
                    Spacer(minLength: 0)
                    if beaten.contains(w.id) {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.gold).accessibilityLabel(tr("倒した", "Beaten"))
                    }
                }
                .padding(12)
                .background(CarvedPanel(palette: zp))
            }
        }
    }

    private func proTag(_ pal: ZonePalette) -> some View {
        Text("PRO").font(Theme.label(9, weight: .heavy)).foregroundStyle(pal.deep)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Capsule().fill(Theme.gold))
    }
}

// MARK: - 記録

struct RecordsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let pal = ZonePalette.of(.magma)
        let runs = model.progress.runs
        let visible = model.isPro ? runs : Array(runs.prefix(5))
        SheetFrame(title: tr("探索の記録", "Delve Log"), zone: .magma, closeID: "main.closeRecords") {
            HStack(spacing: 10) {
                big(tr("最深", "Deepest"), model.progress.bestDepth > 0 ? "B\(model.progress.bestDepth)" : "—", pal)
                big(tr("続けた日", "Streak"), "\(model.streak)", pal)
                big(tr("探索", "Delves"), "\(runs.count)", pal)
            }
            WeekChart(model: model, palette: pal)
            Plaque(text: tr("これまでの探索", "Past delves"), color: pal.vein)
                .frame(maxWidth: .infinity, alignment: .leading)
            if runs.isEmpty {
                VStack(spacing: 8) {
                    Text(tr("まだ探索の記録がない", "No delves yet"))
                        .font(Theme.label(15, weight: .bold)).foregroundStyle(Theme.text)
                    Text(tr("ホームの「今日の迷宮へ」から、最初の 1 回を。", "Start with Today's dive on the home screen."))
                        .font(Theme.label(12, weight: .regular)).foregroundStyle(Theme.textSoft)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(CarvedPanel(palette: pal))
            }
            ForEach(visible) { r in
                HStack(spacing: 12) {
                    Text("B\(r.depth)")
                        .font(Theme.carved(24)).monospacedDigit()
                        .foregroundStyle(ZonePalette.of(Zone.of(floor: r.depth)).glow)
                        .frame(width: 56, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(r.date.formatted(.dateTime.month().day().hour().minute()))
                            .font(Theme.label(12)).foregroundStyle(Theme.text)
                        Text(r.daily ? tr("今日の迷宮", "Today's Dungeon") : tr("自由な探索", "Free dive"))
                            .font(Theme.label(11, weight: .regular)).foregroundStyle(Theme.textSoft)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(r.relics.prefix(4), id: \.self) { rel in
                            Image(systemName: rel.symbol).font(.system(size: 11)).foregroundStyle(Theme.gold)
                        }
                    }
                    Text(trf("%d 返し", "%d flips", r.flips))
                        .font(Theme.label(11, weight: .regular)).monospacedDigit().foregroundStyle(Theme.textSoft)
                }
                .padding(12)
                .background(CarvedPanel(palette: pal, radius: Theme.radiusS))
            }
            if !model.isPro && runs.count > 5 {
                Button {
                    model.press()
                    model.activeSheet = .paywall
                } label: {
                    Label(trf("ほか %d 回の探索は Pro で", "%d more delves with Pro", runs.count - 5), systemImage: "lock.fill")
                }
                .buttonStyle(CarvedButtonStyle(palette: pal))
            }
        }
    }

    private func big(_ label: String, _ value: String, _ pal: ZonePalette) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.carved(28)).monospacedDigit().foregroundStyle(Theme.text)
            Text(label).font(Theme.label(11, weight: .regular)).foregroundStyle(Theme.textSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(CarvedPanel(palette: pal))
    }
}

/// この 7 日の、今日の迷宮の深さ（縦に下りる棒）
struct WeekChart: View {
    let model: AppModel
    let palette: ZonePalette

    var body: some View {
        let days = (0..<7).reversed().compactMap { model.calendar.date(byAdding: .day, value: -$0, to: model.now) }
        VStack(alignment: .leading, spacing: 8) {
            Plaque(text: tr("この 7 日の今日の迷宮", "Today's Dungeon, last 7 days"), color: palette.vein)
            HStack(alignment: .top, spacing: 8) {
                ForEach(days, id: \.self) { d in
                    let depth = model.progress.dailyBest[Progress.dayKey(d, calendar: model.calendar)] ?? 0
                    VStack(spacing: 4) {
                        Text(d.formatted(.dateTime.weekday(.narrow))).font(Theme.label(10)).foregroundStyle(Theme.textSoft)
                        // 深いほど下へ長く伸びる
                        RoundedRectangle(cornerRadius: 3)
                            .fill(depth > 0 ? AnyShapeStyle(LinearGradient(colors: [palette.glowSoft, ZonePalette.of(Zone.of(floor: depth)).glow], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(palette.slab))
                            .frame(height: max(6, CGFloat(depth) * 9))
                        Text(depth > 0 ? "B\(depth)" : "·").font(Theme.carved(11)).monospacedDigit().foregroundStyle(Theme.text)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 140, alignment: .top)
        }
        .padding(12)
        .background(CarvedPanel(palette: palette))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("この 7 日の今日の迷宮の深さ", "Depth of Today's Dungeon over the last 7 days"))
    }
}

// MARK: - 設定

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let pal = ZonePalette.of(.moss)
        SheetFrame(title: tr("設定", "Settings"), zone: .moss, closeID: "main.closeSettings") {
            VStack(spacing: 0) {
                Toggle(tr("効果音", "Sound effects"), isOn: $model.soundOn).padding(14)
                Divider().overlay(pal.slabLight)
                Toggle(tr("振動", "Haptics"), isOn: $model.hapticsOn).padding(14)
            }
            .font(Theme.label(15))
            .foregroundStyle(Theme.text)
            .tint(pal.glow)
            .background(CarvedPanel(palette: pal))
            VStack(alignment: .leading, spacing: 10) {
                Plaque(text: "Pro", color: Theme.gold)
                Text(model.isPro ? tr("Pro を使っています。ありがとう。", "You have Pro. Thank you.") : tr("10 階より深い階・魔法の石 3 種・探索の記録すべて", "Floors past 10, three magic stones, full delve log"))
                    .font(Theme.label(13, weight: .regular)).foregroundStyle(Theme.text)
                if !model.isPro {
                    Button(tr("Pro でできること", "What Pro adds")) {
                        model.press()
                        model.activeSheet = .paywall
                    }
                    .buttonStyle(CarvedButtonStyle(palette: pal, prominent: true))
                }
                Button(tr("購入を復元", "Restore purchases")) {
                    Task { await model.purchases.restore() }
                }
                .buttonStyle(CarvedButtonStyle(palette: pal))
            }
            .padding(14)
            .background(CarvedPanel(palette: pal))
            VStack(alignment: .leading, spacing: 10) {
                Button(tr("案内をもう一度見る", "Show the intro again")) {
                    model.activeSheet = nil
                    model.onboarded = false
                }
                .buttonStyle(CarvedButtonStyle(palette: pal))
                Text(tr("記録はこの端末の中だけに残ります。ログイン・広告・解析はありません。", "Your records stay on this device. No login, ads or analytics."))
                    .font(Theme.label(12, weight: .regular)).foregroundStyle(Theme.textSoft)
                Text(tr("ルール：リバーシ（挟んだ石を返す）。番人の打ち方は階ごとに決まった簡単な規則です。", "Rules: reversi (sandwich to flip). Each warden follows one simple, fixed play style."))
                    .font(Theme.label(12, weight: .regular)).foregroundStyle(Theme.textSoft)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CarvedPanel(palette: pal))
        }
    }
}

// MARK: - Pro

struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @State private var working = false
    @State private var message: String?

    var body: some View {
        let pal = ZonePalette.of(.star)
        SheetFrame(title: tr("星の底へ", "To the Starfloor"), zone: .star, closeID: "main.closePaywall") {
            VStack(spacing: 6) {
                Text(tr("迷宮リバーシ Pro", "Reversi Delve Pro"))
                    .font(Theme.carved(28)).foregroundStyle(pal.glowSoft)
                Text(tr("買い切り。いちど買えば、ずっと。", "One-time purchase. Yours for good."))
                    .font(Theme.label(13, weight: .regular)).foregroundStyle(Theme.textSoft)
            }
            feature(pal, icon: AnyView(VStack(spacing: 0) {
                Text("B10+").font(Theme.carved(30)).foregroundStyle(LinearGradient(colors: [pal.glowSoft, pal.glow], startPoint: .top, endPoint: .bottom))
                Text(Zone.star.name).font(Theme.label(11)).foregroundStyle(pal.vein)
            }),
                    title: tr("9 階より深く", "Past Floor 9"),
                    detail: tr("星の底（10〜12 階）の番人 3 人と、その先に続く深淵。最深の記録に終わりがなくなる。", "The Starfloor (Floors 10–12), three more wardens, and an abyss with no bottom."))
            feature(pal, icon: AnyView(HStack(spacing: -6) {
                GemView(side: .you, kind: .echo, size: 34)
                GemView(side: .you, kind: .ghost, size: 34)
                GemView(side: .you, kind: .comet, size: 34)
            }),
                    title: tr("魔法の石 3 種", "Three magic stones"),
                    detail: tr("こだま（もう 1 手）・幽霊（穴の上に置ける）・彗星（縦一列を返す）が、階の報酬に出る。", "Echo (extra turn), Ghost (place over pits) and Comet (burn a column) join the rewards."))
            feature(pal, icon: AnyView(Image(systemName: "chart.bar.xaxis").font(.system(size: 30)).foregroundStyle(Theme.gold)),
                    title: tr("探索の記録すべて", "Your full delve log"),
                    detail: tr("無料は最近の 5 回まで。Pro はすべての探索と持ち帰った遺物を残す。", "Free keeps your last 5 delves. Pro keeps every delve and its relics."))
            priceArea(pal)
            Text(tr("核の遊び（1〜9 階・今日の迷宮・図鑑）は、ずっと無料です。", "The core game — Floors 1–9, Today's Dungeon and the Codex — stays free."))
                .font(Theme.label(12, weight: .regular)).foregroundStyle(Theme.textSoft).multilineTextAlignment(.center)
        }
    }

    private func feature(_ pal: ZonePalette, icon: AnyView, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            icon.frame(width: 120, height: 70)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Theme.label(16, weight: .bold)).foregroundStyle(Theme.text)
                Text(detail).font(Theme.label(12, weight: .regular)).foregroundStyle(Theme.textSoft).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(CarvedPanel(palette: pal))
    }

    @ViewBuilder private func priceArea(_ pal: ZonePalette) -> some View {
        let store = model.purchases
        VStack(spacing: 10) {
            if model.isPro {
                Text(tr("Pro を使っています。ありがとう。", "You have Pro. Thank you.")).font(Theme.label(15, weight: .bold)).foregroundStyle(Theme.gold)
            } else if let product = store.products.first {
                Button {
                    working = true
                    Task {
                        let outcome = await store.purchase(product)
                        working = false
                        switch outcome {
                        case .purchased: message = tr("ありがとう。星の底が開いた。", "Thank you. The Starfloor is open.")
                        case .pending: message = tr("承認を待っています。", "Waiting for approval.")
                        case .failed: message = tr("購入できませんでした。時間をおいて、もう一度。", "The purchase didn't go through. Please try again later.")
                        case .cancelled: break
                        }
                    }
                } label: {
                    Text(trf("%@ で Pro にする", "Get Pro for %@", product.displayPrice))
                }
                .buttonStyle(CarvedButtonStyle(palette: pal, prominent: true))
                .disabled(working)
                .accessibilityIdentifier("paywall.buy")
            } else if store.loadState == .loading || store.loadState == .idle {
                ProgressView().tint(pal.glow)
                Text(tr("値段を読み込んでいます…", "Loading the price…")).font(Theme.label(12, weight: .regular)).foregroundStyle(Theme.textSoft)
            } else {
                Text(tr("いまは購入できません。通信できる所で、あとでもう一度開いてください。", "Purchases aren't available right now. Please try again later with a connection."))
                    .font(Theme.label(13, weight: .regular)).foregroundStyle(Theme.text).multilineTextAlignment(.center)
                Button(tr("もう一度読み込む", "Try again")) { Task { await store.load() } }
                    .buttonStyle(CarvedButtonStyle(palette: pal))
            }
            if let message {
                Text(message).font(Theme.label(13)).foregroundStyle(pal.glowSoft)
            }
            Button(tr("購入を復元", "Restore purchases")) {
                Task {
                    await store.restore()
                    message = model.isPro ? tr("Pro を復元しました。", "Pro restored.") : tr("復元できる購入は見つかりませんでした。", "No purchases to restore.")
                }
            }
            .buttonStyle(CarvedButtonStyle(palette: pal))
        }
        .padding(14)
        .background(CarvedPanel(palette: pal, lit: true))
    }
}

// MARK: - 共有

/// 共有のカード（360×640 を 3 倍で書き出す）
struct ShareCard: View {
    let run: Run

    var body: some View {
        let pal = ZonePalette.of(run.zone)
        ZStack {
            DungeonBackdrop(palette: pal)
            VStack(spacing: 16) {
                Text(tr("迷宮リバーシ", "Reversi Delve")).font(Theme.carved(22)).foregroundStyle(Theme.text)
                Text(run.daily ? run.dayKey : tr("自由な探索", "Free dive")).font(Theme.label(12, weight: .regular)).foregroundStyle(Theme.textSoft)
                Spacer()
                Text("B\(run.deepest)")
                    .font(Theme.carved(110)).kerning(-4).monospacedDigit()
                    .foregroundStyle(LinearGradient(colors: [pal.glowSoft, pal.glow], startPoint: .top, endPoint: .bottom))
                    .shadow(color: pal.glow.opacity(0.5), radius: 20)
                Text(Zone.of(floor: run.deepest).name).font(Theme.label(16, weight: .bold)).foregroundStyle(pal.vein)
                HStack(spacing: 8) {
                    ForEach(run.relics, id: \.self) { r in
                        Image(systemName: r.symbol).foregroundStyle(Theme.gold)
                            .frame(width: 34, height: 34)
                            .background(Octagon().fill(pal.slab))
                    }
                }
                Text(trf("%d 個の石を返した", "%d stones flipped", run.flipsTotal)).font(Theme.label(14)).foregroundStyle(Theme.text)
                Spacer()
                HStack(spacing: 10) {
                    GemView(side: .you, size: 22)
                    GemView(side: .you, kind: .flame, size: 22)
                    GemView(side: .foe, size: 22)
                }
                Text(tr("どこまで下りられる？", "How deep can you go?")).font(Theme.label(12, weight: .regular)).foregroundStyle(Theme.textSoft)
            }
            .padding(28)
        }
        .frame(width: 360, height: 640)
    }
}

struct ShareCardSheet: View {
    @Environment(AppModel.self) private var model
    /// 共有の画像は、開いたときに 1 回だけ作る（body の中で作ると、画面が変わるたびに重い書き出しが走る）
    @State private var image: Image?

    var body: some View {
        let run = model.finishedRun ?? model.run
        SheetFrame(title: tr("深さを共有", "Share your depth"), zone: run?.zone ?? .moss, closeID: "main.closeShare") {
            if let run {
                ShareCard(run: run)
                    .scaleEffect(0.8)
                    .frame(width: 288, height: 512)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusL))
                    .accessibilityElement(children: .combine)
                if let image {
                    ShareLink(item: image, preview: SharePreview(tr("迷宮リバーシ", "Reversi Delve"), image: image)) {
                        Label(tr("画像を共有", "Share image"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(CarvedButtonStyle(palette: ZonePalette.of(run.zone), prominent: true))
                } else {
                    ProgressView().tint(Theme.gold).frame(minHeight: 52)
                }
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            guard image == nil, let run else { return }
            image = render(ShareCard(run: run))
        }
    }

    @MainActor private func render(_ card: ShareCard) -> Image? {
        let renderer = ImageRenderer(content: card.environment(\.locale, Lang.locale))
        renderer.scale = 3
        guard let ui = renderer.uiImage else { return nil }
        return Image(uiImage: ui)
    }
}
