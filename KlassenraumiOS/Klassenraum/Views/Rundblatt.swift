import SwiftUI

// Bausteine für runde Blätter — Uhr und Timer teilen sie sich.
//
// Warum eigene Formen statt gedrehter Rechtecke und Kapseln?
//
// `rotationEffect` dreht nicht die Geometrie, sondern die schon gezeichnete
// Ebene: Sie wird einmal gerastert und dann schräg gestellt, und dabei jeder
// Bildpunkt neu abgetastet. Bei 60 dünnen Strichen und zwölf Zahlen summiert
// sich das zu genau dem, was auf der Tafel auffiel — das Zifferblatt wirkte
// weich, obwohl alles vektoriell gezeichnet ist.
//
// Ein `Shape` wird dagegen in der Auflösung seiner Ebene gezeichnet: Die
// Drehung steckt in den Koordinaten, nicht in einer Bildtransformation. Die
// Striche bleiben scharf, und aus sechzig Ebenen wird eine.
//
// Dieselbe Überlegung gilt für Zahlen: Sie stehen jetzt aufrecht an ihrem
// Platz (`Rundblatt.stelle`), statt hin- und zurückgedreht zu werden.

enum Rundblatt {
    /// Wo ein Punkt auf dem Blatt liegt. 0° ist oben, positiv im
    /// Uhrzeigersinn — wie auf einer Uhr.
    static func versatz(_ grad: Double, radius: Double) -> CGSize {
        let bogen = (grad - 90) * .pi / 180
        return CGSize(width: cos(bogen) * radius, height: sin(bogen) * radius)
    }
}

/// Striche auf einem Rundblatt, alle in einem einzigen Pfad.
struct Skalenstriche: Shape {
    /// Winkel der Striche in Grad (0 = oben, im Uhrzeigersinn).
    var winkel: [Double]
    /// Äußeres und inneres Ende, als Anteil des halben Blatts.
    var aussen: Double
    var innen: Double
    /// Strichstärke in Punkten.
    var staerke: Double
    /// Runde Enden — die Uhr zeichnet gerade, der Timer runde.
    var rund: Bool = false

    func path(in rect: CGRect) -> Path {
        let halbe = min(rect.width, rect.height) / 2
        let mitte = CGPoint(x: rect.midX, y: rect.midY)
        var pfad = Path()
        for grad in winkel {
            let bogen = (grad - 90) * .pi / 180
            let dx = cos(bogen), dy = sin(bogen)
            var strich = Path()
            strich.move(to: CGPoint(x: mitte.x + dx * halbe * aussen,
                                    y: mitte.y + dy * halbe * aussen))
            strich.addLine(to: CGPoint(x: mitte.x + dx * halbe * innen,
                                       y: mitte.y + dy * halbe * innen))
            pfad.addPath(strich.strokedPath(StrokeStyle(lineWidth: staerke,
                                                        lineCap: rund ? .round : .butt)))
        }
        return pfad
    }
}

/// Ein Zeiger vom Mittelpunkt nach außen. Der Winkel ist animierbar, damit
/// Sekundenzeiger und Timerzeiger weiterlaufen wie bisher.
struct Zeigerstrich: Shape {
    /// Winkel in Grad (0 = oben, im Uhrzeigersinn).
    var winkel: Double
    /// Länge ab Mittelpunkt, in Punkten.
    var laenge: Double
    var staerke: Double
    /// Wie weit der Zeiger über den Mittelpunkt hinaussteht (Gegengewicht).
    var ueberstand: Double = 0

    var animatableData: Double {
        get { winkel }
        set { winkel = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let mitte = CGPoint(x: rect.midX, y: rect.midY)
        let bogen = (winkel - 90) * .pi / 180
        let dx = cos(bogen), dy = sin(bogen)
        var pfad = Path()
        pfad.move(to: CGPoint(x: mitte.x - dx * ueberstand, y: mitte.y - dy * ueberstand))
        pfad.addLine(to: CGPoint(x: mitte.x + dx * laenge, y: mitte.y + dy * laenge))
        return pfad.strokedPath(StrokeStyle(lineWidth: staerke, lineCap: .round))
    }
}
