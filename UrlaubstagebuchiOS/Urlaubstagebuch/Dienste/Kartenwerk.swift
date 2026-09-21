import MapKit
import SwiftUI
import UIKit

enum Kartenstil: String, Codable, CaseIterable, Identifiable {
    case gedaempft
    case standard
    case gelaende
    case satellit

    var id: String { rawValue }

    var name: String {
        switch self {
        case .gedaempft: return "Zurückhaltend"
        case .standard: return "Standard"
        case .gelaende: return "Gelände"
        case .satellit: return "Satellit"
        }
    }

    var aufbau: MKMapConfiguration {
        switch self {
        case .gedaempft:
            return MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        case .standard:
            return MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .default)
        case .gelaende:
            let aufbau = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
            aufbau.pointOfInterestFilter = .excludingAll
            return aufbau
        case .satellit:
            return MKImageryMapConfiguration(elevationStyle: .flat)
        }
    }
}

// Die Karte auf einer Buchseite ist ein BILD, keine Karte.
//
// Das ist eine Entscheidung mit drei Wirkungen auf einmal. Erstens sieht das
// PDF genauso aus wie die Ansicht — eine lebende `Map` ließe sich nicht in
// eine Seite drucken, ohne sie doch wieder abzufotografieren. Zweitens
// schluckt sie keine Geste: Auf der Seite wird geschoben, gezoomt und
// gewählt, und ein Kartenausschnitt mitten darin nähme jeden Finger an, der
// ihn berührt (dieselbe Lehre wie in der Abfahrtstafel). Drittens bleibt
// das Bild stehen, wenn das Gerät gerade kein Netz hat.
//
// Gewählt wird der Ausschnitt dagegen auf einer ECHTEN Karte, in einem
// eigenen Bildschirm — dort ist die Karte die Hauptsache und darf alles.
actor Kartenwerk {
    static let shared = Kartenwerk()

    private var vorrat: [String: UIImage] = [:]
    private var laufend: [String: Task<UIImage?, Never>] = [:]

    private func schluessel(_ punkte: [Koordinate], groesse: CGSize, stil: Kartenstil,
                            linie: Farbwert, ausschnitt: Kartenausschnitt?) -> String
    {
        let orte = punkte.map { String(format: "%.5f,%.5f", $0.breite, $0.laenge) }.joined(separator: ";")
        let rahmen = ausschnitt.map { String(format: "%.5f,%.5f,%.5f", $0.mitte.breite, $0.mitte.laenge, $0.spanne) } ?? "auto"
        return "\(orte)|\(Int(groesse.width))x\(Int(groesse.height))|\(stil.rawValue)|\(linie.rot),\(linie.gruen),\(linie.blau)|\(rahmen)"
    }

    func bild(punkte: [Koordinate], groesse: CGSize, stil: Kartenstil, linienfarbe: Farbwert,
              ausschnitt: Kartenausschnitt?) async -> UIImage?
    {
        guard groesse.width > 8, groesse.height > 8 else { return nil }
        let merker = schluessel(punkte, groesse: groesse, stil: stil, linie: linienfarbe,
                                ausschnitt: ausschnitt)
        if let da = vorrat[merker] { return da }
        if let laeuft = laufend[merker] { return await laeuft.value }

        let auftrag = Task<UIImage?, Never> { [stil, linienfarbe] in
            await Self.zeichnen(punkte: punkte, groesse: groesse, stil: stil,
                                linienfarbe: linienfarbe, ausschnitt: ausschnitt)
        }
        laufend[merker] = auftrag
        let ergebnis = await auftrag.value
        laufend[merker] = nil
        if let ergebnis { vorrat[merker] = ergebnis }
        // Der Vorrat wird gedeckelt, nicht aufgeräumt: Kartenbilder sind
        // groß, und ein Buch mit dreißig Tagen hätte sonst dreißig davon im
        // Speicher, jedes in zwei Größen.
        if vorrat.count > 24 { vorrat.removeAll() }
        return ergebnis
    }

    func vergessen() {
        vorrat.removeAll()
    }

    private static func region(_ punkte: [Koordinate], ausschnitt: Kartenausschnitt?)
        -> MKCoordinateRegion
    {
        if let ausschnitt {
            return MKCoordinateRegion(
                center: ausschnitt.mitte.clLocation,
                span: MKCoordinateSpan(latitudeDelta: ausschnitt.spanne,
                                       longitudeDelta: ausschnitt.spanne)
            )
        }
        guard let erster = punkte.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 48.137, longitude: 11.575),
                span: MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 3)
            )
        }
        var minB = erster.breite, maxB = erster.breite
        var minL = erster.laenge, maxL = erster.laenge
        for punkt in punkte {
            minB = min(minB, punkt.breite)
            maxB = max(maxB, punkt.breite)
            minL = min(minL, punkt.laenge)
            maxL = max(maxL, punkt.laenge)
        }
        let mitte = CLLocationCoordinate2D(latitude: (minB + maxB) / 2, longitude: (minL + maxL) / 2)
        // Ein Viertel Rand, und ein Mindestmaß: Liegen alle Punkte auf
        // demselben Fleck, wäre die Spanne null und die Karte zeigte einen
        // einzelnen Pflasterstein.
        let spanneB = max((maxB - minB) * 1.35, 0.008)
        let spanneL = max((maxL - minL) * 1.35, 0.008)
        return MKCoordinateRegion(
            center: mitte,
            span: MKCoordinateSpan(latitudeDelta: spanneB, longitudeDelta: spanneL)
        )
    }

    private static func zeichnen(punkte: [Koordinate], groesse: CGSize, stil: Kartenstil,
                                 linienfarbe: Farbwert, ausschnitt: Kartenausschnitt?) async -> UIImage?
    {
        let wunsch = MKMapSnapshotter.Options()
        wunsch.region = region(punkte, ausschnitt: ausschnitt)
        wunsch.size = groesse
        wunsch.scale = 2
        wunsch.preferredConfiguration = stil.aufbau

        let aufnahme: MKMapSnapshotter.Snapshot
        do {
            aufnahme = try await MKMapSnapshotter(options: wunsch).start()
        } catch {
            return nil
        }

        let zeichner = UIGraphicsImageRenderer(size: groesse)
        return zeichner.image { zusammenhang in
            aufnahme.image.draw(at: .zero)
            let stellen = punkte.map { aufnahme.point(for: $0.clLocation) }
            guard !stellen.isEmpty else { return }
            let feder = zusammenhang.cgContext

            if stellen.count >= 2 {
                // Erst eine helle Kontur, dann die Linie. Ohne sie
                // verschwindet ein dunkler Strich über dunklem Wald und ein
                // heller über hellem Meer — dieselbe Rechnung wie bei den
                // Linienzügen der Abfahrtstafel.
                let weg = UIBezierPath()
                weg.move(to: stellen[0])
                for stelle in stellen.dropFirst() { weg.addLine(to: stelle) }
                weg.lineCapStyle = .round
                weg.lineJoinStyle = .round
                feder.setStrokeColor(UIColor.white.withAlphaComponent(0.85).cgColor)
                weg.lineWidth = max(groesse.width / 90, 4.2)
                weg.stroke()
                feder.setStrokeColor(linienfarbe.uiFarbe.cgColor)
                weg.lineWidth = max(groesse.width / 150, 2.4)
                weg.stroke()
            }

            let radius = max(groesse.width / 110, 3.4)
            for (stelle, punkt) in stellen.enumerated() {
                let gross = stelle == 0 || stelle == stellen.count - 1
                let r = gross ? radius * 1.5 : radius
                let kreis = UIBezierPath(ovalIn: CGRect(x: punkt.x - r, y: punkt.y - r,
                                                        width: r * 2, height: r * 2))
                feder.setFillColor(UIColor.white.cgColor)
                kreis.fill()
                feder.setFillColor(linienfarbe.uiFarbe.cgColor)
                let innen = UIBezierPath(ovalIn: CGRect(x: punkt.x - r * 0.58, y: punkt.y - r * 0.58,
                                                        width: r * 1.16, height: r * 1.16))
                innen.fill()
            }
        }
    }
}

// Ein von Hand gewählter Kartenausschnitt. Ohne ihn rahmt die Karte die
// Spur selbst — das ist fast immer richtig und manchmal nicht: Wer einen
// Tagesausflug in einer Stadt zeigt, will die Stadt sehen und nicht das
// Land drumherum.
struct Kartenausschnitt: Codable, Hashable {
    var mitte: Koordinate
    var spanne: Double
}
