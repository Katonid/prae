import SwiftUI
import UIKit
import UniformTypeIdentifiers

// VORLAGEN — Einstellungen, die man einmal trifft und wiederverwendet
// (ab 1.0.95).
//
// Ein Bildschirm für beide Arten, und die Trennung steht in der
// Überschrift: „Aussehen des Buches" ist die eigene Handschrift,
// „Druckereien" sind fremde Vorgaben. Was eine Vorlage überschreibt, steht
// vor dem Anwenden da — erst zeigen, dann übernehmen, wie bei jeder
// Einfuhr dieser App.
struct VorlagenView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen
    @State private var vorlagen: [Vorlage] = []
    @State private var sichernArt: Vorlage.Art?
    @State private var neuerName = ""
    @State private var umbenennen: Vorlage?
    @State private var teilen: Teilwunsch?
    @State private var waehler = false
    @State private var meldung = ""

    struct Teilwunsch: Identifiable {
        var ort: URL
        var id: String { ort.lastPathComponent }
    }

    var body: some View {
        NavigationStack {
            inhalt
        }
    }

    private var inhalt: some View {
        Form {
            sichernAbschnitt
            ForEach(Vorlage.Art.allCases) { art in
                artAbschnitt(art)
            }
            dateiAbschnitt
            if !meldung.isEmpty {
                Section {
                    Text(meldung)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Vorlagen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { schliessen() }
            }
        }
        .task { neuLesen() }
        // Der Dateiwähler hängt an der WURZEL dieses Blattes und nicht an
        // einer Zeile: Eine `Form` ist eine `List` und baut ihre Zeilen
        // erst auf, wenn sie in Sichtweite kommen (die Lehre aus Tafelbild).
        .fullScreenCover(isPresented: $waehler) {
            Dateiwahl(typen: dateitypen) { urls in
                waehler = false
                guard let erste = urls.first else { return }
                einlesen(erste)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $teilen) { wunsch in
            Teilenblatt(gegenstaende: [wunsch.ort])
        }
        // EIN Blatt je Ansicht — zwei streiten sich, und eines schweigt
        // (die Lehre aus Tafelbild). Das Anwenden ist deshalb eine
        // Unterseite DIESES Stapels und kein zweites Blatt: Auf dem iPad
        // wäre das ein Kärtchen auf einem Kärtchen (die Lehre aus 1.0.18).
        .navigationDestination(for: Vorlage.self) { vorlage in
            Anwendenseite(werk: werk, vorlage: vorlage) { satz in
                meldung = satz
            }
        }
        .alert("Vorlage sichern", isPresented: .init(
            get: { sichernArt != nil },
            set: { if !$0 { sichernArt = nil } }
        )) {
            TextField("Name", text: $neuerName)
            Button("Sichern") { sichern() }
            Button("Abbrechen", role: .cancel) { sichernArt = nil }
        } message: {
            Text(namenshinweis)
        }
        .alert("Vorlage umbenennen", isPresented: .init(
            get: { umbenennen != nil },
            set: { if !$0 { umbenennen = nil } }
        )) {
            TextField("Name", text: $neuerName)
            Button("Sichern") { namenSetzen() }
            Button("Abbrechen", role: .cancel) { umbenennen = nil }
        }
    }

    private var namenshinweis: String {
        if sichernArt == .druckerei {
            return "Ein Name, unter dem du sie wiederfindest \u{2014} zum Beispiel der "
                + "Name der Druckerei samt Format."
        }
        return "Ein Name, unter dem du sie wiederfindest \u{2014} zum Beispiel "
            + "\u{201E}Urlaubstagebuch, ruhig\u{201C}."
    }

    // MARK: - Aus diesem Buch sichern

    @ViewBuilder
    private var sichernAbschnitt: some View {
        Section {
            ForEach(Vorlage.Art.allCases) { art in
                Button {
                    neuerName = vorschlag(art)
                    sichernArt = art
                } label: {
                    Label(art.name + " sichern\u{2026}", systemImage: art.symbol)
                }
            }
        } header: {
            Text("Aus diesem Buch")
        } footer: {
            Text("Eine Vorlage trägt EINSTELLUNGEN und keinen Inhalt: kein Foto, "
                 + "keinen Text, keine Seiten. Was die App dabei ausdrücklich "
                 + "weglässt, steht beim Anwenden noch einmal da.")
        }
    }

    // MARK: - Die Listen

    @ViewBuilder
    private func artAbschnitt(_ art: Vorlage.Art) -> some View {
        let liste = vorlagen.filter { $0.art == art }
        Section {
            if liste.isEmpty {
                Text("Noch keine \u{2014} sichere die Einstellungen dieses Buches oben.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(liste) { vorlage in
                NavigationLink(value: vorlage) {
                    zeile(vorlage)
                }
                .swipeActions(edge: .trailing) {
                    Button("Löschen", role: .destructive) { loeschen(vorlage) }
                }
                .contextMenu {
                    Button("Als Datei teilen\u{2026}", systemImage: "square.and.arrow.up") {
                        teilenlassen(vorlage)
                    }
                    Button("Umbenennen\u{2026}", systemImage: "pencil") {
                        neuerName = vorlage.name
                        umbenennen = vorlage
                    }
                    Divider()
                    Button {
                        vorgabeUmschalten(vorlage)
                    } label: {
                        Label(vorgabeAn(vorlage) ? "Nicht mehr für neue Bücher vorschlagen"
                                                 : "Für neue Bücher vorschlagen",
                              systemImage: "wand.and.stars")
                    }
                    Divider()
                    Button(role: .destructive) {
                        loeschen(vorlage)
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
        } header: {
            Text(art == .aussehen ? "Aussehen des Buches" : "Druckereien")
        } footer: {
            Text(artfuss(art))
        }
    }

    private func artfuss(_ art: Vorlage.Art) -> String {
        if art == .aussehen {
            return "Schrift, Farben, Ränder, Fugen, wie sich Fotos abheben, wie "
                + "Textfelder aussehen, Hintergrund, Wasserzeichen und Karten "
                + "\u{2014} also alles, was du selbst entscheidest."
        }
        return "Seitenformat, Anschnitt, Sicherheitsabstand, Bundsteg und die Maße "
            + "des Umschlagbogens samt Rückenstärke \u{2014} also alles, was die "
            + "Druckerei vorgibt."
    }

    @ViewBuilder
    private func zeile(_ vorlage: Vorlage) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(vorlage.name)
                    .font(.body)
                if vorgabeAn(vorlage) {
                    Image(systemName: "wand.and.stars")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Wird neuen Büchern vorgeschlagen")
                }
            }
            Text(vorlage.beschreibung)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: - Datei

    @ViewBuilder
    private var dateiAbschnitt: some View {
        Section {
            Button {
                waehler = true
            } label: {
                Label("Vorlage einlesen\u{2026}", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Austausch")
        } footer: {
            Text(dateisatz)
        }
    }

    // Ausgeschrieben und nicht als ternärer Ausdruck mit zwei langen
    // `+`-Ketten: Genau diese Mischung sprengt den Typprüfer (die Lehre aus
    // 1.0.38).
    private var ablagesatz: String {
        if Wolke.stand == .an {
            return "Die Vorlagen liegen in deinem iCloud-Laufwerk neben den Büchern "
                + "und stehen damit auf jedem Gerät zur Verfügung, das mit derselben "
                + "Apple-ID angemeldet ist."
        }
        return "Die Vorlagen liegen auf diesem Gerät. Schalte in den Einstellungen "
            + "den Abgleich über iCloud ein, dann stehen sie auf jedem deiner "
            + "Geräte \u{2014} sie ziehen dabei mit um."
    }

    private var dateisatz: String {
        let erste = "Eine Vorlage lässt sich als Datei mit der Endung ."
            + Vorlagenablage.endung
            + " weitergeben \u{2014} über \u{201E}Als Datei teilen\u{2026}\u{201C} im Menü "
            + "einer Zeile (lange drauftippen)."
        return erste + "\n\n" + ablagesatz
    }

    private var dateitypen: [UTType] {
        var liste: [UTType] = []
        if let eigen = UTType(filenameExtension: Vorlagenablage.endung) { liste.append(eigen) }
        liste.append(.json)
        liste.append(.data)
        return liste
    }

    // MARK: - Handgriffe

    private func neuLesen() {
        vorlagen = Vorlagenablage.alle()
    }

    private func vorschlag(_ art: Vorlage.Art) -> String {
        switch art {
        case .aussehen:
            return Buchstil.mit(werk.reise.stil)?.name ?? werk.reise.anzeigename
        case .druckerei:
            return werk.reise.format.masstext
        }
    }

    private func sichern() {
        guard let art = sichernArt else { return }
        let name = neuerName.trimmingCharacters(in: .whitespacesAndNewlines)
        meldung = werk.vorlageSichern(name: name.isEmpty ? vorschlag(art) : name, art: art)
        sichernArt = nil
        neuLesen()
    }

    private func namenSetzen() {
        guard var vorlage = umbenennen else { return }
        let name = neuerName.trimmingCharacters(in: .whitespacesAndNewlines)
        umbenennen = nil
        guard !name.isEmpty else { return }
        vorlage.name = name
        do {
            try Vorlagenablage.sichern(vorlage)
        } catch {
            meldung = "Der neue Name ließ sich nicht sichern: " + error.localizedDescription
        }
        neuLesen()
    }

    private func loeschen(_ vorlage: Vorlage) {
        Vorlagenablage.loeschen(vorlage)
        if vorgabeAn(vorlage) { Vorlagenablage.vorgabeSetzen(vorlage.art, nil) }
        neuLesen()
    }

    private func teilenlassen(_ vorlage: Vorlage) {
        do {
            teilen = Teilwunsch(ort: try Vorlagenablage.zumTeilen(vorlage))
        } catch {
            meldung = "Die Datei ließ sich nicht schreiben: " + error.localizedDescription
        }
    }

    // Gelesen wird mit `startAccessingSecurityScopedResource`: Auf dem Mac
    // kommt die Datei aus einem fremden Ordner und ließe sich sonst gar
    // nicht öffnen, und zwar ohne Fehlermeldung (die Lehre aus 1.0.62).
    //
    // Weggeräumt wird NUR, was in unserem eigenen temporären Ordner liegt —
    // `Dateiwahl` arbeitet mit `asCopy: true`, und eine fremde Datei
    // löscht diese App nie.
    private func einlesen(_ ort: URL) {
        let offen = ort.startAccessingSecurityScopedResource()
        defer { if offen { ort.stopAccessingSecurityScopedResource() } }
        do {
            let vorlage = try Vorlagenablage.einlesen(ort)
            meldung = "\u{201E}" + vorlage.name + "\u{201C} eingelesen."
            neuLesen()
        } catch {
            meldung = "Die Datei ließ sich nicht lesen: " + error.localizedDescription
        }
        let tmp = FileManager.default.temporaryDirectory.standardizedFileURL.path
        if ort.standardizedFileURL.path.hasPrefix(tmp) {
            try? FileManager.default.removeItem(at: ort)
        }
    }

    private func vorgabeAn(_ vorlage: Vorlage) -> Bool {
        Vorlagenablage.vorgabe(vorlage.art)?.id == vorlage.id
    }

    private func vorgabeUmschalten(_ vorlage: Vorlage) {
        Vorlagenablage.vorgabeSetzen(vorlage.art, vorgabeAn(vorlage) ? nil : vorlage)
        neuLesen()
    }
}

// MARK: - Erst zeigen, dann übernehmen

// Was eine Vorlage überschreibt, steht VOR dem Anwenden da — dieselbe
// Bauweise wie beim Formatwechsel (1.0.27) und beim Neuverteilen (1.0.38).
// Sie fasst das ganze Buch an; ein Knopf, der ungefragt loslegt, ist ein
// Sprung ins Dunkle.
private struct Anwendenseite: View {
    @ObservedObject var werk: Reisewerk
    let vorlage: Vorlage
    let fertig: (String) -> Void
    @Environment(\.dismiss) private var schliessen
    @State private var auchHandarbeit = false
    @State private var formatweg = Formatweg.mitrechnen

    enum Formatweg: String, CaseIterable, Identifiable {
        case mitrechnen
        case nurFormat
        case lassen

        var id: String { rawValue }

        var name: String {
            switch self {
            case .mitrechnen: return "Format wechseln und Inhalt mitrechnen"
            case .nurFormat: return "Nur das Format wechseln"
            case .lassen: return "Format lassen, wie es ist"
            }
        }
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Vorlage", value: vorlage.name)
                LabeledContent("Art", value: vorlage.art.name)
                LabeledContent("Angelegt", value: datum)
                if !vorlage.fassung.isEmpty {
                    LabeledContent("Aus Fassung", value: vorlage.fassung)
                }
            }

            Section {
                ForEach(umfang, id: \.self) { zeile in
                    Label(zeile, systemImage: "checkmark")
                        .font(.footnote)
                }
            } header: {
                Text("Was gesetzt wird")
            } footer: {
                Text("Alles andere bleibt, wie es ist \u{2014} Text, Fotos, Seiten und "
                     + "der Titel dieses Buches sowieso. Mit \u{201E}Widerrufen\u{201C} "
                     + "ist der ganze Griff zurückzunehmen.")
            }

            if formatAnders {
                Section {
                    LabeledContent("Jetzt", value: werk.reise.format.masstext)
                    LabeledContent("Vorlage", value: vorlage.werte.format.masstext)
                    Picker("Weg", selection: $formatweg) {
                        ForEach(Formatweg.allCases) { weg in
                            Text(weg.name).tag(weg)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Das Format ist ein anderes")
                } footer: {
                    Text("Mitgerechnet wird alles, was eine Länge ist: Blockrahmen, "
                         + "Ränder, Schriftgrößen. \u{201E}Nur das Format\u{201C} ist der "
                         + "Weg, wenn danach ohnehin alles neu verteilt wird.")
                }
            }

            if handarbeit > 0 {
                Section {
                    Toggle("Auch bearbeitete Seiten neu setzen", isOn: $auchHandarbeit)
                } header: {
                    Text(handarbeitstitel)
                } footer: {
                    Text("Ausgeschaltet bleiben diese Tage so stehen, wie du sie "
                         + "gesetzt hast \u{2014} die neuen Einstellungen gelten dort "
                         + "erst, wenn du sie einzeln neu anordnen lässt.")
                }
            }

            if !vorlage.werte.bildhinweise.isEmpty {
                Section {
                    ForEach(vorlage.werte.bildhinweise, id: \.self) { satz in
                        Text(satz)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Was eine Vorlage nicht mitbringen kann")
                }
            }

            Section {
                Button("Vorlage anwenden") {
                    let satz = werk.vorlageAnwenden(
                        vorlage,
                        auchHandarbeit: auchHandarbeit,
                        formatMitrechnen: formatwunsch
                    )
                    schliessen()
                    fertig(satz)
                }
            }
        }
        .navigationTitle("Vorlage anwenden")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var formatAnders: Bool {
        vorlage.art == .druckerei
            && vorlage.werte.format.millimeter != werk.reise.format.millimeter
    }

    private var formatwunsch: Bool? {
        guard formatAnders else { return nil }
        switch formatweg {
        case .mitrechnen: return true
        case .nurFormat: return false
        case .lassen: return nil
        }
    }

    private var handarbeit: Int { werk.handarbeitstage() }

    private var handarbeitstitel: String {
        handarbeit == 1 ? "Ein Tag von Hand bearbeitet"
                        : "\(handarbeit) Tage von Hand bearbeitet"
    }

    private var datum: String {
        vorlage.angelegt.formatted(date: .abbreviated, time: .omitted)
    }

    // WER DIE LISTE IN `Vorlagenwerte.anwenden` ÄNDERT, ÄNDERT SIE HIER MIT.
    // Eine Aufzählung, die etwas verspricht, was nicht gesetzt wird — oder
    // etwas verschweigt, was gesetzt wird —, ist schlimmer als keine.
    private var umfang: [String] {
        switch vorlage.art {
        case .aussehen:
            return ["Stil, Akzentfarbe und Papierfarbe",
                    "Alle vier Schriften samt Größen und Ausrichtung",
                    "Ränder, Fuge und Eckenradius",
                    "Wie sich Fotos abheben (Schatten, weißer Rand, Abstand der Bildunterschrift)",
                    "Wie Textfelder aussehen (Grund, Innenabstand, Linie, Schatten)",
                    "Breite der Textspalte und der Karte, Datumsstil, Seitenzahlen",
                    "Seitenhintergrund, Wasserzeichen und Karteneinstellung",
                    "Die Gestaltung des Umschlags (Hintergrund, Rand, Titelgröße und -lage)"]
        case .druckerei:
            return ["Seitenformat",
                    "Anschnitt \u{2014} und ob am Bund einer liegt",
                    "Sicherheitsabstand außen und am Bund",
                    "Bundsteg",
                    "Maß und Anschnitt des Umschlagbogens",
                    "Einband, Papierstärke, Deckenstärke und die Rückenstärke samt Tabelle",
                    "Ob die Innenseiten des Umschlags mitgeliefert werden"]
        }
    }
}
