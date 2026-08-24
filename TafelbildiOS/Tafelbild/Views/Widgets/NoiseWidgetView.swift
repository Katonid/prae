import SwiftUI

/// Lautstärkeanzeige: misst über das Mikrofon des Geräts den Geräuschpegel
/// im Raum. Drei Darstellungen — Tacho, Balken oder große Lampe.
struct NoiseWidgetView: View {
    let content: NoiseContent
    var interactive: Bool

    @ObservedObject private var meter = NoiseMeter.shared
    @State private var overSince: Date?
    @State private var tooLoud = false

    private var level: Double { min(1, meter.level * content.gain) }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 10) {
                if !content.title.isEmpty {
                    Text(tooLoud && content.alert ? "Zu laut!" : content.title)
                        .font(Theme.font(min(geo.size.width * 0.11, 30), weight: .bold))
                        .foregroundStyle(tooLoud && content.alert ? Theme.danger : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }

                Group {
                    switch meter.permission {
                    case .denied:
                        hint("Mikrofon ist nicht erlaubt. In den iOS-Einstellungen → Tafelbild → Mikrofon einschalten.",
                             symbol: "mic.slash")
                    case .unknown where !meter.running:
                        Button {
                            meter.requestPermission()
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: "mic.circle.fill")
                                    .font(.system(size: 44))
                                Text("Messung starten")
                                    .font(Theme.font(20, weight: .semibold))
                            }
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(.plain)
                    default:
                        gaugeContent(size: geo.size)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
        .overlay {
            RoundedRectangle(cornerRadius: Theme.widgetCorner, style: .continuous)
                .strokeBorder(Theme.danger.opacity(tooLoud && content.alert ? 0.9 : 0), lineWidth: 5)
                .animation(.easeInOut(duration: 0.3), value: tooLoud)
        }
        .onAppear { meter.retain() }
        .onDisappear { meter.release() }
        .onChange(of: meter.level) { _, _ in updateAlert() }
    }

    @ViewBuilder
    private func gaugeContent(size: CGSize) -> some View {
        switch content.style {
        case .gauge: gauge(size: size)
        case .bars: bars(size: size)
        case .lamp: lamp(size: size)
        }
    }

    // MARK: - Tacho

    private func gauge(size: CGSize) -> some View {
        let side = min(size.width, size.height * 1.6)
        return ZStack {
            // Skala: 240°, unten offen.
            Circle()
                .trim(from: 0, to: 0.666)
                .stroke(Color.white.opacity(0.12),
                        style: StrokeStyle(lineWidth: side * 0.11, lineCap: .round))
                .rotationEffect(.degrees(150))
            Circle()
                .trim(from: 0, to: 0.666 * level)
                .stroke(
                    AngularGradient(colors: [Color(hex: "#22c55e"), Color(hex: "#f59e0b"), Color(hex: "#ef4444")],
                                    center: .center, angle: .degrees(150)),
                    style: StrokeStyle(lineWidth: side * 0.11, lineCap: .round)
                )
                .rotationEffect(.degrees(150))
                .animation(.easeOut(duration: 0.15), value: level)
            // Schwellenmarke
            Rectangle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 3, height: side * 0.13)
                .offset(y: -side * 0.5 + side * 0.055)
                .rotationEffect(.degrees(-120 + 240 * content.threshold))

            VStack(spacing: 0) {
                Text("\(Int(level * 100))")
                    .font(Theme.font(side * 0.24, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("Pegel")
                    .font(Theme.font(side * 0.07, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(width: side, height: side)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Balken

    private func bars(size: CGSize) -> some View {
        let count = 14
        let active = Int(round(level * Double(count)))
        return HStack(alignment: .bottom, spacing: max(3, size.width * 0.012)) {
            ForEach(0..<count, id: \.self) { index in
                let share = Double(index + 1) / Double(count)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(index < active ? barColor(share) : Color.white.opacity(0.12))
                    .frame(height: max(10, size.height * CGFloat(0.28 + 0.62 * share)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(.easeOut(duration: 0.12), value: active)
    }

    private func barColor(_ share: Double) -> Color {
        if share > 0.8 { return Color(hex: "#ef4444") }
        if share > 0.55 { return Color(hex: "#f59e0b") }
        return Color(hex: "#22c55e")
    }

    // MARK: - Lampe

    private func lamp(size: CGSize) -> some View {
        let side = min(size.width, size.height)
        let color: Color = level > content.threshold
            ? Color(hex: "#ef4444")
            : (level > content.threshold * 0.6 ? Color(hex: "#f59e0b") : Color(hex: "#22c55e"))
        return Circle()
            .fill(color)
            .overlay {
                Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: side * 0.03)
            }
            .shadow(color: color.opacity(0.7), radius: side * 0.16)
            .scaleEffect(0.7 + 0.3 * level)
            .frame(width: side * 0.9, height: side * 0.9)
            .animation(.easeOut(duration: 0.15), value: level)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Hinweis & Warnung

    private func hint(_ text: String, symbol: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34))
            Text(text)
                .font(Theme.font(17, weight: .medium))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white.opacity(0.75))
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// „Zu laut" erst nach kurzem Anhalten melden — einzelne Ausrufe
    /// sollen die Anzeige nicht sofort rot färben.
    private func updateAlert() {
        if level > content.threshold {
            if overSince == nil { overSince = Date() }
            if let since = overSince, Date().timeIntervalSince(since) > 1.2, !tooLoud {
                tooLoud = true
            }
        } else {
            overSince = nil
            if tooLoud { tooLoud = false }
        }
    }
}
