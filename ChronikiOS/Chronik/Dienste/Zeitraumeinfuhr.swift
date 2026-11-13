import Foundation
import Photos

// Alle Fotos eines Zeitraums holen, ohne sie einzeln anzutippen.
//
// Gemeldet 09/2026: „Beim Foto-Import muss ich bislang die Fotos einzeln
// auswählen. Ich möchte, dass sie alle ausgewählt werden können."
//
// Apples Fotowähler kann das nicht: `PHPickerViewController` kennt keinen
// Knopf „alle auswählen", und eine App kann ihm keinen einbauen — er läuft
// in einem eigenen Prozess, damit er OHNE Mediathekserlaubnis arbeiten
// darf. Was die App stattdessen tun kann, ist das Naheliegende für ein
// Reisetagebuch: nicht nach Bildern fragen, sondern nach einem ZEITRAUM.
// Eine Reise IST ein Zeitraum, und die Mediathek gibt ihn her, sobald die
// Erlaubnis da ist — dieselbe Erlaubnis, die die App ohnehin für die
// Aufnahmeorte braucht.
//
// Grenzen, und sie stehen auch in der Oberfläche:
//
//  - Ohne Mediathekserlaubnis geht es gar nicht. Der Weg daneben (der
//    Fotowähler) bleibt deshalb bestehen und ist nicht der Notbehelf,
//    sondern der Weg für alle anderen Fälle.
//  - Bei `.limited` liefert die Abfrage nur die ausdrücklich freigegebenen
//    Fotos. Das ist kein Fehler, aber es sieht aus wie einer, wenn es
//    niemand sagt.
//  - Der Zeitraum wird am `creationDate` gemessen, und das ist ein
//    Augenblick auf der Weltuhr. Die Grenzen werden deshalb in der
//    GERÄTEZONE gebildet — dieselbe ausdrückliche Ausnahme wie beim Datum
//    aus der Mediathek. Wer in Toronto fotografiert und zu Hause einliest,
//    kann an den Rändern einen Tag danebenliegen; deshalb ist der Zeitraum
//    frei wählbar und nicht fest.
enum Zeitraumeinfuhr {
    // Was in diesem Zeitraum liegt — ohne irgendetwas zu laden.
    static func zaehle(von: Tagesdatum, bis: Tagesdatum) -> Int {
        treffer(von: von, bis: bis)?.count ?? 0
    }

    static func treffer(von: Tagesdatum, bis: Tagesdatum) -> PHFetchResult<PHAsset>? {
        guard let anfang = beginn(von), let ende = beginn(bis.naechster()) else { return nil }
        let optionen = PHFetchOptions()
        optionen.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@",
                                         anfang as NSDate, ende as NSDate)
        optionen.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        return PHAsset.fetchAssets(with: .image, options: optionen)
    }

    // Die Bilddaten EINES Eintrags. Geladen wird immer nur eines — ein
    // Zeitraum kann tausend Fotos umfassen, und die passen zusammen nicht
    // in den Arbeitsspeicher. Der Aufrufer legt jedes sofort ab und lässt
    // es wieder los.
    static func rohbild(_ eintrag: PHAsset) async -> Rohbild? {
        let optionen = PHImageRequestOptions()
        // Ein Foto kann in iCloud liegen und nicht auf dem Gerät. Ohne
        // diese Zeile käme dann NICHTS zurück, ohne Fehler und ohne
        // Erklärung — der Zeitraum sähe halb leer aus.
        optionen.isNetworkAccessAllowed = true
        optionen.version = .current
        optionen.deliveryMode = .highQualityFormat
        optionen.isSynchronous = false

        let daten: Data? = await withCheckedContinuation { fortsetzen in
            // `requestImageDataAndOrientation` darf seinen Rückruf mehr als
            // einmal aufrufen. Ein zweites `resume` ist kein Fehler,
            // sondern ein ABSTURZ — deshalb der Wächter.
            let wachter = Einmal()
            PHImageManager.default().requestImageDataAndOrientation(for: eintrag,
                                                                    options: optionen)
            { rohdaten, _, _, _ in
                guard wachter.nimm() else { return }
                fortsetzen.resume(returning: rohdaten)
            }
        }
        guard let daten else { return nil }
        let name = PHAssetResource.assetResources(for: eintrag).first?.originalFilename
        return Rohbild(daten: daten,
                       kennung: eintrag.localIdentifier,
                       endung: endung(name),
                       name: name)
    }

    private static func endung(_ name: String?) -> String {
        guard let name else { return "jpg" }
        let gelesen = (name as NSString).pathExtension.lowercased()
        return gelesen.isEmpty ? "jpg" : gelesen
    }

    private static func beginn(_ datum: Tagesdatum) -> Date? {
        var teile = DateComponents()
        teile.year = datum.jahr
        teile.month = datum.monat
        teile.day = datum.tag
        return Calendar(identifier: .gregorian).date(from: teile)
    }

    private final class Einmal: @unchecked Sendable {
        private let sperre = NSLock()
        private var vergeben = false
        func nimm() -> Bool {
            sperre.lock()
            defer { sperre.unlock() }
            if vergeben { return false }
            vergeben = true
            return true
        }
    }
}

// KAPITELWEISE: ALLE FOTOS EINES ALBUMS (ab 1.0.5, Ansage des Nutzers
// 11/2026: „Für das Einlesen der Fotos möchte ich bitte auch auf ein Album
// meiner Galerie zugreifen können.").
//
// Derselbe Weg wie der Zeitraum: eine Abfrage an die Mediathek, dann Foto
// für Foto über `Zeitraumeinfuhr.rohbild` in `fotosAufnehmen` — dort
// bekommt jedes Foto sein Kapitel nach dem Aufnahmedatum. Gezeigt werden
// die eigenen Alben (auch geteilte und solche in Ordnern) und die
// Favoriten; leere Alben nicht.
enum Albumeinfuhr {
    struct Album: Identifiable, Hashable {
        let id: String
        let name: String
        let anzahl: Int
    }

    private static var nurBilder: PHFetchOptions {
        let optionen = PHFetchOptions()
        optionen.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        optionen.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        return optionen
    }

    static func alben() -> [Album] {
        var liste: [Album] = []
        var gesehen = Set<String>()
        let quellen = [
            PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumFavorites, options: nil),
            PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil),
        ]
        for quelle in quellen {
            for stelle in 0 ..< quelle.count {
                let sammlung = quelle.object(at: stelle)
                guard !gesehen.contains(sammlung.localIdentifier) else { continue }
                gesehen.insert(sammlung.localIdentifier)
                let anzahl = PHAsset.fetchAssets(in: sammlung, options: nurBilder).count
                guard anzahl > 0 else { continue }
                liste.append(Album(id: sammlung.localIdentifier,
                                   name: sammlung.localizedTitle ?? "Album",
                                   anzahl: anzahl))
            }
        }
        return liste.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func treffer(_ albumID: String) -> PHFetchResult<PHAsset>? {
        guard let sammlung = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [albumID], options: nil).firstObject else { return nil }
        return PHAsset.fetchAssets(in: sammlung, options: nurBilder)
    }
}
