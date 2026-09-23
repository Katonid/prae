import SwiftUI

// Der Hintergrund — für das ganze Buch oder für eine einzelne Seite.
//
// Beides führt auf dieselbe Ansicht, weil es dieselbe Entscheidung ist. Der
// Unterschied steht in der Fußzeile: was hier gilt und was es überschreibt.
// Zwei getrennte Bildschirme für dieselbe Sache liefen unweigerlich
// auseinander.
struct HintergrundView: View {
    @ObservedObject var werk: Reisewerk
    // Leer heißt: Es geht um das ganze Buch.
    var seite: (tag: UUID, stelle: Int)?
    // Oder um den UMSCHLAG (ab 1.0.50): Er hat seine eigene Gestaltung,
    // weil er ein eigenes Stück Papier ist. Dieselbe Ansicht, drittes
    // Ziel — drei Bildschirme für dieselbe Entscheidung liefen auseinander.
    var fuerUmschlag: Bool = false
    @Environment(\.dismiss) private var schliessen
    @State private var fotowahl = false
    // Was das Strecken kostet — GEMESSEN, nicht geschätzt (siehe
    // `Model/Farbkraft.swift`). Gerechnet wird in `.task(id:)` und nicht im
    // Körper: Der läuft bei jedem Neuzeichnen.
    @State private var randanteil: Double?

    private var istBuch: Bool { seite == nil && !fuerUmschlag }

    private var grund: Seitenhintergrund {
        if fuerUmschlag {
            return werk.reise.umschlag.hintergrund ?? werk.reise.gestaltung.hintergrund
        }
        if let seite, let t = werk.tagIndex(seite.tag),
           werk.reise.tage[t].seiten.indices.contains(seite.stelle),
           let eigener = werk.reise.tage[t].seiten[seite.stelle].hintergrund
        {
            return eigener
        }
        return werk.reise.gestaltung.hintergrund
    }

    private var eigenerGesetzt: Bool {
        if fuerUmschlag { return werk.reise.umschlag.hintergrund != nil }
        guard let seite, let t = werk.tagIndex(seite.tag),
              werk.reise.tage[t].seiten.indices.contains(seite.stelle) else { return false }
        return werk.reise.tage[t].seiten[seite.stelle].hintergrund != nil
    }

    private var aenderbar: Bool { istBuch || eigenerGesetzt }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    probe
                        .frame(height: 140)
                        .listRowInsets(EdgeInsets())
                }

                if !istBuch {
                    Section {
                        Toggle(fuerUmschlag ? "Eigener Hintergrund für den Umschlag"
                                            : "Eigener Hintergrund für diese Seite",
                               isOn: Binding(
                                   get: { eigenerGesetzt },
                                   set: { an in
                                       setzen(an ? werk.reise.gestaltung.hintergrund : nil)
                                   }
                               ))
                    } footer: {
                        Text(fussnote)
                    }
                }

                if aenderbar {
                    Section("Art") {
                        Picker("Hintergrund", selection: binden(\.art)) {
                            ForEach(Seitenhintergrund.Art.allCases) { art in
                                Text(art.name).tag(art)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("Farbe") {
                        ColorPicker("Grundfarbe", selection: Binding(
                            get: { grund.farbe.farbe },
                            set: { neu in aendern { $0.farbe = Farbwert(neu) } }
                        ))
                        if grund.art == .verlauf {
                            ColorPicker("Zweite Farbe", selection: Binding(
                                get: { grund.zweitfarbe.farbe },
                                set: { neu in aendern { $0.zweitfarbe = Farbwert(neu) } }
                            ))
                            VStack(alignment: .leading) {
                                LabeledContent("Richtung",
                                               value: "\(Int(grund.winkel))°")
                                Slider(value: binden(\.winkel), in: 0...360, step: 15)
                            }
                        }
                        if grund.dunkel {
                            Label("Dunkler Grund — helle Schrift wählen, sonst verschwindet der Text.",
                                  systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    if grund.art == .papierstruktur {
                        Section("Struktur") {
                            VStack(alignment: .leading) {
                                LabeledContent("Körnung",
                                               value: String(format: "%.0f %%", grund.koernung * 100))
                                Slider(value: binden(\.koernung), in: 0...0.25)
                            }
                            Text("Ein feines Korn nimmt einer Farbfläche das Bildschirmhafte. Im Druck wirkt es schwächer als auf dem Schirm.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if grund.art == .foto {
                        Section("Bild") {
                            Button {
                                fotowahl = true
                            } label: {
                                LabeledContent("Foto",
                                               value: grund.fotoID == nil ? "keines gewählt" : "gewählt")
                            }
                            VStack(alignment: .leading) {
                                LabeledContent("Schleier",
                                               value: String(format: "%.0f %%", grund.schleier * 100))
                                Slider(value: binden(\.schleier), in: 0...0.95)
                            }
                            Text("Ohne Schleier steht der Text auf dem Bild und ist nicht zu lesen. Ein Hintergrundfoto ist nicht das, worauf man schauen soll.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        farbkraftabschnitt

                        Section {
                            Toggle("Bild über die Doppelseite",
                                   isOn: binden(\.ueberDoppelseite))
                        } header: {
                            Text("Wie weit das Bild reicht")
                        } footer: {
                            Text(doppelseitenhinweis)
                        }
                    }
                }
            }
            .navigationTitle(titelzeile)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
            .sheet(isPresented: $fotowahl) {
                HintergrundfotoView(werk: werk) { id in
                    aendern { $0.fotoID = id }
                }
            }
            .task(id: kraftschluessel) { randanteil = gemessenerRandanteil() }
        }
    }

    // MARK: - Farbkraft

    // Eigener Abschnitt und keine Zeile im Bildabschnitt: Es ist die
    // Antwort auf den Schleier darüber und will daneben gelesen werden.
    private var farbkraftabschnitt: some View {
        Section {
            VStack(alignment: .leading) {
                LabeledContent("Farbkraft",
                               value: String(format: "%.0f %%", grund.farbkraft * 100))
                Slider(value: binden(\.farbkraft), in: 0...1)
            }
            LabeledContent("Sättigung des Fotos", value: faktortext)
            if let randanteil, randanteil > 0.005 {
                Label(randtext(randanteil), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(randanteil > 0.08 ? Color.orange : Color.secondary)
            }
        } header: {
            Text("Farbkraft")
        } footer: {
            Text(farbkrafthinweis)
        }
    }

    private var faktortext: String {
        let faktor = grund.farbkraftfaktor
        guard faktor > 1.001 else { return "unverändert" }
        let zahl = String(format: "%.2f", faktor).replacingOccurrences(of: ".", with: ",")
        return "\u{00D7} " + zahl
    }

    private func randtext(_ anteil: Double) -> String {
        var text = "Gemessen: " + String(format: "%.0f", anteil * 100)
        text += " % der Bildpunkte laufen dadurch an den Rand und verlieren dort ihre "
        text += "Zeichnung. Gezählt an einer verkleinerten Fassung, einmal vorher und "
        text += "einmal nachher."
        return text
    }

    // Die ganze Rechnung in einem Absatz — samt dem, was sie NICHT kann.
    private var farbkrafthinweis: String {
        let schleiertext = String(format: "%.0f", grund.schleier * 100)
        let decke = String(format: "%.0f",
                           Farbkraft.erreichbareSaettigung(schleier: grund.schleier) * 100)
        var text = "Der Schleier zieht jede Farbe Richtung Papierweiß, und dabei rücken alle "
        text += "Farben zusammen — daher das Grau in Grau. Die Farbkraft sättigt das Foto, "
        text += "BEVOR der Schleier darüberkommt, und holt damit genau den Abstand zurück, "
        text += "den der Schleier genommen hat: durchsichtig und trotzdem bunt. "
        text += "Eine Grenze bleibt, und die ist Arithmetik: Hinter einem Schleier von "
        text += schleiertext + " % kann nichts mehr als " + decke + " % Sättigung erreichen, "
        text += "ganz gleich, was das Foto zeigt. Der Regler führt bis dorthin und keinen "
        text += "Schritt weiter. Bei einer einfarbigen Fläche gibt es dagegen nichts "
        text += "auszugleichen: Eine Farbe mit halber Deckung über weißem Papier IST eine "
        text += "hellere Farbe — dort wählt man gleich die hellere."
        return text
    }

    // Ändert sich einer dieser drei Werte, wird neu gemessen.
    private var kraftschluessel: String {
        "\(grund.fotoID?.uuidString ?? "-")|\(grund.schleier)|\(grund.farbkraft)"
    }

    private func gemessenerRandanteil() -> Double? {
        guard grund.art == .foto, let id = grund.fotoID,
              let foto = werk.reise.foto(id),
              let bild = Bildarchiv.shared.vorschau(foto.datei, reise: werk.reise.id, kante: 600)
        else { return nil }
        return Farbkraft.randanteil(bild, faktor: grund.farbkraftfaktor)
    }

    private var probe: some View {
        ZStack(alignment: .topLeading) {
            // Ohne Bogen und ohne Seitennummer: Die Probe steht nicht im
            // Buch, sie hat keine Nachbarseite, und ein Bild über die
            // Doppelseite wäre hier eine Behauptung über etwas, das es an
            // dieser Stelle nicht gibt.
            HintergrundFlaeche(werk: werk, hintergrund: grund, seite: Seite(),
                               format: werk.reise.format.groesse,
                               anschnitt: werk.reise.gestaltung.anschnittPt)
            VStack(alignment: .leading, spacing: 6) {
                Text(werk.reise.gestaltung.datumsstil
                    .text(Tagesdatum(Date()), nummer: 3).uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(werk.reise.akzent.farbe)
                Text("Über den Pass")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(grund.dunkel ? Color.white : Color.primary)
                Text("So sieht die Seite mit diesem Hintergrund aus.")
                    .font(.system(size: 10))
                    .foregroundStyle(grund.dunkel ? Color.white.opacity(0.85) : Color.secondary)
            }
            .padding(16)
        }
    }

    // Was der Schalter kann und was nicht — beides steht da, und der
    // zweite Teil ist der wichtigere: Die App kann eine Doppelseite nicht
    // erzwingen. Wer den Hintergrund je SEITE setzt, muss beiden Seiten
    // dasselbe Bild geben, sonst zeigt jede ihre Hälfte eines anderen.
    private var doppelseitenhinweis: String {
        var text = "Aus: Das Bild füllt jede Seite für sich. An: Es füllt die ganze "
        text += "aufgeschlagene Doppelseite, und jede Seite zeigt ihre Hälfte davon. "
        text += "Ein Muster oder ein Himmel gehört auf jede Seite, eine Landschaft über den Bund."
        if fuerUmschlag {
            text += " Auf dem Umschlag hat der Schalter keine Wirkung: Der ist EIN Stück "
            text += "Papier, und das Bild läuft dort ohnehin über Rückseite, Rücken und "
            text += "Titelseite."
        } else if istBuch {
            text += " Die linke Hälfte des ersten Bogens wird nie gedruckt — dort liegt im "
            text += "gebundenen Buch die Innenseite des Umschlags, solange der Umschlag nicht "
            text += "als Bogen gesetzt ist."
        } else {
            text += " Damit es aufgeht, braucht die Nachbarseite dasselbe Bild mit demselben "
            text += "Schalter. Sonst zeigt jede Seite ihre Hälfte eines anderen Bildes, und "
            text += "das fällt erst im gedruckten Buch auf."
        }
        return text
    }

    private var titelzeile: String {
        if fuerUmschlag { return "Hintergrund des Umschlags" }
        return istBuch ? "Hintergrund des Buches" : "Hintergrund der Seite"
    }

    private var fussnote: String {
        if fuerUmschlag {
            return eigenerGesetzt
                ? "Der Umschlag weicht vom Buch ab. Ausschalten stellt den Hintergrund des Buches wieder her."
                : "Der Umschlag folgt dem Hintergrund des Buches. Er gilt für Rückseite, Rücken und Titelseite zusammen — es ist ein Stück Papier."
        }
        return eigenerGesetzt
            ? "Diese Seite weicht vom Buch ab. Ausschalten stellt den Hintergrund des Buches wieder her."
            : "Diese Seite folgt dem Hintergrund des Buches."
    }

    private func binden<W>(_ pfad: WritableKeyPath<Seitenhintergrund, W>) -> Binding<W> {
        Binding(
            get: { grund[keyPath: pfad] },
            set: { neu in aendern { $0[keyPath: pfad] = neu } }
        )
    }

    private func aendern(_ arbeit: (inout Seitenhintergrund) -> Void) {
        var neu = grund
        arbeit(&neu)
        setzen(neu)
    }

    private func setzen(_ neu: Seitenhintergrund?) {
        if fuerUmschlag {
            werk.reise.umschlag.hintergrund = neu
            return
        }
        if let seite, let t = werk.tagIndex(seite.tag),
           werk.reise.tage[t].seiten.indices.contains(seite.stelle)
        {
            werk.reise.tage[t].seiten[seite.stelle].hintergrund = neu
            // Die alte Einzelfarbe je Seite geht im Hintergrund auf. Beides
            // nebeneinander zu führen hieße, zwei Wahrheiten über dieselbe
            // Fläche zu haben.
            werk.reise.tage[t].seiten[seite.stelle].papier = nil
        } else if let neu {
            werk.reise.gestaltung.hintergrund = neu
            werk.reise.gestaltung.papier = neu.farbe
        }
    }
}

struct HintergrundfotoView: View {
    @ObservedObject var werk: Reisewerk
    var gewaehlt: (UUID?) -> Void
    @Environment(\.dismiss) private var schliessen

    private let raster = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: raster, spacing: 8) {
                    ForEach(werk.reise.fotos.filter { !$0.abgelegt }) { foto in
                        Button {
                            gewaehlt(foto.id)
                            schliessen()
                        } label: {
                            if let bild = Bildarchiv.shared.vorschau(foto.datei,
                                                                     reise: werk.reise.id,
                                                                     kante: 300)
                            {
                                Image(uiImage: bild)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 100)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                            } else {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 100)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Hintergrundbild")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Ohne Bild") {
                        gewaehlt(nil)
                        schliessen()
                    }
                }
            }
        }
    }
}
