import SwiftUI

/// Eine Zeile der Abfahrtstafel: Schild — Ziel — Minutenziffer.
///
/// Die Aufteilung ist die einer Anzeigetafel am Bahnsteig und nicht die einer
/// Listenzeile: Die Ziffer steht rechts, groß, mit gleich breiten Ziffern
/// (`monospacedDigit`). Ohne das springt die Spalte bei jedem Weiterzählen um
/// ein paar Punkte, und eine Liste, die im Sekundentakt zuckt, liest sich
/// schlecht.
struct AbfahrtsZeile: View {
    let abfahrt: Abfahrt
    let jetzt: Date
    /// Bei der Tafel „Alle in der Nähe" steht die Haltestelle mit in der
    /// Zeile; in der Tafel EINER Haltestelle wäre sie fünfzehnmal dieselbe.
    var zeigtHaltestelle: Bool = false
    /// Der Stand kommt aus dem Zwischenspeicher und ist alt. Dann wird die
    /// Minutenziffer NICHT gezeigt: Sie ist die einzige Angabe der Zeile, die
    /// fortlaufend etwas behauptet, und eine weiterzählende Ziffer über alten
    /// Daten ist eine Lüge, die wie eine Auskunft aussieht.
    var standIstAlt: Bool = false
    /// Die Tafel gilt für einen GEWÄHLTEN Zeitpunkt und nicht für jetzt (ab
    /// 1.1.11). Dann gibt es ebenfalls keine Minutenziffer: „in 3 Minuten"
    /// über einer Tafel für morgen früh wäre schlicht falsch, und zwar auf
    /// dieselbe Art wie eine weiterzählende Ziffer über altem Stand. Die
    /// Abfahrtszeit selbst steht links und genügt.
    var fuerGewaehlteZeit: Bool = false
    /// Die Quelle steht nur dann an der Zeile, wenn die Tafel aus MEHREREN
    /// kommt. Unter einer Tafel aus einer einzigen Quelle wäre sie
    /// fünfzehnmal dasselbe Wort.
    var zeigtQuelle: Bool = false
    /// Zu dieser Linie liegt eine Betriebsmeldung vor (Umleitung, Sperrung,
    /// Ersatzverkehr). `nil` heißt „keine" — und das ist etwas anderes als
    /// „nicht nachgesehen", was die Fußzeile trennt.
    var meldung: Betriebsmeldung?

    var body: some View {
        HStack(spacing: 12) {
            Liniensymbol(linie: abfahrt.linie)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    if let meldung {
                        Meldungsmarke(dringend: meldung.dringend)
                    }
                    Text(abfahrt.richtung)
                        .font(.body.weight(.medium))
                        .strikethrough(abfahrt.faelltAus, color: .secondary)
                        .foregroundStyle(abfahrt.faelltAus ? Color.secondary : Color.primary)
                }
                .lineLimit(1)

                HStack(spacing: 6) {
                    if zeigtHaltestelle {
                        Text(abfahrt.haltestelle.name)
                            .lineLimit(1)
                    }
                    if let steig = abfahrt.steig {
                        if zeigtHaltestelle { Text("·") }
                        Text(steig)
                    }
                    if zeigtHaltestelle || abfahrt.steig != nil { Text("·") }
                    Zeitangabe(abfahrt: abfahrt)
                    if zeigtQuelle {
                        Text("· \(abfahrt.quelle)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if standIstAlt {
                Text("alt")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 62, alignment: .trailing)
            } else if fuerGewaehlteZeit {
                // Leer, aber gleich breit: Sonst rückten die Zeilen einer
                // Tafel für später gegenüber jeder anderen ein.
                Color.clear.frame(width: 62, height: 1)
            } else {
                Minutenziffer(abfahrt: abfahrt, jetzt: jetzt)
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(vorgelesen)
    }

    private var vorgelesen: String {
        var teile = ["\(abfahrt.linie.mittel.name) \(abfahrt.linie.name) nach \(abfahrt.richtung)"]
        if zeigtHaltestelle { teile.append("ab \(abfahrt.haltestelle.name)") }
        if standIstAlt {
            teile.append("alter Stand")
        }
        if meldung != nil {
            teile.append("Betriebsmeldung liegt vor")
        }
        if abfahrt.faelltAus {
            teile.append("fällt aus")
        } else if standIstAlt || fuerGewaehlteZeit {
            teile.append("geplant \(abfahrt.geplant.formatted(date: .omitted, time: .shortened))")
        } else {
            let minuten = abfahrt.minutenBis(jetzt)
            teile.append(minuten <= 0 ? "fährt jetzt" : "in \(minuten) Minuten")
            if abfahrt.hatAbweichung {
                let v = abfahrt.verspaetungMinuten
                teile.append(v > 0 ? "\(v) Minuten später" : "\(-v) Minuten früher")
            } else if !abfahrt.istEchtzeit {
                teile.append("Planzeit ohne Echtzeit")
            }
        }
        return teile.joined(separator: ", ")
    }
}

/// Die Uhrzeit, und daneben die Abweichung.
///
/// Drei Fälle, und alle drei sehen verschieden aus, weil sie Verschiedenes
/// bedeuten:
///
/// - **Echtzeit und pünktlich:** die Uhrzeit, sonst nichts.
/// - **Echtzeit und abweichend:** die PLANZEIT durchgestrichen, dahinter die
///   Abweichung und die geltende Zeit in Rot beziehungsweise Blau, beide
///   halbfett. Nur die neue Zeit zu zeigen wäre bequemer und verschwiege, dass
///   es eine Verspätung gibt — und wer den Fahrplan im Kopf hat, hielte die App
///   für falsch. Die durchgestrichene Planzeit darf aber nie die
///   auffälligere von beiden sein: Gefahren wird nach der neuen.
/// - **Ohne Echtzeit:** die Planzeit mit dem Wort „Plan" daneben. Das ist der
///   wichtigste der drei: Eine Zeit ohne Echtzeitmeldung sieht genauso aus wie
///   eine pünktliche, ist aber etwas völlig anderes. Ein grünes „pünktlich"
///   für „nicht nachgesehen" wäre die teuerste Lüge, die diese App erzählen
///   kann.
struct Zeitangabe: View {
    let abfahrt: Abfahrt

    var body: some View {
        HStack(spacing: 4) {
            Text(abfahrt.geplant, format: .dateTime.hour().minute())
                .monospacedDigit()
                .strikethrough(abfahrt.hatAbweichung, color: .secondary)

            if abfahrt.faelltAus {
                Text("fällt aus")
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
            } else if abfahrt.hatAbweichung {
                let minuten = abfahrt.verspaetungMinuten
                Text(minuten > 0 ? "+\(minuten)" : "\(minuten)")
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(minuten > 0 ? Color.red : Color.blue)
                // Halbfett wie die Abweichung daneben: Die GELTENDE Zeit ist
                // die Auskunft, die Planzeit davor nur noch die Erklärung.
                // Gleich groß bleiben beide — in einer Zeile nebeneinander
                // wäre ein Größenunterschied Unruhe und kein Hinweis.
                Text(abfahrt.tatsaechlich, format: .dateTime.hour().minute())
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(minuten > 0 ? Color.red : Color.blue)
            } else if !abfahrt.istEchtzeit {
                Text("Plan")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Die Minutenziffer rechts — das, worauf am Bahnsteig wirklich geschaut wird.
struct Minutenziffer: View {
    let abfahrt: Abfahrt
    let jetzt: Date

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(abfahrt.minutentext(jetzt))
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(farbe)
            if abfahrt.zeigtMinutenwort(jetzt) {
                Text("min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        // Feste Breite, damit die Ziffern aller Zeilen untereinander stehen.
        // Ohne sie wandert die Spalte, sobald irgendwo „jetzt" auftaucht.
        .frame(minWidth: 62, alignment: .trailing)
    }

    private var farbe: Color {
        if abfahrt.faelltAus { return .secondary }
        let minuten = abfahrt.minutenBis(jetzt)
        // Unter zwei Minuten orange: Das ist die Schwelle, ab der Losgehen
        // und Sitzenbleiben verschiedene Entscheidungen sind. Nicht rot — rot
        // gehört in dieser App der Verspätung, und zwei Bedeutungen für eine
        // Farbe sind keine.
        if minuten <= 1 { return .orange }
        return .primary
    }
}

#Preview {
    List {
        ForEach(Musterdienst.beispielabfahrten()) { abfahrt in
            AbfahrtsZeile(abfahrt: abfahrt, jetzt: Date(), zeigtHaltestelle: true)
        }
    }
}
