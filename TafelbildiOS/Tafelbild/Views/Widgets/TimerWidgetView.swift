import SwiftUI
import Combine

/// Countdown und Stoppuhr. Die Zeit wird aus Zeitstempeln berechnet, damit
/// sie auch dann stimmt, wenn die App zwischendurch im Hintergrund war.
struct TimerWidgetView: View {
    @Binding var content: TimerContent
    var interactive: Bool

    @Environment(\.boardStyle) private var style

    @State private var now = Date()
    @State private var flashing = false
    @State private var showDurationPicker = false

    private let ticker = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    /// Häufige Unterrichtszeiten in Minuten — wie in der Web-App.
    private let presets: [Double] = [60, 120, 180, 300, 600, 900, 1200, 1800, 2700]

    var body: some View {
        GeometryReader { geo in
            let value = displayValue
            let controlHeight: CGFloat = content.showControls ? 78 : 0
            let labelHeight: CGFloat = style.showLabels ? 24 : 0
            let side = max(70, min(geo.size.width, geo.size.height - controlHeight - labelHeight))

            VStack(spacing: 6) {
                if style.showLabels {
                    Text(content.mode == .countdown ? "TIMER" : "STOPPUHR")
                        .widgetLabel(min(geo.size.width * 0.052, 15), color: style.inkSoft)
                }

                ZStack {
                    Circle()
                        .stroke(style.wash, lineWidth: side * 0.067)
                    Circle()
                        .trim(from: 0, to: max(0.0001, progress))
                        .stroke(ringStyle(value: value),
                                style: StrokeStyle(lineWidth: side * 0.067, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: style.accent.opacity(0.55), radius: side * 0.05)
                        .animation(.linear(duration: 0.2), value: progress)

                    VStack(spacing: 2) {
                        Text(formatDuration(value))
                            .font(Theme.font(side * 0.25, weight: .heavy))
                            .monospacedDigit()
                            .tracking(-side * 0.005)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .foregroundStyle(timeColor(value: value))
                        if content.mode == .countdown && !running && style.showLabels {
                            Text("Dauer ändern")
                                .font(Theme.font(side * 0.07, weight: .medium))
                                .foregroundStyle(style.inkSoft)
                        }
                    }
                    .padding(.horizontal, side * 0.16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard interactive, content.mode == .countdown, !running else { return }
                        Haptics.tap()
                        showDurationPicker = true
                    }
                }
                .frame(width: side, height: side)
                .scaleEffect(flashing ? 1.04 : 1.0)

                if content.showControls {
                    controls(width: geo.size.width)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
        .onReceive(ticker) { date in
            guard running || flashing else { return }
            now = date
            checkFinished()
        }
        .sheet(isPresented: $showDurationPicker) {
            DurationPickerSheet(duration: $content.duration)
        }
    }

    // MARK: - Bedienung

    private func controls(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                RoundControl(title: "−1", size: 44, style: style) { addMinute(-1) }
                RoundControl(systemImage: "arrow.counterclockwise", size: 54, style: style) { reset() }
                RoundControl(systemImage: running ? "pause.fill" : "play.fill",
                             primary: true, size: 54, style: style) {
                    running ? pause() : start()
                }
                RoundControl(title: "+1", size: 44, style: style) { addMinute(1) }
            }
            .disabled(!interactive)

            if content.mode == .countdown && !running && content.pausedValue == nil && width > 300 {
                HStack(spacing: 5) {
                    ForEach(presets, id: \.self) { preset in
                        let active = abs(content.duration - preset) < 1
                        Button {
                            guard interactive else { return }
                            Haptics.tap()
                            content.duration = preset
                        } label: {
                            Text("\(Int(preset / 60))")
                                .font(Theme.font(13.5, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(active ? Color.white : style.inkSoft)
                                .frame(width: 30, height: 26)
                                .background {
                                    Capsule().fill(active
                                                   ? AnyShapeStyle(style.accentGradient)
                                                   : AnyShapeStyle(style.wash))
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(!interactive)
                    }
                    Text("Min.")
                        .font(Theme.font(12, weight: .medium))
                        .foregroundStyle(style.inkSoft)
                }
            }
        }
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
