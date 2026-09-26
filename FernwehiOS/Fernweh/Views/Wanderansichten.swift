import SwiftUI
import MapKit

// Was man von einer Wanderung SIEHT (ab 1.0.17): eine Zeile mit den Zahlen,
// eine kleine Karte, und bildschirmfüllend die Strecke mit Uhrzeiten — am
// Start, am Ziel und zu jeder vollen Stunde dazwischen. So steht auf der
// Karte, wann man wo war („mit Zeitangabe sichtbar machen").

/// „Wanderung · 09:12–15:40 · 14,2 km · 5:48 h · ↑ 620 m"
struct WanderZeile: View {
    @ObservedObject var eintrag: Eintrag

    var body: some View {
        let teile = [
            Wanderung.sportname(eintrag.sportart ?? ""),
            eintrag.streckenzeit ?? "",
            Tagesspurwahl.kilometertext(eintrag.streckeMeter / 1000),
            Wanderung.dauertext(eintrag.dauer),
            eintrag.hoehenmeter >= 1 ? "↑ \(Int(eintrag.hoehenmeter)) m" : "",
        ].filter { !$0.isEmpty }
        Label(teile.joined(separator: " · "), systemImage: "figure.hiking")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Kartenfarben.shared.wanderung)
            .lineLimit(2)
    }
}

/// Eine Uhrzeit auf der Strecke.
struct Zeitmarke: Identifiable {
    enum Art { case start, ziel, stunde }
    let id: Int
    let text: String
    let ort: CLLocationCoordinate2D
    let art: Art

    /// Start, jede volle Stunde (in der Zone des Eintrags) und Ziel.
    static func fuer(_ punkte: [Spurpunkt], zone: TimeZone) -> [Zeitmarke] {
        guard let erster = punkte.first, let letzter = punkte.last, punkte.count > 1 else { return [] }
        let uhr = { (p: Spurpunkt) in Tag.text(p.datum, "HH:mm", zone: zone) }
        var marken = [Zeitmarke(id: 0, text: "Start " + uhr(erster), ort: erster.koordinate, art: .start)]
        if letzter.zeit > erster.zeit {
            var k = Tag.kalender
            k.timeZone = zone
            var stunde = k.dateInterval(of: .hour, for: erster.datum)?.end ?? erster.datum
            var i = 0
            // Eine Marke je Stunde, höchstens 24 — eine Mehrtagestour wäre
            // sonst ein Zaun aus Uhrzeiten.
            while stunde.timeIntervalSince1970 < letzter.zeit - 600, marken.count < 25 {
                while i < punkte.count - 1, punkte[i].zeit < stunde.timeIntervalSince1970 { i += 1 }
                marken.append(Zeitmarke(id: marken.count, text: Tag.text(stunde, "HH:mm", zone: zone),
                                        ort: punkte[i].koordinate, art: .stunde))
                stunde = stunde.addingTimeInterval(3600)
            }
        }
        marken.append(Zeitmarke(id: marken.count, text: "Ziel " + uhr(letzter), ort: letzter.koordinate, art: .ziel))
        return marken
    }
}

/// Wie eine Zeitmarke auf der Karte aussieht.
struct Zeitmarkenbild: View {
    let marke: Zeitmarke

    var body: some View {
        let farbe: Color = marke.art == .start ? .green : (marke.art == .ziel ? .red : Kartenfarben.shared.wanderung)
        HStack(spacing: 4) {
            if marke.art != .stunde { Circle().fill(.white).frame(width: 6, height: 6) }
            Text(marke.text).font(.caption2.weight(.bold)).monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(farbe, in: Capsule())
        .overlay(Capsule().stroke(.white, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }
}

/// Die Strecke einer Wanderung als kleine Karte. Wie alle kleinen Karten
/// ein BILD (`allowsHitTesting(false)`); den Tipp nimmt eine Fläche darüber
/// und öffnet das Vollbild mit Uhrzeiten.
struct Wanderkarte: View {
    @ObservedObject var eintrag: Eintrag
    let palette: Palette
    var hoehe: CGFloat = 230
    var antippbar = true

    @State private var linie: [CLLocationCoordinate2D] = []
    @State private var vollbild = false
    @ObservedObject private var farben = Kartenfarben.shared

    var body: some View {
        Map(initialPosition: .automatic, interactionModes: []) {
            MapPolyline(coordinates: linie)
                .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            MapPolyline(coordinates: linie)
                .stroke(farben.wanderung, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            if let a = linie.first {
                Annotation("", coordinate: a) { Circle().fill(.green).frame(width: 11, height: 11).overlay(Circle().stroke(.white, lineWidth: 2)) }
            }
            if let b = linie.last {
                Annotation("", coordinate: b) { Circle().fill(.red).frame(width: 11, height: 11).overlay(Circle().stroke(.white, lineWidth: 2)) }
            }
        }
        // `.automatic` rahmt nur beim ersten Zeichnen — mit der Strecke neu.
        .id(linie.count)
        .frame(height: hoehe)
        .clipShape(RoundedRectangle(cornerRadius: antippbar ? 18 : 0, style: .continuous))
        .allowsHitTesting(false)
        .overlay(alignment: .topTrailing) { if antippbar { VollbildHinweis() } }
        .overlay {
            if antippbar {
                Color.clear.contentShape(Rectangle()).onTapGesture { vollbild = true }
            }
        }
        .fullScreenCover(isPresented: $vollbild) {
            let punkte = eintrag.streckenpunkte
            SpurVollbild(titel: eintrag.anzeigeTitel,
                         unter: [eintrag.datum.map { Tag.text($0, "EEEE, d. MMMM yyyy", zone: eintrag.zone) } ?? "",
                                 eintrag.streckenzeit ?? ""].filter { !$0.isEmpty }.joined(separator: " · "),
                         linien: [Tagesspurkarte.Linie(id: "wanderung", punkte: punkte.map(\.koordinate))],
                         kilometer: eintrag.streckeMeter / 1000, marken: [], palette: palette,
                         linienfarbe: farben.wanderung,
                         zeitmarken: Zeitmarke.fuer(punkte, zone: eintrag.zone))
        }
        .task(id: eintrag.strecke?.count ?? 0) {
            let daten = eintrag.strecke
            linie = await Task.detached(priority: .userInitiated) {
                Spurpunkt.ausgeduennt(Spurpunkt.entpacken(daten), abstand: 20).map(\.koordinate)
            }.value
        }
    }
}
