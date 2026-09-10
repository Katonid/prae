//  Alarmklang.swift
//  Welcher Ton ein Alarm auf DIESEM iPad macht — und wie er dorthin kommt.
//
//  Die Schule möchte einen Probealarm (und im Zweifel auch einen echten)
//  zunächst vor den Kindern verbergen. Ein durchdringendes Zweitonsignal auf
//  dreißig iPads ist dafür unbrauchbar (Ansage des Nutzers, 09/2026).
//
//  Zwei Dinge, die dabei zusammenhängen und leicht verwechselt werden:
//
//  * **Die Lautstärke steckt in der DATEI.** Seit 1.0.29 sind kritische
//    Hinweise an, und die spielen mit `withAudioVolume: 1.0` — unabhängig
//    davon, wie laut das iPad gestellt ist. Genau das war der Sinn der Sache:
//    Ein stummgeschaltetes iPad wird trotzdem laut. Eine Lautstärke-Einstellung
//    in der App gäbe es also gar nicht zu setzen; leise wird ein Ton nur
//    dadurch, dass er leise GERECHNET ist (`scripts/make-sounds.py`).
//  * **Die Erweiterung kennt die Wahl nicht.** Sie ist ein eigener Prozess mit
//    eigenem Behälter. Gemeinsame Einstellungen bräuchten eine App-Gruppe und
//    damit eine Entitlements-Datei an der Erweiterung — das eine, was dieses
//    Projekt schon einmal unsignierbar gemacht hat.
//
//  Daraus folgt der Aufbau hier: Die Erweiterung nennt IMMER denselben
//  Dateinamen (`PushAsset.signalSound`), und die App legt unter diesem Namen
//  den gewählten Ton ab. Der Name ist fest, die Datei wechselt.

import Foundation

/// Die vier mitgelieferten Töne.
///
/// Einer laut, drei leise. Mehr Auswahl wäre keine Hilfe: Wer im Ernstfall
/// überlegen muss, welchen Ton er gerade hört, hat schon verloren.
enum Alarmklang: String, CaseIterable, Identifiable {
    case alarm
    case dezent
    case holz
    case tropfen
    /// Eine selbst mitgebrachte Datei. Sie liegt nicht im Bündel, sondern in
    /// Application Support — siehe `Eigenklang`.
    case eigen

    var id: String { rawValue }

    /// Die Vorlage im App-Bündel — `nil` beim eigenen Ton.
    var datei: String? {
        switch self {
        case .alarm: return "alarm.wav"
        case .dezent: return "dezent.wav"
        case .holz: return "holz.wav"
        case .tropfen: return "tropfen.wav"
        case .eigen: return nil
        }
    }

    /// Woher die Datei kommt — Bündel oder Application Support.
    ///
    /// Die eine Stelle, an der die beiden Herkünfte zusammenlaufen. Wer sie
    /// umgeht, baut den zweiten Weg ein zweites Mal.
    var quelle: URL? {
        guard let datei else { return Eigenklang.datei }
        let teile = datei.split(separator: ".")
        guard teile.count == 2 else { return nil }
        return Bundle.main.url(forResource: String(teile[0]),
                               withExtension: String(teile[1]))
    }

    /// Steht dieser Ton überhaupt zur Verfügung?
    var vorhanden: Bool { quelle != nil }

    var titel: String {
        switch self {
        case .alarm: return "Alarm"
        case .dezent: return "Dezent"
        case .holz: return "Holzton"
        case .tropfen: return "Tropfen"
        case .eigen: return Eigenklang.name ?? "Eigener Ton"
        }
    }

    var beschreibung: String {
        switch self {
        case .alarm:
            return "Zwei Töne im Wechsel, 25 Sekunden, laut. Nicht zu "
                 + "überhören und nicht zu verbergen."
        case .dezent:
            return "Weiche Doppelnote wie eine Kalendererinnerung, 10 "
                 + "Sekunden, leise. Klingt nach Termin, nicht nach Gefahr."
        case .holz:
            return "Warmer Marimba-Anschlag, 10 Sekunden, leise. Der "
                 + "unauffälligste Ton, der noch als Meldung durchgeht."
        case .tropfen:
            return "Kurzes Blubb mit fallender Tonhöhe, 10 Sekunden, sehr "
                 + "leise. Wer nicht darauf wartet, hört ein Geräusch."
        case .eigen:
            return Eigenklang.datei == nil
                ? "Noch keine Datei gewählt. WAV, AIFF, CAF, MP3 oder M4A, "
                + "höchstens 30 Sekunden — die App rechnet sie um und macht "
                + "sie so leise wie „Holzton“."
                : "Selbst mitgebracht, umgerechnet und auf dieselbe "
                + "Lautstärke gebracht wie die leisen Töne."
        }
    }

    /// Hört eine Klasse diesen Ton?
    ///
    /// Beim eigenen Ton: nein — er wird beim Übernehmen auf dieselbe Spitze
    /// normiert wie „Holzton". Was er BEDEUTET, weiß die App trotzdem nicht;
    /// eine Sirene bleibt eine Sirene, auch leise.
    var verraetSichVorDerKlasse: Bool { self == .alarm }

    static let vorgabe = Alarmklang.alarm
}

/// Legt den gewählten Ton dort ab, wo iOS ihn beim Zustellen sucht.
///
/// `UNNotificationSound(named:)` schlägt an genau zwei Stellen nach: ganz oben
/// im App-Bündel und in `Library/Sounds` des App-Behälters. Der Name
/// `signal.wav` kommt im Bündel bewusst NICHT vor — sonst wäre nicht
/// entschieden, welche der beiden Fassungen gewinnt.
enum Klanginstallation {

    /// Was zuletzt eingesetzt wurde. Ohne diesen Vermerk würden bei jedem
    /// Start zwei Megabyte umkopiert.
    private static let vermerk = "alarmklang.eingesetzt"

    static var ordner: URL? {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("Sounds", isDirectory: true)
    }

    static var ziel: URL? {
        ordner?.appendingPathComponent(PushAsset.signalSound)
    }

    /// Sorgt dafür, dass `signal.wav` den gewählten Ton enthält.
    ///
    /// Läuft bei jedem Start. Geschrieben wird nur, wenn sich die Wahl
    /// geändert hat oder die Datei fehlt — Letzteres kommt vor: Eine
    /// Wiederherstellung aus einer Sicherung bringt `Library/Sounds` nicht
    /// zwingend mit.
    ///
    /// Gibt im Fehlerfall den ROHEN Grund zurück, sonst `nil`. Er landet in
    /// der Diagnose und nicht in einem hübschen Satz: „Ton kommt an, aber es
    /// ist der falsche" sieht sonst genauso aus wie ein Tippfehler im Namen.
    @discardableResult
    static func sicherstellen(_ klang: Alarmklang,
                              erzwingen: Bool = false,
                              defaults: UserDefaults = .standard) -> String? {
        guard let ordner, let ziel else {
            return "Library/Sounds ist auf diesem Gerät nicht zu finden."
        }
        let liegtDa = FileManager.default.fileExists(atPath: ziel.path)
        // Beim eigenen Ton sagt der Vermerk nichts: Wer eine neue Datei
        // wählt, ändert den Inhalt und nicht den Namen der Wahl. Also immer
        // schreiben — es ist eine Datei unter zwei Megabyte.
        let unveraendert = defaults.string(forKey: vermerk) == klang.rawValue
            && klang != .eigen
        if liegtDa, unveraendert, !erzwingen { return nil }

        guard let quelle = klang.quelle else {
            return klang == .eigen
                ? "Es ist kein eigener Ton hinterlegt."
                : "\(klang.datei ?? klang.rawValue) liegt nicht im App-Bündel."
        }
        do {
            try FileManager.default.createDirectory(at: ordner,
                                                    withIntermediateDirectories: true)
            // Erst weg, dann hin: `copyItem` schreibt nicht über eine
            // vorhandene Datei, und ein stillschweigend gescheitertes
            // Ersetzen wäre der schlimmste Ausgang — der alte Ton bliebe,
            // und niemand wüsste warum.
            if liegtDa { try FileManager.default.removeItem(at: ziel) }
            try FileManager.default.copyItem(at: quelle, to: ziel)
            defaults.set(klang.rawValue, forKey: vermerk)
            return nil
        } catch {
            return "\(klang.datei ?? klang.rawValue) ließ sich nicht "
                 + "einsetzen: \(error.localizedDescription)"
        }
    }

    /// Für die Diagnose: Was liegt gerade da, und wie groß ist es?
    static func befund() -> String {
        guard let ziel else { return "Library/Sounds: nicht zu finden" }
        guard let werte = try? FileManager.default.attributesOfItem(atPath: ziel.path),
              let groesse = werte[.size] as? Int else {
            return "\(PushAsset.signalSound): FEHLT — es spielte der Standardton"
        }
        let name = UserDefaults.standard.string(forKey: vermerk) ?? "unbekannt"
        return "\(PushAsset.signalSound): \(groesse / 1024) KiB (\(name))"
    }
}
