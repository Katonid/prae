import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Einträge aus Day One übernehmen: Archiv wählen → nachsehen → einlesen.
///
/// Erst zeigen, dann übernehmen (dieselbe Regel wie bei jeder Einfuhr in
/// diesem Repo): Vor dem Einlesen steht da, welche Tagebücher im Archiv
/// liegen, wie viele Einträge und Fotos — und hinterher, was angekommen ist.
struct DayOneView: View {
    @Environment(\.dismiss) private var schliessen

    enum Stand {
        case waehlen
        case liest
        case bereit(DayOne.Befund)
        case laeuft(Int, Int)
        case fertig(DayOne.Bericht)
        case fehler(String)
    }

    @State private var stand: Stand = .waehlen
    @State private var auswahl: Set<String> = []
    @State private var mitFotos = true

    var body: some View {
        NavigationStack {
            Form {
                switch stand {
                case .waehlen:
                    waehlenAbschnitt(nil)
                case .liest:
                    Section { HStack { ProgressView(); Text("Archiv wird gelesen …") } }
                case .bereit(let befund):
                    bereitAbschnitte(befund)
                case .laeuft(let fertig, let gesamt):
                    Section {
                        ProgressView(value: Double(fertig), total: Double(max(gesamt, 1)))
                        Text("Eintrag \(fertig) von \(gesamt) …").font(.caption).foregroundStyle(.secondary)
                    }
                case .fertig(let bericht):
                    berichtAbschnitt(bericht)
                case .fehler(let text):
                    waehlenAbschnitt(text)
                }
            }
            .navigationTitle("Aus Day One")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(istFertig ? "Fertig" : "Abbrechen") { schliessen() }.disabled(laeuft)
                }
            }
            .interactiveDismissDisabled(laeuft)
        }
    }

    private var laeuft: Bool { if case .laeuft = stand { return true }; return false }
    private var istFertig: Bool { if case .fertig = stand { return true }; return false }

    // MARK: Abschnitte

    @ViewBuilder
    private func waehlenAbschnitt(_ fehler: String?) -> some View {
        Section {
            Text("Exportiere in Day One unter Einstellungen → Import/Export → **Day One JSON (.zip) exportieren** und sichere die Datei in „Dateien“. Nur dieser Export trägt Fotos, Ort, Wetter und die Zeitzone jedes Eintrags.")
                .font(.callout)
            Button {
                DateiWahl.zeigen { url in Task { await lesen(url) } }
            } label: {
                Label("Day-One-Export wählen (.zip)", systemImage: "doc.zipper")
                    .font(.headline)
            }
            if let fehler {
                Text(fehler).font(.caption).foregroundStyle(.red)
            }
        } footer: {
            Text("Die Einträge kommen in dein Lebenstagebuch und sind nur für dich — in eine geteilte Reise schreibt der Import nie. Fällt ein Eintrag in den Zeitraum einer Reise, steht er dort im Kapitel.")
        }
    }

    @ViewBuilder
    private func bereitAbschnitte(_ befund: DayOne.Befund) -> some View {
        Section {
            ForEach(befund.tagebuecher) { t in
                Toggle(isOn: Binding(
                    get: { auswahl.contains(t.name) },
                    set: { an in if an { auswahl.insert(t.name) } else { auswahl.remove(t.name) } })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.name).font(.headline)
                        Text(zeile(t)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Tagebücher im Archiv")
        } footer: {
            if !befund.unlesbar.isEmpty {
                Text("Nicht lesbar: \(befund.unlesbar.joined(separator: ", "))").foregroundStyle(.orange)
            }
        }

        Section {
            Toggle("Fotos übernehmen", isOn: $mitFotos)
        } footer: {
            Text("Übernommen wird eine Kopie mit höchstens 2048 Bildpunkten, wie bei Fotos aus der Mediathek. Videos, Tonaufnahmen und PDFs bleiben in Day One — sie werden gezählt, nicht übernommen.")
        }

        Section {
            Button {
                Task { await einlesen(befund) }
            } label: {
                Label("\(anzahl(befund)) Einträge übernehmen", systemImage: "square.and.arrow.down")
                    .font(.headline)
            }
            .disabled(auswahl.isEmpty)
        } footer: {
            Text("Jeder Eintrag behält den Namen seines Day-One-Tagebuchs. Schon übernommene Einträge werden erkannt und übersprungen — fehlt ihnen der Tagebuchname, wird er dabei nachgetragen.")
        }
    }

    private func berichtAbschnitt(_ b: DayOne.Bericht) -> some View {
        Section {
            LabeledContent("Neu im Tagebuch", value: "\(b.neu)")
            if b.schonDa > 0 { LabeledContent("Schon vorhanden, übersprungen", value: "\(b.schonDa)") }
            if b.nachgetragen > 0 { LabeledContent("Tagebuchname nachgetragen", value: "\(b.nachgetragen)") }
            LabeledContent("Fotos", value: "\(b.fotos)")
            if b.fotosFehlen > 0 {
                LabeledContent("Fotos ohne Datei im Archiv", value: "\(b.fotosFehlen)").foregroundStyle(.orange)
            }
            if b.anderesUebergangen > 0 {
                LabeledContent("Videos, Ton, PDFs (nicht übernommen)", value: "\(b.anderesUebergangen)")
            }
            if b.ohneDatum > 0 {
                LabeledContent("Ohne Datum, übersprungen", value: "\(b.ohneDatum)").foregroundStyle(.orange)
            }
        } header: {
            Text("Übernommen")
        } footer: {
            Text("Die Einträge stehen jetzt im Reiter „Tagebuch“, jeder mit der Uhrzeit und Zeitzone, in der er geschrieben wurde.")
        }
    }

    // MARK: Ablauf

    private func zeile(_ t: DayOne.Tagebuch) -> String {
        var s = "\(t.eintraege.count) Einträge · \(t.fotos) Fotos"
        if t.anderes > 0 { s += " · \(t.anderes) andere Medien" }
        if let z = t.zeitraum { s += " · " + Tag.zeitraum(z.0, z.1) }
        return s
    }

    private func anzahl(_ befund: DayOne.Befund) -> Int {
        befund.tagebuecher.filter { auswahl.contains($0.name) }.reduce(0) { $0 + $1.eintraege.count }
    }

    private func lesen(_ url: URL) async {
        stand = .liest
        do {
            let befund = try await Task.detached(priority: .userInitiated) { try DayOne.pruefen(url) }.value
            auswahl = Set(befund.tagebuecher.map(\.name))
            stand = .bereit(befund)
        } catch {
            stand = .fehler(error.localizedDescription)
        }
    }

    private func einlesen(_ befund: DayOne.Befund) async {
        stand = .laeuft(0, anzahl(befund))
        UIApplication.shared.isIdleTimerDisabled = true
        let bericht = await DayOne.einlesen(befund, tagebuecher: auswahl, mitFotos: mitFotos) { f, g in
            stand = .laeuft(f, g)
        }
        UIApplication.shared.isIdleTimerDisabled = false
        stand = .fertig(bericht)
    }
}

/// Der Dateiwähler über UIKit, an SwiftUI vorbei (Lehre aus Tafelbild: an
/// einem Blatt hängend flackert `.fileImporter`). `asCopy: true` — die Datei
/// liegt danach im eigenen Behälter, ohne Zugriffsrechte auf fremde Ordner.
@MainActor
enum DateiWahl {
    private static var delegat: Delegat?

    static func zeigen(_ fertig: @escaping (URL) -> Void) {
        guard let oben = Teilen.obersterController() else { return }
        let wahl = UIDocumentPickerViewController(forOpeningContentTypes: [.zip], asCopy: true)
        let d = Delegat(fertig: fertig)
        delegat = d
        wahl.delegate = d
        oben.present(wahl, animated: true)
    }

    private final class Delegat: NSObject, UIDocumentPickerDelegate {
        let fertig: (URL) -> Void
        init(fertig: @escaping (URL) -> Void) { self.fertig = fertig }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { fertig(url) }
        }
    }
}
