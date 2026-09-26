import Photos
import SwiftUI
import UniformTypeIdentifiers

// Die Übergabedatei aus Fernweh einlesen (ab 1.0.106).
//
// Dieselbe Bauweise wie bei Tagesspur und Textimport: Erst steht da, was in
// der Datei steht, Tag für Tag — DANN wird übernommen. Ein Einlesen, das
// gleich losschreibt, nimmt dem Nutzer die einzige Stelle, an der er den
// Fehler noch sieht.
struct FernwehimportView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    @State private var waehler = false
    @State private var daten: Data?
    @State private var dateiname = ""
    @State private var befund: Fernweheinfuhr.Befund?
    @State private var fehler: String?
    @State private var gewaehlt: Set<String> = []
    @State private var zone: TimeZone = .current
    @State private var sucht = false
    @State private var liest = false
    @State private var arbeit: String?

    @State private var ersetzen = false
    @State private var autorenNennen = false
    @State private var wetter = true
    @State private var titel = false
    @State private var ausMediathek = true
    @State private var orte: Reisewerk.Ortswahl = .fernweh

    var body: some View {
        NavigationStack {
            Form {
                if let arbeit {
                    Section {
                        HStack(spacing: 9) {
                            ProgressView()
                            Text(arbeit)
                        }
                    } footer: {
                        Text("Bitte die App so lange geöffnet lassen. Mit Originalen werden "
                             + "leicht einige hundert Megabyte bewegt.")
                    }
                } else if befund == nil {
                    einstieg
                } else {
                    vorschau
                }
            }
            .navigationTitle("Aus Fernweh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                        .disabled(arbeit != nil)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") { uebernehmen() }
                        .disabled(gewaehlt.isEmpty || arbeit != nil)
                }
            }
            .interactiveDismissDisabled(arbeit != nil)
            .fullScreenCover(isPresented: $waehler) {
                Dateiwahl(typen: typen) { urls in
                    waehler = false
                    if let erste = urls.first { einlesen(erste) }
                }
                .ignoresSafeArea()
            }
        }
    }

    private var typen: [UTType] {
        var liste: [UTType] = []
        if let eigen = UTType(filenameExtension: Fernweheinfuhr.endung) { liste.append(eigen) }
        liste.append(.zip)
        // Über Umwege geteilt, kommt die Datei gern ohne ihre Endung an.
        // Was sie ist, entscheidet ohnehin der Inhalt.
        liste.append(.data)
        return liste
    }

    // MARK: - Einstieg

    @ViewBuilder
    private var einstieg: some View {
        Section {
            Button {
                waehler = true
            } label: {
                Label("Übergabedatei wählen", systemImage: "folder")
            }
            .disabled(liest)
            if liest {
                HStack(spacing: 9) {
                    ProgressView()
                    Text("Wird gelesen\u{2026}").foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("In Fernweh: Reise \u{2192} \u{201E}\u{2026}\u{201C} \u{2192} \u{201E}Fürs Fotobuch "
                 + "übergeben\u{201C}. Die Datei endet auf .fernweh und trägt Texte, Orte, "
                 + "Wetter, die Reisespur und \u{2014} wenn du es dort so wählst \u{2014} die Fotos.")
        }

        if let fehler {
            Section {
                Label(fehler, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }

        Section("Was dabei passiert") {
            Text("Mehrere Einträge eines Tages werden aneinandergehängt. Der Titel des "
                 + "ersten wird die Überschrift des Tages, sein Ort die zweite Überschrift.")
                .font(.footnote)
            Text("Fotos, die schon im Buch stehen, kommen nicht doppelt. Orte und Spur "
                 + "aus einem früheren Einlesen werden ersetzt \u{2014} zweimal dieselbe "
                 + "Datei ergibt nicht die doppelte Spur. Ob die Orte aus Fernweh kommen "
                 + "oder die App sie aus den Fotos bildet, wählst du nach dem Öffnen.")
                .font(.footnote)
        }
    }

    // MARK: - Vorschau

    @ViewBuilder
    private var vorschau: some View {
        if let befund {
            Section {
                if !befund.titel.isEmpty { LabeledContent("Reise", value: befund.titel) }
                LabeledContent("Tage", value: "\(befund.tage.count)")
                LabeledContent("Einträge", value: "\(befund.eintraege)")
                LabeledContent("Fotos", value: fotozeile(befund))
                LabeledContent("Orte", value: "\(befund.orte) benannt, \(befund.spurpunkte) Spurpunkte")
                if !befund.app.isEmpty { LabeledContent("Aus", value: befund.app) }
            } header: {
                Text(dateiname)
            } footer: {
                Text(auskunft(befund))
            }

            Section {
                Toggle("Vorhandenen Text ersetzen", isOn: $ersetzen)
                Toggle("Wetter unter den Text schreiben", isOn: $wetter)
                Toggle("Namen der Schreibenden nennen", isOn: $autorenNennen)
                if !befund.titel.isEmpty {
                    Toggle("Titel übernehmen: \u{201E}\(befund.titel)\u{201C}", isOn: $titel)
                }
                if befund.fotos > befund.fotosMitDatei {
                    Toggle("Fehlende Bilder aus der Mediathek holen", isOn: $ausMediathek)
                }
            } header: {
                Text("Übernehmen")
            } footer: {
                Text(schaltersatz(befund))
            }

            Section {
                Picker("Orte und Spur", selection: $orte) {
                    Text("Aus Fernweh übernehmen").tag(Reisewerk.Ortswahl.fernweh)
                    Text("Aus den Fotos bilden").tag(Reisewerk.Ortswahl.fotos)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Orte")
            } footer: {
                Text(ortesatz(befund))
            }

            Section {
                if sucht {
                    HStack(spacing: 9) {
                        ProgressView()
                        Text("Zeitzonen werden nachgeschlagen\u{2026}")
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Nachgeschlagen",
                               value: "\(befund.tage.filter(\.zoneNachgeschlagen).count) von \(befund.tage.count) Tagen")
                Picker("Sonst gilt", selection: $zone) {
                    ForEach(zonen, id: \.identifier) { eine in
                        Text(eine.identifier).tag(eine)
                    }
                }
                .onChange(of: zone) { _, _ in nochEinmalLesen() }
            } header: {
                Text("Uhrzeiten")
            } footer: {
                Text("Im Buch steht die Uhrzeit AM ORT. Welche Zone gilt, wird je Tag am "
                     + "ersten Ort nachgeschlagen; das braucht Netz. Der Tag selbst steht in "
                     + "der Datei und wird nicht umgerechnet.")
            }

            Section {
                ForEach(befund.tage) { tag in
                    zeile(tag)
                }
            } header: {
                HStack {
                    Text("\(gewaehlt.count) von \(befund.tage.count) gewählt")
                    Spacer()
                    Button(gewaehlt.count == befund.tage.count ? "Keinen" : "Alle") {
                        gewaehlt = gewaehlt.count == befund.tage.count
                            ? []
                            : Set(befund.tage.map(\.id))
                    }
                    .font(.caption)
                }
            }

            Section {
                Button("Andere Datei wählen", systemImage: "folder") { waehler = true }
            }
        }
    }

    private func zeile(_ tag: Fernweheinfuhr.Tag) -> some View {
        let text = Fernweheinfuhr.tagestext(tag, autorenNennen: false, wetterAnhaengen: false)
        return Button {
            if gewaehlt.contains(tag.id) { gewaehlt.remove(tag.id) } else { gewaehlt.insert(tag.id) }
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: gewaehlt.contains(tag.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(gewaehlt.contains(tag.id) ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(tag.datum.mittel)
                        if !imBuch(tag.datum) {
                            Text("neu")
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.18), in: Capsule())
                        }
                    }
                    if !text.ueberschrift.isEmpty {
                        Text(text.unterueberschrift.isEmpty
                             ? text.ueberschrift
                             : text.ueberschrift + " \u{00B7} " + text.unterueberschrift)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                    Text(untertitel(tag))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let wetter = tag.wetter {
                        Text(wetter)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if let zeile = zonenzeile(tag) {
                        Text(zeile)
                            .font(.caption2)
                            .foregroundStyle(tag.zoneNachgeschlagen ? Color.secondary : Color.orange)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // Eine angenommene Zone steht orange da: Sie ist keine Auskunft über
    // den Ort, sondern eine Einstellung.
    private func zonenzeile(_ tag: Fernweheinfuhr.Tag) -> String? {
        guard let zone = tag.zone else { return nil }
        let name = Ortszeit.beschreibung(zone, am: tag.datum.mittag)
        return tag.zoneNachgeschlagen ? name : name + " \u{2014} angenommen"
    }

    private func untertitel(_ tag: Fernweheinfuhr.Tag) -> String {
        var teile: [String] = []
        teile.append(tag.eintraege.count == 1 ? "1 Eintrag" : "\(tag.eintraege.count) Einträge")
        if !tag.fotos.isEmpty { teile.append("\(tag.fotos.count) Fotos") }
        if !tag.orte.isEmpty { teile.append("\(tag.orte.count) Orte") }
        if !tag.spur.isEmpty {
            var spur = "Spur \(tag.spur.count) Punkte"
            if tag.spurenInDatei > 1 { spur += " (längste von \(tag.spurenInDatei))" }
            teile.append(spur)
        }
        return teile.joined(separator: " \u{00B7} ")
    }

    private func fotozeile(_ befund: Fernweheinfuhr.Befund) -> String {
        guard befund.fotos > 0 else { return "keine" }
        return "\(befund.fotos), davon \(befund.fotosMitDatei) mit Bild (\(befund.fotoartName))"
    }

    // Was fehlt, steht als Satz da — der Vertrag sagt es für fehlende Fotos
    // ausdrücklich: „Nicht still übergehen — zählen und sagen."
    private func auskunft(_ befund: Fernweheinfuhr.Befund) -> String {
        var saetze: [String] = []
        if befund.fotosFehlt > 0 {
            saetze.append("\(befund.fotosFehlt) Fotos konnte Fernweh auf seinem Gerät nicht holen.")
        }
        if befund.fotoart == "kopie", befund.fotosMitDatei > 0 {
            saetze.append("Die Bilder sind verkleinerte Kopien (höchstens 2048 Bildpunkte) "
                          + "\u{2014} für ein gedrucktes Buch meist zu klein. Für den Druck in "
                          + "Fernweh \u{201E}Originale\u{201C} wählen.")
        }
        if befund.verworfen > 0 {
            saetze.append("\(befund.verworfen) Angaben in der Datei ließen sich nicht lesen und "
                          + "wurden übersprungen.")
        }
        if befund.tageOhneDatum > 0 {
            saetze.append("\(befund.tageOhneDatum) Tage tragen kein lesbares Datum und fehlen.")
        }
        if saetze.isEmpty { saetze.append("Alles in der Datei ließ sich lesen.") }
        return saetze.joined(separator: " ")
    }

    private func schaltersatz(_ befund: Fernweheinfuhr.Befund) -> String {
        var saetze = ["Ohne \u{201E}ersetzen\u{201C} wird ein vorhandener Text ergänzt; steht "
                      + "derselbe Text schon da, bleibt er einmal stehen."]
        if befund.fotos > befund.fotosMitDatei {
            let ohne = befund.fotos - befund.fotosMitDatei
            var satz = "\(ohne) Fotos stehen ohne Bild in der Datei. Liegen sie in deiner "
                + "Mediathek (dieselbe Apple-ID wie in Fernweh), holt die App sie dort."
            switch Reisewerk.mediathekStand {
            case .authorized, .limited: break
            default: satz += " Dafür braucht sie den Zugriff auf die Fotos \u{2014} er wird beim Übernehmen erfragt."
            }
            saetze.append(satz)
        }
        return saetze.joined(separator: " ")
    }

    // Beide Wege sagen, was sie kosten — keiner ist der richtige für jede Reise.
    private func ortesatz(_ befund: Fernweheinfuhr.Befund) -> String {
        switch orte {
        case .fernweh:
            return "In der Datei stehen \(befund.orte) benannte Orte und \(befund.spurpunkte) "
                + "Spurpunkte (Wege, Wanderungen). Sie kommen als Reisepunkte ins Buch, dazu "
                + "die Orte der Fotos \u{2014} auch die, die nur Fernweh kannte."
        case .fotos:
            var satz = "Spur und benannte Orte aus Fernweh bleiben draußen. Die Reisepunkte "
                + "baut die App aus den Fotos: aus ihren Metadaten und, wo die fehlen, aus dem "
                + "Aufnahmeort in deiner Mediathek. Die Karte zeigt dann die Verbindung der "
                + "Fotoorte, nicht den gegangenen Weg."
            if ersetzen {
                satz += " Mit \u{201E}ersetzen\u{201C} verschwindet auch die Spur eines früheren "
                    + "Einlesens (auch aus Tagesspur)."
            } else {
                satz += " Eine schon vorhandene Spur bleibt stehen; mit \u{201E}ersetzen\u{201C} geht sie weg."
            }
            switch Reisewerk.mediathekStand {
            case .authorized, .limited: break
            default: satz += " Für die Mediathek wird beim Übernehmen um Zugriff gefragt."
            }
            return satz
        }
    }

    private func imBuch(_ datum: Tagesdatum) -> Bool {
        werk.reise.tage.contains { $0.datum == datum }
    }

    private var zonen: [TimeZone] {
        var liste = [TimeZone.current]
        if let utc = TimeZone(identifier: "UTC") { liste.append(utc) }
        liste += TimeZone.knownTimeZoneIdentifiers.sorted().compactMap(TimeZone.init(identifier:))
        var gesehen = Set<String>()
        return liste.filter { gesehen.insert($0.identifier).inserted }
    }

    // MARK: - Tun

    private func einlesen(_ ort: URL) {
        fehler = nil
        dateiname = ort.lastPathComponent
        do {
            daten = try Fernweheinfuhr.oeffnen(ort)
        } catch {
            fehler = error.localizedDescription
            return
        }
        nochEinmalLesen()
    }

    // Gelesen wird ABSEITS des Hauptfadens: Das Verzeichnis einer großen
    // Datei durchzugehen und die Beschreibung zu entziffern ist schnell,
    // aber nicht so schnell, dass es auf den Hauptfaden gehört.
    private func nochEinmalLesen() {
        guard let daten else { return }
        let zone = zone
        liest = true
        Task { @MainActor in
            let ergebnis: Result<Fernweheinfuhr.Befund, Error> = await Task.detached(priority: .userInitiated) {
                Result { try Fernweheinfuhr.lesen(daten, zone: zone) }
            }.value
            liest = false
            switch ergebnis {
            case let .success(neu):
                befund = neu
                let bisher = gewaehlt
                gewaehlt = bisher.isEmpty ? Set(neu.tage.map(\.id)) : bisher
                autorenNennen = neu.autoren.count > 1
                titel = werk.reise.titel == "Meine Reise" && werk.reise.untertitel.isEmpty
                fehler = nil
                zonenNachschlagen(neu)
            case let .failure(fehlschlag):
                befund = nil
                gewaehlt = []
                fehler = fehlschlag.localizedDescription
            }
        }
    }

    // Wie bei der Tagesspur: Die Vorschau steht sofort da, die Zonen tragen
    // sich nach. Eine späte Antwort darf nicht den Stand von vorhin
    // zurückbringen.
    private func zonenNachschlagen(_ roh: Fernweheinfuhr.Befund) {
        sucht = true
        Task { @MainActor in
            let fertig = await Fernweheinfuhr.ortszeitenSetzen(roh)
            guard befund?.tage.map(\.id) == roh.tage.map(\.id),
                  befund?.zone.identifier == roh.zone.identifier else { return }
            befund = fertig
            sucht = false
        }
    }

    private func uebernehmen() {
        guard let befund, let daten else { return }
        let wunsch = Reisewerk.Fernwehwunsch(tage: gewaehlt, ersetzen: ersetzen,
                                             autorenNennen: autorenNennen, wetter: wetter,
                                             titel: titel, ausMediathek: ausMediathek,
                                             orte: orte)
        arbeit = "Wird vorbereitet\u{2026}"
        Task { @MainActor in
            // Die Mediathek nur fragen, wenn sie gebraucht wird — und erst
            // auf den Tipp hin, nie beim Öffnen des Blattes.
            let brauchtMediathek = (wunsch.ausMediathek && befund.fotos > befund.fotosMitDatei)
                || (wunsch.orte == .fotos && befund.fotos > 0)
            if brauchtMediathek, Reisewerk.mediathekStand == .notDetermined
            {
                _ = await Reisewerk.mediathekFragen()
            }
            let satz = await werk.fernwehUebernehmen(befund, daten: daten, wunsch: wunsch) { stand in
                arbeit = stand
            }
            werk.meldung = .init(text: satz)
            arbeit = nil
            schliessen()
        }
    }
}
