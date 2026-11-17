import SwiftUI

// MARK: - 宝石の石

/// 八角形（宝石のカットの外形と、上面のテーブル）
struct Octagon: Shape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let k = min(r.width, r.height) * 0.29
        var p = Path()
        p.move(to: CGPoint(x: r.minX + k, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - k, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + k))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - k))
        p.addLine(to: CGPoint(x: r.maxX - k, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + k, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - k))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + k))
        p.closeSubpath()
        return p
    }

    static func corners(in r: CGRect) -> [CGPoint] {
        let k = min(r.width, r.height) * 0.29
        return [CGPoint(x: r.minX + k, y: r.minY), CGPoint(x: r.maxX - k, y: r.minY), CGPoint(x: r.maxX, y: r.minY + k), CGPoint(x: r.maxX, y: r.maxY - k),
                CGPoint(x: r.maxX - k, y: r.maxY), CGPoint(x: r.minX + k, y: r.maxY), CGPoint(x: r.minX, y: r.maxY - k), CGPoint(x: r.minX, y: r.minY + k)]
    }
}

/// カットの線（外の角とテーブルの角を結ぶ）
struct FacetLines: Shape {
    func path(in rect: CGRect) -> Path {
        let inner = rect.insetBy(dx: rect.width * 0.24, dy: rect.height * 0.24)
        let a = Octagon.corners(in: rect)
        let b = Octagon.corners(in: inner)
        var p = Path()
        for i in 0..<8 {
            p.move(to: a[i])
            p.addLine(to: b[i])
        }
        return p
    }
}

/// 宝石になった石。あなた＝月長石、番人＝黒曜石。特殊な石は宝石の色の縁と印
struct GemView: View {
    let side: Side
    var kind: StoneKind = .plain
    var size: CGFloat = 36
    /// 時の石の残り（0 なら出さない）
    var timer: Int = 0

    var body: some View {
        let light = side == .you
        let face = light ? Theme.moon : Theme.obsidian
        let facet = light ? Theme.moonFacet : Theme.obsidianFacet
        let rim = light ? Theme.moonRim : Theme.obsidianRim
        ZStack {
            if kind != .plain {
                Octagon()
                    .fill(kind.tint.opacity(0.55))
                    .frame(width: size * 1.12, height: size * 1.12)
                    .blur(radius: size * 0.08)
            }
            Octagon()
                .fill(LinearGradient(colors: [face, facet], startPoint: .topLeading, endPoint: .bottomTrailing))
            Octagon(inset: size * 0.24)
                .fill(LinearGradient(colors: [facet, face], startPoint: .topLeading, endPoint: .bottomTrailing))
            FacetLines()
                .stroke(rim.opacity(light ? 0.45 : 0.9), lineWidth: max(0.6, size * 0.018))
            Octagon()
                .stroke(kind == .plain ? rim : kind.tint, lineWidth: kind == .plain ? max(0.8, size * 0.03) : max(1.6, size * 0.07))
            // 光の当たり（左上）
            Ellipse()
                .fill(Color.white.opacity(light ? 0.75 : 0.28))
                .frame(width: size * 0.22, height: size * 0.11)
                .rotationEffect(.degrees(-35))
                .offset(x: -size * 0.17, y: -size * 0.2)
            if !light {
                Octagon(inset: size * 0.24)
                    .stroke(Theme.obsidianSheen.opacity(0.35), lineWidth: 0.8)
            }
            if kind != .plain {
                Image(systemName: kind.symbol)
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(light ? kind.tint.mix(with: .black, by: 0.25) : kind.tint)
            }
            if kind == .hourglass && timer > 0 {
                Text("\(timer)")
                    .font(Theme.carved(size * 0.28, relativeTo: .caption))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 3)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .offset(x: size * 0.32, y: -size * 0.32)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.45), radius: size * 0.06, y: size * 0.06)
        .accessibilityHidden(true)
    }
}

// MARK: - 灯（探索の残りの命）

/// 灯の炎（しずく形）
struct FlameShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.maxY - r.height * 0.32),
                   control1: CGPoint(x: r.midX + r.width * 0.12, y: r.minY + r.height * 0.25),
                   control2: CGPoint(x: r.maxX, y: r.midY - r.height * 0.1))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - r.height * 0.32), control: CGPoint(x: r.minX, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY),
                   control1: CGPoint(x: r.minX, y: r.midY - r.height * 0.1),
                   control2: CGPoint(x: r.midX - r.width * 0.12, y: r.minY + r.height * 0.25))
        p.closeSubpath()
        return p
    }
}

struct TorchRow: View {
    let lit: Int
    var total: Int = Dungeon.startTorches
    var size: CGFloat = 14
    var glow: Color = Theme.torch

    var body: some View {
        // 灯はどの帯でも琥珀の炎（水晶の洞の水色で、しずくに見えないように）
        let glow = Theme.torch
        HStack(spacing: size * 0.35) {
            ForEach(0..<max(total, lit), id: \.self) { i in
                FlameShape()
                    .fill(i < lit ? AnyShapeStyle(LinearGradient(colors: [Theme.goldSoft, glow], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Theme.textFaint.opacity(0.5)))
                    .frame(width: size * 0.7, height: size)
                    .shadow(color: i < lit ? glow.opacity(0.7) : .clear, radius: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trf("灯 %d", "Torches %d", lit))
    }
}

// MARK: - 彫った石の板

/// 彫った石の板（上と左が明るく、下と右が暗い縁）。背景は Canvas で、部品と同じ大きさに描く
struct CarvedPanel: View {
    let palette: ZonePalette
    var radius: CGFloat = Theme.radiusM
    var lit = false

    var body: some View {
        Canvas { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            let path = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
            ctx.fill(path, with: .color(palette.raised))
            // 石の粒（決まった並び）
            var rng = SeededRandom(seed: UInt64(size.width * 7 + size.height))
            for _ in 0..<Int(size.width * size.height / 900) {
                let x = Double(rng.next() % 10_000) / 10_000 * size.width
                let y = Double(rng.next() % 10_000) / 10_000 * size.height
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.4, height: 1.4)), with: .color(palette.slabLight.opacity(0.35)))
            }
            ctx.stroke(path, with: .color(lit ? palette.glow.opacity(0.8) : palette.slabLight.opacity(0.6)), lineWidth: lit ? 1.5 : 1)
            var bottom = Path()
            bottom.move(to: CGPoint(x: radius, y: size.height - 1))
            bottom.addLine(to: CGPoint(x: size.width - radius, y: size.height - 1))
            ctx.stroke(bottom, with: .color(.black.opacity(0.5)), lineWidth: 2)
        }
        .allowsHitTesting(false)
    }
}

/// 押すと沈む、彫った石のボタン
struct CarvedButtonStyle: ButtonStyle {
    let palette: ZonePalette
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.label(16, weight: .bold))
            .foregroundStyle(prominent ? palette.deep : Theme.text)
            .padding(.horizontal, 18)
            .frame(minHeight: 52)
            .frame(maxWidth: .infinity)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                        .fill(Color.black.opacity(0.55))
                        .offset(y: configuration.isPressed ? 1 : 4)
                    RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                        .fill(prominent
                              ? AnyShapeStyle(LinearGradient(colors: [palette.glowSoft, palette.glow], startPoint: .top, endPoint: .bottom))
                              : AnyShapeStyle(palette.slab))
                        .overlay(RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                            .stroke(prominent ? palette.glowSoft : palette.slabLight, lineWidth: 1))
                        .offset(y: configuration.isPressed ? 3 : 0)
                }
                .allowsHitTesting(false)
            }
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 小さな丸いボタン（閉じる・設定など）
struct RuneIconButton: View {
    let symbol: String
    let label: String
    let palette: ZonePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 44, height: 44)
                .background(Octagon().fill(palette.slab).overlay(Octagon().stroke(palette.slabLight, lineWidth: 1)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - 迷宮の背景

/// 地下の暗い地。上から灯りの色がにじみ、石壁の目地が薄く見える
struct DungeonBackdrop: View {
    let palette: ZonePalette

    var body: some View {
        ZStack {
            palette.deep
            RadialGradient(colors: [palette.glow.opacity(0.20), .clear], center: .top, startRadius: 10, endRadius: 520)
            Canvas { ctx, size in
                // 石壁の目地（れんが積み）
                let h: CGFloat = 34
                var y: CGFloat = 0
                var row = 0
                while y < size.height {
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(line, with: .color(palette.slabLight.opacity(0.10)), lineWidth: 1)
                    var x: CGFloat = row % 2 == 0 ? 0 : 36
                    while x < size.width {
                        var v = Path()
                        v.move(to: CGPoint(x: x, y: y))
                        v.addLine(to: CGPoint(x: x, y: y + h))
                        ctx.stroke(v, with: .color(palette.slabLight.opacity(0.08)), lineWidth: 1)
                        x += 72
                    }
                    y += h
                    row += 1
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - 深さの地図

/// 階段の地図（縦の坑道に、階の印が並ぶ）。いまの階が灯る
struct DepthMap: View {
    let current: Int
    let deepest: Int
    var limit: Int = Dungeon.bottom
    var locked: Int = Dungeon.freeDepth + 1
    var showsLock = true
    var compact = false

    var body: some View {
        let floors = Array(1...max(limit, current))
        VStack(spacing: compact ? 2 : 4) {
            ForEach(floors, id: \.self) { f in
                let zone = Zone.of(floor: f)
                let pal = ZonePalette.of(zone)
                HStack(spacing: 8) {
                    Text("B\(f)")
                        .font(Theme.carved(compact ? 10 : 12, relativeTo: .caption))
                        .monospacedDigit()
                        .foregroundStyle(f == current ? pal.glow : (f <= deepest ? Theme.text : Theme.textFaint))
                        .frame(width: 30, alignment: .trailing)
                    ZStack {
                        Octagon()
                            .fill(f == current ? pal.glow : (f <= deepest ? pal.slabLight : pal.raised))
                            .frame(width: compact ? 10 : 14, height: compact ? 10 : 14)
                        if showsLock && f >= locked {
                            Image(systemName: "lock.fill").font(.system(size: 7)).foregroundStyle(Theme.textSoft)
                        }
                    }
                    .frame(width: 18)
                    Rectangle()
                        .fill(pal.vein.opacity(f == current ? 0.8 : 0.25))
                        .frame(height: 1)
                    if f == 1 || Zone.of(floor: f - 1) != zone {
                        Text(zone.name)
                            .font(Theme.label(compact ? 9 : 11))
                            .foregroundStyle(pal.vein)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trf("地下 %d 階。最深 %d 階", "Floor %d. Deepest %d", current, deepest))
    }
}

/// 帯の見出し（小さな字間の開いた札）
struct Plaque: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(Theme.label(11, weight: .bold))
            .kerning(1.2)
            .foregroundStyle(color)
    }
}
