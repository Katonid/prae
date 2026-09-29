import CoreGraphics
import Foundation
import Observation

/// Stufe 5 als Heftseite: mehrere Reihen untereinander, am Anfang jeder
/// Reihe steht, was darin mehrfach geschrieben wird (Ansage des Nutzers
/// 09/2026) — bei einem Buchstaben der Großbuchstabe, der Kleinbuchstabe
/// und erste Verbindungen („Ma“, „ma“); bei Wörtern je Reihe ein Wort; beim
/// gemischten Üben je Reihe ein anderer bekannter Buchstabe.
///
/// Jede Reihe hat eine Pflicht (`mindestens`); danach darf das Kind die
/// Reihe freiwillig voll schreiben. Koordinaten: Einheiten der Lineatur,
/// Reihe `r` liegt um `r × zeilenabstand` tiefer.
@Observable
final class Heftseite {
    static let zeilenabstand: CGFloat = 1.95

    struct Reihe {
        /// Was am Anfang der Reihe steht (Buchstabe, Silbe oder Wort).
        let muster: Zeichen
        let pruefer: Heftpruefer
    }

    let reihen: [Reihe]
    /// Die Reihe, in der zuletzt geschrieben wurde.
    private(set) var aktiv: Int?
    private(set) var fehlerZaehler = 0
    private(set) var strichZaehler = 0
    private(set) var hinweisText: String?
    /// Wann die Pflicht aller Reihen erfüllt war — Sterne zählen bis dahin.
    private(set) var geschafftBeiFehlern: Int?

    /// Wo die Schreibfläche einer Reihe beginnt (rechts vom Muster).
    static func musterEnde(_ muster: Zeichen) -> CGFloat { muster.rahmen.maxX + 0.35 }

    init(muster: [Zeichen], mindestens: (Zeichen) -> Int, genauigkeit: Genauigkeit) {
        reihen = muster.map { m in
            let teile = m.istFolge ? m.folge : [m]
            // Genug Wiederholungen, dass jede Reihe voll werden kann.
            let folge = Array(repeating: teile, count: 30).flatMap { $0 }
            return Reihe(muster: m, pruefer: Heftpruefer(folge: folge, einheitLaenge: teile.count,
                                                          mindestens: mindestens(m), genauigkeit: genauigkeit,
                                                          rechtsVon: Heftseite.musterEnde(m)))
        }
    }

    /// Ändert sich bei jedem Punkt, den das Kind schreibt — damit die
    /// Ansicht neu zeichnet (der Canvas selbst wird nicht beobachtet).
    var stand: Int {
        reihen.reduce(0) { summe, r in
            summe + r.pruefer.aktuelleTinte.count + 100 * r.pruefer.strichNummer + 1000 * r.pruefer.fertige.count
        }
    }

    var fehler: Int { reihen.reduce(0) { $0 + $1.pruefer.fehler } }
    /// Alle Pflichten erfüllt.
    var geschafft: Bool { reihen.allSatisfy { $0.pruefer.fertig } }

    var sterne: Int {
        switch geschafftBeiFehlern ?? fehler {
        case 0: 3
        case 1...3: 2
        default: 1
        }
    }

    // MARK: Eingabe (Punkte in Seiten-Einheiten)

    func beginnen(bei p: CGPoint) {
        let r = reihe(fuer: p)
        aktiv = r
        reihen[r].pruefer.beginnen(bei: lokal(p, r))
    }

    func bewegen(nach p: CGPoint) {
        guard let r = aktiv else { return }
        reihen[r].pruefer.bewegen(nach: lokal(p, r))
    }

    func beenden(bei p: CGPoint) {
        guard let r = aktiv else { return }
        let pruefer = reihen[r].pruefer
        let fehlerVorher = pruefer.fehlerZaehler, striche = pruefer.strichZaehler
        pruefer.beenden(bei: lokal(p, r))
        if pruefer.fehlerZaehler > fehlerVorher {
            hinweisText = pruefer.hinweisText
            fehlerZaehler += 1
        } else if pruefer.strichZaehler > striche {
            hinweisText = nil
            if geschafft, geschafftBeiFehlern == nil { geschafftBeiFehlern = fehler }
            strichZaehler += 1
        }
    }

    func abbrechen() {
        for reihe in reihen { reihe.pruefer.abbrechen() }
    }

    /// Welche Reihe gemeint ist: Schreibt das Kind gerade an einem
    /// Buchstaben (i-Punkt, zweiter Strich, Unterlänge), bleibt es bei
    /// dessen Reihe, solange der Stift in ihrer Nähe ansetzt; sonst die
    /// Reihe, in deren Linien der Ansatz liegt.
    private func reihe(fuer p: CGPoint) -> Int {
        if let r = aktiv, reihen[r].pruefer.imBuchstaben {
            let y = p.y - CGFloat(r) * Self.zeilenabstand
            if y > -0.7 && y < 1.9 { return r }
        }
        let r = Int(((p.y + 0.3) / Self.zeilenabstand).rounded(.down))
        return min(max(r, 0), reihen.count - 1)
    }

    private func lokal(_ p: CGPoint, _ r: Int) -> CGPoint {
        CGPoint(x: p.x, y: p.y - CGFloat(r) * Self.zeilenabstand)
    }
}
