import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// Das Wasserzeichen des Buches — einmal festgelegt, auf jeder Seite.
//
// Ansage des Nutzers, 09/2026: ein Ahornblatt, halbdurchsichtig, möglichst
// dort, wo sonst nichts steht. Was hier eingestellt wird, gilt für das
// ganze Buch; die Seite selbst kann nichts davon abweichen — genau das ist
// der Sinn eines Wasserzeichens.
struct WasserzeichenView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen
    @State private var dateiwahl = false

    private var zeichen: Wasserzeichen? { werk.reise.gestaltung.wasserzeichen }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    probe
                        .frame(height: 190)
                        .listRowInsets(EdgeInsets())
                } footer: {
                    Text(zeichen == nil
                         ? "Noch kein Bild gewählt."
                         : "So liegt es auf einer Seite mit Text und einem Foto. Wo genau, entscheidet sich auf jeder Seite neu.")
                }

                Section {
                    Button {
                        dateiwahl = true
                    } label: {
                        Label(zeichen == nil ? "Bilddatei wählen…" : "Andere Bilddatei wählen…",
                              systemImage: "photo.badge.plus")
                    }
                    if zeichen != nil {
                        Button(role: .destructive) {
                            entfernen()
                        } label: {
                            Label("Wasserzeichen entfernen", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("Bild")
                } footer: {
                    Text(bildhinweis)
                }

                if let zeichen {
                    Section {
                        VStack(alignment: .leading) {
                            LabeledContent("Sichtbarkeit",
                                           value: String(format: "%.0f %%", zeichen.deckung * 100))
                            Slider(value: binden(\.deckung), in: 0.02 ... 0.4)
                        }
                        VStack(alignment: .leading) {
                            LabeledContent("Größe",
                                           value: String(format: "%.0f %%", zeichen.anteil * 100))
                            Slider(value: binden(\.anteil), in: 0.08 ... 1.0)
                        }
                    } header: {
                        Text("Wie stark")
                    } footer: {
                        Text("Die Größe ist ein Anteil der Satzbreite — beim Wechsel von A4 auf A5 bleibt das Verhältnis damit stehen. Auf dem Bildschirm wirkt ein Wasserzeichen kräftiger als im Druck.")
                    }

                    Section {
                        Picker("Lage", selection: binden(\.lage)) {
                            ForEach(Wasserzeichen.Lage.allCases) { lage in
                                Text(lage.name).tag(lage)
                            }
                        }
                        Toggle("Auch auf dem Titelblatt", isOn: binden(\.aufTitelblatt))
                    } header: {
                        Text("Wo")
                    } footer: {
                        Text(lagenhinweis)
                    }

                    Section {
                        Toggle("Gedreht", isOn: Binding(
                            get: { zeichen.drehspanne > 0.01 },
                            set: { an in aendern { $0.drehspanne = an ? 12 : 0 } }
                        ))
                        if zeichen.drehspanne > 0.01 {
                            VStack(alignment: .leading) {
                                LabeledContent("Höchstens",
                                               value: gradtext(zeichen.drehspanne))
                                Slider(value: binden(\.drehspanne),
                                       in: 1 ... Wasserzeichen.groessteDrehung, step: 1)
                            }
                        }
                    } header: {
                        Text("Schräg")
                    } footer: {
                        Text(drehhinweis)
                    }
                }
            }
            .navigationTitle("Wasserzeichen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
            .sheet(isPresented: $dateiwahl) {
                Dateiwahl(typen: [.image]) { adressen in
                    dateiwahl = false
                    if let erste = adressen.first { uebernehmen(erste) }
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Texte

    // Ehrlich statt bequem: Die Mediathek ist bewusst NICHT der Weg.
    private var bildhinweis: String {
        var text = "Am besten ein PNG mit durchsichtigem Grund — eine Silhouette, kein Foto. "
        text += "Ein JPEG hat immer einen Grund, und der legt sich als helles Rechteck über die Seite. "
        text += "Deshalb führt dieser Weg in die Dateien und nicht in die Fotos: "
        text += "Die Mediathek gibt fast nur JPEG und HEIC heraus, und beide können keine Durchsichtigkeit."
        return text
    }

    private func gradtext(_ grad: Double) -> String {
        let zahl = String(format: "%.0f", grad)
        return "\u{00B1}\(zahl)\u{00B0}"
    }

    private var drehhinweis: String {
        guard let zeichen, zeichen.drehspanne > 0.01 else {
            return "Aus heißt: Das Bild steht genau so da, wie es in der Datei liegt."
        }
        var text = "Jede Seite bekommt einen eigenen Winkel zwischen "
        text += gradtext(zeichen.drehspanne).replacingOccurrences(of: "\u{00B1}", with: "\u{2212}")
        text += " und +" + String(format: "%.0f", zeichen.drehspanne) + "\u{00B0}. "
        text += "Er ist NICHT gewürfelt, sondern hängt an der Kennung der Seite: "
        text += "Dieselbe Seite steht beim nächsten Öffnen wieder gleich schief, "
        text += "und das PDF zeigt genau das, was hier zu sehen ist. "
        text += "Der Platz für das Zeichen wird dabei mitgerechnet \u{2014} "
        text += "gedreht braucht es mehr, und sonst ragte es über den Satzspiegel."
        return text
    }

    private var lagenhinweis: String {
        guard let zeichen else { return "" }
        if zeichen.lage == .automatisch {
            var text = "Für jede Seite wird nachgemessen, wo am wenigsten steht: "
            text += "Ein Foto deckt das Zeichen ganz zu, Text läuft nur darüber hinweg und wiegt deshalb viel weniger. "
            text += "Auf einer vollen Seite bleibt trotzdem keine Stelle frei — dann liegt es dort, wo es am wenigsten stört, "
            text += "und nicht nirgends."
            return text
        }
        return "Feste Lage im Satzspiegel. Auf Seiten mit einem randabfallenden Foto verschwindet das Zeichen dann unter dem Bild."
    }

    // MARK: - Probe

    // Kein eigener Zeichenweg: Gezeigt wird eine Papierfläche mit einem
    // angedeuteten Block, und darüber dasselbe Bild in derselben Deckkraft.
    // Die LAGE zeigt die Probe nicht — die hängt an der wirklichen Seite.
    private var probe: some View {
        ZStack {
            werk.reise.gestaltung.papier.farbe
            if let zeichen, let bild = Bildarchiv.shared.vorschau(zeichen.datei,
                                                                  reise: werk.reise.id,
                                                                  kante: 600)
            {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFit()
                    .padding(28)
                    .opacity(zeichen.deckung)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("Über den Pass")
                    .font(.system(size: 17, weight: .bold))
                ForEach(0 ..< 4, id: \.self) { _ in
                    Capsule()
                        .fill(Color.primary.opacity(0.22))
                        .frame(height: 5)
                }
                Capsule()
                    .fill(Color.primary.opacity(0.22))
                    .frame(width: 90, height: 5)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipped()
    }

    // MARK: - Handgriffe

    private func binden<W>(_ pfad: WritableKeyPath<Wasserzeichen, W>) -> Binding<W> {
        Binding(
            get: { zeichen?[keyPath: pfad] ?? Wasserzeichen(datei: "")[keyPath: pfad] },
            set: { neu in
                guard var jetzt = werk.reise.gestaltung.wasserzeichen else { return }
                jetzt[keyPath: pfad] = neu
                werk.reise.gestaltung.wasserzeichen = jetzt
            }
        )
    }

    // Für alles, was mehr als ein Feld setzt oder eine Bedingung hat.
    private func aendern(_ was: (inout Wasserzeichen) -> Void) {
        guard var jetzt = werk.reise.gestaltung.wasserzeichen else { return }
        was(&jetzt)
        werk.reise.gestaltung.wasserzeichen = jetzt
    }

    // Die gewählte Datei wandert unverändert ins Bildarchiv DIESER Reise —
    // mit ihrer echten Endung: Eine PNG unter dem Namen `.jpg` abzulegen
    // ginge zwar, aber jede spätere Suche nach dem Format sähe dann falsch.
    private func uebernehmen(_ adresse: URL) {
        let offen = adresse.startAccessingSecurityScopedResource()
        defer { if offen { adresse.stopAccessingSecurityScopedResource() } }
        guard let daten = try? Data(contentsOf: adresse) else {
            werk.meldung = .init(text: "Die Datei ließ sich nicht lesen.")
            return
        }
        let endung = adresse.pathExtension.isEmpty ? "png" : adresse.pathExtension.lowercased()
        guard let name = try? Bildarchiv.shared.ablegen(daten, reise: werk.reise.id,
                                                        endung: endung)
        else {
            werk.meldung = .init(text: "Die Datei ließ sich nicht ablegen.")
            return
        }

        werk.merken()
        let alt = werk.reise.gestaltung.wasserzeichen
        var neu = Wasserzeichen(datei: name, seitenverhaeltnis: verhaeltnis(daten))
        // Was eingestellt war, bleibt: Wer nur das Bild austauscht, will
        // nicht auch Deckkraft, Größe und Lage zurückgesetzt bekommen.
        if let alt {
            neu.deckung = alt.deckung
            neu.anteil = alt.anteil
            neu.lage = alt.lage
            neu.aufTitelblatt = alt.aufTitelblatt
        }
        werk.reise.gestaltung.wasserzeichen = neu
        if let alt, alt.gueltig { Bildarchiv.shared.loeschen(alt.datei, reise: werk.reise.id) }
    }

    private func entfernen() {
        guard let alt = werk.reise.gestaltung.wasserzeichen else { return }
        werk.merken()
        werk.reise.gestaltung.wasserzeichen = nil
        if alt.gueltig { Bildarchiv.shared.loeschen(alt.datei, reise: werk.reise.id) }
    }

    // Breite durch Höhe, EINMAL gemessen — und zwar aus den Kopfdaten, ohne
    // das Bild zu entpacken. Eine Drehung im EXIF wird dabei mitgelesen:
    // Ohne sie stünde ein hochkant gespeichertes Zeichen quer im Rahmen,
    // und zwar nur hier und nicht in der Vorschau.
    private func verhaeltnis(_ daten: Data) -> Double {
        guard let quelle = CGImageSourceCreateWithData(daten as CFData, nil),
              let werte = CGImageSourceCopyPropertiesAtIndex(quelle, 0, nil) as? [CFString: Any],
              let breite = werte[kCGImagePropertyPixelWidth] as? Double,
              let hoehe = werte[kCGImagePropertyPixelHeight] as? Double,
              breite > 0, hoehe > 0
        else { return 1 }
        let drehung = werte[kCGImagePropertyOrientation] as? Int ?? 1
        let quer = drehung >= 5 && drehung <= 8
        return quer ? hoehe / breite : breite / hoehe
    }
}
