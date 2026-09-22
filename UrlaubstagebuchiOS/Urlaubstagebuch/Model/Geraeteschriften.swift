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
                    meldungen.append(fall.localizedDescription)
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
            notiere(kopf + " Nichts anzumelden.")
            return
        }
        anmelden(anzumelden) { befund in
            let nachher = UIFont.familyNames.count
            notiere(kopf + " Angemeldet: \(anzumelden.count), " + befund
                    + " Familien danach: \(nachher).")
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
        text += "Vom System als dauerhaft angemeldet gemeldet: \(fund.roh) Einträge.\n"
        text += "Davon als Deskriptor lesbar: \(fund.deskriptoren.count) "
            + "in \(fund.familien.count) Familien.\n"
        if fund.familien.isEmpty {
            text += "Keine Familie genannt. Dann gibt diese Abfrage auf diesem Gerät "
                + "nichts her, und es bleibt der Wähler von iOS.\n"
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
