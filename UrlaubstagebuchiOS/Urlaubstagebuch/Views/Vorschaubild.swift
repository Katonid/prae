import SwiftUI

// EIN VORSCHAUBILD, DAS DEN HAUPTFADEN NICHT ANHÄLT (ab 1.0.81).
//
// Gemeldet 09/2026, zum wiederholten Mal: „Das Scrollen über mehrere Seiten
// hinweg gestaltet sich auf dem iPad echt schwierig. Offenbar muss da doch
// noch sehr viel im Hintergrund nachgeladen und aufgebaut werden."
//
// **Er hat recht, und der Punkt stand seit 1.0.59 als offen im Papier:**
// `Bildarchiv.vorschau` liest bei einem Fehlschlag im Vorrat SYNCHRON von
// der Platte und entpackt das Bild sofort. Aufgerufen wurde sie im KÖRPER
// der Seitenansicht — also auf dem Hauptfaden, und zwar genau dann, wenn
// der `LazyVStack` beim Scrollen ein neues Blatt baut. Drei bis sechs
// Bilder je Seite, und dazwischen soll gescrollt werden.
//
// Hier wird zuerst der VORRAT gefragt (das kostet nichts), und nur wenn
// dort nichts liegt, läuft das Holen abseits des Hauptfadens. Bis es da
// ist, bleibt die Fläche leer — ein Blatt, das eine Achtelsekunde später
// sein Bild bekommt, ist besser als eines, das erst erscheint, wenn alle
// Bilder da sind.
//
// **Der Schlüssel muss ALLES nennen, was das Bild verändert** (Datei,
// Kante, Farbkraft). Eine vergessene Stelle zeigt nach dem Umstellen das
// Bild von vorhin — dieselbe Falle wie beim `merkmal` des Kartenbildes in
// 1.0.51.
struct Vorschaubild<Inhalt: View>: View {
    let datei: String
    let reise: UUID
    let kante: Int
    var farbkraft: Double = 1
    /// Für den Messfühler: unter welchem Namen dieses Bild gezählt wird.
    var messname: String = "Fotos"
    var messer: Zeichenmesser?
    @ViewBuilder let inhalt: (UIImage) -> Inhalt

    // Was zuletzt geholt wurde. Nur ein Rückfall: Sobald es im Vorrat
    // liegt, kommt es von dort — und der Vorrat wird bei einem
    // Formatwechsel oder beim Aufräumen geleert, dieser Zustand nicht.
    @State private var geholt: UIImage?
    @State private var geholtFuer: String = ""

    private var schluessel: String {
        "\(datei)|\(kante)|\(String(format: "%.2f", farbkraft))"
    }

    private var bild: UIImage? {
        if let da = Bildarchiv.shared.ausVorrat(datei, kante: kante, farbkraft: farbkraft) {
            return da
        }
        return geholtFuer == schluessel ? geholt : nil
    }

    var body: some View {
        Group {
            if let bild {
                inhalt(bild)
            } else {
                // Kein Platzhalter mit Symbol: Eine Seite, auf der für einen
                // Augenblick graue Kästen mit Bildzeichen stehen, sieht
                // kaputter aus als eine, auf der das Bild eine Wimper später
                // erscheint. Die Fläche bleibt frei.
                Color.clear
            }
        }
        .task(id: schluessel) {
            // Liegt es schon im Vorrat, ist nichts zu tun — `body` hat es
            // dann ohnehin gezeigt.
            guard Bildarchiv.shared.ausVorrat(datei, kante: kante,
                                              farbkraft: farbkraft) == nil else { return }
            let anfang = Date()
            let neu = await Bildarchiv.shared.holen(datei, reise: reise, kante: kante,
                                                    farbkraft: farbkraft)
            // Die Aufgabe kann abgebrochen worden sein, weil die Seite aus
            // dem Bild gescrollt ist. Dann schreibt sie nichts mehr.
            guard !Task.isCancelled else { return }
            messer?.melde(messname, dauer: Date().timeIntervalSince(anfang))
            geholt = neu
            geholtFuer = schluessel
        }
    }
}
