import Foundation
import Photos

/// Ein Zeitraum ganzer Tage (beide Grenzen eingeschlossen), bezogen auf
/// das Aufnahmedatum (`PHAsset.creationDate`), nicht auf den Import.
struct Zeitraum: Codable, Hashable {
    let von: Date
    let bis: Date

    init(von: Date, bis: Date) {
        let kalender = Calendar.current
        self.von = kalender.startOfDay(for: min(von, bis))
        self.bis = kalender.startOfDay(for: max(von, bis))
    }

    var beginn: Date { von }
    /// Erster Augenblick NACH dem Zeitraum.
    var ende: Date { Calendar.current.date(byAdding: .day, value: 1, to: bis) ?? bis }

    var text: String {
        von == bis ? Formate.datum(von) : "\(Formate.datum(von)) – \(Formate.datum(bis))"
    }

    var schluessel: String { "\(von.timeIntervalSince1970)-\(bis.timeIntervalSince1970)" }
}

enum Schnellwahl: String, CaseIterable, Identifiable {
    case heute, woche, monat, jahr, alles

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .heute: return "Heute"
        case .woche: return "Letzte 7 Tage"
        case .monat: return "Letzter Monat"
        case .jahr: return "Letztes Jahr"
        case .alles: return "Gesamter Bestand"
        }
    }

    /// `nil` = gesamter Bestand.
    func zeitraum(jetzt: Date = Date()) -> Zeitraum? {
        let kalender = Calendar.current
        let heute = kalender.startOfDay(for: jetzt)
        switch self {
        case .heute:
            return Zeitraum(von: heute, bis: heute)
        case .woche:
            return Zeitraum(von: kalender.date(byAdding: .day, value: -6, to: heute) ?? heute, bis: heute)
        case .monat:
            return Zeitraum(von: kalender.date(byAdding: .month, value: -1, to: heute) ?? heute, bis: heute)
        case .jahr:
            return Zeitraum(von: kalender.date(byAdding: .year, value: -1, to: heute) ?? heute, bis: heute)
        case .alles:
            return nil
        }
    }
}

enum Standortfilter: String, CaseIterable, Identifiable, Codable {
    case alle, mitStandort, ohneStandort, bearbeitet

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .alle: return "Alle"
        case .mitStandort: return "Mit Ort"
        case .ohneStandort: return "Ohne Ort"
        case .bearbeitet: return "Bearbeitet"
        }
    }
}

/// Ein Tag in der Übersicht: die Fotos `bereich` der Liste.
struct Tagesabschnitt: Identifiable, Hashable {
    let tag: Date
    let bereich: Range<Int>
    var id: Int { bereich.lowerBound }
}

enum Abschnitte {
    /// Fasst aufeinanderfolgende Fotos desselben Kalendertags zusammen.
    /// Erwartet eine nach Datum sortierte Liste (auf- oder absteigend).
    static func bilden(daten: [Date?]) -> [Tagesabschnitt] {
        let kalender = Calendar.current
        var ergebnis: [Tagesabschnitt] = []
        var anfang = 0
        var aktuellerTag: Date?
        for (i, datum) in daten.enumerated() {
            let tag = kalender.startOfDay(for: datum ?? .distantPast)
            if tag != aktuellerTag {
                if let bisheriger = aktuellerTag {
                    ergebnis.append(Tagesabschnitt(tag: bisheriger, bereich: anfang..<i))
                }
                aktuellerTag = tag
                anfang = i
            }
        }
        if let letzter = aktuellerTag {
            ergebnis.append(Tagesabschnitt(tag: letzter, bereich: anfang..<daten.count))
        }
        return ergebnis
    }

    static func bilden(_ assets: [PHAsset]) -> [Tagesabschnitt] {
        bilden(daten: assets.map(\.creationDate))
    }
}

/// Ergebnis einer Suche. PHAsset ist unveränderlich und darf zwischen
/// Threads weitergereicht werden.
struct Suchergebnis: @unchecked Sendable {
    let assets: [PHAsset]
    let abschnitte: [Tagesabschnitt]
    /// Wie viele Fotos im Zeitraum angesehen wurden.
    let untersucht: Int
    /// Davon ohne Standort.
    let ohneStandort: Int
    /// Ohne Standort, aber von iOS gegen Änderungen gesperrt.
    let nichtAenderbar: Int
    let abgebrochen: Bool
}

/// Laden und Filtern der Fotos.
///
/// PhotoKit kann nicht nach dem Standort filtern (`location` ist im
/// Prädikat nicht erlaubt). Datum und Medientyp grenzt deshalb die
/// Datenbank ein; den Standort prüft die Suche selbst, Foto für Foto —
/// außerhalb des Hauptthreads, damit die Oberfläche nicht stockt.
enum FotoSuche {

    static func optionen(zeitraum: Zeitraum?, aufsteigend: Bool) -> PHFetchOptions {
        let optionen = PHFetchOptions()
        // Nur die eigene Mediathek: Fotos aus geteilten Alben oder vom
        // Computer synchronisierte Fotos lassen sich ohnehin nicht ändern.
        optionen.includeAssetSourceTypes = [.typeUserLibrary]
        optionen.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: aufsteigend)]
        var bedingungen = [NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)]
        if let zeitraum {
            bedingungen.append(NSPredicate(
                format: "creationDate >= %@ AND creationDate < %@",
                zeitraum.beginn as NSDate, zeitraum.ende as NSDate))
        }
        optionen.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: bedingungen)
        return optionen
    }

    /// Durchsucht die Mediathek.
    ///
    /// - Parameters:
    ///   - ids: nur diese Fotos (z. B. eine gespeicherte Sitzung).
    ///   - nurAenderbare: Fotos, die iOS gegen Änderungen sperrt, nicht in
    ///     die Liste aufnehmen (aber zählen).
    ///   - fortschritt: 0…1, wird gelegentlich von einem Hintergrundthread gerufen.
    static func durchsuchen(
        zeitraum: Zeitraum?,
        filter: Standortfilter,
        aufsteigend: Bool,
        ids: [String]? = nil,
        nurAenderbare: Bool = false,
        fortschritt: @escaping @Sendable (Double) -> Void = { _ in }
    ) async -> Suchergebnis {
        let optionen = optionen(zeitraum: zeitraum, aufsteigend: aufsteigend)
        let ergebnis: PHFetchResult<PHAsset>
        if let ids {
            ergebnis = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: optionen)
        } else {
            ergebnis = PHAsset.fetchAssets(with: optionen)
        }

        let gesamt = ergebnis.count
        var treffer: [PHAsset] = []
        treffer.reserveCapacity(filter == .alle || filter == .bearbeitet ? gesamt : gesamt / 4)
        var ohne = 0
        var gesperrt = 0
        var abgebrochen = false

        ergebnis.enumerateObjects { asset, index, stopp in
            if index % 250 == 0 {
                if Task.isCancelled {
                    abgebrochen = true
                    stopp.pointee = true
                    return
                }
                fortschritt(gesamt > 0 ? Double(index) / Double(gesamt) : 1)
            }
            let hatOrt = asset.location != nil
            if !hatOrt { ohne += 1 }
            switch filter {
            case .alle, .bearbeitet:
                treffer.append(asset)
            case .mitStandort:
                if hatOrt { treffer.append(asset) }
            case .ohneStandort:
                guard !hatOrt else { return }
                if nurAenderbare && !asset.canPerform(.properties) {
                    gesperrt += 1
                } else {
                    treffer.append(asset)
                }
            }
        }
        fortschritt(1)

        return Suchergebnis(
            assets: treffer,
            abschnitte: Abschnitte.bilden(treffer),
            untersucht: gesamt,
            ohneStandort: ohne,
            nichtAenderbar: gesperrt,
            abgebrochen: abgebrochen
        )
    }
}
