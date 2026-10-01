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
/// Reihe freiwillig voll schreiben. Koordinaten: Seiten-Einheiten; wo jede
/// Reihe liegt und wie groß sie ist, sagt `Lage` (Buchstaben: gleich große
/// Reihen im Abstand `zeilenabstand`; Ziffern: Rechenkästchen in drei
/// Größen).
@Observable
final class Heftseite {
    static let zeilenabstand: CGFloat = 1.95

    /// Was eine Reihe verlangt, bevor es einen Prüfer dafür gibt.
    struct Vorgabe {
        enum Art: String, Codable { case einzeln, wechsel, wort }

        let art: Art
        /// Was am Anfang der Reihe steht.
        let muster: Zeichen
        /// Die Buchstaben einer Einheit, die wiederholt wird.
        let teile: [Zeichen]
        /// Silbe/Wort (eng) oder nur nebeneinander (A a im Wechsel).
        let imWort: Bool
        let mindestens: Int
        /// Ziffern in Rechenkästchen statt Buchstaben in der Lineatur.
        var kaestchen = false
        /// Größe der Reihe (1 = große Kästchen; kleiner = kleinere).
        var faktor: CGFloat = 1
    }

    /// Wo die Reihen einer Seite liegen (Seiten-Einheiten, y nach unten,
    /// 0 = oberer Rand des Inhalts). Reihen dürfen verschieden groß sein:
    /// Ziffern üben in großen, dann mittleren, dann kleinen Kästchen.
    struct Lage {
        /// Seiten-y von y = 0 der Reihe (Oberlinie bzw. Ziffer-Oberkante).
        var ursprung: [CGFloat] = []
        var faktor: [CGFloat] = []
        var kaestchen: [Bool] = []
        var hoehe: CGFloat = 0

        init(_ reihen: [(kaestchen: Bool, faktor: CGFloat)]) {
            var y: CGFloat = 0
            var vorher: CGFloat?
            for (k, f) in reihen {
                // Oben und unten der Reihe in ihren eigenen Einheiten.
                let oben: CGFloat = k ? Kaestchen.oben : -0.28
                let unten: CGFloat = k ? Kaestchen.oben + Kaestchen.seite : 1.5
                let luecke: CGFloat = k ? 0.22 : 0.17
                if let v = vorher { y += v != f ? 0.45 : 0 }
                ursprung.append(y - oben * f)
                faktor.append(f)
                kaestchen.append(k)
                y += (unten - oben) * f + luecke * f
                vorher = f
            }
            hoehe = y
        }

        /// Die Reihe, deren Mitte einem Punkt am nächsten liegt.
        func reihe(_ y: CGFloat) -> Int {
            var beste = 0
            var abstand = CGFloat.infinity
            for i in ursprung.indices {
                let mitte = ursprung[i] + (kaestchen[i] ? 0.5 : 0.6) * faktor[i]
                if abs(mitte - y) < abstand {
                    abstand = abs(mitte - y)
                    beste = i
                }
            }
            return beste
        }
    }

    struct Reihe {
        /// Was am Anfang der Reihe steht (Buchstabe, Silbe oder Wort).
        let muster: Zeichen
        let vorgabe: Vorgabe
        let pruefer: Heftpruefer
    }

    let reihen: [Reihe]
    let lage: Lage
    /// Die Reihe, in der zuletzt geschrieben wurde.
    private(set) var aktiv: Int?
    private(set) var fehlerZaehler = 0
    private(set) var strichZaehler = 0
    private(set) var hinweisText: String?
    /// Wann die Pflicht aller Reihen erfüllt war — Sterne zählen bis dahin.
    private(set) var geschafftBeiFehlern: Int?

    /// Wo die Schreibfläche einer Reihe beginnt (rechts vom Muster).
    static func musterEnde(_ muster: Zeichen) -> CGFloat { muster.rahmen.maxX + 0.35 }

    init(vorgaben: [Vorgabe], genauigkeit: Genauigkeit) {
        reihen = vorgaben.map { v in
            // Genug Wiederholungen, dass jede Reihe voll werden kann.
            let folge = Array(repeating: v.teile, count: 30).flatMap { $0 }
            let pruefer = v.kaestchen
                ? Heftpruefer(folge: folge, einheitLaenge: v.teile.count, imWort: false,
                              mindestens: v.mindestens, genauigkeit: genauigkeit, kaestchenStart: v.teile.count)
                : Heftpruefer(folge: folge, einheitLaenge: v.teile.count, imWort: v.imWort,
                              mindestens: v.mindestens, genauigkeit: genauigkeit,
                              rechtsVon: Heftseite.musterEnde(v.muster))
            return Reihe(muster: v.muster, vorgabe: v, pruefer: pruefer)
        }
        lage = Lage(vorgaben.map { ($0.kaestchen, $0.faktor) })
    }

    /// Wie weit eine Reihe nach rechts reichen muss: Muster und Pflicht.
    func bedarf(_ r: Int) -> CGFloat {
        let reihe = reihen[r]
        if reihe.vorgabe.kaestchen {
            let kaesten = reihe.vorgabe.teile.count * (1 + reihe.pruefer.mindestens)
            return (CGFloat(kaesten) * Kaestchen.seite + 0.3) * lage.faktor[r]
        }
        return Self.musterEnde(reihe.muster) + CGFloat(reihe.pruefer.mindestens) * (reihe.muster.rahmen.width + 0.9) + 0.4
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

    /// Die Reihe, in der gerade geschrieben wird (vor dem ersten Strich die erste).
    var aktuelleReihe: Reihe { reihen[aktiv ?? 0] }

    func hilfeAnfordern() {
        aktuelleReihe.pruefer.hilfeAnfordern()
    }

    /// Buchstaben mit Hilfe auf der ganzen Seite.
    var hilfen: Int { reihen.reduce(0) { $0 + $1.pruefer.hilfen } }

    func abbrechen() {
        for reihe in reihen { reihe.pruefer.abbrechen() }
    }

    /// Welche Reihe gemeint ist: Schreibt das Kind gerade an einem
    /// Buchstaben (i-Punkt, zweiter Strich, Unterlänge), bleibt es bei
    /// dessen Reihe, solange der Stift in ihrer Nähe ansetzt; sonst die
    /// Reihe, in deren Linien der Ansatz liegt.
    private func reihe(fuer p: CGPoint) -> Int {
        if let r = aktiv, reihen[r].pruefer.imBuchstaben {
            let y = lokal(p, r).y
            if y > -0.7 && y < 1.9 { return r }
        }
        return lage.reihe(p.y)
    }

    /// Seite → Einheiten der Reihe (ihr Maßstab, ihr Ursprung).
    private func lokal(_ p: CGPoint, _ r: Int) -> CGPoint {
        CGPoint(x: p.x / lage.faktor[r], y: (p.y - lage.ursprung[r]) / lage.faktor[r])
    }
}

typealias Reihenvorgabe = Heftseite.Vorgabe

extension Heftseite.Vorgabe {
    /// Ein Buchstabe, dreimal.
    static func einzeln(_ z: Zeichen) -> Self {
        Self(art: .einzeln, muster: z, teile: [z], imWort: false, mindestens: 3)
    }

    /// Groß und klein im Wechsel („A a A a“) — mit Abstand, nicht als Wort.
    static func wechsel(_ paar: [Zeichen]) -> Self {
        let muster = Zeichenvorrat.folge(id: paar.map(\.id).joined(separator: " "), paar, abstand: 0.35)
        return Self(art: .wechsel, muster: muster, teile: paar, imWort: false, mindestens: 2)
    }

    /// Silbe oder Wort: kurze zweimal, längere einmal.
    static func wort(_ w: Zeichen) -> Self {
        let teile = w.istFolge ? w.folge : [w]
        return Self(art: .wort, muster: w, teile: teile, imWort: true, mindestens: teile.count <= 3 ? 2 : 1)
    }
}

extension Heftseite.Vorgabe {
    /// Ziffern in Rechenkästchen: die Muster-Ziffer(n) im ersten Kästchen
    /// bzw. den ersten Kästchen, jede weitere Ziffer in das nächste.
    static func kaestchen(_ teile: [Zeichen], faktor: CGFloat, mindestens: Int) -> Self {
        let muster = teile.count == 1 ? teile[0] : Zeichenvorrat.kaestchenFolge(teile)
        return Self(art: teile.count == 1 ? .einzeln : .wechsel, muster: muster, teile: teile, imWort: false,
                    mindestens: mindestens, kaestchen: true, faktor: faktor)
    }

    /// Eine gespeicherte Reihe wieder aufbauen (Klassenübersicht).
    static func aus(teile ids: [String], art: Art, kaestchen: Bool = false, faktor: CGFloat = 1) -> Self? {
        let teile = ids.compactMap { Zeichenvorrat.zeichen(id: $0) }
        guard teile.count == ids.count, let erster = teile.first else { return nil }
        if kaestchen { return .kaestchen(teile, faktor: faktor, mindestens: 1) }
        switch art {
        case .einzeln: return .einzeln(erster)
        case .wechsel: return .wechsel(teile)
        case .wort:
            return .wort(teile.count == 1 ? erster
                         : Zeichenvorrat.folge(id: ids.joined(), teile, abstand: 0.16))
        }
    }
}
