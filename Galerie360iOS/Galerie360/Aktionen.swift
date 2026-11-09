import CoreLocation
import Photos

/// Fehler beim Ändern einer Aufnahme — mit verständlichen deutschen Texten.
enum AenderungsFehler: LocalizedError {
    case nichtGefunden
    case nichtAenderbar
    case nichtBestaetigt
    case mediathek(String)

    var errorDescription: String? {
        switch self {
        case .nichtGefunden: return "Die Aufnahme ist nicht mehr in der Mediathek."
        case .nichtAenderbar: return "iOS erlaubt für diese Aufnahme keine Änderung — zum Beispiel bei Aufnahmen aus geteilten Alben oder vom Computer synchronisierten."
        case .nichtBestaetigt: return "Die Mediathek hat die Änderung nicht bestätigt. Bitte noch einmal versuchen."
        case .mediathek(let t): return t
        }
    }
}

/// Änderungen an Aufnahmen wie in der Fotos-App (seit 1.0.15, Galerie-Ersatz). Alles läuft
/// über `PHAssetChangeRequest` — die Datei selbst wird nie kopiert oder neu codiert. Datum und
/// Ort stehen danach in der Fotos-Datenbank und gleichen sich über iCloud ab, genau wie wenn
/// man sie in der Fotos-App ändert. Regeln für den Ort aus PhotoLocator übernommen
/// (`PhotoLocatoriOS/CLAUDE.md`): nach dem Schreiben neu lesen und vergleichen, Genauigkeit
/// 5 m, Höhe unbekannt, Zeitstempel = Aufnahmezeit.
enum Aenderungen {
    static func holen(_ id: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }

    private static func aendern(_ f: @escaping @Sendable () -> Void) async throws {
        do {
            try await PHPhotoLibrary.shared().performChanges(f)
        } catch {
            throw uebersetzen(error)
        }
    }

    /// Liest die Aufnahme nach dem Schreiben neu, bis `stimmt` zutrifft (die Datenbank hängt
    /// selten einen Moment hinterher) — erst dann gilt die Änderung als gelungen.
    private static func nachlesen(_ id: String, _ stimmt: (PHAsset) -> Bool) async throws -> PHAsset {
        for versuch in 0..<6 {
            if versuch > 0 { try? await Task.sleep(for: .milliseconds(250)) }
            guard let neu = holen(id) else { throw AenderungsFehler.nichtGefunden }
            if stimmt(neu) { return neu }
        }
        throw AenderungsFehler.nichtBestaetigt
    }

    private static func pruefen(_ a: PHAsset) throws {
        guard a.canPerform(.properties) else { throw AenderungsFehler.nichtAenderbar }
    }

    static func favorit(_ a: PHAsset, _ an: Bool) async throws -> PHAsset {
        try pruefen(a)
        let id = a.localIdentifier
        try await aendern {
            guard let z = holen(id) else { return }
            PHAssetChangeRequest(for: z).isFavorite = an
        }
        return try await nachlesen(id) { $0.isFavorite == an }
    }

    static func datum(_ a: PHAsset, _ d: Date) async throws -> PHAsset {
        try pruefen(a)
        let id = a.localIdentifier
        try await aendern {
            guard let z = holen(id) else { return }
            PHAssetChangeRequest(for: z).creationDate = d
        }
        return try await nachlesen(id) { abs(($0.creationDate ?? .distantPast).timeIntervalSince(d)) < 1 }
    }

    /// Setzt den Ort (oder entfernt ihn mit `nil`).
    static func ort(_ a: PHAsset, _ k: CLLocationCoordinate2D?) async throws -> PHAsset {
        try pruefen(a)
        let id = a.localIdentifier
        let neu = k.map {
            CLLocation(coordinate: $0, altitude: 0, horizontalAccuracy: 5, verticalAccuracy: -1,
                       timestamp: a.creationDate ?? Date())
        }
        try await aendern {
            guard let z = holen(id) else { return }
            PHAssetChangeRequest(for: z).location = neu
        }
        return try await nachlesen(id) { Koordinaten.gleich($0.location?.coordinate, k) }
    }

    /// Denselben Ort für mehrere Aufnahmen auf einmal (seit 1.0.24, für „Ohne Ort“). Zeitstempel
    /// je Aufnahme = ihre Aufnahmezeit, sonst wie `ort(_:_:)`. Danach neu gelesen; liefert die
    /// Zahl der Aufnahmen, die iOS nicht ändern lässt (geteilte Alben u. Ä.).
    static func ort(_ assets: [PHAsset], _ k: CLLocationCoordinate2D) async throws -> Int {
        let aenderbar = assets.filter { $0.canPerform(.properties) }
        let ids = aenderbar.map(\.localIdentifier)
        guard !ids.isEmpty else { return assets.count }
        let breite = k.latitude, laenge = k.longitude
        try await aendern {
            let ziel = CLLocationCoordinate2D(latitude: breite, longitude: laenge)
            PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil).enumerateObjects { z, _, _ in
                PHAssetChangeRequest(for: z).location = CLLocation(
                    coordinate: ziel, altitude: 0, horizontalAccuracy: 5, verticalAccuracy: -1,
                    timestamp: z.creationDate ?? Date())
            }
        }
        for versuch in 0..<6 {
            if versuch > 0 { try? await Task.sleep(for: .milliseconds(250)) }
            var alle = true
            PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil).enumerateObjects { z, _, stopp in
                if !Koordinaten.gleich(z.location?.coordinate, k) { alle = false; stopp.pointee = true }
            }
            if alle { return assets.count - aenderbar.count }
        }
        throw AenderungsFehler.nichtBestaetigt
    }

    static func ausblenden(_ assets: [PHAsset]) async throws {
        let ids = assets.map(\.localIdentifier)
        try await aendern {
            PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil).enumerateObjects { z, _, _ in
                if z.canPerform(.properties) { PHAssetChangeRequest(for: z).isHidden = true }
            }
        }
    }

    /// Löscht aus der Mediathek (iOS fragt selbst nach; landet in „Zuletzt gelöscht").
    static func loeschen(_ assets: [PHAsset]) async throws {
        let ids = assets.map(\.localIdentifier)
        try await aendern {
            PHAssetChangeRequest.deleteAssets(PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil))
        }
    }

    /// Legt Aufnahmen (als Verweis) ans Ende eines eigenen Albums; schon enthaltene bleiben, wo sie sind.
    static func hinzufuegen(_ assets: [PHAsset], zuAlbum albumId: String) async throws {
        guard let album = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumId], options: nil).firstObject else {
            throw AenderungsFehler.nichtGefunden
        }
        guard album.canPerform(.addContent) else { throw AenderungsFehler.nichtAenderbar }
        let vorhanden = PHAsset.fetchAssets(in: album, options: nil)
        var schon = Set<String>()
        vorhanden.enumerateObjects { x, _, _ in schon.insert(x.localIdentifier) }
        let neu = assets.filter { !schon.contains($0.localIdentifier) }
        guard !neu.isEmpty else { return }
        let stellen = IndexSet(integersIn: vorhanden.count..<(vorhanden.count + neu.count))
        try await aendern {
            PHAssetCollectionChangeRequest(for: album)?.insertAssets(neu as NSArray, at: stellen)
        }
    }

    static func uebersetzen(_ error: Error) -> Error {
        if error is AenderungsFehler { return error }
        if let p = error as? PHPhotosError {
            switch p.code {
            case .userCancelled: return p // Rückfrage von iOS abgebrochen — kein Fehler
            case .changeNotSupported: return AenderungsFehler.nichtAenderbar
            case .identifierNotFound: return AenderungsFehler.nichtGefunden
            case .notEnoughSpace: return AenderungsFehler.mediathek("Auf dem Gerät ist nicht genug Speicherplatz frei.")
            case .networkError: return AenderungsFehler.mediathek("Die Änderung scheiterte an einem Netzwerkfehler.")
            default: break
            }
        }
        return AenderungsFehler.mediathek("Die Fotomediathek hat die Änderung abgelehnt: \(error.localizedDescription)")
    }

    /// Abbruch in der Rückfrage von iOS (Löschen) — keine Fehlermeldung zeigen.
    static func abgebrochen(_ error: Error) -> Bool { (error as NSError).code == 3072 }
}
