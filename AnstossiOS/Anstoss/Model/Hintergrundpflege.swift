import BackgroundTasks
import Foundation

/// Holt den Spielstand nach, während die App geschlossen ist, und meldet, was
/// sich geändert hat.
///
/// Was hier ehrlich gesagt gehört: **iOS entscheidet, wann das läuft.** Die
/// App darf einen Wunsch anmelden, mehr nicht. In der Praxis sind das je nach
/// Nutzungsgewohnheit Abstände von einer Viertelstunde bis zu mehreren
/// Stunden; nach einem Zwangsbeenden (App aus dem Umschalter geschoben) und
/// im Stromsparmodus läuft gar nichts. Ein Tor kommt also verzögert an, nicht
/// in dem Augenblick, in dem es fällt.
///
/// Verlässlich auf die Minute ist nur die Erinnerung vor dem Anpfiff — die
/// stellt iOS als Wecker, weil die Anstoßzeit vorher feststeht.
enum Hintergrundpflege {
    static let kennung = "de.familie.anstoss.spielstand"

    /// Muss beim Start angemeldet werden, bevor die App fertig hochgefahren
    /// ist — sonst weist iOS die Aufgabe später zurück.
    static func anmelden() {
        _ = BGTaskScheduler.shared.register(forTaskWithIdentifier: kennung, using: nil) { aufgabe in
            guard let auffrischung = aufgabe as? BGAppRefreshTask else {
                aufgabe.setTaskCompleted(success: false)
                return
            }
            bearbeiten(auffrischung)
        }
    }

    /// Nächsten Lauf erbitten. Frühestens in zehn Minuten — häufiger gewährt
    /// iOS ohnehin nicht.
    static func planen() {
        let bitte = BGAppRefreshTaskRequest(identifier: kennung)
        bitte.earliestBeginDate = Date().addingTimeInterval(10 * 60)
        try? BGTaskScheduler.shared.submit(bitte)
    }

    static func abbestellen() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: kennung)
    }

    // MARK: Der eigentliche Lauf

    private static func bearbeiten(_ aufgabe: BGAppRefreshTask) {
        // Sofort den nächsten Lauf erbitten: Wer das vergisst, wird genau
        // einmal geweckt und nie wieder.
        planen()

        let arbeit = Task {
            let erfolg = await nachsehen()
            aufgabe.setTaskCompleted(success: erfolg)
        }

        aufgabe.expirationHandler = {
            arbeit.cancel()
        }
    }

    /// Holt die heutigen Spiele, vergleicht sie mit dem gesicherten Stand und
    /// meldet die Unterschiede. Läuft bewusst ohne die `Datenhaltung` — die
    /// hängt an der Oberfläche, hier gibt es keine.
    @discardableResult
    static func nachsehen() async -> Bool {
        let wunsch = Meldungswunsch.gesichert()

        // Die Ligameldungen hängen nicht am Schlüssel und nicht an
        // freigeschalteten Spielen — sie kommen aus den RSS-Quellen und
        // laufen deshalb auch dann, wenn zum Spielstand nichts zu tun ist.
        if !wunsch.nachrichtenStumm {
            await Nachrichtenpflege.durchgang(wunsch: wunsch)
        }

        // Nichts freigeschaltet, nichts zu tun — dann auch keine Abfrage, die
        // vom knappen Kontingent des freien Zugangs abginge.
        guard !wunsch.istStumm else { return true }

        let schluessel = Schluesselbund.lesen()
        guard !schluessel.isEmpty else { return true }

        let dienst = FussballDienst(schluessel: schluessel)
        guard let geholt = try? await dienst.spieleHeute() else { return false }
        // Wie im Vordergrund: erst die Torfolge nachziehen, dann
        // vergleichen — sonst meldet der Hintergrund Tore ohne Namen.
        let frisch = await Datenhaltung.torfolgeNachziehen(geholt)

        let vorher = Standspeicher.laden()
        let neue = Tickerwerk.meldungen(frisch: frisch, vorher: vorher)

        var stand = vorher
        for spiel in frisch { stand[spiel.id] = spiel }
        Standspeicher.sichern(stand)

        Tickerspeicher.anhaengen(neue)
        Benachrichtiger.melden(neue, wunsch: wunsch)
        Vereinsverzeichnis.merken(spiele: frisch)
        return true
    }
}
