import SwiftUI

enum Stil {
    static let akzent = Color(hex: 0xFF6B4A)
    static let nacht = Color(hex: 0x0E1A2B)
    /// Die Farbe einer Wanderung auf jeder Karte (ab 1.0.17) — ein sattes
    /// Grün, damit sie sich von der Reisespur in den Farben der Reise abhebt.
    static let wanderfarbe = Color(hex: 0x2E9E5B)

    static func titel(_ groesse: CGFloat) -> Font { .system(size: groesse, weight: .bold, design: .rounded) }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Die Farbwelt einer Reise.
enum Palette: String, CaseIterable, Identifiable {
    case sonne, meer, wald, abend, wueste, gletscher, kirsche

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sonne: return "Sonne"
        case .meer: return "Meer"
        case .wald: return "Wald"
        case .abend: return "Abend"
        case .wueste: return "Wüste"
        case .gletscher: return "Gletscher"
        case .kirsche: return "Kirschblüte"
        }
    }

    var farben: [Color] {
        switch self {
        case .sonne: return [Color(hex: 0xFFB347), Color(hex: 0xFF5E62)]
        case .meer: return [Color(hex: 0x2BC0E4), Color(hex: 0x1F4E9C)]
        case .wald: return [Color(hex: 0x7ED56F), Color(hex: 0x1E7A55)]
        case .abend: return [Color(hex: 0xB06AB3), Color(hex: 0x3A2A8C)]
        case .wueste: return [Color(hex: 0xF3C98B), Color(hex: 0xC0562F)]
        case .gletscher: return [Color(hex: 0x9BE7F0), Color(hex: 0x3B7DD8)]
        case .kirsche: return [Color(hex: 0xFFC3D8), Color(hex: 0xE0457B)]
        }
    }

    var haupt: Color { farben[1] }
    var hell: Color { farben[0] }

    var verlauf: LinearGradient {
        LinearGradient(colors: farben, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Eine Zahl mit Beschriftung — die Statistikzeile einer Reise.
struct Kennzahl: View {
    let wert: String
    let beschriftung: String
    let symbol: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(wert)
                .font(Stil.titel(20))
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(beschriftung)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Ein pulsierender Punkt — „läuft gerade".
struct Pulspunkt: View {
    var farbe: Color = .red
    @State private var an = false

    var body: some View {
        ZStack {
            Circle().fill(farbe.opacity(0.35))
                .frame(width: 18, height: 18)
                .scaleEffect(an ? 1.3 : 0.6)
                .opacity(an ? 0 : 1)
            Circle().fill(farbe).frame(width: 9, height: 9)
        }
        .frame(width: 18, height: 18)
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { an = true }
        }
    }
}

/// Anfangsbuchstaben in einem Kreis — wer den Eintrag geschrieben hat.
struct Monogramm: View {
    let name: String
    var groesse: CGFloat = 26
    var farbe: Color = Stil.akzent

    var body: some View {
        let teile = name.split(separator: " ").prefix(2).compactMap { $0.first }
        Text(teile.isEmpty ? "?" : String(teile).uppercased())
            .font(.system(size: groesse * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: groesse, height: groesse)
            .background(farbe.gradient, in: Circle())
    }
}

/// Ein weicher Knopfstil mit Verlauf.
struct VerlaufKnopf: ButtonStyle {
    var palette: Palette = .sonne

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(palette.verlauf, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: palette.haupt.opacity(0.35), radius: 14, y: 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}
