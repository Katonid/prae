import SwiftUI

// WAS AUF DER KARTE STEHT — vier Ebenen, einzeln schaltbar (ab 1.0.26,
// Ansage des Nutzers 09/2026: „Ich möchte, dass in beiden Darstellungen alle
// vier Dinge zu sehen sind und auch einzeln ausfilterbar sind: Komoot,
// Autofahrt, GPX-Koordinaten der Fotos und gegebenenfalls auch der Import
// aus der Tagesspur.")
//
// - Reisespur (aufgezeichnet bzw. aus der Tagesspur übernommen),
// - Autofahrten (GPX),
// - Wanderungen (Komoot / GPX),
// - Fotos (jedes Foto mit Ort als kleines Bild an seiner Stelle).
//
// Die Wahl gilt für ALLE Karten der Reise zugleich — die Gesamtkarte, die
// Karte jedes Tages und ihr Vollbild — und wird je Gerät gemerkt. Zwei
// getrennte Schalterreihen liefen auseinander, und dann zeigte die
// Tageskarte etwas anderes als der Tag in der Gesamtkarte.
enum Kartenebene: String, CaseIterable, Identifiable {
    case reisespur, fahrt, wanderung, fotos
    var id: String { rawValue }

    var name: String {
        switch self {
        case .reisespur: return "Spur"
        case .fahrt: return "Autofahrten"
        case .wanderung: return "Wanderungen"
        case .fotos: return "Fotos"
        }
    }

    var symbol: String {
        switch self {
        case .reisespur: return Spurart.reisespur.symbol
        case .fahrt: return Spurart.fahrt.symbol
        case .wanderung: return Spurart.wanderung.symbol
        case .fotos: return "photo"
        }
    }

    /// Der Schlüssel in `UserDefaults`.
    var schluessel: String { "fernweh.ebene." + rawValue }

    static func an(_ art: Spurart) -> Kartenebene {
        switch art {
        case .reisespur: return .reisespur
        case .fahrt: return .fahrt
        case .wanderung: return .wanderung
        }
    }
}

/// Die vier Schalter als Knopfreihe.
struct Ebenenwahl: View {
    let palette: Palette
    /// Welche Schalter stehen — auf einer Tageskarte ohne Fotos nur die
    /// Linien, die es gibt.
    var ebenen: [Kartenebene] = Kartenebene.allCases
    @ObservedObject private var farben = Kartenfarben.shared
    @AppStorage(Kartenebene.reisespur.schluessel) private var spur = true
    @AppStorage(Kartenebene.fahrt.schluessel) private var fahrt = true
    @AppStorage(Kartenebene.wanderung.schluessel) private var wanderung = true
    @AppStorage(Kartenebene.fotos.schluessel) private var fotos = true

    private func bindung(_ e: Kartenebene) -> Binding<Bool> {
        switch e {
        case .reisespur: return $spur
        case .fahrt: return $fahrt
        case .wanderung: return $wanderung
        case .fotos: return $fotos
        }
    }

    private func farbe(_ e: Kartenebene) -> Color {
        switch e {
        case .reisespur: return farben.farbe(.reisespur, palette: palette)
        case .fahrt: return farben.fahrt
        case .wanderung: return farben.wanderung
        case .fotos: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ebenen) { e in
                let an = bindung(e)
                Button { withAnimation(.snappy(duration: 0.2)) { an.wrappedValue.toggle() } } label: {
                    HStack(spacing: 5) {
                        Image(systemName: e.symbol).font(.caption2.weight(.bold))
                        Text(e.name).font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(an.wrappedValue ? Color.white : Color.secondary)
                    .background(an.wrappedValue ? AnyShapeStyle(farbe(e)) : AnyShapeStyle(.regularMaterial), in: Capsule())
                    .overlay(Capsule().stroke(farbe(e).opacity(an.wrappedValue ? 0 : 0.6), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(e.name)
                .accessibilityValue(an.wrappedValue ? "gezeigt" : "ausgeblendet")
            }
        }
    }
}
