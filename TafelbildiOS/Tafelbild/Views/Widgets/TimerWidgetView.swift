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
                                   - (style.showLabels ? metrics.em(1.2) : 0)
                                   - (zeitUnterScheibe ? metrics.em(2.4) : 0)))
            // Im SVG der Web-App: viewBox 120, Kreisradius 52, Strich 8.
            let ring = side * (104.0 / 120.0)
            let lineWidth = side * (8.0 / 120.0)

            VStack(spacing: 6) {
                if style.showLabels {
                    // `.w-timer__label`: 0.84em, gesperrt, gedämpft.
                    Text(content.mode == .countdown ? "TIMER" : "STOPPUHR")
                        .font(Theme.font(metrics.em(style.kopf(0.84)), weight: .bold))
                        .tracking(metrics.em(style.kopf(0.84)) * 0.09)
                        .foregroundStyle(style.inkSoft)
                }

                Group {
                    if content.darstellung == .scheibe {
                        TimerScheibe(content: content, restSekunden: value, seite: side)
                    } else {
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
                    }
                }
                .frame(width: side, height: side)
                .scaleEffect(flashing ? 1.04 : 1.0)

                // Bei der Scheibe steht die Zahl unter dem Blatt — in der
                // Mitte käme sie dem Zeiger in die Quere.
                if zeitUnterScheibe {
                    Text(formatDuration(value))
                        .font(Theme.font(metrics.em(1.7), weight: .heavy))
                        .monospacedDigit()
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .foregroundStyle(timeColor(value: value))
                }

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

    /// Zeigt die Scheibe die Zeit zusätzlich als Zahl?
    private var zeitUnterScheibe: Bool {
        content.darstellung == .scheibe && content.zeitZeigen
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

// MARK: - Ablaufende Scheibe

/// Die ablaufende Farbfläche auf einem Ziffernblatt.
///
/// Das Vorbild steht in vielen Klassenzimmern. Sein Kunstgriff: Das Blatt
/// ist **gegen** den Uhrzeigersinn beschriftet — 0 oben, dann 5, 10, 15 nach
/// links herum. Dadurch wandert der Zeiger im Uhrzeigersinn auf die 0 zu und
/// die Farbfläche schrumpft mit ihm. Wer noch keine Uhr lesen kann, sieht
/// trotzdem sofort, wie viel Zeit übrig ist: als Fläche, nicht als Zahl.
struct TimerScheibe: View {
    let content: TimerContent
    /// Anzuzeigender Wert in Sekunden — Rest beim Countdown, gelaufene Zeit
    /// bei der Stoppuhr.
    let restSekunden: Double
    /// Kantenlänge des Quadrats, in das die Scheibe passen muss.
    let seite: Double

    private var skala: Double { max(1, content.skala) }
    private var radius: Double { seite / 2 }

    /// Anteil des vollen Kreises, den die Farbfläche bedeckt (0 … 1).
    ///
    /// Ist die eingestellte Dauer größer als das Blatt fasst, steht die
    /// Fläche zunächst voll und beginnt erst zu schrumpfen, wenn die
    /// Restzeit auf die Skala gefallen ist — genau wie beim Vorbild.
    private var anteil: Double {
        let minuten = max(0, restSekunden) / 60
        if content.mode == .stopwatch {
            // Stoppuhr: eine Umdrehung je Skalenlänge, dann von vorn.
            return minuten.truncatingRemainder(dividingBy: skala) / skala
        }
        return min(1, minuten / skala)
    }

    /// Die Farbfläche bleibt innerhalb des Ziffernkranzes.
    private var flaeche: Double {
        radius * (content.ziffernblatt.zeigtZahlen ? 0.70 : 0.88)
    }

    private var kranz: Double { radius * 0.94 }

    private var strichfarbe: Color {
        Fuellung.istHell(content.blattHex) ? Color(hex: "#0f172a") : Color(hex: "#f8fafc")
    }

    /// Abstand der beschrifteten Striche, damit die Zahlen aufgehen.
    private var grosserSchritt: Int {
        switch Int(skala) {
        case ...5:  return 1
        case ...10: return 2
        case ...60: return 5
        default:    return 15
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: content.blattHex))
                .overlay {
                    Circle().strokeBorder(strichfarbe.opacity(0.16),
                                          lineWidth: max(1, seite * 0.012))
                }
                .shadow(color: .black.opacity(0.3), radius: seite * 0.04, y: seite * 0.012)

            Sektor(anteil: anteil)
                .fill(Fuellung.stil(content.scheibeHex, content.scheibeHex2))
                .frame(width: flaeche * 2, height: flaeche * 2)
                .animation(.linear(duration: 0.25), value: anteil)

            if content.ziffernblatt.zeigtStriche { striche }
            if content.ziffernblatt.zeigtZahlen { zahlen }
            if content.zeiger { zeiger }
        }
        .frame(width: seite, height: seite)
    }

    // MARK: Ziffernblatt

    private var marken: [Int] {
        Array(stride(from: 0, to: Int(skala), by: grosserSchritt))
    }

    private var striche: some View {
        ZStack {
            // Feine Striche je Minute — nur, solange sie nicht ineinander
            // laufen. Bei 120 Minuten auf einem Blatt wäre das ein Filz.
            if skala <= 60 {
                ForEach(Array(0..<Int(skala)), id: \.self) { minute in
                    if minute % grosserSchritt != 0 {
                        strich(minute, laenge: radius * 0.045,
                               dicke: max(1, seite * 0.006),
                               farbe: strichfarbe.opacity(0.4))
                    }
                }
            }
            ForEach(marken, id: \.self) { minute in
                strich(minute, laenge: radius * 0.085,
                       dicke: max(1.5, seite * 0.013),
                       farbe: strichfarbe.opacity(0.85))
            }
        }
    }

    private func strich(_ minute: Int, laenge: Double, dicke: Double, farbe: Color) -> some View {
        Capsule()
            .fill(farbe)
            .frame(width: dicke, height: laenge)
            .offset(y: -(kranz - laenge / 2))
            .rotationEffect(lage(Double(minute)))
    }

    private var zahlen: some View {
        ForEach(marken, id: \.self) { minute in
            Text("\(minute)")
                .font(Theme.font(seite * 0.105, weight: .heavy))
                .foregroundStyle(strichfarbe)
                .offset(stelle(Double(minute), abstand: radius * 0.80))
        }
    }

    private var zeiger: some View {
        ZStack {
            Capsule()
                .fill(strichfarbe)
                .frame(width: max(2, seite * 0.024), height: radius * 0.76)
                .offset(y: -radius * 0.38)
                .rotationEffect(.degrees(-anteil * 360))
            Circle()
                .fill(strichfarbe)
                .frame(width: seite * 0.08, height: seite * 0.08)
        }
        .shadow(color: .black.opacity(0.25), radius: seite * 0.012)
        .animation(.linear(duration: 0.25), value: anteil)
    }

    // MARK: Lage auf dem Blatt

    /// Wo eine Minutenmarke sitzt — gegen den Uhrzeigersinn ab 12 Uhr.
    private func lage(_ minute: Double) -> Angle {
        .degrees(-(minute / skala) * 360)
    }

    /// Dasselbe als Versatz, für aufrecht stehende Zahlen.
    private func stelle(_ minute: Double, abstand: Double) -> CGSize {
        let winkel = -Double.pi / 2 - (minute / skala) * 2 * .pi
        return CGSize(width: cos(winkel) * abstand, height: sin(winkel) * abstand)
    }
}

/// Kreisausschnitt von der Zeigerstellung im Uhrzeigersinn zurück zur 0.
private struct Sektor: Shape {
    /// 0 … 1 des vollen Kreises.
    var anteil: Double

    var animatableData: Double {
        get { anteil }
        set { anteil = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var pfad = Path()
        let wert = min(max(anteil, 0), 1)
        guard wert > 0.0005 else { return pfad }
        let mitte = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        // 12 Uhr liegt bei -90°; von dort aus rückwärts um den nicht mehr
        // gefüllten Teil, dann im Uhrzeigersinn wieder bis 12 Uhr.
        let start = Angle.degrees(-90 + (1 - wert) * 360)
        pfad.move(to: mitte)
        pfad.addArc(center: mitte, radius: r, startAngle: start,
                    endAngle: .degrees(270), clockwise: false)
        pfad.closeSubpath()
        return pfad
    }
}
