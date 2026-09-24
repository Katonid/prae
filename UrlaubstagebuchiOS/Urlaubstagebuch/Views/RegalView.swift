import SwiftUI
import UIKit

struct RegalView: View {
    @EnvironmentObject private var regal: Regal
    @State private var neuerTitel = ""
    @State private var anlegenOffen = false
    @State private var zuLoeschen: Reise?
    @State private var einstellungen = false
    @State private var angebot: Buchdatei.Befund?
    @State private var einlesefehler: String?
    @State private var kopiert: String?
    @State private var kopiertGerade = false
    // UMBENENNEN IM REGAL (ab 1.0.84). Geändert wird dabei der Name in der
    // ÜBERSICHT und nie der gedruckte Titel — hier steht man vor der
    // Liste, nicht vor dem Buch.
    @State private var umzubenennen: Reise?
    @State private var neuerName = ""
    // Einlesen heißt: jedes Bild des Buches auf die Platte schreiben.
    // Das gehört nicht auf den Hauptfaden (ab 1.0.103) — dieselbe
    // Rechnung wie beim Schreiben einer Buchdatei.
    @State private var arbeit: Buchdatei.Fortschritt?
    @State private var arbeitsaufgabe: Task<Void, Never>?
    // Abgebrochen wird die ABGESETZTE Aufgabe: `Task.detached` erbt den
    // Abbruch des Aufrufers nicht.
    @State private var abbruch: (() -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                if regal.reisen.isEmpty {
                    leer
                } else {
                    liste
                }
            }
            .navigationTitle("Reisetagebücher")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        einstellungen = true
                    } label: {
                        Label("Einstellungen", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        neuerTitel = ""
                        anlegenOffen = true
                    } label: {
                        Label("Neue Reise", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $einstellungen) {
                EinstellungenView()
                    .environmentObject(regal)
            }
            .arbeitsanzeige(arbeit, titel: "Buchdatei", abbrechen: abbruch)
            // Eine hereingereichte Buchdatei — aus „Dateien", per AirDrop
            // oder über den Wähler in den Einstellungen. Die Frage steht
            // hier und nur hier.
            .onChange(of: regal.angeboteneDatei) { _, ort in
                guard let ort else { return }
                // Auch das Nachsehen liest eine Datei, die in iCloud liegen
                // kann — über die Wolke wartet der erste Zugriff, bis sie
                // geholt ist.
                Task { @MainActor in
                    arbeit = Buchdatei.Fortschritt(text: "Datei wird gelesen\u{2026}")
                    defer { arbeit = nil }
                    do {
                        angebot = try await mitZugriffAbseits(ort) {
                            try Buchdatei.pruefen(ort)
                        }
                    } catch {
                        einlesefehler = error.localizedDescription
                        aufraeumen()
                    }
                }
            }
            .alert("Buch einlesen", isPresented: .init(
                get: { angebot != nil },
                set: { if !$0 { angebot = nil; aufraeumen() } }
            )) {
                if angebot?.schonVorhanden == true {
                    Button("Vorhandenes ersetzen", role: .destructive) { einlesen(alsKopie: false) }
                    Button("Als Kopie anlegen") { einlesen(alsKopie: true) }
                } else {
                    Button("Einlesen") { einlesen(alsKopie: false) }
                }
                Button("Abbrechen", role: .cancel) { angebot = nil; aufraeumen() }
            } message: {
                if let angebot { Text(einlesetext(angebot)) }
            }
            .alert("Das ging nicht", isPresented: .init(
                get: { einlesefehler != nil },
                set: { if !$0 { einlesefehler = nil } }
            )) {
                Button("Gut") { einlesefehler = nil }
            } message: {
                Text(einlesefehler ?? "")
            }
            // EIN BLATT STATT EINES ALERTS (ab 1.0.95).
            //
            // Bis 1.0.94 stand hier ein Alert mit einem Textfeld. Seit es
            // Vorlagen gibt, ist beim Anlegen eine zweite Frage zu
            // beantworten — und ein Alert kann keine Auswahl tragen. Zwei
            // Wege nebeneinander (Alert ohne Vorlagen, Blatt mit) wären
            // zwei Fassungen derselben Sache und liefen auseinander.
            .sheet(isPresented: $anlegenOffen) {
                NeueReiseBlatt(titel: $neuerTitel) { aussehen, druckerei in
                    let neu = regal.anlegen(titel: neuerTitel,
                                            aussehen: aussehen, druckerei: druckerei)
                    regal.oeffnen(neu)
                }
            }
            .alert("Name in der Übersicht", isPresented: .init(
                get: { umzubenennen != nil },
                set: { if !$0 { umzubenennen = nil } }
            )) {
                TextField("Name", text: $neuerName)
                Button("Übernehmen") {
                    if let reise = umzubenennen { regal.umbenennen(reise, auf: neuerName) }
                    umzubenennen = nil
                }
                if umzubenennen?.hatEigenenRegalnamen == true {
                    Button("Wieder wie der Titel") {
                        if let reise = umzubenennen { regal.umbenennen(reise, auf: "") }
                        umzubenennen = nil
                    }
                }
                Button("Abbrechen", role: .cancel) { umzubenennen = nil }
            } message: {
                Text(umbenenntext)
            }
            .alert("Kopiert", isPresented: .init(
                get: { kopiert != nil },
                set: { if !$0 { kopiert = nil } }
            )) {
                Button("Gut") { kopiert = nil }
            } message: {
                Text(kopiert ?? "")
            }
            .alert("Reise löschen?", isPresented: .init(
                get: { zuLoeschen != nil },
                set: { if !$0 { zuLoeschen = nil } }
            )) {
                Button("Löschen", role: .destructive) {
                    if let reise = zuLoeschen { regal.loeschen(reise.id) }
                    zuLoeschen = nil
                }
                Button("Abbrechen", role: .cancel) { zuLoeschen = nil }
            } message: {
                Text("Alle Seiten, Texte und Fotos dieser Reise werden vom Gerät gelöscht. Das lässt sich nicht rückgängig machen.")
            }
        }
        .fullScreenCover(item: $regal.offen) { werk in
            ReiseView(werk: werk)
                .environmentObject(regal)
        }
    }

    // Kopiert wird in einem `Task`, weil die Bilder abseits des
    // Hauptfadens gehen (siehe `Regal.duplizieren`). Solange er läuft,
    // sind die Zeilen gesperrt: Zweimal auf dasselbe Buch getippt ergäbe
    // zwei Kopien, und die zweite hieße dann auch noch anders.
    private func duplizieren(_ reise: Reise) {
        guard !kopiertGerade else { return }
        kopiertGerade = true
        Task {
            let satz = await regal.duplizieren(reise)
            kopiertGerade = false
            kopiert = satz
        }
    }

    private func umbenennen(_ reise: Reise) {
        // Vorbelegt mit dem Namen, der GILT — nicht mit einem leeren Feld:
        // Sonst ließe sich beim Öffnen nicht unterscheiden, ob nichts
        // eingetragen ist oder nur nichts dasteht.
        neuerName = reise.anzeigename
        umzubenennen = reise
    }

    private var umbenenntext: String {
        guard let reise = umzubenennen else { return "" }
        var satz = "Dieser Name steht nur in der Übersicht, auf der Buchdatei und auf "
        satz += "der PDF. Auf der Titelseite steht weiter \u{201E}\(reise.titel)\u{201C}."
        if !reise.hatEigenenRegalnamen {
            satz += "\n\nBisher folgt der Name dem Titel."
        }
        return satz
    }

    private func einlesetext(_ befund: Buchdatei.Befund) -> String {
        var satz = "\u{201E}\(befund.reise.anzeigename)\u{201C} mit \(befund.reise.tage.count) Tagen "
            + "und \(befund.bilder) Bildern."
        if befund.fehlendeBilder > 0 {
            satz += " \(befund.fehlendeBilder) Bilder fehlen in der Datei."
        }
        if befund.schonVorhanden {
            satz += "\n\nEin Buch mit derselben Kennung gibt es schon. Ersetzen "
                + "überschreibt es; eine Kopie legt ein zweites daneben."
        }
        return satz
    }

    private func einlesen(alsKopie: Bool) {
        guard let ort = regal.angeboteneDatei, arbeitsaufgabe == nil else { return }
        angebot = nil
        let melder = Arbeitsmelder()
        // Der Zugriff auf eine Datei an Ort und Stelle wird angemeldet und
        // bleibt offen, solange die Arbeit läuft — `defer` greift auch nach
        // einem `await`.
        let offen = ort.startAccessingSecurityScopedResource()
        let kiste = Kiste<Void>()
        let lauf = Task.detached(priority: .userInitiated) {
            kiste.ergebnis = Result {
                _ = try Buchdatei.einlesen(ort, alsKopie: alsKopie) { melder.melde($0) }
            }
        }
        abbruch = { lauf.cancel() }
        arbeitsaufgabe = Task { @MainActor in
            defer {
                if offen { ort.stopAccessingSecurityScopedResource() }
                arbeit = nil
                arbeitsaufgabe = nil
                abbruch = nil
                aufraeumen()
            }
            arbeit = Buchdatei.Fortschritt(text: "Wird eingelesen\u{2026}")
            let anzeige = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(200))
                    if let stand = melder.stand { arbeit = stand }
                }
            }
            defer { anzeige.cancel() }
            await lauf.value
            switch kiste.ergebnis {
            case .success:
                regal.neuLesen()
            case .failure(let fehler) where fehler is CancellationError:
                einlesefehler = "Das Einlesen wurde abgebrochen."
            case .failure(let fehler):
                einlesefehler = fehler.localizedDescription
            case nil:
                einlesefehler = "Das Einlesen hat nichts zurückgegeben."
            }
        }
    }

    // EINE DATEI AN ORT UND STELLE MUSS ANGEMELDET WERDEN (ab 1.0.62).
    //
    // Seit `LSSupportsOpeningDocumentsInPlace = YES` gibt das System nicht
    // mehr nur eine Kopie im Posteingang heraus, sondern auch die
    // Originaldatei in einem fremden Ordner — und die lässt sich ohne
    // angemeldeten Zugriff nicht lesen. Ohne diese Zeilen käme aus „in
    // Reisebuch öffnen" nichts an, und zwar ohne Fehlermeldung.
    //
    // Für eine Datei aus dem Posteingang ist der Aufruf folgenlos: Er
    // gibt dort `false` zurück, und gelesen wird trotzdem.
    //
    // ANGEMELDET WIRD AUF DEM HAUPTFADEN, GEARBEITET DANEBEN (ab 1.0.103).
    // Der Zugriff gilt für die Dauer des Aufrufs, und `defer` läuft auch
    // nach einem `await` — er bleibt also offen, solange die Arbeit läuft.
    private func mitZugriffAbseits<W>(
        _ ort: URL, _ arbeit: @escaping @Sendable () throws -> W) async throws -> W
    {
        let offen = ort.startAccessingSecurityScopedResource()
        defer { if offen { ort.stopAccessingSecurityScopedResource() } }
        let kiste = Kiste<W>()
        await Task.detached(priority: .userInitiated) {
            kiste.ergebnis = Result { try arbeit() }
        }.value
        switch kiste.ergebnis {
        case .success(let wert): return wert
        case .failure(let fehler): throw fehler
        case nil: throw Buchdatei.Fehler.kaputt("Die Arbeit hat nichts zurückgegeben.")
        }
    }

    // Was iOS in den Posteingang der App gelegt hat, gehört danach nicht
    // mehr dort hin: Beim nächsten Öffnen läge es sonst noch einmal da.
    private func aufraeumen() {
        if let ort = regal.angeboteneDatei,
           ort.path.contains("/Inbox/")
        {
            try? FileManager.default.removeItem(at: ort)
        }
        regal.angeboteneDatei = nil
    }

    private var leer: some View {
        ContentUnavailableView {
            Label("Noch kein Reisetagebuch", systemImage: "book.closed")
        } description: {
            Text("Leg eine Reise an, wirf die Fotos hinein und lies deinen Tagebuchtext ein. Die App verteilt beides auf die Tage und setzt daraus Seiten.")
        } actions: {
            Button("Reise anlegen") {
                neuerTitel = ""
                anlegenOffen = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var liste: some View {
        List {
            // DIE APP SAGT, WORAN SIE GESTORBEN IST (ab 1.0.100).
            //
            // Ein Absturz nimmt jede Meldung mit, die im Speicher steht —
            // deshalb legt `Absturzspur` ihren Schritt vorher auf die
            // Platte. Hier steht er, kopierbar, und verschwindet nach dem
            // ersten Lesen: Ein Befund, der zweimal erschiene, sähe aus wie
            // ein zweiter Absturz.
            if let befund = regal.absturzbefund {
                Section {
                    Label("Beim letzten Mal ist die App abgestürzt.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(befund)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    Button("Befund kopieren", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = befund
                    }
                    Button("Weglegen") {
                        Absturzspur.weglegen()
                        regal.absturzbefund = nil
                    }
                } header: {
                    Text("Absturz")
                } footer: {
                    Text("Der letzte Schritt vor dem Absturz. Schick ihn mit \u{2014} er sagt, an welcher Stelle es passiert ist.")
                }
            }
            if regal.unlesbar > 0 {
                // Eine Reise, die sich nicht lesen lässt, wird gezählt und
                // nicht verschwiegen. Eine Liste, die stillschweigend kürzer
                // ist, sieht aus wie Datenverlust — und ohne die Zahl wüsste
                // niemand, ob sie einer ist.
                Section {
                    Label("\(regal.unlesbar) Datei(en) im Reisenordner ließen sich nicht lesen.",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            ForEach(regal.reisen) { reise in
                Button {
                    regal.oeffnen(reise)
                } label: {
                    ReiseZeile(reise: reise)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Löschen", role: .destructive) { zuLoeschen = reise }
                    Button("Duplizieren") { duplizieren(reise) }
                        .tint(.accentColor)
                    Button("Umbenennen") { umbenennen(reise) }
                        .tint(.gray)
                }
                // Daneben im Kontextmenü, und zwar bewusst zweimal: Eine
                // Wischgeste kennt, wer sie kennt. Beides ruft dieselbe
                // Stelle — zwei Wege zu einer Sache, nicht zwei Sachen.
                .contextMenu {
                    Button("Umbenennen", systemImage: "pencil") { umbenennen(reise) }
                    Button("Duplizieren", systemImage: "plus.square.on.square") {
                        duplizieren(reise)
                    }
                    Button(role: .destructive) {
                        zuLoeschen = reise
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
                .disabled(kopiertGerade)
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct ReiseZeile: View {
    let reise: Reise

    var body: some View {
        HStack(spacing: 14) {
            Vorschaubild(reise: reise)
            VStack(alignment: .leading, spacing: 3) {
                // DER NAME IN DER ÜBERSICHT, nicht der gedruckte Titel
                // (ab 1.0.84). Solange niemand etwas anderes eingetragen
                // hat, sind beide dasselbe.
                Text(reise.anzeigename)
                    .font(.headline)
                if !reise.zeitraum.isEmpty {
                    Text(reise.zeitraum)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(zusammenfassung)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            // Die Spalte nimmt die Breite, die übrig ist, statt sich einen
            // `Spacer` danebenzustellen: Eine `VStack` in einer `HStack`
            // bekäme sonst ihre IDEALBREITE, und die ist das Maß des
            // längsten Kindes — dieselbe Falle wie in der Abfahrtstafel.
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var zusammenfassung: String {
        var teile: [String] = []
        teile.append(reise.tage.count == 1 ? "1 Tag" : "\(reise.tage.count) Tage")
        teile.append(reise.fotos.count == 1 ? "1 Foto" : "\(reise.fotos.count) Fotos")
        teile.append("\(reise.seitenzahl) Seiten")
        return teile.joined(separator: " · ")
    }
}

private struct Vorschaubild: View {
    let reise: Reise

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(reise.gestaltung.papier.farbe)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
            // Das TITELFOTO zuerst — das ist das Bild, das auch auf dem
            // Titelblatt steht, und damit das Gesicht dieses Buches. Bis
            // 1.0.19 stand hier das erste Foto der Reise, also ein
            // beliebiges; zwei Bücher mit demselben Anreisetag sahen im
            // Regal gleich aus.
            if let datei = titelbild,
               let bild = Bildarchiv.shared.vorschau(datei, reise: reise.id, kante: 240)
            {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(.tertiary)
            }
        }
        // Hochkant wie ein Buchrücken im Regal, nicht quadratisch: Apple
        // Books und jede Bücher-App zeigen ein Buch als Buch.
        .frame(width: 52, height: 68)
        // BESCHNITTEN wird hier und nicht am Bild. `scaledToFill` füllt den
        // vorgeschlagenen Rahmen und wird in einer Richtung GRÖSSER als er:
        // ein Querformat-Titelfoto misst bei 68 Punkt Höhe gut 90 Punkt in
        // der Breite. Und `.frame` beschneidet nicht — es stellt ein zu
        // großes Kind mittig hinein, das dann links und rechts um je knapp
        // zwanzig Punkte übersteht. Genau darauf beginnt die Beschriftung
        // (gemeldet 09/2026). Ein `clipShape` am BILD half nicht: Es
        // beschneidet den Rahmen des Bildes, und der ist ja der zu große.
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }

    private var titelbild: String? {
        if let id = reise.titelfoto, let foto = reise.foto(id) { return foto.datei }
        return reise.fotos.first?.datei
    }
}


// MARK: - Eine neue Reise anlegen

// DIE VORLAGE GEHÖRT AN DEN ANFANG (ab 1.0.95).
//
// Ansage des Nutzers, 09/2026: „Wenn ich zum Beispiel jetzt ein
// Urlaubstagebuch erstellt habe, dann möchte ich für den nächsten Urlaub
// gerne dieselben Einstellungen haben." Genau hier entsteht der nächste
// Urlaub — sie erst im fertigen Buch anzuwenden hieße, das Buch zweimal zu
// setzen.
//
// **Vorbelegt, aber sichtbar.** Was als Vorgabe markiert ist, steht schon
// im Wähler; es steht aber DA, und man kann es wegnehmen. Eine App, die
// ein neues Buch still nach einer Vorlage anlegt, sieht für den Menschen
// davor aus wie eine App mit seltsamen Vorgaben (dieselbe Überlegung wie
// beim Deutschland-Ticket-Filter der Abfahrtstafel).
private struct NeueReiseBlatt: View {
    @Binding var titel: String
    let anlegen: (Vorlage?, Vorlage?) -> Void
    @Environment(\.dismiss) private var schliessen
    @State private var vorlagen: [Vorlage] = []
    @State private var aussehen: UUID?
    @State private var druckerei: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Titel", text: $titel)
                } header: {
                    Text("Wie soll das Buch heißen?")
                } footer: {
                    Text("Der Titel steht auf der Titelseite und lässt sich jederzeit ändern.")
                }

                if !vorlagen.isEmpty {
                    Section {
                        wahl("Aussehen", art: .aussehen, auswahl: $aussehen)
                        wahl("Druckerei", art: .druckerei, auswahl: $druckerei)
                    } header: {
                        Text("Mit Vorlage anfangen")
                    } footer: {
                        Text("Vorlagen sicherst du in einem offenen Buch unter "
                             + "\u{201E}Ganzes Buch\u{201C} \u{2192} \u{201E}Vorlagen\u{201C}. "
                             + "Hier gesetzt gelten sie von der ersten Seite an.")
                    }
                }

                Section {
                    Button("Anlegen") {
                        anlegen(vorlage(.aussehen, aussehen), vorlage(.druckerei, druckerei))
                        schliessen()
                    }
                }
            }
            .navigationTitle("Neue Reise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
            }
            .task {
                vorlagen = Vorlagenablage.alle()
                aussehen = Vorlagenablage.vorgabe(.aussehen)?.id
                druckerei = Vorlagenablage.vorgabe(.druckerei)?.id
            }
        }
    }

    @ViewBuilder
    private func wahl(_ titel: String, art: Vorlage.Art, auswahl: Binding<UUID?>) -> some View {
        let liste = vorlagen.filter { $0.art == art }
        if !liste.isEmpty {
            Picker(titel, selection: auswahl) {
                Text("Keine").tag(UUID?.none)
                ForEach(liste) { eintrag in
                    Text(eintrag.name).tag(UUID?.some(eintrag.id))
                }
            }
        }
    }

    private func vorlage(_ art: Vorlage.Art, _ id: UUID?) -> Vorlage? {
        guard let id else { return nil }
        return vorlagen.first { $0.id == id && $0.art == art }
    }
}
