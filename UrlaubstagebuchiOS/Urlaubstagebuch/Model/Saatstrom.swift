import Foundation

// Ein Zufallsstrom, der sich WIEDERHOLEN lässt.
//
// `SystemRandomNumberGenerator` kann das nicht — er liefert bei jedem Lauf
// etwas anderes, und genau das ist bei einem gedruckten Buch der falsche
// Zufall: Das Papierkorn sah auf dem Bildschirm bei jeder Neuzeichnung
// anders aus (ein Flimmern statt einer Struktur), und die gedruckte Seite
// sah nie aus wie die angesehene.
//
// Gerechnet wird mit splitmix64 — demselben Schlussmischer wie bei den
// Linienfarben der Abfahrtstafel. Zwei Zeilen, kein fremdes Paket, und für
// ein Korn auf Papier gut genug; für irgendetwas Sicherheitsrelevantes ist
// er ausdrücklich NICHT gedacht.
struct Saatstrom: RandomNumberGenerator {
    private var stand: UInt64

    init(_ saat: UInt64) {
        // Ein Anfangswert von 0 gäbe sonst eine sehr regelmäßige erste
        // Zahl; der Streuschritt vorweg kostet nichts.
        stand = saat &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    }

    mutating func next() -> UInt64 {
        stand &+= 0x9E37_79B9_7F4A_7C15
        var z = stand
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

extension UUID {
    // Eine feste Zahl aus einer Kennung.
    //
    // NICHT `hashValue`: Den streut Swift bei jedem Programmlauf neu, und
    // dann sähe dieselbe Seite nach jedem Start der App anders aus —
    // dieselbe Falle wie bei den Linienfarben der Abfahrtstafel. Gelesen
    // werden die ersten acht Bytes, und die sind in jeder Kennung dieselben.
    var saat: UInt64 {
        let teile = uuid
        var wert: UInt64 = 0
        for byte in [teile.0, teile.1, teile.2, teile.3,
                     teile.4, teile.5, teile.6, teile.7]
        {
            wert = (wert << 8) | UInt64(byte)
        }
        return wert
    }
}
