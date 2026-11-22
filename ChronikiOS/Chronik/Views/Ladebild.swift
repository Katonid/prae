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
struct Ladebild<Inhalt: View>: View {
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

    // KAPITELWEISE (ab 1.0.41, gemeldet 11/2026 mit Bildschirmfoto: „Häufig
    // werden die Bilder nur weiß angezeigt und erhalten erst wieder einen
    // Inhalt, wenn ich die Zoom-Stufe der Seite verändert habe"). Ursache:
    // Lag das Bild beim ersten Zeichnen im Vorrat, kehrte die Aufgabe sofort
    // zurück und merkte sich NICHTS. Räumte der Vorrat danach auf
    // (`NSCache`, 120 Bilder, Speicherdruck), zeigte `body` ein leeres Feld —
    // und die Aufgabe lief erst wieder, als sich der Schlüssel änderte, also
    // beim Zoomen (die Kante hängt am Maßstab). Jetzt: Auch ein Treffer im
    // Vorrat wird festgehalten, und ein älteres Bild (andere Kante) bleibt
    // stehen, bis das neue da ist — beim Zoomen wird es nicht kurz weiß.
    private var bild: UIImage? {
        if let da = Bildarchiv.shared.ausVorrat(datei, kante: kante, farbkraft: farbkraft) {
            return da
        }
        return geholt
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
            if let da = Bildarchiv.shared.ausVorrat(datei, kante: kante, farbkraft: farbkraft) {
                geholt = da
                geholtFuer = schluessel
                return
            }
            let anfang = Date()
            // Bis zu drei Versuche: Scheitert das Holen (Speicherdruck,
            // Datei gerade gesperrt), bliebe das Feld sonst bis zum
            // nächsten Zoomen weiß.
            for versuch in 0 ..< 3 {
                let neu = await Bildarchiv.shared.holen(datei, reise: reise, kante: kante,
                                                        farbkraft: farbkraft)
                // Die Aufgabe kann abgebrochen worden sein, weil die Seite
                // aus dem Bild gescrollt ist. Dann schreibt sie nichts mehr.
                guard !Task.isCancelled else { return }
                if let neu {
                    messer?.melde(messname, dauer: Date().timeIntervalSince(anfang))
                    geholt = neu
                    geholtFuer = schluessel
                    return
                }
                try? await Task.sleep(for: .milliseconds(300 * (versuch + 1)))
            }
        }
    }
}
