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
    @State private var ziel: Fotoziel = .ablage
    @State private var von = Date()
    @State private var bis = Date()
    @State private var gefunden: Int?

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
                    Text("Im Fotowähler lassen sich beliebig viele Fotos antippen. Einen Knopf \u{201E}alle auswählen\u{201C} hat er nicht — der Wähler gehört iOS und läuft in einem eigenen Programm, damit er ohne Zugriff auf die Mediathek arbeiten kann. Wer alles auf einmal will, nimmt den Zeitraum darunter.")
                }

                // Der eigentliche Weg zu „alle auf einmal": nicht nach
                // Bildern fragen, sondern nach einem Zeitraum. Eine Reise
                // IST ein Zeitraum — und die Mediathek gibt ihn her,
                // sobald die Erlaubnis da ist, die diese App ohnehin für
                // die Aufnahmeorte braucht.
                Section {
                    if stand == .authorized || stand == .limited {
                        DatePicker("Von", selection: $von, displayedComponents: .date)
                        DatePicker("Bis", selection: $bis, displayedComponents: .date)
                        HStack {
                            Text("Gefunden")
                            Spacer()
                            Text(gefunden.map { "\($0) Fotos" } ?? "…")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Button {
                            Task { await zeitraumHolen() }
                        } label: {
                            Label("Alle Fotos dieses Zeitraums einlesen",
                                  systemImage: "square.stack.3d.down.right")
                        }
                        .disabled(laeuft || (gefunden ?? 0) == 0)
                    } else {
                        Text("Dafür braucht die App Zugriff auf die Fotomediathek — ohne ihn kann sie nicht nachsehen, was in einem Zeitraum liegt.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Alle Fotos eines Zeitraums")
                } footer: {
                    if stand == .limited {
                        Text("Es sind nur ausgewählte Fotos freigegeben — in diesem Zeitraum findet die App deshalb nur diese.")
                    } else {
                        Text("Gezählt wird nach dem Aufnahmezeitpunkt, den die Mediathek führt. Fotos, die in iCloud liegen, werden beim Einlesen geladen; das kann dauern.")
                    }
                }

                Section {
                    Picker("Fotos ohne Datum", selection: $ziel) {
                        Text("In die Ablage").tag(Fotoziel.ablage)
                        ForEach(werk.reise.tage) { tag in
                            Text("Zu \(tag.datum.mittel)").tag(Fotoziel.tag(tag.id))
                        }
                    }
                } footer: {
                    Text("Die Fotos werden nach ihrem Aufnahmedatum auf die Tage verteilt, und ein Tag, den es noch nicht gibt, entsteht dabei von selbst. Steht kein Datum im Foto, sieht die App in der Mediathek und im Dateinamen nach. Bleibt auch dann keines übrig, trägt das Foto keine Auskunft darüber, wann es aufgenommen wurde — wohin es dann kommt, ist eine Entscheidung und keine Messung. Deshalb steht sie hier.")
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
            .onAppear {
                stand = Reisewerk.mediathekStand
                vorbelegen()
            }
            .onChange(of: von) { _, _ in zaehlen() }
            .onChange(of: bis) { _, _ in zaehlen() }
        }
    }

    // Auch dieser Weg holt Foto für Foto (ab 1.0.30). Bis dahin sammelte er
    // erst alle Rohbilder in einer Liste und reichte sie dann weiter — das
    // war tragbar, solange man Fotos einzeln antippt, und ist es nicht
    // mehr, seit der Wunsch ausdrücklich „alle“ lautet: Fünfhundert
    // ausgewählte Bilder wären ein Gigabyte im Arbeitsspeicher, bevor das
    // erste auf der Platte liegt.
    private func verarbeiten(_ treffer: [PHPickerResult]) async {
        guard !treffer.isEmpty else { return }
        laeuft = true
        let bericht = await werk.fotosAufnehmen(anzahl: treffer.count, ohneDatum: ziel) { stelle in
            let eintrag = treffer[stelle]
            guard let daten = await ladeDaten(eintrag) else { return nil }
            return Rohbild(daten: daten, kennung: eintrag.assetIdentifier,
                           endung: endung(eintrag),
                           name: eintrag.itemProvider.suggestedName)
        }
        laeuft = false
        werk.meldung = .init(text: bericht.text)
        schliessen()
    }

    // Vorbelegt wird der Zeitraum der Reise, wenn es schon Tage gibt —
    // das ist die Frage, die jemand in diesem Augenblick stellt. Ist das
    // Buch noch leer, sind es die letzten vier Wochen; eine leere Liste
    // sähe aus wie eine kaputte Abfrage.
    private func vorbelegen() {
        if let erster = werk.reise.tage.first?.datum,
           let letzter = werk.reise.tage.last?.datum
        {
            von = erster.mittag
            bis = letzter.mittag
        } else {
            bis = Date()
            von = Calendar(identifier: .gregorian)
                .date(byAdding: .day, value: -28, to: bis) ?? bis
        }
        if let erster = werk.reise.tage.first { ziel = .tag(erster.id) }
        zaehlen()
    }

    private func zaehlen() {
        guard stand == .authorized || stand == .limited else {
            gefunden = 0
            return
        }
        let a = Tagesdatum(min(von, bis))
        let b = Tagesdatum(max(von, bis))
        gefunden = Zeitraumeinfuhr.zaehle(von: a, bis: b)
    }

    // Der Zeitraum-Import holt Foto für Foto. Tausend Rohbilder auf
    // einmal wären mehrere Gigabyte — deshalb reicht die Ansicht dem Werk
    // keine Liste, sondern einen Weg, das nächste zu holen.
    private func zeitraumHolen() async {
        let a = Tagesdatum(min(von, bis))
        let b = Tagesdatum(max(von, bis))
        guard let treffer = Zeitraumeinfuhr.treffer(von: a, bis: b), treffer.count > 0 else {
            werk.meldung = .init(text: "In diesem Zeitraum liegt kein Foto.")
            return
        }
        laeuft = true
        let bericht = await werk.fotosAufnehmen(anzahl: treffer.count, ohneDatum: ziel) { stelle in
            await Zeitraumeinfuhr.rohbild(treffer.object(at: stelle))
        }
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

    // Dieser Weg hat keinen eigenen Bildschirm — er ist der Dateiwähler und
    // sonst nichts. Für Fotos ohne Datum gilt deshalb dieselbe Vorgabe wie
    // beim Foto-Import: der erste Reisetag, und die Ablage nur, solange es
    // gar keinen Tag gibt. Der Bericht sagt hinterher, wo sie gelandet
    // sind; wer sie woanders haben will, nimmt sie dort wieder heraus.
    private var ziel: Fotoziel {
        werk.reise.tage.first.map { Fotoziel.tag($0.id) } ?? .ablage
    }

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
            bilder.append(Rohbild(daten: daten, kennung: nil, endung: endung,
                                  name: adresse.lastPathComponent))
        }
        let bericht = await werk.fotosAufnehmen(bilder, ohneDatum: ziel)
        werk.meldung = .init(text: bericht.text)
        schliessen()
    }
}
