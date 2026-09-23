import SwiftUI

// DAS WASSERZEICHEN AUF GENAU DIESER SEITE (ab 1.0.54).
//
// Ansage des Nutzers, 09/2026: „Dennoch soll es mir möglich sein, einzelne
// Seiten bezüglich des Wasserzeichens noch anzupassen und die Drehung oder
// eine Verschiebung zu korrigieren."
//
// Der Bildschirm zeigt zuerst, was die AUTOMATIK auf dieser Seite tut —
// den Winkel als Zahl und die Lage als Skizze. Das ist die halbe Antwort
// auf den Satz „offenbar hast du mich falsch verstanden": Dass sich Winkel
// und Lage von Seite zu Seite unterscheiden, lässt sich behaupten oder
// hinschreiben. Hier steht es als Zahl.
//
// Geändert wird darunter, und zwar als ABWEICHUNG: Was nicht angefasst
// ist, folgt weiter der Automatik. Dieselbe Regel wie bei
// `Schriftabweichung` und `Block.wirkung`.
struct WasserzeichenSeiteView: View {
    @ObservedObject var werk: Reisewerk
    var tagID: UUID
    var stelle: Int
    @Environment(\.dismiss) private var schliessen

    private var zeichen: Wasserzeichen? {
        let z = werk.reise.gestaltung.wasserzeichen
        return z?.gueltig == true ? z : nil
    }

    private var seite: Seite? {
        guard let t = werk.tagIndex(tagID),
              werk.reise.tage[t].seiten.indices.contains(stelle) else { return nil }
        return werk.reise.tage[t].seiten[stelle]
    }

    private var satz: CGRect { werk.reise.gestaltung.satzspiegel(werk.reise.format) }

    private var eigen: Wasserzeichenabweichung? { seite?.wasserzeichen }

    private var gesetzt: Bool { eigen?.gesetzt == true }

    var body: some View {
        NavigationStack {
            Form {
                if let zeichen, let seite {
                    skizzenabschnitt(zeichen, seite)
                    bildabschnitt(zeichen, seite)
                    drehabschnitt(zeichen, seite)
                    versatzabschnitt
                    ruecksetzabschnitt
                } else {
                    Section {
                        Text("Für dieses Buch ist kein Wasserzeichen gesetzt.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Wasserzeichen hier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
    }

    // MARK: - Abschnitte
    //
    // Je Abschnitt eine eigene Funktion und nicht alles im Körper: Ein
    // Formular mit vier Abschnitten, Bedingungen und Bindungen darin ist
    // genau die Mischung, an der der Typprüfer in 1.0.38 aufgegeben hat.

    private func skizzenabschnitt(_ zeichen: Wasserzeichen, _ seite: Seite) -> some View {
        Section {
            Skizze(seite: seite, zeichen: zeichen, satz: satz,
                   format: werk.reise.format, reise: werk.reise.id)
                .frame(height: 220)
                .listRowInsets(EdgeInsets())
        } footer: {
            Text(skizzenhinweis)
        }
    }

    // WELCHES der Bilder hier liegt (ab 1.0.56).
    //
    // Der Abschnitt zeigt sich nur, wenn es überhaupt mehr als eines gibt:
    // Ein Wähler mit einem einzigen Eintrag ist kein Wähler, sondern eine
    // Zeile, die nichts tut.
    @ViewBuilder
    private func bildabschnitt(_ zeichen: Wasserzeichen, _ seite: Seite) -> some View {
        if zeichen.gueltigeBilder.count > 1 {
            Section {
                Picker("Bild", selection: bildwahl(zeichen)) {
                    Text("Automatisch (\(bildname(zeichen, automatisch(zeichen, seite))))")
                        .tag(String?.none)
                    ForEach(zeichen.gueltigeBilder) { eintrag in
                        Text(bildname(zeichen, eintrag)).tag(String?.some(eintrag.datei))
                    }
                }
            } header: {
                Text("Bild")
            } footer: {
                Text(bildhinweis(zeichen, seite))
            }
        }
    }

    private func bildwahl(_ zeichen: Wasserzeichen) -> Binding<String?> {
        Binding(
            get: {
                // Ein Name, den es nicht mehr gibt, gilt als nicht
                // gesetzt — sonst stünde im Wähler eine Auswahl, die es
                // nirgends gibt, und er zeigte gar nichts an.
                guard let name = eigen?.bild, zeichen.bild(name) != nil else { return nil }
                return name
            },
            set: { neu in aendern { $0.bild = neu } }
        )
    }

    private func automatisch(_ zeichen: Wasserzeichen, _ seite: Seite) -> Zeichenbild? {
        Wasserzeichenlage.automatischesBild(zeichen, seite: seite)
    }

    // Ein Dateiname ist eine UUID und sagt niemandem etwas — gezählt wird
    // die Stelle in der Liste, wie im Blatt für das ganze Buch.
    private func bildname(_ zeichen: Wasserzeichen, _ eintrag: Zeichenbild?) -> String {
        guard let eintrag,
              let stelle = zeichen.gueltigeBilder.firstIndex(of: eintrag) else { return "keines" }
        return "Bild \(stelle + 1)"
    }

    private func bildhinweis(_ zeichen: Wasserzeichen, _ seite: Seite) -> String {
        var text = "Ohne Auswahl zieht die App eines der \(zeichen.gueltigeBilder.count) "
        text += "Bilder aus der Kennung dieser Seite \u{2014} nicht aus dem Zufall: "
        text += "Dieselbe Seite bekommt beim nächsten Öffnen dasselbe Bild, und das PDF "
        text += "zeigt, was hier steht. Gleichverteilt ist das im Erwartungswert und nicht "
        text += "gleich oft; wie oft jedes Bild im Buch vorkommt, zählt die Druckprüfung. "
        text += "Wird ein Bild später entfernt, fällt diese Seite auf die Automatik zurück."
        return text
    }

    private func drehabschnitt(_ zeichen: Wasserzeichen, _ seite: Seite) -> some View {
        Section {
            Toggle("Eigener Winkel", isOn: winkelschalter(zeichen, seite))
            if let winkel = eigen?.winkel {
                VStack(alignment: .leading) {
                    LabeledContent("Drehung", value: gradtext(winkel))
                    Slider(value: winkelregler(winkel),
                           in: -Wasserzeichen.groessteDrehung ... Wasserzeichen.groessteDrehung,
                           step: 0.5)
                }
            }
        } header: {
            Text("Drehung")
        } footer: {
            Text(drehhinweis(zeichen, seite))
        }
    }

    private func winkelschalter(_ zeichen: Wasserzeichen, _ seite: Seite) -> Binding<Bool> {
        Binding(
            get: { eigen?.winkel != nil },
            set: { an in
                let vorgabe = Wasserzeichenlage.automatischerWinkel(zeichen, seite: seite)
                aendern { $0.winkel = an ? vorgabe : nil }
            }
        )
    }

    private func winkelregler(_ jetzt: Double) -> Binding<Double> {
        Binding(
            get: { jetzt },
            set: { neu in aendern { $0.winkel = neu } }
        )
    }

    private var versatzabschnitt: some View {
        Section {
            regler("Nach rechts", pfad: \.versatzX, weite: Double(weite.width))
            regler("Nach unten", pfad: \.versatzY, weite: Double(weite.height))
        } header: {
            Text("Verschiebung")
        } footer: {
            Text(versatzhinweis)
        }
    }

    private var ruecksetzabschnitt: some View {
        Section {
            Button(role: .destructive) {
                zuruecksetzen()
            } label: {
                Label("Wieder ganz automatisch", systemImage: "arrow.uturn.backward")
            }
            .disabled(!gesetzt)
        } footer: {
            Text(gesetzt
                 ? "Nimmt beides zurück: Winkel und Verschiebung."
                 : "Diese Seite folgt ganz der Automatik.")
        }
    }

    // MARK: - Regler

    // Die Spanne ist die halbe Satzbreite bzw. -höhe — mehr braucht es
    // nicht: Geklemmt wird ohnehin auf den Satzspiegel, und ein Regler,
    // der über seine eigene Wirkung hinausläuft, ist ein Regler, der
    // irgendwann nichts mehr tut.
    private var weite: CGSize {
        CGSize(width: max(Druckmass.mm(Double(satz.width)) / 2, 5),
               height: max(Druckmass.mm(Double(satz.height)) / 2, 5))
    }

    private func regler(_ titel: String,
                        pfad: WritableKeyPath<Wasserzeichenabweichung, Double>,
                        weite: Double) -> some View
    {
        let wert = eigen?[keyPath: pfad] ?? 0
        return VStack(alignment: .leading) {
            LabeledContent(titel, value: mmtext(wert))
            Slider(value: Binding(
                get: { wert },
                set: { neu in aendern { $0[keyPath: pfad] = neu } }
            ), in: -weite ... weite, step: 0.5)
        }
    }

    // MARK: - Texte

    private func gradtext(_ grad: Double) -> String {
        let gerundet = (grad * 10).rounded() / 10
        let zahl = String(format: "%.1f", abs(gerundet)).replacingOccurrences(of: ".", with: ",")
        let zeichen = gerundet < -0.05 ? "\u{2212}" : (gerundet > 0.05 ? "+" : "")
        return "\(zeichen)\(zahl)\u{00B0}"
    }

    private func mmtext(_ wert: Double) -> String {
        let gerundet = (wert * 10).rounded() / 10
        let zahl = String(format: "%.1f", abs(gerundet)).replacingOccurrences(of: ".", with: ",")
        let zeichen = gerundet < -0.05 ? "\u{2212}" : (gerundet > 0.05 ? "+" : "")
        return "\(zeichen)\(zahl) mm"
    }

    private var skizzenhinweis: String {
        var text = "Grau die Blöcke dieser Seite, dünn der Satzspiegel. "
        text += "So liegt das Zeichen hier \u{2014} "
        if gesetzt {
            text += "mit deiner Korrektur."
        } else {
            text += "ganz von der Automatik gesetzt."
        }
        return text
    }

    private func drehhinweis(_ zeichen: Wasserzeichen, _ seite: Seite) -> String {
        let automatisch = Wasserzeichenlage.automatischerWinkel(zeichen, seite: seite)
        var text = "Die Automatik gibt dieser Seite \(gradtext(automatisch)). "
        if zeichen.drehspanne <= 0.01 {
            text += "Im Buch ist die Drehung ausgeschaltet, deshalb ist das 0\u{00B0} \u{2014} "
            text += "ein eigener Winkel gilt hier trotzdem. "
        } else {
            text += "Sie zieht ihn aus der Kennung der Seite, "
            text += "innerhalb der eingestellten Spanne; jede Seite bekommt damit einen "
            text += "anderen, und beim nächsten Öffnen wieder denselben. "
        }
        text += "Ein eigener Winkel hier schlägt sie."
        return text
    }

    private var versatzhinweis: String {
        var text = "Gemessen von der Stelle aus, die die Automatik gefunden hat \u{2014} "
        text += "0 mm heißt also: dort, wo es ohnehin läge. "
        text += "Das Zeichen bleibt dabei IM SATZSPIEGEL: Was darüber hinausginge, wird "
        text += "an der Kante gehalten, denn im Druck wäre es sonst angeschnitten. "
        text += "Nach einem Neuanordnen des Tages bleibt die Korrektur an der STELLE im Tag "
        text += "\u{2014} die Seite selbst ist danach eine andere, und die Automatik sucht "
        text += "für sie neu."
        return text
    }

    // MARK: - Handgriffe

    private func aendern(_ arbeit: (inout Wasserzeichenabweichung) -> Void) {
        guard let t = werk.tagIndex(tagID),
              werk.reise.tage[t].seiten.indices.contains(stelle) else { return }
        var abweichung = werk.reise.tage[t].seiten[stelle].wasserzeichen
            ?? Wasserzeichenabweichung()
        arbeit(&abweichung)
        // Eine Abweichung, die nichts mehr sagt, wird wieder `nil` — sonst
        // stünde in der Datei ein Eintrag, der nichts bedeutet, und die
        // Zählung in der Druckprüfung meldete eine Korrektur, die keine ist.
        werk.reise.tage[t].seiten[stelle].wasserzeichen = abweichung.gesetzt ? abweichung : nil
    }

    private func zuruecksetzen() {
        guard let t = werk.tagIndex(tagID),
              werk.reise.tage[t].seiten.indices.contains(stelle) else { return }
        werk.merken()
        werk.reise.tage[t].seiten[stelle].wasserzeichen = nil
    }
}

// Eine SKIZZE der Seite — kein zweiter Zeichenweg.
//
// Gezeigt wird, was `Wasserzeichenlage.ort` sagt: derselbe Rahmen, derselbe
// Winkel, dasselbe Bild. Die Blöcke stehen als graue Flächen da, weil es
// hier um die Frage geht, was das Zeichen verdeckt — und nicht darum, wie
// die Seite aussieht. Wer das sehen will, macht das Blatt zu.
private struct Skizze: View {
    var seite: Seite
    var zeichen: Wasserzeichen
    var satz: CGRect
    var format: Seitenformat
    var reise: UUID

    var body: some View {
        GeometryReader { raum in
            let bogen = format.groesse
            let faktor = min(Double(raum.size.width) / max(Double(bogen.width), 1),
                             Double(raum.size.height) / max(Double(bogen.height), 1))
            let breite = Double(bogen.width) * faktor
            let hoehe = Double(bogen.height) * faktor
            let ort = Wasserzeichenlage.ort(zeichen, satz: satz, seite: seite)
            ZStack(alignment: .topLeading) {
                Color.clear
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    rechteck(satz, faktor: faktor)
                        .stroke(Color.secondary.opacity(0.35), style:
                            StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    ForEach(seite.bloecke) { block in
                        rechteck(block.rahmen.rect, faktor: faktor)
                            .fill(Color.primary.opacity(0.14))
                    }
                    bildchen(ort, faktor: faktor)
                }
                .frame(width: breite, height: hoehe)
                .clipped()
                .overlay(Rectangle().stroke(Color.secondary.opacity(0.5), lineWidth: 0.5))
                .offset(x: (Double(raum.size.width) - breite) / 2,
                        y: (Double(raum.size.height) - hoehe) / 2)
            }
        }
        .padding(10)
    }

    private func rechteck(_ quelle: CGRect, faktor: Double) -> Path {
        Path(CGRect(x: Double(quelle.minX) * faktor, y: Double(quelle.minY) * faktor,
                    width: Double(quelle.width) * faktor,
                    height: Double(quelle.height) * faktor))
    }

    @ViewBuilder
    private func bildchen(_ ort: Wasserzeichenlage.Ort, faktor: Double) -> some View {
        let rahmen = CGRect(x: Double(ort.bildrahmen.minX) * faktor,
                            y: Double(ort.bildrahmen.minY) * faktor,
                            width: Double(ort.bildrahmen.width) * faktor,
                            height: Double(ort.bildrahmen.height) * faktor)
        if let zeichenbild = ort.bild,
           let bild = Bildarchiv.shared.vorschau(zeichenbild.datei, reise: reise, kante: 400)
        {
            Image(uiImage: bild)
                .resizable()
                .scaledToFit()
                .frame(width: rahmen.width, height: rahmen.height)
                .rotationEffect(.degrees(ort.winkel))
                .opacity(max(zeichen.deckung, 0.25))
                .offset(x: rahmen.minX, y: rahmen.minY)
        } else {
            Rectangle()
                .fill(Color.accentColor.opacity(0.3))
                .frame(width: rahmen.width, height: rahmen.height)
                .rotationEffect(.degrees(ort.winkel))
                .offset(x: rahmen.minX, y: rahmen.minY)
        }
    }
}
