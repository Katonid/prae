import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// DAS VORWORT BEARBEITEN (Kapitelweise, ab 1.0.15).
//
// Ansage des Nutzers 11/2026: „einen einleitenden Text dem eigentlichen
// Chronikbuch voranstellen … persönliche Worte … mindestens 7 Seiten …
// einzelne Fotos beifügen … zweispaltig … dass der Text sie umfließt."
//
// Hier stehen Überschrift, Text und Fotos; gesetzt wird beim Sichern
// (`Reisewerk.vorwortSichern` → `Layoutautomat.vorwortseiten`). Der Text
// lässt sich aus der Zwischenablage holen — er ist meist schon woanders
// geschrieben —, und die Leerzeichenregeln der Textpflege lassen sich auf
// ihn anwenden.
struct VorwortView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    @State private var titel = "Vorwort"
    @State private var text = ""
    @State private var fotos: [UUID] = []
    @State private var geladen = false
    // Schließen sichert (ab 1.0.45, gemeldet 11/2026: „Manchmal gehen
    // Texte … verloren, wenn ich nach dem Eingeben das Fenster schließe").
    @State private var ausgang: String?
    @State private var erledigt = false
    @State private var verwerfenFragen = false
    @State private var mediathek = false
    @State private var auswahl: [PhotosPickerItem] = []
    @State private var laedt = false
    @State private var dateiwahl = false
    @State private var entfernenFragen = false
    @State private var hinweis: String?
    @State private var fotohinweis: String?
    // Die Schrift des Vorworts (ab 1.0.17). Gleich der des Buches heißt: wie
    // der Fließtext des Buches — dann folgt das Vorwort jeder späteren
    // Änderung an der Typografie.
    @State private var leerzeilenBehalten = false
    // Abstand Text–Foto (ab 1.0.26).
    @State private var fotoabstand = 6.0
    @State private var schriftwahlOffen = false
    @State private var schrift = Schriftbild()

    private var gibtEs: Bool { werk.reise.vorwortIndex != nil }

    /// Was sich ändern kann, als ein Vergleichswert.
    private var stand: String {
        titel + "\u{1F}" + text + "\u{1F}" + fotos.map(\.uuidString).joined(separator: ",")
            + "\u{1F}" + String(fotoabstand) + "\u{1F}" + String(leerzeilenBehalten)
    }

    private var geaendert: Bool {
        guard let ausgang else { return false }
        return ausgang != stand
            && !(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && fotos.isEmpty)
    }

    private func sichern() {
        erledigt = true
        let t = titel.trimmingCharacters(in: .whitespacesAndNewlines)
        let gesetzt = leerzeilenBehalten ? text : Self.ohneLeerzeilen(text)
        let buch = werk.automat.vorwortbild()
        werk.vorwortSichern(titel: t.isEmpty ? "Vorwort" : t, text: gesetzt, fotos: fotos,
                            schrift: schrift == buch ? nil : schrift,
                            abstand: fotoabstand)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Überschrift", text: $titel)
                        .font(.headline)
                } header: {
                    Text("Überschrift")
                }

                Section {
                    // Mit Formatleiste (ab 1.0.20): einzelne Wörter fett,
                    // kursiv, unterstrichen, größer, in anderer Schrift.
                    Formatfeld(text: $text, bild: schrift, schriften: werk.reise.buchschriften)
                        .frame(minHeight: 320)
                    Button {
                        if let s = UIPasteboard.general.string, !s.isEmpty {
                            text = text.isEmpty ? s : text + "\n\n" + s
                            hinweis = "Text aus der Zwischenablage angefügt."
                        } else {
                            hinweis = "In der Zwischenablage liegt kein Text."
                        }
                    } label: {
                        Label("Aus der Zwischenablage anfügen", systemImage: "doc.on.clipboard")
                    }
                    Button {
                        let vorher = text
                        text = Textpflege.aufraeumen(text)
                        hinweis = vorher == text ? "Nichts aufzuräumen." : "Leerzeichen und Satzzeichen aufgeräumt."
                    } label: {
                        Label("Leerzeichen und Satzzeichen aufräumen", systemImage: "text.badge.checkmark")
                    }
                    .disabled(text.isEmpty)
                    if let hinweis {
                        Text(hinweis).font(.caption).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Text")
                } footer: {
                    Text("\(text.count) Zeichen. Im Buch läuft der Text in zwei Spalten im Blocksatz; Absätze (eine Leerzeile) bleiben erhalten.")
                }

                schriftAbschnitt

                Section {
                    ForEach(fotos, id: \.self) { id in
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray5))
                                if let foto = werk.foto(id) {
                                    Ladebild(datei: foto.datei, reise: werk.reise.id, kante: 160) { bild in
                                        Image(uiImage: bild).resizable().scaledToFill()
                                    }
                                }
                            }
                            .frame(width: 64, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            Text("Foto \((fotos.firstIndex(of: id) ?? 0) + 1)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onMove { von, nach in fotos.move(fromOffsets: von, toOffset: nach) }
                    .onDelete { stellen in fotos.remove(atOffsets: stellen) }
                    if let fotohinweis {
                        Text(fotohinweis).font(.caption).foregroundStyle(.secondary)
                    }
                    if laedt {
                        HStack { ProgressView(); Text("Fotos werden geladen \u{2026}").foregroundStyle(.secondary) }
                    }
                    Menu {
                        Button("Aus der Mediathek", systemImage: "photo.on.rectangle") { mediathek = true }
                        Button("Aus Dateien", systemImage: "folder") { dateiwahl = true }
                    } label: {
                        Label("Fotos hinzufügen", systemImage: "photo.badge.plus")
                    }
                } header: {
                    HStack {
                        Text("Fotos (\(fotos.count))")
                        Spacer()
                        EditButton().font(.caption)
                    }
                } footer: {
                    Text("Der Aufnahmezeit nach geordnet und in dieser Reihenfolge über die Seiten des Vorworts verteilt, je in einer Spalte oben oder unten, im Wechsel rechts und links \u{2014} der Text fließt darum herum. Sie gehören zu keinem Kapitel." + (ohneZeit > 0 ? " \(ohneZeit) Fotos tragen keine Aufnahmezeit und stehen am Ende." : ""))
                }

                if gibtEs {
                    Section {
                        Button("Vorwort entfernen", role: .destructive) { entfernenFragen = true }
                    }
                }
            }
            .sheet(isPresented: $schriftwahlOffen) {
                NavigationStack {
                    // Direkt gebunden: Jede Wahl gilt sofort, auch wenn das
                    // Blatt anders als über „Fertig" zugeht (Wischen).
                    SchriftwahlView(auswahl: $schrift.familie, titel: "Schrift des Vorworts")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Fertig") { schriftwahlOffen = false }
                            }
                        }
                }
                .onAppear { Absturzspur.endetSpaeter() }
            }
            .navigationTitle("Vorwort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        if geaendert {
                            verwerfenFragen = true
                        } else {
                            erledigt = true
                            schliessen()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        sichern()
                        schliessen()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && fotos.isEmpty)
                }
            }
            .onDisappear {
                if !erledigt, geaendert { sichern() }
            }
            .confirmationDialog("Änderungen verwerfen?", isPresented: $verwerfenFragen, titleVisibility: .visible) {
                Button("Sichern") { sichern(); schliessen() }
                Button("Verwerfen", role: .destructive) { erledigt = true; schliessen() }
                Button("Weiter schreiben", role: .cancel) {}
            } message: {
                Text("Das Vorwort ist noch nicht gesichert.")
            }
            .onAppear {
                guard !geladen else { return }
                geladen = true
                defer { ausgang = stand }
                if let i = werk.reise.vorwortIndex {
                    let tag = werk.reise.tage[i]
                    titel = tag.ueberschrift.isEmpty ? "Vorwort" : tag.ueberschrift
                    text = tag.text
                    fotos = tag.fotos
                    fotoabstand = tag.vorwortabstand ?? 6
                    // Fotos aus 1.0.15–1.0.18 tragen keine Aufnahmezeit:
                    // einmal aus der abgelegten Datei nachlesen.
                    for id in fotos {
                        guard var foto = werk.foto(id), foto.aufnahme == nil, foto.grafik else { continue }
                        let adresse = Bildarchiv.shared.pfad(werk.reise.id, datei: foto.datei)
                        if let zeit = Bildleser.befund(datei: adresse).aufnahme {
                            foto.aufnahme = zeit
                            werk.reise.setzeFoto(foto)
                        }
                    }
                    zeitlichOrdnen()
                    schrift = werk.automat.vorwortbild(tag)
                } else {
                    schrift = werk.automat.vorwortbild()
                }
            }
            // DER FOTOWÄHLER VON SWIFTUI (ab 1.0.17). Gemeldet 11/2026:
            // „Fotos, die ich auswähle, werden leider nicht ins Vorwort
            // eingefügt." Bis dahin lief hier `Fotowahl` in einem Blatt: Der
            // UIKit-Wähler schließt sich selbst (`picker.dismiss`), und das
            // Blatt wurde zusätzlich über `mediathek = false` geschlossen.
            // In einem Blatt IM Blatt (das Vorwort ist selbst eines) kann der
            // zweite Schließbefehl das Vorwort-Blatt treffen — mit ihm
            // verschwindet die Fotoliste, bevor die Fotos geladen sind.
            // `photosPicker` schließt SwiftUI selbst, genau einmal.
            .photosPicker(isPresented: $mediathek, selection: $auswahl,
                          maxSelectionCount: nil, matching: .images,
                          preferredItemEncoding: .current)
            .onChange(of: auswahl) { _, neu in
                guard !neu.isEmpty else { return }
                auswahl = []
                Task { @MainActor in await fotosLaden(neu) }
            }
            .fileImporter(isPresented: $dateiwahl, allowedContentTypes: [.image], allowsMultipleSelection: true) { ergebnis in
                guard case .success(let adressen) = ergebnis else { return }
                for adresse in adressen {
                    let offen = adresse.startAccessingSecurityScopedResource()
                    defer { if offen { adresse.stopAccessingSecurityScopedResource() } }
                    if let id = werk.grafikAblegen(vonDatei: adresse) { fotos.append(id) }
                }
                zeitlichOrdnen()
                fotohinweis = "Mit \u{201E}Sichern\u{201C} kommen die Fotos ins Vorwort."
            }
            .confirmationDialog("Vorwort entfernen?", isPresented: $entfernenFragen, titleVisibility: .visible) {
                Button("Entfernen", role: .destructive) {
                    werk.vorwortEntfernen()
                    schliessen()
                }
            } message: {
                Text("Die Seiten des Vorworts verschwinden aus dem Buch. \u{201E}Widerrufen\u{201C} holt sie zurück.")
            }
        }
    }

    // MARK: Schrift

    // Schrift und Absätze (ab 1.0.17, Ansage des Nutzers 11/2026: „Ich
    // möchte auch Schriftfarbe und Absatzformatierungen vornehmen können.
    // Konkret wird im Vorwort nach jedem Absatz eine Reihenhöhe Abstand
    // gehalten. Das möchte ich nicht."). Immer sichtbar, ohne Schalter
    // davor: Gilt beim Sichern genau die Schrift des Buches, wird `nil`
    // gesichert — dann folgt das Vorwort späteren Änderungen an der
    // Typografie.
    private var schriftAbschnitt: some View {
        Group {
            Section {
                // ALS EIGENES BLATT (ab 1.0.18, gemeldet 11/2026: „Die App
                // stürzt ab, wenn ich eine andere Schriftart für das Vorwort
                // wählen möchte."). Bis 1.0.17 ein `NavigationLink` im Stapel
                // des Vorwort-Blatts, gebunden direkt an `schrift` — jede
                // Wahl zeichnete das ganze Blatt samt Textfeld mit dem
                // langen Vorworttext neu. Jetzt wie im Inspektor: eigenes
                // Blatt, eigener Stapel. Die eigentliche Ursache war wohl der
                // doppelt geschlossene Wähler von iOS (siehe `Schriftwahl` in
                // `Waehler.swift`, behoben 1.0.19).
                Button {
                    Absturzspur.beginnt("Vorwort: Schriftwahl \u{00F6}ffnen (jetzt \(schrift.familie.vollerName))")
                    schriftwahlOffen = true
                } label: {
                    LabeledContent("Schriftart", value: schrift.familie.vollerName)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(.primary)
                Stepper(value: $schrift.groesse, in: 7...24, step: 0.5) {
                    LabeledContent("Größe", value: String(format: "%.1f pt", schrift.groesse))
                }
                ColorPicker("Schriftfarbe", selection: Binding(
                    get: { schrift.farbe.farbe },
                    set: { schrift.farbe = Farbwert($0) }
                ), supportsOpacity: false)
                Toggle("Fett", isOn: $schrift.fett)
                Toggle("Kursiv", isOn: $schrift.kursiv)
                if schrift != werk.automat.vorwortbild() {
                    Button("Wie der Fließtext des Buches") { schrift = werk.automat.vorwortbild() }
                }
            } header: {
                Text("Schrift")
            }

            Section {
                Picker("Ausrichtung", selection: $schrift.ausrichtung) {
                    ForEach(Ausrichtung.allCases) { art in
                        Label(art.name, systemImage: art.symbol).tag(art)
                    }
                }
                .pickerStyle(.menu)
                VStack(alignment: .leading) {
                    LabeledContent("Zeilenabstand", value: String(format: "%.2f", schrift.zeilenabstand))
                    Slider(value: $schrift.zeilenabstand, in: 0.5...2.6, step: 0.01)
                }
                VStack(alignment: .leading) {
                    LabeledContent("Abstand nach jedem Absatz", value: String(format: "%.0f pt", schrift.absatzabstand))
                    Slider(value: $schrift.absatzabstand, in: 0...24, step: 1)
                }
                Toggle("Leerzeilen zwischen Absätzen behalten", isOn: $leerzeilenBehalten)
                VStack(alignment: .leading) {
                    LabeledContent("Abstand Text \u{2013} Foto", value: String(format: "%.0f pt (%.1f mm)", fotoabstand, fotoabstand * 25.4 / 72))
                    Slider(value: $fotoabstand, in: 0...24, step: 1)
                }
                Toggle("Silben trennen", isOn: $schrift.trennung)
                // Eine Probe in der gewählten Schrift — in der Größe, die
                // gedruckt wird, damit 12 pt hier auch nach 12 pt aussehen.
                Text(probe)
                    .font(Font(schrift.uiFont))
                    .foregroundStyle(schrift.farbe.farbe)
                    .lineSpacing(CGFloat(schrift.groesse * (schrift.zeilenabstand - 1)))
                    .multilineTextAlignment(schrift.ausrichtung.swiftUIWert)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } header: {
                Text("Absätze")
            } footer: {
                Text("Eine leere Zeile zwischen zwei Absätzen steht im Buch als ganze Zeile Abstand. Ohne Haken werden solche Leerzeilen beim Sichern entfernt; den Abstand bestimmt dann allein \u{201E}Abstand nach jedem Absatz\u{201C} (0 pt: gar keiner). Beim Sichern fließt der Text neu, die Fotos bleiben, wo sie stehen.")
            }
        }
    }

    /// Leerzeilen zwischen Absätzen zu EINEM Zeilenwechsel. Ein Absatz ist im
    /// Satz ein Zeilenwechsel (`Textmass.absatzgrenze`); eine leere Zeile
    /// dazwischen ist ein zusätzlicher, leerer Absatz — eine Zeilenhöhe plus
    /// zweimal der Absatzabstand.
    static func ohneLeerzeilen(_ text: String) -> String {
        text.replacingOccurrences(of: "\n[ \t\u{00A0}]*(\n[ \t\u{00A0}]*)+", with: "\n",
                                  options: .regularExpression)
    }

    private var probe: String {
        let anfang = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !anfang.isEmpty else { return "Dieses Buch erzählt von den ersten Jahren \u{2014} Kapitel für Kapitel, Foto für Foto." }
        return String(anfang.prefix(220)) + (anfang.count > 220 ? "\u{2026}" : "")
    }


    // MARK: Fotos laden

    /// Lädt die gewählten Fotos als Datei, legt sie im Buch ab und hängt sie
    /// an die Liste. Die Datei wird in voller Güte genommen (`.current`).
    private func fotosLaden(_ treffer: [PhotosPickerItem]) async {
        laedt = true
        defer { laedt = false }
        var neu = 0
        for eintrag in treffer {
            guard let daten = try? await eintrag.loadTransferable(type: Data.self) else { continue }
            let endung = eintrag.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
            let datei = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "." + endung)
            guard (try? daten.write(to: datei)) != nil else { continue }
            if let id = werk.grafikAblegen(vonDatei: datei) {
                fotos.append(id)
                neu += 1
            }
            try? FileManager.default.removeItem(at: datei)
        }
        zeitlichOrdnen()
        if neu < treffer.count {
            fotohinweis = "\(treffer.count - neu) von \(treffer.count) Fotos ließen sich nicht laden."
        } else {
            fotohinweis = "\(neu) Fotos hinzugefügt. Mit \u{201E}Sichern\u{201C} kommen sie ins Vorwort."
        }
    }


    /// Die Fotos der Aufnahmezeit nach (ab 1.0.19, Wunsch des Nutzers
    /// 11/2026: „dass die eingefügten Fotos im Vorwort in chronologischer
    /// Reihenfolge erscheinen"). Fotos ohne Zeit bleiben in ihrer Folge am
    /// Ende; bei gleicher Zeit bleibt die gewählte Folge.
    private func zeitlichOrdnen() {
        var stelle: [UUID: Int] = [:]
        for (i, id) in fotos.enumerated() where stelle[id] == nil { stelle[id] = i }
        let zeit: (UUID) -> Date? = { werk.foto($0)?.aufnahme }
        fotos.sort { a, b in
            switch (zeit(a), zeit(b)) {
            case let (x?, y?) where x != y: return x < y
            case (.some, nil): return true
            case (nil, .some): return false
            default: return (stelle[a] ?? 0) < (stelle[b] ?? 0)
            }
        }
    }

    private var ohneZeit: Int {
        fotos.filter { werk.foto($0)?.aufnahme == nil }.count
    }

}
