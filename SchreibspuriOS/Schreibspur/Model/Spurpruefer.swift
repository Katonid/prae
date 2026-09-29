import CoreGraphics
import Foundation
import Observation

/// Prüft, ob ein Kind ein Zeichen bewegungsrichtig nachspurt.
///
/// Angenommen wird nur, was die Lehrkraft auch annähme:
///
/// * **Anfang:** Jeder Strich beginnt am roten Startpunkt. Wer am Ziel
///   ansetzt, bekommt „andersherum" zu hören.
/// * **Richtung:** Der Fortschritt läuft nur vorwärts den Weg entlang.
///   Wer zurück oder quer fährt, verlässt das Suchfenster und damit die Spur.
/// * **Ordentlich:** Der Finger bleibt in einem Band um die Mittellinie des
///   Strichs (Breite je nach Einstellung „Genauigkeit").
/// * **Absetzen:** Nur am Ziel des Strichs. Hebt das Kind vorher ab, gilt
///   der Strich als nicht geschafft und beginnt von vorn.
///
/// Alle Maße in Einheiten des Vierliniensystems (Oberlinie bis Grundlinie = 1).
@Observable
final class Spurpruefer {

    enum Hinweis: Equatable {
        case amStartBeginnen
        case andersherum
        case aufDerSpurBleiben
        case nichtAbsetzen

        var text: String {
            switch self {
            case .amStartBeginnen: "Fang beim roten Pfeil an!"
            case .andersherum: "Andersherum! Beginne beim Pfeil."
            case .aufDerSpurBleiben: "Bleib auf der Spur!"
            case .nichtAbsetzen: "Nicht absetzen – schreib bis zum Kreis!"
            }
        }
    }

    let zeichen: Zeichen
    /// Halbe Breite des erlaubten Bandes um den Strich.
    var toleranz: CGFloat

    private(set) var strichNummer = 0
    /// Geschaffte Weglänge im aktuellen Strich.
    private(set) var fortschritt: CGFloat = 0
    private(set) var schreibtGerade = false
    private(set) var fehler = 0
    private(set) var hinweis: Hinweis?
    /// Zählt jeden Fehler hoch — Anlass für Wackeln und Rückmeldung.
    private(set) var fehlerZaehler = 0
    /// Zählt jeden geschafften Strich hoch.
    private(set) var strichZaehler = 0

    private var letzterPunkt: CGPoint?

    init(zeichen: Zeichen, toleranz: CGFloat) {
        self.zeichen = zeichen
        self.toleranz = toleranz
    }

    var fertig: Bool { strichNummer >= zeichen.striche.count }

    var aktuellerStrich: Strich? {
        fertig ? nil : zeichen.striche[strichNummer]
    }

    /// 3 Sterne ohne Fehler, 2 bei höchstens zwei, sonst 1.
    var sterne: Int {
        switch fehler {
        case 0: 3
        case 1...2: 2
        default: 1
        }
    }

    // MARK: Eingabe

    func beginnen(bei p: CGPoint) {
        guard let strich = aktuellerStrich else { return }
        let fang = toleranz * 1.5
        if p.abstand(zu: strich.anfang) <= fang {
            hinweis = nil
            schreibtGerade = true
            fortschritt = 0
            letzterPunkt = p
        } else if !strich.istPunkt, p.abstand(zu: strich.ende) <= fang {
            fehlerMelden(.andersherum)
        } else {
            fehlerMelden(.amStartBeginnen)
        }
    }

    func bewegen(nach p: CGPoint) {
        guard schreibtGerade, let strich = aktuellerStrich else { return }
        let von = letzterPunkt ?? p
        // Schnelle Bewegungen in kleine Schritte zerlegen, damit kein Stück
        // des Wegs übersprungen wird.
        let schritt = toleranz * 0.4
        let anzahl = max(1, Int(ceil(von.abstand(zu: p) / schritt)))
        for k in 1...anzahl {
            let q = von.mitte(zu: p, anteil: CGFloat(k) / CGFloat(anzahl))
            if !pruefen(q, auf: strich) { return }
        }
        letzterPunkt = p
    }

    func beenden(bei p: CGPoint) {
        guard schreibtGerade, let strich = aktuellerStrich else { return }
        bewegen(nach: p)
        guard schreibtGerade else { return }  // unterwegs schon von der Spur
        schreibtGerade = false
        letzterPunkt = nil
        if strich.istPunkt || fortschritt >= strich.gesamt - toleranz * 0.9 {
            strichGeschafft()
        } else {
            fehlerMelden(.nichtAbsetzen)
        }
    }

    /// Das System hat die Berührung abgebrochen (z. B. ein Anruf) — kein
    /// Fehler des Kindes, der Strich beginnt einfach neu.
    func abbrechen() {
        schreibtGerade = false
        letzterPunkt = nil
        fortschritt = 0
    }

    func vonVorn() {
        abbrechen()
        strichNummer = 0
        fehler = 0
        hinweis = nil
    }

    // MARK: Intern

    private func pruefen(_ q: CGPoint, auf strich: Strich) -> Bool {
        if strich.istPunkt {
            if q.abstand(zu: strich.anfang) > toleranz * 1.8 {
                fehlerMelden(.aufDerSpurBleiben)
                return false
            }
            return true
        }
        // Suchfenster und Gleichstand sind mit `scripts/spur-simulation.py`
        // abgestimmt: Sauberes Nachspuren mit Zittern wird bei allen
        // Zeichen angenommen, verkehrt herum oder halb geschrieben nie.
        // Ein kürzerer Blick nach vorn lässt spitze Ecken (W) abbrechen,
        // ein längerer lässt den Fortschritt beim n über den Rückweg
        // springen.
        let stelle = strich.naechsteStelle(
            zu: q,
            von: max(0, fortschritt - toleranz * 1.5),
            bis: fortschritt + toleranz * 3.5,
            bezug: fortschritt,
            gleichstand: toleranz * 0.05
        )
        guard stelle.abstand <= toleranz else {
            fehlerMelden(.aufDerSpurBleiben)
            return false
        }
        fortschritt = max(fortschritt, stelle.s)
        return true
    }

    private func strichGeschafft() {
        strichNummer += 1
        fortschritt = 0
        hinweis = nil
        strichZaehler += 1
    }

    private func fehlerMelden(_ art: Hinweis) {
        schreibtGerade = false
        letzterPunkt = nil
        fortschritt = 0
        fehler += 1
        hinweis = art
        fehlerZaehler += 1
    }
}
