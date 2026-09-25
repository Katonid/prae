import SwiftUI
import UIKit

/// „Fürs Fotobuch übergeben“ — baut die Übergabedatei und reicht sie weiter.
///
/// Die Fotos sind ein SCHALTER (Ansage des Nutzers: „wäre es gut, wenn diese
/// Funktion zur Verfügung stünde, ich sie aber aktivieren oder deaktivieren
/// kann“). Vorgabe ist AUS: Texte und Wetter sind in Sekunden übergeben,
/// Originalfotos können ein halbes Gigabyte wiegen.
struct UebergabeView: View {
    @ObservedObject var reise: Reise
    @Environment(\.dismiss) private var schliessen

    // In einer View liegt `@AppStorage` richtig (die Regel dieses Repos).
    @AppStorage("fernweh.uebergabe.fotos") private var fotoWahl = Uebergabewunsch.Fotos.keine.rawValue
    @AppStorage("fernweh.uebergabe.spur") private var spur = true

    @State private var laeuft = false
    @State private var fertig = 0
    @State private var gesamt = 0
    @State private var ergebnis: Uebergabebau.Ergebnis?
    @State private var fehler: String?

    private var fotos: Uebergabewunsch.Fotos { Uebergabewunsch.Fotos(rawValue: fotoWahl) ?? .keine }
    private var fotoAnzahl: Int { reise.fotoAnzahl }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Fernweh schreibt eine Datei mit den Texten, Orten und dem Wetter jedes Tages. Das Reisebuch liest sie ein und legt daraus die Tage des Fotobuchs an.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    LabeledContent("Tage mit Einträgen", value: "\(Set(reise.eintragListe.compactMap { $0.datum.map(Tag.schluessel) }).count)")
                    LabeledContent("Einträge", value: "\(reise.eintragListe.count)")
                    LabeledContent("Fotos in den Einträgen", value: "\(fotoAnzahl)")
                }

                Section {
                    Picker("Fotos", selection: $fotoWahl) {
                        ForEach(Uebergabewunsch.Fotos.allCases) { Text($0.name).tag($0.rawValue) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Fotos")
                } footer: {
                    Text(fotoHinweis)
                }

                Section {
                    Toggle("Reisespur mitgeben", isOn: $spur)
                } footer: {
                    Text("Die aufgezeichneten Wege jedes Tages, von allen Geräten der Reise. Daraus zeichnet das Reisebuch die Karte des Tages; ohne sie verbindet es nur die Orte der Einträge.")
                }

                Section {
                    if laeuft {
                        VStack(alignment: .leading, spacing: 8) {
                            ProgressView(value: gesamt == 0 ? 0.5 : Double(fertig), total: Double(max(gesamt, 1)))
                            Text(gesamt == 0 ? "Datei wird geschrieben …" : "Foto \(fertig) von \(gesamt) …")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            Task { await erstellen() }
                        } label: {
                            Label("Übergabedatei erstellen", systemImage: "square.and.arrow.up")
                                .font(.headline)
                        }
                    }
                    if let ergebnis {
                        Text(bericht(ergebnis))
                            .font(.caption)
                            .foregroundStyle(ergebnis.fehlend > 0 ? .orange : .secondary)
                        Button("Noch einmal weitergeben") { weitergeben(ergebnis.datei) }
                    }
                    if let fehler {
                        Text(fehler).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Fürs Fotobuch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { schliessen() }.disabled(laeuft)
                }
            }
            .interactiveDismissDisabled(laeuft)
        }
    }

    private var fotoHinweis: String {
        switch fotos {
        case .keine:
            return "Nur Texte, Orte und Wetter — in Sekunden fertig. Die Datei nennt je Foto trotzdem Aufnahmezeit, Ort und seine Kennung in der Mediathek."
        case .kopie:
            return "Die Fassung, mit der Fernweh selbst arbeitet: höchstens 2048 Bildpunkte an der langen Kante. Klein und schnell — für ein gedrucktes Buch meist zu grob."
        case .original:
            return "Die Aufnahme aus der Mediathek dieses Geräts, mit Datum und Ort in der Datei. Für den Druck die richtige Wahl — und bei vielen Fotos eine große Datei. Liegt ein Foto nur bei einem Miturlauber, geht die verkleinerte Kopie mit, und das steht in der Datei dabei."
        }
    }

    private func bericht(_ e: Uebergabebau.Ergebnis) -> String {
        let groesse = (try? e.datei.resourceValues(forKeys: [.fileSizeKey]).fileSize).map {
            ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file)
        } ?? "?"
        var satz = "\(e.eintraege) Einträge"
        if fotos != .keine { satz += ", \(e.fotos) Fotos" }
        satz += " · \(groesse)"
        if e.fehlend > 0 { satz += "\n\(e.fehlend) Fotos ließen sich auf diesem Gerät nicht holen und fehlen in der Datei." }
        return satz
    }

    private func erstellen() async {
        laeuft = true
        fehler = nil
        ergebnis = nil
        fertig = 0
        gesamt = fotos == .keine ? 0 : fotoAnzahl
        UIApplication.shared.isIdleTimerDisabled = true
        defer {
            laeuft = false
            UIApplication.shared.isIdleTimerDisabled = false
        }
        do {
            let e = try await Uebergabebau.bauen(reise, wunsch: Uebergabewunsch(fotos: fotos, spur: spur)) { f, g in
                fertig = f
                gesamt = g
            }
            ergebnis = e
            weitergeben(e.datei)
        } catch {
            fehler = "Die Datei ließ sich nicht schreiben: \(error.localizedDescription)"
        }
    }

    /// Teilen-Blatt über UIKit, an SwiftUI vorbei (Lehre aus Tafelbild:
    /// eingebettet flackert oder bleibt schwarz). Von dort: „In Dateien
    /// sichern“, AirDrop an den Mac, oder direkt ins Reisebuch.
    private func weitergeben(_ datei: URL) {
        guard let oben = Teilen.obersterController() else { return }
        let blatt = UIActivityViewController(activityItems: [datei], applicationActivities: nil)
        if let pop = blatt.popoverPresentationController {
            pop.sourceView = oben.view
            pop.sourceRect = CGRect(x: oben.view.bounds.midX, y: oben.view.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        oben.present(blatt, animated: true)
    }
}
