import CoreText
import UIKit

// SCHRIFTEN, DIE DER NUTZER SELBST AUF DAS GERÄT GELEGT HAT (ab 1.0.41).
//
// Gemeldet 09/2026: „Quicksand und … sind auf dem iPad installiert und
// können beispielsweise in Pages auch genutzt werden. In der App werden sie
// allerdings nicht einmal angezeigt."
//
// Der Grund steht in einer Zeile von `Schriftfamilie.alleDesGeraets`: Die
// Liste kommt aus `UIFont.familyNames`, und das ist das Verzeichnis DIESES
// PROZESSES — die Schriften des Systems und die, die eine App in ihrem
// Bündel mitbringt. Was jemand über eine Schriftverwaltung auf dem iPad
// installiert, liegt woanders; dafür gibt es seit iOS 13 den
// `UIFontPickerViewController`, und genau den zeigt Pages. Eine App, die
// nur aufzählt, sieht diese Schriften nie — sie ist nicht kaputt, sie
// fragt an der falschen Stelle.
//
// **Gemessen ist das hier nicht**, und deshalb behauptet diese Datei nichts:
// Sie versucht anzumelden und SIEHT danach nach, ob die Schrift unter ihrem
// Namen auffindbar ist (`befund`). Was dabei herauskommt, steht als Satz in
// der Schriftwahl. Dieselbe Bauweise wie die Stufenprobe bei Schulalarm.
enum Geraeteschriften {
    // MARK: - Anmelden

    // Eine über den Systemwähler gewählte Schrift für DIESEN Prozess
    // anmelden. `.process` und nicht `.persistent`: Wir wollen sie lesen,
    // nicht auf dem Gerät installieren — installiert hat sie der Nutzer
    // längst.
    //
    // Der Aufruf ist asynchron; hier wird nur angestoßen. Ob es gewirkt
    // hat, sagt nicht sein Rückgabewert, sondern der Blick danach:
    // `kennt(_:)`.
    static func anmelden(_ deskriptor: UIFontDescriptor) {
        CTFontManagerRegisterFontDescriptors(
            [deskriptor] as CFArray, .process, true, nil)
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

    static var gemerkte: [String] {
        UserDefaults.standard.stringArray(forKey: schluessel) ?? []
    }

    static func merken(_ name: String) {
        var liste = gemerkte
        guard !liste.contains(name) else { return }
        liste.append(name)
        UserDefaults.standard.set(liste, forKey: schluessel)
    }

    // Beim Start alles wieder anmelden, was einmal gewählt wurde.
    //
    // Nötig ist das, weil eine Anmeldung auf `.process` mit dem Prozess
    // endet. Möglich ist es nur über den NAMEN — der Deskriptor von damals
    // ist weg. Ob ein Deskriptor aus einem blossen Namen eine Schrift
    // findet, die dieser Prozess noch gar nicht kennt, ist offen; deshalb
    // wird das Ergebnis gezählt und nicht angenommen.
    @discardableResult
    static func beimStartAnmelden() -> (gesucht: Int, gefunden: Int) {
        let namen = gemerkte
        guard !namen.isEmpty else { return (0, 0) }
        let offene = namen.filter { !kennt($0) }
        if !offene.isEmpty {
            let deskriptoren = offene.map { UIFontDescriptor(name: $0, size: 12) }
            CTFontManagerRegisterFontDescriptors(
                deskriptoren as CFArray, .process, true, nil)
        }
        return (namen.count, namen.filter { kennt($0) }.count)
    }

    // MARK: - Der Befund

    // Was nach einer Wahl wirklich der Fall ist — ein Satz, kein Versprechen.
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
            + "sagt es noch einmal. Bitte melde das \u{2014} dieser Fall ist nicht "
            + "gemessen, sondern vorgesehen."
    }
}
