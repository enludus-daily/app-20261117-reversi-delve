import SwiftUI

/// 迷宮の入口（地上のキャンプ）。今日の迷宮・続き・自由に潜る・最深の記録
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let pal = ZonePalette.of(.moss)
        ZStack {
            DungeonBackdrop(palette: pal)
            ScrollView {
                VStack(spacing: 16) {
                    TopBar()
                    if sizeClass == .regular {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(spacing: 16) {
                                Gate()
                                TodayCard()
                            }
                            VStack(spacing: 16) {
                                DepthCard()
                                ProCard()
                            }
                        }
                    } else {
                        Gate()
                        TodayCard()
                        DepthCard()
                        ProCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: sizeClass == .regular ? 900 : Theme.maxWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        // 主なボタンは、スクロールしなくても押せるように下に固定する
        .safeAreaInset(edge: .bottom) { DiveButtons() }
    }
}

private struct TopBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let pal = ZonePalette.of(.moss)
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("迷宮リバーシ", "Reversi Delve"))
                    .font(Theme.carved(26))
                    .foregroundStyle(Theme.text)
                Text(tr("石を宝石に。地下へ下りる。", "Your stones are gems. Go down."))
                    .font(Theme.label(12, weight: .regular))
                    .foregroundStyle(Theme.textSoft)
            }
            Spacer()
            RuneIconButton(symbol: "book.closed", label: tr("図鑑", "Codex"), palette: pal) {
                model.press()
                model.activeSheet = .codex
            }
            .accessibilityIdentifier("main.codex")
            RuneIconButton(symbol: "chart.bar.xaxis", label: tr("記録", "Records"), palette: pal) {
                model.press()
                model.activeSheet = .records
            }
            .accessibilityIdentifier("main.records")
            RuneIconButton(symbol: "gearshape", label: tr("設定", "Settings"), palette: pal) {
                model.press()
                model.activeSheet = .settings
            }
            .accessibilityIdentifier("main.settings")
        }
        .padding(.top, 8)
    }
}

/// 入口の門：石のアーチの奥に階段が下りていき、宝石が光る
private struct Gate: View {
    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let w = size.width
                let h = size.height
                let pal = ZonePalette.of(.moss)
                // アーチ
                var arch = Path()
                let inset: CGFloat = w * 0.18
                arch.move(to: CGPoint(x: inset, y: h))
                arch.addLine(to: CGPoint(x: inset, y: h * 0.42))
                arch.addQuadCurve(to: CGPoint(x: w - inset, y: h * 0.42), control: CGPoint(x: w / 2, y: -h * 0.05))
                arch.addLine(to: CGPoint(x: w - inset, y: h))
                arch.closeSubpath()
                ctx.fill(arch, with: .linearGradient(Gradient(colors: [.black, pal.deep]), startPoint: CGPoint(x: w / 2, y: h), endPoint: CGPoint(x: w / 2, y: 0)))
                ctx.stroke(arch, with: .color(pal.slabLight), lineWidth: 6)
                ctx.stroke(arch, with: .color(pal.slab), lineWidth: 3)
                // 奥へ下りる階段（だんだん狭く、暗く）
                for i in 0..<7 {
                    let t = CGFloat(i) / 7
                    let y = h - CGFloat(i) * h * 0.075
                    let half = (w / 2 - inset - 6) * (1 - t * 0.75)
                    let step = Path(CGRect(x: w / 2 - half, y: y - h * 0.05, width: half * 2, height: h * 0.045))
                    ctx.fill(step, with: .color(pal.slab.opacity(Double(1 - t * 0.85))))
                    ctx.fill(Path(CGRect(x: w / 2 - half, y: y - h * 0.05, width: half * 2, height: 1.5)), with: .color(pal.slabLight.opacity(Double(1 - t))))
                }
                // 灯り
                ctx.fill(Path(ellipseIn: CGRect(x: w / 2 - 70, y: h * 0.28, width: 140, height: 90)),
                         with: .radialGradient(Gradient(colors: [pal.glow.opacity(0.35), .clear]), center: CGPoint(x: w / 2, y: h * 0.33), startRadius: 0, endRadius: 70))
                // 苔
                var rng = SeededRandom(seed: 7)
                for _ in 0..<26 {
                    let side = rng.next() % 2 == 0
                    let x = side ? inset + CGFloat(rng.next() % 14) - 7 : w - inset + CGFloat(rng.next() % 14) - 7
                    let y = h * 0.45 + CGFloat(rng.next() % 1000) / 1000 * h * 0.55
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 4, height: 3)), with: .color(pal.vein.opacity(0.7)))
                }
            }
            .allowsHitTesting(false)
            HStack(spacing: 14) {
                GemView(side: .foe, size: 30)
                GemView(side: .you, kind: .flame, size: 40)
                GemView(side: .you, size: 30)
            }
            .offset(y: 4)
        }
        .frame(height: 170)
        .accessibilityHidden(true)
    }
}

/// 今日の迷宮（だれが潜っても同じ盤）と、続けた日の灯
private struct TodayCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let pal = ZonePalette.of(.moss)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Plaque(text: tr("今日の迷宮", "Today's Dungeon"), color: pal.glow)
                Spacer()
                Text(model.now.formatted(.dateTime.month().day()))
                    .font(Theme.carved(14))
                    .foregroundStyle(Theme.textSoft)
            }
            if model.dailyDone {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("B\(model.dailyBestToday)")
                        .font(Theme.carved(40))
                        .kerning(-2)
                        .monospacedDigit()
                        .foregroundStyle(pal.glow)
                    Text(tr("今日の最深。また明日、新しい迷宮が開く。", "Today's depth. A new dungeon opens tomorrow."))
                        .font(Theme.label(13, weight: .regular))
                        .foregroundStyle(Theme.text)
                }
            } else {
                Text(tr("だれが潜っても同じ盤と同じ宝石。1 日 1 回、どこまで下りられるか。", "Same boards and gems for everyone. One dive a day — how deep can you go?"))
                    .font(Theme.label(14, weight: .regular))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                TorchRow(lit: min(model.streak, 7), total: 7, size: 16, glow: pal.glow)
                Text(model.streak > 0 ? trf("%d 日続けて潜っている", "%d-day streak", model.streak) : tr("今日から灯をともそう", "Light your first torch today"))
                    .font(Theme.label(12, weight: .regular))
                    .foregroundStyle(Theme.textSoft)
            }
        }
        .padding(16)
        .background(CarvedPanel(palette: pal, radius: Theme.radiusL, lit: !model.dailyDone))
    }
}

/// 最深の記録と、階の帯の地図
private struct DepthCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let pal = ZonePalette.of(.moss)
        let best = model.progress.bestDepth
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Plaque(text: tr("最深の記録", "Deepest"), color: pal.vein)
                Spacer()
                Text(best > 0 ? "B\(best)" : "—")
                    .font(Theme.carved(28))
                    .monospacedDigit()
                    .foregroundStyle(Theme.gold)
            }
            HStack(spacing: 6) {
                ForEach(Zone.allCases, id: \.self) { z in
                    let zp = ZonePalette.of(z)
                    let reached = best >= (z.rawValue * 3 + 1)
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: Theme.radiusS)
                            .fill(LinearGradient(colors: [zp.slabLight, zp.deep], startPoint: .top, endPoint: .bottom))
                            .overlay(RoundedRectangle(cornerRadius: Theme.radiusS).stroke(reached ? zp.glow : zp.slabLight.opacity(0.4), lineWidth: reached ? 1.5 : 1))
                            .overlay {
                                if z == .star && !model.isPro {
                                    Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(Theme.textSoft)
                                } else {
                                    Circle().fill(reached ? zp.glow : .clear).frame(width: 6, height: 6)
                                }
                            }
                            .frame(height: 38)
                        Text(z.name).font(Theme.label(10)).foregroundStyle(reached ? Theme.text : Theme.textFaint).lineLimit(1).minimumScaleFactor(0.7)
                        Text(z.floors).font(Theme.label(9, weight: .regular)).foregroundStyle(Theme.textFaint)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 16) {
                small(tr("返した石", "Stones flipped"), "\(model.progress.totalFlips)")
                small(tr("探索", "Delves"), "\(model.progress.runs.count)")
                small(tr("倒した番人", "Wardens beaten"), "\(model.progress.beatenWardens.count)/\(Warden.all.count)")
            }
        }
        .padding(16)
        .background(CarvedPanel(palette: pal, radius: Theme.radiusL))
    }

    private func small(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(Theme.carved(17)).monospacedDigit().foregroundStyle(Theme.text)
            Text(label).font(Theme.label(10, weight: .regular)).foregroundStyle(Theme.textSoft)
        }
    }
}

/// Pro の案内（押し付けない。ホームの下の方に 1 枚だけ）
private struct ProCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if !model.isPro {
            let pal = ZonePalette.of(.star)
            Button {
                model.press()
                model.activeSheet = .paywall
            } label: {
                HStack(spacing: 12) {
                    HStack(spacing: -8) {
                        GemView(side: .you, kind: .echo, size: 30)
                        GemView(side: .you, kind: .ghost, size: 30)
                        GemView(side: .you, kind: .comet, size: 30)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("星の底へ（Pro）", "Down to the Starfloor (Pro)"))
                            .font(Theme.label(15, weight: .bold))
                            .foregroundStyle(pal.glowSoft)
                        Text(tr("10 階より深い階・魔法の石 3 種・探索の記録すべて", "Floors past 10, three magic stones, full delve log"))
                            .font(Theme.label(11, weight: .regular))
                            .foregroundStyle(Theme.textSoft)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(pal.glow)
                }
                .padding(14)
                .background(CarvedPanel(palette: pal, radius: Theme.radiusL, lit: true))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("pro.card")
        }
    }
}

/// 下に固定する主なボタン
private struct DiveButtons: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let pal = ZonePalette.of(.moss)
        VStack(spacing: 10) {
            if let run = model.run, !run.isFinished {
                Button {
                    model.resume()
                } label: {
                    Label(trf("続きから・地下 %d 階", "Resume · Floor %d", run.floor), systemImage: "arrow.down.right")
                }
                .buttonStyle(CarvedButtonStyle(palette: ZonePalette.of(run.zone), prominent: true))
                .accessibilityIdentifier("main.resume")
            } else {
                HStack(spacing: 10) {
                    if !model.dailyDone {
                        Button {
                            model.startDaily()
                        } label: {
                            Label(tr("今日の迷宮へ", "Today's dive"), systemImage: "stairs")
                        }
                        .buttonStyle(CarvedButtonStyle(palette: pal, prominent: true))
                        .accessibilityIdentifier("main.daily")
                    }
                    Button {
                        model.startDive()
                    } label: {
                        Label(tr("自由に潜る", "Free dive"), systemImage: "arrow.down.to.line")
                    }
                    .buttonStyle(CarvedButtonStyle(palette: pal, prominent: model.dailyDone))
                    .accessibilityIdentifier("main.dive")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: Theme.maxWidth)
        .frame(maxWidth: .infinity)
        .background(pal.deep.opacity(0.94).ignoresSafeArea(edges: .bottom))
    }
}
