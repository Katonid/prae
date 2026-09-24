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
    // AUF WELCHER SEITE ETWAS EINGESETZT WIRD (ab 1.0.61).
    //
    // Befund des Nutzers, 09/2026: „schwer zu erkennen, ob eine Seite
    // ausgewählt wird bzw. auf welcher Seite die Änderungen, die ich
    // vornehmen möchte, greifen werden."
    //
    // Er hat recht, und es war schlimmer als unsichtbar: Bis 1.0.60 stand
    // unter „Auf die Seite legen" im Inspektor der `seitenzeiger` — ein
    // Zähler, den Einfügen, Löschen und Verschieben setzen, der mit dem,
    // was gerade im Bild steht, aber NICHTS zu tun hat. Der neue Block
    // landete also auf irgendeiner Seite des gewählten Tages, und wer ihn
    // dort nicht fand, hielt den Knopf für kaputt.
    //
    // Gewählt wird jetzt eine SEITE, sie wird auf der Bühne sichtbar
    // umrandet, und sie folgt dem, was oben im Bild steht — dieselbe
    // Regel wie beim gewählten Tag seit 1.0.28. Ein Tipp auf ein Blatt
    // wählt es ausdrücklich.
    @Published var gewaehlteSeite: UUID?
    @Published var seitenzeiger: Int = 0
    @Published var meldung: Meldung?
    @Published var beschaeftigt: String?
    // DIE ZWISCHENABLAGE (ab 1.0.65).
    //
    // Befund des Nutzers, 09/2026: „Im Moment ist es so, dass ich zum
    // Beispiel ein Foto nur auf eine Seite verschieben kann, die nach der
    // aktuellen Seite neu angelegt wird. Etwas anderes steht mir offenbar
    // nicht zur Verfügung. Ich würde es begrüßen, wenn ich dort einen ganz
    // normalen Dialog bekommen würde, so wie er in jeder App gültig ist.
    // Ausschneiden, kopieren, einfügen."
    //
    // Er hat recht, und der Grund steht im Quelltext: `blockVerschieben`
    // und `blockKopieren` rechnen beide mit `seitenlage`, also mit den
    // Seiten DIESES Tages — und ein frisch angelegter Tag hat genau eine.
    // Dann fällt „eine Seite zurück“, „eine Seite vor“ und „auf Seite …“
    // weg, und übrig bleibt der eine Eintrag, den er beschreibt.
    //
    // Ausschneiden, Kopieren und Einfügen lösen das allgemein: Was in der
    // Ablage liegt, geht auf JEDE gewählte Seite — auch in einen anderen
    // Tag und auf den Umschlag. Damit braucht die Zielseite keinen Platz
    // in einem Menü mehr; sie wird ausgewählt wie sonst auch.
    @Published private(set) var ablage: Ablageinhalt?

    struct Ablageinhalt {
        var block: Block
        // Woher er kam. Bei einem Block vom Umschlag ist das `nil` — und
        // genau daran hängt die Regel unten, dass ein Tagebuchtext seinen
        // Tag nicht verlässt.
        var tagID: UUID?
        var ausgeschnitten: Bool

        var name: String { block.inhalt.name }
    }

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
    // Was beim letzten Zoomen der BUEHNE gerechnet wurde (ab 1.0.22).
    //
    // Eine eigene Zeile neben `letzterGriff`, weil es zwei verschiedene
    // Fragen sind: Dort geht es darum, was ein Block entgegengenommen hat,
    // hier darum, ob sich die Seite ueberhaupt schieben laesst. Gemeldet
    // 09/2026: „Die Seite kann leider nicht verschoben werden. Wenn ich sie
    // zoome, dann springt sie immer in irgendeine offenbar vorgerasterte
    // Position." Geschrieben wird EINMAL je Geste und nie je Bildpunkt —
    // ein `@Published` im Sekundentakt waere der Fehler aus 1.0.16.
    @Published var letzteBuehne: String?
    @Published var zeigeGriffprobe = false

    // WO DIE BILDER DIESES BUCHES LIEGEN (ab 1.0.71).
    //
    // Gemeldet 09/2026: „Auf dem iPad ist kein Arbeiten möglich. Vielleicht
    // liegt es daran, dass ich das Projekt insgesamt auf einem anderen
    // Gerät erstellt und verarbeitet habe." Ein Buch kommt über iCloud
    // Drive binnen Sekunden an — die JSON-Datei ist klein —, seine
    // zweihundert Bilder brauchen länger, und bis 1.0.70 wurden sie
    // überhaupt nicht angefordert (siehe `Wolkenbilder`).
    //
    // Der Stand ist ein GESPEICHERTER Wert und keine berechnete
    // Eigenschaft: Dahinter steckt ein Lauf über jede Bilddatei, und der
    // Körper einer Ansicht läuft bei jedem Neuzeichnen. Vierte Auflage
    // derselben Falle — eine berechnete Eigenschaft sieht billig aus.
    @Published private(set) var bildstand: Wolkenbilder.Stand?
    private var bilderauftrag: Task<Void, Never>?
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

    // DIE BEFUNDE DER DRUCKPRÜFUNG, AUF DER SEITE (ab 1.0.93).
    //
    // Ansage des Nutzers, 09/2026: „Ich möchte, dass nach der
    // Dokumentprüfung alle Stellen im Dokument, an denen etwas auszusetzen
    // war, rot umrandet erscheinen. Ich habe jetzt beispielsweise recht
    // viel Zeit dafür verwendet, an den angegebenen Tagen die Textfelder zu
    // suchen, die angeblich zu klein sind."
    //
    // **GESPEICHERT und nicht gerechnet.** Dahinter steckt ein voller
    // CoreText-Satz je Textblock des Buches; als berechnete Eigenschaft
    // liefe er bei jedem Neuzeichnen der Bühne mit — dieselbe Falle wie bei
    // `textUeberlauf` seit 1.0.8 und bei der Netzkarte der Abfahrtstafel.
    // Gerechnet wird deshalb auf EINEN Anlass: wenn die Prüfung läuft, wenn
    // jemand „Im Buch zeigen" tippt, und danach bei jedem Griff, der einen
    // Block ändern kann — aber NUR, solange die Marken überhaupt gezeigt
    // werden. Ist der Schalter aus, kostet das Ganze nichts.
    @Published private(set) var befundstellen: [Befundstelle] = []
    @Published var zeigeBefunde: Bool = false {
        didSet {
            guard zeigeBefunde != oldValue else { return }
            if zeigeBefunde { befundeAuffrischen(erzwingen: true) } else { befundstellen = [] }
        }
    }
    /// Welche Stelle gerade angesteuert wurde — für „Befund 3 von 12".
    @Published var befundzeiger: Int = 0
    /// Ein Sprungwunsch an die Bühne: die Seite, auf der etwas steht.
    /// `ReiseView` löst ihn ein und setzt ihn zurück.
    @Published var sprungZuSeite: UUID?
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
    // Seit 1.0.50 gilt dasselbe für die RÜCKSEITE des Buches: Auch sie
    // gibt es nicht, sie wird gerechnet — und sie hängt an denselben
    // Werten plus dem, was auf ihr steht.
    private var rueckblatt: (schluessel: Int, seite: Seite)?

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
        // Der Umschlag bringt seit 1.0.50 eigene Gestaltung mit: Rand,
        // Hintergrund, Schrift, Titelgröße — und den Text der Rückseite.
        // Fehlte er hier, bliebe ein alter Umschlag stehen, ohne dass
        // etwas darauf hinwiese.
        //
        // Seit 1.0.64 nur sein `satzmerkmal` und nicht mehr er selbst: Die
        // eigenen Blöcke auf Titel- und Rückseite werden erst HINTER dem
        // gerechneten Satz angehängt (`Reise.seitenfolge`). Ständen sie im
        // Schlüssel, setzte jeder Bildpunkt einer Ziehbewegung die
        // Titelseite neu — zwei CoreText-Messungen je Fingerbewegung.
        misch.combine(reise.umschlag.satzmerkmal)
        return misch.finalize()
    }

    // Die Seitenfolge der Bühne. Gezählt wird sie NICHT hier, sondern in
    // `Reise.seitenfolge(titelblatt:rueckblatt:)` — bis 1.0.51 stand die
    // Zählung an beiden Stellen, und eine davon hätte die andere
    // irgendwann überholt. Was hier bleibt, ist das Merken der gesetzten
    // Umschlagseiten: Ihr Satz kostet zwei CoreText-Messungen, und der
    // Körper einer Ansicht läuft oft.
    var seitenfolge: [Buchseite] {
        var gesetztesTitelblatt: Seite?
        var gesetztesRueckblatt: Seite?
        let schluessel = titelblattschluessel
        if reise.hatRueckseite {
            if let da = rueckblatt, da.schluessel == schluessel {
                gesetztesRueckblatt = da.seite
            } else {
                let seite = messer.sammelt("Titelblatt") {
                    reise.automat.rueckseite(text: reise.umschlag.rueckseitentext,
                                             foto: reise.umschlag.rueckseitenfoto)
                }
                rueckblatt = (schluessel, seite)
                gesetztesRueckblatt = seite
            }
        }
        if reise.titelseite {
            if let da = titelblatt, da.schluessel == schluessel {
                gesetztesTitelblatt = da.seite
            } else {
                let seite = messer.sammelt("Titelblatt") {
                    reise.automat.titelseite(titel: reise.titel, untertitel: reise.untertitel,
                                             zeitraum: reise.zeitraum, titelfoto: reise.titelfoto)
                }
                titelblatt = (schluessel, seite)
                gesetztesTitelblatt = seite
            }
        }
        return reise.seitenfolge(titelblatt: gesetztesTitelblatt,
                                 rueckblatt: gesetztesRueckblatt)
    }

    // Gehört diese Seite zu diesem Tag? `Self.titelseitenKennung` steht
    // für die Titelseite, die zu keinem Tag gehört.
    func gehoert(_ seite: Buchseite, zu tag: UUID) -> Bool {
        if tag == Self.titelseitenKennung { return seite.tag == nil }
        return seite.tag?.id == tag
    }

    // DAS GANZE BUCH STEHT UNTEREINANDER (ab 1.0.28, Ansage des Nutzers
    // 09/2026: „Lieb, wenn alle Seiten fortlaufend untereinander stehen
    // würden, beziehungsweise in dieser Ansicht die Doppelseiten, sodass
    // man mühelos von einem Seitenpaar zum nächsten wischen kann, ohne
    // dass man links die Liste der Seiten [braucht]").
    //
    // Bis 1.0.27 filterte diese Liste nach dem gewählten Tag. Damit war
    // die Tagesliste links keine Übersicht, sondern die EINZIGE Art, sich
    // durch das Buch zu bewegen: Wer die letzte Seite eines Tages sah und
    // weiterblättern wollte, musste zur Liste greifen. Ein Buch blättert
    // man aber, man schlägt es nicht neu auf. Gezeigt wird deshalb alles;
    // die Tagesliste ist seither eine SPRUNGMARKE, und welcher Tag gewählt
    // ist, folgt dem, was gerade im Bild steht.
    var sichtbareSeiten: [Buchseite] {
        messer.sammelt("Seitenliste") { () -> [Buchseite] in self.seitenfolge }
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
    //
    // Der UMSCHLAG ist seit 1.0.52 ein eigener Bogen mit der Nummer 0 und
    // steht außerhalb dieser Zählung — bis dahin zählte er mit und schob
    // damit jede Seite des Buchblocks um eine Stelle, also auf die falsche
    // Buchhälfte (siehe `Buchteil`).
    struct Doppelseite: Identifiable {
        // Der laufende Bogen: 0 ist der Umschlag, 1 trägt rechts die
        // Seite 1, 2 die Seiten 2 und 3, und so weiter.
        let bogen: Int
        var links: Buchseite?
        var rechts: Buchseite?

        var id: Int { bogen }
        var istUmschlag: Bool { bogen == 0 }
        // Links liegt die Innenseite des Umschlags — auf dem ersten Bogen
        // des Buchblocks, weil davor keine Seite steht.
        var beginntMitUmschlag: Bool { !istUmschlag && links == nil }
        // Und rechts liegt die Innenseite des RÜCKEN-Umschlags: Eine
        // fehlende rechte Seite kann es nur am Ende des Buches geben, denn
        // gebaut wird der Bogen aus fortlaufenden Nummern.
        var endetMitUmschlag: Bool { !istUmschlag && rechts == nil }
    }

    var doppelseiten: [Doppelseite] {
        let alle = seitenfolge
        guard !alle.isEmpty else { return [] }
        var nachBogen: [Int: Doppelseite] = [:]
        for seite in alle {
            // Links die gerade, rechts die ungerade Nummer — nie
            // umgekehrt. Entschieden wird das an EINER Stelle
            // (`Buchseite.liegtRechts`), und dieselbe Antwort entscheidet
            // seit 1.0.47 auch, welche Hälfte eines Hintergrundbildes auf
            // diese Seite fällt: Zwei Fassungen ergäben eine Ansicht, die
            // anders paart als der Druck.
            let nummer = seite.bogennummer
            var doppel = nachBogen[nummer] ?? Doppelseite(bogen: nummer, links: nil, rechts: nil)
            if seite.liegtRechts { doppel.rechts = seite } else { doppel.links = seite }
            nachBogen[nummer] = doppel
        }
        return nachBogen.keys.sorted().compactMap { nachBogen[$0] }
    }

    // Auch hier das ganze Buch (ab 1.0.28) — siehe `sichtbareSeiten`.
    //
    // Gepaart wurde schon vorher über das GANZE Buch und erst danach
    // gefiltert, und der Grund dafür gilt weiter: Eine Paarung innerhalb
    // einer Auswahl verschöbe die Seiten. Fängt ein Tag auf einer linken
    // Seite an, stünde er darin plötzlich rechts — und die Doppelseite
    // zeigte etwas, das im gedruckten Buch nie so aussieht. Jetzt entfällt
    // der Filter ganz, und damit auch diese Falle.
    var sichtbareDoppelseiten: [Doppelseite] {
        messer.sammelt("Seitenliste") { () -> [Doppelseite] in self.doppelseiten }
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

    // MARK: - Bilder aus iCloud

    // Nachsehen, was von den Bildern dieses Buches auf dem Gerät liegt —
    // und anstoßen, was fehlt.
    //
    // Beides läuft ABSEITS des Hauptfadens: Es sind zweihundert Abfragen an
    // das Dateisystem, und über iCloud kann jede davon warten. Zurück auf
    // den Hauptfaden kommt nur die Zahl.
    //
    // Ein laufender Auftrag wird abgebrochen, bevor ein neuer beginnt —
    // sonst liefen beim schnellen Blättern mehrere Läufe übereinander und
    // der letzte, der fertig wird, setzte den Stand, nicht der jüngste.
    func bilderPruefen(anstossen: Bool = true) {
        let kennung = reise.id
        let namen = Wolkenbilder.dateien(reise)
        bilderauftrag?.cancel()
        bilderauftrag = Task { [weak self] in
            var nochAnstossen = anstossen
            // Nachgesehen wird, SOLANGE etwas lädt, und dann hört es auf.
            // Ein Band, dessen Zahl nicht kleiner wird, sieht aus wie ein
            // Fehler; ein Lauf, der ewig weiterzählt, ist einer. Ein Bild,
            // das wirklich fort ist (`fehlt`), kommt von keinem weiteren
            // Nachsehen zurück — dann bleibt das Band stehen und die
            // Schleife endet.
            while !Task.isCancelled {
                let holen = nochAnstossen
                let stand = await Task.detached(priority: .utility) { () -> Wolkenbilder.Stand in
                    if holen {
                        Wolkenbilder.anstossen(reise: kennung, dateien: namen)
                    }
                    return Wolkenbilder.nachsehen(reise: kennung, dateien: namen)
                }.value
                guard !Task.isCancelled, let self else { return }
                self.bildstand = stand
                guard stand.laedt > 0 else { return }
                nochAnstossen = false
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    // Der Knopf im Band. Er räumt zusätzlich die gemerkten Fehlgriffe weg:
    // Wer ausdrücklich tippt, wartet keine drei Sekunden auf das nächste
    // Nachsehen.
    func bilderJetztHolen() {
        Bildarchiv.shared.nachsehen()
        bilderPruefen(anstossen: true)
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

    // WER ENTSCHEIDET, OB HANDARBEIT STEHEN BLEIBT, IST DER NUTZER (ab 1.0.32).
    //
    // Bis 1.0.31 wurden von Hand bearbeitete Tage beim Stilwechsel IMMER
    // verschont. Die Vorsicht ist richtig — eine Automatik, die eine Stunde
    // Handarbeit ohne Rückfrage überschreibt, benutzt man genau einmal.
    // Falsch war, daraus eine Regel zu machen: Wer den Stil wechselt, will
    // das ganze Buch anders haben, und dann stehen ein paar Seiten im alten
    // Satz mitten darin (Ansage des Nutzers, 09/2026: „Ich möchte das frei
    // entscheiden können."). Gefragt wird weiterhin, nur ist die Antwort
    // jetzt eine echte Wahl und keine Ansage.
    func stilAnwenden(_ stil: Buchstil, auchHandarbeit: Bool = false) {
        merken()
        reise.stilAnwenden(stil)
        // Ein Stil ändert Ränder, Fugen und Schriftgrößen — also alles, was
        // die Seiten bestimmt. Sie nicht neu zu setzen hieße, den Stil zu
        // wählen und ihn nicht zu sehen.
        alleNeuAnordnen(nurUnberuehrte: !auchHandarbeit)
    }

    // Wie viele Tage von Hand bearbeitet sind. Die Stilauswahl nennt die
    // Zahl in ihrer Rückfrage: „an einigen Tagen" lässt einen raten, ob
    // es um einen geht oder um zwanzig.
    //
    // Gerechnet wird über alle Tage und alle Seiten — das gehört nicht in
    // den Körper einer Ansicht, sondern an den Tipp, der die Frage
    // auslöst (dieselbe Falle wie bei der Druckprüfung in 1.0.0).
    func handarbeitstage() -> Int {
        reise.tage.filter { tag in tag.seiten.contains(where: \.vonHand) }.count
    }

    // Gibt zurück, ob an diesem Tag von Hand gearbeitet wurde. Die Ansicht
    // fragt damit nach, BEVOR sie eine Stunde Arbeit überschreibt.
    func hatHandarbeit(_ id: UUID) -> Bool {
        guard let stelle = tagIndex(id) else { return false }
        return reise.tage[stelle].seiten.contains { $0.vonHand }
    }

    // SEITEN NEU SETZEN \u{2014} und dabei die Karteneinstellung retten.
    //
    // Der Layoutautomat baut den Kartenblock frisch; was an ihm eingestellt
    // war (`Block.kartenbild`, `.kartenausschnitt`, ab 1.0.51), kennt er
    // nicht. Ohne diese eine Stelle wäre eine eigene Karteneinstellung nach
    // jedem Neuanordnen weg, und zwar STILL \u{2014} die Seite steht ja
    // danach da. Dasselbe Muster wie `wortlautSichern` seit 1.0.38, nur
    // zusammengezogen: Es gibt genau EINEN Weg, der Seiten setzt, und wer
    // einen zweiten baut, ruft diesen hier.
    //
    // Gerettet wird die Einstellung der ERSTEN Karte des Tages, die eine
    // trägt, und sie gilt danach für jede Karte des Tages. Mehrere Karten
    // mit verschiedenen Einstellungen gibt es nur über eine Kopie, und die
    // ist nach dem Neusetzen ohnehin weg.
    //
    // Seit 1.0.54 hängt dasselbe an der Wasserzeichen-Korrektur. Sie wird
    // nach der STELLE im Tag übernommen und nicht nach der Kennung: Die
    // neuen Seiten haben neue Kennungen, und damit zieht die Automatik
    // ohnehin einen anderen Winkel und sucht eine andere Stelle. Die
    // Korrektur bleibt also am PLATZ im Tag hängen und nicht am Inhalt —
    // das ist eine Entscheidung und keine Messung, und die Oberfläche sagt
    // sie auch.
    private func seitenNeuSetzen(_ stelle: Int, mit werkzeug: Layoutautomat) {
        var bild: Kartenbild?
        var ausschnitt: Kartenausschnitt?
        for seite in reise.tage[stelle].seiten {
            for block in seite.bloecke where block.inhalt == .karte {
                if bild == nil { bild = block.kartenbild }
                if ausschnitt == nil { ausschnitt = block.kartenausschnitt }
            }
        }
        let zeichen = reise.tage[stelle].seiten.map(\.wasserzeichen)
        reise.tage[stelle].seiten = werkzeug.seiten(fuer: reise.tage[stelle])
        for nummer in reise.tage[stelle].seiten.indices where zeichen.indices.contains(nummer) {
            reise.tage[stelle].seiten[nummer].wasserzeichen = zeichen[nummer]
        }
        guard bild != nil || ausschnitt != nil else { return }
        for nummer in reise.tage[stelle].seiten.indices {
            for b in reise.tage[stelle].seiten[nummer].bloecke.indices
            where reise.tage[stelle].seiten[nummer].bloecke[b].inhalt == .karte {
                reise.tage[stelle].seiten[nummer].bloecke[b].kartenbild = bild
                reise.tage[stelle].seiten[nummer].bloecke[b].kartenausschnitt = ausschnitt
            }
        }
    }

    func neuAnordnen(_ id: UUID, erzwingen: Bool) {
        guard let stelle = tagIndex(id) else { return }
        if !erzwingen, hatHandarbeit(id) { return }
        merken()
        wortlautSichern(stelle)
        seitenNeuSetzen(stelle, mit: automat)
        seitenzeiger = 0
    }

    func alleNeuAnordnen(nurUnberuehrte: Bool) {
        merken()
        let werkzeug = automat
        for stelle in reise.tage.indices {
            if nurUnberuehrte, reise.tage[stelle].seiten.contains(where: { $0.vonHand }) { continue }
            wortlautSichern(stelle)
            seitenNeuSetzen(stelle, mit: werkzeug)
        }
        befundeAuffrischen()
    }

    // EIN TAGEBUCH DARF KEINEN SATZ VERLIEREN — auch nicht beim Neusetzen
    // (ab 1.0.38).
    //
    // `textSchreiben` legt einen auf der SEITE bearbeiteten Fließtext in den
    // Block und nicht an den Tag; `Layoutautomat.seiten(fuer:)` setzt aber
    // aus `tag.text`. Wer also einen Tag mit bearbeitetem Text neu anordnen
    // ließ, verlor seinen Wortlaut — still, denn die Seite steht ja danach
    // da. Das gab es schon vor dieser Fassung; „Alle unberührten Tage" war
    // nur deshalb ungefährlich, weil es solche Tage übersprang.
    //
    // Gerettet wird VOR dem Setzen: Weicht der Wortlaut auf den Seiten vom
    // Tagebuchtext ab, ist er der neuere Stand und wandert an den Tag
    // zurück. Wo die Stücke unverändert im Tagebuchtext stehen, wird dort
    // nachgesehen, was zwischen ihnen lag; nur an einer bearbeiteten Naht
    // wird geraten (siehe `Neuverteilung.zusammenfuegen`).
    //
    // **Der Aufruf gehört an JEDE Stelle, die Seiten neu setzt.** Wer einen
    // neuen Weg dorthin baut und ihn vergisst, baut denselben stillen
    // Verlust wieder ein.
    @discardableResult
    func wortlautSichern(_ stelle: Int) -> Bool {
        guard reise.tage.indices.contains(stelle) else { return false }
        let tag = reise.tage[stelle]
        let stuecke = Neuverteilung.fliesstexte(tag)
        guard !stuecke.isEmpty else { return false }
        let original = tag.text.trimmingCharacters(in: .whitespacesAndNewlines)
        var geraten = 0
        let zusammen = Neuverteilung.zusammenfuegen(stuecke, original: original,
                                                    geraten: &geraten)
        guard Neuverteilung.vergleichsform(zusammen)
            != Neuverteilung.vergleichsform(original) else { return false }
        reise.tage[stelle].text = zusammen
        return true
    }

    // ALLES NEU VERTEILEN LASSEN (ab 1.0.38).
    //
    // Frage des Nutzers, 09/2026: „Vielleicht wäre eine Funktion sinnvoll,
    // das Ganze einmal so weit zurückzusetzen, dass der Bild- und
    // Textverteiler in Aktion treten kann."
    //
    // Das ist mehr als `alleNeuAnordnen`: Dort bleibt jeder Tag mit
    // Handarbeit stehen, und Handarbeit ist schon ein verschobener Block.
    // Wer eine neue Fassung der Satzmaschine auf ein fertiges Buch anwenden
    // will, kommt damit nicht weiter — für jeden angefassten Tag müsste er
    // einzeln ins Tagesmenü.
    //
    // Was dabei WEGFÄLLT, steht in der Vorschau und nicht erst hinterher in
    // einer Meldung: Lage, Größe, Drehung und Abweichungen der Blöcke, von
    // Hand angelegte oder entfernte Seiten. Was BLEIBT: der Tagebuchtext,
    // die Überschrift, die Datumszeile, die Bildunterschriften (die stehen
    // am Tag bzw. am Foto), die Fotos selbst und die Reisepunkte.
    @discardableResult
    func neuVerteilen(nurUnberuehrte: Bool) -> String {
        merken()
        let werkzeug = automat
        var gesetzt = 0
        var verschont = 0
        var gerettet = 0
        for stelle in reise.tage.indices {
            if nurUnberuehrte, reise.tage[stelle].seiten.contains(where: { $0.vonHand }) {
                verschont += 1
                continue
            }
            if wortlautSichern(stelle) { gerettet += 1 }
            seitenNeuSetzen(stelle, mit: werkzeug)
            gesetzt += 1
        }
        sofortSichern()
        var satz = "\(gesetzt) Tage neu verteilt."
        if verschont > 0 {
            satz += " \(verschont) Tage tragen Handarbeit und blieben stehen."
        }
        if gerettet > 0 {
            satz += " Bei \(gerettet) Tagen wurde der auf der Seite geänderte Wortlaut "
                + "in den Tagebuchtext übernommen."
        }
        meldung = .init(text: satz)
        return satz
    }

    // WELCHES Muster für diesen Tag gerade gilt, wenn keines gesetzt ist.
    //
    // Gebraucht wird es für die Anzeige im Tagesmenü: Ein Menüpunkt, der
    // „automatisch" sagt und nicht dazu, WAS der Automat gewählt hat,
    // lässt einen raten — und genau daran ist die Frage entstanden, ob es
    // das Muster „Text und Bilder im Wechsel" überhaupt gibt.
    func gewaehltesMuster(_ id: UUID) -> Seitenmuster? {
        guard let stelle = tagIndex(id) else { return nil }
        let tag = reise.tage[stelle]
        if let eigenes = tag.muster { return eigenes }
        let fotos = tag.fotos.compactMap { reise.foto($0) }.filter { !$0.abgelegt }
        return automat.musterVorschlag(text: tag.text, fotos: fotos,
                                       hatSpur: tag.karteZeigen && tag.hatSpur)
    }

    // Dasselbe Muster für JEDEN Tag — oder überall zurück auf
    // „automatisch".
    //
    // Der Weg dorthin steht dort, wo die Frage entsteht: im Menü des
    // einzelnen Tages. Wer für einen Tag einstellt, wie seine Seiten
    // gesetzt werden, ist genau die Person, die als Nächstes fragt „und
    // für alle?" — dieselbe Lehre wie beim Fotostil in 1.0.10.
    //
    // Neu angeordnet werden dabei NUR die Tage ohne Handarbeit. Ein Muster
    // zu wechseln und dabei eine Stunde Handarbeit stillschweigend
    // wegzuräumen wäre genau die Automatik, die man genau einmal benutzt.
    @discardableResult
    func musterFuerAlle(_ muster: Seitenmuster?) -> String {
        merken()
        for stelle in reise.tage.indices { reise.tage[stelle].muster = muster }
        var gesetzt = 0
        var verschont = 0
        let werkzeug = automat
        for stelle in reise.tage.indices {
            if reise.tage[stelle].seiten.contains(where: { $0.vonHand }) {
                verschont += 1
                continue
            }
            wortlautSichern(stelle)
            seitenNeuSetzen(stelle, mit: werkzeug)
            gesetzt += 1
        }
        sofortSichern()
        let name = muster?.name ?? "Automatisch wählen"
        var satz = "\(name): \(gesetzt) Tage neu gesetzt."
        if verschont > 0 {
            satz += " \(verschont) Tage tragen Handarbeit und blieben stehen — "
                + "sie lassen sich einzeln über „Seiten neu anordnen\u{201C} nachziehen."
        }
        meldung = .init(text: satz)
        return satz
    }

    // DAS MUSTER EINES EINZELNEN TAGES — an EINER Stelle (ab 1.0.38).
    //
    // Bis 1.0.37 stand dieselbe Folge zweimal in ANSICHTEN: im Picker von
    // `TagInhaltView` und in `ReiseView.musterSetzen`. Beide riefen den
    // Automaten unmittelbar — und keine der beiden wusste vom Wortlaut in
    // den Blöcken, also verloren beide den auf der Seite geschriebenen Text.
    // Genau der Fall, vor dem der Kommentar an `wortlautSichern` warnt, und
    // er stand schon da, bevor der Kommentar geschrieben war.
    //
    // **Eine Ansicht setzt keine Seiten.** Sie sagt, was gewollt ist; wie
    // daraus Seiten werden, weiß das Werk.
    func musterSetzen(_ id: UUID, muster: Seitenmuster?) {
        guard let stelle = tagIndex(id) else { return }
        merken()
        reise.tage[stelle].muster = muster
        wortlautSichern(stelle)
        seitenNeuSetzen(stelle, mit: automat)
    }

    // Seiten, die noch gar nicht gesetzt sind, werden beim Öffnen gesetzt.
    // Das ist kein Neuanordnen: Eine leere Seitenliste ist kein Stand, den
    // jemand gewollt haben könnte.
    func fehlendeSeitenNachholen() {
        let werkzeug = automat
        for stelle in reise.tage.indices where reise.tage[stelle].seiten.isEmpty {
            seitenNeuSetzen(stelle, mit: werkzeug)
        }
        zeilenAnsBildLegen()
    }

    // JEDE UNTERSCHRIFT LIEGT AN IHREM BILD (ab 1.0.90, seit 1.0.92 auch
    // mit dem richtigen ABSTAND).
    //
    // Ansage des Nutzers, 09/2026, an einer Zeile, die waagerecht unter
    // einem schief stehenden Bild hing: „Ich hätte es gerne so, dass die
    // Schrift sich automatisch mit dem Bild mitdreht und am unteren Rand zu
    // sehen ist."
    //
    // Mitgedreht wird seit 1.0.86 — an den Stellen, die eine Zeile ANLEGEN,
    // und beim Drehen von Hand. Was dabei nicht abgedeckt war: eine Seite,
    // die vor 1.0.86 gesetzt wurde, und der Aufmacher in `bildZuerst`, der
    // `angelegt` bis 1.0.89 nicht fragte. **Merke: Wer eine Regel an den
    // Entstehungsstellen einbaut, erreicht damit keinen einzigen Block, der
    // schon auf der Platte liegt.**
    //
    // Angelegt wird deshalb beim Öffnen, und zwar nur, was NICHT von Hand
    // angefasst wurde: `vonHand` schützt jede Zeile, die jemand selbst
    // gesetzt, gedreht oder mit ihrem Bild verschoben hat (beides setzt es
    // seit 1.0.86). Gerechnet wird dieselbe Lage, die der Automat rechnet —
    // eine zweite Fassung ergäbe eine Seite, die nach dem Öffnen anders
    // aussieht als nach dem Neuanordnen.
    //
    // Geschrieben wird nur, wo sich wirklich etwas ändert: `reise` sichert
    // über sein `didSet`, und ohne Zuweisung gibt es keine. Ein
    // Sicherungslauf bei jedem Öffnen wäre ein geänderter Zeitstempel für
    // nichts — und beim Abgleich ein Buch, das sich ohne Zutun als neuer
    // ausgibt.
    @discardableResult
    func zeilenAnsBildLegen() -> Int {
        var gerichtet = 0
        for t in reise.tage.indices {
            for s in reise.tage[t].seiten.indices {
                let bloecke = reise.tage[t].seiten[s].bloecke
                for (stelle, zeile) in bloecke.enumerated() where !zeile.vonHand {
                    let bildart: Blockinhalt
                    switch zeile.inhalt {
                    case let .bildunterschrift(id): bildart = .foto(id)
                    case .kartenunterschrift: bildart = .karte
                    default: continue
                    }
                    guard let bild = bloecke.first(where: { $0.inhalt == bildart })
                    else { continue }
                    // AUCH DER ABSTAND WIRD GERICHTET (ab 1.0.92).
                    //
                    // Bis 1.0.91 stand hier: „Der Abstand bleibt, wie er
                    // ist" — und ein `guard` auf die Drehung davor. Bei
                    // einem GERADE stehenden Bild lief diese Schleife
                    // damit leer durch, und eine Seite aus einem Stand vor
                    // 1.0.86 behielt ihre Zeile drei Punkte unter dem
                    // RAHMEN, also mitten im weißen Rand. Genau das wurde
                    // 09/2026 gemeldet („soll nicht halb noch im weißen
                    // Rahmen des Bildes stehen").
                    //
                    // **Zweite Auflage derselben Lehre wie 1.0.90:** Wer
                    // eine Regel an den Entstehungsstellen einbaut,
                    // erreicht keinen Block, der schon dasteht — damals
                    // wurde sie für die Neigung gezogen und für den
                    // Abstand nicht.
                    let fuge = reise.gestaltung.unterschriftfugePt(
                        fotorand: bild.wirkung(reise.gestaltung).fotorand)
                    // Die Soll-Lage im UNGEDREHTEN System: unter dem Bild,
                    // so breit wie es, um die Fuge darunter. Danach um die
                    // Mitte des Bildes in dessen Winkel gedreht — dieselbe
                    // Rechnung wie in `Layoutautomat.angelegt`.
                    let soll = Rahmen(x: bild.rahmen.x,
                                      y: bild.rahmen.y + bild.rahmen.hoehe + fuge,
                                      breite: bild.rahmen.breite,
                                      hoehe: zeile.rahmen.hoehe)
                    let ziel = abs(bild.drehung) > 0.01
                        ? soll.gedreht(um: bild.rahmen.mitte, grad: bild.drehung)
                        : soll
                    // Geschrieben wird nur, wo sich wirklich etwas ändert:
                    // `reise` sichert über sein `didSet`, und ein
                    // Sicherungslauf bei jedem Öffnen wäre beim Abgleich
                    // ein Buch, das sich ohne Zutun als neuer ausgibt.
                    let sitzt = abs(ziel.x - zeile.rahmen.x) < 0.5
                        && abs(ziel.y - zeile.rahmen.y) < 0.5
                        && abs(ziel.breite - zeile.rahmen.breite) < 0.5
                        && abs(zeile.drehung - bild.drehung) < 0.01
                        && zeile.ebene == bild.ebene
                    guard !sitzt else { continue }
                    reise.tage[t].seiten[s].bloecke[stelle].rahmen = ziel
                    reise.tage[t].seiten[s].bloecke[stelle].drehung = bild.drehung
                    reise.tage[t].seiten[s].bloecke[stelle].ebene = bild.ebene
                    gerichtet += 1
                }
            }
        }
        return gerichtet
    }

    // MARK: - Befunde auf der Seite (ab 1.0.93)

    /// Neu sammeln — nur, wenn die Marken gezeigt werden. Gerufen von
    /// jedem Griff, der einen Block ändern kann; ist der Schalter aus,
    /// kehrt es sofort um und kostet nichts.
    func befundeAuffrischen(erzwingen: Bool = false) {
        guard zeigeBefunde || erzwingen else { return }
        let neu = Befundstellen.alle(reise)
        // Zugewiesen wird nur bei echter Änderung: Ein `@Published`, das
        // denselben Wert noch einmal bekommt, zeichnet die Bühne trotzdem
        // neu (die Lehre aus der Abfahrtstafel 1.1.16).
        guard neu != befundstellen else { return }
        befundstellen = neu
        if befundzeiger >= neu.count { befundzeiger = 0 }
    }

    /// Die Marken einschalten und zur ersten Stelle springen. Gerufen von
    /// der Druckprüfung („Im Buch zeigen") — sie schließt sich danach
    /// selbst, sonst läge das Blatt über dem, was es zeigen will.
    func befundeZeigen(_ stellen: [Befundstelle]) {
        // Das `didSet` von `zeigeBefunde` frischt selbst auf — aber nur,
        // wenn sich der Schalter WIRKLICH ändert. War er schon an, muss es
        // hier geschehen; zweimal wäre ein voller Lauf über das Buch für
        // nichts.
        let warAn = zeigeBefunde
        zeigeBefunde = true
        if warAn { befundeAuffrischen(erzwingen: true) }
        guard let erste = stellen.first else { return }
        befundzeiger = befundstellen.firstIndex(where: { $0.block == erste.block }) ?? 0
        springeZu(befundstellen.indices.contains(befundzeiger)
            ? befundstellen[befundzeiger] : erste)
    }

    /// Einen weiter — und am Ende wieder von vorn. Ein Knopf, der beim
    /// letzten Befund nichts mehr tut, sieht kaputt aus.
    func naechsterBefund() {
        guard !befundstellen.isEmpty else { return }
        befundzeiger = (befundzeiger + 1) % befundstellen.count
        springeZu(befundstellen[befundzeiger])
    }

    private func springeZu(_ stelle: Befundstelle) {
        // Die eigenen Felder auf dem Umschlag tragen keine Seite, auf die
        // sich springen ließe — sie werden erst in `seitenfolge` an die
        // gerechnete Seite gehängt. Gezählt werden sie trotzdem; gesagt
        // wird es in der Prüfung.
        let gibtEs = reise.tage.contains { tag in
            tag.seiten.contains { seite in seite.id == stelle.seite }
        }
        guard gibtEs else { return }
        gewaehlteSeite = stelle.seite
        sprungZuSeite = stelle.seite
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

    // EIN BLOCK LIEGT ENTWEDER IM BUCHBLOCK ODER AUF DEM UMSCHLAG
    // (ab 1.0.64).
    //
    // `block(_:)` sucht in `reise.tage` und findet einen Umschlagblock
    // deshalb nie — und das ist richtig so: Wer einen TAG braucht (den
    // Text teilen, auf eine andere Seite schieben, kopieren), kann mit
    // einem Umschlagblock nichts anfangen, und diese Knöpfe erscheinen
    // dort von selbst nicht. Alles, was nur den Block selbst betrifft,
    // geht seit 1.0.64 durch die beiden Stellen hier.
    enum Umschlagflaeche: Hashable {
        case titel
        case rueckseite
    }

    /// Zu welcher Umschlagseite diese Seitenkennung gehört — `nil` heißt:
    /// eine gewöhnliche Seite (oder gar keine).
    func umschlagflaeche(_ seiteID: UUID) -> Umschlagflaeche? {
        if seiteID == Layoutautomat.titelseitenKennung { return .titel }
        if seiteID == Layoutautomat.rueckseitenKennung { return .rueckseite }
        return nil
    }

    func umschlagblock(_ id: UUID) -> (flaeche: Umschlagflaeche, stelle: Int)? {
        if let stelle = reise.umschlag.titelbloecke.firstIndex(where: { $0.id == id }) {
            return (.titel, stelle)
        }
        if let stelle = reise.umschlag.rueckbloecke.firstIndex(where: { $0.id == id }) {
            return (.rueckseite, stelle)
        }
        return nil
    }

    /// Ob sich dieser Block überhaupt ANFASSEN lässt.
    ///
    /// Auf Titel- und Rückseite liegen zweierlei Blöcke nebeneinander: die
    /// GERECHNETEN (Titel, Zeitraum, Titelfoto) und die eigenen Felder.
    /// Nur die zweiten lassen sich schieben, ziehen und löschen — die
    /// ersten entstehen bei jedem Durchgang neu. Ein gerechneter Block,
    /// der sich auswählen ließe und dann auf keine Geste reagiert, wäre
    /// für den Menschen davor ein kaputter Knopf; die Seitenfläche geht
    /// deshalb beim Tippen an ihm vorbei.
    func anfassbar(_ id: UUID) -> Bool {
        umschlagblock(id) != nil || block(id) != nil
    }

    /// Ein Block, wo immer er liegt. Gebraucht von allem, was ihn nur
    /// LESEN will — der Inspektor, die Werkzeugleiste, die Überlaufmarke.
    func blockWert(_ id: UUID) -> Block? {
        if let stelle = umschlagblock(id) { return umschlagbloecke(stelle.flaeche)[stelle.stelle] }
        guard let stelle = block(id) else { return nil }
        return reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block]
    }

    func umschlagbloecke(_ flaeche: Umschlagflaeche) -> [Block] {
        switch flaeche {
        case .titel: return reise.umschlag.titelbloecke
        case .rueckseite: return reise.umschlag.rueckbloecke
        }
    }

    private func setzeUmschlagbloecke(_ flaeche: Umschlagflaeche, _ bloecke: [Block]) {
        switch flaeche {
        case .titel: reise.umschlag.titelbloecke = bloecke
        case .rueckseite: reise.umschlag.rueckbloecke = bloecke
        }
    }

    private func amUmschlagblock(_ stelle: (flaeche: Umschlagflaeche, stelle: Int),
                                 _ arbeit: (inout Block) -> Void)
    {
        var bloecke = umschlagbloecke(stelle.flaeche)
        guard bloecke.indices.contains(stelle.stelle) else { return }
        arbeit(&bloecke[stelle.stelle])
        setzeUmschlagbloecke(stelle.flaeche, bloecke)
    }

    func aendere(_ id: UUID, merken merkt: Bool = true, _ arbeit: (inout Block) -> Void) {
        if let stelle = umschlagblock(id) {
            if merkt { merken() }
            amUmschlagblock(stelle) { block in
                arbeit(&block)
                block.vonHand = true
            }
            return
        }
        guard let stelle = block(id) else { return }
        if merkt { merken() }
        arbeit(&reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block])
        reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block].vonHand = true
    }

    // DIE BILDUNTERSCHRIFT GEHÖRT ZUM BILD — SIE GEHT MIT (ab 1.0.86).
    //
    // Gemeldet 09/2026: „Ich habe jetzt erstmalig eine Bildunterschrift
    // einfügen wollen und habe festgestellt, dass sie sich bei Drehung des
    // Bildes nicht mitdreht. Im vorliegenden Fall ist es so, dass sie sogar
    // zum großen Teil vom Bild verdeckt ist."
    //
    // **Beide Hälften haben dieselbe Ursache.** Die Unterschrift ist seit
    // 1.0.5 ein eigener Block; sie steht unter dem RAHMEN des Fotos, und
    // ein gedrehtes Bild ragt mit seiner Ecke weit darüber hinaus (die
    // Rechnung dazu steht an `Block.umriss` seit 1.0.83: ein Grad auf
    // 300 Punkt Breite sind gut zweieinhalb Punkt, bei zehn Grad ein
    // Vielfaches davon). Sie wird also nicht nur schief, sondern
    // verschwindet darunter.
    //
    // Im Quelltext stand bis 1.0.85 der Satz, sie drehe bewusst NICHT mit:
    // „Mitgedreht würde sie um ihre EIGENE Mitte gedreht und rückte damit
    // vom Bild ab." Das stimmt — für eine Drehung, die nur den WINKEL
    // setzt. Es stimmt nicht mehr, sobald auch die LAGE mitgedreht wird,
    // und genau das tut `Rahmen.gedreht(um:grad:)`. **Merke: Eine
    // Begründung, die gegen einen Weg spricht, trifft oft nur seine
    // einfachste Form.**
    //
    // Gedreht wird um die Mitte des FOTOS und um die DIFFERENZ zum
    // bisherigen Winkel: Der Griff setzt ihn absolut, und die gespeicherte
    // Lage der Unterschrift trägt die vorherige Drehung schon in sich.
    func drehe(_ id: UUID, auf grad: Double, merken merkt: Bool = false) {
        if umschlagblock(id) != nil {
            // Auf dem Umschlag gibt es keine Bildunterschriften: Die
            // gehören einem Foto eines Tages.
            aendere(id, merken: merkt) { $0.drehung = grad }
            return
        }
        guard let stelle = block(id) else { return }
        if merkt { merken() }
        var bloecke = reise.tage[stelle.tag].seiten[stelle.seite].bloecke
        let delta = grad - bloecke[stelle.block].drehung
        bloecke[stelle.block].drehung = grad
        bloecke[stelle.block].vonHand = true
        if let u = unterschriftZu(bloecke[stelle.block], in: bloecke) {
            let mitte = bloecke[stelle.block].rahmen.mitte
            bloecke[u].rahmen = bloecke[u].rahmen.gedreht(um: mitte, grad: delta)
            bloecke[u].drehung += delta
            bloecke[u].vonHand = true
        }
        reise.tage[stelle.tag].seiten[stelle.seite].bloecke = bloecke
    }

    // Dasselbe für das Verschieben: Was am Bild hängt, hängt auch am
    // Schieben daran. Wer die Unterschrift woanders haben will, fasst SIE
    // an — dann bleibt die neue Lage erhalten, denn bewegt wird immer nur
    // die Differenz.
    //
    // Die GRÖSSENÄNDERUNG nimmt sie bewusst nicht mit: Dort ist es keine
    // starre Bewegung — die Zeile müsste neu umbrechen und ihre Höhe neu
    // messen. Sie liegt danach sichtbar neben dem Bild und ist in einem
    // Griff nachgezogen; eine gedrehte Zeile unter dem Bild war gar nicht
    // mehr zu greifen, und das ist der Unterschied.
    func schiebeMitUnterschrift(_ id: UUID, auf neu: Rahmen, merken merkt: Bool = false) {
        if umschlagblock(id) != nil {
            aendere(id, merken: merkt) { $0.rahmen = neu }
            return
        }
        guard let stelle = block(id) else { return }
        if merkt { merken() }
        var bloecke = reise.tage[stelle.tag].seiten[stelle.seite].bloecke
        let alt = bloecke[stelle.block].rahmen
        bloecke[stelle.block].rahmen = neu
        bloecke[stelle.block].vonHand = true
        if let u = unterschriftZu(bloecke[stelle.block], in: bloecke) {
            // NICHT auf die Seite geklemmt: Starr ist starr. Schiebt jemand
            // das Bild an den Rand, soll die Unterschrift ihren Abstand
            // behalten — was dabei über die Kante gerät, meldet die rote
            // Marke, und das ist die ehrlichere Auskunft als eine Zeile,
            // die sich still an das Bild heranschiebt.
            bloecke[u].rahmen = bloecke[u].rahmen.verschoben(dx: neu.x - alt.x,
                                                             dy: neu.y - alt.y)
            bloecke[u].vonHand = true
        }
        reise.tage[stelle.tag].seiten[stelle.seite].bloecke = bloecke
    }

    /// Die Unterschrift zu einem Fotoblock — in DERSELBEN Seite.
    ///
    /// Seit `blockKopieren` (1.0.39) darf dasselbe Foto zweimal im Buch
    /// stehen; über das ganze Buch gesucht bewegte ein Griff die Zeile der
    /// anderen Kopie mit.
    private func unterschriftZu(_ block: Block, in bloecke: [Block]) -> Int? {
        guard let fotoID = block.fotoID else { return nil }
        return bloecke.firstIndex { $0.inhalt == .bildunterschrift(fotoID) }
    }

    // EINE KARTENEINSTELLUNG IST KEINE HANDARBEIT AM SATZ (ab 1.0.51).
    //
    // `aendere` setzt `vonHand` — richtig, wo jemand einen Block schiebt,
    // dreht oder in der Größe zieht: Das Neuanordnen soll ihn danach in
    // Ruhe lassen. Wer aber die Reisepunkte DIESER einen Karte umstellt,
    // hat an der Anordnung nichts getan; der Tag fiele sonst für immer aus
    // dem automatischen Neuanordnen heraus, und zwar wegen einer Farbe.
    // Die Einstellung selbst übersteht das Neusetzen ohnehin — dafür gibt
    // es `seitenNeuSetzen`.
    func karteAendern(_ id: UUID, merken merkt: Bool = true, _ arbeit: (inout Block) -> Void) {
        guard let stelle = block(id) else { return }
        if merkt { merken() }
        arbeit(&reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block])
    }

    // Beim Schieben wird NICHT bei jedem Bildpunkt ein Zwischenstand
    // gemerkt — sonst wäre der Rückgängig-Stapel nach einer Fingerbewegung
    // voll und der Zustand davor nicht mehr erreichbar.
    func schiebe(_ id: UUID, dx: Double, dy: Double, merken merkt: Bool) {
        // Auch ein Umschlagblock wird auf das SEITENformat geklemmt: Jede
        // Hälfte des Umschlagbogens ist genau ein Endformat breit.
        if let stelle = umschlagblock(id) {
            if merkt { merken() }
            amUmschlagblock(stelle) { block in
                block.rahmen = block.rahmen.verschoben(dx: dx, dy: dy)
                    .begrenzt(auf: reise.format.groesse)
                block.vonHand = true
            }
            return
        }
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
                // UNTER DEM WEISSEN RAND, nicht darin (ab 1.0.86): Der
                // liegt außerhalb des Rahmens und deckte die Zeile sonst zu.
                let fuge = Druckmass.pt(fotoblock.wirkung(reise.gestaltung).fotorand) + 3
                var neu = Block(
                    inhalt: .bildunterschrift(fotoID),
                    rahmen: Rahmen(x: fotoblock.rahmen.x,
                                   y: fotoblock.rahmen.y + fotoblock.rahmen.hoehe + fuge,
                                   breite: fotoblock.rahmen.breite, hoehe: hoehe)
                )
                // Und mit derselben Neigung wie ihr Bild, um dessen Mitte
                // gedreht — sonst stünde sie schief darunter und bei
                // stärkerer Drehung halb dahinter.
                neu.ebene = fotoblock.ebene
                if abs(fotoblock.drehung) > 0.01 {
                    neu.rahmen = neu.rahmen.gedreht(um: fotoblock.rahmen.mitte,
                                                    grad: fotoblock.drehung)
                    neu.drehung = fotoblock.drehung
                }
                reise.tage[t].seiten[s].bloecke.insert(neu, at: stelle + 1)
            }
        }
    }

    // DIE KARTE IST AUCH NUR EIN BILD (ab 1.0.87).
    //
    // Wunsch des Nutzers, 09/2026: „Nicht nur Bilder sollen eine
    // Bildunterschrift tragen können, sondern auch die
    // Kartendarstellungen." Gebaut wie beim Foto und mit denselben zwei
    // Regeln: Der Schalter wirkt SOFORT, und der Text steht nicht im Block
    // (hier am Tag, denn eine Karte wechselt ihn nie).
    //
    // Die Karte wird dabei um die Höhe der Zeile KÜRZER, statt zusätzlichen
    // Platz zu verlangen — dieselbe Rechnung wie im Automaten
    // (`karteBloecke`); eine zweite ergäbe eine Seite, die nach dem ersten
    // Neuanordnen anders aussieht.
    func kartenunterschriftUmschalten(_ tagID: UUID, an: Bool) {
        guard let t = reise.tage.firstIndex(where: { $0.id == tagID }) else { return }
        merken()
        reise.tage[t].kartentextZeigen = an
        let bild = reise.typografie.bildunterschrift
        let text = reise.tage[t].kartentext
        for s in reise.tage[t].seiten.indices {
            if !an {
                // Was die Karte hergegeben hat, bekommt sie zurück.
                let zeilen = reise.tage[t].seiten[s].bloecke
                    .filter { $0.inhalt == .kartenunterschrift }
                reise.tage[t].seiten[s].bloecke.removeAll { $0.inhalt == .kartenunterschrift }
                if let zeile = zeilen.first,
                   let k = reise.tage[t].seiten[s].bloecke
                       .firstIndex(where: { $0.inhalt == .karte })
                {
                    let unten = zeile.rahmen.y + zeile.rahmen.hoehe
                    reise.tage[t].seiten[s].bloecke[k].rahmen.hoehe =
                        unten - reise.tage[t].seiten[s].bloecke[k].rahmen.y
                }
                continue
            }
            guard !reise.tage[t].seiten[s].bloecke.contains(where: {
                $0.inhalt == .kartenunterschrift
            }), let k = reise.tage[t].seiten[s].bloecke
                .firstIndex(where: { $0.inhalt == .karte })
            else { continue }
            let karte = reise.tage[t].seiten[s].bloecke[k]
            let hoehe = Textmass.hoehe(text.isEmpty ? "Kartenunterschrift" : text,
                                       bild: bild, breite: karte.rahmen.breite)
            let fuge: Double = 3
            guard karte.rahmen.hoehe - hoehe - fuge >= 24 else { continue }
            reise.tage[t].seiten[s].bloecke[k].rahmen.hoehe -= hoehe + fuge
            let oben = reise.tage[t].seiten[s].bloecke[k].rahmen
            var neu = Block(
                inhalt: .kartenunterschrift,
                rahmen: Rahmen(x: oben.x, y: oben.y + oben.hoehe + fuge,
                               breite: oben.breite, hoehe: hoehe)
            )
            neu.ebene = karte.ebene
            if abs(karte.drehung) > 0.01 {
                neu.rahmen = neu.rahmen.gedreht(um: karte.rahmen.mitte, grad: karte.drehung)
                neu.drehung = karte.drehung
            }
            reise.tage[t].seiten[s].bloecke.insert(neu, at: k + 1)
        }
    }

    /// Welchem Tag ein Block gehört — gefragt von allem, was an einem
    /// Block hängt und den TAG braucht. Nie der gewählte Tag: Der folgt
    /// seit 1.0.28 dem, was oben im Bild steht (die Lehre aus 1.0.51).
    func tagZuBlock(_ id: UUID?) -> UUID? {
        guard let id, let stelle = block(id) else { return nil }
        return reise.tage[stelle.tag].id
    }

    /// Der kurze Weg von einer Karte zu ihrer Zeile — einschalten, wenn sie
    /// aus ist, und gleich zum Schreiben öffnen. Dieselbe Bauweise wie
    /// `unterschriftOeffnen` beim Foto.
    func kartenunterschriftOeffnen(_ tagID: UUID) {
        guard let tag = reise.tage.first(where: { $0.id == tagID }) else { return }
        if !tag.kartentextZeigen { kartenunterschriftUmschalten(tagID, an: true) }
        for seite in reise.tage.first(where: { $0.id == tagID })?.seiten ?? [] {
            guard let block = seite.bloecke.first(where: { $0.inhalt == .kartenunterschrift })
            else { continue }
            gewaehlterBlock = block.id
            textBearbeitung = block.id
            return
        }
    }

    // ALLE LEEREN BILDUNTERSCHRIFTEN AUF EINMAL ABSCHALTEN (ab 1.0.36).
    //
    // Sie entstehen durch einen Doppeltipp auf ein Foto und halten danach
    // eine leere Zeile unter dem Bild frei. Einzeln lassen sie sich schon
    // seit 1.0.5 abschalten — nur findet man sie nicht, wenn man nicht
    // weiß, wonach man sucht. `Druckpruefung.leereUnterschriften` sagt, wo
    // sie stehen, und hier steht der Weg, sie loszuwerden.
    //
    // Angefasst wird NUR, was wirklich leer ist: Eine Unterschrift, in der
    // ein Wort steht, ist Handarbeit und bleibt.
    @discardableResult
    func leereUnterschriftenAbschalten() -> Int {
        // Die roten Marken der Druckprüfung folgen dem, was hier
        // geschieht (ab 1.0.93). `defer`, weil diese Funktion mehr als
        // einen Rückweg hat — und die Auffrischung kehrt sofort um,
        // solange die Marken gar nicht gezeigt werden.
        defer { befundeAuffrischen() }
        let leere = reise.tage
            .flatMap(\.seiten)
            .flatMap(\.bloecke)
            .compactMap { block -> UUID? in
                guard case let .bildunterschrift(id) = block.inhalt,
                      let foto = reise.foto(id),
                      foto.unterschrift.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { return nil }
                return id
            }
        let kennungen = Set(leere)
        guard !kennungen.isEmpty else { return 0 }
        // EINMAL merken, nicht je Foto: `unterschriftUmschalten` legt bei
        // jedem Aufruf einen Stand auf den Rückgängig-Stapel, und der ist
        // flach (25 Stände). Zwanzig leere Unterschriften hätten ihn damit
        // geleert — und der Stand von davor wäre unerreichbar.
        merken()
        for id in kennungen {
            if var foto = reise.foto(id) {
                foto.unterschriftZeigen = false
                reise.setzeFoto(foto)
            }
        }
        for t in reise.tage.indices {
            for seite in reise.tage[t].seiten.indices {
                reise.tage[t].seiten[seite].bloecke.removeAll { block in
                    guard case let .bildunterschrift(id) = block.inhalt else { return false }
                    return kennungen.contains(id)
                }
            }
        }
        return kennungen.count
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
        // Die roten Marken der Druckprüfung folgen dem, was hier
        // geschieht (ab 1.0.93). `defer`, weil diese Funktion mehr als
        // einen Rückweg hat — und die Auffrischung kehrt sofort um,
        // solange die Marken gar nicht gezeigt werden.
        defer { befundeAuffrischen() }
        // Auf dem Umschlag gibt es nur eigene Textfelder: Titel,
        // Datumszeile und Bildunterschrift gehören einem Tag bzw. einem
        // Foto, und die kommen dort nicht vor. Der Text steht deshalb im
        // Block, und das ist die richtige Stelle — er gehört ja niemandem
        // sonst.
        if let stelle = umschlagblock(id) {
            merken()
            amUmschlagblock(stelle) { block in
                guard block.inhalt.istText else { return }
                block.inhalt = .text(text)
                block.vonHand = true
            }
            hoeheAnTextAnpassen(id, merken: false)
            return
        }
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
        case .kartenunterschrift:
            // Sie gehört dem TAG: Eine Karte zeigt dessen Spur (ab 1.0.87).
            reise.tage[stelle.tag].kartentext = text
            if !text.isEmpty { reise.tage[stelle.tag].kartentextZeigen = true }
        case .titel:
            reise.tage[stelle.tag].ueberschrift = text
        case .unterueberschrift:
            reise.tage[stelle.tag].unterueberschrift = text
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
    // Gerechnet wird in `Textpassung` — der einen Stelle, die auch die
    // Druckprüfung fragt (ab 1.0.94). Bis 1.0.93 stand dieselbe Rechnung
    // zweimal da, mit dem Kommentar „zwei Fassungen ergaben eine Seite, auf
    // der die Marke schweigt und die Prüfung anschlägt" — und sie standen
    // trotzdem getrennt.
    func fehlendeHoehe(_ block: Block, tag: Reisetag?) -> Double? {
        Textpassung.pruefe(block, tag: tag, reise: reise)?.noetig
    }

    // Den Rahmen so hoch machen, dass der Text hineinpasst. Nur WACHSEN:
    // Ein Kasten, der beim Tippen von selbst schrumpft, nähme eine Größe
    // weg, die jemand mit der Hand eingestellt hat.
    @discardableResult
    func hoeheAnTextAnpassen(_ id: UUID, merken merkt: Bool = true) -> Bool {
        if let stelle = umschlagblock(id) {
            let block = umschlagbloecke(stelle.flaeche)[stelle.stelle]
            guard let noetig = fehlendeHoehe(block, tag: nil) else { return false }
            if merkt { merken() }
            amUmschlagblock(stelle) { block in
                block.rahmen.hoehe = noetig
                block.vonHand = true
            }
            textUeberlauf = nil
            befundeAuffrischen()
            return true
        }
        guard let stelle = block(id) else { return false }
        let tag = reise.tage[stelle.tag]
        let block = tag.seiten[stelle.seite].bloecke[stelle.block]
        guard let noetig = fehlendeHoehe(block, tag: tag) else { return false }
        if merkt { merken() }
        reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block].rahmen.hoehe = noetig
        reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block].vonHand = true
        textUeberlauf = nil
        // Die rote Marke gehört weg, sobald der Kasten passt — sonst steht
        // sie über einem Befund, den es nicht mehr gibt (ab 1.0.93).
        befundeAuffrischen()
        return true
    }

    // MARK: - Einen Textkasten teilen

    // Nur der Tagebuchtext lässt sich teilen. Überschrift, Datumszeile und
    // Bildunterschrift stehen am Tag bzw. am Foto; von ihnen eine zweite
    // Hälfte anzulegen hieße, eine Kopie zu bauen, die beim nächsten
    // Neuanordnen auseinanderläuft.
    func teilbar(_ block: Block) -> Bool {
        // Ein Textfeld auf dem UMSCHLAG lässt sich nicht teilen: Die
        // Fortsetzung bräuchte eine nächste Seite, und der Umschlag hat
        // keine. Ein Knopf, der dort nichts tut, ist für den Menschen
        // davor ein kaputter Knopf — deshalb hier und nicht erst in der
        // Ansicht: Gefragt wird an zwei Stellen (Werkzeugleiste und
        // Blockmenü), und zwei Antworten liefen auseinander.
        guard umschlagblock(block.id) == nil else { return false }
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
        // Die roten Marken der Druckprüfung folgen dem, was hier
        // geschieht (ab 1.0.93). `defer`, weil diese Funktion mehr als
        // einen Rückweg hat — und die Auffrischung kehrt sofort um,
        // solange die Marken gar nicht gezeigt werden.
        defer { befundeAuffrischen() }
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
        // Der weiße Rand liegt AUSSERHALB des Rahmens und bestimmt damit,
        // wie weit die Bildunterschrift abrückt (ab 1.0.92). Wer ihn
        // zurücksetzt, verschiebt jede Zeile mit — ohne diese Zeile bliebe
        // sie stehen, wo sie zum alten Rand gehörte.
        zeilenAnsBildLegen()
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
        if let stelle = umschlagblock(id) {
            merken()
            var bloecke = umschlagbloecke(stelle.flaeche)
            bloecke.remove(at: stelle.stelle)
            setzeUmschlagbloecke(stelle.flaeche, bloecke)
            if gewaehlterBlock == id { gewaehlterBlock = nil }
            return
        }
        guard let stelle = block(id) else { return }
        merken()
        reise.tage[stelle.tag].seiten[stelle.seite].bloecke.remove(at: stelle.block)
        if gewaehlterBlock == id { gewaehlterBlock = nil }
    }

    // EINEN BLOCK AUF EINE ANDERE SEITE SCHIEBEN (ab 1.0.29, Ansage des
    // Nutzers 09/2026: „ich möchte ein Bild problemlos von einer Seite auf
    // eine andere schieben können beziehungsweise auch andere Elemente wie
    // zum Beispiel Textfelder.").
    //
    // Bewusst ein BEFEHL und keine Geste über die Seitengrenze. Eine
    // Ziehgeste, die ein Blatt verlässt, müsste mitten im Ziehen
    // entscheiden, zu welcher Seite der Finger gerade gehört, und zwar in
    // einer Bühne, die sich dabei rollt und zoomt — das ist die Art
    // Ziehgeste, die dieses Projekt von 1.0.5 bis 1.0.8 gekostet hat. Ein
    // Knopf, der immer tut, was draufsteht, ist hier mehr wert als eine
    // Geste, die meistens tut, was gemeint war.
    //
    // Verschoben wird INNERHALB eines Tages. Über Tagesgrenzen hinweg ist
    // es keine Frage der Seite mehr, sondern der Zuordnung: Ein Foto
    // gehört zu einem Tag (`tag.fotos`), und das ändert man dort, wo diese
    // Frage gestellt wird — in der Fotoliste des Tages.
    @discardableResult
    func blockVerschieben(_ id: UUID, aufSeite ziel: Int) -> Bool {
        guard let stelle = block(id) else { return false }
        guard reise.tage[stelle.tag].seiten.indices.contains(ziel),
              ziel != stelle.seite
        else { return false }
        merken()
        var geschoben = reise.tage[stelle.tag].seiten[stelle.seite].bloecke.remove(at: stelle.block)
        // Er zählt danach als Handarbeit: Ein Neuanordnen, das ihn
        // stillschweigend auf die alte Seite zurückholte, nähme genau die
        // Entscheidung zurück, die jemand gerade getroffen hat.
        geschoben.vonHand = true
        // Die Lage bleibt, wie sie war — auf der neuen Seite steht der
        // Block an derselben Stelle. Ihn zu zentrieren wäre bequemer und
        // verschöbe etwas, das niemand angefasst hat.
        reise.tage[stelle.tag].seiten[ziel].bloecke.append(geschoben)
        reise.tage[stelle.tag].seiten[ziel].heben(geschoben.id)
        gewaehlterBlock = geschoben.id
        seitenzeiger = ziel
        return true
    }

    // Auf welche Seiten dieser Block überhaupt kann — und auf welcher er
    // gerade steht. Gebraucht an zwei Stellen (Inspektor und Blockmenü);
    // zwei Fassungen zählten irgendwann verschieden.
    //
    // **Das Blockmenü gab es bis 1.0.38 nicht**, obwohl dieser Kommentar es
    // seit 1.0.29 nennt. Genau daran hing der Befund des Nutzers (09/2026:
    // „Ich suche noch nach der Funktion, Elemente auf eine andere Seite zu
    // kopieren oder zu verschieben. Sie ist zu versteckt."): Verschieben
    // gab es nur im Inspektor, also hinter dem Schieberegler in der
    // Werkzeugleiste und dort ganz unten. Ein Kommentar, der eine zweite
    // Aufrufstelle behauptet, ist kein Beleg dafür, dass es sie gibt.
    func seitenlage(_ id: UUID) -> (jetzt: Int, anzahl: Int)? {
        guard let stelle = block(id) else { return nil }
        return (stelle.seite, reise.tage[stelle.tag].seiten.count)
    }

    // Eine neue Seite hinter der jetzigen anlegen UND gleich dorthin
    // schieben. Ohne das endet „auf die nächste Seite" auf der letzten
    // Seite in einem Knopf, der nichts tut.
    func blockAufNeueSeite(_ id: UUID) {
        guard let stelle = block(id) else { return }
        merken()
        reise.tage[stelle.tag].seiten.insert(Seite(), at: stelle.seite + 1)
        var geschoben = reise.tage[stelle.tag].seiten[stelle.seite].bloecke.remove(at: stelle.block)
        geschoben.vonHand = true
        reise.tage[stelle.tag].seiten[stelle.seite + 1].bloecke.append(geschoben)
        gewaehlterBlock = geschoben.id
        seitenzeiger = stelle.seite + 1
    }

    // EINEN BLOCK KOPIEREN (ab 1.0.39, Ansage des Nutzers 09/2026:
    // „Elemente auf eine andere Seite zu kopieren oder zu verschieben").
    //
    // **Kopiert werden kann, was sich SELBST gehört.** Ein Foto gehört dem
    // Tag und darf zweimal im Buch stehen — klein im Text und groß auf einer
    // Aufmacherseite ist ein gewollter Satz. Ein TAGEBUCHTEXT dagegen gehört
    // dem Tag als Ganzes und steht einmal darin: Eine Kopie davon wäre
    // derselbe Absatz zweimal im gedruckten Buch, `Druckpruefung.doppelterText`
    // meldet genau das seit 1.0.9 als Fehler, und `Neuverteilung` schriebe
    // ihn beim nächsten Neuverteilen doppelt in den Tagebuchtext zurück.
    // Dasselbe gilt für Überschrift, Datumszeile und Bildunterschrift —
    // deren Text steht am Tag bzw. am Foto, eine zweite Anzeige desselben
    // Textes wäre kein Element, sondern eine Dublette.
    //
    // Wer einen Textkasten aufteilen will, teilt ihn (`textTeilen`); das ist
    // die Sache, die dahinter wirklich gemeint ist.
    func kopierbar(_ block: Block) -> Bool { !block.inhalt.istText }

    // `nil` als Ziel heißt: auf dieselbe Seite. Dann liegt die Kopie ein
    // Stück versetzt — deckungsgleich übereinander sähe sie aus, als wäre
    // nichts geschehen, und man verschöbe beim nächsten Griff das Original.
    @discardableResult
    func blockKopieren(_ id: UUID, aufSeite ziel: Int? = nil) -> Bool {
        guard let stelle = block(id) else { return false }
        let vorlage = reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block]
        guard kopierbar(vorlage) else {
            meldung = .init(text: "Kopieren geht nur bei Fotos, Karten, Linien und Flächen. "
                            + "Ein Tagebuchtext gehört dem Tag und steht einmal im Buch \u{2014} "
                            + "zum Aufteilen gibt es \u{201E}Rest auf die nächste Seite\u{201C}.",
                            schwer: true)
            return false
        }
        let seite = ziel ?? stelle.seite
        guard reise.tage[stelle.tag].seiten.indices.contains(seite) else { return false }
        merken()
        var kopie = vorlage
        // EINE KOPIE ERBT KEINE KENNUNG. Zwei Blöcke mit derselben id sind
        // für jede Suche EIN Block — `block(_:)` fände immer nur den ersten,
        // und der zweite ließe sich nie wieder anfassen. Dieselbe Lehre wie
        // bei Tafelbild 1.4.5.
        kopie.id = UUID()
        kopie.vonHand = true
        if ziel == nil || ziel == stelle.seite {
            // Versetzt um eine Fuge, aber nicht aus dem Satzspiegel hinaus.
            let versatz = max(reise.gestaltung.fugePt, 6)
            let raum = reise.gestaltung.satzspiegel(reise.format)
            // `Double(…)` um die Kanten des `CGRect`: Bei gemischten Typen
            // in einem `min` rechnet Swift `CGFloat` und `Double` nicht
            // zuverlässig ineinander um — dieselbe Falle, die 1.0.37 einen
            // Bau gekostet hat.
            let rechts = Double(raum.maxX) - kopie.rahmen.breite
            let unten = Double(raum.maxY) - kopie.rahmen.hoehe
            kopie.rahmen.x = min(kopie.rahmen.x + versatz, rechts)
            kopie.rahmen.y = min(kopie.rahmen.y + versatz, unten)
        }
        reise.tage[stelle.tag].seiten[seite].bloecke.append(kopie)
        reise.tage[stelle.tag].seiten[seite].heben(kopie.id)
        gewaehlterBlock = kopie.id
        seitenzeiger = seite
        return true
    }

    // AUSSCHNEIDEN, KOPIEREN, EINFÜGEN (ab 1.0.65).
    //
    // Die drei Handgriffe, die jede App kennt — und der Weg, der die
    // Seitenfrage ganz aus dem Menü nimmt: Eingefügt wird auf die GEWÄHLTE
    // Seite, und die wählt man auf der Bühne mit einem Tipp. Damit geht es
    // über Seiten-, Tages- und Umschlagsgrenzen hinweg, ohne dass ein Menü
    // jede mögliche Zielseite aufzählen müsste.
    //
    // Die Ablage hält eine KOPIE und keinen Verweis. Wer ausschneidet und
    // dann etwas anderes tut, hat den Block trotzdem noch; wer zweimal
    // einfügt, bekommt zwei Blöcke.
    func blockAusschneiden(_ id: UUID) {
        guard let geholt = blockWert(id) else { return }
        let tag = block(id).map { reise.tage[$0.tag].id }
        ablage = Ablageinhalt(block: geholt, tagID: tag, ausgeschnitten: true)
        // `blockLoeschen` merkt selbst — ein zweites `merken()` davor
        // legte einen Stand auf den Stapel, in dem nichts geschehen ist.
        blockLoeschen(id)
        meldung = .init(text: "\(geholt.inhalt.name) ausgeschnitten. "
                        + "Seite antippen, dann \u{201E}Einfügen\u{201C}.")
    }

    func blockInDieAblage(_ id: UUID) {
        guard let geholt = blockWert(id) else { return }
        let tag = block(id).map { reise.tage[$0.tag].id }
        ablage = Ablageinhalt(block: geholt, tagID: tag, ausgeschnitten: false)
        meldung = .init(text: "\(geholt.inhalt.name) kopiert. "
                        + "Seite antippen, dann \u{201E}Einfügen\u{201C}.")
    }

    // Warum es hier NICHT geht — oder `nil`, wenn es geht.
    //
    // Zwei Fälle, und beide sind keine Bequemlichkeit: Ein TAGEBUCHTEXT
    // gehört seinem Tag. `Neuverteilung.fliesstexte` schreibt ihn beim
    // Neuverteilen dorthin zurück, wo sein Block liegt; in einem fremden
    // Tag stünde er danach im falschen Tagebuchtext, und zwar still.
    // Dasselbe gilt für Überschrift, Datumszeile und Bildunterschrift —
    // deren Text steht am Tag bzw. am Foto. Und eine KARTE zeichnet die
    // Spur eines Tages; auf dem Umschlag gibt es keinen.
    func einfuegenGrund(auf seiteID: UUID) -> String? {
        guard let inhalt = ablage else { return nil }
        let amUmschlag = umschlagflaeche(seiteID) != nil
        if inhalt.block.inhalt == .karte, amUmschlag {
            return "Eine Karte zeichnet die Spur eines Tages \u{2014} auf dem Umschlag "
                + "gibt es keinen."
        }
        guard inhalt.block.inhalt.istText else { return nil }
        let zielTag = seitenstelle(seiteID).map { reise.tage[$0.tag].id }
        if zielTag != nil, zielTag == inhalt.tagID { return nil }
        return "\(inhalt.name) gehört seinem Tag \u{2014} der Text steht am Tag und nicht "
            + "im Block. Einfügen geht deshalb nur auf einer Seite desselben Tages."
    }

    @discardableResult
    func blockEinfuegen(auf seiteID: UUID) -> Bool {
        guard let inhalt = ablage else { return false }
        if let grund = einfuegenGrund(auf: seiteID) {
            meldung = .init(text: grund, schwer: true)
            return false
        }
        let flaeche = umschlagflaeche(seiteID)
        guard flaeche != nil || seitenstelle(seiteID) != nil else { return false }
        merken()
        var neu = inhalt.block
        // EINE KOPIE ERBT KEINE KENNUNG — auch die eines ausgeschnittenen
        // Blocks nicht: Er lässt sich zweimal einfügen, und zwei Blöcke mit
        // derselben Kennung sind für jede Suche einer. Dieselbe Lehre wie
        // bei `blockKopieren` und bei Tafelbild 1.4.5.
        neu.id = UUID()
        neu.vonHand = true
        let satz = flaeche == nil ? reise.gestaltung.satzspiegel(reise.format) : umschlagsatz
        neu.rahmen = inSatz(neu.rahmen, satz)
        if let flaeche {
            setzeUmschlagbloecke(flaeche, umschlagbloecke(flaeche) + [neu])
            gewaehlterBlock = neu.id
            return true
        }
        guard let stelle = seitenstelle(seiteID) else { return false }
        reise.tage[stelle.tag].seiten[stelle.seite].bloecke.append(neu)
        reise.tage[stelle.tag].seiten[stelle.seite].heben(neu.id)
        // Ein FOTO gehört einem Tag (`tag.fotos`), und genau das ändert
        // sich, wenn es auf die Seite eines anderen Tages wandert. Ohne
        // diesen Schritt stünde es weiter in der Fotoliste des alten Tages
        // und würde beim nächsten Neuanordnen dort wieder gesetzt.
        if let fotoID = neu.fotoID { fotoDemTagZuordnen(fotoID, tag: stelle.tag) }
        gewaehlterBlock = neu.id
        seitenzeiger = stelle.seite
        return true
    }

    // Der Rahmen bleibt, wo er war — aber nicht außerhalb des Papiers. Ein
    // Block vom Umschlag ist breiter als eine Buchseite; ohne das Klemmen
    // läge er dort halb im Anschnitt, ohne dass es jemand gewollt hätte.
    private func inSatz(_ rahmen: Rahmen, _ satz: CGRect) -> Rahmen {
        var neu = rahmen
        neu.breite = min(neu.breite, Double(satz.width))
        neu.hoehe = min(neu.hoehe, Double(satz.height))
        neu.x = min(max(neu.x, Double(satz.minX)), Double(satz.maxX) - neu.breite)
        neu.y = min(max(neu.y, Double(satz.minY)), Double(satz.maxY) - neu.hoehe)
        return neu
    }

    // Ein Foto dem Zieltag zuschlagen — und aus jedem Tag nehmen, der es
    // danach in keinem Block mehr zeigt.
    //
    // Eine GRAFIK bleibt außen vor: Sie gehört keinem Tag (seit 1.0.61),
    // taucht in keiner Fotoliste auf und soll es auch nicht.
    private func fotoDemTagZuordnen(_ fotoID: UUID, tag ziel: Int) {
        guard let bild = reise.foto(fotoID), !bild.grafik else { return }
        if !reise.tage[ziel].fotos.contains(fotoID) {
            reise.tage[ziel].fotos.append(fotoID)
        }
        for andere in reise.tage.indices where andere != ziel {
            guard reise.tage[andere].fotos.contains(fotoID) else { continue }
            let zeigtEsNoch = reise.tage[andere].seiten.contains { seite in
                seite.bloecke.contains { $0.fotoID == fotoID }
            }
            if !zeigtEsNoch { reise.tage[andere].fotos.removeAll { $0 == fotoID } }
        }
    }

    func blockNachVorn(_ id: UUID) {
        // Auf dem Umschlag ist „nach vorn" das Ende der eigenen Liste: Sie
        // wird hinter den gerechneten Satz gehängt, also liegt ihr letzter
        // Block obenauf.
        if let stelle = umschlagblock(id) {
            merken()
            var bloecke = umschlagbloecke(stelle.flaeche)
            let geholt = bloecke.remove(at: stelle.stelle)
            bloecke.append(geholt)
            setzeUmschlagbloecke(stelle.flaeche, bloecke)
            return
        }
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

    // Wo eine Seite im Buch steht — Tag und Stelle. Die Bühne kennt nur
    // ihre Kennung; alles, was an ihr arbeitet, braucht beides.
    func seitenstelle(_ seiteID: UUID) -> (tag: Int, seite: Int)? {
        for (t, tag) in reise.tage.enumerated() {
            if let stelle = tag.seiten.firstIndex(where: { $0.id == seiteID }) {
                return (t, stelle)
            }
        }
        return nil
    }

    // Dieselbe Frage als Wahrheitswert: Lässt sich auf dieser Seite
    // überhaupt etwas einsetzen?
    //
    // Die AUSGLEICHSSEITE (1.0.60) wird gerechnet und steht in keinem
    // Tag — ein Block darauf wäre beim nächsten Durchgang weg. Ein Knopf,
    // der das trotzdem anbietet, ist ein Knopf, der nichts tut.
    //
    // Bis 1.0.63 stand dieser Satz auch über Titel- und Rückseite. Er galt
    // dort ebenso — solange ein Block IN der gerechneten Seite liegen
    // musste. Seit 1.0.64 liegt er daneben, am Umschlag, und wird der
    // gerechneten Seite nur angehängt; damit übersteht er jeden
    // Durchgang, und beide Seiten nehmen etwas an.
    var einsetzbareSeite: UUID? {
        guard let id = gewaehlteSeite else { return nil }
        if umschlagflaeche(id) != nil { return id }
        guard seitenstelle(id) != nil else { return nil }
        return id
    }

    // Der Name der gewählten Seite, für die Beschriftung des Menüs. Ohne
    // ihn stünde dort „Auf die Seite legen" und man müsste raten, welche
    // gemeint ist — genau der gemeldete Zustand.
    func seitenname(_ seiteID: UUID) -> String? {
        if let flaeche = umschlagflaeche(seiteID) {
            return flaeche == .titel ? "Umschlag: Titelseite" : "Umschlag: Rückseite"
        }
        guard let stelle = seitenstelle(seiteID) else { return nil }
        let tag = reise.tage[stelle.tag]
        return "\(tag.datum.kurz), Blatt \(stelle.seite + 1)"
    }

    // Wo ein neuer Block auf dem Umschlag anfängt: in der Mitte seines
    // Satzspiegels — und das ist der des UMSCHLAGS, nicht der des Buches.
    // Er kennt keinen Bundsteg: Ein Umschlag wird nicht gebunden, er wird
    // umgelegt.
    private var umschlagsatz: CGRect {
        Umschlagmass.satzspiegel(reise.format, gestaltung: reise.gestaltung,
                                 umschlag: reise.umschlag)
    }

    private func umschlagblockHinzufuegen(_ inhalt: Blockinhalt, auf flaeche: Umschlagflaeche) {
        merken()
        let satz = umschlagsatz
        let breite = min(Double(satz.width) * 0.6, 280.0)
        let neu = Block(
            inhalt: inhalt,
            rahmen: Rahmen(x: Double(satz.midX) - breite / 2,
                           y: Double(satz.midY) - 45,
                           breite: breite, hoehe: inhalt.istFoto ? breite * 0.7 : 90),
            vonHand: true
        )
        setzeUmschlagbloecke(flaeche, umschlagbloecke(flaeche) + [neu])
        gewaehlterBlock = neu.id
    }

    // Einsetzen auf einer BESTIMMTEN Seite, nicht auf dem Seitenzeiger.
    func blockHinzufuegen(_ inhalt: Blockinhalt, aufSeite seiteID: UUID) {
        if let flaeche = umschlagflaeche(seiteID) {
            umschlagblockHinzufuegen(inhalt, auf: flaeche)
            return
        }
        guard let stelle = seitenstelle(seiteID) else { return }
        blockHinzufuegen(inhalt, tag: reise.tage[stelle.tag].id, seite: stelle.seite)
    }

    // EIN BILD VON HAND (ab 1.0.61).
    //
    // Ansage des Nutzers, 09/2026: „Ich möchte in das Buch manuell Bilder
    // oder Grafiken einfügen können. Dies soll über den Plus-Button
    // geschehen, sowie bei den Textfeldern auch."
    //
    // Es geht NICHT durch die Fotoeinfuhr: Die ordnet einem Tag zu, fragt
    // nach Datum und Ort und meldet, was fehlt — für eine Grafik ist das
    // alles keine Auskunft, sondern Lärm (gemeldet 09/2026: „1 Fotos
    // tragen keinen Ort … 1 Fotos tragen kein Datum und stehen jetzt bei
    // 4. Juni 2026"). Gelesen werden nur die MASSE; der Rest der Datei
    // interessiert hier nicht.
    //
    // Der Rahmen folgt dem Seitenverhältnis des Bildes: Ein fester Rahmen
    // schnitte jedes Hochformat an, denn gefüllt wird, nicht eingepasst.
    @discardableResult
    func grafikEinfuegen(_ daten: Data, endung: String, aufSeite seiteID: UUID) -> Bool {
        let flaeche = umschlagflaeche(seiteID)
        guard flaeche != nil || seitenstelle(seiteID) != nil else { return false }
        let befund = Bildleser.befund(datei: daten)
        guard let datei = try? Bildarchiv.shared.ablegen(daten, reise: reise.id, endung: endung)
        else { return false }
        merken()
        let foto = Foto(datei: datei,
                        breite: befund.breite > 0 ? befund.breite : 1000,
                        hoehe: befund.hoehe > 0 ? befund.hoehe : 750,
                        grafik: true)
        reise.setzeFoto(foto)
        let satz = flaeche == nil ? reise.gestaltung.satzspiegel(reise.format) : umschlagsatz
        let breite = min(Double(satz.width) * 0.46, 260.0)
        let hoehe = min(breite / max(foto.seitenverhaeltnis, 0.2), Double(satz.height) * 0.7)
        let neu = Block(
            inhalt: .foto(foto.id),
            rahmen: Rahmen(x: Double(satz.midX) - breite / 2,
                           y: Double(satz.midY) - hoehe / 2,
                           breite: breite, hoehe: hoehe),
            vonHand: true
        )
        if let flaeche {
            setzeUmschlagbloecke(flaeche, umschlagbloecke(flaeche) + [neu])
            gewaehlterBlock = neu.id
            return true
        }
        guard let stelle = seitenstelle(seiteID) else { return false }
        reise.tage[stelle.tag].seiten[stelle.seite].bloecke.append(neu)
        reise.tage[stelle.tag].seiten[stelle.seite].heben(neu.id)
        gewaehlterBlock = neu.id
        return true
    }

    // EINE LEERE SEITE AN EINER BESTIMMTEN STELLE (ab 1.0.33).
    //
    // Bis 1.0.32 gab es nur „Seite anfügen", und das hängte immer hinten
    // an. Wer zwischen dem zweiten und dem dritten Tag Platz brauchte,
    // musste die Seite am Ende anlegen und alles von Hand dorthin
    // schieben. Angefügt wird weiterhin — das ist jetzt der Sonderfall
    // „einfügen ganz hinten" und keine zweite Funktion daneben.
    //
    // Die neue Seite trägt `vonHandAngelegt`: Ohne den Vermerk räumte das
    // nächste Neuanordnen des Tages sie wieder weg, und zwar STILL.
    @discardableResult
    func seiteEinfuegen(_ tagID: UUID, an stelle: Int) -> Int? {
        guard let t = tagIndex(tagID) else { return nil }
        let ziel = min(max(stelle, 0), reise.tage[t].seiten.count)
        merken()
        reise.tage[t].seiten.insert(Seite(vonHandAngelegt: true), at: ziel)
        seitenzeiger = ziel
        return ziel
    }

    func seiteHinzufuegen(_ tagID: UUID) {
        guard let t = tagIndex(tagID) else { return }
        seiteEinfuegen(tagID, an: reise.tage[t].seiten.count)
    }

    // Die letzte Seite eines Tages bleibt stehen: Ein Tag ohne Seite wäre
    // kein Tag mehr, sondern ein Loch im Buch — und `fehlendeSeitenNachholen`
    // setzte ihn beim nächsten Öffnen ohnehin neu.
    func seiteLoeschen(_ tagID: UUID, seite: Int) {
        guard let t = tagIndex(tagID), reise.tage[t].seiten.count > 1,
              reise.tage[t].seiten.indices.contains(seite) else { return }
        merken()
        reise.tage[t].seiten.remove(at: seite)
        // Wer eine Seite entfernt, hat an der Seitenfolge dieses Tages
        // gearbeitet. Ohne diesen Vermerk holte das nächste Neuanordnen
        // sie zurück, als wäre nichts gewesen.
        seitenfolgeGemerkt(t)
        seitenzeiger = min(seitenzeiger, reise.tage[t].seiten.count - 1)
    }

    func seiteVerschieben(_ tagID: UUID, von: IndexSet, nach: Int) {
        guard let t = tagIndex(tagID) else { return }
        merken()
        reise.tage[t].seiten.move(fromOffsets: von, toOffset: nach)
        seitenfolgeGemerkt(t)
    }

    // Eine Seite dieses Tages trägt danach den Vermerk — welche, ist
    // gleichgültig: Gefragt wird überall nur, OB der Tag Handarbeit
    // enthält. Steht der Vermerk schon irgendwo, bleibt alles wie es ist.
    private func seitenfolgeGemerkt(_ t: Int) {
        guard !reise.tage[t].seiten.contains(where: \.vonHand),
              !reise.tage[t].seiten.isEmpty
        else { return }
        reise.tage[t].seiten[0].vonHandAngelegt = true
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

    // EINEN VORHANDENEN PUNKT ÄNDERN (ab 1.0.20, Ansage des Nutzers 09/2026:
    // „Ich möchte sie löschen, örtlich und zeitlich verändern können.").
    //
    // Ändert sich die UHRZEIT, wird der Punkt neu einsortiert: Die Reihenfolge
    // der Liste ist die Reihenfolge der gezeichneten Spur, und ein Punkt von
    // 8 Uhr hinter einem von 17 Uhr ergäbe eine Linie, die niemand gefahren
    // ist. Punkte OHNE Uhrzeit bleiben, wo sie sind — wohin sie gehören,
    // weiß auch die App nicht (die Regel steht seit 1.0.0 dort).
    func punktAendern(_ tagID: UUID, punktID: UUID, ort: Koordinate,
                      name: String, zeit: Date?)
    {
        guard let t = tagIndex(tagID),
              let stelle = reise.tage[t].spur.firstIndex(where: { $0.id == punktID })
        else { return }
        merken()
        var punkt = reise.tage[t].spur[stelle]
        let alteZeit = punkt.zeit
        punkt.koordinate = ort
        punkt.name = name
        punkt.zeit = zeit
        reise.tage[t].spur[stelle] = punkt
        if zeit != alteZeit, let zeit {
            reise.tage[t].spur.remove(at: stelle)
            let neueStelle = reise.tage[t].spur.firstIndex { ($0.zeit ?? .distantFuture) > zeit }
                ?? reise.tage[t].spur.count
            reise.tage[t].spur.insert(punkt, at: neueStelle)
        }
        // `hatSpur` kann sich dabei nicht ändern — die Zahl der Punkte bleibt
        // gleich. Gesichert und neu gezeichnet werden muss trotzdem.
        sofortSichern()
    }

    func punktLoeschen(_ tagID: UUID, punktID: UUID) {
        guard let t = tagIndex(tagID),
              let stelle = reise.tage[t].spur.firstIndex(where: { $0.id == punktID })
        else { return }
        punkteLoeschen(tagID, stellen: IndexSet(integer: stelle))
    }

    // MEHRERE ZEITSTEMPEL AUF EINMAL VERSCHIEBEN (ab 1.0.21, Ansage des
    // Nutzers 09/2026: „mehrere von ihnen auswählen zu können und ihren
    // Zeitstempel gemeinsam verschieben zu können, beispielsweise um drei
    // Stunden nach hinten.").
    //
    // Der Fall dahinter ist der Regelfall auf einer Reise: eine Kamera, deren
    // Uhr auf der Zeit von zu Hause stand, oder eine Spur aus einer fremden
    // App ohne Zonenangabe. Verschoben wird die WANDUHR am Ort — dieselbe
    // Bedeutung wie überall (siehe `Dienste/Ortszeit.swift`); addiert werden
    // schlicht Sekunden.
    //
    // Zurückgegeben wird ein Satz für die Meldung, und er nennt AUCH, was
    // NICHT verschoben wurde: Ein Punkt ohne Uhrzeit hat keine, die sich
    // verschieben ließe, und eine stillschweigend übergangene Auswahl sieht
    // aus wie ein Fehler.
    @discardableResult
    func zeitenVerschieben(_ tagID: UUID, punkte: Set<UUID>, um sekunden: TimeInterval) -> String {
        guard let t = tagIndex(tagID), !punkte.isEmpty else { return "Nichts ausgewählt." }
        merken()
        var verschoben = 0
        var ohneZeit = 0
        for stelle in reise.tage[t].spur.indices where punkte.contains(reise.tage[t].spur[stelle].id) {
            guard let zeit = reise.tage[t].spur[stelle].zeit else {
                ohneZeit += 1
                continue
            }
            reise.tage[t].spur[stelle].zeit = zeit.addingTimeInterval(sekunden)
            verschoben += 1
        }
        reise.tage[t].spur = nachZeitGeordnet(reise.tage[t].spur)
        sofortSichern()
        var satz = verschoben == 1 ? "1 Punkt verschoben." : "\(verschoben) Punkte verschoben."
        if ohneZeit > 0 {
            satz += ohneZeit == 1
                ? " 1 Punkt hat keine Uhrzeit und blieb unverändert."
                : " \(ohneZeit) Punkte haben keine Uhrzeit und blieben unverändert."
        }
        return satz
    }

    func punkteLoeschen(_ tagID: UUID, ids: Set<UUID>) {
        guard let t = tagIndex(tagID) else { return }
        let stellen = IndexSet(reise.tage[t].spur.indices.filter { ids.contains(reise.tage[t].spur[$0].id) })
        guard !stellen.isEmpty else { return }
        punkteLoeschen(tagID, stellen: stellen)
    }

    // Nach Zeit ordnen, STABIL und ohne die zeitlosen Punkte zu verwürfeln.
    //
    // `sorted` ist in Swift nicht als stabil zugesichert; ohne den Index als
    // zweites Merkmal stünden zwei Punkte derselben Minute nach jedem
    // Verschieben in einer anderen Reihenfolge. Punkte OHNE Uhrzeit rutschen
    // ans Ende und behalten dort ihre Ordnung — wohin sie gehören, weiß auch
    // die App nicht (die Regel steht seit 1.0.0 dort).
    private func nachZeitGeordnet(_ spur: [Reisepunkt]) -> [Reisepunkt] {
        spur.enumerated()
            .sorted { links, rechts in
                let a = links.element.zeit ?? .distantFuture
                let b = rechts.element.zeit ?? .distantFuture
                if a == b { return links.offset < rechts.offset }
                return a < b
            }
            .map(\.element)
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
        // Auch auf dem Umschlag: Ein Block, dessen Bild es nicht mehr gibt,
        // wäre dort eine leere Fläche, an die niemand mehr herankommt.
        reise.umschlag.titelbloecke.removeAll { $0.fotoID == fotoID }
        reise.umschlag.rueckbloecke.removeAll { $0.fotoID == fotoID }
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
