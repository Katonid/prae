import SwiftUI

/// Kleine, oft gebrauchte Bausteine der Oberflaeche.
enum Gestaltung {
    static let rasen = Color(red: 0.06, green: 0.42, blue: 0.27)
    static let ecke: CGFloat = 14
}

/// Wappen einer Mannschaft. Der Dienst liefert manche Wappen als SVG —
/// die kann iOS nicht zeichnen, dafuer gibt es das Buchstabenzeichen.
struct Wappen: View {
    let mannschaft: Mannschaft
    var groesse: CGFloat = 26

    var body: some View {
        Group {
            if let adresse = mannschaft.ladbaresWappen {
                AsyncImage(url: adresse) { stufe in
                    switch stufe {
                    case .success(let bild):
                        bild.resizable().scaledToFit()
                    default:
                        ersatz
                    }
                }
            } else {
                ersatz
            }
        }
        .frame(width: groesse, height: groesse)
    }

    private var ersatz: some View {
        ZStack {
            Circle().fill(Color.secondary.opacity(0.16))
            Text(mannschaft.zeichen)
                .font(.system(size: groesse * 0.36, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(2)
        }
    }
}

/// Farbiges Ligakennzeichen mit Flagge.
struct LigaZeichen: View {
    let liga: Liga
    var mitNamen = true

    var body: some View {
        HStack(spacing: 6) {
            Text(liga.flagge)
            if mitNamen {
                Text(liga.name)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(liga.farbe.opacity(0.15), in: Capsule())
        .foregroundStyle(liga.farbe)
    }
}

/// Ein Punkt, der zeigt, dass gerade gespielt wird.
struct Livepunkt: View {
    @State private var gross = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .scaleEffect(gross ? 1.35 : 0.9)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: gross)
            .onAppear { gross = true }
    }
}

/// Formzeichen der letzten Spiele in der Tabelle.
struct Formreihe: View {
    let form: [String]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(form.indices, id: \.self) { platz in
                Text(form[platz])
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 14, height: 14)
                    .background(farbe(form[platz]), in: RoundedRectangle(cornerRadius: 3))
            }
        }
    }

    private func farbe(_ zeichen: String) -> Color {
        switch zeichen {
        case "S": return Gestaltung.rasen
        case "U": return .gray
        case "N": return Color(red: 0.75, green: 0.18, blue: 0.18)
        default: return .secondary
        }
    }
}
