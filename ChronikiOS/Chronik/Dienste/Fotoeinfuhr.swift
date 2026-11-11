import Photos
import PhotosUI
import UIKit
import UniformTypeIdentifiers

// FOTOS ÜBERNEHMEN — aus der Mediathek (Fotowähler) oder aus Dateien.
//
// Das Datum kommt in dieser Reihenfolge:
//   1. EXIF der Datei (Aufnahmezeit, Uhr am Aufnahmeort),
//   2. der Mediathekseintrag (`PHAsset.creationDate`) — nur, wenn die App
//      Zugriff hat; der Fotowähler selbst braucht keinen,
//   3. bei Dateien das Erstellungsdatum der Datei,
//   4. jetzt.
// Jedes Datum lässt sich danach von Hand ändern.
enum Fotoeinfuhr {
    static func einlesen(_ ergebnisse: [PHPickerResult]) async -> [Fotoeintrag] {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        let darf = status == .authorized || status == .limited
        var liste: [Fotoeintrag] = []
        for r in ergebnisse {
            guard let datei = await datei(r.itemProvider) else { continue }
            var ersatz: Date?
            if darf, let kennung = r.assetIdentifier {
                ersatz = PHAsset.fetchAssets(withLocalIdentifiers: [kennung], options: nil).firstObject?.creationDate
            }
            liste.append(eintrag(datei: datei, ersatzdatum: ersatz))
        }
        return liste
    }

    /// Kopiert das Bild eines Treffers in die Ablage.
    static func datei(_ anbieter: NSItemProvider) async -> String? {
        let typ = anbieter.registeredTypeIdentifiers.first { UTType($0)?.conforms(to: .image) == true }
            ?? UTType.image.identifier
        return await withCheckedContinuation { (fortsetzung: CheckedContinuation<String?, Never>) in
            _ = anbieter.loadFileRepresentation(forTypeIdentifier: typ) { adresse, _ in
                // Die Datei gilt nur innerhalb dieses Rückrufs — sofort kopieren.
                guard let adresse else {
                    fortsetzung.resume(returning: nil)
                    return
                }
                fortsetzung.resume(returning: try? Medien.ablegen(kopieVon: adresse))
            }
        }
    }

    static func ausDatei(_ adresse: URL) -> Fotoeintrag? {
        guard let datei = try? Medien.ablegen(kopieVon: adresse) else { return nil }
        let werte = try? adresse.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return eintrag(datei: datei, ersatzdatum: werte?.creationDate ?? werte?.contentModificationDate)
    }

    static func eintrag(datei: String, ersatzdatum: Date?) -> Fotoeintrag {
        let info = Medien.bildinfo(Medien.url(datei))
        return Fotoeintrag(datei: datei,
                           zeit: info.datum ?? ersatzdatum ?? Date(),
                           breite: info.breite,
                           hoehe: info.hoehe)
    }
}
