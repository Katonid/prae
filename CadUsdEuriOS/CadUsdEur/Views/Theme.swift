import SwiftUI

// Farbwelt: dunkle Premium-Basis, die Länderfarben der PWA
// (Kanada-Rot, US-Navy, Euro-Blau, Gold) als leuchtende Akzente.
enum Theme {
    // Flaggen- und Basisfarben (aus der PWA)
    static let canada = Color(red: 0xD8 / 255, green: 0x06 / 255, blue: 0x21 / 255)
    static let usaRed = Color(red: 0xB2 / 255, green: 0x22 / 255, blue: 0x34 / 255)
    static let usaBlue = Color(red: 0x3C / 255, green: 0x3B / 255, blue: 0x6E / 255)
    static let euroBlue = Color(red: 0x00 / 255, green: 0x33 / 255, blue: 0x99 / 255)
    static let gold = Color(red: 1.0, green: 0xCE / 255, blue: 0x00 / 255)
    static let ink = Color(red: 0x15 / 255, green: 0x15 / 255, blue: 0x15 / 255)
    static let germanBlack = Color.black
    static let germanRed = Color(red: 0xDD / 255, green: 0x00 / 255, blue: 0x00 / 255)

    // Dunkle Bühne
    static let bgTop = Color(red: 0.04, green: 0.05, blue: 0.10)
    static let bgBottom = Color(red: 0.08, green: 0.09, blue: 0.17)

    // Text auf dunklem Grund
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textFaint = Color.white.opacity(0.4)

    // Glas-Flächen
    static let glassStroke = Color.white.opacity(0.14)
    static let glassFill = Color.white.opacity(0.06)
    static let fieldFill = Color.white.opacity(0.07)

    // Leuchtende Akzenttöne (für Beschriftungen auf dunklem Grund)
    static let canadaBright = Color(red: 1.0, green: 0.42, blue: 0.47)
    static let usaBrightRed = Color(red: 1.0, green: 0.47, blue: 0.52)
    static let euroBright = Color(red: 0.48, green: 0.64, blue: 1.0)
    static let goldBright = Color(red: 1.0, green: 0.86, blue: 0.35)

    static func localBright(_ country: Country) -> Color {
        country == .ca ? canadaBright : usaBrightRed
    }

    static func localMain(_ country: Country) -> Color {
        country == .ca ? canada : usaRed
    }

    // Verlaufe
    static func accentGradient(_ country: Country) -> LinearGradient {
        country == .ca
            ? LinearGradient(colors: [Color(red: 1.0, green: 0.28, blue: 0.35), canada],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [usaRed, usaBlue],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let euroGradient = LinearGradient(
        colors: [Color(red: 0.36, green: 0.55, blue: 1.0), euroBlue],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let goldGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.88, blue: 0.38), Color(red: 0.95, green: 0.70, blue: 0.0)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static func rateBarGradient(_ country: Country) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: localMain(country), location: 0),
                .init(color: usaBlue, location: 0.54),
                .init(color: euroBlue, location: 1)
            ],
            startPoint: .leading, endPoint: .trailing
        )
    }
}

// MARK: - Ahornblatt
// Eckpunkte des offiziellen elfzackigen Ahornblatts der kanadischen
// Nationalflagge (aus dem amtlichen Flaggen-SVG extrahiert; die
// Original-Kontur besteht aus geraden Segmenten). Seitenverhältnis 3720:4030.

struct MapleLeaf: Shape {
    static let aspectRatio: CGFloat = 3720.0 / 4030.0

    static let points: [CGPoint] = [
        CGPoint(x: 0.5242, y: 1.0000), CGPoint(x: 0.5121, y: 0.7859), CGPoint(x: 0.5419, y: 0.7615),
        CGPoint(x: 0.7728, y: 0.7990), CGPoint(x: 0.7417, y: 0.7196), CGPoint(x: 0.7470, y: 0.7015),
        CGPoint(x: 1.0000, y: 0.5124), CGPoint(x: 0.9430, y: 0.4878), CGPoint(x: 0.9339, y: 0.4682),
        CGPoint(x: 0.9839, y: 0.3263), CGPoint(x: 0.8382, y: 0.3548), CGPoint(x: 0.8185, y: 0.3454),
        CGPoint(x: 0.7903, y: 0.2841), CGPoint(x: 0.6766, y: 0.3968), CGPoint(x: 0.6468, y: 0.3826),
        CGPoint(x: 0.7016, y: 0.1216), CGPoint(x: 0.6137, y: 0.1685), CGPoint(x: 0.5892, y: 0.1618),
        CGPoint(x: 0.5000, y: 0.0000), CGPoint(x: 0.4108, y: 0.1618), CGPoint(x: 0.3863, y: 0.1685),
        CGPoint(x: 0.2984, y: 0.1216), CGPoint(x: 0.3532, y: 0.3826), CGPoint(x: 0.3234, y: 0.3968),
        CGPoint(x: 0.2097, y: 0.2841), CGPoint(x: 0.1815, y: 0.3454), CGPoint(x: 0.1618, y: 0.3548),
        CGPoint(x: 0.0161, y: 0.3263), CGPoint(x: 0.0661, y: 0.4682), CGPoint(x: 0.0570, y: 0.4878),
        CGPoint(x: 0.0000, y: 0.5124), CGPoint(x: 0.2530, y: 0.7015), CGPoint(x: 0.2583, y: 0.7196),
        CGPoint(x: 0.2272, y: 0.7990), CGPoint(x: 0.4581, y: 0.7615), CGPoint(x: 0.4879, y: 0.7859),
        CGPoint(x: 0.4758, y: 1.0000)
    ]

    func path(in rect: CGRect) -> Path {
        // Blatt formatfüllend, aber unverzerrt in rect einpassen.
        var box = rect
        if rect.width / rect.height > Self.aspectRatio {
            let width = rect.height * Self.aspectRatio
            box = CGRect(x: rect.midX - width / 2, y: rect.minY, width: width, height: rect.height)
        } else {
            let height = rect.width / Self.aspectRatio
            box = CGRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height)
        }
        var path = Path()
        let scaled = Self.points.map {
            CGPoint(x: box.minX + $0.x * box.width, y: box.minY + $0.y * box.height)
        }
        path.addLines(scaled)
        path.closeSubpath()
        return path
    }
}

// MARK: - Flaggen (wie das Original gezeichnet, keine Bilddateien)

private struct FlagFrame: ViewModifier {
    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 8, y: 5)
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
                    .frame(width: proxy.size.width * 0.41, height: proxy.size.height * 0.67)
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
                    .frame(width: proxy.size.width * 0.43, height: proxy.size.height * 0.53)
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

// MARK: - Bühnenbild: dunkler Verlauf mit farbigen Lichtinseln
// und einem großen, dezenten Länder-Wasserzeichen.

struct CountryBackground: View {
    let country: Country

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.bgTop, Theme.bgBottom],
                           startPoint: .top, endPoint: .bottom)
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    // Lichtinseln in den Länderfarben
                    Circle()
                        .fill((country == .ca ? Theme.canada : Theme.usaBlue).opacity(0.5))
                        .frame(width: size.width * 1.2, height: size.width * 1.2)
                        .blur(radius: 80)
                        .position(x: country == .ca ? size.width * 0.12 : size.width * 0.88,
                                  y: size.height * 0.02)
                    Circle()
                        .fill((country == .ca ? Theme.gold : Theme.usaRed).opacity(0.22))
                        .frame(width: size.width * 0.9, height: size.width * 0.9)
                        .blur(radius: 80)
                        .position(x: country == .ca ? size.width * 1.0 : size.width * 0.0,
                                  y: size.height * 0.4)
                    Circle()
                        .fill(Theme.euroBlue.opacity(0.45))
                        .frame(width: size.width * 1.1, height: size.width * 1.1)
                        .blur(radius: 80)
                        .position(x: size.width * 0.5, y: size.height * 1.02)

                    // Wasserzeichen: Ahornblatt bzw. Stern
                    if country == .ca {
                        MapleLeaf()
                            .fill(Color.white.opacity(0.045))
                            .frame(width: size.width * 1.15, height: size.width * 1.25)
                            .rotationEffect(.degrees(10))
                            .position(x: size.width * 0.85, y: size.height * 0.32)
                    } else {
                        Image(systemName: "star.fill")
                            .font(.system(size: size.width * 0.9))
                            .foregroundStyle(Color.white.opacity(0.045))
                            .rotationEffect(.degrees(-12))
                            .position(x: size.width * 0.15, y: size.height * 0.3)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}
