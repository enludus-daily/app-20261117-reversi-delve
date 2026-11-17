import SwiftUI

/// 案内 3 ページ：石は宝石 → 特殊な石 → 毎日の迷宮と灯。動く見本つき
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var page = 0

    var body: some View {
        let zones: [Zone] = [.moss, .crystal, .magma]
        let pal = ZonePalette.of(zones[page])
        ZStack {
            DungeonBackdrop(palette: pal)
            VStack(spacing: 18) {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Octagon().fill(i == page ? pal.glow : pal.slabLight).frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 20)
                Spacer(minLength: 0)
                Group {
                    switch page {
                    case 0: FlipDemo(palette: pal).id(0)
                    case 1: StoneShowcase()
                    default: TorchPage(palette: pal)
                    }
                }
                .frame(height: 280)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                VStack(spacing: 10) {
                    Text(title)
                        .font(Theme.carved(26))
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.center)
                    Text(bodyText)
                        .font(Theme.label(15, weight: .regular))
                        .foregroundStyle(Theme.textSoft)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                Spacer(minLength: 0)
                Button(page < 2 ? tr("次へ", "Next") : tr("迷宮の入口へ", "To the entrance")) {
                    model.press()
                    if page < 2 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { page += 1 }
                    } else {
                        model.onboarded = true
                    }
                }
                .buttonStyle(CarvedButtonStyle(palette: pal, prominent: true))
                .accessibilityIdentifier(page < 2 ? "main.next" : "main.start")
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: Theme.maxWidth)
        }
        .animation(.easeOut(duration: 0.3), value: page)
    }

    private var title: String {
        switch page {
        case 0: tr("挟んで返す。石は宝石。", "Sandwich to flip. Stones are gems.")
        case 1: tr("宝石には、力がある", "Every gem has a power")
        default: tr("灯が尽きるまで、下へ", "Go down until your torches run out")
        }
    }

    private var bodyText: String {
        switch page {
        case 0: tr("いつものリバーシ。1 階 1 局で、勝てば下の階へ。階ごとに盤の形と番人が変わる。", "Classic reversi rules. Win a game to go down a floor. Every floor brings a new board and a new warden.")
        case 1: tr("勝つたびに、宝石か遺物を 3 つから 1 つ。炎の石は横一列を、錨の石は返されない。", "After each win, pick one of three gems or relics. Flame burns a whole row. Anchor never flips.")
        default: tr("負けると灯がひとつ消える。今日の迷宮は、だれが潜っても同じ盤。記録はこの端末の中だけ。", "Lose and a torch goes out. Today's Dungeon is the same for everyone. Your records stay on this device.")
        }
    }
}

/// 動く見本：小さな盤で、置いた石から近い順に石が返る（1 回だけ）
struct FlipDemo: View {
    let palette: ZonePalette
    @State private var board = Board(rows: [
        "......",
        ".xxxo.",
        "..xo..",
        "..ox..",
        "......",
        "......",
    ])
    @State private var placed: Pos?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let side: CGFloat = 240
        let cell = side / 6
        ZStack {
            BoardSlab(board: board, palette: palette)
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<6, id: \.self) { c in
                            let p = Pos(r, c)
                            ZStack {
                                if let s = board.stone(at: p) {
                                    StoneSprite(stone: s, size: cell * 0.8, delay: Double(board.distance(p, placed ?? Pos(1, 0))) * 0.055 + 0.05,
                                                placedNow: placed == p, reduceMotion: reduceMotion)
                                }
                            }
                            .frame(width: cell, height: cell)
                        }
                    }
                }
            }
        }
        .frame(width: side, height: side)
        .shadow(color: palette.glow.opacity(0.25), radius: 24)
        .task {
            try? await Task.sleep(for: .milliseconds(900))
            placed = Pos(1, 0)
            board.apply(Move(pos: Pos(1, 0), kind: .plain, side: .you))
            try? await Task.sleep(for: .milliseconds(1300))
            placed = Pos(4, 4)
            board.apply(Move(pos: Pos(4, 4), kind: .plain, side: .you))
        }
        .accessibilityHidden(true)
    }
}

/// 特殊な石の見本
struct StoneShowcase: View {
    var body: some View {
        let kinds = StoneKind.freeSpecials
        VStack(spacing: 12) {
            ForEach(kinds, id: \.self) { k in
                HStack(spacing: 12) {
                    GemView(side: .you, kind: k, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(k.name).font(Theme.label(15, weight: .bold)).foregroundStyle(Theme.text)
                        Text(k.detail).font(Theme.label(12, weight: .regular)).foregroundStyle(Theme.textSoft)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 32)
    }
}

/// 灯と、今日の迷宮
struct TorchPage: View {
    let palette: ZonePalette

    var body: some View {
        VStack(spacing: 24) {
            TorchRow(lit: 3, total: 3, size: 54, glow: palette.glow)
            DepthMap(current: 7, deepest: 7, limit: 9, showsLock: false, compact: true)
                .frame(width: 220)
        }
    }
}
