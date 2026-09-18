import SwiftUI

/// Eine Verbindung in der Ergebnisliste.
///
/// Oben die beiden Zeiten, darunter die Linien in Fahrtrichtung. Die
/// Linienschilder sind die Zeile: Wer zwischen fünf Vorschlägen wählt,
/// entscheidet nach „S1 oder zweimal umsteigen" und nicht nach Minuten.
struct VerbindungsZeile: View {
    let verbindung: Verbindung
    let jetzt: Date

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
                            Liniensymbol(linie: linie)
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
