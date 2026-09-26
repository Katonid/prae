import SwiftUI
import UniformTypeIdentifiers

/// Die Texte einer Reise zum Überarbeiten hinaus und wieder herein (ab
/// 1.0.27). Die Regeln stehen in `Textglaettung.swift`.
struct TexteView: View {
    @ObservedObject var reise: Reise
    @Environment(\.dismiss) private var schliessen

    @State private var dateiWahl = false
    @State private var zuordnung: Textglaettung.Zuordnung?
    @State private var abgewaehlt: Set<String> = []
    @State private var fehler: String?
    @State private var meldung: String?
    @State private var letzte: Date?
    @State private var zuruecknehmenFragen = false

    private var gewaehlt: [Textglaettung.Aenderung] {
        (zuordnung?.aenderungen ?? []).filter { !abgewaehlt.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let zuordnung {
                    vorschau(zuordnung)
                } else {
                    hinaus
                    herein
                    if let letzte {
                        Section {
                            Button(role: .destructive) { zuruecknehmenFragen = true } label: {
                                Label("Letzte Übernahme zurücknehmen", systemImage: "arrow.uturn.backward")
                            }
                        } footer: {
                            Text("Stellt die Texte wieder her, wie sie vor dem Einlesen am \(Tag.text(letzte, "d. MMMM 'um' HH:mm", zone: .current)) waren.")
                        }
                    }
                }
                if let meldung {
                    Section { Label(meldung, systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                }
                if let fehler {
                    Section { Label(fehler, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                }
            }
            .navigationTitle("Texte überarbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(zuordnung == nil ? "Fertig" : "Abbrechen") {
                        if zuordnung == nil { schliessen() } else { withAnimation { zuordnung = nil } }
                    }
                }
                if zuordnung != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Ersetzen") {
                            let n = gewaehlt.count
                            Textglaettung.uebernehmen(gewaehlt, in: reise)
                            withAnimation {
                                zuordnung = nil
                                meldung = n == 1 ? "1 Eintrag ersetzt." : "\(n) Einträge ersetzt."
                                letzte = Textglaettung.letzteUebernahme(reise)
                            }
                        }
                        .fontWeight(.semibold)
                        .disabled(gewaehlt.isEmpty)
                    }
                }
            }
            .fileImporter(isPresented: $dateiWahl, allowedContentTypes: [.plainText, .text, .utf8PlainText, .data],
                          allowsMultipleSelection: false) { ergebnis in
                guard case .success(let urls) = ergebnis, let url = urls.first else { return }
                let zugriff = url.startAccessingSecurityScopedResource()
                defer { if zugriff { url.stopAccessingSecurityScopedResource() } }
                if let daten = try? Data(contentsOf: url), let text = String(data: daten, encoding: .utf8)
                    ?? String(data: daten, encoding: .isoLatin1) {
                    einlesen(text)
                } else {
                    fehler = "Die Datei ließ sich nicht als Text lesen."
                }
            }
            .confirmationDialog("Letzte Übernahme zurücknehmen?", isPresented: $zuruecknehmenFragen, titleVisibility: .visible) {
                Button("Zurücknehmen", role: .destructive) {
                    let n = Textglaettung.zuruecknehmen(reise)
                    meldung = n == 1 ? "1 Eintrag zurückgesetzt." : "\(n) Einträge zurückgesetzt."
                    letzte = nil
                }
            } message: {
                Text("Die Einträge bekommen ihre Texte von vor dem Einlesen zurück. Was du seither in diesen Einträgen geändert hast, geht dabei verloren.")
            }
            .onAppear { letzte = Textglaettung.letzteUebernahme(reise) }
        }
    }

    // MARK: - Hinaus

    private var hinaus: some View {
        Section {
            Button { teilen() } label: {
                Label("Als Textdatei teilen …", systemImage: "square.and.arrow.up")
            }
            Button {
                UIPasteboard.general.string = Textglaettung.text(reise)
                meldung = "Alle Texte kopiert — in den KI-Chat einfügen."
            } label: {
                Label("Alle Texte kopieren", systemImage: "doc.on.doc")
            }
        } header: {
            Text("1. Hinausgeben")
        } footer: {
            let n = Textglaettung.eintraege(reise).count
            Text("\(n) Einträge dieser Reise, nach Tagen geordnet, mit Titel und Text. Oben steht ein Hinweis für die KI, die Kennzeilen („=== Eintrag …“) stehen zu lassen — an ihnen erkennt Fernweh beim Einlesen jeden Eintrag wieder. Einträge aus gesperrten Tagebüchern gehen nicht mit.")
        }
    }

    private var herein: some View {
        Section {
            Button { dateiWahl = true } label: {
                Label("Überarbeitete Datei wählen …", systemImage: "doc.badge.arrow.up")
            }
            PasteButton(payloadType: String.self) { texte in
                if let t = texte.first { einlesen(t) }
            }
        } header: {
            Text("2. Überarbeitete Fassung einlesen")
        } footer: {
            Text("Aus einer Datei oder aus der Zwischenablage (die Antwort der KI kopieren). Du siehst vorher jeden geänderten Eintrag und kannst einzelne abwählen. Der alte Stand wird gemerkt und lässt sich zurückholen.")
        }
    }

    private func einlesen(_ text: String) {
        fehler = nil
        meldung = nil
        let z = Textglaettung.zuordnen(text, reise: reise)
        guard z.bloecke > 0 else {
            fehler = "Im Text steht keine Kennzeile „=== Eintrag …“. Hat die KI sie entfernt? Dann bitte noch einmal mit dem Hinweis, diese Zeilen stehen zu lassen."
            return
        }
        abgewaehlt = []
        withAnimation { zuordnung = z }
    }

    private func teilen() {
        do {
            let datei = try Textglaettung.datei(reise)
            guard let oben = Teilen.obersterController() else { return }
            let blatt = UIActivityViewController(activityItems: [datei], applicationActivities: nil)
            if let pop = blatt.popoverPresentationController {
                pop.sourceView = oben.view
                pop.sourceRect = CGRect(x: oben.view.bounds.midX, y: oben.view.bounds.midY, width: 1, height: 1)
                pop.permittedArrowDirections = []
            }
            oben.present(blatt, animated: true)
        } catch {
            fehler = "Die Datei ließ sich nicht schreiben: \(error.localizedDescription)"
        }
    }

    // MARK: - Vorschau

    @ViewBuilder
    private func vorschau(_ z: Textglaettung.Zuordnung) -> some View {
        Section {
            Text(z.aenderungen.count == 1 ? "1 Eintrag ist geändert." : "\(z.aenderungen.count) Einträge sind geändert.")
                .font(.headline)
            if z.unveraendert > 0 { Text("\(z.unveraendert) unverändert.").foregroundStyle(.secondary) }
            if z.fehlend > 0 {
                Text("\(z.fehlend) Einträge der Reise stehen nicht im Text — sie bleiben, wie sie sind.")
                    .foregroundStyle(.secondary)
            }
            if z.leer > 0 {
                Label("\(z.leer) Einträge kamen leer zurück und bleiben unverändert.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            if !z.unbekannt.isEmpty {
                Label("\(z.unbekannt.count) Kennzeilen passen zu keinem Eintrag dieser Reise (\(z.unbekannt.prefix(3).joined(separator: ", "))) — übersprungen.",
                      systemImage: "questionmark.circle")
                    .foregroundStyle(.orange)
            }
            if z.gesperrt > 0 {
                Text("\(z.gesperrt) Einträge darfst du nicht bearbeiten — übersprungen.").foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        ForEach(z.aenderungen) { a in
            Section {
                Toggle(isOn: Binding(
                    get: { !abgewaehlt.contains(a.id) },
                    set: { an in if an { abgewaehlt.remove(a.id) } else { abgewaehlt.insert(a.id) } }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.neuerTitel.isEmpty ? a.eintrag.anzeigeTitel : a.neuerTitel).font(.headline)
                        if let d = a.eintrag.tagDatum {
                            Text(Tag.wochentagLang.string(from: d)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if a.titelGeaendert {
                    Text("Titel vorher: \((a.eintrag.titel ?? "").isEmpty ? "—" : a.eintrag.titel ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if a.textGeaendert {
                    DisclosureGroup("Vorher / Nachher") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Vorher").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                            Text(a.eintrag.text ?? "").font(.callout).foregroundStyle(.secondary)
                            Text("Nachher").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                            Text(a.neuerText).font(.callout)
                        }
                        .textSelection(.enabled)
                    }
                    Text(a.neuerText).font(.callout).lineLimit(3)
                }
            }
        }
    }
}
