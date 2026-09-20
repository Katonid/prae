import SwiftUI

/// Eine Verbindung in der Ergebnisliste.
///
/// Oben die beiden Zeiten, darunter die Linien in Fahrtrichtung. Die
/// Linienschilder sind die Zeile: Wer zwischen fünf Vorschlägen wählt,
/// entscheidet nach „S1 oder zweimal umsteigen" und nicht nach Minuten.
///
/// **Ganz unten der `Dauerbalken`** (ab 1.1.19): die Zahl rechts oben ist die
/// Auskunft, der Balken der Vergleich. Warum er eine eigene Zeile bekommt und
/// nicht die Schilderkette staucht, steht dort.
struct VerbindungsZeile: View {
    let verbindung: Verbindung
    let jetzt: Date
    /// Die längste Dauer der gezeigten Liste — der Maßstab des Balkens. 0
    /// heißt „kein Maßstab", dann bleibt der Balken weg.
    var laengsteDauer: TimeInterval = 0
    /// Ob der Deutschland-Ticket-Filter an ist. Nur dann steht der
    /// Grenzhinweis an der Zeile: Wer ohne Filter sucht, hat die Frage nach
    /// dem Fahrschein gerade nicht gestellt, und eine Zeile mehr an jeder
    /// Auslandsverbindung wäre dann bloß Lärm.
    var mitTicketfilter: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbindung.abfahrt, format: .dateTime.hour().minute())
                    .monospacedDigit()
                    .fontWeight(.semibold)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(verbindung.ankunft, format: .dateTime.hour().minute())
                    .monospacedDigit()
                    .fontWeight(.semibold)

                if let minuten = verbindung.verspaetungMinuten {
                    Text(minuten > 0 ? "+\(minuten)" : "\(minuten)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(minuten > 0 ? Color.red : Color.blue)
                } else if !verbindung.hatEchtzeit {
                    // Dieselbe Regel wie an einer Abfahrt: „Plan" ist nicht
                    // „pünktlich". Ein stilles Weglassen sähe aus wie eine
                    // bestätigte Zeit.
                    Text("Plan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Text(dauertext)
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            if verbindung.faelltAus {
                Label("Ein Abschnitt dieser Verbindung fällt aus", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }

            // Die Kette der Linien. Fußwege stehen als Gehsymbol dazwischen —
            // ohne sie sähe ein Vorschlag mit zwanzig Minuten Fußweg genauso
            // aus wie einer, bei dem man am Bahnsteig gegenüber umsteigt.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(verbindung.abschnitte) { abschnitt in
                        if abschnitt.art == .fussweg {
                            HStack(spacing: 2) {
                                Image(systemName: "figure.walk")
                                if let meter = abschnitt.meter, meter >= 50 {
                                    Text(Haltestelle.entfernungstext(Double(meter)))
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        } else if let linie = abschnitt.linie {
                            // **Mit dem Symbol des Verkehrsmittels** (ab
                            // 1.1.29). Genau hier fiel es auf: Bei „nur
                            // Busse" standen in jedem Vorschlag Schilder mit
                            // „RE1" — Schienenersatzverkehr, gemessen als
                            // `mode = BUS`. Die Schilderkette IST diese
                            // Zeile, also muss sie das Verkehrsmittel sagen.
                            Liniensymbol(linie: linie, mitMittel: true)
                                .opacity(abschnitt.faelltAus ? 0.45 : 1)
                                .overlay {
                                    if abschnitt.faelltAus {
                                        Image(systemName: "xmark")
                                            .font(.headline.weight(.black))
                                            .foregroundStyle(.red)
                                    }
                                }
                        }
                    }
                }
                .padding(.vertical, 1)
            }

            Dauerbalken(verbindung: verbindung, laengsteDauer: laengsteDauer)

            // **Ersatzverkehr steht an der ZEILE, nicht am Schild** (ab
            // 1.1.30). Die Schilderkette ist eine waagerecht scrollende
            // Leiste; ein zweizeiliges Schild darin wäre entweder
            // abgeschnitten oder machte die Kette doppelt so hoch. Hier
            // steht der Satz einmal und nennt die betroffene Linie.
            if let ersatztext {
                Label(ersatztext, systemImage: "arrow.triangle.swap")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            if mitTicketfilter, let grenztext {
                Label(grenztext.text, systemImage: grenztext.symbol)
                    .font(.caption2)
                    .foregroundStyle(grenztext.farbe)
            }

            HStack(spacing: 10) {
                Text(umstiegstext)
                if verbindung.fussmeter > 0 {
                    Text("· \(Haltestelle.entfernungstext(Double(verbindung.fussmeter))) zu Fuß")
                }
                if let ziel = verbindung.abschnitte.last?.nachName {
                    Text("· bis \(ziel)").lineLimit(1)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    /// Die Linien dieser Verbindung, die sich SELBST einen Ersatzverkehr
    /// nennen — oder `nil`, wenn keine es tut.
    ///
    /// **Das ist keine vollständige Liste der Ersatzverkehre**, und das ist
    /// hier ausdrücklich in Kauf genommen: Gemessen am 21.09.2026 schrieb
    /// von 194 Busabschnitten nur einer (National Express) seinen Langnamen
    /// hin. Eine „S1", die als Bus fährt, steht in den Daten ohne jedes
    /// Wort dazu — die Zeile schweigt dann, statt es zu behaupten. Das
    /// Verkehrsmittelsymbol auf dem Schild (1.1.29) sagt trotzdem, dass ein
    /// Bus fährt; das ist der gemessene Teil der Auskunft.
    private var ersatztext: String? {
        var gesehen = Set<String>()
        var teile: [String] = []
        for fahrt in verbindung.fahrten {
            guard let linie = fahrt.linie,
                  let wortlaut = Ersatzverkehr.laut(linie.langname),
                  gesehen.insert(linie.name).inserted
            else { continue }
            teile.append("\(linie.name) (\(wortlaut))")
        }
        guard !teile.isEmpty else { return nil }
        return "Ersatzverkehr laut Quelle: " + teile.joined(separator: ", ")
    }

    /// Was an der Zeile über die Grenze steht — oder `nil`, wenn nichts zu
    /// sagen ist (die Verbindung bleibt nachweislich in Deutschland).
    ///
    /// **Drei Fälle, und alle drei werden unterschieden**, weil sie
    /// Verschiedenes bedeuten: in der Liste, nicht in der Liste, und „Land
    /// nicht feststellbar". Der dritte ist der, den man am liebsten
    /// weglassen würde — und genau der darf nicht als „bleibt in
    /// Deutschland" durchgehen.
    private var grenztext: (text: String, symbol: String, farbe: Color)? {
        let laender = verbindung.auslandslaender
        let unklar = verbindung.landStellenweiseUnbekannt
        // **Der Nachsatz ist kein Beiwerk.** Gemessen am 19.09.2026 an
        // Mönchengladbach → Venlo: Der Zug endet in Venlo (Treffer in der
        // Liste), danach geht es mit einem niederländischen Stadtbus weiter,
        // und dessen Halte tragen eine Kennung ohne Landesvorsatz. Ohne
        // diesen Zusatz stünde an einer Fahrt, die im Ausland noch Bus
        // fährt, ein glattes „steht in der Liste" — und der Bus ist ganz
        // sicher nicht enthalten.
        let nachsatz = unklar ? " (an einem Halt nennt die Quelle das Land nicht)" : ""

        if let fall = verbindung.grenzfall {
            if fall.gesichert && !unklar {
                return ("Grenzabschnitt \(fall.name) — steht in der Liste der abgedeckten Abschnitte",
                        "checkmark.circle", .secondary)
            }
            let grund = fall.gesichert ? "" : ", dort aber nicht bestätigt"
            return ("Grenzabschnitt \(fall.name) — steht in der Liste\(grund)\(nachsatz)",
                    "questionmark.circle", .orange)
        }
        if let erstes = laender.first {
            let wohin = laender.count == 1
                ? Landkennung.wohin(erstes)
                : laender.map(Landkennung.name).joined(separator: ", ")
            return ("Fährt \(wohin) — dieser Abschnitt steht nicht in der Liste",
                    "exclamationmark.triangle", .orange)
        }
        if unklar {
            return ("Bei einem Halt sagt die Quelle das Land nicht — ob die Fahrt in Deutschland bleibt, ist hier nicht zu erkennen",
                    "questionmark.circle", .secondary)
        }
        return nil
    }

    private var dauertext: String {
        let minuten = Int((verbindung.dauer / 60).rounded())
        if minuten < 60 { return "\(minuten) min" }
        return "\(minuten / 60) h \(minuten % 60) min"
    }

    private var umstiegstext: String {
        switch verbindung.umstiege {
        case 0: return "ohne Umstieg"
        case 1: return "1 Umstieg"
        default: return "\(verbindung.umstiege) Umstiege"
        }
    }
}
