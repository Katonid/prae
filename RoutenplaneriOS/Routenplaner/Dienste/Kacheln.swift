import MapKit
import UIKit

/// Holt Kartenkacheln so, wie es die Nutzungsrichtlinie der OSM Foundation
/// verlangt (gelesen, nicht vermutet — dieselben Regeln wie im Reisebuch):
/// eigener User-Agent, ein Zwischenspeicher, der die Verfallszeiten des
/// Servers achtet, höchstens zwei Verbindungen je Server. Und KEIN
/// Vorausladen: Geholt wird nur, was die Karte gerade zeigen will.
enum Kacheln {
    static let sitzung: URLSession = {
        let k = URLSessionConfiguration.default
        k.timeoutIntervalForRequest = 20
        k.httpMaximumConnectionsPerHost = 2
        k.requestCachePolicy = .useProtocolCachePolicy
        let ordner = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Kacheln", isDirectory: true)
        k.urlCache = URLCache(memoryCapacity: 24 * 1024 * 1024,
                              diskCapacity: 256 * 1024 * 1024,
                              directory: ordner)
        k.httpAdditionalHeaders = ["User-Agent": "Routenplaner-iOS/1.0 (privat; github.com/katonid/prae)"]
        return URLSession(configuration: k)
    }()
}

/// Eine Kachelschicht auf der MapKit-Karte.
final class Kachelschicht: MKTileOverlay {
    let quelle: Kachelquelle

    init(quelle: Kachelquelle) {
        self.quelle = quelle
        super.init(urlTemplate: nil)
        canReplaceMapContent = quelle.ersetzt
        tileSize = CGSize(width: 256, height: 256)
        minimumZ = 0
        // Tiefer als der Dienst rendert, vergrößert die App selbst (siehe
        // `loadTile`). Ohne das bliebe die Karte beim Hineinzoomen leer.
        maximumZ = 21
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        quelle.adresse(z: path.z, x: path.x, y: path.y) ?? URL(string: "about:blank")!
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let tiefer = path.z - quelle.hoechsteStufe
        guard tiefer > 0 else {
            holen(z: path.z, x: path.x, y: path.y, result: result)
            return
        }
        // Mehr als viermal vergrößert ist nur noch Brei; dann lieber nichts.
        guard tiefer <= 4 else { result(nil, nil); return }
        let n = 1 << tiefer
        holen(z: quelle.hoechsteStufe, x: path.x >> tiefer, y: path.y >> tiefer) { daten, fehler in
            guard let daten, let bild = UIImage(data: daten)?.cgImage else {
                result(nil, fehler)
                return
            }
            let teil = CGFloat(bild.width) / CGFloat(n)
            let ausschnitt = CGRect(x: CGFloat(path.x % n) * teil, y: CGFloat(path.y % n) * teil,
                                    width: teil, height: teil)
            guard let stueck = bild.cropping(to: ausschnitt) else { result(nil, nil); return }
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = self.quelle.ersetzt
            let groesse = CGSize(width: bild.width, height: bild.height)
            let vergroessert = UIGraphicsImageRenderer(size: groesse, format: format).image { _ in
                UIImage(cgImage: stueck).draw(in: CGRect(origin: .zero, size: groesse))
            }
            result(vergroessert.pngData(), nil)
        }
    }

    private func holen(z: Int, x: Int, y: Int, result: @escaping (Data?, Error?) -> Void) {
        guard let url = quelle.adresse(z: z, x: x, y: y) else { result(nil, nil); return }
        Kacheln.sitzung.dataTask(with: url) { daten, antwort, fehler in
            let status = (antwort as? HTTPURLResponse)?.statusCode ?? 0
            result(status == 200 ? daten : nil, fehler)
        }.resume()
    }
}
