import SwiftUI
import UniformTypeIdentifiers

// EIN BILD ODER EINE GRAFIK VON HAND (ab 1.0.61).
//
// Ansage des Nutzers, 09/2026: „Ich möchte in das Buch manuell Bilder oder
// Grafiken einfügen können. Dies soll über den Plus-Button geschehen, sowie
// bei den Textfeldern auch. Diese Bilder sollen dann nicht in der Reisespur
// auftauchen und es ist völlig unerheblich, ob sie einen Zeitstempel haben
// oder einen Ort."
//
// Das ist NICHT die Fotoeinfuhr, und der Unterschied ist die ganze Sache:
// Die ordnet einem TAG zu, liest Datum und Ort, baut daraus Reisepunkte und
// meldet hinterher, was gefehlt hat. Für eine Grafik ist jede dieser
// Auskünfte Lärm — gemeldet 09/2026, wörtlich über ein eingesetztes Bild:
// „1 Fotos tragen keinen Ort … 1 Fotos tragen kein Datum und stehen jetzt
// bei 4. Juni 2026." Hier wird deshalb nur die Datei abgelegt, ihre Maße
// gelesen und ein Block auf die gewählte Seite gesetzt.
//
// Der Weg führt in die DATEIEN und nicht in die Mediathek: Eine Grafik ist
// meist ein PNG mit durchsichtigem Grund, und genau das gibt die Mediathek
// nicht zuverlässig her — dieselbe Überlegung wie beim Wasserzeichen.
struct GrafikEinfuehrView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        // Der Wähler zeigt sich SELBST und wird nicht in ein weiteres
        // Blatt gepackt — dieselbe Regel wie bei jeder anderen Stelle
        // dieser App, an der ein fremder Dienst ein Fenster aufmacht.
        Dateiwahl(typen: [.image], mehrere: true) { adressen in
            einsetzen(adressen)
        }
        .ignoresSafeArea()
    }

    private func einsetzen(_ adressen: [URL]) {
        guard let seite = werk.einsetzbareSeite else {
            schliessen()
            return
        }
        var gesetzt = 0
        var gescheitert = 0
        for adresse in adressen {
            // Auch bei `asCopy: true` wird der Zugriff angemeldet —
            // dieselbe Bauweise wie in der Fotoeinfuhr; ohne sie kommt je
            // nach Herkunft der Datei nichts an.
            let offen = adresse.startAccessingSecurityScopedResource()
            defer { if offen { adresse.stopAccessingSecurityScopedResource() } }
            guard let daten = try? Data(contentsOf: adresse) else {
                gescheitert += 1
                continue
            }
            // Die ECHTE Endung bleibt erhalten. Ein PNG als „jpg"
            // abzulegen nähme ihm den durchsichtigen Grund, sobald es
            // irgendwo neu kodiert wird — und ein Wasserzeichen oder eine
            // Vereinsgrafik lebt genau davon.
            let endung = adresse.pathExtension.isEmpty
                ? "png" : adresse.pathExtension.lowercased()
            if werk.grafikEinfuegen(daten, endung: endung, aufSeite: seite) {
                gesetzt += 1
            } else {
                gescheitert += 1
            }
        }
        // Gesagt wird, was angekommen ist — auch die Null. Ein Wähler, der
        // sich wortlos schließt, lässt einen raten, ob er etwas getan hat.
        var satz = gesetzt == 1 ? "1 Bild eingesetzt." : "\(gesetzt) Bilder eingesetzt."
        if gesetzt > 0 {
            satz += " Es liegt in der Mitte der Seite und lässt sich von dort "
            satz += "verschieben, drehen und in der Größe ziehen."
        }
        if gescheitert > 0 {
            satz += " \(gescheitert) ließen sich nicht lesen."
        }
        werk.meldung = .init(text: satz)
        schliessen()
    }
}
