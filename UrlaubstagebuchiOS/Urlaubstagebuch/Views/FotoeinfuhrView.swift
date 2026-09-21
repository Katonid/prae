import PhotosUI
import SwiftUI

// Fotos aus der Mediathek holen — samt der Erklärung, warum die App nach
// der Erlaubnis fragt, und samt dem Weg, der auch ohne sie funktioniert.
//
// Der Bildschirm ist mit Absicht kein einzelner Knopf. Die Frage nach der
// Fotomediathek erscheint sonst aus dem Nichts, und wer sie verneint,
// bekommt eine App, die ohne erkennbaren Grund keine Karte zeichnet.
struct FotoeinfuhrView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    @State private var waehlerOffen = false
    @State private var laeuft = false
    @State private var stand: PHAuthorizationStatus = Reisewerk.mediathekStand

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    switch stand {
                    case .authorized, .limited:
                        Label("Die App darf die Aufnahmeorte lesen.", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                        if stand == .limited {
                            Text("Es sind nur ausgewählte Fotos freigegeben. Von allen anderen kommt kein Ort.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    case .denied, .restricted:
                        Label("Kein Zugriff auf die Fotomediathek", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text("Die Fotos lassen sich trotzdem einsetzen. Was fehlt, sind die Aufnahmeorte: iOS entfernt sie aus den Bilddaten, wenn eine App keinen Zugriff hat. Die Reisespur kannst du dann auf der Karte selbst setzen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("In den Einstellungen ändern") {
                            if let ziel = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(ziel)
                            }
                        }
                    default:
                        Text("Die App kann den Aufnahmeort eines Fotos nur lesen, wenn sie auf die Fotomediathek zugreifen darf. Der Fotowähler selbst braucht das nicht — die Orte aber schon.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Erlaubnis geben") {
                            Task { stand = await Reisewerk.mediathekFragen() }
                        }
                    }
                } header: {
                    Text("Aufnahmeorte")
                }

                Section {
                    Button {
                        waehlerOffen = true
                    } label: {
                        Label("Fotos auswählen…", systemImage: "photo.on.rectangle.angled")
                    }
                    .disabled(laeuft)
                } footer: {
                    Text("Die Fotos werden nach ihrem Aufnahmedatum auf die Tage verteilt. Fehlt das Datum, liegen sie in der Ablage, bis du sie zuordnest — verloren geht keines.")
                }

                if laeuft {
                    Section {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Fotos werden gelesen…")
                        }
                    }
                }
            }
            .navigationTitle("Fotos einlesen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
            .sheet(isPresented: $waehlerOffen) {
                Fotowahl { treffer in
                    Task { await verarbeiten(treffer) }
                }
                .ignoresSafeArea()
            }
            .onAppear { stand = Reisewerk.mediathekStand }
        }
    }

    private func verarbeiten(_ treffer: [PHPickerResult]) async {
        guard !treffer.isEmpty else { return }
        laeuft = true
        var bilder: [Rohbild] = []
        for eintrag in treffer {
            guard let daten = await ladeDaten(eintrag) else { continue }
            bilder.append(Rohbild(daten: daten, kennung: eintrag.assetIdentifier,
                                  endung: endung(eintrag)))
        }
        let bericht = await werk.fotosAufnehmen(bilder)
        laeuft = false
        werk.meldung = .init(text: bericht.text)
        schliessen()
    }

    private func endung(_ eintrag: PHPickerResult) -> String {
        let typen = eintrag.itemProvider.registeredTypeIdentifiers
        if typen.contains(UTType.heic.identifier) { return "heic" }
        if typen.contains(UTType.png.identifier) { return "png" }
        return "jpg"
    }

    // Geladen werden DATEN, nicht ein `UIImage`. Ein Bild ist schon
    // entpackt — seine Metadaten sind dabei weg, und mit ihnen Datum und
    // Ort. Genau daran scheitern die meisten Versuche, EXIF aus einem
    // Fotowähler zu bekommen.
    private func ladeDaten(_ eintrag: PHPickerResult) async -> Data? {
        let anbieter = eintrag.itemProvider
        for kennung in [UTType.image.identifier] {
            guard anbieter.hasItemConformingToTypeIdentifier(kennung) else { continue }
            let ergebnis: Data? = await withCheckedContinuation { fortsetzen in
                anbieter.loadDataRepresentation(forTypeIdentifier: kennung) { daten, _ in
                    fortsetzen.resume(returning: daten)
                }
            }
            if let ergebnis { return ergebnis }
        }
        return nil
    }
}

struct DateieinfuhrView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        Dateiwahl(typen: [.image], mehrere: true) { adressen in
            Task { await verarbeiten(adressen) }
        }
        .ignoresSafeArea()
    }

    // Aus dem Dateisystem kommt die Datei unangetastet — hier sind Datum
    // UND Ort vollständig vorhanden, ganz ohne Mediathekserlaubnis. Das ist
    // der verlässlichere der beiden Wege und deshalb kein Notbehelf.
    private func verarbeiten(_ adressen: [URL]) async {
        guard !adressen.isEmpty else {
            schliessen()
            return
        }
        var bilder: [Rohbild] = []
        for adresse in adressen {
            let offen = adresse.startAccessingSecurityScopedResource()
            defer { if offen { adresse.stopAccessingSecurityScopedResource() } }
            guard let daten = try? Data(contentsOf: adresse) else { continue }
            let endung = adresse.pathExtension.isEmpty ? "jpg" : adresse.pathExtension.lowercased()
            bilder.append(Rohbild(daten: daten, kennung: nil, endung: endung))
        }
        let bericht = await werk.fotosAufnehmen(bilder)
        werk.meldung = .init(text: bericht.text)
        schliessen()
    }
}
