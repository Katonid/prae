import SwiftUI

/// Uhr — analog (mit Ziffern, wie im Unterricht gebraucht), digital oder beides.
struct ClockWidgetView: View {
    let content: ClockContent

    private var accent: Color { Color(hex: content.accentHex) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: content.showSeconds ? 0.5 : 5)) { context in
            GeometryReader { geo in
                let size = geo.size
                switch content.style {
                case .analog:
                    VStack(spacing: 10) {
                        analogFace(date: context.date, side: faceSide(in: size, share: 1.0))
                        if content.showDate { dateLine(context.date, size: size) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .digital:
                    VStack(spacing: 8) {
                        digitalTime(context.date, size: size)
                        if content.showDate { dateLine(context.date, size: size) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .both:
                    VStack(spacing: 12) {
                        analogFace(date: context.date, side: faceSide(in: size, share: 0.62))
                        digitalTime(context.date, size: size, scale: 0.55)
                        if content.showDate { dateLine(context.date, size: size) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(18)
    }

    private func faceSide(in size: CGSize, share: CGFloat) -> CGFloat {
        let height = content.showDate ? size.height - 46 : size.height
        return max(60, min(size.width, height * share))
    }

    // MARK: - Analog

    private func analogFace(date: Date, side: CGFloat) -> some View {
        let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double(parts.hour ?? 0).truncatingRemainder(dividingBy: 12)
        let minute = Double(parts.minute ?? 0)
        let second = Double(parts.second ?? 0)

        return ZStack {
            Circle()
                .fill(Color(hex: content.faceHex))
                .shadow(color: .black.opacity(0.25), radius: side * 0.04, y: side * 0.015)
            Circle()
                .strokeBorder(accent.opacity(0.9), lineWidth: side * 0.035)

            ForEach(0..<60, id: \.self) { index in
                Rectangle()
                    .fill(Color.black.opacity(index % 5 == 0 ? 0.8 : 0.28))
                    .frame(width: index % 5 == 0 ? side * 0.014 : side * 0.006,
                           height: index % 5 == 0 ? side * 0.05 : side * 0.026)
                    .offset(y: -side * 0.5 + side * 0.075)
                    .rotationEffect(.degrees(Double(index) * 6))
            }

            // Ziffern: Text gegenrotieren, damit er trotz Drehung um das
            // Zifferblatt aufrecht steht.
            ForEach(1...12, id: \.self) { number in
                Text("\(number)")
                    .font(Theme.font(side * 0.1, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .rotationEffect(.degrees(-Double(number) * 30))
                    .offset(y: -side * 0.33)
                    .rotationEffect(.degrees(Double(number) * 30))
            }

            hand(length: side * 0.26, width: side * 0.038, color: .black.opacity(0.85),
                 angle: (hour + minute / 60) / 12 * 360)
            hand(length: side * 0.37, width: side * 0.026, color: .black.opacity(0.85),
                 angle: (minute + second / 60) / 60 * 360)
            if content.showSeconds {
                hand(length: side * 0.41, width: side * 0.010, color: accent, angle: second / 60 * 360)
            }
            Circle()
                .fill(accent)
                .frame(width: side * 0.06, height: side * 0.06)
        }
        .frame(width: side, height: side)
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
            .font(Theme.font(base * scale, weight: .bold))
            .monospacedDigit()
            .minimumScaleFactor(0.4)
            .lineLimit(1)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
    }

    private func dateLine(_ date: Date, size: CGSize) -> some View {
        Text(Self.dateText(date))
            .font(Theme.font(min(size.width * 0.07, 30), weight: .medium))
            .foregroundStyle(.white.opacity(0.85))
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
