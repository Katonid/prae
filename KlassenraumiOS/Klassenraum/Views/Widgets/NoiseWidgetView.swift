import SwiftUI

/// Lautstärkeanzeige: misst über das Mikrofon des Geräts den Geräuschpegel
/// im Raum.
///
/// Aufbau und Maße folgen der Web-App (`.w-noise` im Stylesheet): Kopfzeile
/// mit Aufschrift und Pegelzahl, darunter ein Band aus 24 Segmenten, unten
/// eine Statuszeile. Ein Tipp startet und beendet die Messung. Aufgezeichnet
/// wird nichts; berechnet wird nur der Pegel.
struct NoiseWidgetView: View {
    let content: NoiseContent
    var interactive: Bool

    @Environment(\.boardStyle) private var style
    @Environment(\.widgetMetrics) private var metrics

    @ObservedObject private var meter = NoiseMeter.shared
    @State private var overSince: Date?
    @State private var alarmUntil: Date?
    /// Dieses Element hat die Messung angefordert (für ein sauberes Freigeben).
    @State private var listening = false

    /// So viele Segmente hat das Band — wie in der Web-App.
    private static let segments = 24

    /// Geschätzter Schalldruckpegel in dB(A) — siehe `NoiseSkala`.
    private var dezibel: Double { meter.dezibel }
    /// Ausschlag des Bandes, 0 … 1.
    private var ausschlag: Double { meter.level }
    /// Ausschlag, ab dem „zu laut" gilt.
    private var schwelleAusschlag: Double { NoiseSkala.ausschlag(content.schwelleDb) }
    private var zuLaut: Bool { dezibel >= content.schwelleDb }
    private var measuring: Bool { listening && meter.running }
    private var alarm: Bool {
        guard content.alert, let until = alarmUntil else { return false }
        return Date() < until
    }

    var body: some View {
        // Die Web-App polstert den Lautstärkemesser fest: 16px oben und
        // unten, 18px an den Seiten, 10px zwischen den Zeilen.
        VStack(alignment: .leading, spacing: 10) {
            head
            band
            status
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            // `is-alarm` lässt in der Web-App die Fläche rot aufblinken.
            RoundedRectangle(cornerRadius: Theme.widgetCorner, style: .continuous)
                .fill(Color(hex: "#f43f5e").opacity(alarm ? 0.22 : 0))
                .animation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true), value: alarm)
        }
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
        // Erst messen, wenn das Mikrofon freigegeben ist: Sonst fragt iOS
        // gleich beim ersten Start nach der Erlaubnis, obwohl vielleicht
        // niemand messen möchte.
        .onAppear { beginListening() }
        .onDisappear { endListening() }
        .onChange(of: meter.permission) { _, _ in beginListening() }
        .onChange(of: meter.level) { _, _ in updateAlarm() }
    }

    // MARK: - Kopfzeile

    /// `.w-noise__head` — Aufschrift links, Pegelzahl rechts, beide auf
    /// derselben Schriftlinie.
    private var head: some View {
        HStack(alignment: .firstTextBaseline, spacing: metrics.em(0.5)) {
            if style.showLabels {
                Text(content.title.isEmpty ? "Lautstärke" : content.title)
                    .font(Theme.font(metrics.em(style.kopf(1)), weight: .bold))
                    .foregroundStyle(style.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
            // `.w-noise__value`: 2em, sehr fett. Der Farbverlauf kommt erst
            // beim Messen dazu (`.is-live`), sonst steht dort ein Strich.
            // Angezeigt wird jetzt ein geschätzter Schalldruckpegel statt
            // einer Zahl von 0 bis 100 — 68 dB sagt einer Lehrkraft etwas,
            // „68 von 100" nicht.
            HStack(alignment: .firstTextBaseline, spacing: metrics.em(0.18)) {
                Text(measuring ? "\(Int(dezibel.rounded()))" : "–")
                    .font(Theme.font(metrics.em(2), weight: .heavy))
                    .monospacedDigit()
                    .tracking(-metrics.em(2) * 0.02)
                    .foregroundStyle(measuring ? style.bigText : AnyShapeStyle(style.ink))
                    .lineLimit(1)
                if measuring {
                    Text("dB")
                        .font(Theme.font(metrics.em(0.9), weight: .bold))
                        .foregroundStyle(style.inkSoft)
                }
            }
        }
    }

    // MARK: - Segmentband

    /// `.w-noise__meter` — die Segmente teilen sich die Breite, der Abstand
    /// beträgt feste 3 Punkte, das Band ist mindestens 46 Punkte hoch.
    private var band: some View {
        let value = measuring ? ausschlag : 0
        let active = Int((value * Double(Self.segments)).rounded())
        let thresholdIndex = Int((schwelleAusschlag * Double(Self.segments)).rounded())
        return HStack(spacing: 3) {
            ForEach(0..<Self.segments, id: \.self) { index in
                segment(index: index, active: active, thresholdIndex: thresholdIndex)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 46)
        .animation(.linear(duration: 0.08), value: active)
    }

    private func segment(index: Int, active: Int, thresholdIndex: Int) -> some View {
        let on = index < active
        let hot = on && index >= thresholdIndex
        let share = Double(index) / Double(Self.segments)
        let lit = hot ? Color(hex: "#f43f5e") : segmentColor(share)
        let glow = hot ? Color(hex: "#f43f5e").opacity(0.9)
                       : Color(hslHue: 150 - share * 120, saturation: 0.90, lightness: 0.55)

        return RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(on ? lit : style.wash)
            .shadow(color: on ? glow : .clear, radius: hot ? 7 : 6)
            .overlay(alignment: .trailing) {
                // `.is-threshold::after`: ein schmaler Strich am rechten Rand
                // des Segments, das die Schwelle markiert — etwas höher als
                // das Band selbst.
                if index == thresholdIndex - 1 {
                    Capsule()
                        .fill(style.ink.opacity(0.55))
                        .frame(width: 2)
                        .padding(.vertical, -4)
                        .offset(x: 3)
                }
            }
    }

    /// `hsl(150 - seg * 120, 85%, 52%)` — Grün über Gelb nach Rot.
    private func segmentColor(_ share: Double) -> Color {
        Color(hslHue: 150 - share * 120, saturation: 0.85, lightness: 0.52)
    }

    // MARK: - Statuszeile

    /// `.w-noise__status` — sagt in einem kurzen Satz, was gerade gilt.
    @ViewBuilder
    private var status: some View {
        if style.showLabels || meter.permission != .granted {
            Text(statusText)
                .font(Theme.font(metrics.em(0.94), weight: alarm ? .bold : .semibold))
                .foregroundStyle(alarm ? Theme.danger : style.inkSoft)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusText: String {
        switch meter.permission {
        case .denied:
            return "Kein Zugriff auf das Mikrofon — in den iOS-Einstellungen unter Klassenraum erlauben."
        case .unknown:
            return "Zum Messen antippen."
        case .granted:
            guard measuring else { return "Zum Messen antippen." }
            if alarm { return "Zu laut!" }
            // Fünf Dezibel vor der Schwelle vorwarnen: 5 dB sind eine
            // deutlich hörbare Stufe, ein fester Bruchteil der Schwelle
            // wäre dagegen willkürlich.
            return dezibel > content.schwelleDb - 5 ? "Grenze fast erreicht" : "Gute Arbeitslautstärke"
        }
    }

    // MARK: - Messung an und aus

    private func toggle() {
        guard interactive else { return }
        switch meter.permission {
        case .granted:
            Haptics.tap()
            if listening { endListening() } else { beginListening() }
        case .unknown:
            meter.requestPermission()
        case .denied:
            break
        }
    }

    private func beginListening() {
        guard !listening, meter.permission == .granted else { return }
        listening = true
        meter.retain()
    }

    private func endListening() {
        guard listening else { return }
        listening = false
        meter.release()
        alarmUntil = nil
        overSince = nil
    }

    /// „Zu laut" erst nach kurzem Anhalten melden — einzelne Ausrufe sollen
    /// die Anzeige nicht sofort rot färben. Danach bleibt die Meldung vier
    /// Sekunden stehen, genau wie in der Web-App.
    private func updateAlarm() {
        guard measuring else { return }
        let now = Date()
        if zuLaut {
            if overSince == nil { overSince = now }
            if let since = overSince, now.timeIntervalSince(since) > 1.2,
               alarmUntil == nil || now >= alarmUntil! {
                alarmUntil = now.addingTimeInterval(4)
            }
        } else {
            overSince = nil
        }
    }
}
