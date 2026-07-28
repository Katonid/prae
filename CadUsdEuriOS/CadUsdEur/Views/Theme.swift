import SwiftUI

// Farbwerte 1:1 aus dem Stylesheet der PWA.
enum Theme {
    static let canada = Color(red: 0xD8 / 255, green: 0x06 / 255, blue: 0x21 / 255)
    static let canadaDark = Color(red: 0x9F / 255, green: 0x00 / 255, blue: 0x18 / 255)
    static let canadaSoft = Color(red: 1.0, green: 0xF0 / 255, blue: 0xF2 / 255)
    static let usaRed = Color(red: 0xB2 / 255, green: 0x22 / 255, blue: 0x34 / 255)
    static let usaBlue = Color(red: 0x3C / 255, green: 0x3B / 255, blue: 0x6E / 255)
    static let usaSoft = Color(red: 1.0, green: 0xF1 / 255, blue: 0xF3 / 255)
    static let euroBlue = Color(red: 0x00 / 255, green: 0x33 / 255, blue: 0x99 / 255)
    static let euroSoft = Color(red: 0xE7 / 255, green: 0xEF / 255, blue: 0xFF / 255)
    static let gold = Color(red: 1.0, green: 0xCE / 255, blue: 0x00 / 255)
    static let ink = Color(red: 0x15 / 255, green: 0x15 / 255, blue: 0x15 / 255)
    static let muted = Color(red: 0x63 / 255, green: 0x63 / 255, blue: 0x63 / 255)
    static let line = Color(red: 0x15 / 255, green: 0x15 / 255, blue: 0x15 / 255).opacity(0.14)
    static let germanBlack = Color.black
    static let germanRed = Color(red: 0xDD / 255, green: 0x00 / 255, blue: 0x00 / 255)

    static func localMain(_ country: Country) -> Color {
        country == .ca ? canada : usaRed
    }

    static func localDark(_ country: Country) -> Color {
        country == .ca ? canadaDark : usaBlue
    }

    static func localSoft(_ country: Country) -> Color {
        country == .ca ? canadaSoft : usaSoft
    }
}

// MARK: - Ahornblatt (clip-path-Polygon der PWA als Shape)

struct MapleLeaf: Shape {
    static let points: [CGPoint] = [
        CGPoint(x: 0.50, y: 0.00), CGPoint(x: 0.61, y: 0.30), CGPoint(x: 0.92, y: 0.17),
        CGPoint(x: 0.76, y: 0.48), CGPoint(x: 1.00, y: 0.55), CGPoint(x: 0.66, y: 0.62),
        CGPoint(x: 0.70, y: 1.00), CGPoint(x: 0.50, y: 0.76), CGPoint(x: 0.30, y: 1.00),
        CGPoint(x: 0.34, y: 0.62), CGPoint(x: 0.00, y: 0.55), CGPoint(x: 0.24, y: 0.48),
        CGPoint(x: 0.08, y: 0.17), CGPoint(x: 0.39, y: 0.30)
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scaled = Self.points.map {
            CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height)
        }
        path.addLines(scaled)
        path.closeSubpath()
        return path
    }
}

// MARK: - Flaggen (54 x 36, wie in der PWA gezeichnet, keine Bilddateien)

private struct FlagFrame: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: 54, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Theme.ink.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: Theme.ink.opacity(0.1), radius: 9, y: 8)
    }
}

struct CanadaFlag: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack {
                HStack(spacing: 0) {
                    Theme.canada.frame(width: width * 0.25)
                    Color.white
                    Theme.canada.frame(width: width * 0.25)
                }
                MapleLeaf()
                    .fill(Theme.canada)
                    .frame(width: 14, height: 20)
            }
        }
        .modifier(FlagFrame())
    }
}

struct USFlag: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { index in
                        (index.isMultiple(of: 2) ? Theme.usaRed : Color.white)
                            .frame(height: proxy.size.height / 6)
                    }
                }
                Theme.usaBlue
                    .frame(width: 23, height: 19)
            }
        }
        .modifier(FlagFrame())
    }
}

struct GermanyFlag: View {
    var body: some View {
        VStack(spacing: 0) {
            Theme.germanBlack
            Theme.germanRed
            Theme.gold
        }
        .modifier(FlagFrame())
    }
}

// MARK: - Seitenhintergründe (Portierung der body-Verläufe)

struct CountryBackground: View {
    let country: Country

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            if country == .ca {
                // Kanada: rote Randstreifen, weiße Mitte, weiße Kreisfläche oben.
                ZStack {
                    HStack(spacing: 0) {
                        Theme.canada.frame(width: size.width * 0.19)
                        Color.white
                        Theme.canada.frame(width: size.width * 0.19)
                    }
                    Circle()
                        .fill(Color.white.opacity(0.98))
                        .frame(width: max(size.width, size.height) * 0.19)
                        .position(x: size.width * 0.5, y: size.height * 0.13)
                }
            } else {
                // USA: rot-weiße Querstreifen, marineblaue Diagonale oben links.
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        let stripe: CGFloat = 28
                        let count = Int(ceil(size.height / stripe)) + 1
                        ForEach(0..<count, id: \.self) { index in
                            (index.isMultiple(of: 2) ? Theme.usaRed : Color.white)
                                .frame(height: stripe)
                        }
                    }
                    Path { path in
                        let reach = (size.width + size.height) * 0.41
                        path.move(to: .zero)
                        path.addLine(to: CGPoint(x: reach, y: 0))
                        path.addLine(to: CGPoint(x: 0, y: reach))
                        path.closeSubpath()
                    }
                    .fill(Theme.usaBlue.opacity(0.95))
                }
            }
        }
        .ignoresSafeArea()
    }
}
