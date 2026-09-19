import SwiftUI

/// Die Dauer einer Verbindung als Balken — im Verhältnis zur längsten in
/// derselben Liste.
///
/// **Warum es das gibt** (ab 1.1.19, Ansage des Nutzers 09/2026: „Es wäre
/// schön, wenn man die angezeigten Verbindungen schnell hinsichtlich ihrer
/// Dauer vergleichen könnte."). Rechts an jeder Zeile steht „2 h 3 min" — das
/// ist die Auskunft, aber kein Vergleich: Sechs solcher Angaben untereinander
/// muss man lesen und im Kopf voneinander abziehen. Eine Länge sieht man.
///
/// **Der naheliegende Weg wäre gewesen, die KETTE DER LINIENSCHILDER zu
/// stauchen** — so hat der Nutzer es vorgeschlagen, und so machen es andere
/// Apps. Nachgezählt an seinem eigenen Bildschirmfoto (Duisburg
/// Großenbaum, 19.09.2026) geht das nicht auf:
///
/// | Verbindung | Dauer | Schilder |
/// |---|---|---|
/// | 11:01 → 13:04 | 2 h 3 min (die längste) | 3 (470, RE6, S1) |
/// | 12:14 → 13:34 | 1 h 20 min (die kürzeste) | 4 (S4, S2, RE1, S1) |
///
/// Die KÜRZESTE Verbindung hat also die MEISTEN Schilder. Auf 65 % der Breite
/// gestaucht müsste ihre Kette schmaler sein als die der längsten und dabei
/// ein Schild mehr tragen — es bliebe nur, die Schilder zu verkleinern oder
/// abzuschneiden. Beides trifft genau das, was diese Zeile ausmacht: „Die
/// Linienschilder SIND die Ergebniszeile." Deshalb tragen sie unverändert
/// ihre volle Größe, und die Länge bekommt eine eigene Zeile.
///
/// **Der Balken ist die Zeitachse DIESER Verbindung.** Jeder Abschnitt liegt
/// dort, wo er wirklich liegt (`start`/`ende`), und die Lücken dazwischen sind
/// die Wartezeit. Nur die Abschnitte zu zeichnen wäre falsch: Sie summieren
/// sich nicht zur Gesamtdauer — zwischen zwei Fahrten steht man am Bahnsteig,
/// und in der Liste des Nutzers ist das ein gutes Viertel der Reise.
///
/// **Verglichen wird nur die LÄNGE, nicht der Zeitpunkt.** Jeder Balken
/// beginnt bei seiner eigenen Abfahrt und nicht auf einer gemeinsamen Uhr.
/// Eine gemeinsame Achse sagte zusätzlich, wer zuerst ankommt — sie schöbe
/// aber jede spätere Verbindung nach rechts, und bei anderthalb Stunden
/// Spanne bliebe von den Balken wenig übrig. Gefragt war der Vergleich der
/// Dauer; die Fußzeile schreibt hin, dass es genau der ist.
struct Dauerbalken: View {
    let verbindung: Verbindung
    /// Die längste Dauer in der gezeigten Liste — der Maßstab. Ist sie 0 oder
    /// kleiner, wird gar nichts gezeichnet: Ein Balken ohne Maßstab wäre eine
    /// Länge, die nichts bedeutet.
    let laengsteDauer: TimeInterval

    private let hoehe: CGFloat = 7

    var body: some View {
        if laengsteDauer > 0, verbindung.dauer > 0 {
            GeometryReader { flaeche in
                let ganz = flaeche.size.width
                let anteil = min(verbindung.dauer / laengsteDauer, 1)
                let breite = ganz * anteil

                ZStack(alignment: .leading) {
                    // Die volle Breite, ganz blass: So lang wäre die längste
                    // Verbindung dieser Liste. Ohne sie schwebte ein kurzer
                    // Balken im Nichts, und man sähe nur den Vergleich zu den
                    // Nachbarzeilen, nicht den zum Maßstab.
                    Capsule()
                        .fill(Color.primary.opacity(0.07))

                    // Diese Verbindung. Der Grund darunter ist die WARTEZEIT
                    // — er ist mit Absicht sichtbar und nicht weiß: Wer eine
                    // Verbindung wählt, will wissen, wie viel davon Stehen
                    // am Bahnsteig ist.
                    Capsule()
                        .fill(Color.primary.opacity(0.18))
                        .frame(width: breite)

                    ForEach(verbindung.abschnitte) { abschnitt in
                        let von = anfang(abschnitt) * breite
                        let bis = ende(abschnitt) * breite
                        RoundedRectangle(cornerRadius: hoehe / 2, style: .continuous)
                            .fill(farbe(abschnitt))
                            // Ein Abschnitt, der ausfällt, wird blass — die
                            // Farbe bleibt seine. Ihn rot zu färben hieße,
                            // einer Linienfarbe eine zweite Bedeutung zu
                            // geben, und Rot IST hier eine Linienfarbe (RE1).
                            // Gesagt wird der Ausfall ohnehin zweimal: als
                            // Band über der Zeile und als Kreuz am Schild.
                            .opacity(abschnitt.faelltAus ? 0.3 : 1)
                            .frame(width: max(bis - von, 0))
                            .offset(x: von)
                    }
                }
            }
            .frame(height: hoehe)
            // Für VoiceOver sagt die Zeile schon „2 h 3 min" — eine
            // zusätzliche Ansage „Balken, 65 Prozent" wäre Lärm. Der Balken
            // ist hier das Bild zur Zahl und nicht die Zahl selbst.
            .accessibilityHidden(true)
        }
    }

    /// Wo ein Abschnitt auf der Achse dieser Verbindung beginnt — als Anteil
    /// zwischen 0 und 1.
    private func anfang(_ abschnitt: Verbindungsabschnitt) -> Double {
        anteil(abschnitt.start)
    }

    private func ende(_ abschnitt: Verbindungsabschnitt) -> Double {
        anteil(abschnitt.ende)
    }

    /// Geschnitten wird auf 0…1. Eine Quelle, die einen Abschnitt vor der
    /// gemeldeten Abfahrt oder nach der Ankunft führt, darf den Balken nicht
    /// über seine Länge hinausschieben — sonst wäre er länger, als die Dauer
    /// daneben sagt, und der Vergleich wäre still falsch.
    private func anteil(_ zeitpunkt: Date) -> Double {
        let versetzt = zeitpunkt.timeIntervalSince(verbindung.abfahrt)
        return min(max(versetzt / verbindung.dauer, 0), 1)
    }

    private func farbe(_ abschnitt: Verbindungsabschnitt) -> Color {
        guard abschnitt.art == .fahrt, let linie = abschnitt.linie else {
            // Ein Fußweg trägt keine Linienfarbe und bekommt hier auch keine
            // erfundene. Er ist dunkler als die Wartezeit und blasser als
            // eine Fahrt — dazwischen, wie er es auch ist.
            return .primary.opacity(0.42)
        }
        return linie.anzeigefarbe
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 18) {
        ForEach(Musterdienst.beispielverbindungen) { verbindung in
            VStack(alignment: .leading, spacing: 6) {
                Text(verbindung.abfahrt, format: .dateTime.hour().minute())
                    .monospacedDigit()
                Dauerbalken(
                    verbindung: verbindung,
                    laengsteDauer: Musterdienst.beispielverbindungen.map(\.dauer).max() ?? 0
                )
            }
        }
    }
    .padding()
}
