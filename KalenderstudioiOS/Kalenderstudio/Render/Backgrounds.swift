import SwiftUI

/// Der Seitenhintergrund bis in den Beschnitt: Verlauf, Muster oder Foto.
struct PageBackground: View {
    let design: Design
    let geometry: PageGeometry
    /// Foto der Seite (für „Seitenfoto“ als Hintergrund).
    var pagePhotoID: UUID? = nil
    var seed: String = ""

    var body: some View {
        let size = geometry.size
        ZStack {
            LinearGradient(colors: [design.bg1.color, design.bg2.color],
                           startPoint: .top, endPoint: .bottom)
            switch design.backgroundSource {
            case .theme:
                PatternLayer(design: design, size: size, safe: geometry.safeRect, unit: geometry.unit, seed: seed)
            case .photo:
                photoLayer(design.backgroundPhotoID, size: size)
            case .pagePhoto:
                photoLayer(pagePhotoID ?? design.backgroundPhotoID, size: size)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    @ViewBuilder
    private func photoLayer(_ id: UUID?, size: CGSize) -> some View {
        if let id, let img = ImageStore.shared.blurred(id, amount: design.backgroundBlur), img.size.height > 0 {
            let fit = PhotoFill.fillSize(aspect: img.size.width / img.size.height, frame: size, zoom: 1.05)
            ZStack {
                Image(uiImage: img)
                    .resizable()
                    .frame(width: fit.width, height: fit.height)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                // Abdunkeln (helle Schrift) oder aufhellen (dunkle Schrift).
                (design.isDark ? Color.black : Color.white).opacity(design.backgroundDim)
                LinearGradient(colors: [design.bg1.alpha(0.25), .clear, design.bg2.alpha(0.35)],
                               startPoint: .top, endPoint: .bottom)
            }
        } else {
            PatternLayer(design: design, size: size, safe: geometry.safeRect, unit: geometry.unit, seed: seed)
        }
    }
}

/// Weicher Farbfleck aus einem Radialverlauf — bleibt im PDF ein Vektor.
struct Blob: View {
    let color: Color
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    var squash: CGFloat = 1

    var body: some View {
        Ellipse()
            .fill(RadialGradient(colors: [color, color.opacity(0.45), color.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: radius))
            .frame(width: radius * 2, height: radius * 2 * squash)
            .position(x: x, y: y)
    }
}

struct PatternLayer: View {
    let design: Design
    let size: CGSize
    let safe: CGRect
    let unit: CGFloat
    let seed: String

    private var w: CGFloat { size.width }
    private var h: CGFloat { size.height }
    private var m: CGFloat { max(w, h) }

    var body: some View {
        ZStack {
            switch design.pattern {
            case .none: gradientOnly
            case .aurora: aurora
            case .paper: paper
            case .watercolor: watercolor
            case .bauhaus: bauhaus
            case .artDeco: artDeco
            case .chalk: chalk
            case .waves: waves
            case .confetti: confetti
            case .dots: dots
            case .bokeh: bokeh
            case .riso: riso
            case .linen: linen
            }
        }
        .frame(width: w, height: h)
        .clipped()
    }

    private var gradientOnly: some View {
        Blob(color: design.bg3.alpha(0.25), x: w * 0.85, y: h * 0.1, radius: m * 0.6)
    }

    private var aurora: some View {
        ZStack {
            LinearGradient(colors: [design.bg1.color, design.bg2.color, design.bg1.color],
                           startPoint: .top, endPoint: .bottom)
            Blob(color: design.bg3.alpha(0.55), x: w * 0.2, y: h * 0.15, radius: m * 0.45, squash: 0.45)
            Blob(color: design.accent.alpha(0.35), x: w * 0.65, y: h * 0.08, radius: m * 0.4, squash: 0.35)
            Blob(color: RGBA(hex: 0x8A5CF6).alpha(0.45), x: w * 0.9, y: h * 0.3, radius: m * 0.38, squash: 0.5)
            Blob(color: RGBA(hex: 0x2EC4F1).alpha(0.3), x: w * 0.1, y: h * 0.75, radius: m * 0.35, squash: 0.6)
            Blob(color: design.bg3.alpha(0.25), x: w * 0.75, y: h * 0.95, radius: m * 0.4, squash: 0.4)
            stars
        }
    }

    private var stars: some View {
        Canvas { ctx, sz in
            var rng = SeededRandom(seed: (seed + "sterne").stableSeed)
            for _ in 0..<140 {
                let x = rng.range(0, Double(sz.width))
                let y = rng.range(0, Double(sz.height))
                let r = rng.range(0.25, 1.1) * Double(unit) * 0.22
                let a = rng.range(0.25, 0.9)
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                         with: .color(.white.opacity(a)))
            }
        }
    }

    private var paper: some View {
        ZStack {
            RadialGradient(colors: [design.bg1.color, design.bg2.color],
                           center: .center, startRadius: m * 0.1, endRadius: m * 0.75)
            Canvas { ctx, sz in
                var rng = SeededRandom(seed: (seed + "papier").stableSeed)
                for _ in 0..<220 {
                    let x = rng.range(0, Double(sz.width))
                    let y = rng.range(0, Double(sz.height))
                    let len = rng.range(2, 9) * Double(unit) * 0.3
                    let angle = rng.range(0, .pi)
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x + cos(angle) * len, y: y + sin(angle) * len))
                    ctx.stroke(p, with: .color(design.bg3.alpha(0.18)), lineWidth: Double(unit) * 0.05)
                }
            }
            Rectangle()
                .strokeBorder(design.accent.alpha(0.35), lineWidth: unit * 0.12)
                .frame(width: safe.width + unit * 2, height: safe.height + unit * 2)
                .position(x: safe.midX, y: safe.midY)
        }
    }

    private var watercolor: some View {
        ZStack {
            design.bg1.color
            Blob(color: RGBA(hex: 0xF9C6D3).alpha(0.9), x: w * 0.05, y: h * 0.05, radius: m * 0.35)
            Blob(color: design.bg3.alpha(0.85), x: w * 0.95, y: h * 0.12, radius: m * 0.3)
            Blob(color: RGBA(hex: 0xCDEAC0).alpha(0.85), x: w * 0.9, y: h * 0.95, radius: m * 0.36)
            Blob(color: RGBA(hex: 0xFFE5A8).alpha(0.75), x: w * 0.08, y: h * 0.9, radius: m * 0.28)
            Blob(color: design.accent.alpha(0.25), x: w * 0.55, y: h * 0.5, radius: m * 0.25)
            Canvas { ctx, sz in
                var rng = SeededRandom(seed: (seed + "spritzer").stableSeed)
                let colors = [design.accent.alpha(0.25), design.bg3.alpha(0.4), RGBA(hex: 0xF9C6D3).alpha(0.6)]
                for i in 0..<36 {
                    let corner = i % 4
                    let cx = corner % 2 == 0 ? 0.1 : 0.9
                    let cy = corner < 2 ? 0.1 : 0.9
                    let x = (cx + rng.range(-0.12, 0.12)) * Double(sz.width)
                    let y = (cy + rng.range(-0.12, 0.12)) * Double(sz.height)
                    let r = rng.range(0.3, 1.6) * Double(unit) * 0.6
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                             with: .color(colors[i % colors.count]))
                }
            }
        }
    }

    private var bauhaus: some View {
        ZStack {
            design.bg1.color
            Circle()
                .fill(design.accent.alpha(0.9))
                .frame(width: m * 0.34, height: m * 0.34)
                .position(x: w * 0.97, y: h * 0.02)
            Circle()
                .trim(from: 0, to: 0.5)
                .fill(design.bg3.alpha(0.9))
                .frame(width: m * 0.3, height: m * 0.3)
                .rotationEffect(.degrees(180))
                .position(x: w * 0.04, y: h * 1.0)
            Rectangle()
                .fill(RGBA(hex: 0xF4A261).alpha(0.95))
                .frame(width: m * 0.05, height: m * 0.22)
                .position(x: w * 0.02, y: h * 0.3)
            Canvas { ctx, sz in
                let step = Double(unit) * 3
                let r = Double(unit) * 0.35
                let x0 = Double(sz.width) * 0.78
                let y0 = Double(sz.height) * 0.86
                for i in 0..<6 {
                    for j in 0..<4 {
                        let x = x0 + Double(i) * step
                        let y = y0 + Double(j) * step
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                                 with: .color(design.text.alpha(0.6)))
                    }
                }
            }
        }
    }

    private var artDeco: some View {
        ZStack {
            RadialGradient(colors: [design.bg2.color, design.bg1.color],
                           center: UnitPoint(x: 0.5, y: 1.0), startRadius: 0, endRadius: m * 0.9)
            Canvas { ctx, sz in
                let center = CGPoint(x: sz.width / 2, y: sz.height * 1.02)
                let len = Double(max(sz.width, sz.height)) * 1.3
                for i in 0..<36 {
                    let angle = Double.pi + Double(i) / 35 * Double.pi
                    var p = Path()
                    p.move(to: center)
                    p.addLine(to: CGPoint(x: center.x + cos(angle) * len, y: center.y + sin(angle) * len))
                    ctx.stroke(p, with: .color(design.accent.alpha(0.10)), lineWidth: Double(unit) * 0.12)
                }
                for k in 1...4 {
                    let r = Double(unit) * 14 * Double(k)
                    ctx.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)),
                               with: .color(design.accent.alpha(0.10)), lineWidth: Double(unit) * 0.1)
                }
            }
            // Doppelter Goldrahmen innerhalb des Sicherheitsabstands.
            Rectangle()
                .strokeBorder(design.accent.alpha(0.75), lineWidth: unit * 0.18)
                .frame(width: safe.width + unit * 2.4, height: safe.height + unit * 2.4)
                .position(x: safe.midX, y: safe.midY)
            Rectangle()
                .strokeBorder(design.accent.alpha(0.4), lineWidth: unit * 0.08)
                .frame(width: safe.width + unit * 1.2, height: safe.height + unit * 1.2)
                .position(x: safe.midX, y: safe.midY)
        }
    }

    private var chalk: some View {
        ZStack {
            RadialGradient(colors: [design.bg1.color, design.bg2.color],
                           center: .center, startRadius: 0, endRadius: m * 0.75)
            Blob(color: .white.opacity(0.07), x: w * 0.3, y: h * 0.3, radius: m * 0.3, squash: 0.5)
            Blob(color: .white.opacity(0.05), x: w * 0.75, y: h * 0.7, radius: m * 0.35, squash: 0.4)
            Canvas { ctx, sz in
                var rng = SeededRandom(seed: (seed + "kreide").stableSeed)
                for _ in 0..<60 {
                    let x = rng.range(0, Double(sz.width))
                    let y = rng.range(0, Double(sz.height))
                    let len = rng.range(4, 18) * Double(unit) * 0.5
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addQuadCurve(to: CGPoint(x: x + len, y: y + rng.range(-1, 1) * Double(unit)),
                                   control: CGPoint(x: x + len / 2, y: y - Double(unit) * 0.8))
                    ctx.stroke(p, with: .color(.white.opacity(0.05)), lineWidth: Double(unit) * rng.range(0.2, 0.6))
                }
            }
        }
    }

    private var waves: some View {
        ZStack {
            LinearGradient(colors: [design.bg1.color, design.bg2.color, design.bg3.color],
                           startPoint: .top, endPoint: .bottom)
            Blob(color: .white.opacity(0.35), x: w * 0.8, y: h * 0.12, radius: m * 0.18)
            WaveShape(amplitude: 0.025, frequency: 1.3, phase: 0.2, level: 0.80)
                .fill(Color.white.opacity(0.10))
            WaveShape(amplitude: 0.03, frequency: 1.0, phase: 1.4, level: 0.86)
                .fill(Color.white.opacity(0.14))
            WaveShape(amplitude: 0.02, frequency: 1.7, phase: 2.6, level: 0.92)
                .fill(Color.white.opacity(0.18))
        }
    }

    private var confetti: some View {
        ZStack {
            design.bg1.color
            Canvas { ctx, sz in
                var rng = SeededRandom(seed: (seed + "konfetti").stableSeed)
                let colors: [Color] = [design.accent.color, design.holiday.color,
                                       RGBA(hex: 0xFFC145).color, RGBA(hex: 0x2EC4B6).color,
                                       RGBA(hex: 0xFF8FAB).color]
                for i in 0..<120 {
                    // Dichter am Rand, frei in der Mitte.
                    var x = rng.unit()
                    var y = rng.unit()
                    if i % 3 != 0 {
                        if rng.unit() < 0.5 { x = rng.unit() < 0.5 ? rng.range(0, 0.12) : rng.range(0.88, 1) }
                        else { y = rng.unit() < 0.5 ? rng.range(0, 0.12) : rng.range(0.88, 1) }
                    }
                    let px = x * Double(sz.width)
                    let py = y * Double(sz.height)
                    let s = rng.range(0.6, 1.6) * Double(unit)
                    let color = colors[i % colors.count].opacity(rng.range(0.55, 0.95))
                    var c = ctx
                    c.translateBy(x: px, y: py)
                    c.rotate(by: .radians(rng.range(0, .pi)))
                    switch i % 3 {
                    case 0:
                        c.fill(Path(CGRect(x: -s / 2, y: -s / 5, width: s, height: s / 2.5)), with: .color(color))
                    case 1:
                        c.fill(Path(ellipseIn: CGRect(x: -s / 3, y: -s / 3, width: s / 1.5, height: s / 1.5)), with: .color(color))
                    default:
                        var p = Path()
                        p.move(to: CGPoint(x: -s / 2, y: 0))
                        p.addQuadCurve(to: CGPoint(x: s / 2, y: 0), control: CGPoint(x: 0, y: -s / 1.5))
                        c.stroke(p, with: .color(color), lineWidth: s / 5)
                    }
                }
            }
        }
    }

    private var dots: some View {
        ZStack {
            LinearGradient(colors: [design.bg1.color, design.bg2.color], startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { ctx, sz in
                let step = Double(unit) * 3.2
                let r = Double(unit) * 0.22
                var y = 0.0
                var row = 0
                while y < Double(sz.height) {
                    var x = row % 2 == 0 ? 0 : step / 2
                    while x < Double(sz.width) {
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                                 with: .color(design.bg3.alpha(0.35)))
                        x += step
                    }
                    y += step * 0.87
                    row += 1
                }
            }
        }
    }

    private var bokeh: some View {
        ZStack {
            RadialGradient(colors: [design.bg1.color, design.bg2.color],
                           center: UnitPoint(x: 0.3, y: 0.2), startRadius: 0, endRadius: m)
            Canvas { ctx, sz in
                var rng = SeededRandom(seed: (seed + "lichter").stableSeed)
                let colors: [Color] = [design.accent.color, design.holiday.color, RGBA(hex: 0xFFE7A3).color]
                for i in 0..<46 {
                    let x = rng.unit() * Double(sz.width)
                    let y = rng.unit() * Double(sz.height)
                    let r = rng.range(1.5, 7) * Double(unit)
                    let rect = CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)
                    let color = colors[i % colors.count]
                    ctx.fill(Path(ellipseIn: rect),
                             with: .radialGradient(Gradient(colors: [color.opacity(rng.range(0.15, 0.4)), color.opacity(0.04)]),
                                                   center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
                    ctx.stroke(Path(ellipseIn: rect), with: .color(color.opacity(0.12)), lineWidth: Double(unit) * 0.1)
                }
            }
        }
    }
}

extension PatternLayer {
    /// Risographie: wenige große Farbflächen, leicht versetzt übereinander,
    /// mit feinem Korn — wie die Drucke kleiner Studios (design-milk 2026).
    var riso: some View {
        ZStack {
            design.bg1.color
            Circle()
                .fill(design.accent.alpha(0.82))
                .frame(width: m * 0.42, height: m * 0.42)
                .position(x: w * 0.9, y: h * 0.06)
            Circle()
                .fill(design.bg3.alpha(0.55))
                .frame(width: m * 0.42, height: m * 0.42)
                .position(x: w * 0.84, y: h * 0.1)
            RoundedRectangle(cornerRadius: m * 0.1, style: .continuous)
                .fill(design.holiday.alpha(0.35))
                .frame(width: m * 0.3, height: m * 0.16)
                .rotationEffect(.degrees(-12))
                .position(x: w * 0.06, y: h * 0.97)
            Circle()
                .trim(from: 0, to: 0.5)
                .fill(design.bg3.alpha(0.45))
                .frame(width: m * 0.26, height: m * 0.26)
                .position(x: w * 0.97, y: h * 0.9)
            Canvas { ctx, sz in
                var rng = SeededRandom(seed: (seed + "korn").stableSeed)
                let r = Double(unit) * 0.07
                let ink = design.isDark ? Color.white : design.text.color
                for _ in 0..<1400 {
                    let x = rng.unit() * Double(sz.width)
                    let y = rng.unit() * Double(sz.height)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                             with: .color(ink.opacity(rng.range(0.04, 0.12))))
                }
            }
        }
    }

    /// Leinen: feines Gewebe aus waagerechten und senkrechten Fäden — eine
    /// ruhige Papierstruktur, die hinter Fotos nicht stört.
    var linen: some View {
        ZStack {
            LinearGradient(colors: [design.bg1.color, design.bg2.color], startPoint: .top, endPoint: .bottom)
            Canvas { ctx, sz in
                var rng = SeededRandom(seed: (seed + "leinen").stableSeed)
                let step = Double(unit) * 0.55
                let thread = design.isDark ? Color.white : design.text.color
                var x = 0.0
                while x < Double(sz.width) {
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: Double(sz.height)))
                    ctx.stroke(p, with: .color(thread.opacity(rng.range(0.015, 0.045))), lineWidth: Double(unit) * 0.05)
                    x += step * rng.range(0.7, 1.3)
                }
                var y = 0.0
                while y < Double(sz.height) {
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: Double(sz.width), y: y))
                    ctx.stroke(p, with: .color(thread.opacity(rng.range(0.015, 0.045))), lineWidth: Double(unit) * 0.05)
                    y += step * rng.range(0.7, 1.3)
                }
            }
            Blob(color: design.bg3.alpha(0.12), x: w * 0.8, y: h * 0.15, radius: m * 0.5)
        }
    }
}

struct WaveShape: Shape {
    var amplitude: CGFloat
    var frequency: CGFloat
    var phase: CGFloat
    /// Höhe der Wellenlinie als Anteil der Fläche (0 = oben).
    var level: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let baseline = rect.height * level
        let amp = rect.height * amplitude
        p.move(to: CGPoint(x: 0, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: baseline))
        let steps = 80
        for i in 0...steps {
            let x = rect.width * CGFloat(i) / CGFloat(steps)
            let y = baseline + amp * sin(frequency * 2 * .pi * CGFloat(i) / CGFloat(steps) + phase)
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.closeSubpath()
        return p
    }
}
