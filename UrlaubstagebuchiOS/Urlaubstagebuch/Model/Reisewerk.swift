import Combine
import Foundation
import SwiftUI

// Das Modell hinter allen Ansichten: genau EINE Reise, in Arbeit.
//
// Es macht zwei Dinge, die zusammengehören und getrennt werden müssen: Es
// hält den INHALT (Texte, Fotos, Spur) und es hält den SATZ (die Seiten).
// Der Inhalt gehört dem Nutzer, der Satz der App — und deshalb darf der
// Satz jederzeit neu gerechnet werden, der Inhalt nie.
@MainActor
final class Reisewerk: ObservableObject, Identifiable {
    nonisolated let id = UUID()

    @Published var reise: Reise { didSet { geplantSichern() } }
    @Published var gewaehlterTag: UUID?
    @Published var gewaehlterBlock: UUID?
    @Published var seitenzeiger: Int = 0
    @Published var meldung: Meldung?
    @Published var beschaeftigt: String?
    // Was die Seite bei der letzten Ziehbewegung entgegengenommen hat.
    //
    // Das ist eine PROBE und keine Zugabe: Dass sich Bilder nicht
    // verschieben lassen, wurde zweimal gemeldet, und beide Male ließ sich
    // hier nicht messen, woran es liegt — es gab mehrere Verdächtige und
    // kein Gerät, sie zu trennen. Diese Zeile sagt beim nächsten Mal, ob
    // die Geste überhaupt ankam und als was sie gelesen wurde. Dasselbe
    // Muster wie die Stufenprobe bei Schulalarm und der Kartenmesser der
    // Abfahrtstafel: Wo sich eine Ursache nicht erschließen lässt, muss
    // eine Probe entscheiden.
    @Published var letzterGriff: String?
    @Published var zeigeGriffprobe = false
    // Wie oft sich Seite und Inspektor neu zeichnen. Bewusst KEIN
    // `@Published` — siehe `Zeichenmesser`: Ein Messgerät, dessen Messung
    // ein Neuzeichnen auslöst, misst sich selbst.
    let messer = Zeichenmesser()
    // Kein `@AppStorage` in einem `ObservableObject`: Der Wrapper ist eine
    // `DynamicProperty` und gehört in eine View. Hier schriebe er zwar in
    // die Voreinstellungen, löste aber kein `objectWillChange` aus — die
    // Seite bliebe beim Umschalten stehen, und niemand sähe, woran es
    // liegt. (Dieselbe Falle wie in der Abfahrtstafel.)
    @Published var zeigeSatzspiegel: Bool = UserDefaults.standard
        .object(forKey: "zeigeSatzspiegel") as? Bool ?? true
    {
        didSet { UserDefaults.standard.set(zeigeSatzspiegel, forKey: "zeigeSatzspiegel") }
    }
    @Published var zeigeHilfslinien: Bool = true
    // Solange dieser Wert gesetzt ist, verschiebt eine Ziehgeste auf dem
    // Block nicht den Block, sondern das Bild IN ihm. Der Modus ist
    // sichtbar — ein Band über der Seite sagt, was gerade gilt. Eine Geste,
    // die mal dies und mal jenes tut, ohne dass man den Unterschied sieht,
    // ist für den Menschen davor ein kaputtes Bedienelement.
    @Published var ausschnittsmodus: UUID?
    // Wie viel Höhe dem gewählten Textblock fehlt, damit nichts
    // abgeschnitten wird — oder nil.
    //
    // GESPEICHERT und nicht gerechnet: Dahinter steckt ein voller
    // CoreText-Satz, und als berechnete Eigenschaft liefe der bei jedem
    // Neuzeichnen der Seite mit. Dieselbe Falle wie bei der Netzkarte der
    // Abfahrtstafel. Gefüllt wird er an EINER Stelle — in
    // `SeitenflaecheView`, wenn sich Auswahl, Rahmen oder Text ändern.
    @Published var textUeberlauf: Double?
    // Welcher Textblock gerade AUF DER SEITE bearbeitet wird. Bis 1.0.1
    // ging das nur über ein Feld im Inspektor — gemeldet 09/2026: „Ich
    // würde den Text am liebsten direkt auf der Seite ändern können."
    @Published var textBearbeitung: UUID?

    struct Meldung: Identifiable {
        var id = UUID()
        var text: String
        var schwer: Bool = false
    }

    private var sicherungsauftrag: Task<Void, Never>?
    private var rueckstapel: [Reise] = []

    init(reise: Reise) {
        self.reise = reise
        gewaehlterTag = reise.tage.first?.id
    }

    // MARK: - Die Seitenliste

    // Die Kennung der Titelseite in der Tagesliste. Sie gehört zu keinem
    // Tag — deshalb eine feste Kennung und kein erfundener leerer Tag, den
    // dann jede Auswertung wieder aussortieren muss.
    static let titelseitenKennung = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    // Was die Bühne zeigt — und zwar OHNE bei jedem Neuzeichnen das
    // Titelblatt neu zu setzen.
    //
    // `Reise.seitenfolge` ist eine BERECHNETE Eigenschaft, und darin steckt
    // zweierlei, was nicht nach Rechnung aussieht: `reise.automat` baut
    // `fotoIndex`, also ein Wörterbuch über ALLE Fotos des Buches, und
    // `automat.titelseite(…)` setzt das Titelblatt samt zwei
    // CoreText-Messungen. Gelesen wurde das bis 1.0.15 im Körper von
    // `ReiseView` — und dort ZWEIMAL je Durchgang, einmal für die Liste und
    // einmal für die Prüfung auf leer. Der Körper läuft bei jedem Bildpunkt
    // einer Ziehbewegung; bei zweihundert Fotos ist das die teuerste Zeile
    // der ganzen Ansicht. **Eine berechnete Eigenschaft sieht billig aus** —
    // dieselbe Falle wie bei der Netzkarte der Abfahrtstafel, hier zum
    // dritten Mal.
    //
    // Gemerkt wird NUR das Titelblatt, und das ist Absicht: Es ist die
    // einzige Seite, die es nicht GIBT, sondern die gerechnet wird — alle
    // anderen stehen als `Seite` am Tag und werden hier nur aufgereiht. Die
    // Blöcke eines Tages zu merken hieße, beim Schieben einen alten Stand
    // zu zeichnen; zwei Wahrheiten für dieselbe Seite laufen auseinander
    // (Lehre aus 1.0.8).
    private var titelblatt: (schluessel: Int, seite: Seite)?

    // Alles, was in das Titelblatt eingeht — und nichts sonst. Fehlte hier
    // ein Feld, bliebe ein alter Titel stehen, ohne dass etwas darauf
    // hinwiese; deshalb steht die Liste neben dem Bauplan in
    // `Layoutautomat.titelseite` und wird mit ihm zusammen geändert.
    private var titelblattschluessel: Int {
        var misch = Hasher()
        misch.combine(reise.titel)
        misch.combine(reise.untertitel)
        misch.combine(reise.zeitraum)
        misch.combine(reise.titelfoto)
        // Ob es das Titelfoto NOCH gibt, entscheidet über die Gestalt der
        // Seite (Plakat oder Textblatt). Ein Vergleich von Kennungen über
        // die Fotoliste ist dabei ein Bruchteil dessen, was das Wörterbuch
        // kostet, das `fotoIndex` sonst baut.
        misch.combine(reise.titelfoto.map { id in reise.fotos.contains { $0.id == id } } ?? false)
        misch.combine(reise.format)
        misch.combine(reise.gestaltung)
        misch.combine(reise.typografie)
        misch.combine(reise.buchstil)
        return misch.finalize()
    }

    var seitenfolge: [Buchseite] {
        var folge: [Buchseite] = []
        var nummer = 1
        if reise.titelseite {
            let schluessel = titelblattschluessel
            let seite: Seite
            if let da = titelblatt, da.schluessel == schluessel {
                seite = da.seite
            } else {
                seite = messer.sammelt("Titelblatt") {
                    reise.automat.titelseite(titel: reise.titel, untertitel: reise.untertitel,
                                             zeitraum: reise.zeitraum, titelfoto: reise.titelfoto)
                }
                titelblatt = (schluessel, seite)
            }
            folge.append(Buchseite(seite: seite, tag: nil, nummer: nummer))
            nummer += 1
        }
        for tag in reise.tage where !tag.ausgeblendet {
            for seite in tag.seiten {
                folge.append(Buchseite(seite: seite, tag: tag, nummer: nummer))
                nummer += 1
            }
        }
        return folge
    }

    // Gehört diese Seite zur gerade gewählten Auswahl? Ist kein Tag
    // gewählt, gehört das ganze Buch dazu.
    func inAuswahl(_ seite: Buchseite) -> Bool {
        guard let gewaehlt = gewaehlterTag else { return true }
        if gewaehlt == Self.titelseitenKennung { return seite.tag == nil }
        return seite.tag?.id == gewaehlt
    }

    // Die Seiten, die gerade gezeigt werden. Gefiltert wird nach dem
    // gewählten Tag; ist keiner gewählt, ist es das ganze Buch.
    var sichtbareSeiten: [Buchseite] {
        messer.sammelt("Seitenliste") { () -> [Buchseite] in
            self.seitenfolge.filter { self.inAuswahl($0) }
        }
    }

    // MARK: - Doppelseiten

    // Zwei Seiten, wie sie im aufgeschlagenen Buch nebeneinanderliegen.
    //
    // Die Paarung ist keine Geschmacksfrage, sondern Buchbinderei: Seite 1
    // ist eine RECHTE Seite (ein Recto), und jede rechte Seite trägt eine
    // ungerade Nummer. Der erste Bogen zeigt also rechts die Seite 1 und
    // links — nichts: Dort liegt im gebundenen Buch die INNENSEITE DES
    // UMSCHLAGS (beim Hardcover das Vorsatzpapier), und die kommt von der
    // Druckerei und steht in keinem PDF. Sie wird deshalb gezeigt und als
    // solche benannt, aber nicht mitgezählt.
    struct Doppelseite: Identifiable {
        // Der laufende Bogen: 0 trägt rechts die Seite 1, 1 die Seiten 2
        // und 3, und so weiter.
        let bogen: Int
        var links: Buchseite?
        var rechts: Buchseite?

        var id: Int { bogen }
        // Links liegt die Innenseite des Umschlags — nur auf dem ersten
        // Bogen, und nur dort, weil davor keine Seite steht.
        var beginntMitUmschlag: Bool { bogen == 0 && links == nil }
        // Und rechts liegt die Innenseite des RÜCKEN-Umschlags: Eine
        // fehlende rechte Seite kann es nur am Ende des Buches geben, denn
        // gebaut wird der Bogen aus fortlaufenden Nummern.
        var endetMitUmschlag: Bool { rechts == nil }
    }

    var doppelseiten: [Doppelseite] {
        let alle = seitenfolge
        guard !alle.isEmpty else { return [] }
        var nachNummer: [Int: Buchseite] = [:]
        for seite in alle { nachNummer[seite.nummer] = seite }
        let letzte = alle.map(\.nummer).max() ?? 0
        var bogen: [Doppelseite] = []
        var zaehler = 0
        while 2 * zaehler <= letzte {
            // Links die gerade, rechts die ungerade Nummer — nie umgekehrt.
            let links = nachNummer[2 * zaehler]
            let rechts = nachNummer[2 * zaehler + 1]
            if links != nil || rechts != nil || zaehler == 0 {
                bogen.append(Doppelseite(bogen: zaehler, links: links, rechts: rechts))
            }
            zaehler += 1
        }
        return bogen
    }

    // Gepaart wird über das GANZE Buch und erst danach gefiltert.
    //
    // Andernfalls verschöbe eine Auswahl die Paarung: Fängt ein Tag auf
    // einer linken Seite an, stünde er bei einer Paarung innerhalb der
    // Auswahl plötzlich rechts, und die Doppelseite zeigte etwas, das im
    // gedruckten Buch nie so aussieht. Gezeigt wird deshalb jeder Bogen,
    // auf dem eine Seite der Auswahl liegt — samt der Nachbarseite, auch
    // wenn die zu einem anderen Tag gehört. Genau so liegt das Buch dann
    // auch auf dem Tisch.
    var sichtbareDoppelseiten: [Doppelseite] {
        messer.sammelt("Seitenliste") { () -> [Doppelseite] in
            self.doppelseiten.filter { bogen in
                if let links = bogen.links, self.inAuswahl(links) { return true }
                if let rechts = bogen.rechts, self.inAuswahl(rechts) { return true }
                return false
            }
        }
    }

    // MARK: - Sichern

    // Gesichert wird verzögert. Beim Schieben eines Fotos ändert sich das
    // Modell sechzig Mal in der Sekunde; jedes Mal ein Buch mit dreihundert
    // Blöcken nach JSON zu schreiben, machte das Schieben zäh — und genau
    // das Schieben soll sich leicht anfühlen.
    private func geplantSichern() {
        sicherungsauftrag?.cancel()
        sicherungsauftrag = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            self?.sofortSichern()
        }
    }

    func sofortSichern() {
        var kopie = reise
        kopie.geaendert = Date()
        do {
            try Ablage.sichern(kopie)
        } catch {
            meldung = Meldung(text: "Die Reise ließ sich nicht sichern: \(error.localizedDescription)",
                              schwer: true)
        }
    }

    // MARK: - Rückgängig

    // Ein flacher Stapel von Zwischenständen. Er ersetzt keine
    // Fassungsverwaltung; er fängt den Griff daneben — ein Block, der beim
    // Schieben hinter einem anderen verschwindet, eine Neuanordnung, die
    // doch nicht gefiel. Ohne ihn traut sich niemand, etwas auszuprobieren.
    func merken() {
        rueckstapel.append(reise)
        if rueckstapel.count > 25 { rueckstapel.removeFirst() }
    }

    var kannZurueck: Bool { !rueckstapel.isEmpty }

    func zurueck() {
        guard let vorher = rueckstapel.popLast() else { return }
        reise = vorher
    }

    // MARK: - Tage

    func tagIndex(_ id: UUID) -> Int? { reise.tage.firstIndex { $0.id == id } }

    var tag: Reisetag? {
        guard let gewaehlterTag else { return reise.tage.first }
        return reise.tage.first { $0.id == gewaehlterTag }
    }

    func tagHinzufuegen(_ datum: Tagesdatum) {
        merken()
        let stelle = reise.tagIndex(fuer: datum)
        neuAnordnen(reise.tage[stelle].id, erzwingen: true)
        gewaehlterTag = reise.tage.first { $0.datum == datum }?.id
    }

    func tagLoeschen(_ id: UUID) {
        merken()
        reise.tage.removeAll { $0.id == id }
        if gewaehlterTag == id { gewaehlterTag = reise.tage.first?.id }
    }

    // MARK: - Satz

    // Der Automat kommt von der Reise selbst — sonst gäbe es ihn zweimal,
    // und die Seitenfolge (die ihn für die Titelseite braucht) hätte einen
    // anderen als die Tagesseiten.
    var automat: Layoutautomat { reise.automat }

    func stilAnwenden(_ stil: Buchstil) {
        merken()
        reise.stilAnwenden(stil)
        // Ein Stil ändert Ränder, Fugen und Schriftgrößen — also alles, was
        // die Seiten bestimmt. Sie nicht neu zu setzen hieße, den Stil zu
        // wählen und ihn nicht zu sehen.
        alleNeuAnordnen(nurUnberuehrte: true)
    }

    // Gibt zurück, ob an diesem Tag von Hand gearbeitet wurde. Die Ansicht
    // fragt damit nach, BEVOR sie eine Stunde Arbeit überschreibt.
    func hatHandarbeit(_ id: UUID) -> Bool {
        guard let stelle = tagIndex(id) else { return false }
        return reise.tage[stelle].seiten.contains { $0.vonHand }
    }

    func neuAnordnen(_ id: UUID, erzwingen: Bool) {
        guard let stelle = tagIndex(id) else { return }
        if !erzwingen, hatHandarbeit(id) { return }
        merken()
        reise.tage[stelle].seiten = automat.seiten(fuer: reise.tage[stelle])
        seitenzeiger = 0
    }

    func alleNeuAnordnen(nurUnberuehrte: Bool) {
        merken()
        let werkzeug = automat
        for stelle in reise.tage.indices {
            if nurUnberuehrte, reise.tage[stelle].seiten.contains(where: { $0.vonHand }) { continue }
            reise.tage[stelle].seiten = werkzeug.seiten(fuer: reise.tage[stelle])
        }
    }

    // Seiten, die noch gar nicht gesetzt sind, werden beim Öffnen gesetzt.
    // Das ist kein Neuanordnen: Eine leere Seitenliste ist kein Stand, den
    // jemand gewollt haben könnte.
    func fehlendeSeitenNachholen() {
        let werkzeug = automat
        for stelle in reise.tage.indices where reise.tage[stelle].seiten.isEmpty {
            reise.tage[stelle].seiten = werkzeug.seiten(fuer: reise.tage[stelle])
        }
    }

    // MARK: - Blöcke

    func block(_ id: UUID) -> (tag: Int, seite: Int, block: Int)? {
        for (t, tag) in reise.tage.enumerated() {
            for (s, seite) in tag.seiten.enumerated() {
                if let b = seite.bloecke.firstIndex(where: { $0.id == id }) {
                    return (t, s, b)
                }
            }
        }
        return nil
    }

    func aendere(_ id: UUID, merken merkt: Bool = true, _ arbeit: (inout Block) -> Void) {
        guard let stelle = block(id) else { return }
        if merkt { merken() }
        arbeit(&reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block])
        reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block].vonHand = true
    }

    // Beim Schieben wird NICHT bei jedem Bildpunkt ein Zwischenstand
    // gemerkt — sonst wäre der Rückgängig-Stapel nach einer Fingerbewegung
    // voll und der Zustand davor nicht mehr erreichbar.
    func schiebe(_ id: UUID, dx: Double, dy: Double, merken merkt: Bool) {
        guard let stelle = block(id) else { return }
        if merkt { merken() }
        var block = reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block]
        block.rahmen = block.rahmen.verschoben(dx: dx, dy: dy).begrenzt(auf: reise.format.groesse)
        block.vonHand = true
        reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block] = block
    }

    // Die Bildunterschrift eines Fotos ein- und ausschalten.
    //
    // Sie wird SOFORT gesetzt oder weggenommen und nicht erst beim nächsten
    // Neuanordnen: Ein Schalter, nach dem auf der Seite nichts passiert,
    // ist für den Menschen davor ein kaputter Schalter. Den ganzen Tag neu
    // zu setzen wäre die andere Möglichkeit und die schlechtere — sie
    // nähme jede Handarbeit mit.
    func unterschriftUmschalten(_ fotoID: UUID, an: Bool) {
        merken()
        if var foto = reise.foto(fotoID) {
            foto.unterschriftZeigen = an
            reise.setzeFoto(foto)
        }
        let bild = reise.typografie.bildunterschrift
        let text = reise.foto(fotoID)?.unterschrift ?? ""
        for t in reise.tage.indices {
            for s in reise.tage[t].seiten.indices {
                if !an {
                    reise.tage[t].seiten[s].bloecke.removeAll {
                        $0.inhalt == .bildunterschrift(fotoID)
                    }
                    continue
                }
                guard !reise.tage[t].seiten[s].bloecke.contains(where: {
                    $0.inhalt == .bildunterschrift(fotoID)
                }), let stelle = reise.tage[t].seiten[s].bloecke.firstIndex(where: {
                    $0.fotoID == fotoID
                }) else { continue }
                let fotoblock = reise.tage[t].seiten[s].bloecke[stelle]
                let hoehe = Textmass.hoehe(text.isEmpty ? "Bildunterschrift" : text,
                                           bild: bild, breite: fotoblock.rahmen.breite)
                let neu = Block(
                    inhalt: .bildunterschrift(fotoID),
                    rahmen: Rahmen(x: fotoblock.rahmen.x,
                                   y: fotoblock.rahmen.y + fotoblock.rahmen.hoehe + 3,
                                   breite: fotoblock.rahmen.breite, hoehe: hoehe)
                )
                reise.tage[t].seiten[s].bloecke.insert(neu, at: stelle + 1)
            }
        }
    }

    // Der kurze Weg von einem Foto zu seiner Unterschrift: einschalten,
    // wenn sie aus ist, den Block suchen und ihn gleich zum Schreiben
    // öffnen. Gemeldet 09/2026: „Ich habe noch nicht gefunden, wie ich eine
    // Unterschrift unter ein Bild setzen kann." Sie stand im Inspektor
    // hinter dem Abschnitt „Foto" und in der Fotoliste des Tages — beides
    // Wege, die man kennen muss. **Ein Knopf, den niemand findet, ist kein
    // Knopf**, und das gilt auch für einen Schalter in einem Formular.
    func unterschriftOeffnen(_ fotoID: UUID) {
        if reise.foto(fotoID)?.unterschriftZeigen != true {
            unterschriftUmschalten(fotoID, an: true)
        }
        for tag in reise.tage {
            for seite in tag.seiten {
                guard let block = seite.bloecke.first(where: {
                    $0.inhalt == .bildunterschrift(fotoID)
                }) else { continue }
                gewaehlterBlock = block.id
                textBearbeitung = block.id
                return
            }
        }
    }

    // Wohin ein auf der Seite geänderter Text gehört, hängt an der Blockart:
    // Der Fließtext steckt im Block, die Überschrift und die Datumszeile am
    // TAG, die Bildunterschrift am FOTO. Alles in den Block zu schreiben
    // wäre der bequeme Weg und der falsche — beim nächsten Neuanordnen
    // entstünde ein neuer Block, und die Änderung wäre weg.
    func textSchreiben(_ id: UUID, text: String) {
        guard let stelle = block(id) else { return }
        merken()
        let art = reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block].inhalt
        switch art {
        case let .bildunterschrift(fotoID):
            // Sie gehört dem Foto und reist mit ihm mit.
            if var foto = reise.foto(fotoID) {
                foto.unterschrift = text
                if !text.isEmpty { foto.unterschriftZeigen = true }
                reise.setzeFoto(foto)
            }
        case .titel:
            reise.tage[stelle.tag].ueberschrift = text
        case .datum:
            // Leer heißt: wieder das Format des Buches.
            reise.tage[stelle.tag].datumstext = text.isEmpty ? nil : text
        case .text:
            reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block].inhalt = .text(text)
            reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block].vonHand = true
        default:
            break
        }
        // Der Kasten WÄCHST mit dem Text, wie ein Textfeld in Pages. Ohne
        // das schriebe man in einen Kasten hinein, und der Rest fiele
        // unten heraus, ohne dass etwas darauf hinweist. `merken` steht
        // schon oben — ein zweiter Stand wäre ein zweiter Schritt
        // zurück für eine Änderung.
        hoeheAnTextAnpassen(id, merken: false)
    }

    // MARK: - Ein Tagebuch darf keinen Satz verlieren

    // Wie hoch ein Textblock sein MÜSSTE, damit sein Text vollständig
    // hineinpasst — oder nil, wenn er es schon tut.
    //
    // Gemessen mit demselben Satz, der hinterher zeichnet und druckt
    // (`Textmass`), nicht geschätzt. Ein Kasten, aus dem unten zwei Sätze
    // herausfallen, sieht auf dem Bildschirm aus wie ein Kasten, der zu
    // Ende ist — das ist der eine Fehler, den ein Tagebuch nicht machen
    // darf.
    func fehlendeHoehe(_ block: Block, tag: Reisetag) -> Double? {
        guard block.inhalt.istText else { return nil }
        let text = Seitensatz.inhaltstext(block, tag: tag, reise: reise)
        guard !text.isEmpty, block.rahmen.breite > 1 else { return nil }
        let bild = Seitensatz.schriftbild(block, reise: reise)
        // Gemessen wird in der TEXTbreite, nicht in der Blockbreite: Liegt
        // ein Innenabstand darum, steht dem Text weniger zur Verfügung, und
        // eine Messung ohne ihn meldete „passt", während im Druck eine Zeile
        // fehlt. Zurückgegeben wird wieder eine BLOCKhöhe — der Rahmen ist
        // es, den der Knopf danach hochzieht.
        let rand = block.textrand(reise.gestaltung)
        let noetig = Textmass.hoehe(text, bild: bild, breite: block.textbreite(rand: rand))
            + 2 * rand
        return noetig > block.rahmen.hoehe + 0.5 ? noetig : nil
    }

    // Den Rahmen so hoch machen, dass der Text hineinpasst. Nur WACHSEN:
    // Ein Kasten, der beim Tippen von selbst schrumpft, nähme eine Größe
    // weg, die jemand mit der Hand eingestellt hat.
    @discardableResult
    func hoeheAnTextAnpassen(_ id: UUID, merken merkt: Bool = true) -> Bool {
        guard let stelle = block(id) else { return false }
        let tag = reise.tage[stelle.tag]
        let block = tag.seiten[stelle.seite].bloecke[stelle.block]
        guard let noetig = fehlendeHoehe(block, tag: tag) else { return false }
        if merkt { merken() }
        reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block].rahmen.hoehe = noetig
        reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block].vonHand = true
        textUeberlauf = nil
        return true
    }

    // MARK: - Einen Textkasten teilen

    // Nur der Tagebuchtext lässt sich teilen. Überschrift, Datumszeile und
    // Bildunterschrift stehen am Tag bzw. am Foto; von ihnen eine zweite
    // Hälfte anzulegen hieße, eine Kopie zu bauen, die beim nächsten
    // Neuanordnen auseinanderläuft.
    func teilbar(_ block: Block) -> Bool {
        if case .text = block.inhalt { return true }
        return false
    }

    // Teilt einen Textkasten und führt ihn auf einer weiteren Seite fort.
    //
    // Zwei Wege, und beide hat der Nutzer beschrieben (09/2026: „Im
    // Nachhinein möchte ich eine Textbox gegebenenfalls teilen können und
    // sie manuell auf einer weiteren Seite fortführen können."):
    // `nachAbsatz: nil` teilt dort, wo der Kasten voll ist — also genau
    // das, was unten herausfällt, wandert weiter; eine Zahl teilt nach dem
    // genannten Absatz.
    //
    // Der erste Kasten behält seinen Rahmen. Ihn auf den verbliebenen Text
    // zu schrumpfen wäre der naheliegende Griff und der falsche: Dieselbe
    // Regel wie bei `hoeheAnTextAnpassen` — ein Kasten, der von selbst
    // kleiner wird, nimmt eine Größe weg, die jemand mit der Hand
    // eingestellt hat.
    @discardableResult
    func textTeilen(_ id: UUID, nachAbsatz: Int? = nil) -> Bool {
        guard let stelle = block(id) else { return false }
        let tag = reise.tage[stelle.tag]
        let block = tag.seiten[stelle.seite].bloecke[stelle.block]
        guard case let .text(inhalt) = block.inhalt else {
            // Überschrift, Datumszeile und Bildunterschrift stehen am Tag
            // bzw. am Foto und nicht im Block — sie zu teilen hieße, eine
            // Kopie anzulegen, die beim nächsten Neuanordnen auseinanderläuft.
            meldung = .init(text: "Teilen geht nur beim Tagebuchtext. Überschrift, "
                            + "Datumszeile und Bildunterschrift gehören dem Tag "
                            + "bzw. dem Foto.", schwer: true)
            return false
        }

        let bild = Seitensatz.schriftbild(block, reise: reise)
        let rand = block.textrand(reise.gestaltung)
        let breite = block.textbreite(rand: rand)
        var kopf = ""
        var rest = ""

        if let nachAbsatz {
            (kopf, rest) = Textaufbereitung.teilen(inhalt, nachAbsatz: nachAbsatz)
        } else {
            let platz = CGSize(width: breite, height: max(block.rahmen.hoehe - 2 * rand, 1))
            (kopf, rest) = Textmass.teilen(inhalt, bild: bild, groesse: platz)
        }

        guard !rest.isEmpty else {
            meldung = .init(text: "Hier ist nichts zu teilen: Der Text passt "
                            + "vollständig in diesen Kasten.")
            return false
        }
        guard !kopf.isEmpty else {
            // Passt nicht eine Zeile hinein, ist der Kasten zu klein oder
            // die Schrift zu groß. Den ganzen Text wegzuschieben sähe aus,
            // als sei er verschwunden.
            meldung = .init(text: "In diesen Kasten passt nicht einmal die erste Zeile — "
                            + "erst den Rahmen größer ziehen oder die Schrift kleiner "
                            + "stellen.", schwer: true)
            return false
        }

        merken()
        reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block].inhalt = .text(kopf)
        reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block].vonHand = true

        // Die Fortsetzung ist eine KOPIE des Kastens — mit neuer Kennung.
        // Sie soll aussehen wie ihr Anfang: Schrift, Grund, Innenabstand,
        // Linie und Breite bleiben, nur Inhalt, Lage und Höhe sind neu.
        var fortsetzung = block
        fortsetzung.id = UUID()
        fortsetzung.inhalt = .text(rest)
        fortsetzung.vonHand = true
        fortsetzung.ebene = 0
        let satz = reise.gestaltung.satzspiegel(reise.format)
        let noetig = Textmass.hoehe(rest, bild: bild, breite: breite) + 2 * rand
        fortsetzung.rahmen = Rahmen(x: block.rahmen.x, y: satz.minY,
                                    breite: block.rahmen.breite,
                                    hoehe: min(noetig, satz.height))

        // Auf eine LEERE Folgeseite darf die Fortsetzung; auf eine schon
        // gefüllte nicht — dort läge sie über dem, was da steht. Dann
        // bekommt sie eine eigene Seite, und die steht unmittelbar hinter
        // dem Anfang: Eine Fortsetzung drei Seiten später findet niemand.
        let folge = stelle.seite + 1
        let seiten = reise.tage[stelle.tag].seiten
        let leerDa = seiten.indices.contains(folge) && seiten[folge].bloecke.isEmpty
        if !leerDa {
            reise.tage[stelle.tag].seiten.insert(Seite(), at: min(folge, seiten.count))
        }
        let ziel = min(folge, reise.tage[stelle.tag].seiten.count - 1)
        reise.tage[stelle.tag].seiten[ziel].bloecke.append(fortsetzung)
        reise.tage[stelle.tag].seiten[ziel].heben(fortsetzung.id)

        // Hingehen, wo die Fortsetzung steht. Ein Knopf, nach dem sich
        // sichtbar nichts tut, ist für den Menschen davor ein kaputter Knopf.
        seitenzeiger = ziel
        gewaehlterBlock = fortsetzung.id
        textUeberlauf = nil
        meldung = .init(text: "Der Kasten ist geteilt — der Rest steht auf Seite "
                        + "\(ziel + 1) dieses Tages.")
        return true
    }

    // Alle Abweichungen einzelner Fotos zurücknehmen — danach folgt jedes
    // Foto wieder der Einstellung des Buches.
    func fotowirkungVereinheitlichen() {
        merken()
        for t in reise.tage.indices {
            for s in reise.tage[t].seiten.indices {
                for b in reise.tage[t].seiten[s].bloecke.indices
                where reise.tage[t].seiten[s].bloecke[b].istFoto {
                    reise.tage[t].seiten[s].bloecke[b].schatten = nil
                    reise.tage[t].seiten[s].bloecke[b].fotorand = nil
                    reise.tage[t].seiten[s].bloecke[b].randbreite = nil
                    reise.tage[t].seiten[s].bloecke[b].rand = nil
                }
            }
        }
    }

    // Dasselbe für die Textkästen — danach folgt jeder wieder der
    // Einstellung des Buches. Der weiße Sofortbild-Rand bleibt außen vor:
    // Den gibt es nur am Foto.
    func textwirkungVereinheitlichen() {
        merken()
        for t in reise.tage.indices {
            for s in reise.tage[t].seiten.indices {
                for b in reise.tage[t].seiten[s].bloecke.indices
                where reise.tage[t].seiten[s].bloecke[b].inhalt.istText {
                    reise.tage[t].seiten[s].bloecke[b].schatten = nil
                    reise.tage[t].seiten[s].bloecke[b].randbreite = nil
                    reise.tage[t].seiten[s].bloecke[b].rand = nil
                    reise.tage[t].seiten[s].bloecke[b].grund = nil
                    reise.tage[t].seiten[s].bloecke[b].innenabstand = nil
                    reise.tage[t].seiten[s].bloecke[b].ohneGrund = false
                }
            }
        }
    }

    func tagAendern(_ id: UUID, _ arbeit: (inout Reisetag) -> Void) {
        guard let stelle = tagIndex(id) else { return }
        merken()
        arbeit(&reise.tage[stelle])
    }

    // Absätze eines Tages aufräumen — derselbe Lauf wie beim Einlesen, für
    // Texte, die schon im Buch stehen.
    @discardableResult
    func absaetzeAufraeumen(_ tagID: UUID) -> Textaufbereitung.Befund? {
        guard let stelle = tagIndex(tagID) else { return nil }
        let befund = Textaufbereitung.pruefen(reise.tage[stelle].text)
        guard befund.zusammengefuehrt else { return befund }
        merken()
        reise.tage[stelle].text = Textaufbereitung.leerzeilenStraffen(befund.text)
        neuAnordnen(tagID, erzwingen: false)
        return befund
    }

    func blockLoeschen(_ id: UUID) {
        guard let stelle = block(id) else { return }
        merken()
        reise.tage[stelle.tag].seiten[stelle.seite].bloecke.remove(at: stelle.block)
        if gewaehlterBlock == id { gewaehlterBlock = nil }
    }

    func blockNachVorn(_ id: UUID) {
        guard let stelle = block(id) else { return }
        merken()
        reise.tage[stelle.tag].seiten[stelle.seite].heben(id)
    }

    func blockHinzufuegen(_ inhalt: Blockinhalt, tag tagID: UUID, seite: Int) {
        guard let t = tagIndex(tagID), reise.tage[t].seiten.indices.contains(seite) else { return }
        merken()
        let satz = reise.gestaltung.satzspiegel(reise.format)
        let breite = min(satz.width * 0.46, 260.0)
        let neu = Block(
            inhalt: inhalt,
            rahmen: Rahmen(x: satz.midX - breite / 2, y: satz.midY - 60,
                           breite: breite, hoehe: inhalt.istFoto ? breite * 0.7 : 90),
            vonHand: true
        )
        reise.tage[t].seiten[seite].bloecke.append(neu)
        reise.tage[t].seiten[seite].heben(neu.id)
        gewaehlterBlock = neu.id
    }

    func seiteHinzufuegen(_ tagID: UUID) {
        guard let t = tagIndex(tagID) else { return }
        merken()
        reise.tage[t].seiten.append(Seite())
        seitenzeiger = reise.tage[t].seiten.count - 1
    }

    func seiteLoeschen(_ tagID: UUID, seite: Int) {
        guard let t = tagIndex(tagID), reise.tage[t].seiten.count > 1,
              reise.tage[t].seiten.indices.contains(seite) else { return }
        merken()
        reise.tage[t].seiten.remove(at: seite)
        seitenzeiger = min(seitenzeiger, reise.tage[t].seiten.count - 1)
    }

    // MARK: - Spur

    // Die Spuren aus der Tagesspur übernehmen.
    //
    // Idempotent: Was bei einem früheren Einlesen desselben Tages
    // hereinkam, wird ERSETZT und nicht verdoppelt. Wer eine Sicherung
    // zweimal wählt, soll nicht die doppelte Spur bekommen. Punkte aus
    // Fotos und von Hand bleiben unberührt und werden nach der Uhrzeit
    // wieder eingeordnet.
    @discardableResult
    func spurUebernehmen(_ tage: [Spureinfuhr.Tagesspur], fehlendeAnlegen: Bool) -> String {
        merken()
        var geaendert = 0
        var angelegt = 0
        var uebersprungen = 0
        for neue in tage {
            var stelle = reise.tage.firstIndex { $0.datum == neue.datum }
            if stelle == nil {
                guard fehlendeAnlegen else {
                    uebersprungen += 1
                    continue
                }
                stelle = reise.tagIndex(fuer: neue.datum)
                angelegt += 1
            }
            guard let stelle else { continue }
            let behalten = reise.tage[stelle].spur.filter { $0.quelle != .tagesspur }
            var spur = neue.punkte
            for punkt in behalten {
                guard let zeit = punkt.zeit else {
                    spur.append(punkt)
                    continue
                }
                let wohin = spur.firstIndex { ($0.zeit ?? .distantFuture) > zeit } ?? spur.count
                spur.insert(punkt, at: wohin)
            }
            reise.tage[stelle].spur = spur
            // Woraufhin sich die Uhrzeiten dieses Tages beziehen. Sie sind
            // bereits umgerechnet; das Feld ist die Auskunft dazu.
            if let zone = neue.zone { reise.tage[stelle].zeitzone = zone.identifier }
            geaendert += 1
        }
        reise.tage.sort { $0.datum < $1.datum }
        // NEU SETZEN, nicht bloß fehlende Seiten nachholen (ab 1.0.17).
        //
        // Bis 1.0.16 stand hier `fehlendeSeitenNachholen()`, und das
        // überspringt jeden Tag, dessen Seitenliste schon gefüllt ist. Der
        // Kartenblock entsteht aber erst, wenn der Tag eine Spur HAT
        // (`Layoutautomat.seiten`: `tag.karteZeigen && tag.hatSpur`). Wer
        // also in der vom Nutzer beschriebenen Reihenfolge arbeitet — erst
        // der Text, dann die Reisespur — bekam auf keiner Seite eine Karte,
        // und zwar stumm: Die Tage waren angelegt, die Punkte standen in
        // der Liste, nur gesetzt wurde nichts. Dass es beim Einlesen der
        // FOTOS danach doch noch auffiel, war Zufall — dieser Weg rief
        // `alleNeuAnordnen` von Anfang an.
        // `nurUnberuehrte` hält die Handarbeit an: Ein Tag, an dem jemand
        // geschoben hat, bleibt, wie er ist.
        alleNeuAnordnen(nurUnberuehrte: true)
        var satz = "\(geaendert) Tage haben eine neue Spur"
        if angelegt > 0 { satz += ", \(angelegt) davon neu angelegt" }
        if uebersprungen > 0 { satz += "; \(uebersprungen) übersprungen, weil es den Tag nicht gibt" }
        return satz + "."
    }

    func spurAktualisieren(_ tagID: UUID) {
        guard let t = tagIndex(tagID) else { return }
        let fotos = reise.tage[t].fotos.compactMap { reise.foto($0) }
        reise.tage[t].spur = Spurbau.aktualisiert(
            spur: reise.tage[t].spur,
            fotos: fotos,
            mindestabstand: reise.gestaltung.mindestabstandSpur
        )
    }

    // Ob ein Tag eine Spur HAT, entscheidet über den Kartenblock. Kippt das
    // um, muss die Seite neu gesetzt werden — sonst bleibt die Karte aus
    // oder steht leer da. Nur beim UMKIPPEN: Ein Punkt mehr in einer
    // vorhandenen Spur soll die Seite nicht durcheinanderwerfen, und
    // `erzwingen: false` hält die Handarbeit ohnehin an.
    private func spurGeaendert(_ tagID: UUID, hatteSpur: Bool) {
        guard let t = tagIndex(tagID) else { return }
        if reise.tage[t].hatSpur != hatteSpur {
            neuAnordnen(tagID, erzwingen: false)
        }
    }

    func punktHinzufuegen(_ tagID: UUID, ort: Koordinate, name: String, zeit: Date?) {
        guard let t = tagIndex(tagID) else { return }
        merken()
        let hatteSpur = reise.tage[t].hatSpur
        let punkt = Reisepunkt(koordinate: ort, name: name, zeit: zeit, quelle: .vonHand)
        if let zeit {
            let stelle = reise.tage[t].spur.firstIndex { ($0.zeit ?? .distantFuture) > zeit }
                ?? reise.tage[t].spur.count
            reise.tage[t].spur.insert(punkt, at: stelle)
        } else {
            reise.tage[t].spur.append(punkt)
        }
        spurGeaendert(tagID, hatteSpur: hatteSpur)
    }

    func punkteLoeschen(_ tagID: UUID, stellen: IndexSet) {
        guard let t = tagIndex(tagID) else { return }
        merken()
        let hatteSpur = reise.tage[t].hatSpur
        reise.tage[t].spur.remove(atOffsets: stellen)
        spurGeaendert(tagID, hatteSpur: hatteSpur)
    }

    func punkteVerschieben(_ tagID: UUID, von: IndexSet, nach: Int) {
        guard let t = tagIndex(tagID) else { return }
        merken()
        reise.tage[t].spur.move(fromOffsets: von, toOffset: nach)
    }

    // MARK: - Fotos

    func fotoZuTag(_ fotoID: UUID, tag tagID: UUID) {
        guard let t = tagIndex(tagID) else { return }
        merken()
        for stelle in reise.tage.indices { reise.tage[stelle].fotos.removeAll { $0 == fotoID } }
        reise.tage[t].fotos.append(fotoID)
        spurAktualisieren(tagID)
    }

    func fotoEntfernen(_ fotoID: UUID) {
        merken()
        for stelle in reise.tage.indices { reise.tage[stelle].fotos.removeAll { $0 == fotoID } }
        if let foto = reise.foto(fotoID) {
            Bildarchiv.shared.loeschen(foto.datei, reise: reise.id)
        }
        reise.fotos.removeAll { $0.id == fotoID }
        for t in reise.tage.indices {
            for s in reise.tage[t].seiten.indices {
                reise.tage[t].seiten[s].bloecke.removeAll { $0.fotoID == fotoID }
            }
        }
    }

    func fotoOrtSetzen(_ fotoID: UUID, ort: Koordinate) {
        guard var foto = reise.foto(fotoID) else { return }
        merken()
        foto.koordinate = ort
        foto.ortsquelle = .vonHand
        reise.setzeFoto(foto)
        if let tag = reise.tage.first(where: { $0.fotos.contains(fotoID) }) {
            spurAktualisieren(tag.id)
        }
    }
}
