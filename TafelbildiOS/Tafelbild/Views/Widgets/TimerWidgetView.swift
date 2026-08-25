import SwiftUI
import Combine

/// Countdown und Stoppuhr. Die Zeit wird aus Zeitstempeln berechnet, damit
/// sie auch dann stimmt, wenn die App zwischendurch im Hintergrund war.
struct TimerWidgetView: View {
    @Binding var content: TimerContent
    var interactive: Bool

    @Environment(\.boardStyle) private var style
    @Environment(\.widgetMetrics) private var metrics

    @State private var now = Date()
    @State private var flashing = false
    @State private var showDurationPicker = false

    private let ticker = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let value = displayValue
            // Der Ring füllt den Platz zwischen Aufschrift und Knöpfen.
            let side = max(70, min(geo.size.width, geo.size.height
                                   - (content.knoepfe ? metrics.em(3.5) + 6 : 0)
                                   - (style.showLabels ? metrics.em(1.2) : 0)))
            // Im SVG der Web-App: viewBox 120, Kreisradius 52, Strich 8.
            let ring = side * (104.0 / 120.0)
            let lineWidth = side * (8.0 / 120.0)

            VStack(spacing: 6) {
                if style.showLabels {
                    // `.w-timer__label`: 0.84em, gesperrt, gedämpft.
                    Text(content.mode == .countdown ? "TIMER" : "STOPPUHR")
                        .font(Theme.font(metrics.em(0.84), weight: .bold))
                        .tracking(metrics.em(0.84) * 0.09)
                        .foregroundStyle(style.inkSoft)
                }

                ZStack {
                    Circle()
                        .stroke(style.wash, lineWidth: lineWidth)
                        .frame(width: ring, height: ring)
                    Circle()
                        .trim(from: 0, to: max(0.0001, progress))
                        .stroke(ringStyle(value: value),
                                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: style.accent.opacity(0.55), radius: 6)
                        .frame(width: ring, height: ring)
                        .animation(.linear(duration: 0.2), value: progress)

                    // `.w-timer__time`: max(26, min(Breite, Höhe) * 0.24).
                    Text(formatDuration(value))
                        .font(Theme.font(timeSize(geo.size), weight: .heavy))
                        .monospacedDigit()
                        .tracking(-timeSize(geo.size) * 0.02)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .foregroundStyle(timeColor(value: value))
                        .padding(.horizontal, side * 0.14)
                }
                .frame(width: side, height: side)
                .scaleEffect(flashing ? 1.04 : 1.0)

                if content.knoepfe {
                    controls
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(14)
        // Ein Timer wird angetippt, nicht bedient.
        //
        // Die vier Knöpfe waren im Unterricht überflüssig: Ein Tipp auf das
        // Element startet und hält an, ein Doppeltipp setzt zurück, langes
        // Drücken stellt die Dauer ein. Wer die Knöpfe trotzdem will,
        // schaltet sie in den Einstellungen wieder ein.
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { zuruecksetzen() }
        .onTapGesture { anhaltenOderWeiter() }
        .onLongPressGesture(minimumDuration: 0.45) { dauerEinstellen() }
        .onReceive(ticker) { date in
            guard running || flashing else { return }
            now = date
            checkFinished()
        }
        .sheet(isPresented: $showDurationPicker) {
            DurationPickerSheet(duration: $content.duration)
        }
    }

    // MARK: - Bedienung durch Antippen

    private func anhaltenOderWeiter() {
        guard interactive else { return }
        Haptics.tap()
        running ? pause() : start()
    }

    private func zuruecksetzen() {
        guard interactive else { return }
        Haptics.tap()
        reset()
    }

    private func dauerEinstellen() {
        guard interactive, content.mode == .countdown else { return }
        Haptics.tap()
        showDurationPicker = true
    }

    // MARK: - Bedienung

    /// `.w-timer__controls` — vier runde Knöpfe, sonst nichts. Die Dauer
    /// stellt ein Tipp auf die Zeit ein (in der Web-App das Zahnrad).
    private var controls: some View {
        HStack(spacing: 8) {
            RoundControl(title: "−1", size: metrics.em(2.9), style: style) { addMinute(-1) }
                .opacity(content.mode == .stopwatch ? 0 : 1)
            RoundControl(systemImage: "arrow.counterclockwise",
                         size: metrics.em(3.5), style: style) { reset() }
            RoundControl(systemImage: running ? "pause.fill" : "play.fill",
                         primary: true, size: metrics.em(3.5), style: style) {
                running ? pause() : start()
            }
            RoundControl(title: "+1", size: metrics.em(2.9), style: style) { addMinute(1) }
                .opacity(content.mode == .stopwatch ? 0 : 1)
        }
        .disabled(!interactive)
    }

    /// `fit()` in der Web-App: die Zeit wächst mit der kleineren Seite.
    private func timeSize(_ size: CGSize) -> Double {
        max(26, min(Double(size.width), Double(size.height)) * 0.24)
    }

    // MARK: - Zustand

    private var running: Bool {
        content.mode == .countdown ? content.endsAtMs != nil : content.startedAtMs != nil
    }

    /// Anzuzeigender Wert in Sekunden.
    private var displayValue: Double {
        let nowSeconds = now.timeIntervalSince1970
        if content.mode == .countdown {
            if let endsAtMs = content.endsAtMs {
                return max(0, Double(endsAtMs) / 1000 - nowSeconds)
            }
            return content.pausedValue ?? content.duration
        } else {
            if let startedAtMs = content.startedAtMs {
                return (content.pausedValue ?? 0) + max(0, nowSeconds - Double(startedAtMs) / 1000)
            }
            return content.pausedValue ?? 0
        }
    }

    private var progress: Double {
        if content.mode == .countdown {
            guard content.duration > 0 else { return 0 }
            return min(1, max(0, displayValue / content.duration))
        }
        // Stoppuhr: eine Runde pro Minute.
        return displayValue.truncatingRemainder(dividingBy: 60) / 60
    }

    /// Kurz vor Schluss färbt sich auch die Zeit.
    private func timeColor(value: Double) -> Color {
        guard content.mode == .countdown else { return style.ink }
        if value <= 0 { return Theme.danger }
        if value <= max(10, content.duration * 0.1) { return Color(hex: "#f97316") }
        return style.ink
    }

    /// Der Ring läuft im Farbverlauf der Tafel — außer kurz vor Schluss.
    private func ringStyle(value: Double) -> AnyShapeStyle {
        if content.mode == .countdown {
            if value <= 0 { return AnyShapeStyle(Theme.danger) }
            if value <= max(10, content.duration * 0.1) { return AnyShapeStyle(Color(hex: "#f97316")) }
        }
        return AnyShapeStyle(style.accentGradient)
    }

    private func start() {
        now = Date()
        if content.mode == .countdown {
            let remaining = content.pausedValue ?? content.duration
            guard remaining > 0.2 else { return }
            content.endsAtMs = Int64((Date().timeIntervalSince1970 + remaining) * 1000)
            content.pausedValue = nil
        } else {
            content.startedAtMs = Date.nowMs
        }
    }

    private func pause() {
        let value = displayValue
        content.pausedValue = value
        content.endsAtMs = nil
        content.startedAtMs = nil
    }

    private func reset() {
        content.endsAtMs = nil
        content.startedAtMs = nil
        content.pausedValue = nil
        flashing = false
    }

    /// Eine Minute mehr oder weniger — auch während der Timer läuft.
    private func addMinute(_ direction: Double) {
        let step = 60.0 * direction
        if content.mode == .countdown {
            if let endsAtMs = content.endsAtMs {
                content.endsAtMs = max(Date.nowMs, endsAtMs + Int64(step * 1000))
            } else if let paused = content.pausedValue {
                content.pausedValue = max(0, paused + step)
            } else {
                content.duration = max(0, content.duration + step)
            }
        } else {
            content.pausedValue = max(0, (content.pausedValue ?? 0) + step)
        }
    }

    /// Countdown abgelaufen: Signal geben und den Rahmen kurz pulsieren lassen.
    private func checkFinished() {
        guard content.mode == .countdown, let endsAtMs = content.endsAtMs else { return }
        guard Double(endsAtMs) / 1000 <= Date().timeIntervalSince1970 else { return }
        content.endsAtMs = nil
        content.pausedValue = 0
        if content.soundOnEnd { SoundPlayer.playAlarm() }
        Haptics.success()
        withAnimation(.easeInOut(duration: 0.4).repeatCount(6, autoreverses: true)) {
            flashing = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            flashing = false
        }
    }
}

/// Dauer bequem als Minuten/Sekunden einstellen.
struct DurationPickerSheet: View {
    @Binding var duration: Double
    @Environment(\.dismiss) private var dismiss

    @State private var minutes: Int = 5
    @State private var seconds: Int = 0

    var body: some View {
        NavigationStack {
            VStack {
                HStack(spacing: 0) {
                    Picker("Minuten", selection: $minutes) {
                        ForEach(0..<121, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    Text("Min.")
                    Picker("Sekunden", selection: $seconds) {
                        ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    Text("Sek.")
                }
                .padding(.horizontal)
                Spacer()
            }
            .navigationTitle("Timer-Dauer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        duration = Double(minutes * 60 + seconds)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            minutes = Int(duration) / 60
            seconds = Int(duration) % 60
        }
        .presentationDetents([.height(340)])
    }
}
