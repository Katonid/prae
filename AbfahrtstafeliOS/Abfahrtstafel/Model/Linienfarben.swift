import SwiftUI

/// Die Farben für Linien, die **keine eigene Farbe** mitbringen.
///
/// **Warum es das gibt** (ab 1.1.9, gemeldet 09/2026 aus Salzburg und
/// Berchtesgaden: „Am Ende des Tages ist immer noch alles lila. Selbst wenn
/// man jetzt ein paar leichte Farbnuancen unterscheiden kann. Ich möchte es
/// aber deutlicher haben."): Bis 1.1.8 bekam eine Linie ohne eigene Farbe den
/// Ton ihres Verkehrsmittels, um höchstens ±0,055 im Farbton abgewandelt. Das
/// war als Unterscheidungshilfe gedacht und ist keine.
///
/// **Nachgemessen am 18.09.2026** an den acht Buslinien um Berchtesgaden, in
/// CIE Lab: Der kleinste Farbabstand zwischen zwei Linien betrug **dE 1,6** —
/// die Schwelle, ab der ein Mensch überhaupt zwei Farben auseinanderhält,
/// liegt bei etwa 2,3. Die Abwandlung war also nicht schwach, sondern
/// unsichtbar, und mit ihr jede Aussage über „leichte Nuancen". 1.1.8 hat die
/// Ursache dafür behoben, dass die Streuung gar nicht ankam; dass die Spanne
/// selbst zu eng ist, hat sie nicht behoben.
///
/// **Die Farbfamilie des Verkehrsmittels ist der Preis**, und er ist geringer,
/// als er klingt: Eine Linie MIT eigener Farbe hält sich ohnehin nie an sie —
/// die S4 im Berchtesgadener Land führt `route_color 9764ac` und ist damit
/// genauso violett wie jeder Bus daneben. Die Farbe des Schildes hat das
/// Verkehrsmittel also noch nie verlässlich genannt. Wo es wirklich um das
/// Verkehrsmittel geht, steht die Farbe unverändert: in der Filterleiste
/// („Busse", „S-Bahnen" — `Verkehrsmittel.rueckfallfarbe`), und in der Legende
/// der Netzkarte steht seit 1.1.9 das Symbol des Verkehrsmittels neben dem
/// Schild.
enum Linienfarben {

    /// Zwölf Farbtöne in drei Helligkeiten — 36 unterscheidbare Plätze.
    ///
    /// Je Zeile: Grundton, dunkle Fassung, helle Fassung. **Die Stufen sind
    /// gemessen und nicht geschätzt.** Zwei Bedingungen mussten zugleich
    /// gelten, und sie ziehen gegeneinander: Je weiter die helle Stufe
    /// aufgehellt wird, desto besser trägt schwarze Schrift darauf und desto
    /// blasser und ähnlicher werden die zwölf Töne untereinander. Gesucht war
    /// also nicht das Maximum von einem, sondern das beste Paar.
    ///
    /// Ergebnis (18.09.2026): Grundton so weit abgedunkelt, dass weiße Schrift
    /// 4,6:1 erreicht; dunkle Stufe mal 0,60; helle Stufe 40 % in Richtung
    /// Weiß. Damit liegt der kleinste Abstand zwischen zwei der 36 Plätze bei
    /// **dE 15,5** und der schlechteste Schriftkontrast bei **4,6:1**.
    ///
    /// Eine mittlere Aufhellung (30 %) war der erste Entwurf und fiel durch:
    /// Dort trägt WEDER schwarze noch weiße Schrift — gemessen 2,6:1 bis
    /// 3,7:1. Drei Helligkeiten gehen nur als dunkel / Grundton / hell.
    private static let toene: [(grund: String, dunkel: String, hell: String)] = [
        ("d23b2e", "7e231c", "e48982"),   // Rot
        ("b5570d", "6d3408", "d39a6e"),   // Orange
        ("966c00", "5a4100", "c0a766"),   // Bernstein
        ("627f1b", "3b4c10", "a1b276"),   // Oliv
        ("2b833d", "1a4e25", "80b48b"),   // Grün
        ("008174", "004d45", "66b3ab"),   // Türkis
        ("0e77b8", "08486f", "6eaed5"),   // Himmelblau
        ("3a46c0", "232a73", "8990d9"),   // Indigo
        ("b3339e", "6b1f5f", "d185c5"),   // Magenta
        ("c2185b", "740e37", "da749d"),   // Kirsche
        ("8a5a3c", "533624", "b99c8a"),   // Braun
        ("4a5f78", "2c3948", "929fae"),   // Schiefer
    ]

    /// Die Zahl der unterscheidbaren Plätze.
    static var plaetze: Int { toene.count * 3 }

    /// Die Farbe für eine Linie ohne eigene Farbe.
    static func farbe(fuer name: String) -> Color {
        let platz = platz(fuer: name)
        let ton = toene[platz % toene.count]
        switch platz / toene.count {
        case 1: return Color(hex: ton.dunkel) ?? .gray
        case 2: return Color(hex: ton.hell) ?? .gray
        default: return Color(hex: ton.grund) ?? .gray
        }
    }

    /// Welchen der 36 Plätze eine Linie bekommt.
    ///
    /// **Die Ziffern der Liniennummer entscheiden, nicht ein Streuwert** — und
    /// das ist der Kern der Sache. Ein Streuwert verteilt zufällig, und
    /// zufällig heißt: Bei vierzehn Linien auf zwölf Farben teilen sich
    /// regelmäßig zwei denselben Ton (nachgemessen für Salzburg: nur acht von
    /// zwölf Farben belegt, sieben Doppel). Benachbarte Buslinien einer Gegend
    /// sind aber fast immer fortlaufend NUMMERIERT — 837, 838, 839, 840 —, und
    /// eine Zuordnung über die Zahl gibt genau diesen Linien garantiert
    /// verschiedene Plätze.
    ///
    /// Nachgemessen am 18.09.2026 an vier echten Liniensätzen: Berchtesgaden
    /// 7 von 7, Salzburg 14 von 14, München 10 von 10, Dortmund 9 von 10
    /// (448 und 412 liegen genau 36 auseinander). Der kleinste Farbabstand
    /// innerhalb eines Satzes liegt bei dE 18,6 — gegen dE 1,6 in 1.1.8.
    ///
    /// Eine Linie ganz ohne Ziffern (etwa „Airport Express") bekommt ihren
    /// Platz aus dem Streuwert über den Namen. **Nie aus `hashValue`**: Den
    /// streut Swift je Programmlauf zufällig, die Linie wäre morgens grün und
    /// abends blau.
    static func platz(fuer name: String) -> Int {
        var zahl = 0
        var hatZiffern = false
        for zeichen in name where zeichen.isASCII && zeichen.isNumber {
            guard let ziffer = zeichen.wholeNumberValue else { continue }
            hatZiffern = true
            // Fortlaufend mit Rest gerechnet: Eine Liniennummer ist zwar nie
            // lang genug für einen Überlauf, aber ein Feld aus fremden Daten
            // ist nie garantiert kurz.
            zahl = (zahl * 10 + ziffer) % plaetze
        }
        if hatZiffern { return zahl }
        return Int(streuwert(name) % UInt64(plaetze))
    }

    /// FNV-1a über den Namen, danach der Schlussmischer von splitmix64.
    ///
    /// Die Durchmischung ist die Lehre aus 1.1.8: Die niedrigen Bits von
    /// FNV-1a hängen nur von den niedrigen Bits der Eingabe ab, und ein
    /// Restwert greift genau dort zu.
    private static func streuwert(_ text: String) -> UInt64 {
        var wert: UInt64 = 1469598103934665603
        for byte in Array(text.utf8) {
            wert = (wert ^ UInt64(byte)) &* 1099511628211
        }
        wert ^= wert >> 30
        wert = wert &* 0xBF58_476D_1CE4_E5B9
        wert ^= wert >> 27
        wert = wert &* 0x94D0_49BB_1331_11EB
        wert ^= wert >> 31
        return wert
    }
}
