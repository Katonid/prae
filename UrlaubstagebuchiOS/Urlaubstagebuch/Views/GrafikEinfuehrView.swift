import PhotosUI
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
            Absturzspur.beginnt("Bild aus Dateien: \(adresse.lastPathComponent) lesen")
            guard let daten = try? Data(contentsOf: adresse) else {
                Absturzspur.endet()
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

// EIN BILD AUS DER MEDIATHEK, OHNE DATUMSLOGIK (ab 1.0.65).
//
// Ansage des Nutzers, 09/2026: „Nachdem dies geschehen ist, möchte ich über
// das Plusmenü aber auch Fotos auswählen können, egal ob von Dateien oder
// aus der Fotomediathek, die dann einfach auf der Seite eingefügt werden,
// egal welchen Zeitstempel sie haben."
//
// Bis 1.0.64 führte JEDER Weg aus der Mediathek durch die Fotoeinfuhr —
// also durch Datum, Ort, Tageszuordnung und einen Bericht darüber, was
// fehlt. Das ist richtig, solange es um Reisefotos geht, und falsch, sobald
// jemand ein Bild einfach auf eine Seite legen will. Der Weg über DATEIEN
// konnte das seit 1.0.61; dieser hier ist derselbe, nur mit dem anderen
// Wähler davor — dieselbe Funktion dahinter (`grafikEinfuegen`), denn zwei
// Fassungen desselben Einsetzens liefen auseinander.
//
// Das Bild gilt danach als GRAFIK: Es steht in keiner Fotoliste eines
// Tages, erzeugt keinen Punkt auf der Karte und taucht nicht in der Ablage
// „Fotos ohne Tag" auf. Genau das ist gemeint mit „egal welchen Zeitstempel
// sie haben".
struct BildAusFotosView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        // Der Wähler zeigt sich SELBST — dieselbe Regel wie überall, wo ein
        // fremder Dienst ein Fenster aufmacht.
        Fotowahl { treffer in
            Absturzspur.beginnt("Mediathek: \(treffer.count) Bild(er) gewählt")
            Task { await einsetzen(treffer) }
        }
        .ignoresSafeArea()
        .onAppear { Absturzspur.beginnt("Mediathek-Wähler steht \u{2014} Auswahl läuft") }
    }

    private func einsetzen(_ treffer: [PHPickerResult]) async {
        guard !treffer.isEmpty else {
            schliessen()
            return
        }
        guard let seite = werk.einsetzbareSeite else {
            werk.meldung = .init(text: "Erst eine Seite antippen, dann das Bild wählen.",
                                 schwer: true)
            schliessen()
            return
        }
        var gesetzt = 0
        var gescheitert = 0
        for (nummer, eintrag) in treffer.enumerated() {
            // WAS GERADE LÄUFT, STEHT AUF DER PLATTE (ab 1.0.100).
            //
            // Gemeldet 09/2026: „Leider stürzt die App nun immer ab, wenn
            // ich ein Foto aus der Galerie auf den Schmutztitel
            // positionieren will." Die Ursache war am Quelltext nicht zu
            // finden — also sagt die App beim nächsten Start selbst, in
            // welchem Schritt sie gestorben ist (`Absturzspur`).
            Absturzspur.beginnt("Bild \(nummer + 1) von \(treffer.count) aus der "
                + "Mediathek: Daten holen")
            // Wie lange die Mediathek braucht, ist GEMESSEN und nicht
            // geraten (ab 1.0.103): Ein Bild, das nur in iCloud liegt, wird
            // hier erst geholt, und genau das wurde vom Mac als „dauerte"
            // gemeldet.
            let holanfang = Date()
            guard let daten = await ladeDaten(eintrag) else {
                Absturzspur.endet()
                gescheitert += 1
                continue
            }
            Tempomesser.melde("Bild aus der Mediathek",
                              dauer: Date().timeIntervalSince(holanfang),
                              zusatz: "\(daten.count / 1024) KB")
            if werk.grafikEinfuegen(daten, endung: endung(eintrag), aufSeite: seite) {
                gesetzt += 1
            } else {
                gescheitert += 1
            }
        }
        var satz = gesetzt == 1 ? "1 Bild eingesetzt." : "\(gesetzt) Bilder eingesetzt."
        if gesetzt > 0 {
            satz += " Es liegt in der Mitte der Seite und lässt sich von dort "
            satz += "verschieben, drehen und in der Größe ziehen. "
            satz += "Ein Tag wird ihm nicht zugeordnet."
        }
        if gescheitert > 0 {
            satz += " \(gescheitert) ließen sich nicht lesen."
        }
        werk.meldung = .init(text: satz)
        schliessen()
    }

    // Die ECHTE Endung, soweit die Mediathek sie hergibt. Ein PNG als
    // „jpg" abzulegen nähme ihm den durchsichtigen Grund.
    private func endung(_ eintrag: PHPickerResult) -> String {
        let typen = eintrag.itemProvider.registeredTypeIdentifiers
        if typen.contains(UTType.png.identifier) { return "png" }
        if typen.contains(UTType.heic.identifier) { return "heic" }
        return "jpg"
    }

    // Geladen werden DATEN und nie ein `UIImage` — ein entpacktes Bild hat
    // seine Maße noch, aber alles andere nicht mehr, und `Bildleser` liest
    // die Maße aus der Datei.
    private func ladeDaten(_ eintrag: PHPickerResult) async -> Data? {
        let anbieter = eintrag.itemProvider
        guard anbieter.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
            return nil
        }
        return await withCheckedContinuation { fortsetzen in
            // `loadDataRepresentation` darf seinen Rückruf MEHRMALS
            // aufrufen; ein zweites `resume` an einer Continuation ist kein
            // Fehler, sondern ein Absturz. Dieselbe Falle wie in der
            // Zeitraumeinfuhr seit 1.0.30.
            let einmal = Einmal()
            anbieter.loadDataRepresentation(
                forTypeIdentifier: UTType.image.identifier
            ) { daten, _ in
                einmal.tun { fortsetzen.resume(returning: daten) }
            }
        }
    }
}

// Ein Wächter, der genau einmal durchlässt.
private final class Einmal: @unchecked Sendable {
    private let sperre = NSLock()
    private var schon = false

    func tun(_ arbeit: () -> Void) {
        sperre.lock()
        let jetzt = !schon
        schon = true
        sperre.unlock()
        if jetzt { arbeit() }
    }
}
