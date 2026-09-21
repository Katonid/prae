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

    // Wohin ein auf der Seite geänderter Text gehört, hängt an der Blockart:
    // Der Fließtext steckt im Block, die Überschrift und die Datumszeile am
    // TAG. Sie in den Block zu schreiben wäre der bequeme Weg und der
    // falsche — beim nächsten Neuanordnen entstünde ein neuer Block, und die
    // Änderung wäre weg.
    func textSchreiben(_ id: UUID, text: String) {
        guard let stelle = block(id) else { return }
        merken()
        let art = reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block].inhalt
        switch art {
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

    func spurAktualisieren(_ tagID: UUID) {
        guard let t = tagIndex(tagID) else { return }
        let fotos = reise.tage[t].fotos.compactMap { reise.foto($0) }
        reise.tage[t].spur = Spurbau.aktualisiert(
            spur: reise.tage[t].spur,
            fotos: fotos,
            mindestabstand: reise.gestaltung.mindestabstandSpur
        )
    }

    func punktHinzufuegen(_ tagID: UUID, ort: Koordinate, name: String, zeit: Date?) {
        guard let t = tagIndex(tagID) else { return }
        merken()
        let punkt = Reisepunkt(koordinate: ort, name: name, zeit: zeit, quelle: .vonHand)
        if let zeit {
            let stelle = reise.tage[t].spur.firstIndex { ($0.zeit ?? .distantFuture) > zeit }
                ?? reise.tage[t].spur.count
            reise.tage[t].spur.insert(punkt, at: stelle)
        } else {
            reise.tage[t].spur.append(punkt)
        }
    }

    func punkteLoeschen(_ tagID: UUID, stellen: IndexSet) {
        guard let t = tagIndex(tagID) else { return }
        merken()
        reise.tage[t].spur.remove(atOffsets: stellen)
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
