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
                        if content.showDate && style.showLabels { dateLine(context.date, size: size) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .digital:
                    VStack(spacing: 6) {
                        digitalTime(context.date, size: size)
                        if content.showDate && style.showLabels { dateLine(context.date, size: size) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .both:
                    VStack(spacing: 6) {
                        analogFace(date: context.date, side: faceSide(in: size, share: 0.62))
                        digitalTime(context.date, size: size, scale: 0.55)
                        if content.showDate && style.showLabels { dateLine(context.date, size: size) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(14)
    }

    private func faceSide(in size: CGSize, share: CGFloat) -> CGFloat {
        let height = (content.showDate && style.showLabels) ? size.height - 46 : size.height
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

    private func ticks(side: CGFloat) -> some View {
        // „Minimal" zeigt nur die Fünf-Minuten-Striche.
        let indexes = face == .minimal ? Array(stride(from: 0, to: 60, by: 5)) : Array(0..<60)
        let outer: Double = isLearning ? 79 : 88
        return ForEach(indexes, id: \.self) { index in
            let major = index % 5 == 0
            let inner = major ? outer - (face == .minimal ? 9 : 8) : outer - 4
            let length = outer - inner
            Rectangle()
                .fill(tickColor.opacity(major ? 1 : 0.4))
                .frame(width: unit(major ? (face == .modern ? 3.2 : 3) : 1.4, side),
                       height: unit(length, side))
                .offset(y: -unit((outer + inner) / 2, side))
                .rotationEffect(.degrees(Double(index) * 6))
        }
    }

    @ViewBuilder
    private func numbers(side: CGFloat) -> some View {
        if face == .minimal {
            ForEach([12, 3, 6, 9], id: \.self) { number in
                Text("\(number)")
                    .font(Theme.font(Double(unit(19, side)), weight: .semibold))
                    .foregroundStyle(faceInk.opacity(0.5))
                    .rotationEffect(.degrees(-Double(number) * 30))
                    .offset(y: -unit(68, side))
                    .rotationEffect(.degrees(Double(number) * 30))
            }
        } else {
            ForEach(1...12, id: \.self) { number in
                Text("\(number)")
                    .font(Theme.font(Double(unit(face == .modern ? 21 : 23, side)),
                                     weight: face == .modern ? .semibold : .bold))
                    .foregroundStyle(isLearning ? Self.hourBlue : faceInk.opacity(0.85))
                    .rotationEffect(.degrees(-Double(number) * 30))
                    .offset(y: -unit(isLearning ? 60 : 66, side))
                    .rotationEffect(.degrees(Double(number) * 30))
            }
            if isLearning {
                // Außen die Minutenzahlen 5, 10, 15 … in Orange.
                ForEach(Array(stride(from: 5, through: 60, by: 5)), id: \.self) { value in
                    Text("\(value == 60 ? 0 : value)")
                        .font(Theme.font(Double(unit(11, side)), weight: .bold))
                        .foregroundStyle(Self.minuteOrange)
                        .rotationEffect(.degrees(-Double(value) * 6))
                        .offset(y: -unit(89, side))
                        .rotationEffect(.degrees(Double(value) * 6))
                }
            }
        }
    }

    /// Zeiger: Drehpunkt liegt im Mittelpunkt des Zifferblatts.
    private func hand(length: CGFloat, width: CGFloat, color: Color, angle: Double) -> some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
            .rotationEffect(.degrees(angle))
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

    private func dateLine(_ date: Date, size: CGSize) -> some View {
        Text(Self.dateText(date))
            .font(Theme.font(metrics.em(0.94), weight: .semibold))
            .foregroundStyle(style.inkSoft)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

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
