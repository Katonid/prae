import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// Das Wasserzeichen des Buches — einmal festgelegt, auf jeder Seite.
//
// Seit 1.0.56 sind es bis zu ZEHN Bilder, und welches auf einer Seite
// liegt, zieht die Automatik aus der Kennung der Seite. Was hier
// eingestellt wird, gilt weiterhin für alle: Deckkraft, Größe, Lage und
// Drehung gehören dem Buch, nicht dem einzelnen Bild.
//
// Ansage des Nutzers, 09/2026: ein Ahornblatt, halbdurchsichtig, möglichst
// dort, wo sonst nichts steht. Was hier eingestellt wird, gilt für das
// ganze Buch.
//
// Bis 1.0.53 stand hier, die Seite selbst könne nichts davon abweichen —
// „genau das ist der Sinn eines Wasserzeichens". Der Satz ist seit 1.0.54
// falsch: Lage und Winkel sucht die Automatik weiterhin je Seite, und wo
// sie danebenliegt, lässt sich EINE Seite nachstellen (nichts auswählen →
// Pinsel → Wasserzeichen). Dieses Blatt bleibt das Buchganze; die
// Korrektur ist eine Abweichung davon.
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
                    Text(probenhinweis)
                }

                bilderabschnitt

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
                // MEHRERE auf einmal: Wer zehn Symbole hat, soll nicht
                // zehnmal denselben Weg gehen.
                Dateiwahl(typen: [.image], mehrere: true) { adressen in
                    dateiwahl = false
                    uebernehmen(adressen)
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Die Bilder

    private var bilder: [Zeichenbild] { zeichen?.gueltigeBilder ?? [] }

    private var bilderabschnitt: some View {
        Section {
            ForEach(bilder) { eintrag in
                bildzeile(eintrag)
            }
            if bilder.count < Wasserzeichen.hoechstzahl {
                Button {
                    dateiwahl = true
                } label: {
                    Label(bilder.isEmpty ? "Bilddatei wählen…" : "Weitere Bilder hinzufügen…",
                          systemImage: "photo.badge.plus")
                }
            }
            if !bilder.isEmpty {
                Button(role: .destructive) {
                    alleEntfernen()
                } label: {
                    Label("Alle entfernen", systemImage: "trash")
                }
            }
        } header: {
            Text(bilder.count > 1 ? "Bilder (\(bilder.count) von \(Wasserzeichen.hoechstzahl))"
                                  : "Bild")
        } footer: {
            Text(bildhinweis)
        }
    }

    // Der Knopf zum Entfernen ist `.borderless`: In einer Liste machte
    // eine gewöhnliche Schaltfläche die ganze Zeile antippbar, und dann
    // löschte ein Tipp irgendwo in der Zeile das Bild.
    private func bildzeile(_ eintrag: Zeichenbild) -> some View {
        HStack(spacing: 12) {
            bildchen(eintrag)
            VStack(alignment: .leading, spacing: 2) {
                Text(name(eintrag))
                Text(formtext(eintrag))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                entfernen(eintrag)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private func bildchen(_ eintrag: Zeichenbild) -> some View {
        if let bild = Bildarchiv.shared.vorschau(eintrag.datei, reise: werk.reise.id,
                                                 kante: 120)
        {
            Image(uiImage: bild)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray5))
                .frame(width: 40, height: 40)
        }
    }

    // Ein Dateiname ist eine UUID und sagt niemandem etwas. Gezählt wird
    // deshalb die Stelle in der Liste.
    private func name(_ eintrag: Zeichenbild) -> String {
        let stelle = (bilder.firstIndex(of: eintrag) ?? 0) + 1
        return "Bild \(stelle)"
    }

    private func formtext(_ eintrag: Zeichenbild) -> String {
        if eintrag.seitenverhaeltnis > 1.08 { return "quer" }
        if eintrag.seitenverhaeltnis < 0.93 { return "hochkant" }
        return "quadratisch"
    }

    // MARK: - Texte

    private var probenhinweis: String {
        if bilder.isEmpty { return "Noch kein Bild gewählt." }
        if bilder.count == 1 {
            return "So liegt es auf einer Seite mit Text und einem Foto. Wo genau, entscheidet sich auf jeder Seite neu."
        }
        var text = "Gezeigt ist Bild 1. Auf einer Seite liegt jeweils EINES der "
        text += "\(bilder.count) Bilder — welches, zieht die App aus der Kennung der Seite, "
        text += "nicht aus dem Zufall: Dieselbe Seite bekommt beim nächsten Öffnen dasselbe "
        text += "Bild, und das PDF zeigt, was auf dem Bildschirm steht. Eine einzelne Seite "
        text += "lässt sich umstellen: nichts auswählen, dann Pinsel \u{2192} Wasserzeichen."
        return text
    }

    // Ehrlich statt bequem: Die Mediathek ist bewusst NICHT der Weg.
    private var bildhinweis: String {
        var text = "Am besten ein PNG mit durchsichtigem Grund — eine Silhouette, kein Foto. "
        text += "Ein JPEG hat immer einen Grund, und der legt sich als helles Rechteck über die Seite. "
        text += "Deshalb führt dieser Weg in die Dateien und nicht in die Fotos: "
        text += "Die Mediathek gibt fast nur JPEG und HEIC heraus, und beide können keine Durchsichtigkeit."
        if bilder.count >= Wasserzeichen.hoechstzahl {
            text += " Mehr als \(Wasserzeichen.hoechstzahl) Bilder gehen nicht \u{2014} "
            text += "entferne eines, um ein anderes aufzunehmen."
        }
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
        text += "gedreht braucht es mehr, und sonst ragte es über den Satzspiegel. "
        text += "Eine einzelne Seite lässt sich nachstellen: nichts auswählen, dann "
        text += "Pinsel \u{2192} Wasserzeichen."
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
        var text = "Feste Lage im Satzspiegel. Auf Seiten mit einem randabfallenden Foto "
        text += "verschwindet das Zeichen dann unter dem Bild \u{2014} eine einzelne Seite "
        text += "lässt sich nachstellen: nichts auswählen, dann Pinsel \u{2192} Wasserzeichen."
        return text
    }

    // MARK: - Probe

    // Kein eigener Zeichenweg: Gezeigt wird eine Papierfläche mit einem
    // angedeuteten Block, und darüber dasselbe Bild in derselben Deckkraft.
    // Die LAGE zeigt die Probe nicht — die hängt an der wirklichen Seite.
    private var probe: some View {
        ZStack {
            werk.reise.gestaltung.papier.farbe
            if let erstes = bilder.first,
               let bild = Bildarchiv.shared.vorschau(erstes.datei, reise: werk.reise.id,
                                                     kante: 600)
            {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFit()
                    .padding(28)
                    .opacity(zeichen?.deckung ?? 0.1)
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
            get: { zeichen?[keyPath: pfad] ?? Wasserzeichen()[keyPath: pfad] },
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
    // HINZUGEFÜGT, nicht ersetzt (ab 1.0.56). Was eingestellt war, bleibt
    // ohnehin: Deckkraft, Größe, Lage und Drehung gehören dem Buch und
    // nicht dem einzelnen Bild.
    private func uebernehmen(_ adressen: [URL]) {
        guard !adressen.isEmpty else { return }
        var neu = werk.reise.gestaltung.wasserzeichen ?? Wasserzeichen()
        var aufgenommen = 0
        var uebrig = 0
        var gemerkt = false
        for adresse in adressen {
            guard neu.bilder.count < Wasserzeichen.hoechstzahl else {
                uebrig += 1
                continue
            }
            guard let eintrag = eingelesen(adresse) else { continue }
            if !gemerkt {
                werk.merken()
                gemerkt = true
            }
            neu.bilder.append(eintrag)
            aufgenommen += 1
        }
        guard aufgenommen > 0 || uebrig > 0 else { return }
        if aufgenommen > 0 { werk.reise.gestaltung.wasserzeichen = neu }
        // Stillschweigend die Hälfte zu verschlucken wäre der schlimmere
        // Fehler: Wer zwölf Dateien wählt, muss erfahren, dass zwei
        // draußen blieben.
        if uebrig > 0 {
            werk.meldung = .init(text: "\(uebrig) Bild(er) nicht aufgenommen \u{2014} mehr als \(Wasserzeichen.hoechstzahl) gehen nicht.")
        }
    }

    private func eingelesen(_ adresse: URL) -> Zeichenbild? {
        let offen = adresse.startAccessingSecurityScopedResource()
        defer { if offen { adresse.stopAccessingSecurityScopedResource() } }
        guard let daten = try? Data(contentsOf: adresse) else {
            werk.meldung = .init(text: "Die Datei ließ sich nicht lesen.")
            return nil
        }
        let endung = adresse.pathExtension.isEmpty ? "png" : adresse.pathExtension.lowercased()
        guard let name = try? Bildarchiv.shared.ablegen(daten, reise: werk.reise.id,
                                                        endung: endung)
        else {
            werk.meldung = .init(text: "Die Datei ließ sich nicht ablegen.")
            return nil
        }
        return Zeichenbild(datei: name, seitenverhaeltnis: verhaeltnis(daten))
    }

    // Ein einzelnes Bild geht, die Einstellungen bleiben. Seiten, die
    // ausdrücklich auf dieses Bild zeigten, fallen auf die Automatik
    // zurück — ein Verweis ins Leere darf nie eine leere Fläche ergeben,
    // und die Korrekturen der anderen Seiten dafür anzutasten wäre zu viel
    // des Guten.
    private func entfernen(_ eintrag: Zeichenbild) {
        guard var neu = werk.reise.gestaltung.wasserzeichen else { return }
        werk.merken()
        neu.bilder.removeAll { $0.datei == eintrag.datei }
        werk.reise.gestaltung.wasserzeichen = neu.gueltig ? neu : nil
        Bildarchiv.shared.loeschen(eintrag.datei, reise: werk.reise.id)
    }

    private func alleEntfernen() {
        guard let alt = werk.reise.gestaltung.wasserzeichen else { return }
        werk.merken()
        werk.reise.gestaltung.wasserzeichen = nil
        for eintrag in alt.gueltigeBilder {
            Bildarchiv.shared.loeschen(eintrag.datei, reise: werk.reise.id)
        }
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
