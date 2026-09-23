import CoreGraphics
import Foundation
import PDFKit
import UIKit

// WO IM BUCH EINE SEITE LIEGT (ab 1.0.52).
//
// Bis 1.0.51 gab es dafür nur die laufende Nummer, und die zählte den
// Umschlag mit: Rückseite 0, Titelseite 1, die erste Seite des Buchblocks
// also 2. Nach `Bogenlage` ist eine gerade Nummer eine LINKE Seite — und
// damit lag die erste wirkliche Buchseite links. Gemeldet 09/2026: „die
// erste wirkliche Seite im Fotobuch ist ja eine rechte Seite, also eine
// ungerade Seite. … Denn links von der Seite 1 wäre ja praktisch die
// Innenseite des Umschlags, die nicht bearbeitet bzw. bedruckt wird."
//
// Er hat recht, und es ist keine Geschmacksfrage, sondern Buchbinderei:
// Der Umschlag ist ein EIGENES Stück Papier und zählt im Buchblock nicht
// mit. Die Zählung trennt sich deshalb in zwei Angaben — wo eine Seite
// liegt (`teil`) und welche Zahl auf ihr steht (`nummer`).
enum Buchteil: String {
    /// Links auf dem Umschlagbogen.
    case rueckseite
    /// Rechts auf dem Umschlagbogen.
    case titel
    /// Der Buchblock: alles, was gebunden wird.
    case innen
}

// Eine Seite des fertigen Buches samt ihrem Zusammenhang. Die Titelseite
// gehört zu keinem Tag — deshalb ist `tag` freiwillig und nicht etwa ein
// erfundener leerer Tag, den dann jede Auswertung wieder aussortieren muss.
// EQUATABLE, und das ist keine Formsache (ab 1.0.59): Die Bühne hängt
// `.equatable()` an jede Seitenfläche, damit die Zweifingergeste nicht
// sechzigmal in der Sekunde jede sichtbare Seite neu aufbaut. Dafür muss
// sich eine Seite mit ihrer Vorgängerin vergleichen lassen — Block für
// Block, denn genau daraus wird sie gezeichnet.
struct Buchseite: Identifiable, Equatable {
    var id: UUID { seite.id }
    var seite: Seite
    var tag: Reisetag?
    var teil: Buchteil = .innen
    /// Die gedruckte Seitenzahl. Sie zählt AUSSCHLIESSLICH den Buchblock,
    /// ab 1; eine Umschlagseite trägt 0 und keine Zahl auf dem Papier.
    var nummer: Int
    /// Die Stelle in der Seitenfolge, ab 0 — die einzige Angabe, die
    /// eindeutig UND ordenbar ist. Die Nummer ist es seit 1.0.52 nicht
    /// mehr: Rückseite und Titelseite tragen beide die 0, weil sie keine
    /// Seiten des Buchblocks sind. Wer damit einen Schlüssel bildet (die
    /// Bühne tut das, um zu wissen, welcher Tag oben im Bild steht), nimmt
    /// den Rang und nie die Nummer.
    var rang: Int = 0
    /// Die leere Seite, die den Buchblock auf eine gerade Zahl bringt
    /// (ab 1.0.60). Sie steht in KEINEM Tag — sie wird gerechnet, wie die
    /// Titelseite, und darf deshalb nirgends bearbeitet werden.
    var ausgleich: Bool = false

    var amUmschlag: Bool { teil != .innen }

    /// Ob diese Seite im aufgeschlagenen Buch RECHTS liegt. Die eine
    /// Stelle, an der das entschieden wird — gefragt von der Paarung, vom
    /// Hintergrund über die Doppelseite und von der Druckprüfung.
    var liegtRechts: Bool {
        switch teil {
        case .rueckseite: return false
        case .titel: return true
        case .innen: return Bogenlage.rechts(nummer)
        }
    }

    /// Der laufende Bogen: 0 ist der Umschlag, 1 trägt rechts die Seite 1,
    /// 2 die Seiten 2 und 3, und so weiter.
    var bogennummer: Int { amUmschlag ? 0 : Bogenlage.bogen(nummer) }

    /// Wie diese Seite heißt — unter ihrem Blatt auf der Bühne und in
    /// jedem Befund. An EINER Stelle, weil „Seite 0" unter der Rückseite
    /// genau der Satz wäre, den 1.0.52 abstellt.
    var kurzname: String {
        switch teil {
        case .rueckseite: return "Umschlag: Rückseite"
        case .titel: return "Umschlag: Titelseite"
        case .innen: return tag == nil ? "Titelseite" : "Seite \(nummer)"
        }
    }
}

extension Reise {
    // Ob auf DIESER Seite ein Wasserzeichen liegt — gefragt von der
    // Ansicht und vom PDF. Eine zweite Fassung dieser Prüfung ergäbe eine
    // Vorschau, die etwas anderes zeigt als der Druck.
    func wasserzeichen(fuer buchseite: Buchseite) -> Wasserzeichen? {
        guard let zeichen = gestaltung.wasserzeichen, zeichen.gueltig else { return nil }
        // Kein Tag heißt Umschlag — Titelseite oder Rückseite.
        if buchseite.tag == nil, !zeichen.aufTitelblatt { return nil }
        return zeichen
    }

    var automat: Layoutautomat {
        Layoutautomat(format: format, gestaltung: gestaltung, typografie: typografie,
                      stil: buchstil, fotoIndex: fotoIndex, umschlag: umschlag)
    }

    // DIE LETZTE SEITE EINES BUCHES IST EINE LINKE (ab 1.0.60).
    //
    // Ansage des Nutzers, 09/2026: „Natürlich muss die letzte Seite des
    // Buches eine linke Seite sein, also eine gerade Seitenzahl haben. Ist
    // das bei den erstellten Seiten nicht der Fall, dann musst du bitte
    // noch eine zusätzliche Seite anlegen."
    //
    // Das ist keine Vorliebe, sondern Buchbinderei: Ein Blatt hat zwei
    // Seiten, also hat ein gebundener Block immer eine GERADE Zahl davon.
    // Bis 1.0.59 hat die App den Fall nur GEMELDET („die letzte Seite hat
    // keine Rückseite") — gemeldet wird ein Zustand, den man ändern kann;
    // diesen kann man nicht ändern, das Papier ist ja da. Die Frage ist
    // allein, ob die letzte Seite im PDF steht oder ob der Druckdienst sie
    // stillschweigend anhängt, und das Zweite ist eine Seite, die niemand
    // gesehen hat.
    static func brauchtAusgleich(_ blockseiten: Int) -> Bool {
        blockseiten > 0 && blockseiten % 2 == 1
    }

    // Die Kennung der Ausgleichsseite ist FEST und wird nicht gewürfelt.
    // Sie wird bei jedem Durchgang neu gebaut, und eine neue Kennung je
    // Durchgang risse der Bühne die Identität ihrer Zeile weg: `ForEach`
    // und `scrollTo` hängen daran, und `.equatable()` verglich ab 1.0.59
    // jedes Mal etwas anderes. Dieselbe Überlegung wie beim gemerkten
    // Titelblatt.
    static let ausgleichsseitenKennung =
        UUID(uuidString: "5EEE0000-0000-4000-A000-000000000001")!

    // Wie viele Seiten der BUCHBLOCK hat — das, was gebunden wird, samt
    // der Ausgleichsseite und samt der Titelseite, wenn die kein eigener
    // Umschlagbogen ist. Gerechnet und nicht gezählt: `seitenfolge` setzt
    // dafür das Titelblatt, und das kostet zwei CoreText-Messungen; diese
    // Zahl wird aber in jedem Ansichtskörper gebraucht, der die
    // Rückenbreite zeigt.
    var blockseiten: Int {
        var anzahl = tage.filter { !$0.ausgeblendet }.reduce(0) { $0 + $1.seiten.count }
        // Ohne Umschlagbogen ist die Titelseite die gewöhnliche Seite 1 —
        // sie wird mitgebunden und zählt für den Rücken mit. Bis 1.0.59
        // fehlte sie in dieser Zahl, und der Rücken war um ein halbes
        // Blatt zu dünn gerechnet.
        if titelseite, !hatRueckseite { anzahl += 1 }
        if Reise.brauchtAusgleich(anzahl) { anzahl += 1 }
        return anzahl
    }

    // Wie viele Seiten der INNENTEIL hat — ohne Umschlag. Das ist die
    // Zahl, aus der die Rückenbreite folgt.
    var innenseiten: Int { blockseiten }

    // Die RÜCKSEITE des Buches, sobald der Umschlag als Bogen gilt. Sie
    // trägt die Nummer 0 und liegt damit nach `Bogenlage` links — die
    // Doppelseitenansicht paart den Umschlagbogen dadurch von selbst
    // richtig, ohne eine zweite Regel daneben.
    var hatRueckseite: Bool { titelseite && umschlag.alsBogen }

    // DIE SEITENFOLGE — und die Nummerierung dahinter — steht an GENAU
    // EINER Stelle.
    //
    // Sie wird von zwei Enden gebraucht: von der Ausgabe (hier) und von
    // der Bühne (`Reisewerk.seitenfolge`, die sich die gesetzten
    // Umschlagseiten merkt, weil ihr Satz zwei CoreText-Messungen kostet
    // und der Körper einer Ansicht oft läuft). Bis 1.0.51 stand die
    // Zählung deshalb ZWEIMAL da — und genau so etwas läuft auseinander.
    // Hereingereicht werden deshalb die fertigen Umschlagseiten; wer sie
    // setzt, entscheidet der Aufrufer.
    func seitenfolge(titelblatt: Seite?, rueckblatt: Seite?) -> [Buchseite] {
        var folge: [Buchseite] = []
        if hatRueckseite, let rueckblatt {
            folge.append(Buchseite(seite: rueckblatt, tag: nil,
                                   teil: .rueckseite, nummer: 0))
        }
        var nummer = 1
        if titelseite, let titelblatt {
            // GILT DER UMSCHLAG ALS BOGEN, gehört die Titelseite ihm und
            // nicht dem Buchblock: Sie wird auf denselben Bogen gedruckt
            // wie Rückseite und Rücken, und die Zählung des Buches fängt
            // dahinter bei 1 an. Ohne Bogen ist sie die gewöhnliche erste
            // Seite — und liegt als ungerade Nummer ebenfalls rechts.
            let amBogen = hatRueckseite
            folge.append(Buchseite(seite: titelblatt, tag: nil,
                                   teil: amBogen ? .titel : .innen,
                                   nummer: amBogen ? 0 : nummer))
            if !amBogen { nummer += 1 }
        }
        var letzterTag: Reisetag?
        for tag in tage where !tag.ausgeblendet {
            for seite in tag.seiten {
                folge.append(Buchseite(seite: seite, tag: tag, teil: .innen, nummer: nummer))
                nummer += 1
            }
            if !tag.seiten.isEmpty { letzterTag = tag }
        }
        // Die Ausgleichsseite: leer, ohne Seitenzahl, mit dem Hintergrund
        // des Buches — und sie gehört dem LETZTEN Tag. Ohne Tag hielte
        // `wasserzeichen(fuer:)` sie für eine Umschlagseite und
        // `kurzname` nennte sie „Titelseite"; mit ihm ist sie schlicht
        // die letzte Seite dieses Tages, und die Bühne springt beim
        // Blättern an die richtige Stelle.
        if Reise.brauchtAusgleich(nummer - 1), let letzterTag {
            let leer = Seite(id: Reise.ausgleichsseitenKennung, bloecke: [],
                             ohneSeitenzahl: true)
            folge.append(Buchseite(seite: leer, tag: letzterTag, teil: .innen,
                                   nummer: nummer, ausgleich: true))
        }
        for (stelle, _) in folge.enumerated() { folge[stelle].rang = stelle }
        return folge
    }

    var seitenfolge: [Buchseite] {
        seitenfolge(
            titelblatt: titelseite
                ? automat.titelseite(titel: titel, untertitel: untertitel,
                                     zeitraum: zeitraum, titelfoto: titelfoto)
                : nil,
            rueckblatt: hatRueckseite
                ? automat.rueckseite(text: umschlag.rueckseitentext,
                                     foto: umschlag.rueckseitenfoto)
                : nil
        )
    }
}

// Schreibt das Buch als PDF — druckfertig.
//
// Nicht über `UIGraphicsPDFRenderer`, sondern über einen `CGContext`
// unmittelbar. Der Unterschied ist genau eine Sache, und die entscheidet
// beim Druckdienst: Nur so lassen sich **TrimBox und BleedBox** setzen.
// Daran erkennt die Druckerei, wo das Endformat aufhört und wo der
// Anschnitt beginnt; ohne sie nimmt sie die Seite für das Endformat und
// schneidet drei Millimeter Bild weg.
enum Buchausgabe {
    enum Fehler: LocalizedError {
        case keineSeiten
        case schreibfehler(String)

        var errorDescription: String? {
            switch self {
            case .keineSeiten: return "Diese Reise hat noch keine Seiten."
            case let .schreibfehler(grund): return "Das PDF ließ sich nicht schreiben: \(grund)"
            }
        }
    }

    struct Auftrag {
        var bildkante: Int = 3600
        // Für Druckereien, die PDF/X-1a oder X-3 verlangen: Beide erlauben
        // keine Transparenz. Dann fallen Schatten weg, und der Verlauf
        // unter einer Überschrift wird zu einem geschlossenen Feld.
        var ohneTransparenz: Bool = false
        var nurUmschlag: Bool = false
        var ohneUmschlag: Bool = false
        // Nur für die Broschüre: Manche Drucker wenden über die kurze
        // Kante, dann steht die Rückseite auf dem Kopf. Welche Einstellung
        // gilt, weiß nur der Mensch davor.
        var rueckseitenDrehen: Bool = false
    }

    static func pdf(_ reise: Reise, auftrag: Auftrag = Auftrag(),
                    fortschritt: @escaping @MainActor (Double) -> Void) async throws -> URL
    {
        // Der Umschlag ist ein BOGEN und keine Seite (ab 1.0.50): eine
        // einzige PDF-Seite, zwei Buchseiten breit, mit dem Rücken
        // dazwischen. So will es jeder Buchdienst, und so sieht es der
        // Mensch, der das fertige Buch in die Hand nimmt.
        if auftrag.nurUmschlag, reise.hatRueckseite {
            return try await umschlagPdf(reise, auftrag: auftrag, fortschritt: fortschritt)
        }

        var gefiltert = reise.seitenfolge
        // WAS IN DIE UMSCHLAGDATEI GEHÖRT, ist „alles ohne Tag" und nicht
        // `amUmschlag`: Ohne Bogen gibt es keine Umschlagseiten, und dann
        // ist die Titelseite allein der Umschlag — mit `amUmschlag` käme
        // dort eine LEERE Liste heraus. Beide Zweige fragen dasselbe, nur
        // andersherum; sonst stünde die Titelseite in beiden Dateien oder
        // in keiner.
        if auftrag.nurUmschlag {
            gefiltert = gefiltert.filter { $0.tag == nil }
        } else if auftrag.ohneUmschlag {
            gefiltert = gefiltert.filter { $0.tag != nil }
        } else {
            // Die Rückseite gehört auf den Umschlagbogen, nicht in den
            // Buchblock. Im vollständigen PDF stünde sie sonst als erste
            // Seite vor dem Titel — eine Reihenfolge, die es im gebundenen
            // Buch nirgends gibt. Die Titelseite bleibt dagegen drin: Wer
            // eine Datei für alles ausgibt, will sie vorn haben.
            gefiltert = gefiltert.filter { $0.teil != .rueckseite }
        }
        guard !gefiltert.isEmpty else { throw Fehler.keineSeiten }
        // Ab hier unveränderlich: Eine `var`, die aus einem nebenläufigen
        // Abschluss gelesen wird, ist unter Swift 6 ein Fehler — und der
        // Grund dafür ist echt, nicht formal: Beim Fortschritt dürfte sich
        // die Liste zwischen zwei Meldungen nicht ändern.
        let seiten = gefiltert
        let anzahl = Double(seiten.count)

        let endformat = reise.format.groesse
        let anschnitt = reise.gestaltung.anschnittPt
        let bogen = reise.gestaltung.bogen(reise.format)

        // Die Kartenbilder werden VOR dem Zeichnen geholt. Der Schnappschuss
        // ist asynchron; mitten im PDF-Lauf darauf zu warten hieße, den
        // Zeichenkontext offen zu halten, während das Netz antwortet.
        // Dieselbe Schleife benutzt die Broschüre — zwei Fassungen liefen
        // auseinander, und dann hätte sie andere Karten als das Buch.
        let karten = await kartenbilder(seiten, reise: reise) { anteil in
            fortschritt(anteil * 0.45)
        }

        let ziel = FileManager.default.temporaryDirectory
            .appendingPathComponent(dateiname(reise, auftrag: auftrag))
        try? FileManager.default.removeItem(at: ziel)

        var medienbox = CGRect(origin: .zero, size: bogen)
        let angaben: [String: Any] = [
            kCGPDFContextTitle as String: reise.titel,
            kCGPDFContextCreator as String: "Urlaubstagebuch",
            kCGPDFContextSubject as String: reise.zeitraum,
        ]
        guard let abnehmer = CGDataConsumer(url: ziel as CFURL),
              let zusammenhang = CGContext(consumer: abnehmer, mediaBox: &medienbox,
                                           angaben as CFDictionary)
        else {
            throw Fehler.schreibfehler("Die Datei ließ sich nicht anlegen.")
        }

        // Die drei Boxen. Die TrimBox ist das Endformat, die BleedBox der
        // bedruckte Bogen. Beide werden als rohe `CGRect`-Bytes übergeben —
        // so verlangt es CoreGraphics, ein `NSValue` nimmt es nicht an.
        var trimbox = CGRect(x: anschnitt, y: anschnitt,
                             width: endformat.width, height: endformat.height)
        var bleedbox = medienbox
        let seiteninfo: [String: Any] = [
            kCGPDFContextMediaBox as String: Data(bytes: &medienbox,
                                                  count: MemoryLayout<CGRect>.size),
            kCGPDFContextTrimBox as String: Data(bytes: &trimbox,
                                                 count: MemoryLayout<CGRect>.size),
            kCGPDFContextBleedBox as String: Data(bytes: &bleedbox,
                                                  count: MemoryLayout<CGRect>.size),
        ]

        for (stelle, buchseite) in seiten.enumerated() {
            zusammenhang.beginPDFPage(seiteninfo as CFDictionary)
            zusammenhang.saveGState()
            // CoreGraphics zeichnet ein PDF von unten links, UIKit von oben
            // links. Einmal umdrehen, und danach gilt überall dieselbe
            // Rechnung wie auf dem Bildschirm.
            zusammenhang.translateBy(x: 0, y: bogen.height)
            zusammenhang.scaleBy(x: 1, y: -1)
            // Und dann in die Ecke des ENDFORMATS: Ab hier sind die
            // Koordinaten genau die, die im Modell stehen, und der
            // Anschnitt ist negativer Raum.
            zusammenhang.translateBy(x: anschnitt, y: anschnitt)

            UIGraphicsPushContext(zusammenhang)
            zeichneSeite(buchseite, reise: reise, karten: karten, auftrag: auftrag,
                         in: zusammenhang)
            UIGraphicsPopContext()

            zusammenhang.restoreGState()
            zusammenhang.endPDFPage()

            let anteil = 0.45 + Double(stelle + 1) / anzahl * 0.55
            await MainActor.run { fortschritt(anteil) }
        }
        zusammenhang.closePDF()
        await MainActor.run { fortschritt(1) }
        return ziel
    }

    // MARK: - Broschüre für den eigenen Drucker

    // ZWEI SEITEN AUF EINEN BOGEN, IN HEFTFOLGE (ab 1.0.27).
    //
    // Ansage des Nutzers, 09/2026: „Wenn dann noch die Möglichkeit besteht,
    // automatisch einen Buchdruck auswählen zu können, so dass die Seiten
    // des Dokumentes automatisch umsortiert werden, so dass ich eine
    // doppelseitige Broschüre drucken kann."
    //
    // Der Bogen ist doppelt so breit wie eine Seite: Zwei A5-Seiten
    // nebeneinander ergeben A4 quer. Gefaltet und in der Mitte geheftet
    // liegt daraus ein Heft in der Hand.
    //
    // **Die Reihenfolge ist keine Geschmacksfrage, sondern Buchbinderei.**
    // Bei `n` Seiten (auf ein Vielfaches von vier aufgefüllt) trägt der
    // Bogen `i` vorn `[n−1−2i | 2i]` und hinten `[2i+1 | n−2−2i]`. Bei vier
    // Seiten heißt das vorn `4|1` und hinten `2|3` — einmal gefaltet steht
    // die 1 vorn, dann 2, 3, 4. Wer das nachrechnen will, faltet ein Blatt.
    //
    // **Kein Anschnitt.** Ein Heimdrucker druckt nicht bis an die Kante,
    // und ein Anschnitt, den niemand wegschneidet, wäre ein Rand aus
    // abgeschnittenem Bild. Gezeichnet wird das Endformat; was darüber
    // hinausragt, wird beschnitten — sonst liefe ein randabfallendes Foto
    // in die Nachbarseite.
    //
    // **Leere Seiten sind echte leere Seiten.** Ein Heft hat immer ein
    // Vielfaches von vier; die fehlenden bleiben weiß, statt dass die
    // Reihenfolge verrutscht.
    static func broschuere(_ reise: Reise, auftrag: Auftrag = Auftrag(),
                           fortschritt: @escaping @MainActor (Double) -> Void)
        async throws -> URL
    {
        // DIE RÜCKSEITE GEHÖRT ANS ENDE, nicht an den Anfang. In der
        // Seitenfolge steht sie vorn, weil sie dort die LINKE Hälfte des
        // Umschlagbogens ist — ein gefaltetes Heft hat aber keinen Bogen
        // und keinen Rücken: Dort ist die Titelseite die erste Seite und
        // die Rückseite die letzte. Bis 1.0.51 lief sie als Heftseite 1
        // mit, also noch vor dem Titel; das war schon damals falsch und
        // fiel erst beim Umbau der Zählung auf.
        var alle = reise.seitenfolge.filter { $0.teil != .rueckseite }
        if let rueckseite = reise.seitenfolge.first(where: { $0.teil == .rueckseite }) {
            alle.append(rueckseite)
        }
        guard !alle.isEmpty else { throw Fehler.keineSeiten }

        // Auf ein Vielfaches von vier auffüllen. `nil` heißt: leere Seite.
        var folge: [Buchseite?] = alle.map { $0 }
        while folge.count % 4 != 0 { folge.append(nil) }
        let n = folge.count

        var bogenfolge: [(links: Buchseite?, rechts: Buchseite?, rueckseite: Bool)] = []
        for i in 0 ..< (n / 4) {
            bogenfolge.append((folge[n - 1 - 2 * i], folge[2 * i], false))
            bogenfolge.append((folge[2 * i + 1], folge[n - 2 - 2 * i], true))
        }

        let end = reise.format.groesse
        let bogen = CGSize(width: end.width * 2, height: end.height)
        let anzahl = Double(bogenfolge.count)

        let karten = await kartenbilder(alle, reise: reise) { anteil in
            fortschritt(anteil * 0.45)
        }

        let ziel = FileManager.default.temporaryDirectory
            .appendingPathComponent(dateiname(reise, auftrag: auftrag, broschuere: true))
        try? FileManager.default.removeItem(at: ziel)

        var medienbox = CGRect(origin: .zero, size: bogen)
        let angaben: [String: Any] = [
            kCGPDFContextTitle as String: reise.titel + " \u{2014} Brosch\u{00FC}re",
            kCGPDFContextCreator as String: "Urlaubstagebuch",
            kCGPDFContextSubject as String: reise.zeitraum,
        ]
        guard let abnehmer = CGDataConsumer(url: ziel as CFURL),
              let zusammenhang = CGContext(consumer: abnehmer, mediaBox: &medienbox,
                                           angaben as CFDictionary)
        else {
            throw Fehler.schreibfehler("Die Datei ließ sich nicht anlegen.")
        }
        let seiteninfo: [String: Any] = [
            kCGPDFContextMediaBox as String: Data(bytes: &medienbox,
                                                  count: MemoryLayout<CGRect>.size),
        ]

        for (stelle, bogenseite) in bogenfolge.enumerated() {
            zusammenhang.beginPDFPage(seiteninfo as CFDictionary)
            zusammenhang.saveGState()
            zusammenhang.translateBy(x: 0, y: bogen.height)
            zusammenhang.scaleBy(x: 1, y: -1)

            // WENDEN ÜBER DIE KURZE KANTE dreht die Rückseite um 180 Grad.
            // Welche der beiden Einstellungen ein Drucker benutzt, weiß nur
            // der Mensch davor — deshalb ein Schalter und keine Annahme.
            if bogenseite.rueckseite, auftrag.rueckseitenDrehen {
                zusammenhang.translateBy(x: bogen.width, y: bogen.height)
                zusammenhang.rotate(by: .pi)
            }

            for (spalte, seite) in [bogenseite.links, bogenseite.rechts].enumerated() {
                guard let seite else { continue }
                zusammenhang.saveGState()
                zusammenhang.translateBy(x: Double(spalte) * end.width, y: 0)
                zusammenhang.clip(to: CGRect(origin: .zero, size: end))
                UIGraphicsPushContext(zusammenhang)
                zeichneSeite(seite, reise: reise, karten: karten, auftrag: auftrag,
                             in: zusammenhang)
                UIGraphicsPopContext()
                zusammenhang.restoreGState()
            }

            zusammenhang.restoreGState()
            zusammenhang.endPDFPage()
            let anteil = 0.45 + Double(stelle + 1) / anzahl * 0.55
            await MainActor.run { fortschritt(anteil) }
        }
        zusammenhang.closePDF()
        await MainActor.run { fortschritt(1) }
        return ziel
    }

    // Die Kartenbilder werden VOR dem Zeichnen geholt — für beide Ausgaben
    // dieselbe Schleife. Zwei Fassungen desselben Vorlaufs liefen
    // auseinander, und dann hätte die Broschüre andere Karten als das Buch.
    private static func kartenbilder(_ seiten: [Buchseite], reise: Reise,
                                     fortschritt: @escaping @MainActor (Double) -> Void)
        async -> [UUID: UIImage]
    {
        var karten: [UUID: UIImage] = [:]
        let anzahl = Double(max(seiten.count, 1))
        for (stelle, buchseite) in seiten.enumerated() {
            guard let tag = buchseite.tag else { continue }
            for block in buchseite.seite.bloecke where block.inhalt == .karte {
                let groesse = CGSize(width: max(block.rahmen.breite * 3, 60),
                                     height: max(block.rahmen.hoehe * 3, 60))
                // Dieselbe Auflösung wie auf dem Bildschirm — Block vor
                // Tag vor Buch. Zwei Fassungen ergäben ein PDF, das anders
                // aussieht als die Vorschau.
                let gilt = Kartenwahl.geltend(block: block, tag: tag, reise: reise)
                let bild = await Kartenwerk.shared.bild(
                    punkte: tag.spur.map(\.koordinate),
                    groesse: groesse,
                    kartenbild: gilt.bild,
                    linienfarbe: reise.akzent,
                    ausschnitt: gilt.ausschnitt
                )
                if let bild { karten[block.id] = bild }
            }
            await MainActor.run { fortschritt(Double(stelle) / anzahl) }
        }
        return karten
    }

    static func dateiname(_ reise: Reise, auftrag: Auftrag,
                          broschuere: Bool = false) -> String {
        let roh = reise.titel.isEmpty ? "Reisetagebuch" : reise.titel
        let erlaubt = roh.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let grund = erlaubt.isEmpty ? "Reisetagebuch" : erlaubt
        if broschuere { return grund + "-Broschuere.pdf" }
        if auftrag.nurUmschlag { return grund + "-Umschlag.pdf" }
        if auftrag.ohneUmschlag { return grund + "-Innenteil.pdf" }
        return grund + ".pdf"
    }

    // MARK: - Der Umschlagbogen

    // EINE PDF-Seite: links die Rückseite, in der Mitte der Rücken, rechts
    // die Titelseite (ab 1.0.50).
    //
    // Ansage des Nutzers, 09/2026: „In meiner Erinnerung ist es bei Saal
    // Digital beispielsweise so, dass die Titelseite bzw. der Umschlag des
    // Buches so dargestellt wird, dass die rechte Hälfte einer Doppelseite
    // die tatsächliche Titelseite ist und die linke Seite die Rückseite des
    // Buches."
    //
    // **Keine TrimBox in der Mitte.** Sie sagt einer Druckerei, wo
    // geschnitten wird; auf einem Bogen mit zwei Seiten und einem Rücken
    // gäbe es dafür keine einzige richtige Stelle — geschnitten wird außen,
    // gefalzt wird am Rücken. Die TrimBox umfasst deshalb den GANZEN Bogen,
    // und wo die Falze liegen, sagt die Rückenbreite. Dieselbe Überlegung
    // wie bei der Broschüre seit 1.0.27.
    static func umschlagPdf(_ reise: Reise, auftrag: Auftrag,
                            fortschritt: @escaping @MainActor (Double) -> Void) async throws -> URL
    {
        let format = reise.format
        let seitenmass = format.groesse
        let anschnitt = reise.gestaltung.anschnittPt
        let innen = reise.innenseiten
        let endformat = Umschlagmass.endformat(format, umschlag: reise.umschlag,
                                               innenseiten: innen)
        let bogen = Umschlagmass.bogen(format, gestaltung: reise.gestaltung,
                                       umschlag: reise.umschlag, innenseiten: innen)
        let ruecken = Umschlagmass.ruecken(format, umschlag: reise.umschlag,
                                           innenseiten: innen)

        let seiten = reise.seitenfolge.filter(\.amUmschlag)
        guard let rueckseite = seiten.first(where: { $0.teil == .rueckseite }),
              let titelseite = seiten.first(where: { $0.teil == .titel })
        else { throw Fehler.keineSeiten }

        let karten = await kartenbilder(seiten, reise: reise) { anteil in
            fortschritt(anteil * 0.45)
        }

        let ziel = FileManager.default.temporaryDirectory
            .appendingPathComponent(dateiname(reise, auftrag: auftrag))
        try? FileManager.default.removeItem(at: ziel)

        var medienbox = CGRect(origin: .zero, size: bogen)
        let angaben: [String: Any] = [
            kCGPDFContextTitle as String: reise.titel + " — Umschlag",
            kCGPDFContextCreator as String: "Urlaubstagebuch",
            kCGPDFContextSubject as String: reise.zeitraum,
        ]
        guard let abnehmer = CGDataConsumer(url: ziel as CFURL),
              let zusammenhang = CGContext(consumer: abnehmer, mediaBox: &medienbox,
                                           angaben as CFDictionary)
        else {
            throw Fehler.schreibfehler("Die Datei ließ sich nicht anlegen.")
        }

        var trimbox = CGRect(x: anschnitt, y: anschnitt,
                             width: endformat.width, height: endformat.height)
        var bleedbox = medienbox
        let seiteninfo: [String: Any] = [
            kCGPDFContextMediaBox as String: Data(bytes: &medienbox,
                                                  count: MemoryLayout<CGRect>.size),
            kCGPDFContextTrimBox as String: Data(bytes: &trimbox,
                                                 count: MemoryLayout<CGRect>.size),
            kCGPDFContextBleedBox as String: Data(bytes: &bleedbox,
                                                  count: MemoryLayout<CGRect>.size),
        ]

        zusammenhang.beginPDFPage(seiteninfo as CFDictionary)
        zusammenhang.saveGState()
        zusammenhang.translateBy(x: 0, y: bogen.height)
        zusammenhang.scaleBy(x: 1, y: -1)
        zusammenhang.translateBy(x: anschnitt, y: anschnitt)

        // Der Grund liegt über dem GANZEN Bogen, samt Rücken und
        // Anschnitt. Eine Fläche, die am Endformat aufhört, hätte nach dem
        // Beschneiden den weißen Faden, wegen dem es den Anschnitt gibt.
        var grund = reise.umschlag.hintergrund ?? reise.gestaltung.hintergrund
        // Ein Hintergrundfoto über den Umschlag ist etwas anderes als eines
        // über eine Doppelseite: Hier ist es EIN Blatt, also wird es auch
        // als eines gezeichnet.
        grund.ueberDoppelseite = false
        var grundbild: UIImage?
        if grund.art == .foto, let id = grund.fotoID, let foto = reise.foto(id) {
            grundbild = Bildarchiv.shared.fuerAusgabe(foto.datei, reise: reise.id,
                                                      kante: auftrag.bildkante)
        }
        Seitensatz.zeichneHintergrund(
            grund,
            rechteck: CGRect(x: -anschnitt, y: -anschnitt,
                             width: endformat.width + 2 * anschnitt,
                             height: endformat.height + 2 * anschnitt),
            bild: grundbild, saat: reise.id.saat, bildflaeche: nil, in: zusammenhang)

        // Jede Hälfte in ihrem eigenen Koordinatensystem, beschnitten auf
        // ihre Fläche plus den AUSSEN liegenden Anschnitt. Ohne den
        // Beschnitt liefe ein randabfallendes Titelfoto über den Rücken —
        // also genau über die Beschriftung, die dort stehen soll.
        zeichneUmschlagseite(rueckseite, reise: reise, karten: karten, auftrag: auftrag,
                             ursprung: .zero, aussenLinks: true,
                             seitenmass: seitenmass, anschnitt: anschnitt,
                             in: zusammenhang)
        zeichneUmschlagseite(titelseite, reise: reise, karten: karten, auftrag: auftrag,
                             ursprung: CGPoint(x: seitenmass.width + ruecken.width, y: 0),
                             aussenLinks: false,
                             seitenmass: seitenmass, anschnitt: anschnitt,
                             in: zusammenhang)

        if ruecken.width > 1 {
            zeichneRuecken(reise, rechteck: ruecken, in: zusammenhang)
        }

        zusammenhang.restoreGState()
        zusammenhang.endPDFPage()
        zusammenhang.closePDF()
        await MainActor.run { fortschritt(1) }
        return ziel
    }

    private static func zeichneUmschlagseite(_ buchseite: Buchseite, reise: Reise,
                                             karten: [UUID: UIImage], auftrag: Auftrag,
                                             ursprung: CGPoint, aussenLinks: Bool,
                                             seitenmass: CGSize, anschnitt: Double,
                                             in zusammenhang: CGContext)
    {
        zusammenhang.saveGState()
        zusammenhang.translateBy(x: ursprung.x, y: ursprung.y)
        let x = aussenLinks ? -anschnitt : 0
        let breite = seitenmass.width + anschnitt
        zusammenhang.clip(to: CGRect(x: x, y: -anschnitt, width: breite,
                                     height: seitenmass.height + 2 * anschnitt))
        zeichneSeite(buchseite, reise: reise, karten: karten, auftrag: auftrag,
                     in: zusammenhang)
        zusammenhang.restoreGState()
    }

    // DIE BESCHRIFTUNG DES RÜCKENS läuft von OBEN nach UNTEN.
    //
    // Das ist die deutsche und europäische Gepflogenheit: Ein Buch, das
    // flach auf dem Tisch liegt, soll sich mit dem Titel nach oben lesen
    // lassen. Gedreht wird deshalb um +90 Grad — im schon umgedrehten
    // Zeichensystem läuft die Schrift damit nach unten.
    private static func zeichneRuecken(_ reise: Reise, rechteck: CGRect,
                                       in zusammenhang: CGContext)
    {
        let text = reise.umschlag.rueckenbeschriftung(titel: reise.titel)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        var bild = reise.typografie.titel
        if let familie = reise.umschlag.schriftfamilie { bild.familie = familie }
        bild.ausrichtung = .mitte
        // Der Rücken ist schmal. Die Schrift darf ihn nicht ausfüllen,
        // sondern muss hineinpassen, auch wenn jemand einen dicken Titel
        // gewählt hat — sonst stünde sie halb auf der Titelseite.
        let platz = rechteck.width * 0.62
        if bild.zeilenhoehe > platz, bild.zeilenhoehe > 0 {
            bild.groesse = bild.groesse * platz / bild.zeilenhoehe
        }

        let laenge = rechteck.height
        let breite = rechteck.width
        let hoehe = min(Textmass.hoehe(text, bild: bild, breite: laenge), breite)

        zusammenhang.saveGState()
        zusammenhang.translateBy(x: rechteck.midX, y: rechteck.midY)
        zusammenhang.rotate(by: .pi / 2)
        zusammenhang.translateBy(x: -laenge / 2, y: -breite / 2)
        Seitensatz.zeichneText(
            text, bild: bild,
            rechteck: CGRect(x: 0, y: (breite - hoehe) / 2, width: laenge, height: hoehe),
            in: zusammenhang, seitenhoehe: breite)
        zusammenhang.restoreGState()
    }

    // MARK: - Eine Seite

    static func zeichneSeite(_ buchseite: Buchseite, reise: Reise, karten: [UUID: UIImage],
                             auftrag: Auftrag, in zusammenhang: CGContext)
    {
        let endformat = reise.format.groesse
        let anschnitt = reise.gestaltung.anschnittPt
        let ecken = reise.gestaltung.eckenradiusPt
        // Der Maßstab für Schatten: Auf einem 30er-Buch darf ein Schatten
        // größer sein als auf einer Postkarte, sonst verschwindet er.
        let massstab = endformat.width / 600

        // Der Hintergrund läuft IMMER bis in den Anschnitt — eine Fläche,
        // die am Endformat aufhört, hätte nach dem Beschneiden genau den
        // weißen Faden, wegen dem es den Anschnitt gibt.
        let bogenrechteck = CGRect(x: -anschnitt, y: -anschnitt,
                                   width: endformat.width + 2 * anschnitt,
                                   height: endformat.height + 2 * anschnitt)
        var grund = buchseite.seite.hintergrund ?? reise.gestaltung.hintergrund
        if let eigenes = buchseite.seite.papier {
            grund.farbe = eigenes
            grund.art = .einfarbig
        }
        var grundbild: UIImage?
        if grund.art == .foto, let id = grund.fotoID, let foto = reise.foto(id) {
            grundbild = Bildarchiv.shared.fuerAusgabe(foto.datei, reise: reise.id,
                                                      kante: auftrag.bildkante)
        }
        // Geht das Hintergrundfoto über die Doppelseite, wird es in die
        // Fläche BEIDER Seiten gerechnet und hier die Hälfte davon
        // gezeichnet. Gerechnet wird das von derselben Funktion, die auch
        // die Ansicht fragt — zwei Fassungen ergäben eine Vorschau, in
        // der das Bild anders steht als im Druck.
        var bildflaeche: CGRect?
        if grund.art == .foto, grund.ueberDoppelseite {
            bildflaeche = Bogenlage.bildflaeche(rechts: buchseite.liegtRechts,
                                                format: endformat, anschnitt: anschnitt)
        }
        Seitensatz.zeichneHintergrund(grund, rechteck: bogenrechteck, bild: grundbild,
                                      saat: buchseite.seite.id.saat,
                                      bildflaeche: bildflaeche, in: zusammenhang)

        // Das Wasserzeichen liegt über dem Hintergrund und unter allem
        // anderen. Ohne Transparenz fällt es WEG und wird nicht etwa
        // deckend gezeichnet: Ein undurchsichtiges Ahornblatt mitten auf
        // der Seite wäre keine abgeschwächte Fassung, sondern ein Fehler
        // im Buch. Dieselbe Entscheidung wie beim Schatten daneben — nur
        // dass der Verlauf dort zu einem geschlossenen Feld wird, weil er
        // etwas lesbar machen muss und dieses Zeichen nichts.
        // Erst die LAGE, dann das Bild: Seit 1.0.56 sagt `ort`, welches
        // der bis zu zehn Bilder auf dieser Seite liegt — vorher lässt
        // sich gar nicht wissen, welche Datei zu holen ist.
        if !auftrag.ohneTransparenz, let zeichen = reise.wasserzeichen(fuer: buchseite) {
            let satz = reise.gestaltung.satzspiegel(reise.format)
            let ort = Wasserzeichenlage.ort(zeichen, satz: satz, seite: buchseite.seite)
            if let zeichenbild = ort.bild,
               let bild = Bildarchiv.shared.fuerAusgabe(zeichenbild.datei, reise: reise.id,
                                                        kante: auftrag.bildkante)
            {
                Seitensatz.zeichneWasserzeichen(bild, ort: ort,
                                                deckung: zeichen.deckung, in: zusammenhang)
            }
        }

        for block in buchseite.seite.sortiert {
            let rechteck = block.rahmen.rect
            zusammenhang.saveGState()
            if block.drehung != 0 {
                zusammenhang.translateBy(x: rechteck.midX, y: rechteck.midY)
                zusammenhang.rotate(by: block.drehung * .pi / 180)
                zusammenhang.translateBy(x: -rechteck.midX, y: -rechteck.midY)
            }

            let wirkung = block.wirkung(reise.gestaltung)
            let randPt = Druckmass.pt(wirkung.fotorand)
            let traeger = Seitensatz.fotorandRechteck(rechteck, rand: randPt)
            if block.istFoto, !auftrag.ohneTransparenz {
                Seitensatz.zeichneSchatten(traeger, art: wirkung.schatten, massstab: massstab,
                                           eckenradius: ecken, in: zusammenhang)
            }
            if randPt > 0 {
                Seitensatz.zeichneFlaeche(traeger, farbe: .white, eckenradius: ecken,
                                          in: zusammenhang)
            }
            // Der Grund kommt aus der WIRKUNG: Er darf seit 1.0.12 auch
            // vom Buch vorgegeben sein. Dieselbe Quelle wie auf dem
            // Bildschirm — zwei Fassungen ergäben ein PDF, das anders
            // aussieht als die Vorschau.
            if let grund = wirkung.grund {
                Seitensatz.zeichneFlaeche(rechteck, farbe: grund.uiFarbe,
                                          eckenradius: ecken, in: zusammenhang)
            }

            switch block.inhalt {
            case .titel, .unterueberschrift, .datum, .text, .bildunterschrift:
                let bild = Seitensatz.schriftbild(block, reise: reise)
                let text = Seitensatz.inhaltstext(block, tag: buchseite.tag, reise: reise)
                Seitensatz.zeichneText(text, bild: bild,
                                       rechteck: block.textrechteck(rechteck,
                                                                     rand: wirkung.textrand),
                                       in: zusammenhang, seitenhoehe: endformat.height)

            case .linie:
                let farbe = (block.rand ?? reise.akzent).uiFarbe.withAlphaComponent(0.55)
                Seitensatz.zeichneLinie(rechteck, farbe: farbe, in: zusammenhang)

            case .flaeche:
                break

            case .verlauf:
                Seitensatz.zeichneVerlauf(rechteck, opak: auftrag.ohneTransparenz,
                                          in: zusammenhang)

            case let .foto(id):
                if let foto = reise.foto(id),
                   let bild = Bildarchiv.shared.fuerAusgabe(foto.datei, reise: reise.id,
                                                            kante: auftrag.bildkante)
                {
                    Seitensatz.zeichneBild(bild, ausschnitt: block.ausschnitt,
                                           rechteck: rechteck, in: zusammenhang,
                                           eckenradius: ecken)
                }

            case .karte:
                if let bild = karten[block.id] {
                    if !auftrag.ohneTransparenz {
                        Seitensatz.zeichneSchatten(rechteck, art: wirkung.schatten,
                                                   massstab: massstab, eckenradius: ecken,
                                                   in: zusammenhang)
                    }
                    Seitensatz.zeichneBild(bild, ausschnitt: .voll, rechteck: rechteck,
                                           in: zusammenhang, eckenradius: ecken)
                } else {
                    // Keine Karte ist etwas anderes als eine leere Fläche.
                    // Wer das PDF ohne Netz erzeugt, soll im Buch sehen,
                    // wo sie hingehört hätte, statt zu rätseln.
                    Seitensatz.zeichneFlaeche(rechteck, farbe: UIColor(white: 0.93, alpha: 1),
                                              eckenradius: ecken, in: zusammenhang)
                    var hinweis = reise.typografie.bildunterschrift
                    hinweis.ausrichtung = .mitte
                    Seitensatz.zeichneText(
                        "Kartenbild fehlt", bild: hinweis,
                        rechteck: CGRect(x: rechteck.minX, y: rechteck.midY - 8,
                                         width: rechteck.width, height: 20),
                        in: zusammenhang, seitenhoehe: endformat.height)
                }
            }

            if let rand = wirkung.randfarbe, wirkung.randbreite > 0, block.inhalt != .linie {
                Seitensatz.zeichneRahmen(rechteck, farbe: rand.uiFarbe,
                                         breite: wirkung.randbreite, eckenradius: ecken,
                                         in: zusammenhang)
            }
            zusammenhang.restoreGState()
        }

        zeichneFusszeile(buchseite, reise: reise, in: zusammenhang)
    }

    // Seitenzahl und Kopfzeile gehören zum BUCH und nicht zum Tag — deshalb
    // sind sie keine Blöcke im Satz, wo jemand sie versehentlich verschöbe,
    // sondern werden beim Zeichnen jeder Seite ergänzt.
    //
    // Wo sie stehen, rechnet seit 1.0.50 `Seitenbeiwerk` — dieselbe
    // Funktion, die auch der Bildschirm fragt. Bis 1.0.49 stand die
    // Rechnung nur hier, und damit gab es die Seitenzahlen ausschließlich
    // im PDF; auf dem Bildschirm blieb der Schalter ohne jede Wirkung.
    static func zeichneFusszeile(_ buchseite: Buchseite, reise: Reise,
                                 in zusammenhang: CGContext)
    {
        let endformat = reise.format.groesse
        for zeile in Seitenbeiwerk.zeilen(buchseite, reise: reise) {
            Seitensatz.zeichneText(zeile.text, bild: zeile.bild, rechteck: zeile.rechteck,
                                   in: zusammenhang, seitenhoehe: endformat.height)
        }
    }
}
