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
    // Das Bild für die Ausschnittsprobe. Geholt wird es in `.task(id:)`
    // und nicht im Körper — der läuft bei jedem Neuzeichnen, und die
    // Regler darunter zeichnen ihn bei jedem Bildpunkt neu.
    @State private var ausschnittbild: UIImage?

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

                        ausschnittabschnitt
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
            .task(id: kraftschluessel) {
                randanteil = gemessenerRandanteil()
                ausschnittbild = probenbild()
            }
        }
    }

    // MARK: - Bildausschnitt

    // ZOOMEN UND VERSCHIEBEN (ab 1.0.58).
    //
    // Es sind REGLER und keine Geste, und das ist eine Entscheidung: Diese
    // Ansicht steht in einem `Form`, also in einer Liste, die scrollt. Eine
    // Ziehgeste über der Probe stritte mit dem Scrollen — genau die Lehre
    // aus 1.0.5 („Wer eine Geste über eine ganze Fläche legt, prüft, was
    // diese Fläche sonst noch tut"). Ein Regler nimmt der Liste nichts weg
    // und trifft dazu auf ein Prozent genau.
    private var ausschnittabschnitt: some View {
        Section {
            if let bild = ausschnittbild {
                ausschnittprobe(bild)
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                VStack(alignment: .leading) {
                    LabeledContent("Zoom", value: zoomtext)
                    Slider(value: zoomregler(bild), in: 1...3, step: 0.05)
                }
                verschieberegler(bild, quer: true)
                verschieberegler(bild, quer: false)
                Button("Wieder ganz füllen") {
                    aendern { $0.ausschnitt = .voll }
                }
                .disabled(grund.ausschnitt.istVoll)
            } else {
                Text("Erst ein Foto wählen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Bildausschnitt")
        } footer: {
            Text(ausschnitthinweis)
        }
    }

    // Die Fläche, die das Foto WIRKLICH füllt — dieselbe, die das PDF
    // bekommt. Beim Buchblock ist das der Bogen (Endformat plus Anschnitt
    // ringsum) oder, wenn das Bild über die Doppelseite geht, die Fläche
    // beider Seiten. Beim Umschlag ist es der ganze Umschlagbogen: Der ist
    // EIN Stück Papier, und so steht er auch im PDF.
    private var ausschnittflaeche: CGSize {
        if fuerUmschlag {
            return Umschlagmass.bogen(werk.reise.format,
                                      gestaltung: werk.reise.gestaltung,
                                      umschlag: werk.reise.umschlag,
                                      innenseiten: werk.reise.innenseiten)
        }
        let a = werk.reise.gestaltung.anschnittPt
        let format = werk.reise.format.groesse
        var breite = Double(format.width) + 2 * a
        if grund.ueberDoppelseite { breite += Double(format.width) }
        return CGSize(width: breite, height: Double(format.height) + 2 * a)
    }

    private var ausschnittrahmen: CGRect {
        CGRect(origin: .zero, size: ausschnittflaeche)
    }

    // Wie viel Spielraum der Ausschnitt in dieser Richtung hat — als
    // Anteil der Rahmenbreite bzw. -höhe, also in derselben Einheit, in
    // der `Bildausschnitt` seinen Versatz führt. Ist er null, füllt das
    // Bild den Rahmen genau und es gibt schlicht nichts zu verschieben.
    private func spielraum(_ bild: UIImage, quer: Bool) -> Double {
        let rahmen = ausschnittrahmen
        let ziel = grund.ausschnitt.zielrechteck(bildgroesse: bild.size, rahmen: rahmen)
        if quer {
            return max(Double(ziel.width - rahmen.width) / 2, 0) / max(Double(rahmen.width), 1)
        }
        return max(Double(ziel.height - rahmen.height) / 2, 0) / max(Double(rahmen.height), 1)
    }

    private func zoomregler(_ bild: UIImage) -> Binding<Double> {
        Binding(
            get: { grund.ausschnitt.zoom },
            set: { neu in
                aendern {
                    $0.ausschnitt.zoom = neu
                    // Weniger Zoom heißt weniger Spielraum: Ein Versatz,
                    // der eben noch im Bild lag, ließe sonst einen weißen
                    // Keil stehen.
                    $0.ausschnitt = $0.ausschnitt.begrenzt(bildgroesse: bild.size,
                                                           rahmen: ausschnittrahmen)
                }
            }
        )
    }

    @ViewBuilder
    private func verschieberegler(_ bild: UIImage, quer: Bool) -> some View {
        let luft = spielraum(bild, quer: quer)
        let name = quer ? "Nach links/rechts" : "Nach oben/unten"
        if luft > 0.002 {
            VStack(alignment: .leading) {
                LabeledContent(name, value: versatztext(quer: quer))
                Slider(value: versatzregler(bild, quer: quer), in: -luft...luft)
            }
        } else {
            LabeledContent(name, value: "kein Spielraum")
                .foregroundStyle(.secondary)
        }
    }

    private func versatzregler(_ bild: UIImage, quer: Bool) -> Binding<Double> {
        Binding(
            get: { quer ? grund.ausschnitt.versatzX : grund.ausschnitt.versatzY },
            set: { neu in
                aendern {
                    if quer { $0.ausschnitt.versatzX = neu } else { $0.ausschnitt.versatzY = neu }
                    $0.ausschnitt = $0.ausschnitt.begrenzt(bildgroesse: bild.size,
                                                           rahmen: ausschnittrahmen)
                }
            }
        )
    }

    private var zoomtext: String {
        let zahl = String(format: "%.0f", grund.ausschnitt.zoom * 100)
        return zahl + " %"
    }

    private func versatztext(quer: Bool) -> String {
        let wert = quer ? grund.ausschnitt.versatzX : grund.ausschnitt.versatzY
        let zahl = String(format: "%+.0f", wert * 100)
        return zahl + " %"
    }

    // Die Probe zeigt die Fläche MASSSTÄBLICH — dasselbe Seitenverhältnis,
    // dieselbe Rechnung. `zielrechteck` misst den Versatz in Anteilen der
    // Rahmenbreite, ist also vom Maßstab unabhängig: Was hier steht, steht
    // im PDF an derselben Stelle.
    @ViewBuilder
    private func ausschnittprobe(_ bild: UIImage) -> some View {
        let flaeche = ausschnittflaeche
        let anteilX = werk.reise.gestaltung.anschnittPt / Double(flaeche.width)
        let anteilY = werk.reise.gestaltung.anschnittPt / Double(flaeche.height)
        GeometryReader { raum in
            let rahmen = CGRect(origin: .zero, size: raum.size)
            let ziel = grund.ausschnitt.gefuelltesZiel(bildgroesse: bild.size, rahmen: rahmen)
            ZStack(alignment: .topLeading) {
                grund.farbe.farbe
                Image(uiImage: bild)
                    .resizable()
                    .frame(width: ziel.width, height: ziel.height)
                    .offset(x: ziel.minX, y: ziel.minY)
                grund.farbe.farbe.opacity(grund.schleier)
                // Die SCHNITTKANTE: Alles außerhalb wird weggeschnitten.
                // Dieselbe Linie wie auf der Bühne unter „Satzspiegel
                // zeigen", und derselbe Grund — ohne sie sieht man dem
                // Bild nicht an, wovon es noch etwas verliert.
                Rectangle()
                    .strokeBorder(Color.red.opacity(0.75),
                                  style: StrokeStyle(lineWidth: 0.8, dash: [4, 3]))
                    .padding(.horizontal, raum.size.width * anteilX)
                    .padding(.vertical, raum.size.height * anteilY)
                if zeigtBund {
                    bundband(raum.size)
                }
            }
            .clipped()
        }
        .aspectRatio(Double(flaeche.width) / Double(flaeche.height), contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    private var zeigtBund: Bool { grund.ueberDoppelseite && !fuerUmschlag }

    // DER BUND — und der Streifen, den er kostet.
    //
    // Die beiden Endformate stoßen in der Mitte aneinander; dort wird
    // gefalzt und geheftet. Links und rechts davon liegt je ein Anschnitt,
    // und der wird weggeschnitten: Was in diesem Band steht, steht in der
    // Doppelseitenansicht zweimal da und im gebundenen Buch gar nicht.
    // Genau darauf saß die Sonne (gemeldet 09/2026).
    @ViewBuilder
    private func bundband(_ raum: CGSize) -> some View {
        let anschnitt = werk.reise.gestaltung.anschnittPt
        let breite = raum.width * (2 * anschnitt / Double(ausschnittflaeche.width))
        ZStack {
            Rectangle().fill(Color.red.opacity(0.14))
            Rectangle().fill(Color.red.opacity(0.75)).frame(width: 0.8)
        }
        .frame(width: max(breite, 1), height: raum.height)
        .position(x: raum.width / 2, y: raum.height / 2)
    }

    private var ausschnitthinweis: String {
        var text = "Gefüllt wird, nicht eingepasst: Das Bild deckt die ganze Fläche ab, "
        text += "und was über den Rand ragt, wird beschnitten. Der Zoom sagt, wie viel "
        text += "größer es dafür gezeichnet wird; erst darüber entsteht Spielraum zum "
        text += "Verschieben. Was innerhalb der roten Linie liegt, bleibt nach dem "
        text += "Schneiden stehen.\n\nMaßgeblich ist diese Vorschau — sie hat das Maß der "
        text += "Fläche, die auch ins PDF geht. Die Leiste ganz oben zeigt nur Farben und "
        text += "Schrift."
        if zeigtBund {
            text += "\n\nDas rote Band in der Mitte ist der Bund. Dort stoßen die beiden "
            text += "Seiten aneinander; die beiden Anschnitte darin werden weggeschnitten. "
            text += "In der Doppelseitenansicht steht dieser Streifen deshalb ZWEIMAL da — "
            text += "einmal von jeder Seite. Im gebundenen Buch ist er weg. Was genau dort "
            text += "liegt, verschiebt man am besten heraus."
        }
        return text
    }

    private func probenbild() -> UIImage? {
        guard grund.art == .foto, let id = grund.fotoID,
              let foto = werk.reise.foto(id)
        else { return nil }
        return Bildarchiv.shared.vorschau(foto.datei, reise: werk.reise.id, kante: 900,
                                          farbkraft: grund.farbkraftfaktor)
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
