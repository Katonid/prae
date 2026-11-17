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
    @State private var dateiwahl = false
    @State private var entfernenFragen = false
    @State private var hinweis: String?

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
            .navigationTitle("Vorwort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        let t = titel.trimmingCharacters(in: .whitespacesAndNewlines)
                        werk.vorwortSichern(titel: t.isEmpty ? "Vorwort" : t, text: text, fotos: fotos)
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
                }
            }
            .sheet(isPresented: $mediathek) {
                Fotowahl { treffer in
                    mediathek = false
                    Task { @MainActor in
                        var neu = 0
                        for eintrag in treffer {
                            guard let datei = await KapitelseitenView.ladeDatei(eintrag) else { continue }
                            if let id = werk.grafikAblegen(vonDatei: datei) {
                                fotos.append(id)
                                neu += 1
                            }
                            try? FileManager.default.removeItem(at: datei)
                        }
                        if neu < treffer.count { hinweis = "\(treffer.count - neu) Fotos ließen sich nicht laden." }
                    }
                }
                .ignoresSafeArea()
            }
            .fileImporter(isPresented: $dateiwahl, allowedContentTypes: [.image], allowsMultipleSelection: true) { ergebnis in
                guard case .success(let adressen) = ergebnis else { return }
                for adresse in adressen {
                    let offen = adresse.startAccessingSecurityScopedResource()
                    defer { if offen { adresse.stopAccessingSecurityScopedResource() } }
                    if let id = werk.grafikAblegen(vonDatei: adresse) { fotos.append(id) }
                }
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
}
