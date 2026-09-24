import Foundation

// WO DIE VORLAGEN LIEGEN — eine Datei je Vorlage, neben den Büchern.
//
// Der Nutzer wollte sie „möglichst auch in der Cloud" (Ansage 09/2026).
// Das ist mit einer Zeile zu haben, und zwar ohne eine zweite
// Abgleichsmaschine: Die Bücher liegen seit 1.0.4 als gewöhnliche Dateien
// in iCloud Drive, und ein Ordner daneben gleicht sich genauso ab. Was
// diese App dafür tun muss, ist eine Datei je Vorlage zu schreiben statt
// einer Liste in den Voreinstellungen — dann überträgt iCloud jede
// einzeln, und zwei Geräte, die gleichzeitig je eine anlegen, haben
// hinterher beide.
//
// **Warum nicht in den Voreinstellungen** (wie `Formatvorlagen` seit
// 1.0.52): Die reisen nicht. Eine Liste unter einem Schlüssel wäre
// obendrein die schlechteste Art, sie abzugleichen — zwei Geräte
// überschrieben einander die ganze Liste, statt je eine Datei zu ergänzen.
//
// **Warum eine eigene Endung** (`.reisevorlage`): Weil sie exportierbar
// sein soll, und eine Datei, die im Teilen-Blatt „Unbekannt" heißt, findet
// später niemand wieder. Der Inhalt ist schlichtes JSON — anders als eine
// `.reisebuch`-Datei trägt eine Vorlage keine Bilder und braucht deshalb
// kein eigenes Format.
enum Vorlagenablage {
    static let endung = "reisevorlage"
    static let ordnername = "Vorlagen"

    /// Der Ordner liegt NEBEN `Reisen` und damit auf derselben Seite wie
    /// die Bücher: Ist der Abgleich an, liegt er in iCloud; ist er aus,
    /// auf dem Gerät. Eine zweite Meinung darüber, wo etwas liegt, wären
    /// zwei Ablagen (dieselbe Regel wie bei `Ablage.wurzel`).
    static var wurzel: URL {
        let ort = Wolke.wurzel.deletingLastPathComponent()
            .appendingPathComponent(ordnername, isDirectory: true)
        try? FileManager.default.createDirectory(at: ort, withIntermediateDirectories: true)
        return ort
    }

    static func datei(_ id: UUID) -> URL {
        wurzel.appendingPathComponent("\(id.uuidString).\(endung)")
    }

    // MARK: - Lesen und Schreiben

    static func alle() -> [Vorlage] {
        // Was in iCloud liegt, liegt nicht unbedingt auf dem Gerät.
        herunterladenAnstossen()
        guard let inhalt = try? FileManager.default.contentsOfDirectory(
            at: wurzel, includingPropertiesForKeys: nil)
        else { return [] }
        var gefunden: [Vorlage] = []
        for ort in inhalt where ort.pathExtension == endung {
            guard let daten = try? Data(contentsOf: ort),
                  let vorlage = try? Ablage.leser().decode(Vorlage.self, from: daten)
            else { continue }
            gefunden.append(vorlage)
        }
        return gefunden.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    static func alle(_ art: Vorlage.Art) -> [Vorlage] {
        alle().filter { $0.art == art }
    }

    @discardableResult
    static func sichern(_ vorlage: Vorlage) throws -> URL {
        let daten = try Ablage.kodierer().encode(vorlage)
        let ziel = datei(vorlage.id)
        // Über eine temporäre Datei, wie bei den Büchern: Eine halb
        // geschriebene Vorlage ließe sich nicht mehr lesen und wäre für
        // den Menschen davor eine, die einfach verschwunden ist.
        let zwischen = ziel.appendingPathExtension("neu")
        try daten.write(to: zwischen, options: .atomic)
        if FileManager.default.fileExists(atPath: ziel.path) {
            _ = try FileManager.default.replaceItemAt(ziel, withItemAt: zwischen)
        } else {
            try FileManager.default.moveItem(at: zwischen, to: ziel)
        }
        return ziel
    }

    static func loeschen(_ vorlage: Vorlage) {
        try? FileManager.default.removeItem(at: datei(vorlage.id))
    }

    // MARK: - Austausch

    /// Eine Vorlage als Datei zum Weitergeben. Sie bekommt den NAMEN der
    /// Vorlage und nicht ihre Kennung: Im Teilen-Blatt und in „Dateien"
    /// steht dann „Saal Digital 21x28.reisevorlage" und nicht eine Reihe
    /// Hexadezimalziffern.
    static func zumTeilen(_ vorlage: Vorlage) throws -> URL {
        let daten = try Ablage.kodierer().encode(vorlage)
        let ziel = FileManager.default.temporaryDirectory
            .appendingPathComponent(dateiname(vorlage))
        try? FileManager.default.removeItem(at: ziel)
        try daten.write(to: ziel, options: .atomic)
        return ziel
    }

    private static func dateiname(_ vorlage: Vorlage) -> String {
        let erlaubt = CharacterSet.alphanumerics.union(.init(charactersIn: " -_äöüÄÖÜß"))
        let sauber = vorlage.name.unicodeScalars
            .map { erlaubt.contains($0) ? Character($0) : Character("-") }
        let name = String(sauber).trimmingCharacters(in: .whitespaces)
        return (name.isEmpty ? "Vorlage" : name) + "." + endung
    }

    /// Eine hereingereichte Datei ansehen. Sie bekommt beim Einlesen eine
    /// NEUE Kennung: Zwei Geräte, die dieselbe Vorlage weitergeben,
    /// sollen nicht einander die Datei überschreiben — und wer eine
    /// Vorlage zweimal einliest, hat zwei, nicht eine halb ersetzte.
    static func einlesen(_ ort: URL) throws -> Vorlage {
        let daten = try Data(contentsOf: ort)
        var vorlage = try Ablage.leser().decode(Vorlage.self, from: daten)
        vorlage.id = UUID()
        if alle().contains(where: {
            $0.name.caseInsensitiveCompare(vorlage.name) == .orderedSame && $0.art == vorlage.art
        }) {
            vorlage.name += " (eingelesen)"
        }
        try sichern(vorlage)
        return vorlage
    }

    // MARK: - Für neue Bücher

    // WELCHE VORLAGE EIN NEUES BUCH BEKOMMT.
    //
    // Gemerkt wird die KENNUNG, nicht die Vorlage: Wer sie später ändert,
    // will die geänderte — eine Kopie an dieser Stelle liefe auseinander.
    // Gibt es die Vorlage nicht mehr, ist es keine, und das neue Buch
    // bekommt die Vorgaben der App.
    //
    // **Sie steht in den VOREINSTELLUNGEN und nicht in der Wolke**, und
    // das ist Absicht: „Welche Vorlage schlägt dieses Gerät beim Anlegen
    // vor" ist eine Gewohnheit dieses Geräts. Die Vorlagen selbst reisen.
    static func vorgabe(_ art: Vorlage.Art) -> Vorlage? {
        guard let text = UserDefaults.standard.string(forKey: vorgabeschluessel(art)),
              let id = UUID(uuidString: text)
        else { return nil }
        return alle(art).first { $0.id == id }
    }

    static func vorgabeSetzen(_ art: Vorlage.Art, _ vorlage: Vorlage?) {
        let schluessel = vorgabeschluessel(art)
        if let vorlage {
            UserDefaults.standard.set(vorlage.id.uuidString, forKey: schluessel)
        } else {
            UserDefaults.standard.removeObject(forKey: schluessel)
        }
    }

    private static func vorgabeschluessel(_ art: Vorlage.Art) -> String {
        "vorlageVorgabe-" + art.rawValue
    }

    // MARK: - iCloud

    /// Dieselbe Sache wie bei den Büchern: Was in iCloud liegt, liegt
    /// nicht unbedingt schon auf dem Gerät. Ohne diesen Anstoß stünde eine
    /// Vorlage in der Liste, die sich nicht öffnen lässt — oder sie stünde
    /// gar nicht erst da.
    static func herunterladenAnstossen() {
        guard Wolke.stand == .an else { return }
        let dateien = FileManager.default
        guard let inhalt = try? dateien.contentsOfDirectory(
            at: wurzel, includingPropertiesForKeys: [.ubiquitousItemDownloadingStatusKey])
        else { return }
        for ort in inhalt {
            let werte = try? ort.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if werte?.ubiquitousItemDownloadingStatus == .current { continue }
            try? dateien.startDownloadingUbiquitousItem(at: ort)
        }
    }
}
