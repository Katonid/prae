import CoreText
import UIKit

// SCHRIFTEN, DIE DER NUTZER SELBST AUF DAS GERÄT GELEGT HAT
// (ab 1.0.41, in 1.0.43 umgebaut).
//
// Gemeldet 09/2026: „Quicksand und … sind auf dem iPad installiert und
// können beispielsweise in Pages auch genutzt werden. In der App werden sie
// allerdings nicht einmal angezeigt." — und nach 1.0.41 noch einmal: „Die
// Schriftarten tauchen immer noch nicht auf."
//
// Der erste Befund war richtig und die Antwort darauf war zu klein.
// `Schriftfamilie.alleDesGeraets` baut die Liste aus `UIFont.familyNames`,
// und das ist das Verzeichnis DIESES PROZESSES — die Schriften des Systems
// und die, die eine App in ihrem Bündel mitbringt. 1.0.41 stellte daneben
// den `UIFontPickerViewController`; der erreicht die selbst installierten
// Schriften, aber nur EINE nach der anderen und nur, wenn man den Knopf
// findet. Die LISTE blieb dieselbe wie vorher.
//
// Seit 1.0.43 fragt die App deshalb zuerst das System selbst:
// `CTFontManagerCopyRegisteredFontDescriptors(.persistent, true)` gibt die
// Schriften zurück, die auf diesem Gerät dauerhaft angemeldet sind — also
// auch die, die eine Schriftverwaltung dort abgelegt hat. Was dabei
// herauskommt, wird für diesen Prozess angemeldet; danach steht es in
// `UIFont.familyNames` und damit in der gewohnten Liste.
//
// UND DARÜBER STEHT EIN RECHT — seit 1.0.66 wieder da, diesmal gemessen.
// Ohne `com.apple.developer.user-fonts` gibt iOS einer App die selbst
// installierten Schriften überhaupt nicht heraus. 1.0.44 trug es mit einer
// GERATENEN Zeichenkette ein und machte die App damit unsignierbar; 1.0.45
// nahm es heraus und baute stattdessen `Profilrechte`, das liest, was der
// Bau wirklich darf. Am 23.09.2026 hat genau diese Probe geantwortet:
// „BEWILLIGT als [app-usage, system-installation]" — und seither steht das
// Wort für Wort in der Entitlements-Datei. Die Begründung steht dort.
//
// DER WÄHLER IST EIN EIGENER PROZESS, und das erklärt den scheinbaren
// Widerspruch im selben Befund: Diese Abfrage meldete null Einträge,
// während drei über den Wähler gewählte Schriften auffindbar waren.
// `UIFontPickerViewController` läuft außerhalb der App (wie der
// Fotowähler) und zeigt deshalb, was das Gerät hat; was DIESER Prozess
// aufzählen und anmelden darf, ist eine andere Frage. Ein Befund über den
// einen Weg sagt über den anderen nichts.
//
// **Gemessen ist das hier nicht.** Ob diese Abfrage auf dem iPad des
// Nutzers etwas hergibt, weiß hier niemand — deshalb behauptet diese Datei
// nichts, sondern ZÄHLT: Sie meldet an, sieht danach nach, was der Prozess
// kennt, und schreibt beides in ein Protokoll, das sich kopieren lässt
// (`probe`). Dieselbe Bauweise wie die Stufenprobe bei Schulalarm und der
// Kartenmesser der Abfahrtstafel: Nach einer Erklärung, die nicht geholfen
// hat, wird nicht ein zweites Mal geraten.
enum Geraeteschriften {
    // MARK: - Was das System als installiert meldet

    struct Systemfund {
        // Wie viele Einträge zurückkamen.
        var roh: Int
        // Wie viele davon sich als Deskriptor lesen ließen. Zwei Zahlen,
        // weil es zwei verschiedene Auskünfte sind: „das System meldet
        // nichts" und „das System meldet etwas, das wir nicht lesen".
        var deskriptoren: [UIFontDescriptor]
        var familien: [String]
    }

    static func systemfund() -> Systemfund {
        let roh = CTFontManagerCopyRegisteredFontDescriptors(.persistent, true) as NSArray
        let deskriptoren = roh.compactMap { $0 as? UIFontDescriptor }
        var familien: [String] = []
        for deskriptor in deskriptoren {
            guard let familie = familienname(deskriptor) else { continue }
            if !familien.contains(familie) { familien.append(familie) }
        }
        return Systemfund(roh: roh.count, deskriptoren: deskriptoren,
                          familien: familien.sorted())
    }

    // Der Familienname eines Deskriptors, ohne die Schrift zu bauen: Eine
    // Schrift aus einem Deskriptor zu bauen, den dieser Prozess nicht
    // kennt, gäbe eine ERSATZSCHRIFT zurück — und damit stünde deren Name
    // in der Liste.
    static func familienname(_ deskriptor: UIFontDescriptor) -> String? {
        deskriptor.fontAttributes[.family] as? String
    }

    static func schnittname(_ deskriptor: UIFontDescriptor) -> String? {
        let name = deskriptor.postscriptName
        if !name.isEmpty { return name }
        return deskriptor.fontAttributes[.name] as? String
    }

    // MARK: - Anmelden

    // Deskriptoren für DIESEN Prozess anmelden. `.process` und nicht
    // `.persistent`: Wir wollen sie lesen, nicht auf dem Gerät
    // installieren — installiert hat sie der Nutzer längst.
    //
    // Der Aufruf ist asynchron, und sein Ergebnis steht nicht im
    // Rückgabewert, sondern im Rückrufblock. Bis 1.0.42 wurde er ohne
    // Block aufgerufen und gleich danach nachgesehen, ob die Schrift
    // auffindbar sei — eine Frage, die zu diesem Zeitpunkt noch gar nicht
    // beantwortet sein kann.
    static func anmelden(_ deskriptoren: [UIFontDescriptor],
                         fertig: @escaping (String) -> Void)
    {
        guard !deskriptoren.isEmpty else { fertig("Nichts anzumelden."); return }
        var meldungen: [String] = []
        CTFontManagerRegisterFontDescriptors(
            deskriptoren as CFArray, .process, true
        ) { fehler, abgeschlossen in
            for eintrag in fehler as NSArray {
                if let fall = eintrag as? Error {
                    meldungen.append(fehlertext(fall))
                }
            }
            if abgeschlossen {
                let einmalig = Array(Set(meldungen)).sorted()
                let text = einmalig.isEmpty
                    ? "ohne Fehlermeldung"
                    : "Meldungen: " + einmalig.joined(separator: " / ")
                DispatchQueue.main.async { fertig(text) }
            }
            return true
        }
    }

    // WAS EIN FEHLER HEISST, STEHT IN SEINER ZAHL — nicht in seinem Satz
    // (ab 1.0.66). Im Befund vom 23.09.2026 stand neunmal derselbe Satz:
    // „Die Schriftregistrierung ist fehlgeschlagen." Das ist der
    // allgemeine Text von CoreText und sagt über die Ursache nichts —
    // und im SELBEN Befund waren alle drei über den Wähler gewählten
    // Schriften auffindbar. Ein „Fehler", nach dem die Sache geht, ist
    // fast immer „steht schon" (105); entschieden wird das an der Zahl
    // und nicht an der Formulierung.
    //
    // Aufgeschrieben als Tabelle und nicht über `CTFontManagerError`:
    // Die Zahlen stehen in Apples Papier und ändern sich nicht, die
    // Namen der Swift-Fälle sind zwischen Fassungen schon gewandert.
    // Was nicht in der Tabelle steht, wird NICHT gedeutet — dann steht
    // dort nur die nackte Zahl, und die ist mehr wert als eine geratene
    // Erklärung.
    private static let fehlernamen: [Int: String] = [
        101: "Datei nicht gefunden",
        102: "zu wenig Rechte",
        103: "Format nicht erkannt",
        104: "Schriftdaten ungültig",
        105: "steht schon \u{2014} bereits angemeldet",
        201: "nicht angemeldet",
        202: "in Gebrauch",
        203: "wird vom System gebraucht",
    ]

    private static func fehlertext(_ fall: Error) -> String {
        let roh = fall as NSError
        var text = roh.domain
        text += " "
        text += String(roh.code)
        if let name = fehlernamen[roh.code] {
            text += " ("
            text += name
            text += ")"
        }
        text += ": "
        text += roh.localizedDescription
        return text
    }

    // Eine einzelne, über den Systemwähler gewählte Schrift.
    static func anmelden(_ deskriptor: UIFontDescriptor,
                         fertig: @escaping (String) -> Void)
    {
        anmelden([deskriptor], fertig: fertig)
    }

    // Kennt dieser Prozess die Schrift unter diesem Namen? Das ist die
    // Frage, an der später alles hängt: `Schriftbild.uiFont` baut die
    // Schrift aus dem NAMEN, denn nur der steht im gesicherten Buch.
    static func kennt(_ name: String) -> Bool {
        UIFont(name: name, size: 12) != nil
    }

    // MARK: - Was gewählt wurde

    // Die Namen der über den Systemwähler gewählten Schriften. Sie liegen
    // in den Voreinstellungen und nicht im Buch: Ob eine Schrift auf DIESEM
    // Gerät liegt, ist eine Eigenschaft des Geräts und keine des Buches —
    // dasselbe Buch auf einem zweiten iPad hat andere Schriften.
    //
    // Kein `@AppStorage`: Das ist eine `DynamicProperty` und gehört in eine
    // View (die Regel steht seit 1.0.0 im Papier).
    private static let schluessel = "geraeteschriften"
    private static let protokollschluessel = "geraeteschriftenProtokoll"

    static var gemerkte: [String] {
        UserDefaults.standard.stringArray(forKey: schluessel) ?? []
    }

    static func merken(_ name: String) {
        var liste = gemerkte
        guard !liste.contains(name) else { return }
        liste.append(name)
        UserDefaults.standard.set(liste, forKey: schluessel)
    }

    // MARK: - Das Protokoll

    // Ein Protokoll und keine Behauptung: Wer nachfragt, warum eine
    // Schrift fehlt, bekommt Zahlen und nicht eine Vermutung. Es überlebt
    // den Neustart — und genau darum geht es, denn die Frage lautet ja,
    // ob die Anmeldung beim Start trägt.
    static var protokoll: [String] {
        UserDefaults.standard.stringArray(forKey: protokollschluessel) ?? []
    }

    static func notiere(_ zeile: String) {
        let zeit = DateFormatter.localizedString(
            from: Date(), dateStyle: .short, timeStyle: .medium)
        var liste = protokoll
        liste.append(zeit + "  " + zeile)
        if liste.count > 40 { liste.removeFirst(liste.count - 40) }
        UserDefaults.standard.set(liste, forKey: protokollschluessel)
    }

    // MARK: - Beim Start

    // Beim Start alles anmelden, was dieses Gerät hergibt: erst, was das
    // System als dauerhaft angemeldet meldet, dazu die Namen, die einmal
    // über den Wähler gewählt wurden.
    //
    // Nötig ist das, weil eine Anmeldung auf `.process` mit dem Prozess
    // endet. Ein Deskriptor, der nur einen NAMEN trägt, findet eine dem
    // Prozess unbekannte Schrift womöglich gar nicht; deshalb steht der
    // Weg über das System jetzt davor, und das Ergebnis wird gezählt.
    static func beimStartAnmelden() {
        let vorher = UIFont.familyNames.count
        let fund = systemfund()
        let offene = gemerkte.filter { !kennt($0) }
        var anzumelden = fund.deskriptoren
        anzumelden += offene.map { UIFontDescriptor(name: $0, size: 12) }
        let kopf = "Start: System meldet \(fund.roh) Einträge, davon lesbar "
            + "\(fund.deskriptoren.count) in \(fund.familien.count) Familien; "
            + "\(offene.count) gemerkte noch offen; Familien im Prozess: \(vorher)."
        guard !anzumelden.isEmpty else {
            // „Nichts anzumelden" ist zweierlei, und bis 1.0.65 stand nur
            // das Wort da. Im Befund vom 23.09.2026 war es der GUTE Fall:
            // Alle drei gemerkten Schriften waren schon auffindbar, es gab
            // also nichts nachzuholen. Wer das liest, soll nicht raten
            // müssen, ob gerade etwas fehlschlug.
            let zusatz = gemerkte.isEmpty
                ? " Nichts anzumelden (nichts gemerkt, System meldet nichts)."
                : " Nichts anzumelden \u{2014} alle \(gemerkte.count) gemerkten "
                    + "sind bereits auffindbar."
            notiere(kopf + zusatz)
            return
        }
        anmelden(anzumelden) { befund in
            let nachher = UIFont.familyNames.count
            let treffer = gemerkte.filter { kennt($0) }.count
            notiere(kopf + " Angemeldet: \(anzumelden.count), " + befund
                    + " Familien danach: \(nachher); auffindbar: "
                    + "\(treffer) von \(gemerkte.count) gemerkten.")
        }
    }

    // MARK: - Der Befund

    // Was nach einer Wahl wirklich der Fall ist — ein Satz, kein
    // Versprechen. Er wird erst gebildet, wenn die Anmeldung abgeschlossen
    // gemeldet hat.
    static func befund(_ familie: Schriftfamilie) -> String {
        guard let name = familie.schnitt ?? familie.familienname else {
            return "Eine Systemschrift \u{2014} die ist immer da."
        }
        if kennt(name) {
            return "\u{201E}\(familie.vollerName)\u{201C} ist angemeldet und unter ihrem "
                + "Namen auffindbar. Damit steht sie auch nach einem Neustart der App "
                + "wieder zur Verfügung \u{2014} sofern sie auf dem Gerät bleibt."
        }
        return "\u{201E}\(familie.vollerName)\u{201C} ließ sich NICHT unter ihrem Namen "
            + "wiederfinden. Gesetzt wird dann die Systemschrift, und die Druckprüfung "
            + "sagt es noch einmal. Bitte schick den Befund aus \u{201E}Schriften "
            + "prüfen\u{201C} \u{2014} dieser Fall ist nicht gemessen, sondern vorgesehen."
    }

    // Der kopierbare Befund. Er nennt Zahlen und sonst nichts.
    static func probe() -> String {
        let fund = systemfund()
        let familien = UIFont.familyNames.sorted()
        var text = "SCHRIFTEN \u{2014} BEFUND\n"
        text += "Reisebuch \(fassung)\n\n"
        // WAS DIESER BAU DARF — gelesen, nicht behauptet (ab 1.0.45).
        // Es steht ganz oben, weil es jede Zeile darunter erklärt: Ohne
        // das Recht meldet das System einer App gar nichts, und dann sagt
        // „0 Einträge" nichts über das Gerät aus.
        text += "Was dieser Bau darf\n"
        for zeile in Profilrechte.zeilen() { text += zeile + "\n" }
        text += "\n"
        text += "Vom System als dauerhaft angemeldet gemeldet: \(fund.roh) Einträge.\n"
        text += "Davon als Deskriptor lesbar: \(fund.deskriptoren.count) "
            + "in \(fund.familien.count) Familien.\n"
        if fund.familien.isEmpty {
            text += "Keine Familie genannt.\n"
            // WOHIN DER NÄCHSTE VERDACHT ZEIGT, hängt davon ab, was oben
            // steht (ab 1.0.66). Bis 1.0.65 zeigte diese Zeile immer auf
            // das Recht an der App-Id — und im Befund vom 23.09.2026 war
            // genau das schon bewilligt. Eine Probe, die nach dem Messen
            // dieselbe Vermutung wiederholt, ist die Frage von vorhin noch
            // einmal.
            switch Profilrechte.schriftenrechtBewilligt() {
            case .some(true):
                text += "Das Profil BEWILLIGT das Schriftenrecht (siehe oben). Der "
                text += "nächste Verdacht ist damit nicht mehr die App-Id, sondern ob "
                text += "diese Fassung das Recht auch VERLANGT: Das steht in der "
                text += "Entitlements-Datei, und die lässt sich von innen nicht lesen. "
                text += "Im Repo steht es ab 1.0.66; welche Fassung hier läuft, steht "
                text += "ganz oben.\n"
            case .some(false):
                text += "Das Profil nennt das Schriftenrecht NICHT (siehe oben). Dann "
                text += "gibt iOS dieser App die selbst installierten Schriften gar "
                text += "nicht heraus, und die Null darüber sagt nichts über das Gerät "
                text += "aus.\n"
            case .none:
                text += "Ob dieser Bau das Recht "
                text += "\u{201E}com.apple.developer.user-fonts\u{201C} hat, ließ sich "
                text += "hier nicht lesen (siehe oben) \u{2014} ohne das Recht gibt iOS "
                text += "einer App die selbst installierten Schriften gar nicht heraus.\n"
            }
            text += "Gegenprobe ohne Fachwissen: Tippe unten auf "
            text += "\u{201E}Schrift vom Gerät wählen\u{2026}\u{201C}. Stehen deine eigenen "
            text += "Schriften dort, liegt es nicht am Recht; fehlen sie dort auch, dann "
            text += "schon.\n"
        } else {
            text += "Familien: " + fund.familien.prefix(25).joined(separator: ", ")
            if fund.familien.count > 25 { text += " \u{2026}" }
            text += "\n"
        }
        text += "\nFamilien, die dieser Prozess kennt: \(familien.count).\n"
        text += "\nÜber den Wähler gewählt: \(gemerkte.count).\n"
        for name in gemerkte {
            text += "  " + name + " \u{2014} "
            text += kennt(name) ? "auffindbar\n" : "NICHT auffindbar\n"
        }
        // WAS AUFFINDBAR IST, GEHT — auch wenn das Protokoll darunter eine
        // Fehlermeldung trägt (ab 1.0.66). Genau dieser Widerspruch stand
        // im Befund vom 23.09.2026: dreimal „Die Schriftregistrierung ist
        // fehlgeschlagen" und dreimal „auffindbar". Ein Protokoll, das
        // einen harmlosen Fehler wie einen Ausfall aussehen lässt, schickt
        // die Suche in die falsche Richtung.
        if !gemerkte.isEmpty, gemerkte.allSatisfy({ kennt($0) }) {
            text += "  Alle gewählten sind auffindbar. Eine Fehlermeldung beim "
            text += "Anmelden bedeutet dann nichts \u{2014} meist heißt sie "
            text += "\u{201E}steht schon\u{201C} (Code 105).\n"
        }
        text += "\nProtokoll (jüngste zuletzt):\n"
        text += protokoll.isEmpty ? "  (leer)\n" : protokoll.joined(separator: "\n")
        return text
    }

    static var fassung: String {
        let info = Bundle.main.infoDictionary
        let marke = info?["CFBundleShortVersionString"] as? String ?? "?"
        let bau = info?["CFBundleVersion"] as? String ?? "?"
        return marke + " (" + bau + ")"
    }
}
