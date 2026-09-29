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

        /// `mitHilfen`: ob Pfeil und Zielkreis zu sehen sind — beim freien
        /// Schreiben gibt es keinen Pfeil, auf den der Satz zeigen könnte.
        func text(mitHilfen: Bool) -> String {
            switch (self, mitHilfen) {
            case (.amStartBeginnen, true): "Fang beim roten Pfeil an!"
            case (.amStartBeginnen, false): "Da fängt der Strich nicht an."
            case (.andersherum, true): "Andersherum! Beginne beim Pfeil."
            case (.andersherum, false): "Andersherum!"
            case (.aufDerSpurBleiben, true): "Bleib auf der Spur!"
            case (.aufDerSpurBleiben, false): "Schau noch mal genau hin!"
            case (.nichtAbsetzen, true): "Nicht absetzen – schreib bis zum Kreis!"
            case (.nichtAbsetzen, false): "Nicht absetzen – schreib den Strich zu Ende!"
            }
        }
    }

    let zeichen: Zeichen
    /// Halbe Breite des erlaubten Bandes um den Strich.
    let toleranz: CGFloat
    /// Wie weit neben dem Startpunkt ein Strich beginnen darf.
    let fang: CGFloat
    /// Wie viel vom Ende eines Strichs beim Absetzen fehlen darf.
    let zielRest: CGFloat
    /// Maß für Suchfenster und Zerlegung. Bei breitem Band (freies
    /// Schreiben) wächst es nicht mit — sonst spränge der Fortschritt beim
    /// n über den Rückweg (siehe unten).
    private let such: CGFloat
    /// Freies Schreiben: Die Vorlage wandert mit dem ersten Ansatz mit.
    /// Ohne Spur schreibt kaum ein Kind genau an die gedachte Stelle — ein
    /// insgesamt etwas verschobenes, aber richtig geschriebenes Zeichen soll
    /// zählen. Form, Folge und Richtung werden danach wie sonst geprüft.
    let verschiebbar: Bool
    /// Um so viel liegt die Schrift des Kindes neben der Vorlage.
    private(set) var versatz: CGVector = .zero

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

    /// Was das Kind wirklich geschrieben hat, je geschafftem Strich — für
    /// die Stufen ohne Spur, auf denen die eigene Schrift zu sehen ist.
    private(set) var tinte: [[Tintenpunkt]] = []
    private(set) var aktuelleTinte: [Tintenpunkt] = []
    /// Wie nah der Stift zuletzt am Rand des erlaubten Bandes war (0…1).
    private var naehe: CGFloat = 0

    private var letzterPunkt: CGPoint?

    /// Fang und Zielrest sind gedeckelt: Beim freien Schreiben wird das
    /// Band breit, aber der Anfang eines Strichs darf nicht beliebig weit
    /// daneben liegen, und ein halber Querstrich bleibt ein halber.
    init(zeichen: Zeichen, toleranz: CGFloat, fangFaktor: CGFloat = 1.5, verschiebbar: Bool = false) {
        self.zeichen = zeichen
        self.verschiebbar = verschiebbar
        self.toleranz = toleranz
        fang = min(toleranz * fangFaktor, 0.32)
        zielRest = min(toleranz * 0.9, 0.2)
        such = min(toleranz, 0.14)
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

    func beginnen(bei roh: CGPoint) {
        guard let strich = aktuellerStrich else { return }
        let radius = fangRadius(fuer: strich)
        if verschiebbar, strichNummer == 0, roh.abstand(zu: strich.anfang) <= radius {
            versatz = CGVector(dx: roh.x - strich.anfang.x, dy: roh.y - strich.anfang.y)
        }
        let p = vorlage(roh)
        if p.abstand(zu: strich.anfang) <= radius {
            hinweis = nil
            schreibtGerade = true
            fortschritt = 0
            letzterPunkt = p
            aktuelleTinte = [Tintenpunkt(p: roh, warnung: 0)]
        } else if !strich.istPunkt, p.abstand(zu: strich.ende) <= radius {
            fehlerMelden(.andersherum)
        } else {
            fehlerMelden(.amStartBeginnen)
        }
    }

    func bewegen(nach roh: CGPoint) {
        guard schreibtGerade, let strich = aktuellerStrich else { return }
        let p = vorlage(roh)
        let von = letzterPunkt ?? p
        // Schnelle Bewegungen in kleine Schritte zerlegen, damit kein Stück
        // des Wegs übersprungen wird.
        let schritt = such * 0.4
        let anzahl = max(1, Int(ceil(von.abstand(zu: p) / schritt)))
        naehe = 0
        for k in 1...anzahl {
            let q = von.mitte(zu: p, anteil: CGFloat(k) / CGFloat(anzahl))
            if !pruefen(q, auf: strich) { return }
        }
        letzterPunkt = p
        aktuelleTinte.append(Tintenpunkt(p: roh, warnung: naehe))
    }

    func beenden(bei roh: CGPoint) {
        guard schreibtGerade, let strich = aktuellerStrich else { return }
        bewegen(nach: roh)
        guard schreibtGerade else { return }  // unterwegs schon von der Spur
        schreibtGerade = false
        letzterPunkt = nil
        if strich.istPunkt || fortschritt >= strich.gesamt - min(zielRest, strich.gesamt * 0.25) {
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
        aktuelleTinte = []
    }

    func vonVorn() {
        abbrechen()
        tinte = []
        versatz = .zero
        strichNummer = 0
        fehler = 0
        hinweis = nil
    }

    // MARK: Intern

    /// Punkt des Kindes in Koordinaten der Vorlage.
    private func vorlage(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x - versatz.dx, y: p.y - versatz.dy)
    }

    /// Bei kurzen Strichen (Querstrich des t) liegen Anfang und Ende dicht
    /// beisammen — ein weiter Fang nähme sonst auch den verkehrten Anfang.
    private func fangRadius(fuer strich: Strich) -> CGFloat {
        strich.istPunkt ? fang : min(fang, strich.gesamt * 0.5)
    }

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
            von: max(0, fortschritt - such * 1.5),
            bis: fortschritt + such * 4,
            bezug: fortschritt,
            gleichstand: such * 0.05
        )
        guard stelle.abstand <= toleranz else {
            fehlerMelden(.aufDerSpurBleiben)
            return false
        }
        // Ab der halben Bandbreite wird die Tinte orange — das Kind sieht,
        // dass der Strich aus der Form zu laufen droht, bevor es passiert.
        naehe = max(naehe, min(1, max(0, (stelle.abstand / toleranz - 0.5) / 0.5)))
        fortschritt = max(fortschritt, stelle.s)
        return true
    }

    private func strichGeschafft() {
        tinte.append(aktuelleTinte)
        aktuelleTinte = []
        strichNummer += 1
        fortschritt = 0
        hinweis = nil
        strichZaehler += 1
    }

    private func fehlerMelden(_ art: Hinweis) {
        schreibtGerade = false
        letzterPunkt = nil
        fortschritt = 0
        aktuelleTinte = []
        fehler += 1
        hinweis = art
        fehlerZaehler += 1
    }
}
