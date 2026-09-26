import Foundation

// TEXTE EINER REISE ZUM ÜBERARBEITEN HINAUS UND WIEDER HEREIN (ab 1.0.27,
// Ansage des Nutzers 09/2026: „alle Tagebuchtexte einer Reise en bloc
// exportieren … um sie von einer KI sprachlich glätten zu können. Die
// überarbeitete Datei möchte ich dann wieder in die App einlesen können,
// sodass diese sich automatisch auf die einzelnen Tage verteilt und die
// jeweiligen Tageseinträge ersetzt.")
//
// **Eine schlichte Textdatei, keine JSON**: Sie geht durch einen KI-Chat,
// und der gibt Fließtext zurück — Klammern und Anführungszeichen einer JSON
// überlebten das nicht zuverlässig. Jeder Eintrag beginnt mit EINER
// Kennzeile:
//
//     === Eintrag 3F2A91C0 · Tag 2 · Sonntag, 29. März · 06:42 ===
//     Titel: Königssee
//
//     Fließtext …
//
// Zugeordnet wird beim Einlesen NUR über die Kennung (die ersten acht
// Zeichen der UUID des Eintrags) — nie über Reihenfolge oder Datum: Eine KI
// darf die Kopfzeile umformatieren (fett, Markdown-Überschrift), aber ein
// verschobener Tag darf nie einen Text an den falschen Eintrag hängen.
// Unbekannte Kennungen werden gezählt, nicht geraten.
//
// Ersetzt wird Text UND Titel (fehlt die Zeile „Titel:", bleibt der alte).
// Vorher wird der alte Stand in eine Datei gelegt (`Textstand`), und „Letzte
// Übernahme zurücknehmen" stellt ihn wieder her — ein Satz, den die KI
// glattgebügelt hat, soll nicht verloren sein.
//
// Einträge aus gesperrten Tagebüchern gehen nicht hinaus (dieselbe Regel wie
// bei Übergabe und Sicherung); Einträge, die ich nicht bearbeiten darf
// (Reise eines Miturlaubers als Betrachter), werden beim Einlesen
// übersprungen und gezählt.
@MainActor
enum Textglaettung {
    // MARK: - Hinaus

    /// Die Einträge, die hinausgehen — nach Zeit.
    static func eintraege(_ reise: Reise) -> [Eintrag] {
        reise.eintragListe
            .filter { !Buecherei.shared.istGesperrt($0.tagebuchName) && $0.kennung != nil }
            .sorted { ($0.datum ?? .distantPast) < ($1.datum ?? .distantPast) }
    }

    static func kurzkennung(_ e: Eintrag) -> String {
        String((e.kennung ?? UUID()).uuidString.prefix(8))
    }

    static func text(_ reise: Reise) -> String {
        let liste = eintraege(reise)
        let tage = reise.bisherigeTage.map { Tag.schluessel($0) }
        var zeilen: [String] = []
        zeilen.append("FERNWEH · Texte der Reise „\(reise.anzeigeTitel)“")
        zeilen.append("Stand \(Tag.text(Date(), "d. MMMM yyyy, HH:mm", zone: .current)) · \(liste.count) Einträge")
        zeilen.append("")
        zeilen.append("HINWEIS FÜR DIE ÜBERARBEITUNG: Bitte die Texte sprachlich glätten, ohne Inhalt hinzuzufügen oder wegzulassen. Die Zeilen, die mit „=== Eintrag“ beginnen, bitte UNVERÄNDERT an ihrer Stelle lassen, ebenso das Wort „Titel:“ am Anfang der Titelzeile — daran erkennt die App beim Einlesen, welcher Text zu welchem Eintrag gehört. Keine Einträge zusammenlegen, trennen oder umsortieren. Bitte die vollständige überarbeitete Fassung als reinen Text zurückgeben.")
        for e in liste {
            var kopf = "=== Eintrag \(kurzkennung(e))"
            if let t = e.tagSchluessel, let nummer = tage.firstIndex(of: t) { kopf += " · Tag \(nummer + 1)" }
            if let d = e.tagDatum { kopf += " · " + Tag.text(d, "EEEE, d. MMMM", zone: .current) }
            if e.eintragsart == .eintrag, e.datum != nil { kopf += " · " + e.uhrzeitText }
            if e.eintragsart == .seite { kopf += " · freie Seite" }
            if e.eintragsart == .wanderung { kopf += " · Wanderung" }
            kopf += " ==="
            zeilen.append("")
            zeilen.append(kopf)
            zeilen.append("Titel: " + (e.titel ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
            zeilen.append("")
            zeilen.append((e.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        }
        zeilen.append("")
        return zeilen.joined(separator: "\n")
    }

    /// Schreibt die Datei in den Zwischenordner.
    static func datei(_ reise: Reise) throws -> URL {
        let ordner = FileManager.default.temporaryDirectory.appendingPathComponent("Texte", isDirectory: true)
        try? FileManager.default.removeItem(at: ordner)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        let verboten = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let name = ("Texte " + reise.anzeigeTitel).components(separatedBy: verboten).joined(separator: "-")
        let ziel = ordner.appendingPathComponent(name + ".txt")
        try Data(text(reise).utf8).write(to: ziel)
        return ziel
    }

    // MARK: - Herein

    struct Block {
        let kennung: String
        let titel: String?
        let text: String
    }

    /// Zerlegt eine überarbeitete Fassung in Blöcke. Nachsichtig mit dem,
    /// was eine KI aus der Kopfzeile macht: „**=== Eintrag 3F2A91C0 …**",
    /// „### === Eintrag …", „== Eintrag …".
    static func bloecke(_ roh: String) -> [Block] {
        let kopf = try? NSRegularExpression(pattern: #"^[\s*#>_`]*={2,}\s*Eintrag\s+([0-9A-Fa-f]{8})"#)
        let titel = try? NSRegularExpression(pattern: #"^[\s*_#>`]*Titel\s*[:：][\s*_`]*(.*?)[\s*_`]*$"#,
                                             options: [.caseInsensitive])
        var ergebnis: [Block] = []
        var kennung: String?
        var titelzeile: String?
        var koerper: [String] = []
        var titelErlaubt = false

        func abschliessen() {
            guard let k = kennung else { return }
            var text = koerper.joined(separator: "\n")
            // Ein angehängter Schluss-Satz der KI („Ich hoffe, …") lässt
            // sich nicht sicher erkennen — er bleibt, und die Vorschau zeigt
            // ihn. Nur Leerzeilen und Trennstriche am Rand fallen weg.
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            while text.hasSuffix("---") || text.hasSuffix("***") {
                text = String(text.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            ergebnis.append(Block(kennung: k.uppercased(), titel: titelzeile, text: text))
        }

        for zeile in roh.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            let bereich = NSRange(zeile.startIndex..., in: zeile)
            if let treffer = kopf?.firstMatch(in: zeile, range: bereich),
               let r = Range(treffer.range(at: 1), in: zeile) {
                abschliessen()
                kennung = String(zeile[r])
                titelzeile = nil
                koerper = []
                titelErlaubt = true
                continue
            }
            guard kennung != nil else { continue }
            // Die Titelzeile gilt nur als erste nicht-leere Zeile nach dem
            // Kopf — ein „Titel:" mitten im Text ist Text.
            if titelErlaubt, !zeile.trimmingCharacters(in: .whitespaces).isEmpty {
                titelErlaubt = false
                if let t = titel?.firstMatch(in: zeile, range: bereich), let r = Range(t.range(at: 1), in: zeile) {
                    titelzeile = String(zeile[r]).trimmingCharacters(in: .whitespaces)
                    continue
                }
            }
            koerper.append(zeile)
        }
        abschliessen()
        return ergebnis
    }

    /// Ein Eintrag, dem ein neuer Text zugeordnet ist.
    struct Aenderung: Identifiable {
        let eintrag: Eintrag
        let neuerTitel: String
        let neuerText: String
        var id: String { Textglaettung.kurzkennung(eintrag) }
        var titelGeaendert: Bool { neuerTitel != (eintrag.titel ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
        var textGeaendert: Bool { neuerText != (eintrag.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    struct Zuordnung {
        var aenderungen: [Aenderung] = []
        var unveraendert = 0
        /// Kennungen in der Datei, die zu keinem Eintrag dieser Reise passen.
        var unbekannt: [String] = []
        /// Einträge der Reise, die in der Datei fehlen — sie bleiben.
        var fehlend = 0
        /// Einträge, die ich nicht bearbeiten darf.
        var gesperrt = 0
        /// Blöcke mit leerem Text — nie als „Text löschen" verstanden.
        var leer = 0
        var bloecke = 0
    }

    static func zuordnen(_ roh: String, reise: Reise) -> Zuordnung {
        var z = Zuordnung()
        let bloecke = bloecke(roh)
        z.bloecke = bloecke.count
        let liste = eintraege(reise)
        var nachKennung: [String: Eintrag] = [:]
        for e in liste { nachKennung[kurzkennung(e)] = e }
        var gesehen: Set<String> = []
        for b in bloecke {
            guard let e = nachKennung[b.kennung] else { z.unbekannt.append(b.kennung); continue }
            guard !gesehen.contains(b.kennung) else { continue }
            gesehen.insert(b.kennung)
            guard Persistenz.shared.darfBearbeiten(e) else { z.gesperrt += 1; continue }
            // Ein leerer Block löscht keinen Text: Das ist fast immer ein
            // Fehler beim Kopieren, kein Wunsch.
            let alterText = (e.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if b.text.isEmpty && !alterText.isEmpty { z.leer += 1; continue }
            let alterTitel = (e.titel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            // Ein leerer Titel nimmt keinen vorhandenen weg (wie beim Text).
            let neuerTitel = (b.titel ?? "").isEmpty ? alterTitel : (b.titel ?? "")
            let a = Aenderung(eintrag: e, neuerTitel: neuerTitel, neuerText: b.text)
            if a.titelGeaendert || a.textGeaendert { z.aenderungen.append(a) } else { z.unveraendert += 1 }
        }
        z.fehlend = liste.filter { !gesehen.contains(kurzkennung($0)) }.count
        return z
    }

    // MARK: - Übernehmen und zurücknehmen

    private struct Stand: Codable {
        struct Alt: Codable {
            let kennung: UUID
            let titel: String
            let text: String
        }
        let zeit: Date
        let alt: [Alt]
    }

    private static func standdatei(_ reise: Reise) -> URL? {
        guard let k = reise.kennung,
              let basis = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let ordner = basis.appendingPathComponent("Textstaende", isDirectory: true)
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        return ordner.appendingPathComponent(k.uuidString + ".json")
    }

    /// Ersetzt Titel und Text; merkt vorher den alten Stand.
    static func uebernehmen(_ aenderungen: [Aenderung], in reise: Reise) {
        guard !aenderungen.isEmpty else { return }
        let alt = aenderungen.compactMap { a -> Stand.Alt? in
            guard let k = a.eintrag.kennung else { return nil }
            return Stand.Alt(kennung: k, titel: a.eintrag.titel ?? "", text: a.eintrag.text ?? "")
        }
        if let ziel = standdatei(reise), let daten = try? JSONEncoder().encode(Stand(zeit: Date(), alt: alt)) {
            try? daten.write(to: ziel, options: .atomic)
        }
        for a in aenderungen {
            a.eintrag.titel = a.neuerTitel
            a.eintrag.text = a.neuerText
            a.eintrag.geaendert = Date()
        }
        Persistenz.shared.sichern()
    }

    /// Wann zuletzt übernommen wurde — `nil`, wenn nichts zurückzunehmen ist.
    static func letzteUebernahme(_ reise: Reise) -> Date? {
        guard let ziel = standdatei(reise), let daten = try? Data(contentsOf: ziel),
              let stand = try? JSONDecoder().decode(Stand.self, from: daten) else { return nil }
        return stand.zeit
    }

    /// Stellt den Stand vor der letzten Übernahme wieder her. Gibt die
    /// Zahl der zurückgesetzten Einträge zurück.
    @discardableResult
    static func zuruecknehmen(_ reise: Reise) -> Int {
        guard let ziel = standdatei(reise), let daten = try? Data(contentsOf: ziel),
              let stand = try? JSONDecoder().decode(Stand.self, from: daten) else { return 0 }
        var n = 0
        for alt in stand.alt {
            guard let e = reise.eintragListe.first(where: { $0.kennung == alt.kennung }),
                  Persistenz.shared.darfBearbeiten(e) else { continue }
            e.titel = alt.titel
            e.text = alt.text
            e.geaendert = Date()
            n += 1
        }
        Persistenz.shared.sichern()
        try? FileManager.default.removeItem(at: ziel)
        return n
    }
}
