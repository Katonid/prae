import SwiftUI

// Zwei Seiten, wie sie im aufgeschlagenen Buch nebeneinanderliegen.
//
// Gewünscht 09/2026: „Ein Buch hat ja Seiten mit Vorder- und Rückseite. Und
// auf das Titelblatt kommt ja zunächst einmal die Innenseite des Hardcovers,
// bevor die erste wirkliche Buchseite anfängt."
//
// Gezeichnet wird mit `spacing: 0`: Im gebundenen Buch stoßen zwei
// gegenüberliegende Seiten am Bund aneinander. Was dazwischen als heller
// Streifen stehen bleibt, ist der ANSCHNITT beider Seiten — der wird
// weggeschnitten, und wo er endet, zeigt die rote Schnittkante („…“ →
// „Satzspiegel zeigen"). Ein Abstand dazwischen wäre bequemer zu zeichnen
// und würde eine Lücke behaupten, die das Buch nicht hat.
struct DoppelseiteView: View {
    @ObservedObject var werk: Reisewerk
    let bogen: Reisewerk.Doppelseite
    var massstab: Double

    private var bogenmass: CGSize { werk.reise.gestaltung.bogen(werk.reise.format) }

    // DER UMSCHLAGBOGEN (ab 1.0.50) ist seit 1.0.52 der Bogen mit der
    // Nummer 0 und steht damit außerhalb der Zählung des Buchblocks. Bis
    // dahin wurde er an der Seitennummer 0 erkannt — und genau diese
    // Mitzählung schob die erste wirkliche Buchseite auf die linke Hälfte.
    private var istUmschlagbogen: Bool { bogen.istUmschlag }

    private var rueckentext: String {
        werk.reise.umschlag.rueckenbeschriftung(titel: werk.reise.titel)
    }

    private var rueckenbreite: Double {
        guard istUmschlagbogen else { return 0 }
        return Umschlagmass.rueckenbreitePt(werk.reise.umschlag,
                                            format: werk.reise.format,
                                            innenseiten: werk.reise.innenseiten)
    }

    var body: some View {
        VStack(spacing: Buehnenmasse.beschriftungsabstand) {
            ZStack(alignment: .topLeading) {
                // DER HINTERGRUND DES UMSCHLAGS LÄUFT DURCH (ab 1.0.63).
                //
                // Ansage des Nutzers, 09/2026: „Es soll mir zum Beispiel
                // auch möglich sein, dort eigene Felder oder Bilder zu
                // positionieren oder ganz einfach das Hintergrundbild von
                // Deckblatt und Rückseite durchlaufen zu lassen."
                //
                // Im PDF lief es schon immer durch: `umschlagPdf` legt den
                // Grund über den GANZEN Bogen, samt Rücken. Auf dem
                // Bildschirm zeichnete bis 1.0.62 jede Hälfte ihren eigenen,
                // und dazwischen lag der Rücken als graue Fläche — die
                // Ansicht zeigte also etwas anderes als die Datei, und genau
                // das ist die Trennung, die die erste Regel dieser App
                // verbietet. Jetzt ist es EIN Bild über Rückseite, Rücken
                // und Titelseite, und die beiden Hälften lassen ihren Grund
                // weg (`ohneGrund`).
                if istUmschlagbogen {
                    umschlaggrund
                }
                HStack(alignment: .top, spacing: 0) {
                    seite(bogen.links, umschlag: bogen.beginntMitUmschlag, vorn: true)
                    if rueckenbreite > 0.5 {
                        Ruecken(text: rueckentext,
                                typografie: werk.reise.typografie,
                                umschlag: werk.reise.umschlag,
                                breite: rueckenbreite,
                                laenge: Double(bogenmass.height),
                                massstab: massstab)
                    }
                    seite(bogen.rechts, umschlag: bogen.endetMitUmschlag, vorn: false)
                }
            }
            beschriftung
        }
    }

    // Der Grund des ganzen Umschlagbogens — dieselbe Fläche, die das PDF
    // beschreibt: zwei Endformate, der Rücken dazwischen und ringsum der
    // Anschnitt. `liegtRechts: nil` heißt „keine Doppelseite": Hier ist
    // der Bogen schon das Ganze, es gibt keine Nachbarseite, über die
    // etwas laufen könnte.
    private var umschlaggrund: some View {
        let a = werk.reise.gestaltung.anschnittPt
        // Gezeichnet wird über die Fläche, die WIRKLICH dasteht: zwei
        // Bogen — jeder mit seinem eigenen Anschnitt — und der Rücken
        // dazwischen. Der gedruckte Umschlag ist um zwei Anschnitte
        // SCHMALER, denn innen stoßen die Hälften aneinander; hier stehen
        // beide, wie in jeder Doppelseite dieser Ansicht seit 1.0.17. Das
        // Bild ist damit auf dem Bildschirm eine Spur breiter gezeigt, als
        // es gedruckt wird — bei 3 mm Anschnitt gut ein Prozent. Das ist
        // eine Ungenauigkeit der ANSICHT und keine der Datei; sie steht
        // hier, statt sie zu verschweigen.
        let breite = 2 * (Double(werk.reise.format.groesse.width) + 2 * a) + rueckenbreite
        let hoehe = Double(werk.reise.format.groesse.height) + 2 * a
        var grund = werk.reise.umschlag.hintergrund ?? werk.reise.gestaltung.hintergrund
        // Über die Doppelseite ist hier nichts zu verteilen: Der Bogen IST
        // schon das Ganze. Dieselbe Zeile steht im PDF (`umschlagPdf`).
        grund.ueberDoppelseite = false
        return HintergrundFlaeche(
            werk: werk,
            hintergrund: grund,
            seite: bogen.rechts?.seite ?? bogen.links?.seite ?? Seite(),
            format: CGSize(width: breite - 2 * a, height: hoehe - 2 * a),
            anschnitt: a,
            bogen: CGSize(width: breite, height: hoehe),
            liegtRechts: nil,
            massstab: massstab
        )
        .scaleEffect(massstab, anchor: .topLeading)
        .frame(width: breite * massstab, height: hoehe * massstab, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func seite(_ buchseite: Buchseite?, umschlag: Bool, vorn: Bool) -> some View {
        if let buchseite {
            SeitenflaecheView(werk: werk, buchseite: buchseite,
                              ohneGrund: istUmschlagbogen, massstab: massstab)
                // Siehe `SeitenflaecheView.==`: Der Körper dieser Ansicht
                // läuft bei jedem Bildpunkt der Zoomgeste mit, und ohne
                // den Vergleich zöge er beide Seiten des Bogens mit.
                .equatable()
        } else if umschlag {
            UmschlagInnenseite(groesse: bogenmass, massstab: massstab, vorn: vorn)
        } else {
            // Keine Seite und kein Umschlag: Das gibt es nach der Bauweise
            // von `doppelseiten` nicht. Der Platz bleibt trotzdem stehen,
            // damit der Bund in der Mitte bleibt.
            Color.clear
                .frame(width: bogenmass.width * massstab, height: bogenmass.height * massstab)
        }
    }

    private var beschriftung: some View {
        // FESTE Höhe — `Zoomanker` rechnet mit ihr, damit der Zoom um den
        // Mittelpunkt der Geste nicht auf einer Schätzung steht.
        Text(zeile)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(height: Buehnenmasse.beschriftung)
    }

    private var zeile: String {
        if istUmschlagbogen {
            let mm = Umschlagmass.rueckenbreite(werk.reise.umschlag,
                                                format: werk.reise.format,
                                                innenseiten: werk.reise.innenseiten)
            var text = "Umschlag \u{00B7} Rückseite und Titelseite"
            if mm > 0.05 {
                let zahl = String(format: "%.1f", mm).replacingOccurrences(of: ".", with: ",")
                text += " \u{00B7} Rücken \(zahl) mm"
            }
            return text
        }
        let links = bogen.links.map { "\($0.nummer)" }
        let rechts = bogen.rechts.map { "\($0.nummer)" }
        switch (links, rechts) {
        case let (nil, .some(r)):
            return "Umschlag innen \u{00B7} Seite \(r)"
        case let (.some(l), nil):
            return "Seite \(l) \u{00B7} Umschlag innen"
        case let (.some(l), .some(r)):
            return "Seiten \(l) und \(r)"
        default:
            return ""
        }
    }
}

// Die Innenseite des Umschlags — gezeigt, aber nicht gedruckt.
//
// Beim Hardcover ist das das Vorsatzpapier, und das liefert die Druckerei;
// es steht in keinem PDF und zählt in keiner Seitenzahl. Gezeigt wird es
// trotzdem, weil sonst die Seite 1 links läge und damit falsch: Sie ist
// eine RECHTE Seite. Und es steht dabei, was es ist — eine leere graue
// Fläche ohne ein Wort hielte man für einen Fehler.
struct UmschlagInnenseite: View {
    let groesse: CGSize
    let massstab: Double
    let vorn: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(.secondarySystemGroupedBackground))
            VStack(spacing: 6) {
                Image(systemName: "book.closed")
                    .font(.system(size: 22))
                Text(vorn ? "Innenseite des Umschlags" : "Innenseite des Rückens")
                Text("Kommt von der Druckerei \u{2013} nicht im PDF")
                    .font(.caption2)
            }
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(.tertiary)
            .padding(12)
        }
        .frame(width: groesse.width * massstab, height: groesse.height * massstab)
        .overlay {
            Rectangle()
                .strokeBorder(style: StrokeStyle(lineWidth: 0.8, dash: [5, 4]))
                .foregroundStyle(.quaternary)
        }
        .allowsHitTesting(false)
    }
}

// DER RÜCKEN — der Streifen, der die Dicke des Buches ausmacht.
//
// Ansage des Nutzers, 09/2026: „Vielleicht findest du auch noch eine
// Lösung dafür, dass bei Saal Digital normalerweise beim Umschlag auch
// festgelegt werden kann, was an die Seite des Buches … drauf gedruckt
// werden kann. Bislang habe ich dort immer den Titel des Buches
// untergebracht."
//
// Wie breit er ist, rechnet `Umschlagmass` — dieselbe Funktion, die auch
// das PDF fragt. Gezeichnet wird er zwischen den beiden Umschlagseiten,
// also genau dort, wo er im fertigen Buch liegt.
//
// Von oben nach unten ist hierzulande die Gepflogenheit: Ein Buch, das
// flach auf dem Tisch liegt, soll sich mit dem Titel nach oben lesen
// lassen. Seit 1.0.63 ist das aber ein SCHALTER und keine Regel (Ansage
// des Nutzers: „Im konkreten Fall hätte ich sie nämlich gerne um 180 Grad
// gedreht"), und wo die Schrift auf dem Rücken steht, ist ein Anteil.
// Beides rechnet `Rueckensatz` — dieselbe Stelle, die auch das PDF fragt.
//
// SCHRIFT UND GRÖSSE KOMMEN AUS DEM BUCH. Bis 1.0.62 stand hier eine feste
// Bildschirmschrift („max(6, min(breite · 0,6, 13))") auf grauem Grund,
// während das PDF mit der Typografie des Buches setzte: zwei Fassungen
// desselben Rückens, die nichts miteinander zu tun hatten. Gezeichnet wird
// jetzt mit demselben `Textkasten`, mit dem auch jede Seite gesetzt wird.
struct Ruecken: View {
    let text: String
    let typografie: Typografie
    let umschlag: Umschlag
    let breite: Double
    /// Die LÄNGE des Rückens — die Höhe des Bogens.
    let laenge: Double
    let massstab: Double

    // Gemessen wird EINMAL je Änderung und nicht im Körper: Dahinter
    // steckt ein voller CoreText-Satz, und dieser Körper läuft bei jedem
    // Bildpunkt einer Zoomgeste mit.
    @State private var texthoehe: Double = 0
    @State private var textlaenge: Double = 0

    private var bild: Schriftbild {
        Rueckensatz.schriftbild(typografie: typografie, umschlag: umschlag, breite: breite)
    }

    private var schluessel: String {
        // NICHT über `hashValue`: Den streut Swift je Programmlauf neu.
        // Gebraucht wird er hier zwar nur innerhalb einer Sitzung, aber die
        // Regel steht in diesem Papier ohne Ausnahme, und eine Ausnahme
        // wäre morgen der Grund für die nächste.
        var teile: [String] = [text]
        teile.append(String(format: "%.2f", breite))
        teile.append(String(format: "%.2f", laenge))
        teile.append(String(format: "%.2f", bild.groesse))
        teile.append(bild.familie.familienname ?? "system")
        teile.append(bild.familie.schnitt ?? "")
        return teile.joined(separator: "|")
    }

    var body: some View {
        // Der Rücken ist DURCHSICHTIG (ab 1.0.63): Darunter liegt der
        // Hintergrund des Umschlagbogens, und der läuft durch. Bis 1.0.62
        // stand hier eine graue Fläche — gemeldet 09/2026: „Im vorliegenden
        // Beispiel hat es den Eindruck, dass der Buchrücken in einem dunklen
        // Grau gestaltet ist."
        ZStack {
            Color.clear
            if texthoehe > 0 {
                Textkasten(text: text, bild: bild, massstab: massstab)
                    .frame(width: max(textlaenge, 1), height: texthoehe)
                    .rotationEffect(.degrees(umschlag.rueckenrichtung.grad))
                    .offset(y: versatz)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: breite, height: laenge)
        .scaleEffect(massstab, anchor: .topLeading)
        .frame(width: breite * massstab, height: laenge * massstab, alignment: .topLeading)
        // Ein langer Titel auf einem schmalen Rücken ragte sonst über die
        // Nachbarseiten — auf dem Papier ist der Rücken genau so breit,
        // wie er breit ist.
        .clipped()
        .overlay {
            // Die beiden Falze. Sie sind keine Schnittkanten — der Bogen
            // wird dort GEFALTET —, und deshalb sind sie punktiert und
            // nicht rot gestrichelt wie die Schnittkante.
            HStack(spacing: 0) {
                Rectangle().frame(width: 0.7).foregroundStyle(.quaternary)
                Spacer(minLength: 0)
                Rectangle().frame(width: 0.7).foregroundStyle(.quaternary)
            }
        }
        .allowsHitTesting(false)
        .task(id: schluessel) {
            texthoehe = min(Textmass.hoehe(text, bild: bild, breite: laenge), breite)
            textlaenge = Textmass.breite(text, bild: bild, hoechstens: laenge)
        }
    }

    // Wie weit der Kasten aus der Mitte des Rückens wandert.
    //
    // Gerechnet wird die Lage in `Rueckensatz` — derselben Stelle, die das
    // PDF fragt —, und dort liegt die x-Achse ENTLANG des Rückens. Auf dem
    // Bildschirm zeigt sie nach dem Drehen nach unten (bei „von oben nach
    // unten") oder nach oben; quer dazu steht der Kasten ohnehin mittig,
    // deshalb bleibt nur diese eine Verschiebung.
    private var versatz: Double {
        let platz = Rueckensatz.rechteck(laenge: laenge, breite: breite,
                                         textlaenge: textlaenge, texthoehe: texthoehe,
                                         lage: umschlag.rueckenlage)
        let entlang = Double(platz.midX) - laenge / 2
        return umschlag.rueckenrichtung == .obenNachUnten ? entlang : -entlang
    }
}
