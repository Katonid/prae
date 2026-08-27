import SwiftUI

/// Die Tabelle einer Liga mit Platz, Spielen, Toren und Punkten.
struct Tabellensicht: View {
    let liga: Liga
    @EnvironmentObject private var daten: Datenhaltung

    var body: some View {
        List {
            if let fehler = daten.ligaFehler[liga] {
                Hinweiszeile(text: fehler, ernst: true)
            }

            if let tafel = daten.tabellen[liga] {
                Section {
                    kopfzeile
                    ForEach(tafel.zeilen) { zeile in
                        Tabellenzeilensicht(zeile: zeile, liga: liga, mannschaften: tafel.zeilen.count)
                    }
                } footer: {
                    fussnote(tafel)
                }
            } else if daten.ligaLaedt.contains(liga) {
                HStack {
                    ProgressView()
                    Text("Tabelle wird geladen …")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Noch keine Tabelle geladen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .task { await daten.tabelleLaden(liga: liga) }
        .refreshable { await daten.tabelleLaden(liga: liga, erzwingen: true) }
    }

    private var kopfzeile: some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: 24, alignment: .leading)
            Text("Mannschaft")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 30)
            Text("Sp")
                .frame(width: 26, alignment: .trailing)
            Text("Diff")
                .frame(width: 34, alignment: .trailing)
            Text("Pkt")
                .frame(width: 30, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private func fussnote(_ tafel: Tabelle) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                zeichenerklaerung(Gestaltung.rasen, "Champions League")
                zeichenerklaerung(Color.orange, "Europapokal")
                zeichenerklaerung(Color(red: 0.75, green: 0.18, blue: 0.18), "Abstieg")
            }
            Text("Stand: \(tafel.spieltag). Spieltag")
        }
        .font(.caption2)
    }

    private func zeichenerklaerung(_ farbe: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(farbe)
                .frame(width: 3, height: 10)
            Text(text)
        }
    }
}

/// Eine Zeile der Tabelle.
struct Tabellenzeilensicht: View {
    let zeile: Tabellenzeile
    let liga: Liga
    let mannschaften: Int

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(randfarbe)
                    .frame(width: 3, height: 22)
                Text("\(zeile.platz)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(width: 24, alignment: .leading)

            HStack(spacing: 8) {
                Wappen(mannschaft: zeile.mannschaft, groesse: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(zeile.mannschaft.anzeige)
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if !zeile.form.isEmpty {
                        Formreihe(form: zeile.form)
                    }
                }
            }
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(zeile.spiele)")
                .frame(width: 26, alignment: .trailing)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Text(differenz)
                .frame(width: 34, alignment: .trailing)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Text("\(zeile.punkte)")
                .frame(width: 30, alignment: .trailing)
                .font(.subheadline.weight(.bold).monospacedDigit())
        }
        .padding(.vertical, 2)
    }

    private var differenz: String {
        zeile.tordifferenz > 0 ? "+\(zeile.tordifferenz)" : "\(zeile.tordifferenz)"
    }

    /// Der farbige Streifen links: Europapokal oben, Abstieg unten.
    private var randfarbe: Color {
        let unten = mannschaften - liga.abstiegsplaetze
        if zeile.platz <= liga.championsLeaguePlaetze { return Gestaltung.rasen }
        if zeile.platz <= liga.championsLeaguePlaetze + 2 { return .orange }
        if zeile.platz > unten { return Color(red: 0.75, green: 0.18, blue: 0.18) }
        return .clear
    }
}
