//
//  ZifferblattView.swift
//  FlightMateWatch
//
//  Das FlightMate-Zifferblatt (Nutzerwunsch). Apple lässt keine
//  eigenen watchOS-Zifferblätter zu — diese Seite ist der ehrliche
//  Ersatz in der App: analoge Uhr, außen der Böen-Ring (Anteil der
//  Windtoleranz, dieselben Farbregeln wie im Flug-Bildschirm),
//  darunter Wetter und Akku-Schätzung. Läuft ein Flug, kommen Timer
//  und Akku-Ring dazu. Ohne Wetterdaten bleibt der Ring grau und
//  die Zeile sagt es — keine erfundenen Werte.
//

import SwiftUI

struct ZifferblattView: View {
    @EnvironmentObject private var session: FlightSessionModel

    var body: some View {
        GeometryReader { geo in
            TimelineView(.periodic(from: .now, by: 1)) { context in
                face(date: context.date, size: geo.size)
            }
        }
        .ignoresSafeArea()
        .task {
            // Wetter auch ohne laufenden Flug aktuell halten,
            // solange das Zifferblatt sichtbar ist.
            session.refreshWeatherForStandby()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                session.refreshWeatherForStandby()
            }
        }
    }

    // MARK: Aufbau

    private func face(date: Date, size: CGSize) -> some View {
        let radius = min(size.width, size.height) / 2
        return ZStack {
            windRing(radius: radius)
            if session.flying {
                batteryRing(radius: radius)
            }
            ticks(radius: radius)
            topLine(date: date)
                .offset(y: -radius * 0.42)
            bottomLines
                .offset(y: radius * 0.40)
            hands(date: date, radius: radius)
        }
        .frame(width: size.width, height: size.height)
        .background(.black)
    }

    /// Außenring: Böen als Anteil der Windtoleranz. Voller Ring = Limit.
    private func windRing(radius: CGFloat) -> some View {
        let fraction = session.gustsKmh.map { min($0 / session.maxWindKmh, 1) }
        return ZStack {
            Circle()
                .stroke(.gray.opacity(0.25), lineWidth: 5)
            if let fraction {
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(gustColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: radius * 2 - 6, height: radius * 2 - 6)
    }

    /// Innenring im Flug: verbrauchter Anteil der nutzbaren Akkuzeit.
    private func batteryRing(radius: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(.gray.opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: session.batteryFraction)
                .stroke(batteryColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: radius * 1.2, height: radius * 1.2)
    }

    private func ticks(radius: CGFloat) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = radius * 0.86
            for i in 0..<60 {
                let major = i % 5 == 0
                let angle = Double(i) / 60 * 2 * .pi - .pi / 2
                let inner = outer - (major ? radius * 0.10 : radius * 0.05)
                var path = Path()
                path.move(to: point(around: center, angle: angle, radius: outer))
                path.addLine(to: point(around: center, angle: angle, radius: inner))
                context.stroke(path,
                               with: .color(major ? .white : .white.opacity(0.35)),
                               style: StrokeStyle(lineWidth: major ? 3 : 1.5,
                                                  lineCap: .round))
            }
        }
    }

    private func hands(date: Date, radius: CGFloat) -> some View {
        let parts = Calendar.current.dateComponents([.hour, .minute, .second],
                                                    from: date)
        let seconds = Double(parts.second ?? 0)
        let minutes = Double(parts.minute ?? 0) + seconds / 60
        let hours = Double((parts.hour ?? 0) % 12) + minutes / 60
        return ZStack {
            hand(length: radius * 0.42, width: 4, color: .white)
                .rotationEffect(.degrees(hours / 12 * 360))
            hand(length: radius * 0.62, width: 3, color: .white)
                .rotationEffect(.degrees(minutes / 60 * 360))
            hand(length: radius * 0.74, width: 1.5, color: .cyan)
                .rotationEffect(.degrees(seconds / 60 * 360))
            Circle()
                .fill(.cyan)
                .frame(width: 6, height: 6)
        }
    }

    private func hand(length: CGFloat, width: CGFloat, color: Color) -> some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
    }

    // MARK: Textzeilen

    private func topLine(date: Date) -> some View {
        Group {
            if session.flying {
                Text(timeText(session.elapsedS))
                    .foregroundStyle(.green)
                    .monospacedDigit()
            } else {
                Text(date.formatted(.dateTime.weekday(.abbreviated).day()))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
    }

    private var bottomLines: some View {
        VStack(spacing: 1) {
            windLine
            detailLine
        }
        .multilineTextAlignment(.center)
    }

    private var windLine: some View {
        Group {
            if let wind = session.windKmh, let gusts = session.gustsKmh {
                Text("\(Int(wind)) km/h · Böen \(Int(gusts))")
                    .foregroundStyle(gustColor)
            } else if session.weatherFailed {
                Text("Wetter nicht abrufbar")
                    .foregroundStyle(.secondary)
            } else {
                Text("Wetter wird geladen …")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 11, weight: .medium))
    }

    private var detailLine: some View {
        Group {
            if session.flying {
                Text("Akku \(session.batteryCount) · \(remainingText)")
            } else if let temperature = session.temperatureC {
                Text("\(Int(temperature.rounded())) °C · ≈ \(Int(session.batteryEstimateMinutes.rounded())) min/Akku")
            } else {
                Text("≈ \(Int(session.batteryEstimateMinutes.rounded())) min/Akku")
            }
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
    }

    // MARK: Farb- und Formatregeln (Spiegel des Flug-Bildschirms)

    private var gustColor: Color {
        guard let gusts = session.gustsKmh else { return .gray }
        if gusts >= session.maxWindKmh { return .red }
        if gusts >= session.maxWindKmh * 0.8 { return .orange }
        return .green
    }

    private var batteryColor: Color {
        switch session.batteryFraction {
        case ..<0.6: return .green
        case ..<0.85: return .orange
        default: return .red
        }
    }

    private var remainingText: String {
        let remaining = session.usableBatterySeconds - session.batteryElapsedS
        if remaining <= 0 { return "RTH-Reserve!" }
        return "noch \(timeText(remaining))"
    }

    private func timeText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func point(around center: CGPoint,
                       angle: Double,
                       radius: CGFloat) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius)
    }
}
