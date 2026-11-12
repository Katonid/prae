import SwiftUI
import UIKit

// KAPITELWEISE: TEXTE MIT ZEITSTEMPEL.
//
// Die Liste aller Texte nach Kapiteln und der Editor für einen Text. Der
// Zeitstempel ist frei einstellbar und entscheidet über das Kapitel; der
// Text lässt sich sprachlich überarbeiten (`Sprachhilfe`) — als Vorschlag,
// der erst mit „Übernehmen" gilt, und die vorige Fassung bleibt.

struct TexteView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen
    @State private var bearbeiten: Texteintrag?

    var body: some View {
        NavigationStack {
            List {
                if werk.reise.eintraege.isEmpty {
                    Section {
                        Text("Noch keine Texte. Jeder Text trägt einen Zeitpunkt; danach kommt er in sein Kapitel (Grundeinstellung: ein Kapitel je Kalenderjahr).")
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(werk.reise.tage) { kapitel in
                    let liste = werk.reise.kapiteleintraege(kapitel.datum)
                    if !liste.isEmpty {
                        Section(kapitel.ueberschrift.isEmpty ? kapitel.datum.mittel : kapitel.ueberschrift) {
                            ForEach(liste) { eintrag in
                                Button { bearbeiten = eintrag } label: { TexteintragZeile(eintrag: eintrag) }
                                    .buttonStyle(.plain)
                                    .swipeActions {
                                        Button("Löschen", role: .destructive) { werk.eintragLoeschen(eintrag.id) }
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Texte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { schliessen() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        bearbeiten = EintragView.neuerEintrag(werk)
                    } label: {
                        Label("Neuer Text", systemImage: "square.and.pencil")
                    }
                }
            }
            .sheet(item: $bearbeiten) { eintrag in
                EintragView(werk: werk, eintrag: eintrag)
            }
        }
    }
}

struct TexteintragZeile: View {
    let eintrag: Texteintrag

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(eintrag.titel.isEmpty ? "Ohne Überschrift" : eintrag.titel)
                .font(.headline)
                .foregroundStyle(eintrag.titel.isEmpty ? .secondary : .primary)
            Text(Zeitraster.text(eintrag.zeit, "EEEE, d. MMMM yyyy · HH:mm"))
                .font(.caption)
                .foregroundStyle(.secondary)
            if !eintrag.text.isEmpty {
                Text(eintrag.text).font(.callout).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct EintragView: View {
    @ObservedObject var werk: Reisewerk
    @State var eintrag: Texteintrag
    @Environment(\.dismiss) private var schliessen
    @State private var ueberarbeiten = false
    @State private var loeschenFragen = false
    // Diktieren wie in Fernweh (ab 1.0.3): Knopf unten rechts im Textfeld,
    // was gerade gehört wird, steht darunter; fester Text wird angehängt.
    @StateObject private var diktat = Diktat()

    /// Ein neuer Eintrag beginnt im gewählten Kapitel — ein Buch über 2009
    /// soll seinen nächsten Text nicht auf heute datieren.
    static func neuerEintrag(_ werk: Reisewerk) -> Texteintrag {
        var neu = Texteintrag()
        if let tag = werk.tag {
            let k = werk.reise.kapitel(tag.datum)
            let heute = Date()
            let ende = Zeitraster.kalender.date(byAdding: .day, value: -1,
                                                to: werk.reise.zeitraster.kapitelbeginn(k.index + 1)) ?? heute
            neu.zeit = (heute >= k.beginn && heute <= ende) ? heute : tag.datum.mittag
        }
        return neu
    }

    private var diktatKnopf: some View {
        Button {
            Task { await diktat.umschalten(hinweise: diktatHinweise) }
        } label: {
            Group {
                if diktat.bereitet {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: diktat.laeuft ? "stop.fill" : "mic.fill")
                        .font(.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(diktat.laeuft ? AnyShapeStyle(Color.red.gradient) : AnyShapeStyle(Color.accentColor.gradient),
                        in: Circle())
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(diktat.laeuft ? "Diktat beenden" : "Diktieren")
    }

    /// Wörter, die die Erkennung erwarten soll: Buchtitel, Kapitel- und
    /// Textüberschriften — dort stehen die Namen, die in diesem Buch
    /// vorkommen.
    private var diktatHinweise: [String] {
        var liste = [werk.reise.titel, eintrag.titel]
        liste += werk.reise.tage.flatMap { [$0.ueberschrift, $0.unterueberschrift] }
        liste += werk.reise.eintraege.map(\.titel)
        return liste.flatMap { $0.components(separatedBy: CharacterSet(charactersIn: "\u{2013}\u{00B7},")) }
    }

    private var istNeu: Bool { !werk.reise.eintraege.contains { $0.id == eintrag.id } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Überschrift (freiwillig)", text: $eintrag.titel)
                        .font(.headline)
                    DatePicker("Zeitpunkt", selection: $eintrag.zeit, displayedComponents: [.date, .hourAndMinute])
                } footer: {
                    let k = werk.reise.kapitel(eintrag.tagesdatum)
                    Text("Kommt in das Kapitel \u{201E}\(k.standardTitel)\u{201C} (\(k.zeitraum)).")
                }

                Section {
                    TextEditor(text: $eintrag.text)
                        .frame(minHeight: 260)
                        .font(.system(size: 15))
                        .padding(.bottom, 44)
                        .overlay(alignment: .bottomTrailing) { diktatKnopf.padding(.bottom, 4) }
                    if diktat.laeuft || !diktat.zwischentext.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(Color.red).frame(width: 8, height: 8).padding(.top, 5)
                            Text(diktat.zwischentext.isEmpty ? "Ich höre zu \u{2026}" : diktat.zwischentext)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                    }
                } header: {
                    Text("Text")
                } footer: {
                    if let fehler = diktat.fehler {
                        Text(fehler).foregroundStyle(.red)
                    } else if diktat.laeuft {
                        Text(diktat.motor + " \u{00B7} Namen aus dem Buch sind als Hinweise hinterlegt")
                    } else {
                        Text("Mit dem Mikrofon-Knopf diktieren; der erkannte Text wird angehängt.")
                    }
                }

                Section {
                    Button {
                        ueberarbeiten = true
                    } label: {
                        Label("Sprachlich überarbeiten \u{2026}", systemImage: "wand.and.stars")
                    }
                    .disabled(eintrag.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let alt = eintrag.vorfassung {
                        Button {
                            let jetzt = eintrag.text
                            eintrag.text = alt
                            eintrag.vorfassung = jetzt
                        } label: {
                            Label("Zur anderen Fassung wechseln", systemImage: "arrow.uturn.backward")
                        }
                    }
                } header: {
                    Text("Sprache")
                } footer: {
                    Text("Die Überarbeitung schlägt eine neue Fassung vor; übernommen wird erst auf Wunsch, und die vorige bleibt erhalten. Ab iOS 18.1 gibt es außerdem Apples Schreibtools: Text markieren \u{2192} \u{201E}Schreibtools\u{201C}.")
                }

                if !istNeu {
                    Section {
                        Button("Text löschen", role: .destructive) { loeschenFragen = true }
                    }
                }
            }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
                diktat.anhaengen = { neu in
                    let trenner = eintrag.text.isEmpty || eintrag.text.hasSuffix(" ") || eintrag.text.hasSuffix("\n") ? "" : " "
                    eintrag.text += trenner + neu
                }
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
                Task { await diktat.stoppen() }
            }
            .navigationTitle(istNeu ? "Neuer Text" : "Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        Task { @MainActor in
                            // Was noch im Diktat steckt, gehört zum Text.
                            await diktat.stoppen()
                            werk.eintragSichern(eintrag)
                            schliessen()
                        }
                    }
                    .disabled(eintrag.titel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              && eintrag.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $ueberarbeiten) {
                UeberarbeitenView(text: eintrag.text) { neu in
                    eintrag.vorfassung = eintrag.text
                    eintrag.text = neu
                }
            }
            .confirmationDialog("Diesen Text löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    werk.eintragLoeschen(eintrag.id)
                    schliessen()
                }
            }
        }
    }
}

struct UeberarbeitenView: View {
    let text: String
    var uebernehmen: (String) -> Void

    @Environment(\.dismiss) private var schliessen
    @State private var art: Sprachhilfe.Art = .glaetten
    @State private var vorschlag = ""
    @State private var laeuft = false
    @State private var fehler: String?
    @State private var kopiert = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Art", selection: $art) {
                        ForEach(Sprachhilfe.Art.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Art der Überarbeitung")
                } footer: {
                    Text(art.beschreibung)
                }

                if Sprachhilfe.aufDemGeraet {
                    Section {
                        Button {
                            starten()
                        } label: {
                            HStack {
                                Label("Auf dem Gerät überarbeiten", systemImage: "wand.and.stars")
                                if laeuft {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(laeuft)
                    } footer: {
                        Text("Mit Apple Intelligence auf diesem Gerät \u{2014} der Text verlässt es nicht.")
                    }
                } else if let grund = Sprachhilfe.grundOhneGeraet {
                    Section {
                        Text(grund).font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        UIPasteboard.general.string = Sprachhilfe.auftrag(text, art: art)
                        kopiert = true
                    } label: {
                        Label(kopiert ? "Auftrag kopiert" : "Auftrag für einen KI-Chat kopieren", systemImage: "doc.on.doc")
                    }
                    Button {
                        if let s = UIPasteboard.general.string { vorschlag = Sprachhilfe.bereinigen(s) }
                    } label: {
                        Label("Antwort aus der Zwischenablage einsetzen", systemImage: "doc.on.clipboard")
                    }
                } header: {
                    Text("Über einen KI-Chat")
                } footer: {
                    Text("Kopiert Anweisung und Text. In einer KI-App (z. B. ChatGPT oder Claude) einfügen, die Antwort kopieren und hier einsetzen.")
                }

                if let fehler {
                    Section { Text(fehler).foregroundStyle(.red) }
                }

                Section("Vorschlag") {
                    TextEditor(text: $vorschlag)
                        .frame(minHeight: 200)
                }

                Section("Bisher") {
                    Text(text)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("Überarbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        uebernehmen(vorschlag.trimmingCharacters(in: .whitespacesAndNewlines))
                        schliessen()
                    }
                    .disabled(vorschlag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vorschlag == text)
                }
            }
        }
    }

    private func starten() {
        laeuft = true
        fehler = nil
        let t = text
        let a = art
        Task { @MainActor in
            do {
                vorschlag = try await Sprachhilfe.ueberarbeiten(t, art: a)
            } catch {
                fehler = "Die Überarbeitung ist fehlgeschlagen: \(error.localizedDescription)"
            }
            laeuft = false
        }
    }
}

// KAPITEL UND ZEITRASTER.
//
// Eingestellt wird hier in einer Kopie; erst „Kapitel neu einteilen" gilt.
// Jede Stellung des Steppers sofort umzusetzen hieße, das ganze Buch bei
// jedem Antippen neu zu setzen.
struct KapitelrasterView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen
    @State private var raster = Zeitraster()
    @State private var person = ""
    @State private var geladen = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Ein Kapitel je", selection: Binding(
                        get: { raster.vorgabe },
                        set: { raster.anwenden($0) }
                    )) {
                        ForEach(Zeitraster.Vorgabe.allCases) { Text($0.name).tag($0) }
                    }
                    if raster.vorgabe == .lebensjahr {
                        TextField("Name, z. B. Simon", text: $person)
                        DatePicker("Geboren am", selection: $raster.beginn, displayedComponents: .date)
                    }
                    if raster.vorgabe == .eigene {
                        Stepper("Länge: \(raster.anzahl) \(raster.einheit.name(raster.anzahl))",
                                value: $raster.anzahl, in: 1...100)
                        Picker("Einheit", selection: $raster.einheit) {
                            ForEach(Zeitraster.Einheit.allCases) { Text($0.name(2)).tag($0) }
                        }
                        DatePicker("Ein Kapitel beginnt am", selection: $raster.beginn, displayedComponents: .date)
                    }
                } header: {
                    Text("Zeitraster")
                } footer: {
                    Text(raster.vorgabe == .lebensjahr
                         ? "Jedes Kapitel ist ein Lebensjahr, von Geburtstag zu Geburtstag. Es heißt nach dem Jahr (\u{201E}2019\u{201C}), darunter steht \u{201E}\(person.isEmpty ? "Du wirst" : person + " wird") 10 Jahre alt\u{201C} und als Datum der Geburtstag."
                         : "Fotos kommen nach ihrem Aufnahmetag in ein Kapitel, Texte nach ihrem Zeitstempel. Grundeinstellung: ein Kapitel je Kalenderjahr.")
                }

                Section("Vorschau") {
                    let kapitel = vorschau
                    if kapitel.isEmpty {
                        Text("Noch keine Fotos oder Texte.").foregroundStyle(.secondary)
                    }
                    ForEach(kapitel, id: \.titel) { k in
                        LabeledContent(k.titel, value: k.inhalt)
                    }
                }

                Section {
                    Button {
                        werk.reise.person = person.trimmingCharacters(in: .whitespacesAndNewlines)
                        werk.rasterSetzen(raster)
                        schliessen()
                    } label: {
                        Label("Kapitel neu einteilen", systemImage: "rectangle.split.3x1")
                    }
                    .disabled(raster == werk.reise.zeitraster && person == werk.reise.person)
                } footer: {
                    Text("Danach werden alle Kapitel neu gesetzt. Was auf den Seiten von Hand verschoben wurde, gilt dann nicht mehr \u{2014} \u{201E}Widerrufen\u{201C} holt den vorigen Stand zurück.")
                }
            }
            .navigationTitle("Kapitel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { schliessen() }
                }
            }
            .onAppear {
                if !geladen {
                    raster = werk.reise.zeitraster
                    person = werk.reise.person
                    geladen = true
                }
            }
        }
    }

    private struct Vorschau {
        let titel: String
        let inhalt: String
    }

    private var vorschau: [Vorschau] {
        var probe = werk.reise
        probe.zeitraster = raster
        var zaehler: [Tagesdatum: (fotos: Int, texte: Int)] = [:]
        let index = probe.fotoIndex
        for tag in probe.tage {
            for id in tag.fotos {
                let datum = index[id]?.tagesschluessel.flatMap { Tagesdatum(schluessel: $0) } ?? tag.datum
                zaehler[probe.kapitelbeginn(datum), default: (0, 0)].fotos += 1
            }
        }
        for e in probe.eintraege {
            zaehler[probe.kapitelbeginn(e.tagesdatum), default: (0, 0)].texte += 1
        }
        return zaehler.keys.sorted().map { beginn in
            let z = zaehler[beginn] ?? (0, 0)
            return Vorschau(titel: probe.kapitel(beginn).standardTitel,
                            inhalt: "\(z.fotos) Fotos · \(z.texte) Texte")
        }
    }
}
