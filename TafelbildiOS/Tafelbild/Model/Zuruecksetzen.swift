import Foundation

/// Elemente wieder auf „unbenutzt" stellen.
///
/// **Warum das fehlte.** Alles, was auf der Tafel abläuft, bleibt danach
/// stehen: der zuletzt gezogene Name, die ausgeloste Sitzordnung, die
/// gelaufene Geburtstagsfeier, die abgehakten Punkte des Tagesablaufs. Das
/// ist im Unterricht richtig — eine Tafel, die sich selbst aufräumt,
/// während die Klasse noch hinsieht, wäre unbrauchbar. Am nächsten Morgen
/// ist es falsch (Ansage des Nutzers, 08/2026: „Mir fehlt bei allen
/// Elementen, die automatisch ablaufen, die Funktion, sie wieder auf einen
/// unbenutzten Zustand zurückzustellen.").
///
/// **Was zurückgesetzt wird, ist der Ablauf — nie die Einrichtung.** Die
/// Namensliste bleibt, der Grundriss bleibt, die Dauer des Timers bleibt,
/// Farben und Beschriftungen bleiben. Und **Archive bleiben**: die
/// gesicherten Ziehungen und die gesicherten Sitzordnungen sind ein
/// Nachweis, kein Zustand. Wer sie loswerden will, löscht sie dort, wo sie
/// stehen.
extension WidgetContent {

    /// Steht an diesem Element etwas, das ein Zurücksetzen entfernen würde?
    ///
    /// Danach richtet sich, ob der Menüpunkt überhaupt etwas bewirkt — ein
    /// Knopf, der nichts tut, ist schlimmer als keiner.
    var benutzt: Bool {
        switch self {
        case .namePicker(let c):
            return c.currentID != nil || !c.drawnIDs.isEmpty || !c.ergebnis.isEmpty
                || !c.erledigt.isEmpty || !c.revealParts.isEmpty || c.festgehalten
                || !c.zaehler.isEmpty || !c.paare.isEmpty
        case .timer(let c):
            return c.endsAtMs != nil || c.startedAtMs != nil || c.pausedValue != nil
        case .trafficLight(let c):
            return c.state != .green
        case .checklist(let c):
            return c.items.contains { $0.done }
        case .kamera(let c):
            return c.eingefroren != nil
        case .geburtstag(let c):
            return c.ritual > 0 || !c.gratulanten.isEmpty || !c.rollen.isEmpty
                || !c.fragen.isEmpty
        case .sitzplan(let c):
            return !c.belegung.isEmpty || c.aufgedeckt > 0 || c.gesperrt
                || !c.bericht.isEmpty
        case .clock, .noise, .text, .image, .sounds, .symbols, .video:
            // Diese laufen nicht ab — eine Uhr ist nie „benutzt".
            return false
        }
    }

    /// Dasselbe Element im unbenutzten Zustand.
    var unbenutzt: WidgetContent {
        switch self {
        case .namePicker(var c):
            c.currentID = nil
            c.drawnIDs = []
            c.ergebnis = []
            c.erledigt = []
            c.revealParts = []
            c.festgehalten = false
            // Das Gedächtnis gehört zum Gebrauch: Wer wie oft gezogen wurde
            // und wer mit wem in einer Gruppe war, ist die Spur der letzten
            // Wochen. `ziehungen` bleibt — das ist das Archiv.
            c.zaehler = [:]
            c.paare = [:]
            c.ziehungID = ""
            return .namePicker(c)

        case .timer(var c):
            c.endsAtMs = nil
            c.startedAtMs = nil
            c.pausedValue = nil
            return .timer(c)

        case .trafficLight(var c):
            c.state = .green
            return .trafficLight(c)

        case .checklist(var c):
            for stelle in c.items.indices { c.items[stelle].done = false }
            return .checklist(c)

        case .kamera(var c):
            c.eingefroren = nil
            return .kamera(c)

        case .geburtstag(var c):
            c.ritual = 0
            c.gratulanten = []
            c.rollen = []
            c.fragen = []
            return .geburtstag(c)

        case .sitzplan(var c):
            c.belegung = [:]
            c.namen = [:]
            c.reihenfolge = []
            c.aufgedeckt = 0
            c.bericht = []
            c.gesperrt = false
            c.laufenderEintrag = ""
            // `plaetze` und `archiv` bleiben: der Grundriss ist Einrichtung,
            // das Archiv ist ein Nachweis.
            return .sitzplan(c)

        case .clock, .noise, .text, .image, .sounds, .symbols, .video:
            return self
        }
    }
}
