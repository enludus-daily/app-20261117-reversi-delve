import SwiftUI

/// 階の終わり：抜けた（3 つから選ぶ）・負けた（やり直す）・探索の終わり
struct PhaseOverlay: View {
    @Environment(AppModel.self) private var model
    let run: Run

    var body: some View {
        switch run.phase {
        case .playing:
            EmptyView()
        case .cleared(let offer):
            Veil { RewardPanel(run: run, offer: offer) }
        case .fallen:
            Veil { FallenPanel(run: run) }
        case .over, .summit:
            Veil { RunEndPanel(run: model.finishedRun ?? run) }
        }
    }
}

/// 暗い幕（下の盤を押せなくする）
struct Veil<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.88).ignoresSafeArea()
            ScrollView {
                // 上を少し空けて、盤の上の見出しと重ならないようにする
                content
                    .padding(.horizontal, 16)
                    .padding(.top, 72)
                    .padding(.bottom, 20)
                    .frame(maxWidth: Theme.maxWidth)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .transition(.opacity)
    }
}

/// 結果の点（あなた : 番人）
struct ResultScore: View {
    let result: FloorResult?
    let palette: ZonePalette

    var body: some View {
        if let result {
            HStack(spacing: 14) {
                GemView(side: .you, size: 26)
                Text("\(result.yours)").font(Theme.carved(34)).monospacedDigit().foregroundStyle(Theme.text)
                Text(":").font(Theme.carved(24)).foregroundStyle(Theme.textSoft)
                Text("\(result.foes)").font(Theme.carved(34)).monospacedDigit().foregroundStyle(Theme.textSoft)
                GemView(side: .foe, size: 26)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(trf("あなた %d 点、番人 %d 点", "You %d, warden %d", result.yours, result.foes))
        }
    }
}

/// 階を抜けた：石・遺物・灯から 1 つ選ぶ
struct RewardPanel: View {
    @Environment(AppModel.self) private var model
    let run: Run
    let offer: [Reward]
    @State private var shown = false

    var body: some View {
        let pal = ZonePalette.of(run.zone)
        VStack(spacing: 16) {
            Plaque(text: trf("地下 %d 階を抜けた", "Floor %d cleared", run.floor), color: pal.glow)
            ResultScore(result: run.lastResult, palette: pal)
            Text(tr("ひとつ持って、下へ", "Take one, then go deeper"))
                .font(Theme.carved(22))
                .foregroundStyle(Theme.text)
            ForEach(Array(offer.enumerated()), id: \.offset) { i, reward in
                Button {
                    model.take(reward)
                } label: {
                    RuneCard(reward: reward, palette: pal, held: heldCount(reward))
                }
                .buttonStyle(CellPressStyle())
                .accessibilityIdentifier("main.reward.\(i)")
                // 札が下から順にせり上がる（押せる範囲が崩れないよう、回転は使わない）
                .offset(y: shown || model.reduceMotion ? 0 : 28)
                .opacity(shown || model.reduceMotion ? 1 : 0.2)
                .animation(.spring(response: 0.4, dampingFraction: 0.78).delay(Double(i) * 0.1), value: shown)
            }
            Text(trf("次は地下 %d 階・%@", "Next: Floor %d · %@", run.floor + 1, Zone.of(floor: run.floor + 1).name))
                .font(Theme.label(12, weight: .regular))
                .foregroundStyle(Theme.textSoft)
        }
        .onAppear { shown = true }
    }

    private func heldCount(_ reward: Reward) -> Int? {
        if case .stones(let k, _) = reward { return run.charges(k) }
        return nil
    }
}

/// 選べる札（彫った石の板）
struct RuneCard: View {
    let reward: Reward
    let palette: ZonePalette
    var held: Int?

    var body: some View {
        HStack(spacing: 14) {
            icon.frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Plaque(text: reward.kindLabel, color: palette.vein)
                    if case .stones(let k, _) = reward, k.isPro {
                        Text("PRO").font(Theme.label(9, weight: .heavy)).foregroundStyle(palette.deep)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(Theme.gold))
                    }
                }
                Text(reward.title).font(Theme.label(17, weight: .bold)).foregroundStyle(Theme.text)
                Text(reward.detail).font(Theme.label(12, weight: .regular)).foregroundStyle(Theme.textSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if let held, held > 0 {
                    Text(trf("いま %d 個", "You have %d", held)).font(Theme.label(11, weight: .regular)).foregroundStyle(palette.glow)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.down.2").foregroundStyle(palette.glow)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CarvedPanel(palette: palette, radius: Theme.radiusM, lit: true))
        .contentShape(Rectangle())
    }

    @ViewBuilder private var icon: some View {
        switch reward {
        case .stones(let k, _):
            GemView(side: .you, kind: k, size: 42)
        case .relic(let r):
            ZStack {
                Octagon().fill(palette.slab).overlay(Octagon().stroke(Theme.gold, lineWidth: 1.5))
                Image(systemName: r.symbol).font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.gold)
            }
        case .torch:
            FlameShape()
                .fill(LinearGradient(colors: [Theme.goldSoft, Theme.torch], startPoint: .top, endPoint: .bottom))
                .frame(width: 26, height: 38)
                .shadow(color: Theme.torch, radius: 8)
        }
    }
}

/// 負けた：灯を 1 つ使ってやり直すか、引き返すか
struct FallenPanel: View {
    @Environment(AppModel.self) private var model
    let run: Run

    var body: some View {
        let pal = ZonePalette.of(run.zone)
        VStack(spacing: 16) {
            Plaque(text: trf("地下 %d 階で敗れた", "Defeated on Floor %d", run.floor), color: Theme.danger)
            ResultScore(result: run.lastResult, palette: pal)
            TorchRow(lit: run.torches, total: run.torches + 1, size: 26, glow: pal.glow)
            Text(trf("灯がひとつ消えた。残り %d", "A torch went out. %d left", run.torches))
                .font(Theme.carved(20))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            Text(tr("同じ階を、新しい盤でやり直せる。袋の石と遺物はそのまま。", "Retry this floor on a new board. You keep your gems and relics."))
                .font(Theme.label(13, weight: .regular))
                .foregroundStyle(Theme.textSoft)
                .multilineTextAlignment(.center)
            Button(tr("灯をともして、やり直す", "Light a torch and retry")) { model.retryFloor() }
                .buttonStyle(CarvedButtonStyle(palette: pal, prominent: true))
                .accessibilityIdentifier("main.retry")
            Button(tr("ここで引き返す", "Head back to the surface")) { model.retreat() }
                .buttonStyle(CarvedButtonStyle(palette: pal))
                .accessibilityIdentifier("main.retreat")
        }
    }
}

/// 探索の終わり：届いた深さ・持ち帰った遺物・数字
struct RunEndPanel: View {
    @Environment(AppModel.self) private var model
    let run: Run

    var body: some View {
        let pal = ZonePalette.of(run.zone)
        let summit = run.phase == .summit
        VStack(spacing: 16) {
            Plaque(text: summit ? tr("溶岩の炉を抜けた", "You crossed the Magma Forge") : tr("探索のおわり", "The delve is over"), color: summit ? Theme.gold : pal.vein)
            Text("B\(run.deepest)")
                .font(Theme.carved(76))
                .kerning(-3)
                .monospacedDigit()
                .foregroundStyle(LinearGradient(colors: [pal.glowSoft, pal.glow], startPoint: .top, endPoint: .bottom))
                .shadow(color: pal.glow.opacity(0.5), radius: 16)
            Text(trf("地下 %d 階まで下りた", "You reached Floor %d", run.deepest))
                .font(Theme.label(15))
                .foregroundStyle(Theme.text)
            if run.deepest >= model.progress.bestDepth {
                Text(tr("最深の記録を更新", "New depth record"))
                    .font(Theme.label(11, weight: .heavy))
                    .kerning(1)
                    .foregroundStyle(pal.deep)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Theme.gold))
            }
            HStack(spacing: 10) {
                stat(tr("返した石", "Stones flipped"), "\(run.flipsTotal)", pal)
                stat(tr("使った宝石", "Gems used"), "\(run.specialsUsed)", pal)
                stat(tr("持ち帰った遺物", "Relics"), "\(run.relics.count)", pal)
            }
            if !run.relics.isEmpty {
                HStack(spacing: 8) {
                    ForEach(run.relics, id: \.self) { r in
                        Image(systemName: r.symbol)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.gold)
                            .frame(width: 32, height: 32)
                            .background(Octagon().fill(pal.slab))
                            .accessibilityLabel(r.name)
                    }
                }
            }
            if summit && !model.isPro {
                VStack(spacing: 8) {
                    Text(tr("この下に、星の底が続いている", "Below lies the Starfloor"))
                        .font(Theme.carved(18))
                        .foregroundStyle(Theme.goldSoft)
                    Text(tr("Pro で 10 階より深く。番人 4 人と、こだま・幽霊・彗星の石。", "Go past Floor 10 with Pro: four more wardens and the Echo, Ghost and Comet stones."))
                        .font(Theme.label(12, weight: .regular))
                        .foregroundStyle(Theme.textSoft)
                        .multilineTextAlignment(.center)
                    Button(tr("星の底をのぞく", "See the Starfloor")) {
                        model.press()
                        model.activeSheet = .paywall
                    }
                    .buttonStyle(CarvedButtonStyle(palette: ZonePalette.of(.star), prominent: true))
                }
                .padding(14)
                .background(CarvedPanel(palette: ZonePalette.of(.star), lit: true))
            }
            Button {
                model.press()
                model.activeSheet = .share
            } label: {
                Label(tr("深さを共有", "Share your depth"), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(CarvedButtonStyle(palette: pal))
            .accessibilityIdentifier("main.share")
            Button(tr("地上へもどる", "Back to the surface")) { model.finishAndGoHome() }
                .buttonStyle(CarvedButtonStyle(palette: pal, prominent: true))
                .accessibilityIdentifier("main.home")
        }
    }

    private func stat(_ label: String, _ value: String, _ pal: ZonePalette) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Theme.carved(22)).monospacedDigit().foregroundStyle(Theme.text)
            Text(label).font(Theme.label(10, weight: .regular)).foregroundStyle(Theme.textSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(CarvedPanel(palette: pal, radius: Theme.radiusS))
    }
}

/// 中断：続ける・地上で休む（続きから）・引き返す
struct PauseOverlay: View {
    @Environment(AppModel.self) private var model
    let run: Run

    var body: some View {
        let pal = ZonePalette.of(run.zone)
        Veil {
            VStack(spacing: 14) {
                Plaque(text: tr("ひと休み", "Paused"), color: pal.vein)
                Text(trf("地下 %d 階・%@", "Floor %d · %@", run.floor, run.zone.name))
                    .font(Theme.carved(22))
                    .foregroundStyle(Theme.text)
                DepthMap(current: run.floor, deepest: run.deepest, limit: max(Dungeon.bottom, run.floor), showsLock: !model.isPro, compact: true)
                    .padding(12)
                    .background(CarvedPanel(palette: pal))
                if !run.relics.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Plaque(text: tr("持っている遺物", "Your relics"), color: pal.vein)
                        ForEach(run.relics, id: \.self) { r in
                            HStack(spacing: 8) {
                                Image(systemName: r.symbol).foregroundStyle(Theme.gold).frame(width: 20)
                                Text(r.name).font(Theme.label(13)).foregroundStyle(Theme.text)
                                Text(r.detail).font(Theme.label(11, weight: .regular)).foregroundStyle(Theme.textSoft).lineLimit(2)
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CarvedPanel(palette: pal))
                }
                Button(tr("つづける", "Keep going")) {
                    model.press()
                    model.showPause = false
                }
                .buttonStyle(CarvedButtonStyle(palette: pal, prominent: true))
                .accessibilityIdentifier("main.resume")
                Button(tr("地上で休む（あとで続きから）", "Rest on the surface (resume later)")) { model.leaveToHome() }
                    .buttonStyle(CarvedButtonStyle(palette: pal))
                    .accessibilityIdentifier("main.leave")
                Button(tr("引き返して、探索を終える", "Turn back and end the delve")) { model.retreat() }
                    .buttonStyle(CarvedButtonStyle(palette: pal))
                    .accessibilityIdentifier("main.retreat")
            }
        }
    }
}
