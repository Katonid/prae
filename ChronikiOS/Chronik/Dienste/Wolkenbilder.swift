import Foundation

// LIEGEN DIE BILDER DIESES BUCHES AUF DIESEM GERÄT? (ab 1.0.71)
//
// Gemeldet 09/2026: „Auf dem iPad ist kein Arbeiten möglich. Vielleicht
// liegt es daran, dass ich das Projekt insgesamt auf einem anderen Gerät
// erstellt und verarbeitet habe." Der Verdacht des Nutzers trifft eine
// Stelle, die sich am Quelltext abzählen lässt — und es sind zwei Fehler
// übereinander:
//
//  1. `Wolke.herunterladenAnstossen` ging NUR über die oberste Ebene des
//     Ordners `Reisen`. Dort liegen die JSON-Dateien und je Buch ein
//     Ordner; die Bilder liegen zwei Ebenen tiefer, in
//     `Reisen/<Kennung>/Bilder/`. Nach keiner einzigen Bilddatei wurde je
//     gefragt. Ein Buch, das über iCloud von einem anderen Gerät kommt,
//     ist damit binnen Sekunden LESBAR — die JSON-Datei ist klein und wird
//     angestoßen — und hat trotzdem keines seiner zweihundert Bilder.
//  2. Ein Bild, das nicht auf der Platte liegt, gab in
//     `Bildarchiv.vorschau` ein `nil` zurück, und ein `nil` wurde NIRGENDS
//     gemerkt. Jede Neuzeichnung der Bühne suchte also jedes fehlende Bild
//     noch einmal, auf dem Hauptfaden. Das ist die Form, in der sich „kein
//     Arbeiten möglich" erklärt: Nicht eine Rechnung ist zu teuer, sondern
//     dieselbe vergebliche Suche läuft hundertfach.
//
// **Gemessen ist die URSACHE, nicht die Abhilfe.** Ob das iPad danach
// flüssig ist, sagt erst der nächste Befund — und seit 1.0.71 sagt er es
// mit Zahlen: `Stand.befund` steht unter „Bedienung prüfen".
enum Wolkenbilder {
    // Was von den Bildern eines Buches wo liegt.
    //
    // „Liegt noch in iCloud" und „ist weg" sind NICHT dasselbe, und dieser
    // Unterschied ist der ganze Sinn der Zählung: Das eine löst sich von
    // selbst, sobald das Gerät im Netz ist; das andere nie. Eine App, die
    // beides als graue Fläche zeigt, lässt den Menschen davor raten —
    // dieselbe Regel wie beim Wort „Plan" in der Abfahrtstafel.
    struct Stand: Equatable {
        var gesamt = 0
        // Auf der Platte und lesbar.
        var hier = 0
        // In iCloud, aber (noch) nicht heruntergeladen.
        var laedt = 0
        // Weder hier noch dort — diese Datei ist wirklich fort.
        var fehlt = 0
        var geprueft = Date.distantPast

        var vollstaendig: Bool { laedt == 0 && fehlt == 0 }

        // Der Satz für das Band über der Bühne.
        var satz: String {
            var teile: [String] = []
            if laedt > 0 {
                teile.append("\(laedt) von \(gesamt) Bildern liegen noch in iCloud")
            }
            if fehlt > 0 {
                teile.append("\(fehlt) \(fehlt == 1 ? "Bild fehlt" : "Bilder fehlen") ganz")
            }
            return teile.joined(separator: ", ") + "."
        }

        // Die Zeile für den Befund — ohne Deutung, mit allen vier Zahlen
        // und mit dem Alter der Messung. Eine Zahl ohne ihren Zeitpunkt ist
        // keine Messung.
        var befund: String {
            guard gesamt > 0 else { return "Bilder: keines im Buch" }
            let alter = geprueft == .distantPast
                ? "noch nicht nachgesehen"
                : String(format: "vor %.0f s nachgesehen",
                         Date().timeIntervalSince(geprueft))
            return "Bilder: \(gesamt) im Buch · \(hier) auf dem Gerät · "
                + "\(laedt) in iCloud · \(fehlt) fehlen · \(alter)"
        }
    }

    // ALLE Bilddateien, die ein Buch nennt.
    //
    // Die Reisefotos UND die Wasserzeichen: Letztere stehen in keiner
    // Fotoliste und liegen trotzdem im selben Ordner — wer sie hier
    // vergisst, stößt sie nie an, und ein Wasserzeichen liegt auf JEDER
    // Seite. Dieselbe Überlegung wie in `Buchdatei.schreiben`, wo sie aus
    // demselben Grund eigens mitgeschrieben werden.
    static func dateien(_ reise: Reise) -> [String] {
        var namen = reise.fotos.map(\.datei)
        namen += (reise.gestaltung.wasserzeichen?.gueltigeBilder ?? []).map(\.datei)
        return namen
    }

    // MARK: - Nachsehen

    // Läuft über jede Datei und fragt das Dateisystem. Das gehört NICHT auf
    // den Hauptfaden: Bei zweihundert Bildern sind es zweihundert
    // Abfragen, und über iCloud kann jede davon warten.
    static func nachsehen(reise: UUID, dateien namen: [String]) -> Stand {
        let verwalter = FileManager.default
        let ordner = Bildarchiv.shared.ordner(reise)
        var stand = Stand(gesamt: namen.count, geprueft: Date())

        for name in namen {
            let ort = ordner.appendingPathComponent(name)
            if verwalter.fileExists(atPath: ort.path) {
                stand.hier += 1
            } else if inDerWolke(ort, name: name, ordner: ordner, verwalter: verwalter) {
                stand.laedt += 1
            } else {
                stand.fehlt += 1
            }
        }
        return stand
    }

    // WIE ein nicht heruntergeladenes Bild aussieht, lässt sich von hier
    // aus nicht messen — also werden BEIDE bekannten Gestalten geprüft: der
    // Platzhalter `.<Name>.icloud` neben der Datei und die Auskunft des
    // Dateisystems am Namen selbst. Nur eine von beiden zu fragen hieße,
    // sich auf eine Darstellung zu verlassen, die Apple zwischen zwei
    // Fassungen ändern darf; der Preis wäre, dass ein Bild, das gleich
    // ankommt, als „fehlt ganz" gemeldet würde.
    private static func inDerWolke(_ ort: URL, name: String, ordner: URL,
                                   verwalter: FileManager) -> Bool
    {
        let platzhalter = ordner.appendingPathComponent("." + name + ".icloud")
        if verwalter.fileExists(atPath: platzhalter.path) { return true }
        let werte = try? ort.resourceValues(forKeys: [.isUbiquitousItemKey])
        return werte?.isUbiquitousItem == true
    }

    // MARK: - Anstoßen

    // Fragt für jede Datei, die nicht da ist, den Download an.
    //
    // Angestoßen wird für EIN Buch und nicht für alle: Fünf Bücher zu je
    // zweihundert Bildern auf einmal sind genau der Schwall, dem iCloud
    // Drive aus dem Weg gehen soll — es lädt eine Datei, wenn sie gebraucht
    // wird, und gebraucht wird das offene Buch.
    //
    // `startDownloadingUbiquitousItem` wirft, wenn die Datei gar nicht in
    // iCloud liegt. Das ist kein Fehler, sondern der Regelfall für ein
    // Bild, das wirklich fort ist — deshalb `try?` und keine Meldung.
    @discardableResult
    static func anstossen(reise: UUID, dateien namen: [String]) -> Int {
        guard Wolke.stand == .an else { return 0 }
        let verwalter = FileManager.default
        let ordner = Bildarchiv.shared.ordner(reise)
        var angestossen = 0
        for name in namen {
            let ort = ordner.appendingPathComponent(name)
            guard !verwalter.fileExists(atPath: ort.path) else { continue }
            if (try? verwalter.startDownloadingUbiquitousItem(at: ort)) != nil {
                angestossen += 1
            }
        }
        return angestossen
    }
}
