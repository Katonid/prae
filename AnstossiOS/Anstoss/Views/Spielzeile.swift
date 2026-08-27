import SwiftUI

/// Eine Begegnung als Zeile: links die Zeit, rechts beide Mannschaften
/// untereinander mit ihren Toren.
struct Spielzeile: View {
    let spiel: Spiel
    var ligaZeigen = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            zeitspalte
            VStack(alignment: .leading, spacing: 5) {
                if ligaZeigen {
                    LigaZeichen(liga: spiel.liga)
                }
                mannschaftszeile(spiel.heim, tore: spiel.toreHeim, fuehrt: fuehrtHeim)
                mannschaftszeile(spiel.gast, tore: spiel.toreGast, fuehrt: fuehrtGast)
            }
        }
        .padding(.vertical, 4)
    }

    private var fuehrtHeim: Bool {
        guard let h = spiel.toreHeim, let g = spiel.toreGast else { return false }
        return h > g
    }

    private var fuehrtGast: Bool {
        guard let h = spiel.toreHeim, let g = spiel.toreGast else { return false }
        return g > h
    }

    private var zeitspalte: some View {
        VStack(spacing: 4) {
            if spiel.status.laeuftGerade {
                Livepunkt()
            }
            Text(spiel.zeittext)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(spiel.status.laeuftGerade ? Color.red : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if !spiel.istHeute, spiel.status == .geplant {
                Text(Zeitformate.kurzdatum.string(from: spiel.anstoss))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 48)
    }

    private func mannschaftszeile(_ elf: Mannschaft, tore: Int?, fuehrt: Bool) -> some View {
        HStack(spacing: 8) {
            Wappen(mannschaft: elf, groesse: 22)
            Text(elf.anzeige)
                .font(.subheadline.weight(fuehrt ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 6)
            Text(tore.map(String.init) ?? "–")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(tore == nil ? .secondary : .primary)
        }
    }
}
