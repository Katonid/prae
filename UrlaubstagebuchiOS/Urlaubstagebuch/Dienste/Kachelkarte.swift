import CoreLocation
import MapKit
import UIKit

// Eine Karte aus KACHELN — der zweite Weg neben Apples Aufnahme.
//
// Warum es ihn gibt: Apple Karten sind die einzige Quelle, die iOS von
// Hause aus mitbringt, und ihr Aussehen ist nicht verhandelbar. Wer eine
// topographische Karte mit Höhenlinien in sein Buch will oder das
// vertraute Bild von OpenStreetMap, bekommt es dort nicht. Kacheln sind
// dagegen nichts als quadratische Bilder unter einer Adresse, und damit
// steht jede Karte offen, die jemand im Netz ausliefert.
//
// Drei Dinge sind dabei Pflicht und keine Zugabe:
//
//  * **Ein eigener User-Agent.** Die Nutzungsrichtlinie der OpenStreetMap
//    Foundation (abgerufen 21.09.2026) weist Anfragen mit der Vorgabe einer
//    Bibliothek ausdrücklich ab — sie können den Anrufer nicht erkennen und
//    sperren deshalb. Es steht also der Name dieser App darin und eine
//    Adresse, unter der man sie findet. Keine E-Mail des Nutzers: Die geht
//    einen Kachelserver nichts an.
//  * **Ein Zwischenspeicher.** Dieselbe Richtlinie verlangt, die
//    Verfallszeiten des Servers zu achten. Gemessen am selben Tag:
//    `max-age=16144` bei OpenStreetMap, `max-age=604800` bei OpenTopoMap.
//    `URLCache` mit `useProtocolCachePolicy` tut genau das.
//  * **Ein Deckel.** Ein Buch mit dreißig Tagen holt sonst für jede Karte
//    beliebig viele Kacheln. `hoechstzahlKacheln` bricht die Auflösung
//    lieber ab, als einen fremden Server zu belasten, den niemand dafür
//    bezahlt.
//
// Was hier NICHT gebaut wird, und zwar mit Absicht: ein Knopf, der eine
// Gegend im Voraus lädt. Genau das nennt die Richtlinie als verboten
// („bulk downloading", „offline use"). Geholt wird, was auf einer Seite
// steht, und sonst nichts.
enum Kachelkarte {
    static let hoechstzahlKacheln = 48
    private static let kantenlaenge: CGFloat = 256

    // Ein eigener Speicher, damit die Kacheln nicht im selben Topf liegen
    // wie alles andere und beim ersten Speicherdruck verschwinden.
    private static let sitzung: URLSession = {
        let aufbau = URLSessionConfiguration.default
        aufbau.urlCache = URLCache(memoryCapacity: 16 << 20, diskCapacity: 256 << 20,
                                   directory: FileManager.default.urls(
                                       for: .cachesDirectory, in: .userDomainMask)[0]
                                       .appendingPathComponent("Kacheln"))
        aufbau.requestCachePolicy = .useProtocolCachePolicy
        aufbau.httpAdditionalHeaders = ["User-Agent": kennung]
        aufbau.timeoutIntervalForRequest = 20
        return URLSession(configuration: aufbau)
    }()

    static var kennung: String {
        let fassung = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "1"
        return "Reisebuch/\(fassung) (+https://katonid.github.io/prae/)"
    }

    struct Untergrund {
        let bild: UIImage
        // Wo eine Koordinate im gelieferten Bild liegt — in Punkten, also
        // in derselben Rechnung wie Apples `point(for:)`.
        // Bewusst NICHT `@Sendable`: Apples Schnappschuss ist keine
        // sendbare Klasse, und der Untergrund entsteht und vergeht
        // innerhalb einer einzigen Funktion.
        let stelle: (Koordinate) -> CGPoint
    }

    // MARK: - Die Rechnung

    // Web-Mercator: die Projektion, in der jede Kachelkarte der Welt liegt.
    // `zoom` verdoppelt die Welt mit jeder Stufe; bei Stufe 0 ist sie 256
    // Punkte breit.
    static func weltpunkt(_ ort: Koordinate, zoom: Int) -> CGPoint {
        let welt = Double(kantenlaenge) * pow(2, Double(zoom))
        let x = (ort.laenge + 180) / 360 * welt
        // Die Breite wird am Pol unendlich — abgeschnitten wird bei rund
        // 85 Grad, wie in jeder Kachelkarte. Ohne die Klammer liefe `tan`
        // gegen unendlich und das Bild wäre leer.
        let breite = min(max(ort.breite, -85.05112878), 85.05112878) * .pi / 180
        let y = (1 - log(tan(breite) + 1 / cos(breite)) / .pi) / 2 * welt
        return CGPoint(x: x, y: y)
    }

    // MARK: - Das Bild

    static func untergrund(region: MKCoordinateRegion, groesse: CGSize,
                           massstab: CGFloat, bild: Kartenbild) async -> Untergrund?
    {
        guard let vorlage = bild.kachelvorlage, groesse.width > 8, groesse.height > 8 else {
            return nil
        }
        let gewuenscht = CGSize(width: groesse.width * massstab, height: groesse.height * massstab)

        let nord = region.center.latitude + region.span.latitudeDelta / 2
        let sued = region.center.latitude - region.span.latitudeDelta / 2
        let west = region.center.longitude - region.span.longitudeDelta / 2
        let ost = region.center.longitude + region.span.longitudeDelta / 2

        // Die Zoomstufe wird GESUCHT, nicht gerechnet: Genommen wird die
        // höchste, die noch unter dem Deckel bleibt und nicht feiner ist,
        // als das Zielbild auflösen kann. Eine Stufe zu hoch kostet die
        // vierfache Zahl Kacheln für nichts.
        var zoom = 1
        for stufe in 1...bild.hoechsterZoom {
            let feld = ausschnitt(nord: nord, sued: sued, west: west, ost: ost,
                                  zoom: stufe, seitenverhaeltnis: groesse.width / groesse.height)
            let kacheln = zahlDerKacheln(feld)
            if kacheln > hoechstzahlKacheln { break }
            zoom = stufe
            if feld.width >= gewuenscht.width { break }
        }

        let feld = ausschnitt(nord: nord, sued: sued, west: west, ost: ost,
                              zoom: zoom, seitenverhaeltnis: groesse.width / groesse.height)
        let spalteVon = Int(floor(feld.minX / kantenlaenge))
        let spalteBis = Int(floor((feld.maxX - 0.5) / kantenlaenge))
        let zeileVon = Int(floor(feld.minY / kantenlaenge))
        let zeileBis = Int(floor((feld.maxY - 0.5) / kantenlaenge))

        // Zeilen ausserhalb der Welt gibt es nicht — wer über den Pol
        // rahmt, bekommt dort weißes Papier und keine fehlende Karte.
        // Spalten dagegen laufen um: Über den Pazifik geht es weiter.
        let zeilenDerWelt = 1 << zoom
        var wuensche: [(spalte: Int, zeile: Int)] = []
        for zeile in zeileVon...zeileBis where zeile >= 0 && zeile < zeilenDerWelt {
            for spalte in spalteVon...spalteBis { wuensche.append((spalte, zeile)) }
        }
        guard !wuensche.isEmpty, wuensche.count <= hoechstzahlKacheln else { return nil }

        let geholt = await kacheln(wuensche, vorlage: vorlage, zoom: zoom,
                                   weltbreite: zeilenDerWelt)
        // Eine Karte mit Löchern ist im Druck schlimmer als gar keine: Eine
        // weiße Fläche mitten in der Stadt sieht aus wie eine Aussage.
        guard geholt.count == wuensche.count else { return nil }

        // Erst das MOSAIK in voller Kachelauflösung, dann einmal
        // verkleinern. Jede Kachel einzeln in das verkleinerte Bild zu
        // zeichnen wäre der naheliegende Weg und hinterließe an jeder
        // Kachelgrenze einen hellen Haarstrich: Die Ränder lägen auf
        // gebrochenen Bildpunkten, und die Glättung rechnet dort mit dem
        // weißen Grund. Im Mosaik liegen sie auf ganzen Zahlen.
        let spalten = spalteBis - spalteVon + 1
        let zeilen = zeileBis - zeileVon + 1
        let mosaikGroesse = CGSize(width: CGFloat(spalten) * kantenlaenge,
                                   height: CGFloat(zeilen) * kantenlaenge)
        let mosaikForm = UIGraphicsImageRendererFormat()
        mosaikForm.scale = 1
        mosaikForm.opaque = true
        mosaikForm.preferredRange = .standard
        let mosaik = UIGraphicsImageRenderer(size: mosaikGroesse, format: mosaikForm).image { lage in
            UIColor.white.setFill()
            lage.fill(CGRect(origin: .zero, size: mosaikGroesse))
            for (schluessel, kachel) in geholt {
                kachel.draw(in: CGRect(x: CGFloat(schluessel.spalte - spalteVon) * kantenlaenge,
                                       y: CGFloat(schluessel.zeile - zeileVon) * kantenlaenge,
                                       width: kantenlaenge, height: kantenlaenge))
            }
        }

        let faktor = groesse.width / feld.width
        let versatzX = (CGFloat(spalteVon) * kantenlaenge - feld.minX) * faktor
        let versatzY = (CGFloat(zeileVon) * kantenlaenge - feld.minY) * faktor

        let form = UIGraphicsImageRendererFormat()
        form.scale = massstab
        form.opaque = true
        // STANDARDBEREICH heißt sRGB (ab 1.0.89). Ohne diese Zeile nimmt
        // der Zeichner den erweiterten Bereich des Geräts, und die Karte
        // trüge ein anderes Profil als alles andere in der Datei.
        form.preferredRange = .standard
        let zeichner = UIGraphicsImageRenderer(size: groesse, format: form)
        let fertig = zeichner.image { zusammenhang in
            UIColor.white.setFill()
            zusammenhang.fill(CGRect(origin: .zero, size: groesse))
            zusammenhang.cgContext.interpolationQuality = .high
            mosaik.draw(in: CGRect(x: versatzX, y: versatzY,
                                   width: mosaikGroesse.width * faktor,
                                   height: mosaikGroesse.height * faktor))
        }

        let ursprungX = feld.minX
        let ursprungY = feld.minY
        let stufe = zoom
        return Untergrund(bild: fertig, stelle: { ort in
            let punkt = weltpunkt(ort, zoom: stufe)
            return CGPoint(x: (punkt.x - ursprungX) * faktor, y: (punkt.y - ursprungY) * faktor)
        })
    }

    // Der Ausschnitt in Weltpunkten, auf das Seitenverhältnis des Blocks
    // gezogen. Ohne dieses Ziehen stünde die Karte verzerrt auf der Seite —
    // Apples Aufnahme macht dasselbe von selbst.
    private static func ausschnitt(nord: Double, sued: Double, west: Double, ost: Double,
                                   zoom: Int, seitenverhaeltnis: CGFloat) -> CGRect
    {
        let obenLinks = weltpunkt(Koordinate(breite: nord, laenge: west), zoom: zoom)
        let untenRechts = weltpunkt(Koordinate(breite: sued, laenge: ost), zoom: zoom)
        var minX = min(obenLinks.x, untenRechts.x)
        var maxX = max(obenLinks.x, untenRechts.x)
        var minY = min(obenLinks.y, untenRechts.y)
        var maxY = max(obenLinks.y, untenRechts.y)
        var breite = max(maxX - minX, 1)
        var hoehe = max(maxY - minY, 1)
        if breite / hoehe < seitenverhaeltnis {
            let neu = hoehe * seitenverhaeltnis
            minX -= (neu - breite) / 2
            maxX += (neu - breite) / 2
            breite = neu
        } else {
            let neu = breite / seitenverhaeltnis
            minY -= (neu - hoehe) / 2
            maxY += (neu - hoehe) / 2
            hoehe = neu
        }
        return CGRect(x: minX, y: minY, width: breite, height: hoehe)
    }

    private static func zahlDerKacheln(_ feld: CGRect) -> Int {
        let spalten = Int(floor((feld.maxX - 0.5) / kantenlaenge)) - Int(floor(feld.minX / kantenlaenge)) + 1
        let zeilen = Int(floor((feld.maxY - 0.5) / kantenlaenge)) - Int(floor(feld.minY / kantenlaenge)) + 1
        return max(spalten, 1) * max(zeilen, 1)
    }

    // MARK: - Das Netz

    private struct Feld: Hashable { let spalte: Int; let zeile: Int }

    private static func kacheln(_ wuensche: [(spalte: Int, zeile: Int)], vorlage: String,
                                zoom: Int, weltbreite: Int) async -> [Feld: UIImage]
    {
        var ergebnis: [Feld: UIImage] = [:]
        // In Gruppen zu sechs, nicht alle auf einmal: Vierzig gleichzeitige
        // Anfragen an einen Spendenserver sind genau das Verhalten, wegen
        // dem Richtlinien geschrieben werden.
        for haufen in stride(from: 0, to: wuensche.count, by: 6) {
            let teil = wuensche[haufen..<min(haufen + 6, wuensche.count)]
            await withTaskGroup(of: (Feld, UIImage?).self) { gruppe in
                for wunsch in teil {
                    let feld = Feld(spalte: wunsch.spalte, zeile: wunsch.zeile)
                    gruppe.addTask {
                        (feld, await kachel(feld, vorlage: vorlage, zoom: zoom,
                                            weltbreite: weltbreite))
                    }
                }
                for await (feld, bild) in gruppe {
                    if let bild { ergebnis[feld] = bild }
                }
            }
        }
        return ergebnis
    }

    private static func kachel(_ feld: Feld, vorlage: String, zoom: Int,
                               weltbreite: Int) async -> UIImage?
    {
        // Über den Rand hinaus wird umgebrochen: Wer über den Pazifik
        // rahmt, bekommt sonst eine halbe leere Karte. Über den Polen gibt
        // es dagegen nichts umzubrechen.
        guard feld.zeile >= 0, feld.zeile < weltbreite else { return nil }
        let spalte = ((feld.spalte % weltbreite) + weltbreite) % weltbreite
        let unterdienst = ["a", "b", "c"][abs(spalte &+ feld.zeile) % 3]
        let text = vorlage
            .replacingOccurrences(of: "{z}", with: String(zoom))
            .replacingOccurrences(of: "{x}", with: String(spalte))
            .replacingOccurrences(of: "{y}", with: String(feld.zeile))
            .replacingOccurrences(of: "{s}", with: unterdienst)
        guard let adresse = URL(string: text) else { return nil }
        do {
            let (daten, antwort) = try await sitzung.data(from: adresse)
            guard let http = antwort as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return UIImage(data: daten)
        } catch {
            return nil
        }
    }
}
