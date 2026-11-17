import SwiftUI

/// 彫った石の盤。マスの石材・穴・金のはめこみは Canvas で描き、石とボタンを上に重ねる
struct BoardView: View {
    @Environment(AppModel.self) private var model
    let run: Run
    let side: CGFloat

    var body: some View {
        let board = run.board
        let n = board.size
        let cell = side / CGFloat(n)
        let pal = ZonePalette.of(run.zone)
        let legal = model.legalCells
        let tint = model.selectedKind == .plain ? pal.glow : model.selectedKind.tint
        ZStack {
            BoardSlab(board: board, palette: pal)
            VStack(spacing: 0) {
                ForEach(0..<n, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<n, id: \.self) { c in
                            let p = Pos(r, c)
                            CellButton(pos: p, stone: board.stone(at: p), tile: board.tile(at: p), cell: cell,
                                       legal: legal.contains(p), tint: tint, hinted: model.hintPos == p,
                                       burst: model.burstCells.contains(p), palette: pal)
                        }
                    }
                }
            }
            if let e = model.lastEffect, e.move.kind == .flame || e.move.kind == .comet {
                BlastStreak(kind: e.move.kind, index: e.move.kind == .flame ? e.move.pos.r : e.move.pos.c, n: n, side: side)
                    .id(model.placeTick)
            }
        }
        .frame(width: side, height: side)
        .modifier(ShakeEffect(amount: CGFloat(model.shake)))
        .animation(model.reduceMotion ? nil : .linear(duration: 0.45), value: model.shake)
        .id(run.floor * 100 + run.attempt)
    }
}

/// 盤の石材（Canvas。ボタンの当たり判定を持たない）
struct BoardSlab: View {
    let board: Board
    let palette: ZonePalette

    var body: some View {
        Canvas { ctx, size in
            let n = board.size
            let cell = size.width / CGFloat(n)
            let frame = Path(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: -6, dy: -6), cornerRadius: Theme.radiusM)
            ctx.fill(frame, with: .color(palette.slabEdge))
            ctx.stroke(frame, with: .color(palette.slabLight.opacity(0.7)), lineWidth: 1.5)
            for p in board.positions {
                let rect = CGRect(x: CGFloat(p.c) * cell, y: CGFloat(p.r) * cell, width: cell, height: cell).insetBy(dx: 1.5, dy: 1.5)
                let tile = board.tile(at: p)
                if tile == .hole {
                    // 穴：暗い底へ落ちていく
                    let pit = Path(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerRadius: Theme.radiusS)
                    ctx.fill(pit, with: .radialGradient(Gradient(colors: [.black, palette.deep]), center: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0, endRadius: cell * 0.6))
                    ctx.stroke(pit, with: .color(palette.slabEdge), lineWidth: 1)
                    continue
                }
                let slab = Path(roundedRect: rect, cornerRadius: Theme.radiusS)
                ctx.fill(slab, with: .color(palette.slab))
                // 上と左が明るく、下と右が暗い縁（彫った石）
                var light = Path()
                light.move(to: CGPoint(x: rect.minX + 2, y: rect.maxY - 2))
                light.addLine(to: CGPoint(x: rect.minX + 2, y: rect.minY + 2))
                light.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.minY + 2))
                ctx.stroke(light, with: .color(palette.slabLight), lineWidth: 1.2)
                var dark = Path()
                dark.move(to: CGPoint(x: rect.maxX - 1.5, y: rect.minY + 3))
                dark.addLine(to: CGPoint(x: rect.maxX - 1.5, y: rect.maxY - 1.5))
                dark.addLine(to: CGPoint(x: rect.minX + 3, y: rect.maxY - 1.5))
                ctx.stroke(dark, with: .color(.black.opacity(0.45)), lineWidth: 1.6)
                // 石材の筋（決まった並び）
                var rng = SeededRandom(seed: UInt64(p.r * 31 + p.c * 7 + board.size))
                for _ in 0..<2 {
                    let x = rect.minX + CGFloat(rng.next() % 1000) / 1000 * rect.width
                    let y = rect.minY + CGFloat(rng.next() % 1000) / 1000 * rect.height
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)), with: .color(palette.vein.opacity(0.35)))
                }
                if tile == .gilded {
                    let inset = rect.insetBy(dx: cell * 0.12, dy: cell * 0.12)
                    var diamond = Path()
                    diamond.move(to: CGPoint(x: inset.midX, y: inset.minY))
                    diamond.addLine(to: CGPoint(x: inset.maxX, y: inset.midY))
                    diamond.addLine(to: CGPoint(x: inset.midX, y: inset.maxY))
                    diamond.addLine(to: CGPoint(x: inset.minX, y: inset.midY))
                    diamond.closeSubpath()
                    ctx.fill(diamond, with: .color(Theme.gold.opacity(0.16)))
                    ctx.stroke(diamond, with: .color(Theme.gold.opacity(0.85)), lineWidth: 1.4)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// 1 マス（押すと置く）
struct CellButton: View {
    @Environment(AppModel.self) private var model
    let pos: Pos
    let stone: Stone?
    let tile: Tile
    let cell: CGFloat
    let legal: Bool
    let tint: Color
    let hinted: Bool
    let burst: Bool
    let palette: ZonePalette

    var body: some View {
        Button {
            model.tap(pos)
        } label: {
            ZStack {
                if let stone {
                    StoneSprite(stone: stone, size: cell * 0.8,
                                delay: model.flipDelays[pos] ?? 0,
                                placedNow: model.lastEffect?.move.pos == pos,
                                reduceMotion: model.reduceMotion)
                } else if legal {
                    Octagon()
                        .stroke(tint.opacity(0.85), lineWidth: 1.5)
                        .background(Octagon().fill(tint.opacity(0.18)))
                        .frame(width: cell * 0.3, height: cell * 0.3)
                }
                if hinted {
                    Octagon()
                        .stroke(palette.glowSoft, style: StrokeStyle(lineWidth: 2.5, dash: [4, 3]))
                        .frame(width: cell * 0.86, height: cell * 0.86)
                        .shadow(color: palette.glow, radius: 6)
                }
                if burst {
                    Octagon()
                        .fill(StoneKind.hourglass.tint.opacity(0.35))
                        .frame(width: cell * 0.9, height: cell * 0.9)
                }
            }
            .frame(width: cell, height: cell)
            .contentShape(Rectangle())
        }
        .buttonStyle(CellPressStyle())
        .disabled(!legal)
        .accessibilityIdentifier(hinted ? "hint.cell" : "cell.\(pos.r).\(pos.c)")
        .accessibilityLabel(label)
    }

    private var label: String {
        let name = String(UnicodeScalar(UInt8(65 + pos.c))) + "\(pos.r + 1)"
        if let stone {
            let who = stone.side == .you ? tr("あなたの石", "your stone") : tr("番人の石", "warden's stone")
            return stone.kind == .plain ? "\(name) \(who)" : "\(name) \(who) \(stone.kind.name)"
        }
        if tile == .hole { return "\(name) " + tr("穴", "pit") }
        return legal ? "\(name) " + tr("置ける", "playable") : name
    }
}

struct CellPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.16, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// 石。置いた瞬間は大きく浮いて弾み、返るときは縦の軸で回って面が入れ替わる（五十音マインスイーパーのめくりの値）
struct StoneSprite: View {
    let stone: Stone
    let size: CGFloat
    let delay: Double
    let placedNow: Bool
    let reduceMotion: Bool
    @State private var shown: Side?
    @State private var angle: Double = 0
    @State private var scale: CGFloat = 1

    var body: some View {
        GemView(side: shown ?? stone.side, kind: stone.kind, size: size, timer: stone.timer)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .scaleEffect(scale)
            .onAppear {
                shown = stone.side
                guard placedNow, !reduceMotion else { return }
                scale = 1.4
                withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { scale = 1 }
            }
            .onChange(of: stone.side) { _, new in flip(to: new) }
    }

    private func flip(to new: Side) {
        guard !reduceMotion else {
            shown = new
            return
        }
        Task {
            try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            withAnimation(.easeIn(duration: 0.13)) {
                angle = 90
                scale = 1.18
            }
            try? await Task.sleep(for: .milliseconds(130))
            shown = new
            angle = -90
            withAnimation(.easeOut(duration: 0.13)) {
                angle = 0
                scale = 1
            }
        }
    }
}

/// 炎・彗星の石が列を焼く光（1 回だけ）
struct BlastStreak: View {
    let kind: StoneKind
    let index: Int
    let n: Int
    let side: CGFloat
    @State private var on = true

    var body: some View {
        let cell = side / CGFloat(n)
        let horizontal = kind == .flame
        RoundedRectangle(cornerRadius: cell / 2)
            .fill(LinearGradient(colors: [kind.tint.opacity(0), kind.tint.opacity(0.85), Theme.goldSoft.opacity(0.9), kind.tint.opacity(0.85), kind.tint.opacity(0)],
                                 startPoint: horizontal ? .leading : .top, endPoint: horizontal ? .trailing : .bottom))
            .frame(width: horizontal ? side : cell * 0.7, height: horizontal ? cell * 0.7 : side)
            .offset(x: horizontal ? 0 : (CGFloat(index) + 0.5) * cell - side / 2,
                    y: horizontal ? (CGFloat(index) + 0.5) * cell - side / 2 : 0)
            .blendMode(.screen)
            .opacity(on ? 1 : 0)
            .scaleEffect(x: horizontal ? (on ? 1 : 1.08) : 1, y: horizontal ? 1 : (on ? 1 : 1.08))
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeOut(duration: 0.7).delay(0.15)) { on = false }
            }
    }
}

/// 盤を横に揺らす（失敗）。0, -9, 8, -6, 5, -3, 2, 0 の減衰に近い形
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = amount - amount.rounded(.down)
        let x = sin(t * .pi * 7) * 9 * (1 - t)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}
