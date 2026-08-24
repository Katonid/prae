import SwiftUI
import Combine

/// Countdown und Stoppuhr. Die Zeit wird aus Zeitstempeln berechnet, damit
/// sie auch dann stimmt, wenn die App zwischendurch im Hintergrund war.
struct TimerWidgetView: View {
    @Binding var content: TimerContent
    var interactive: Bool

    @State private var now = Date()
    @State private var flashing = false
    @State private var showDurationPicker = false

    private let ticker = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    private let presets: [Double] = [60, 120, 300, 600, 900, 1200]

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height - (content.showControls ? 62 : 0))
            let value = displayValue
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.14), lineWidth: side * 0.075)
                    Circle()
                        .trim(from: 0, to: max(0.0001, progress))
                        .stroke(ringColor(value: value),
                                style: StrokeStyle(lineWidth: side * 0.075, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.2), value: progress)

                    VStack(spacing: 2) {
                        Text(formatDuration(value))
                            .font(Theme.font(side * 0.26, weight: .bold))
                            .monospacedDigit()
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .foregroundStyle(.white)
                        if content.mode == .countdown && !running {
                            Text("Dauer ändern")
                                .font(Theme.font(side * 0.075, weight: .medium))
                                .foregroundStyle(.white.opacity(0.55))
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
        .padding(18)
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
            HStack(spacing: 10) {
                circleButton("arrow.counterclockwise", tint: .white.opacity(0.16)) { reset() }
                circleButton(running ? "pause.fill" : "play.fill",
                             tint: Color(hex: content.accentHex), large: true) {
                    running ? pause() : start()
                }
                circleButton("plus", tint: .white.opacity(0.16)) { addMinute() }
            }
            if content.mode == .countdown && !running && content.pausedValue == nil {
                HStack(spacing: 6) {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            guard interactive else { return }
                            Haptics.tap()
                            content.duration = preset
                        } label: {
                            Text(preset < 60 ? "\(Int(preset))s" : "\(Int(preset / 60))")
                                .font(Theme.font(15, weight: .semibold))
                                .foregroundStyle(abs(content.duration - preset) < 1 ? .black : .white)
                                .frame(width: 34, height: 28)
                                .background {
                                    Capsule().fill(abs(content.duration - preset) < 1
                                                   ? Color.white : Color.white.opacity(0.12))
                                }
                        }
                        .buttonStyle(.plain)
                        .disabled(!interactive)
                    }
                    Text("Min.")
                        .font(Theme.font(14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }

    private func circleButton(_ symbol: String, tint: Color, large: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button {
            guard interactive else { return }
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: large ? 24 : 18, weight: .bold))
                .foregroundStyle(large ? Color.black : .white)
                .frame(width: large ? 56 : 44, height: large ? 56 : 44)
                .background(Circle().fill(tint))
        }
        .buttonStyle(.plain)
        .opacity(interactive ? 1 : 0.7)
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

    private func ringColor(value: Double) -> Color {
        if content.mode == .countdown {
            if value <= 0 { return Theme.danger }
            if value <= max(10, content.duration * 0.1) { return Theme.amber }
        }
        return Color(hex: content.accentHex)
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

    private func addMinute() {
        if content.mode == .countdown {
            if let endsAtMs = content.endsAtMs {
                content.endsAtMs = endsAtMs + 60_000
            } else if let paused = content.pausedValue {
                content.pausedValue = paused + 60
            } else {
                content.duration += 60
            }
        } else {
            content.pausedValue = (content.pausedValue ?? 0) + 60
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
