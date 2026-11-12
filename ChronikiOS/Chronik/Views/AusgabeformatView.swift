import SwiftUI

// WAS GERADE AUSGEGEBEN WIRD — an einer Stelle und zum Kopieren
// (ab 1.0.75).
//
// Ansage des Nutzers, 09/2026: „Das gipfelt jetzt in einer Fülle von
// Formaten. Vielleicht wäre es gut, sich innerhalb der App irgendwo
// anzeigen lassen zu können, wie denn jetzt das Ausgabeformat aussieht und
// wie die einzelnen Werte sind."
//
// **Ein eigener Menüpunkt, keine Zeile in einem Picker.** Das ist die
// Lehre aus 1.0.37 (Broschüre) und 1.0.52 (zwei Dateien): Beides war
// vollständig gebaut und lag hinter einem zugeklappten Picker — gefunden
// hat es niemand. Wer wissen will, was seine Datei für Maße hat, sucht
// keinen Picker; er sucht einen Punkt, der so heißt.
//
// Gerechnet wird hier NICHTS: Jede Zahl kommt aus `Ausgabesteckbrief`, und
// der holt sie von den Stellen, die sie auch beim Ausgeben liefern.
struct AusgabeformatView: View {
    @ObservedObject var werk: Reisewerk
    /// Die Güte, mit der gerechnet wird. Vom Ausgabeblatt hereingereicht,
    /// damit dort die gewählte gilt; sonst die Vorgabe — und die Fußzeile
    /// schreibt hin, dass sie es ist.
    var guete: Bildguete = .vorgabe

    @Environment(\.dismiss) private var schliessen

    // Der Lauf über alle Bilder des Buches gehört in eine Aufgabe und
    // nicht in den Körper: Der läuft bei jedem Neuzeichnen (dieselbe Falle
    // wie bei der Druckprüfung in 1.0.0).
    @State private var bildbefund = ""
    // GEMELDET WIRD HIER, NICHT ÜBER `werk.meldung`. Das Band der Meldungen
    // hängt an `ReiseView`, und diese Ansicht liegt als Blatt darüber —
    // die Quittung erschiene dahinter. Dieselbe Lehre wie bei der
    // Punktwahl in 1.0.52 und bei Schulalarm 1.0.26: Ein Fehlerband unter
    // einem Blatt sieht niemand.
    @State private var kopiert = false

    private var abschnitte: [Ausgabesteckbrief.Abschnitt] {
        Ausgabesteckbrief.abschnitte(werk.reise, guete: guete, bildbefund: bildbefund)
    }

    var body: some View {
        Form {
            Section {
                Text(einleitung)
                    .font(.callout)
            }

            ForEach(abschnitte) { abschnitt in
                Section {
                    ForEach(abschnitt.zeilen) { zeile in
                        Steckbriefzeile(zeile: zeile)
                    }
                } header: {
                    Text(abschnitt.titel)
                } footer: {
                    if !abschnitt.fuss.isEmpty { Text(abschnitt.fuss) }
                }
            }

            Section {
                Button {
                    UIPasteboard.general.string =
                        Ausgabesteckbrief.text(werk.reise, guete: guete,
                                               bildbefund: bildbefund)
                    kopiert = true
                } label: {
                    Label("Alles kopieren", systemImage: "doc.on.doc")
                }
                if kopiert {
                    Label("Liegt in der Zwischenablage", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            } footer: {
                Text(schlusssatz)
            }
        }
        .navigationTitle("Ausgabeformat")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: guete) {
            bildbefund = Ausgabeguete.satz(werk.reise, guete: guete)
        }
    }

    private var einleitung: String {
        var text = "Alle Maße, mit denen dieses Buch gerade ausgegeben wird. "
        text += "Was mit \u{201E}Einstellung\u{201C} gekennzeichnet ist, hat "
        text += "jemand gewählt \u{2014} darunter steht, wo; alles andere folgt "
        text += "daraus."
        return text
    }

    private var schlusssatz: String {
        var text = "Diese Seite sagt, WAS ausgegeben wird. Ob die fertige Datei "
        text += "hält, was hier steht, misst die Prüfung im Ausgabeblatt \u{2014} "
        text += "dort werden Seitenzahl, MediaBox und TrimBox aus dem PDF "
        text += "gelesen und nicht aus dem Modell, das es geschrieben hat."
        return text
    }
}

private struct Steckbriefzeile: View {
    let zeile: Ausgabesteckbrief.Zeile

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if zeile.wert.isEmpty {
                Text(zeile.name)
                    .font(.subheadline.weight(.medium))
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(zeile.name)
                    Spacer(minLength: 12)
                    Text(zeile.wert)
                        .font(.body.weight(.medium))
                        .multilineTextAlignment(.trailing)
                }
            }
            if !zeile.erklaerung.isEmpty {
                Text(zeile.erklaerung)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            if zeile.eingestellt, !zeile.wo.isEmpty {
                Label(zeile.wo, systemImage: "slider.horizontal.3")
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// Als eigenes Blatt braucht es einen Stapel; vom Ausgabeblatt aus steht es
// schon in einem. Zwei Fassungen der Ansicht wären zwei Wege zu derselben
// Sache — deshalb hier nur eine Hülle.
struct Ausgabeformatblatt: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            AusgabeformatView(werk: werk)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fertig") { schliessen() }
                    }
                }
        }
    }
}
