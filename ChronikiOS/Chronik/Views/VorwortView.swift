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
    @State private var mediathek = false
    @State private var auswahl: [PhotosPickerItem] = []
    @State private var laedt = false
    @State private var dateiwahl = false
    @State private var entfernenFragen = false
    @State private var hinweis: String?
    @State private var fotohinweis: String?
    // Die Schrift des Vorworts (ab 1.0.17). `eigeneSchrift` aus heißt: wie
    // der Fließtext des Buches — dann folgt das Vorwort jeder späteren
    // Änderung an der Typografie.
    @State private var eigeneSchrift = false
    @State private var schrift = Schriftbild()

    private var gibtEs: Bool { werk.reise.vorwortIndex != nil }

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
                    TextEditor(text: $text)
                        .frame(minHeight: 320)
                        .font(.system(size: 15))
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
                                if let foto = werk.reise.foto(id) {
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
                    Text("Die Fotos verteilen sich in dieser Reihenfolge gleichmäßig über die Seiten des Vorworts, je in einer Spalte oben oder unten, im Wechsel rechts und links \u{2014} der Text fließt darum herum. Sie gehören zu keinem Kapitel.")
                }

                if gibtEs {
                    Section {
                        Button("Vorwort entfernen", role: .destructive) { entfernenFragen = true }
                    }
                }
            }
            .onChange(of: eigeneSchrift) { _, an in
                // Zurück auf „wie das Buch": Die Werte zeigen wieder, was
                // dann gilt.
                if !an { schrift = werk.automat.vorwortbild() }
            }
            .navigationTitle("Vorwort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        let t = titel.trimmingCharacters(in: .whitespacesAndNewlines)
                        werk.vorwortSichern(titel: t.isEmpty ? "Vorwort" : t, text: text, fotos: fotos,
                                            schrift: eigeneSchrift ? schrift : nil)
                        schliessen()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && fotos.isEmpty)
                }
            }
            .onAppear {
                guard !geladen else { return }
                geladen = true
                if let i = werk.reise.vorwortIndex {
                    let tag = werk.reise.tage[i]
                    titel = tag.ueberschrift.isEmpty ? "Vorwort" : tag.ueberschrift
                    text = tag.text
                    fotos = tag.fotos
                    eigeneSchrift = tag.vorwortschrift != nil
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

    private var schriftAbschnitt: some View {
        Section {
            Toggle("Eigene Schrift für das Vorwort", isOn: $eigeneSchrift)
            if eigeneSchrift {
                NavigationLink {
                    SchriftwahlView(auswahl: $schrift.familie, titel: "Vorwort")
                } label: {
                    LabeledContent("Schriftart", value: schrift.familie.vollerName)
                }
                Stepper(value: $schrift.groesse, in: 7...24, step: 0.5) {
                    LabeledContent("Größe", value: String(format: "%.1f pt", schrift.groesse))
                }
                VStack(alignment: .leading) {
                    LabeledContent("Zeilenabstand", value: String(format: "%.2f", schrift.zeilenabstand))
                    Slider(value: $schrift.zeilenabstand, in: 1.0...2.2)
                }
                VStack(alignment: .leading) {
                    LabeledContent("Abstand nach Absätzen", value: String(format: "%.0f pt", schrift.absatzabstand))
                    Slider(value: $schrift.absatzabstand, in: 0...24, step: 1)
                }
                Picker("Ausrichtung", selection: $schrift.ausrichtung) {
                    ForEach(Ausrichtung.allCases) { art in
                        Label(art.name, systemImage: art.symbol).tag(art)
                    }
                }
                .pickerStyle(.menu)
                Toggle("Kursiv", isOn: $schrift.kursiv)
                Toggle("Silben trennen", isOn: $schrift.trennung)
                ColorPicker("Farbe", selection: Binding(
                    get: { schrift.farbe.farbe },
                    set: { schrift.farbe = Farbwert($0) }
                ), supportsOpacity: false)
            }
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
            Text("Schrift")
        } footer: {
            Text(eigeneSchrift
                 ? "Gilt nur für den Text des Vorworts. Beim Sichern fließt er neu; Fotos bleiben, wo sie stehen."
                 : "Wie der Fließtext des Buches, gerade, im Blocksatz mit Silbentrennung.")
        }
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
        if neu < treffer.count {
            fotohinweis = "\(treffer.count - neu) von \(treffer.count) Fotos ließen sich nicht laden."
        } else {
            fotohinweis = "\(neu) Fotos hinzugefügt. Mit \u{201E}Sichern\u{201C} kommen sie ins Vorwort."
        }
    }

}
