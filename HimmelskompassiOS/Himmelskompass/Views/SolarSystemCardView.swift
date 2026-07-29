//
//  SolarSystemCardView.swift
//  Himmelskompass
//
//  3D-Ansicht des Sonnensystems: Sonne, Merkur bis Saturn inklusive Erde
//  mit ihren Bahnen, zum per Schieberegler wählbaren Zeitpunkt (±1 Jahr).
//  Weicht der gewählte Zeitpunkt von jetzt ab, bleiben die aktuellen
//  Positionen als Geister-Ringe zum Vergleich sichtbar. Die Ansicht ist
//  per Fingergeste frei dreh- und kippbar.
//

import SwiftUI

struct SolarSystemCardView: View {
    @State private var offsetDays: Double = 0
    @State private var heading = 0.0   // Drehung um die Hochachse (Grad)
    @State private var tilt = 55.0     // Kippwinkel (0 = Draufsicht, Grad)
    @State private var playing = false
    @State private var lastDrag: CGPoint?
    @State private var now = Date()

    private let playTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EE, dd.MM.yyyy"
        return f
    }()

    private var selectedDate: Date { now.addingTimeInterval(offsetDays * 86400) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🪐 Sonnensystem")
                .font(.headline)
                .foregroundStyle(HKColor.fg)

            SolarSystemSceneView(
                date: selectedDate,
                referenceDate: now,
                showReference: offsetDays != 0,
                heading: heading,
                tilt: tilt
            )
            .frame(height: 340)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let last = lastDrag ?? value.startLocation
                        let dx = value.location.x - last.x
                        let dy = value.location.y - last.y
                        lastDrag = value.location
                        heading = (heading + dx * 0.5 + 360).truncatingRemainder(dividingBy: 360)
                        tilt = min(85, max(5, tilt - dy * 0.3))
                    }
                    .onEnded { _ in lastDrag = nil }
            )

            VStack(alignment: .leading, spacing: 4) {
                (Text("Zeitpunkt: ").font(.caption).foregroundStyle(HKColor.fgDim) +
                 Text(dateLabel).font(.caption.bold()).foregroundStyle(HKColor.fg))
                HStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { offsetDays },
                            set: { newValue in
                                playing = false
                                offsetDays = newValue
                            }
                        ),
                        in: -365...365, step: 1
                    )
                    .tint(HKColor.accent)
                    Button(playing ? "⏸" : "▶") { playing.toggle() }
                        .buttonStyle(HKButtonStyle(active: playing))
                    Button("Heute") {
                        playing = false
                        now = Date()
                        offsetDays = 0
                    }
                    .buttonStyle(HKButtonStyle())
                }
            }

            Text("Draufsicht auf die Ekliptik von ekliptisch Nord (die Planeten laufen gegen den Uhrzeigersinn). Abstände zur besseren Lesbarkeit komprimiert (Wurzel-Maßstab). Ziehen dreht und kippt die Ansicht, ▶ spielt den Lauf der Planeten ab; blasse Ringe zeigen die heutigen Positionen zum Vergleich.")
                .font(.caption2)
                .foregroundStyle(HKColor.fgDim)
        }
        .hkCard()
        .onReceive(playTimer) { _ in
            guard playing else { return }
            offsetDays += 2
            if offsetDays > 365 { offsetDays = -365 }
        }
        .onAppear { now = Date() }
    }

    private var dateLabel: String {
        if offsetDays == 0 { return "heute" }
        let sign = offsetDays > 0 ? "+" : "−"
        return Self.dateFormatter.string(from: selectedDate) +
            " (\(sign)\(Int(abs(offsetDays))) Tage)"
    }
}

// MARK: - 3D-Szene

struct SolarSystemSceneView: View {
    var date: Date
    var referenceDate: Date
    var showReference: Bool
    var heading: Double  // Grad
    var tilt: Double     // Grad

    // Name, Farbe, Punktgröße (pt) und Umlaufzeit (Tage, für die Bahnkurve)
    private static let bodies: [(name: String, color: Color, radius: CGFloat, periodDays: Double)] = [
        ("Merkur", Color(red: 0xc9 / 255, green: 0xb8 / 255, blue: 0xa8 / 255), 3.0, 88.0),
        ("Venus", Color(red: 0xff / 255, green: 0xf3 / 255, blue: 0xc4 / 255), 4.5, 224.7),
        ("Erde", Color(red: 0x6a / 255, green: 0xb7 / 255, blue: 0xff / 255), 4.5, 365.25),
        ("Mars", Color(red: 0xff / 255, green: 0x8a / 255, blue: 0x66 / 255), 4.0, 687.0),
        ("Jupiter", Color(red: 0xff / 255, green: 0xe0 / 255, blue: 0xb0 / 255), 8.0, 4332.6),
        ("Saturn", Color(red: 0xff / 255, green: 0xd9 / 255, blue: 0x8f / 255), 6.5, 10759.2)
    ]

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height / 2
            // Saturn (9,6 au) liegt im Wurzel-Maßstab bei ~3,1 → Rand einplanen
            let unit = (min(size.width, size.height) / 2 - 26) / 3.15
            let hRad = heading * .pi / 180
            let tRad = tilt * .pi / 180
            let cH = cos(hRad), sH = sin(hRad)
            let cT = cos(tRad), sT = sin(tRad)

            // Heliozentrische Position (au) → Bildschirmpunkt.
            // Abstände werden mit sqrt(r) komprimiert, sonst kleben die
            // inneren Planeten an der Sonne.
            func project(_ p: (x: Double, y: Double, z: Double)) -> CGPoint {
                let r = (p.x * p.x + p.y * p.y + p.z * p.z).squareRoot()
                let f = r > 1e-9 ? r.squareRoot() / r : 0
                let x = p.x * f
                let y = p.y * f
                let z = p.z * f
                let rx = x * cH - y * sH
                let ry = x * sH + y * cH
                return CGPoint(x: cx + rx * unit, y: cy - (ry * cT + z * sT) * unit)
            }

            // Bahnen: je Planet eine volle Umlaufzeit um den Zeitpunkt abtasten
            for body in Self.bodies {
                var path = Path()
                let steps = 120
                for i in 0...steps {
                    let t = date.addingTimeInterval(
                        (Double(i) / Double(steps) - 0.5) * body.periodDays * 86400)
                    let pt = project(Planets.heliocentricPosition(body.name, date: t))
                    if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
                ctx.stroke(path, with: .color(body.color.opacity(0.28)), lineWidth: 1)
            }

            // Sonne mit Glühen
            for (rr, opacity) in [(13.0, 0.12), (9.0, 0.3), (5.5, 1.0)] {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - rr, y: cy - rr, width: 2 * rr, height: 2 * rr)),
                    with: .color(HKColor.sun.opacity(opacity)))
            }
            ctx.draw(Text("Sonne").font(.system(size: 9)).foregroundStyle(HKColor.sun.opacity(0.8)),
                     at: CGPoint(x: cx, y: cy + 16))

            // Geister-Ringe: Positionen zum jetzigen Zeitpunkt (zum Vergleich)
            if showReference {
                for body in Self.bodies {
                    let pt = project(Planets.heliocentricPosition(body.name, date: referenceDate))
                    let r = body.radius + 1.5
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: 2 * r, height: 2 * r)),
                        with: .color(body.color.opacity(0.45)), lineWidth: 1.5)
                }
            }

            // Planeten zum gewählten Zeitpunkt
            for body in Self.bodies {
                let pt = project(Planets.heliocentricPosition(body.name, date: date))
                let r = body.radius
                ctx.fill(
                    Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: 2 * r, height: 2 * r)),
                    with: .color(body.color))
                if body.name == "Saturn" {
                    // Angedeuteter Ring
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: pt.x - r * 1.9, y: pt.y - r * 0.7,
                                               width: 3.8 * r, height: 1.4 * r)),
                        with: .color(body.color.opacity(0.7)), lineWidth: 1)
                }
                ctx.draw(
                    Text(body.name).font(.system(size: 9, weight: .medium)).foregroundStyle(body.color),
                    at: CGPoint(x: pt.x, y: pt.y + r + 8))
            }
        }
        .background(
            RadialGradient(
                colors: [Color(red: 0.09, green: 0.15, blue: 0.25), HKColor.bg],
                center: .center, startRadius: 10, endRadius: 260
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
