import Foundation
import SwiftUI

// Ein Stil ist ein Satz Einstellungen, die zusammen gehören.
//
// Das ist der eigentliche Hebel für ein Buch, das gut aussieht. Schrift,
// Farbe, Fugen, Ränder, Schatten und die Vorliebe für bestimmte
// Seitenmuster sind keine unabhängigen Regler: Eine schmale Didot mit
// engen Fugen und randabfallenden Bildern ergibt ein Magazin, eine runde
// Groteske mit breiten weißen Rändern und Sofortbild-Rahmen ein
// Fotoalbum — und jede Mischung aus beidem sieht aus wie ein Versehen.
//
// Deshalb setzt ein Stil alles auf einmal. Danach lässt sich jede
// Einzelheit weiter ändern; der Stil ist ein Anfang und keine Schranke.
struct Buchstil: Identifiable, Hashable {
    var id: String
    var name: String
    var beschreibung: String
    var typografie: Typografie
    var papier: Farbwert
    var akzent: Farbwert
    var randAussen: Double
    var randOben: Double
    var randUnten: Double
    var fuge: Double
    var eckenradius: Double
    var fotorand: Double
    var schatten: Schattenart
    var randabfallendErlaubt: Bool
    // Dürfen Bilder leicht gedreht und gegeneinander versetzt liegen
    // (siehe `Layoutautomat.reihenIn` und das Album-Muster)?
    // Das ist keine Kleinigkeit, sondern der Unterschied zwischen einem
    // eingeklebten Album und einem gesetzten Magazin — in einem Magazin
    // wäre ein schiefes Bild ein Fehler, in einem Album fehlte es.
    var lebendig: Bool
    var musterVorliebe: [Seitenmuster]
    var seitenzahlen: Bool

    static let alle: [Buchstil] = [tagebuch, magazin, album, journal, klar, postkarte]

    // MARK: - Die sechs

    // Das Tagebuch steht als STIL in der Liste, nicht als Seitenmuster
    // hinter einem Tagesmenü (ab 1.0.32).
    //
    // Es gab „Text und Bilder im Wechsel" seit 1.0.29 — als `Seitenmuster`,
    // also dort, wo man einen einzelnen Tag anders setzen lässt. Der Nutzer
    // hat es dreimal nicht gefunden und beim dritten Mal gesagt, wo er es
    // sucht: bei Fotobuch und Magazin. Er hat recht, und es ist nicht bloß
    // eine Frage des Ortes — ein durchgehend erzählendes Buch ist eine
    // Handschrift und kein Sonderfall eines Tages. Dieselbe Lehre wie beim
    // Gruppenchat in Schulalarm und beim Sichtumschalter der Abfahrtstafel:
    // Was niemand findet, gibt es für den Menschen davor nicht.
    static let tagebuch = Buchstil(
        id: "tagebuch",
        name: "Tagebuch",
        beschreibung: "Text und Bilder wechseln sich über alle Seiten ab, jede Seite anders aufgeteilt. Jeder Tag beginnt mit einem breiten Aufmacherbild.",
        typografie: {
            var t = Typografie()
            t.titel = Schriftbild(familie: .iowan, groesse: 27, zeilenabstand: 1.1,
                                  absatzabstand: 0, ausrichtung: .links, fett: true)
            t.datum = Schriftbild(familie: .avenir, groesse: 8.5, zeilenabstand: 1.2,
                                  absatzabstand: 0, ausrichtung: .links,
                                  farbe: Farbwert(rot: 0.58, gruen: 0.33, blau: 0.20),
                                  versalien: true, sperrung: 2.0)
            t.flieText = Schriftbild(familie: .iowan, groesse: 10.4, zeilenabstand: 1.5,
                                     absatzabstand: 7, ausrichtung: .links, trennung: true)
            t.bildunterschrift = Schriftbild(familie: .avenir, groesse: 7.2,
                                             zeilenabstand: 1.25, absatzabstand: 0,
                                             ausrichtung: .links, farbe: .leise,
                                             kursiv: true)
            return t
        }(),
        papier: Farbwert(rot: 0.996, gruen: 0.988, blau: 0.973),
        akzent: Farbwert(rot: 0.58, gruen: 0.33, blau: 0.20),
        randAussen: 16, randOben: 17, randUnten: 19, fuge: 5,
        eckenradius: 0, fotorand: 0, schatten: .keiner,
        randabfallendErlaubt: true,
        lebendig: true,
        musterVorliebe: [.wechsel, .bildZuerst, .karteSeitlich, .album, .bilderbogen],
        seitenzahlen: true
    )

    static let magazin = Buchstil(
        id: "magazin",
        name: "Magazin",
        beschreibung: "Große Bilder bis an den Rand, schmale Serifenschrift, viel Kontrast. Der Tag beginnt mit einem Aufmacher.",
        typografie: {
            var t = Typografie()
            t.titel = Schriftbild(familie: .didot, groesse: 30, zeilenabstand: 1.06,
                                  absatzabstand: 0, ausrichtung: .links, fett: false)
            t.datum = Schriftbild(familie: .avenir, groesse: 8, zeilenabstand: 1.2,
                                  absatzabstand: 0, ausrichtung: .links,
                                  farbe: Farbwert(rot: 0.62, gruen: 0.24, blau: 0.18),
                                  versalien: true, sperrung: 2.2)
            t.flieText = Schriftbild(familie: .charter, groesse: 10, zeilenabstand: 1.5,
                                     absatzabstand: 0, ausrichtung: .blocksatz, trennung: true)
            t.bildunterschrift = Schriftbild(familie: .avenir, groesse: 7, zeilenabstand: 1.25,
                                             absatzabstand: 0, ausrichtung: .links,
                                             farbe: .leise, versalien: true, sperrung: 0.8)
            return t
        }(),
        papier: Farbwert(rot: 1, gruen: 1, blau: 1),
        akzent: Farbwert(rot: 0.62, gruen: 0.24, blau: 0.18),
        randAussen: 18, randOben: 18, randUnten: 20, fuge: 3.5,
        eckenradius: 0, fotorand: 0, schatten: .keiner,
        randabfallendErlaubt: true,
        lebendig: false,
        musterVorliebe: [.wechsel, .vollbildAufmacher, .halbseitig, .karteSeitlich, .bilderbogen],
        seitenzahlen: true
    )

    static let album = Buchstil(
        id: "album",
        name: "Fotoalbum",
        beschreibung: "Bilder mit weißem Rand und Schatten, leicht gedreht und überlappend, auf getöntem Papier. Wie eingeklebt.",
        typografie: {
            var t = Typografie()
            t.titel = Schriftbild(familie: .handschrift, groesse: 26, zeilenabstand: 1.15,
                                  absatzabstand: 0, ausrichtung: .links)
            t.datum = Schriftbild(familie: .typewriter, groesse: 9, zeilenabstand: 1.2,
                                  absatzabstand: 0, ausrichtung: .links,
                                  farbe: Farbwert(rot: 0.45, gruen: 0.33, blau: 0.22),
                                  sperrung: 1.0)
            t.flieText = Schriftbild(familie: .iowan, groesse: 10.5, zeilenabstand: 1.48,
                                     absatzabstand: 7, ausrichtung: .links, trennung: true)
            t.bildunterschrift = Schriftbild(familie: .handschrift, groesse: 9,
                                             zeilenabstand: 1.2, absatzabstand: 0,
                                             ausrichtung: .mitte,
                                             farbe: Farbwert(rot: 0.34, gruen: 0.28, blau: 0.22))
            return t
        }(),
        papier: Farbwert(rot: 0.976, gruen: 0.961, blau: 0.933),
        akzent: Farbwert(rot: 0.55, gruen: 0.36, blau: 0.20),
        randAussen: 15, randOben: 16, randUnten: 18, fuge: 6,
        eckenradius: 0, fotorand: 2.6, schatten: .weich,
        randabfallendErlaubt: false,
        lebendig: true,
        musterVorliebe: [.wechsel, .album, .karteSeitlich, .bildZuerst, .bilderbogen],
        seitenzahlen: false
    )

    static let journal = Buchstil(
        id: "journal",
        name: "Journal",
        beschreibung: "Der Text trägt die Seite, die Bilder begleiten ihn. Ruhige Serifenschrift, breite Ränder.",
        typografie: {
            var t = Typografie()
            t.titel = Schriftbild(familie: .baskerville, groesse: 24, zeilenabstand: 1.14,
                                  absatzabstand: 0, ausrichtung: .links, fett: true)
            t.datum = Schriftbild(familie: .baskerville, groesse: 9.5, zeilenabstand: 1.2,
                                  absatzabstand: 0, ausrichtung: .links,
                                  farbe: .leise, kursiv: true, sperrung: 0.6)
            t.flieText = Schriftbild(familie: .baskerville, groesse: 11, zeilenabstand: 1.52,
                                     absatzabstand: 8, ausrichtung: .blocksatz, trennung: true)
            t.bildunterschrift = Schriftbild(familie: .baskerville, groesse: 8,
                                             zeilenabstand: 1.25, absatzabstand: 0,
                                             ausrichtung: .links, farbe: .leise, kursiv: true)
            return t
        }(),
        papier: Farbwert(rot: 0.992, gruen: 0.988, blau: 0.976),
        akzent: Farbwert(rot: 0.35, gruen: 0.36, blau: 0.42),
        randAussen: 22, randOben: 22, randUnten: 24, fuge: 4.5,
        eckenradius: 0, fotorand: 0, schatten: .keiner,
        randabfallendErlaubt: false,
        lebendig: false,
        musterVorliebe: [.wechsel, .textZuerst, .karteSeitlich, .bildZuerst],
        seitenzahlen: true
    )

    static let klar = Buchstil(
        id: "klar",
        name: "Klar",
        beschreibung: "Groteske, enge Raster, keine Zierde. Die Bilder sprechen für sich.",
        typografie: {
            var t = Typografie()
            t.titel = Schriftbild(familie: .avenir, groesse: 25, zeilenabstand: 1.1,
                                  absatzabstand: 0, ausrichtung: .links, fett: true)
            t.datum = Schriftbild(familie: .avenir, groesse: 8.5, zeilenabstand: 1.2,
                                  absatzabstand: 0, ausrichtung: .links,
                                  farbe: Farbwert(rot: 0.15, gruen: 0.45, blau: 0.52),
                                  fett: true, versalien: true, sperrung: 1.6)
            t.flieText = Schriftbild(familie: .avenir, groesse: 9.8, zeilenabstand: 1.55,
                                     absatzabstand: 8, ausrichtung: .links, trennung: true)
            t.bildunterschrift = Schriftbild(familie: .avenir, groesse: 7, zeilenabstand: 1.3,
                                             absatzabstand: 0, ausrichtung: .links, farbe: .leise)
            return t
        }(),
        papier: Farbwert(rot: 1, gruen: 1, blau: 1),
        akzent: Farbwert(rot: 0.15, gruen: 0.45, blau: 0.52),
        randAussen: 14, randOben: 15, randUnten: 17, fuge: 3,
        eckenradius: 1.5, fotorand: 0, schatten: .keiner,
        randabfallendErlaubt: true,
        lebendig: false,
        musterVorliebe: [.wechsel, .bilderbogen, .halbseitig, .karteOben, .karteSeitlich],
        seitenzahlen: true
    )

    static let postkarte = Buchstil(
        id: "postkarte",
        name: "Postkarte",
        beschreibung: "Warmes Papier, kräftige Farbe, Bilder mit weichen Ecken und Schatten. Freundlich statt streng.",
        typografie: {
            var t = Typografie()
            t.titel = Schriftbild(familie: .rundeSystem, groesse: 26, zeilenabstand: 1.12,
                                  absatzabstand: 0, ausrichtung: .links, fett: true)
            t.datum = Schriftbild(familie: .rundeSystem, groesse: 9, zeilenabstand: 1.2,
                                  absatzabstand: 0, ausrichtung: .links,
                                  farbe: Farbwert(rot: 0.85, gruen: 0.43, blau: 0.16),
                                  fett: true, versalien: true, sperrung: 1.2)
            t.flieText = Schriftbild(familie: .rundeSystem, groesse: 10.2, zeilenabstand: 1.5,
                                     absatzabstand: 8, ausrichtung: .links, trennung: true)
            t.bildunterschrift = Schriftbild(familie: .rundeSystem, groesse: 7.5,
                                             zeilenabstand: 1.25, absatzabstand: 0,
                                             ausrichtung: .links, farbe: .leise)
            return t
        }(),
        papier: Farbwert(rot: 0.996, gruen: 0.976, blau: 0.945),
        akzent: Farbwert(rot: 0.85, gruen: 0.43, blau: 0.16),
        randAussen: 16, randOben: 17, randUnten: 19, fuge: 4.5,
        eckenradius: 3, fotorand: 0, schatten: .weich,
        randabfallendErlaubt: true,
        lebendig: true,
        musterVorliebe: [.wechsel, .bildZuerst, .karteSeitlich, .album, .bilderbogen],
        seitenzahlen: true
    )

    static func nach(_ id: String) -> Buchstil {
        alle.first { $0.id == id } ?? magazin
    }
}
