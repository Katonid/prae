import SwiftUI

/// Ein einzelnes Spiel: Anzeigetafel, Torfolge und Eckdaten.
struct Spielsicht: View {
    let spiel: Spiel
    @EnvironmentObject private var daten: Datenhaltung
    @State private var geladen: Spiel?

    private var gezeigt: Spiel { geladen ?? spiel }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                anzeigetafel
                if !gezeigt.tore.isEmpty {
                    torfolge
                }
                eckdaten
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("\(spiel.heim.zeichen) – \(spiel.gast.zeichen)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let frisch = await daten.spielNachladen(spiel) {
                geladen = frisch
            }
        }
    }

    // MARK: Tafel

    private var anzeigetafel: some View {
        VStack(spacing: 12) {
            HStack {
                LigaZeichen(liga: gezeigt.liga)
                Spacer()
                if gezeigt.spieltag > 0 {
                    Text("\(gezeigt.spieltag). Spieltag")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .center, spacing: 8) {
                seite(gezeigt.heim)
                VStack(spacing: 4) {
                    Text(gezeigt.standtext)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    zustandszeile
                }
                .frame(minWidth: 110)
                seite(gezeigt.gast)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Gestaltung.ecke))
    }

    private func seite(_ elf: Mannschaft) -> some View {
        VStack(spacing: 8) {
            Wappen(mannschaft: elf, groesse: 48)
            Text(elf.anzeige)
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var zustandszeile: some View {
        HStack(spacing: 5) {
            if gezeigt.status.laeuftGerade {
                Livepunkt()
            }
            Text(zustandstext)
                .font(.caption.weight(.semibold))
                .foregroundStyle(gezeigt.status.laeuftGerade ? Color.red : .secondary)
        }
    }

    private var zustandstext: String {
        switch gezeigt.status {
        case .geplant:
            return "Anstoss \(Zeitformate.uhrzeit.string(from: gezeigt.anstoss)) Uhr"
        case .laeuft:
            return gezeigt.minute.map { "\($0). Minute" } ?? "laeuft"
        case .pause:
            return "Halbzeit"
        case .beendet:
            return "Endstand"
        case .verschoben:
            return "verlegt"
        case .abgesagt:
            return "abgesagt"
        }
    }

    // MARK: Tore

    private var torfolge: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tore")
                .font(.headline)
            ForEach(gezeigt.tore) { tor in
                HStack(spacing: 10) {
                    Text(tor.minutentext)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: tor.fuerHeim ? .leading : .trailing)
                    Image(systemName: "soccerball")
                        .foregroundStyle(Gestaltung.rasen)
                    Text(tor.schuetze)
                        .font(.subheadline)
                    Spacer(minLength: 4)
                    if let heim = tor.standHeim, let gast = tor.standGast {
                        Text("\(heim):\(gast)")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Gestaltung.ecke))
    }

    // MARK: Eckdaten

    private var eckdaten: some View {
        VStack(spacing: 0) {
            zeile("Anstoss", Zeitformate.wochentagDatum.string(from: gezeigt.anstoss)
                  + ", " + Zeitformate.uhrzeit.string(from: gezeigt.anstoss) + " Uhr")
            if let halbzeit = gezeigt.halbzeittext {
                Divider()
                zeile("Halbzeit", halbzeit)
            }
            Divider()
            zeile("Wettbewerb", gezeigt.liga.name)
            Divider()
            zeile("Zustand", gezeigt.status.beschriftung)
        }
        .padding(.horizontal)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Gestaltung.ecke))
    }

    private func zeile(_ titel: String, _ wert: String) -> some View {
        HStack {
            Text(titel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(wert)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }
}
