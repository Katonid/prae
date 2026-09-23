import Foundation

// WAS DIESER BAU WIRKLICH DARF — gelesen, nicht behauptet (ab 1.0.45).
//
// 1.0.44 trug das Schriftenrecht in die Entitlements-Datei ein und schrieb
// daneben, es sei „seit 1.0.44 in Kraft". Das war eine Auskunft über das
// REPO, ausgegeben als Auskunft über das GERÄT — und sie war falsch: Xcode
// wies die Signierung ab, weil das Profil dieses Recht gar nicht bewilligt
// („doesn't match the entitlements file's value for the
// com.apple.developer.user-fonts entitlement"). Die App war damit nicht
// mehr auf ein iPad zu bringen, und der Bau in GitHub Actions konnte es
// nicht melden: Der übersetzt mit `CODE_SIGNING_ALLOWED=NO` und sieht
// Entitlements nie an.
//
// Dieselbe Art Lüge wie bei Schulalarms APNs-Umgebung, und dieselbe
// Antwort: Wo sich eine Frage nicht erschließen lässt, muss eine PROBE
// entscheiden. Was ein Bau darf, steht im eingebetteten
// Bereitstellungsprofil — also wird das gelesen.
//
// ZWEI DINGE SIND ZU UNTERSCHEIDEN, und die Verwechslung war der Fehler:
// Die Entitlements-Datei sagt, was die App VERLANGT; das Profil sagt, was
// ihr BEWILLIGT ist. Stimmen sie nicht überein, entsteht gar kein
// signierter Bau. Gelesen werden kann hier nur die zweite Hälfte — die
// erste steckt nach dem Signieren in der Binärdatei und nicht in einer
// Datei, an die eine App herankommt.
//
// ÜBER TESTFLIGHT UND AUS DEM LADEN LIEGT GAR KEIN PROFIL IM BÜNDEL. Apple
// signiert dort neu und entfernt es (dieselbe Beobachtung wie bei
// Schulalarm 1.0.19). Das ist kein Fehler und wird auch nicht als einer
// gemeldet: Die Zeile sagt dann, dass sich hier nichts messen lässt.
enum Profilrechte {
    struct Befund {
        // Lag ein Profil im Bündel? Nein heißt „über TestFlight oder aus
        // dem Laden installiert" und nicht „etwas ist kaputt".
        var profilVorhanden: Bool
        // Was das Profil bewilligt, Schlüssel für Schlüssel. Leer, wenn
        // sich nichts lesen ließ.
        var rechte: [String: Any]
        // Der rohe Grund, wenn das Lesen scheiterte. Roh, nicht gedeutet —
        // „mapped() gehört nicht in eine Diagnose".
        var fehler: String?

        // Wie das Profil heißt. Das ist die Zeile, an der sich ein
        // Entwicklungsprofil von einem Verteilprofil unterscheiden lässt.
        var name: String?
    }

    static func lesen() -> Befund {
        guard let ort = Bundle.main.url(forResource: "embedded",
                                        withExtension: "mobileprovision")
        else {
            return Befund(profilVorhanden: false, rechte: [:], fehler: nil,
                          name: nil)
        }
        guard let roh = try? Data(contentsOf: ort) else {
            return Befund(profilVorhanden: true, rechte: [:],
                          fehler: "Die Profildatei ließ sich nicht lesen.",
                          name: nil)
        }
        // Ein Profil ist ein signierter CMS-Umschlag; die Liste darin steht
        // im Klartext. Gesucht wird deshalb der XML-Abschnitt und nicht
        // etwa die ganze Datei als Liste gelesen — das schlüge fehl.
        guard let anfang = roh.range(of: Data("<?xml".utf8)),
              let ende = roh.range(of: Data("</plist>".utf8),
                                   options: .backwards)
        else {
            return Befund(profilVorhanden: true, rechte: [:],
                          fehler: "Im Profil steht keine lesbare Liste.",
                          name: nil)
        }
        // `Data(...)` um den Ausschnitt: Ein Teilstück behält die Indizes
        // des Ganzen, und ein Leser, der bei 0 anfängt, läse daneben.
        let abschnitt = Data(roh[anfang.lowerBound..<ende.upperBound])
        do {
            let liste = try PropertyListSerialization.propertyList(
                from: abschnitt, options: [], format: nil)
            guard let woerterbuch = liste as? [String: Any] else {
                return Befund(profilVorhanden: true, rechte: [:],
                              fehler: "Die Liste im Profil ist kein Wörterbuch.",
                              name: nil)
            }
            let rechte = woerterbuch["Entitlements"] as? [String: Any] ?? [:]
            return Befund(profilVorhanden: true, rechte: rechte, fehler: nil,
                          name: woerterbuch["Name"] as? String)
        } catch {
            return Befund(profilVorhanden: true, rechte: [:],
                          fehler: error.localizedDescription, name: nil)
        }
    }

    // Der Schlüssel, um den es in dieser Sache geht.
    static let schriftenschluessel = "com.apple.developer.user-fonts"

    // Nennt das Profil dieses Bauwerks das Schriftenrecht? Gebraucht
    // wird es an zwei Enden — für die Zeilen unten und für die Frage,
    // wohin der nächste Verdacht zeigt, wenn das System trotzdem nichts
    // hergibt (`Geraeteschriften.probe`). Zwei Fassungen liefen
    // auseinander, und dann stünde in einem Befund zweierlei.
    //
    // `nil` heißt hier „kein Profil im Bündel oder nicht lesbar" und
    // NICHT „nicht bewilligt" — über TestFlight und aus dem Laden liegt
    // gar keines da. Ein `false` daraus zu machen wäre genau die Lüge,
    // gegen die diese Datei gebaut ist.
    static func schriftenrechtBewilligt() -> Bool? {
        let befund = lesen()
        guard befund.profilVorhanden, befund.fehler == nil else { return nil }
        return befund.rechte[schriftenschluessel] != nil
    }

    // Die Zeilen für den kopierbaren Befund. Sie nennen Zahlen und
    // Zeichenketten und deuten nichts.
    static func zeilen() -> [String] {
        let befund = lesen()
        var zeilen: [String] = []
        guard befund.profilVorhanden else {
            zeilen.append("Bereitstellungsprofil: keines im Bündel.")
            zeilen.append("  Das ist der Normalfall über TestFlight und aus dem "
                + "App Store \u{2014} Apple signiert dort neu und entfernt es. "
                + "Was dieser Bau darf, lässt sich hier dann nicht messen.")
            return zeilen
        }
        if let fehler = befund.fehler {
            zeilen.append("Bereitstellungsprofil: vorhanden, aber nicht lesbar.")
            zeilen.append("  " + fehler)
            return zeilen
        }
        // STÜCK FÜR STÜCK IN EINE VARIABLE. Eine `+`-Kette, in der ein
        // `??` und eine Interpolation stecken, bringt den Typprüfer zum
        // Aufgeben („unable to type-check this expression in reasonable
        // time") — dieselbe Falle wie in 1.0.38.
        var kopf = "Bereitstellungsprofil: \u{201E}"
        kopf += befund.name ?? "ohne Namen"
        kopf += "\u{201C}, "
        kopf += String(befund.rechte.count)
        kopf += " bewilligte Rechte."
        zeilen.append(kopf)
        if let wert = befund.rechte[schriftenschluessel] {
            var zeile = "Schriftenrecht ("
            zeile += schriftenschluessel
            zeile += "): BEWILLIGT als "
            zeile += beschreibung(wert)
            zeile += "."
            zeilen.append(zeile)
            zeilen.append("  Seit 1.0.66 steht genau diese Zeichenkette in "
                + "Config/Urlaubstagebuch.entitlements. Steht hier etwas "
                + "anderes, bitte melden \u{2014} geraten wird sie nicht.")
        } else {
            var zeile = "Schriftenrecht ("
            zeile += schriftenschluessel
            zeile += "): steht NICHT im Profil."
            zeilen.append(zeile)
            zeilen.append("  Dann sieht diese App nur die Schriften des "
                + "Systems und die aus ihrem eigenen Bündel \u{2014} und die "
                + "Zahlen darunter sagen nichts über das Gerät aus. Das Recht "
                + "hängt an der App-Id: In der Entwicklerkonsole bekommt "
                + "de.familie.urlaubstagebuch die Fähigkeit \u{201E}Fonts\u{201C}, "
                + "danach in Xcode denselben Haken. Ein Recht, das die App-Id "
                + "nicht trägt, lässt sich nicht signieren \u{2014} deshalb "
                + "zuerst dort und erst dann im Repo.")
        }
        return zeilen
    }

    // Ein Wert aus einer Rechteliste kann ein Text, eine Zahl, ein
    // Wahrheitswert oder eine Reihe sein. Gezeigt wird er, wie er ist.
    private static func beschreibung(_ wert: Any) -> String {
        if let reihe = wert as? [Any] {
            let teile: [String] = reihe.map { beschreibung($0) }
            return "[" + teile.joined(separator: ", ") + "]"
        }
        if let text = wert as? String { return "\u{201E}" + text + "\u{201C}" }
        if let zahl = wert as? NSNumber { return zahl.stringValue }
        return String(describing: wert)
    }
}
