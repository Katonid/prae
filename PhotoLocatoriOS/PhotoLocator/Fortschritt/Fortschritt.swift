import Foundation

/// Reine Logik des Bearbeitungsfortschritts — ohne PhotoKit, darum testbar.
enum Fortschritt {

    /// Das nächste noch nicht erledigte Foto nach `index`.
    ///
    /// Reihenfolge der Wahl:
    /// 1. vorwärts (am Ende von vorn weiter) das nächste Foto, das weder
    ///    erledigt noch übersprungen ist;
    /// 2. gibt es keins mehr, das nächste übersprungene;
    /// 3. sonst `nil` — dann ist nichts mehr offen außer höchstens dem
    ///    Foto bei `index` selbst.
    ///
    /// So kommen übersprungene Fotos erst wieder, wenn alles andere
    /// abgearbeitet ist — sie gehen aber nie verloren.
    static func naechsterOffener(
        nach index: Int,
        ids: [String],
        erledigt: Set<String>,
        uebersprungen: Set<String>
    ) -> Int? {
        let anzahl = ids.count
        guard anzahl > 0 else { return nil }
        let start = min(max(index, -1), anzahl - 1)
        let reihenfolge = (1...anzahl).lazy
            .map { (start + $0 + anzahl) % anzahl }
            .filter { $0 != start }

        if let frisch = reihenfolge.first(where: {
            !erledigt.contains(ids[$0]) && !uebersprungen.contains(ids[$0])
        }) {
            return frisch
        }
        return reihenfolge.first(where: { !erledigt.contains(ids[$0]) })
    }

    /// Das Foto, mit dem eine fortgesetzte Sitzung beginnt: das zuletzt
    /// gezeigte, falls noch offen — sonst das nächste offene danach.
    static func startIndex(
        zuletzt: Int?,
        ids: [String],
        erledigt: Set<String>,
        uebersprungen: Set<String>
    ) -> Int {
        guard !ids.isEmpty else { return 0 }
        let ab = min(max(zuletzt ?? 0, 0), ids.count - 1)
        if !erledigt.contains(ids[ab]) && !uebersprungen.contains(ids[ab]) {
            return ab
        }
        return naechsterOffener(nach: ab, ids: ids, erledigt: erledigt, uebersprungen: uebersprungen) ?? ab
    }

    /// „Foto 37 von 128“
    static func titel(position: Int, gesamt: Int) -> String {
        "Foto \(Formate.zahl(position)) von \(Formate.zahl(gesamt))"
    }

    /// „noch 91 Fotos“ / „noch 1 Foto“ / „alle erledigt“
    static func rest(offen: Int) -> String {
        switch offen {
        case ...0: return "alle erledigt"
        case 1: return "noch 1 Foto"
        default: return "noch \(Formate.zahl(offen)) Fotos"
        }
    }

    /// „Foto 37 von 128 – noch 91 Fotos“
    static func text(position: Int, gesamt: Int, offen: Int) -> String {
        "\(titel(position: position, gesamt: gesamt)) – \(rest(offen: offen))"
    }
}
