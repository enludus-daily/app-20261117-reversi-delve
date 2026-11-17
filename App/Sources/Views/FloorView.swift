import SwiftUI

/// 1 階の画面：上に階と番人と灯、真ん中に盤、下に石の袋とヒント。
/// Duo の内側など横に広いときは、盤を大きく、右に番人・袋・深さの地図を並べる
struct FloorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if let run = model.run {
            let pal = ZonePalette.of(run.zone)
            GeometryReader { geo in
                ZStack {
                    DungeonBackdrop(palette: pal)
                    if sizeClass == .regular && geo.size.width > 700 {
                        HStack(alignment: .top, spacing: 24) {
                            VStack(spacing: 12) {
                                FloorHeader(run: run)
                                ScoreBar(run: run)
                                BoardView(run: run, side: min(geo.size.height - 190, geo.size.width * 0.55, 640))
                            }
                            VStack(spacing: 14) {
                                WardenCard(run: run)
                                SatchelTray(run: run, vertical: true)
                                HintButton(run: run)
                                ScrollView { DepthMap(current: run.floor, deepest: run.deepest, limit: max(Dungeon.bottom, run.floor), showsLock: !model.isPro) }
                            }
                            .frame(maxWidth: 320)
                        }
                        .padding(24)
                    } else {
                        VStack(spacing: 10) {
                            FloorHeader(run: run)
                            WardenLine(run: run)
                            ScoreBar(run: run)
                            Spacer(minLength: 0)
                            BoardView(run: run, side: min(geo.size.width - 32, geo.size.height - 330, 520))
                            Spacer(minLength: 0)
                            SatchelTray(run: run, vertical: false)
                            HintButton(run: run)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                    }
                    if let banner = model.banner {
                        BannerView(banner: banner, palette: pal)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                    PhaseOverlay(run: run)
                    if model.showPause {
                        PauseOverlay(run: run)
                    }
                }
                .animation(model.reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: model.banner)
            }
        }
    }
}

/// 階・帯の名前・灯・中断のボタン
struct FloorHeader: View {
    @Environment(AppModel.self) private var model
    let run: Run

    var body: some View {
        let pal = ZonePalette.of(run.zone)
        HStack(spacing: 12) {
            RuneIconButton(symbol: "pause.fill", label: tr("中断", "Pause"), palette: pal) {
                model.press()
                model.showPause = true
            }
            .accessibilityIdentifier("main.menu")
            VStack(alignment: .leading, spacing: 0) {
                Text("B\(run.floor)")
                    .font(Theme.carved(30))
                    .kerning(-1)
                    .monospacedDigit()
                    .foregroundStyle(pal.glow)
                    .contentTransition(.numericText())
                Plaque(text: run.zone.name, color: pal.vein)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                TorchRow(lit: run.torches, total: max(run.torches, Dungeon.startTorches), size: 18, glow: pal.glow)
                if run.daily {
                    Text(tr("今日の迷宮", "Today's Dungeon"))
                        .font(Theme.label(10))
                        .foregroundStyle(Theme.textSoft)
                }
            }
        }
    }
}

/// 番人の一行（縦長の画面）
struct WardenLine: View {
    let run: Run

    var body: some View {
        let pal = ZonePalette.of(run.zone)
        HStack(spacing: 8) {
            GemView(side: .foe, size: 18)
            Text(run.warden.name)
                .font(Theme.label(13, weight: .bold))
                .foregroundStyle(Theme.text)
            Text(run.warden.line)
                .font(Theme.label(11, weight: .regular))
                .foregroundStyle(Theme.textSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(CarvedPanel(palette: pal, radius: Theme.radiusS))
    }
}

/// 番人の札（横に広い画面）
struct WardenCard: View {
    let run: Run

    var body: some View {
        let pal = ZonePalette.of(run.zone)
        VStack(alignment: .leading, spacing: 6) {
            Plaque(text: tr("この階の番人", "Warden"), color: pal.vein)
            HStack(spacing: 10) {
                GemView(side: .foe, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.warden.name).font(Theme.label(16, weight: .bold)).foregroundStyle(Theme.text)
                    Text(run.warden.line).font(Theme.label(12, weight: .regular)).foregroundStyle(Theme.textSoft)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CarvedPanel(palette: pal))
    }
}

/// 点（あなた vs 番人）と、いまの番
struct ScoreBar: View {
    @Environment(AppModel.self) private var model
    let run: Run

    var body: some View {
        let pal = ZonePalette.of(run.zone)
        let you = run.yourScore
        let foe = run.foeScore
        HStack(spacing: 10) {
            side(.you, score: you, active: run.turn == .you && !run.floorOver, pal: pal)
            // 天秤の帯：点の割合
            GeometryReader { g in
                let total = max(1, you + foe)
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.obsidianFacet)
                    Capsule().fill(LinearGradient(colors: [Theme.moon, Theme.moonFacet], startPoint: .leading, endPoint: .trailing))
                        .frame(width: g.size.width * CGFloat(you) / CGFloat(total))
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: you)
            }
            .frame(height: 6)
            side(.foe, score: foe, active: run.turn == .foe && !run.floorOver, pal: pal)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(CarvedPanel(palette: pal, radius: Theme.radiusM, lit: false))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trf("あなた %d 点、番人 %d 点", "You %d, warden %d", you, foe))
    }

    private func side(_ s: Side, score: Int, active: Bool, pal: ZonePalette) -> some View {
        HStack(spacing: 6) {
            if s == .foe {
                Text("\(score)").font(Theme.carved(22)).monospacedDigit().foregroundStyle(Theme.text).contentTransition(.numericText())
            }
            GemView(side: s, size: 24)
                .overlay(Octagon().stroke(active ? pal.glow : .clear, lineWidth: 2).frame(width: 32, height: 32))
            if s == .you {
                Text("\(score)").font(Theme.carved(22)).monospacedDigit().foregroundStyle(Theme.text).contentTransition(.numericText())
            }
        }
    }
}

/// 石の袋（ふつうの石と特殊な石）。押して選び、もう一度押すとふつうの石に戻る
struct SatchelTray: View {
    @Environment(AppModel.self) private var model
    let run: Run
    let vertical: Bool

    var body: some View {
        let pal = ZonePalette.of(run.zone)
        let kinds = run.heldKinds
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Plaque(text: tr("石の袋", "Satchel"), color: pal.vein)
                Spacer()
                Text(model.selectedKind == .plain ? tr("ふつうの石で打つ", "Playing a plain stone") : model.selectedKind.detail)
                    .font(Theme.label(11, weight: .regular))
                    .foregroundStyle(model.selectedKind == .plain ? Theme.textSoft : model.selectedKind.tint)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.8)
            }
            if kinds.isEmpty {
                Text(tr("袋は空。階を抜けると宝石がもらえる", "Empty. Clear floors to find gems."))
                    .font(Theme.label(12, weight: .regular))
                    .foregroundStyle(Theme.textSoft)
            } else {
                let layout = vertical ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
                layout {
                    ForEach(kinds, id: \.self) { kind in
                        chip(kind, count: run.charges(kind), pal: pal)
                    }
                }
            }
        }
        .padding(12)
        .background(CarvedPanel(palette: pal))
    }

    private func chip(_ kind: StoneKind, count: Int, pal: ZonePalette) -> some View {
        let on = model.selectedKind == kind
        return Button {
            model.select(kind)
        } label: {
            HStack(spacing: 6) {
                GemView(side: .you, kind: kind, size: 26)
                if vertical {
                    Text(kind.name).font(Theme.label(13)).foregroundStyle(Theme.text)
                }
                Text("×\(count)")
                    .font(Theme.carved(13, relativeTo: .caption))
                    .monospacedDigit()
                    .foregroundStyle(on ? pal.deep : Theme.text)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: Theme.radiusS).fill(on ? kind.tint : pal.slab))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusS).stroke(on ? Theme.goldSoft : pal.slabLight, lineWidth: 1))
            .scaleEffect(on ? 1.06 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: on)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("stone.\(kind.rawValue)")
        .accessibilityLabel(trf("%@、残り %d", "%@, %d left", kind.name, count))
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct HintButton: View {
    @Environment(AppModel.self) private var model
    let run: Run

    var body: some View {
        let pal = ZonePalette.of(run.zone)
        let unlimited = run.relics.contains(.lantern)
        Button {
            model.useHint()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.max")
                Text(run.turn == .you ? tr("灯りで照らす（ヒント）", "Light the way (hint)") : tr("番人の番…", "Warden's turn…"))
                if !unlimited {
                    Text("\(run.hintsLeft)").font(Theme.carved(14)).monospacedDigit()
                }
            }
        }
        .buttonStyle(CarvedButtonStyle(palette: pal))
        .disabled(run.turn != .you || model.busy || run.hintsLeft == 0 || run.floorOver)
        .accessibilityIdentifier("main.hint")
    }
}

/// 盤の上の一言
struct BannerView: View {
    let banner: Banner
    let palette: ZonePalette

    var body: some View {
        VStack(spacing: 4) {
            Text(banner.text)
                .font(Theme.carved(30))
                .foregroundStyle(palette.glowSoft)
                .kerning(1)
            if !banner.sub.isEmpty {
                Text(banner.sub).font(Theme.label(13)).foregroundStyle(Theme.text)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(
            Octagon().fill(palette.deep.opacity(0.92))
                .overlay(Octagon().stroke(palette.glow.opacity(0.8), lineWidth: 1.5))
                .shadow(color: palette.glow.opacity(0.4), radius: 18)
        )
    }
}
