import MapKit
import SwiftUI
import UIKit

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
//
// Woher der Untergrund kommt, entscheidet `Kartenbild.quelle`: Apple nimmt
// ihn auf, alle anderen werden aus Kacheln zusammengesetzt. Die Spur, die
// Punkte und der Lizenzhinweis werden danach für BEIDE Wege an genau einer
// Stelle gezeichnet — zwei Zeichenwege ergäben zwei Karten.
actor Kartenwerk {
    static let shared = Kartenwerk()

    private var vorrat: [String: UIImage] = [:]
    private var laufend: [String: Task<UIImage?, Never>] = [:]

    private func schluessel(_ punkte: [Koordinate], groesse: CGSize, bild: Kartenbild,
                            linie: Farbwert, ausschnitt: Kartenausschnitt?) -> String
    {
        let orte = punkte.map { String(format: "%.5f,%.5f", $0.breite, $0.laenge) }.joined(separator: ";")
        let rahmen = ausschnitt.map { String(format: "%.5f,%.5f,%.5f", $0.mitte.breite, $0.mitte.laenge, $0.spanne) } ?? "auto"
        return "\(orte)|\(Int(groesse.width))x\(Int(groesse.height))|\(bild.merkmal)|\(linie.rot),\(linie.gruen),\(linie.blau)|\(rahmen)"
    }

    func bild(punkte: [Koordinate], groesse: CGSize, kartenbild: Kartenbild,
              linienfarbe: Farbwert, ausschnitt: Kartenausschnitt?) async -> UIImage?
    {
        guard groesse.width > 8, groesse.height > 8 else { return nil }
        let merker = schluessel(punkte, groesse: groesse, bild: kartenbild, linie: linienfarbe,
                                ausschnitt: ausschnitt)
        if let da = vorrat[merker] { return da }
        if let laeuft = laufend[merker] { return await laeuft.value }

        let auftrag = Task<UIImage?, Never> { [kartenbild, linienfarbe] in
            await Self.zeichnen(punkte: punkte, groesse: groesse, kartenbild: kartenbild,
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

    static func region(_ punkte: [Koordinate], ausschnitt: Kartenausschnitt?)
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

    // Der Maßstab steht FEST auf 2 und kommt nicht vom Bildschirm.
    // `UIGraphicsImageRenderer` nähme sonst `UIScreen.main.scale` — und dann
    // hinge die Auflösung der gedruckten Karte daran, auf welchem Gerät das
    // Buch gerade offen war.
    private static let massstab: CGFloat = 2

    private static func zeichnen(punkte: [Koordinate], groesse: CGSize, kartenbild: Kartenbild,
                                 linienfarbe: Farbwert, ausschnitt: Kartenausschnitt?) async -> UIImage?
    {
        let feld = region(punkte, ausschnitt: ausschnitt)
        // Entschieden wird an der QUELLE und nicht daran, ob eine Adresse
        // dasteht. Sonst bekäme eine eigene Quelle ohne Adresse
        // stillschweigend eine Apple-Karte — und der Nutzer hielte seinen
        // Kachelserver für einen, der genau so aussieht.
        let untergrund: Kachelkarte.Untergrund?
        if kartenbild.quelle == .apple {
            untergrund = await appleAufnahme(region: feld, groesse: groesse, kartenbild: kartenbild)
        } else {
            guard kartenbild.vollstaendig else { return nil }
            untergrund = await Kachelkarte.untergrund(region: feld, groesse: groesse,
                                                      massstab: massstab, bild: kartenbild)
        }
        guard let untergrund else { return nil }

        let form = UIGraphicsImageRendererFormat()
        form.scale = massstab
        form.opaque = true
        let zeichner = UIGraphicsImageRenderer(size: groesse, format: form)
        return zeichner.image { zusammenhang in
            untergrund.bild.draw(in: CGRect(origin: .zero, size: groesse))
            let feder = zusammenhang.cgContext
            let stellen = punkte.map(untergrund.stelle)

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

            zeichneNachweis(kartenbild.nachweis, groesse: groesse, feder: feder)
        }
    }

    // MARK: - Apples Aufnahme

    private static func appleAufnahme(region: MKCoordinateRegion, groesse: CGSize,
                                      kartenbild: Kartenbild) async -> Kachelkarte.Untergrund?
    {
        let wunsch = MKMapSnapshotter.Options()
        wunsch.region = region
        wunsch.size = groesse
        wunsch.scale = massstab
        wunsch.preferredConfiguration = kartenbild.aufbau
        // DAS ist der Griff gegen die dunkle Karte im gedruckten Buch: Ohne
        // ihn nimmt der Schnappschuss die Erscheinung des Systems an, und
        // wer sein iPad abends dunkel schaltet, bekommt eine schwarze Karte
        // aufs Papier. Eine Druckvorlage darf nicht davon abhängen, wie hell
        // es im Zimmer war.
        if kartenbild.helle != .wieApp {
            wunsch.traitCollection = UITraitCollection(userInterfaceStyle: kartenbild.helle.stil)
        }

        let aufnahme: MKMapSnapshotter.Snapshot
        do {
            aufnahme = try await MKMapSnapshotter(options: wunsch).start()
        } catch {
            return nil
        }
        return Kachelkarte.Untergrund(bild: aufnahme.image,
                                      stelle: { aufnahme.point(for: $0.clLocation) })
    }

    // MARK: - Der Lizenzhinweis

    // Er wird IN das Bild gezeichnet und nicht daneben gesetzt.
    //
    // Der Grund ist der Druck: Ein Hinweis, der als eigener Textblock unter
    // der Karte läge, ließe sich verschieben, überdecken oder löschen — und
    // stünde dann nicht mehr da, wenn das Buch beim Drucker liegt. Die
    // Richtlinie von OpenStreetMap verlangt ausdrücklich, ihn nicht hinter
    // Bedienelementen oder Schaltern zu verstecken; OpenTopoMap nennt den
    // Wortlaut, der deutlich sichtbar sein soll. Also gehört er dorthin, wo
    // er nicht abhandenkommen kann.
    private static func zeichneNachweis(_ text: String, groesse: CGSize,
                                        feder: CGContext) {
        let sauber = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sauber.isEmpty else { return }
        let hoehe = max(min(groesse.width / 52, 9), 5.5)
        let schrift = UIFont.systemFont(ofSize: hoehe, weight: .regular)
        let luft = max(groesse.width / 90, 2.5)
        let absatz = NSMutableParagraphStyle()
        absatz.alignment = .right
        absatz.lineBreakMode = .byWordWrapping
        let merkmale: [NSAttributedString.Key: Any] = [
            .font: schrift,
            .foregroundColor: UIColor(white: 0.16, alpha: 1),
            .paragraphStyle: absatz,
        ]
        let hoechstbreite = max(groesse.width - 4 * luft, 20)
        let satz = NSAttributedString(string: sauber, attributes: merkmale)
        let masse = satz.boundingRect(
            with: CGSize(width: hoechstbreite, height: hoehe * 3),
            options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil
        )
        let kasten = CGRect(
            x: groesse.width - masse.width - 3 * luft,
            y: groesse.height - masse.height - 3 * luft,
            width: masse.width + 2 * luft,
            height: masse.height + 1.6 * luft
        )
        // Gesichert und zurückgesetzt, weil eine Beschneidung sonst für
        // alles gälte, was nach ihr käme — heute steht nichts mehr danach,
        // morgen vielleicht doch.
        feder.saveGState()
        feder.setFillColor(UIColor(white: 1, alpha: 0.82).cgColor)
        UIBezierPath(roundedRect: kasten, cornerRadius: luft).fill()
        satz.draw(with: kasten.insetBy(dx: luft, dy: 0.8 * luft),
                  options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        feder.restoreGState()
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
