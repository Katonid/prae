import Foundation

/// In welchem LAND eine Haltestelle liegt — abgelesen an ihrer Kennung.
///
/// **Warum es das gibt** (ab 1.1.21, Ansage des Nutzers 09/2026: „Ich hätte
/// gedacht, dass es irgendwo ein Verzeichnis gibt. So ist zum Beispiel
/// komplett klar, dass eine Fahrt mit der Bahn von München nach Salzburg …
/// auch auf österreichischem Gebiet vom Deutschlandticket abgedeckt wird.").
/// Bis 1.1.20 stand unter der Liste nur der Satz, der Filter kenne das Land
/// nicht. Das stimmte — und war eine Auskunft über die App statt über die
/// Fahrt.
///
/// **Ein Tarifverzeichnis gibt es in den Daten NICHT** (nachgemessen
/// 19.09.2026 an `/plan`): MOTIS kann GTFS-Fares, aber der DELFI-Datensatz
/// trägt keine — `debugOutput.fares` steht auf 0, und `agencyFareUrl` ist an
/// jedem Abschnitt leer. Was es gibt, ist das LAND, und zwar hier.
///
/// **Nur der Landesvorsatz der Kennung zählt.** Die Kennungen sehen so aus:
/// `de-DELFI_de:09162:100:5:9`, also `<Datensatz>_<Kennung des Verbunds>`.
/// Steht in der zweiten Hälfte ein zweibuchstabiger Vorsatz vor einem
/// Doppelpunkt, ist das die Landeskennung — gemessen an `de:` (Deutschland),
/// `at:` (Salzburg, Kufstein), `nl:` und `NL:` (Enschede, Venlo — die
/// Schreibweise wechselt, also wird ohne Rücksicht auf Groß- und
/// Kleinschreibung verglichen) und `ch:` (Basel).
///
/// **Zwei naheliegende Wege sind gemessen FALSCH, und beide in beide
/// Richtungen:**
///
/// 1. **Der Datensatz vorn sagt nicht das Land.** `nl-OpenOV_2860697` heißt
///    „Aachen Hbf" und `be-sncb_8015345` heißt „Aachen Hbf (DE)" — deutsche
///    Bahnhöfe in einem niederländischen und einem belgischen Datensatz.
///    Umgekehrt steht `de-DELFI_000008101912` für „Reutte in Tirol
///    Schulzentrum", also für Österreich im DEUTSCHEN Datensatz.
/// 2. **Rein numerische Kennungen sind keine UIC-Nummern.** Das sieht
///    verführerisch aus — „Ehrwald Zugspitzbahn" steht als `…008100089`, und
///    81 ist die UIC-Nummer Österreichs. Aber „Finkenwerder" in Hamburg
///    steht als `…015198010` und „Hannover Hauptbahnhof" als `…090031022`;
///    15 und 90 sind keine Länder. Die Zahlen gehören dem Datensatz, nicht
///    der Bahn.
///
/// Bleibt also: Vorsatz vorhanden → Land bekannt; sonst **unbekannt**. Und
/// unbekannt heißt unbekannt und NIE „Deutschland" — das ist die Richtung, in
/// der ein Fehler nichts kostet.
enum Landkennung {

    /// Das Land dieser Haltestellenkennung, als Kleinbuchstaben-Kürzel
    /// (`"de"`, `"at"`, `"nl"`, `"ch"`). `nil` heißt „steht nicht in der
    /// Kennung".
    static func land(vonKennung kennung: String) -> String? {
        // Alles vor dem ersten Unterstrich ist der Name des Datensatzes und
        // sagt über das Land nichts (siehe oben).
        let ohneDatensatz = kennung.split(separator: "_", maxSplits: 1).last.map(String.init) ?? kennung
        guard let doppelpunkt = ohneDatensatz.firstIndex(of: ":") else { return nil }
        let vorsatz = ohneDatensatz[ohneDatensatz.startIndex..<doppelpunkt]
        guard vorsatz.count == 2, vorsatz.allSatisfy(\.isLetter) else { return nil }
        return vorsatz.lowercased()
    }

    /// Der Name des Landes in der Oberfläche. Für die Nachbarn ausgeschrieben,
    /// sonst das Kürzel in Großbuchstaben — ein erfundener Name wäre
    /// schlimmer als ein nüchternes „PL".
    static func name(_ kuerzel: String) -> String {
        switch kuerzel {
        case "de": return "Deutschland"
        case "at": return "Österreich"
        case "ch": return "die Schweiz"
        case "nl": return "die Niederlande"
        case "be": return "Belgien"
        case "lu": return "Luxemburg"
        case "fr": return "Frankreich"
        case "dk": return "Dänemark"
        case "pl": return "Polen"
        case "cz": return "Tschechien"
        default: return kuerzel.uppercased()
        }
    }

    /// Dasselbe im Wen-Fall, für „fährt nach …". Deutsch verlangt hier
    /// zweierlei („nach Österreich", aber „in die Niederlande"), und ein
    /// falscher Fall liest sich wie ein Fehler in der App.
    static func wohin(_ kuerzel: String) -> String {
        switch kuerzel {
        case "ch": return "in die Schweiz"
        case "nl": return "in die Niederlande"
        default: return "nach \(name(kuerzel))"
        }
    }
}
