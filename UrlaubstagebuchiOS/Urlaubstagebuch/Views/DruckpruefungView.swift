import SwiftUI
import UIKit

// DIE DRUCKPRÜFUNG BEKOMMT EINEN EIGENEN MENÜPUNKT (ab 1.0.76).
//
// Ansage des Nutzers, 09/2026: „Damit sind wir an der Stelle, wo ich gerne
// einen Menüpunkt einbauen würde namens Druckprüfung. Hier soll die App
// automatisch alle eingegebenen Werte berücksichtigen und nachsehen, ob es
// irgendwo Probleme gibt. Zu diesem Punkt meine ich mich zu erinnern, dass
// mir die App an irgendeiner Stelle bereits rückgemeldet hat, dass
// beispielsweise Text nicht ganz in ein Textfeld gepasst hat. Ich finde
// diesen Menüpunkt leider nicht mehr wieder."
//
// **Er hat sie gesehen, und sie war nicht zu finden.** `Druckpruefung.vorab`
// gibt es seit 1.0.1 samt `abgeschnittenerText` — sie stand aber
// ausschließlich IM Ausgabeblatt, in einem Abschnitt namens „Vor dem
// Ausgeben geprüft", also hinter „…" → „Als PDF sichern…" und dort unter
// der halben Seite Einstellungen. Wer nicht gerade ausgeben will, kommt
// nie daran vorbei. Zwölfte Auflage von „es war da, man fand es nicht" —
// dieselbe Lehre wie bei der Broschüre (1.0.37), den zwei Dateien (1.0.52)
// und dem Ausgabeformat (1.0.75).
//
// **Kein zweiter Prüfer:** Es ist dieselbe Funktion und dieselbe Zeile
// (`BefundZeile`), nur an einer Stelle, an der man sie sucht. Zwei
// Fassungen derselben Prüfung fänden irgendwann Verschiedenes.
struct DruckpruefungView: View {
    @ObservedObject var werk: Reisewerk
    @State private var befund: [Druckpruefung.Zeile] = []
    @State private var laeuft = true
    // Gemeldet wird IN dieser Ansicht und nicht über `werk.meldung`: Das
    // Band hängt an `ReiseView`, und diese Ansicht liegt als Blatt darüber
    // — die Quittung erschiene dahinter (Lehre aus 1.0.52).
    @State private var kopiert = false

    var body: some View {
        Form {
            if laeuft {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Das Buch wird durchgesehen\u{2026}")
                        .foregroundStyle(.secondary)
                }
            } else {
                if !warnungen.isEmpty {
                    Section {
                        ForEach(warnungen) { zeile in BefundZeile(zeile: zeile) }
                    } header: {
                        Text("Das sollte vor dem Druck geklärt werden")
                    } footer: {
                        Text("Ein Buch geht einmal in den Druck und kommt eine Woche später als Stapel Papier zurück. Bis dahin ist jeder Fehler bezahlt.")
                    }
                }

                if !hinweise.isEmpty {
                    Section("Zum Nachlesen") {
                        ForEach(hinweise) { zeile in BefundZeile(zeile: zeile) }
                    }
                }

                if !gutes.isEmpty {
                    Section("Geprüft und in Ordnung") {
                        ForEach(gutes) { zeile in BefundZeile(zeile: zeile) }
                    }
                }

                Section {
                    Button {
                        UIPasteboard.general.string = befundtext
                        kopiert = true
                    } label: {
                        Label("Befund kopieren", systemImage: "doc.on.doc")
                    }
                    if kopiert {
                        Label("Der Befund liegt in der Zwischenablage.",
                              systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Diese Prüfung sieht an, was EINGESTELLT ist und was auf den Seiten steht. Was wirklich in der fertigen Datei landet — Seitenzahl, TrimBox, Bilder —, misst die Prüfung im Ausgabeblatt an der geschriebenen PDF.")
                }
            }
        }
        .navigationTitle("Druckprüfung")
        .navigationBarTitleDisplayMode(.inline)
        // Der Lauf geht über jede Seite, jeden Block und jedes Bild des
        // Buches — er gehört in eine Aufgabe und nie in den Körper
        // (dieselbe Falle wie bei der Druckprüfung in 1.0.0).
        .task {
            befund = Druckpruefung.vorab(werk.reise)
            laeuft = false
        }
    }

    private var warnungen: [Druckpruefung.Zeile] {
        befund.filter { $0.stufe == .warnung }
    }

    private var hinweise: [Druckpruefung.Zeile] {
        befund.filter { $0.stufe == .hinweis }
    }

    private var gutes: [Druckpruefung.Zeile] {
        befund.filter { $0.stufe == .gut }
    }

    // Kopierbar und ohne Deutung — dieselbe Bauweise wie „Zustellung
    // prüfen" bei Schulalarm. Eine Messung, die man abschreiben muss,
    // kommt verkürzt an.
    private var befundtext: String {
        var zeilen: [String] = []
        zeilen.append("Druckprüfung — " + werk.reise.anzeigename)
        zeilen.append(werk.reise.format.name + " \u{00B7} " + werk.reise.format.masstext)
        zeilen.append("")
        for zeile in befund {
            let marke: String
            switch zeile.stufe {
            case .gut: marke = "OK  "
            case .hinweis: marke = "i   "
            case .warnung: marke = "!   "
            }
            zeilen.append(marke + zeile.titel)
            zeilen.append("    " + zeile.text)
            zeilen.append("")
        }
        return zeilen.joined(separator: "\n")
    }
}

// Als Blatt, mit eigenem Stapel — wie jedes andere Blatt dieser App.
struct Druckpruefungblatt: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            DruckpruefungView(werk: werk)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { schliessen() }
                    }
                }
        }
    }
}
