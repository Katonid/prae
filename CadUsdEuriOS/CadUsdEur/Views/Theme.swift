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

// MARK: - Flaggen (54 x 36, wie in der PWA gezeichnet, keine Bilddateien)

private struct FlagFrame: ViewModifier {
    func body(content: Content) -> some View {
        content
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
