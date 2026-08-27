import SwiftUI

/// Uhr — analog mit vier Zifferblättern (Modern, Klassisch, Lernuhr,
/// Minimal), digital oder beides.
struct ClockWidgetView: View {
    let content: ClockContent

    @Environment(\.boardStyle) private var style
    @Environment(\.widgetMetrics) private var metrics

    /// Lernuhr: Stundenzeiger blau, Minutenzeiger orange — die im
    /// Unterricht übliche Farbgebung.
    private static let hourBlue = Color(hex: "#2563eb")
    private static let minuteOrange = Color(hex: "#ea580c")

    private var face: ClockFace { content.face }

    var body: some View {
        TimelineView(.periodic(from: .now, by: content.showSeconds ? 0.5 : 5)) { context in
            GeometryReader { geo in
                let size = geo.size
                switch content.style {
                case .analog:
                    VStack(spacing: 6) {
                        analogFace(date: context.date, side: faceSide(in: size, share: 1.0))
                        if content.showDate { dateLine(context.date, size: size) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .digital:
                    VStack(spacing: 6) {
                        digitalTime(context.date, size: size)
                        if content.showDate { dateLine(context.date, size: size) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .both:
                    VStack(spacing: 6) {
                        analogFace(date: context.date, side: faceSide(in: size, share: 0.62))
                        digitalTime(context.date, size: size, scale: 0.55)
                        if content.showDate { dateLine(context.date, size: size) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(14)
    }

    private func faceSide(in size: CGSize, share: CGFloat) -> CGFloat {
        // Platz für das Datum: seine Zeilenhöhe plus etwas Luft. Vorher
        // standen hier feste 46 Punkte — die passten zur alten, kleinen
        // Schrift und ließen die Zeile jetzt am Zifferblatt kleben.
        let height = content.showDate ? size.height - datumGroesse * 1.9 : size.height
        return max(60, min(size.width, height * share))
    }

    // MARK: - Analoges Zifferblatt

    /// Alle Maße folgen der Web-App: dort liegt das Zifferblatt in einem
    /// Feld von 200 × 200 mit Radius 94. Hier wird derselbe Anteil auf die
    /// tatsächliche Kantenlänge gerechnet.
    private func unit(_ value: Double, _ side: CGFloat) -> CGFloat {
        side * CGFloat(value / 200)
    }

    private var isLearning: Bool { face == .lernuhr }

    /// Farbe des Zifferblatts — hell, damit die Uhr auch auf dunklen Karten
    /// wie eine echte Wanduhr wirkt.
    private var faceColor: AnyShapeStyle {
        style.isDarkCard ? AnyShapeStyle(Color(hex: "#f8fafc"))
                         : Fuellung.stil(content.faceHex, content.faceHex2)
    }

    private var faceInk: Color { Color(hex: "#0f172a") }

    private func analogFace(date: Date, side: CGFloat) -> some View {
        let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double(parts.hour ?? 0).truncatingRemainder(dividingBy: 12)
        let minute = Double(parts.minute ?? 0)
        let second = Double(parts.second ?? 0)

        return ZStack {
            Circle()
                .fill(faceColor)
                .shadow(color: .black.opacity(0.25), radius: side * 0.04, y: side * 0.015)
            Circle()
                .strokeBorder(ringColor, lineWidth: unit(ringWidth, side))
                .frame(width: unit(188, side), height: unit(188, side))

            ticks(side: side)
            numbers(side: side)

            hand(length: unit(isLearning ? 42 : 46, side), width: unit(isLearning ? 8 : 7, side),
                 color: isLearning ? Self.hourBlue : faceInk,
                 angle: (hour + minute / 60) / 12 * 360)
            hand(length: unit(isLearning ? 74 : 71, side), width: unit(isLearning ? 5.5 : 4.8, side),
                 color: isLearning ? Self.minuteOrange : faceInk,
                 angle: (minute + second / 60) / 60 * 360)
            if content.showSeconds {
                hand(length: unit(76, side), width: unit(2.4, side),
                     color: style.accent, angle: second / 60 * 360)
            }
            Circle()
                .fill(style.accentGradient)
                .frame(width: unit(isLearning ? 9 : 10, side), height: unit(isLearning ? 9 : 10, side))
            Circle()
                .fill(faceColor)
                .frame(width: unit(4, side), height: unit(4, side))
        }
        .frame(width: side, height: side)
    }

    private var ringColor: Color {
        switch face {
        case .modern, .minimal: return style.accent.opacity(0.25)
        case .klassisch:        return style.accent
        case .lernuhr:          return Self.hourBlue
        }
    }

    private var ringWidth: Double {
        switch face {
        case .modern, .minimal: return 2
        case .klassisch:        return 3
        case .lernuhr:          return 2.5
        }
    }

    /// Farbe der Skalenstriche.
    private var tickColor: Color {
        switch face {
        case .lernuhr:   return Self.minuteOrange
        case .klassisch: return style.accent
        default:         return Color(hex: "#334155")
        }
    }

    /// Die Skala — zwei Pfade statt sechzig gedrehter Rechtecke.
    ///
    /// Gedrehte Ebenen werden beim Zeichnen neu abgetastet; genau daran lag
    /// es, dass das Zifferblatt weich wirkte. Ein Pfad trägt die Drehung in
    /// seinen Koordinaten und bleibt scharf (siehe Rundblatt.swift).
    @ViewBuilder
    private func ticks(side: CGFloat) -> some View {
        // „Minimal" zeigt nur die Fünf-Minuten-Striche.
        let outer: Double = isLearning ? 79 : 88
        let innenGross = outer - (face == .minimal ? 9 : 8)
        let grosse = Array(stride(from: 0, to: 60, by: 5)).map { Double($0) * 6 }
        // Die Skala steht in 200er-Einheiten, `Skalenstriche` rechnet in
        // Anteilen des halben Blatts — also durch 100.
        Skalenstriche(winkel: grosse, aussen: outer / 100, innen: innenGross / 100,
                      staerke: unit(face == .modern ? 3.2 : 3, side))
            .fill(tickColor)
        if face != .minimal {
            let kleine = (0..<60).filter { $0 % 5 != 0 }.map { Double($0) * 6 }
            Skalenstriche(winkel: kleine, aussen: outer / 100, innen: (outer - 4) / 100,
                          staerke: unit(1.4, side))
                .fill(tickColor.opacity(0.4))
        }
    }

    @ViewBuilder
    private func numbers(side: CGFloat) -> some View {
        if face == .minimal {
            ForEach([12, 3, 6, 9], id: \.self) { number in
                Text("\(number)")
                    .font(Theme.font(Double(unit(19, side)), weight: .semibold))
                    .foregroundStyle(faceInk.opacity(0.5))
                    .offset(Rundblatt.versatz(Double(number) * 30,
                                              radius: Double(unit(68, side))))
            }
        } else {
            ForEach(1...12, id: \.self) { number in
                Text("\(number)")
                    .font(Theme.font(Double(unit(face == .modern ? 21 : 23, side)),
                                     weight: face == .modern ? .semibold : .bold))
                    .foregroundStyle(isLearning ? Self.hourBlue : faceInk.opacity(0.85))
                    .offset(Rundblatt.versatz(Double(number) * 30,
                                              radius: Double(unit(isLearning ? 60 : 66, side))))
            }
            if isLearning {
                // Außen die Minutenzahlen 5, 10, 15 … in Orange.
                ForEach(Array(stride(from: 5, through: 60, by: 5)), id: \.self) { value in
                    Text("\(value == 60 ? 0 : value)")
                        .font(Theme.font(Double(unit(11, side)), weight: .bold))
                        .foregroundStyle(Self.minuteOrange)
                        .offset(Rundblatt.versatz(Double(value) * 6,
                                                  radius: Double(unit(89, side))))
                }
            }
        }
    }

    /// Zeiger: Drehpunkt liegt im Mittelpunkt des Zifferblatts.
    ///
    /// Als Pfad, nicht als gedrehte Kapsel — aus demselben Grund wie bei der
    /// Skala: Eine gedrehte Ebene wird neu abgetastet und bekommt weiche
    /// Kanten, ein Pfad nicht.
    private func hand(length: CGFloat, width: CGFloat, color: Color, angle: Double) -> some View {
        Zeigerstrich(winkel: angle, laenge: Double(length), staerke: Double(width))
            .fill(color)
    }

    // MARK: - Digital

    private func digitalTime(_ date: Date, size: CGSize, scale: CGFloat = 1.0) -> some View {
        let base = min(size.width / 4.6, size.height * 0.62)
        return Text(Self.timeText(date, showSeconds: content.showSeconds, twentyFour: content.twentyFourHour))
            .font(Theme.font(Double(base * scale), weight: .heavy))
            .monospacedDigit()
            .tracking(-Double(base * scale) * 0.03)
            .minimumScaleFactor(0.4)
            .lineLimit(1)
            // `.w-clock__digital` trägt den Farbverlauf der Tafel.
            .foregroundStyle(style.bigText)
    }

    /// Das Datum hängt bewusst NICHT an der Tafelregel „Beschriftungen“.
    ///
    /// Wer „Datum anzeigen“ einschaltet, will es sehen — und wunderte sich
    /// zu Recht, wenn es trotzdem fehlte, weil die Tafel gerade keine
    /// Beschriftungen zeigt. Die Regel gilt für Beiwerk, nicht für
    /// ausdrücklich eingeschaltete Inhalte.
    private func dateLine(_ date: Date, size: CGSize) -> some View {
        Text(Self.dateText(date))
            .font(Theme.font(datumGroesse, weight: .bold))
            .foregroundStyle(style.inkSoft)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    /// Größe des Datums.
    ///
    /// Stand bei 0,94em und war damit kleiner als jede andere Überschrift —
    /// „Dienstag, 25. August" ist aber eine Angabe, die aus der letzten
    /// Reihe zu lesen sein soll. Jetzt 1,45em, und mit dem Maßstab des
    /// Elements einstellbar wie die übrigen Überschriften.
    private var datumGroesse: Double { metrics.em(style.kopf(1.45)) }

    // MARK: - Formate

    private static let timeFormatter24 = makeFormatter("HH:mm")
    private static let timeFormatter24s = makeFormatter("HH:mm:ss")
    private static let timeFormatter12 = makeFormatter("h:mm a")
    private static let timeFormatter12s = makeFormatter("h:mm:ss a")
    private static let dateFormatter = makeFormatter("EEEE, d. MMMM")

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = format
        return formatter
    }

    static func timeText(_ date: Date, showSeconds: Bool, twentyFour: Bool) -> String {
        switch (twentyFour, showSeconds) {
        case (true, true): return timeFormatter24s.string(from: date)
        case (true, false): return timeFormatter24.string(from: date)
        case (false, true): return timeFormatter12s.string(from: date)
        case (false, false): return timeFormatter12.string(from: date)
        }
    }

    static func dateText(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
