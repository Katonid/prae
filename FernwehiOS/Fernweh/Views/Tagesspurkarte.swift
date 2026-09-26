import SwiftUI
import MapKit
import CoreData

/// Die Karte im Eintrag: der Ort des Eintrags, die Orte des Tages und — ab
/// 1.0.13 — die Spur des GANZEN Tages. Bei einem Eintrag in einer Reise ist
/// es die Spur der Reise an diesem Tag, bei einem Eintrag nur für mich die
/// Tagebuchspur (siehe `Spurabgleich`). Sie wächst über den Tag: Wer morgens
/// schreibt, sieht am Abend auch den Nachmittag.
struct Tagesspurkarte: View {
    @ObservedObject var eintrag: Eintrag
    let palette: Palette

    struct Linie: Identifiable {
        let id: String
        let punkte: [CLLocationCoordinate2D]
        /// Welche Art Linie (ab 1.0.21) — bestimmt die Farbe.
        var art: Spurart = .reisespur
    }

    @State private var linien: [Linie] = []
    @State private var kilometer: Double = 0
    @State private var stand = 0
    @State private var vollbild = false
    @ObservedObject private var farben = Kartenfarben.shared

    var body: some View {
        let orte = eintrag.ortListe
        if eintrag.koordinate != nil || !linien.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Map(initialPosition: .automatic, interactionModes: []) {
                    ForEach(linien) { l in
                        MapPolyline(coordinates: l.punkte)
                            .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                        MapPolyline(coordinates: l.punkte)
                            .stroke(farben.farbe(l.art, palette: palette), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                    }
                    if let k = eintrag.koordinate {
                        Marker(eintrag.anzeigeTitel, coordinate: k).tint(palette.haupt)
                    }
                    ForEach(Array(orte.enumerated()), id: \.offset) { _, o in
                        Marker(o.name, systemImage: "mappin", coordinate: o.koordinate).tint(palette.hell)
                    }
                }
                // Neu aufbauen, wenn sich die Spur ändert — `.automatic`
                // rahmt nur beim ersten Zeichnen.
                .id(stand)
                .frame(height: linien.isEmpty ? 180 : 240)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)
                // Ein Tipp öffnet die Karte bildschirmfüllend (ab 1.0.15).
                .overlay(alignment: .topTrailing) { VollbildHinweis() }
                .overlay {
                    // Eine eigene Fläche nimmt den Tipp: Die Karte selbst
                    // nimmt keine Berührung an (`allowsHitTesting(false)`).
                    Color.clear.contentShape(Rectangle()).onTapGesture { vollbild = true }
                }
                .fullScreenCover(isPresented: $vollbild) {
                    SpurVollbild(titel: eintrag.anzeigeTitel,
                                 unter: eintrag.datum.map { Tag.text($0, "EEEE, d. MMMM yyyy", zone: eintrag.zone) } ?? "",
                                 linien: linien, kilometer: kilometer,
                                 marken: (eintrag.koordinate.map { [SpurVollbild.Marke(name: eintrag.anzeigeTitel, ort: $0, haupt: true)] } ?? [])
                                    + orte.map { SpurVollbild.Marke(name: $0.name, ort: $0.koordinate, haupt: false) },
                                 palette: palette)
                }
                if !linien.isEmpty {
                    Label(Tagesspurwahl.kilometertext(kilometer).isEmpty
                          ? "Spur des Tages"
                          : "Spur des Tages · " + Tagesspurwahl.kilometertext(kilometer),
                          systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)
            .task(id: eintrag.tagSchluessel ?? "") { laden() }
            .onReceive(NotificationCenter.default.publisher(
                for: .NSManagedObjectContextObjectsDidChange, object: Persistenz.shared.kontext)) { m in
                    let k = [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSRefreshedObjectsKey]
                    if k.contains(where: { ((m.userInfo?[$0] as? Set<NSManagedObject>) ?? []).contains { $0 is Spur } }) {
                        laden()
                    }
                }
        } else {
            Color.clear.frame(height: 0)
                .task(id: eintrag.tagSchluessel ?? "") { laden() }
        }
    }

    private func laden() {
        guard let tag = eintrag.tagSchluessel else { return }
        let (neu, km) = Tagesspurwahl.linien(tag: tag, nurReise: eintrag.reise)
        let alt = linien.map { "\($0.id):\($0.punkte.count)" }
        if neu.map({ "\($0.id):\($0.punkte.count)" }) != alt {
            linien = neu
            kilometer = km
            stand += 1
        }
    }
}

/// Welche Spur zu einem Tag gehört — an EINER Stelle, gefragt vom Eintrag und
/// vom Tagebuch. In einer Reise die Spur der Reise; sonst je Gerät die
/// Tagebuchspur, und wo die fehlt, die einer eigenen Reise desselben Tages.
enum Tagesspurwahl {
    static func linien(tag: String, nurReise reise: Reise?) -> ([Tagesspurkarte.Linie], Double) {
        let anfrage = Spur.alle()
        anfrage.predicate = NSPredicate(format: "tag == %@", tag)
        let alle = (try? Persistenz.shared.kontext.fetch(anfrage)) ?? []
        var jeGeraet: [String: Spur] = [:]
        if let reise {
            for s in alle where s.reise == reise { jeGeraet[s.geraet ?? ""] = s }
        }
        if reise == nil || jeGeraet.isEmpty {
            for s in alle where s.reise == nil { jeGeraet[s.geraet ?? ""] = s }
            for s in alle where s.reise != nil && jeGeraet[s.geraet ?? ""] == nil { jeGeraet[s.geraet ?? ""] = s }
        }
        let linien = jeGeraet.sorted { $0.key < $1.key }.compactMap { g, s -> Tagesspurkarte.Linie? in
            let p = s.punktListe.map { CLLocationCoordinate2D(latitude: $0.breite, longitude: $0.laenge) }
            return p.count >= 2 ? Tagesspurkarte.Linie(id: g, punkte: p, art: s.spurart) : nil
        }
        // Wie `Reise.meter(am:)`: die längste Gerätespur ODER die Summe der
        // Autofahrten (ab 1.0.21), das Größere.
        let spuren = Array(jeGeraet.values)
        let geraete = spuren.filter { !$0.istFahrt }.map(\.distanz).max() ?? 0
        let fahrten = spuren.filter(\.istFahrt).reduce(0) { $0 + $1.distanz }
        return (linien, max(geraete, fahrten) / 1000)
    }

    static func kilometertext(_ km: Double) -> String {
        km >= 0.1
            ? String(format: "%.1f km", km).replacingOccurrences(of: ".", with: ",")
            : ""
    }
}

/// Die Spur eines Tages im TAGEBUCH (ab 1.0.14): unter der Tagesüberschrift,
/// sobald es für den Tag eine gibt — egal, ob der Eintrag in einer Reise
/// steht oder nur im Tagebuch, und egal, um welche Uhrzeit er geschrieben
/// wurde. Ein Bild, keine bedienbare Karte: Sie liegt in einer scrollenden
/// Liste und darf keinen Wisch schlucken.
struct Tagesspurleiste: View {
    let tag: String
    let palette: Palette

    @State private var linien: [Tagesspurkarte.Linie] = []
    @State private var kilometer: Double = 0
    @State private var stand = 0
    @State private var vollbild = false
    @ObservedObject private var farben = Kartenfarben.shared

    var body: some View {
        Group {
            if linien.isEmpty {
                Color.clear.frame(height: 0)
            } else {
                ZStack(alignment: .bottomLeading) {
                    Map(initialPosition: .automatic, interactionModes: []) {
                        ForEach(linien) { l in
                            MapPolyline(coordinates: l.punkte)
                                .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                            MapPolyline(coordinates: l.punkte)
                                .stroke(farben.farbe(l.art, palette: palette), style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .id(stand)
                    .allowsHitTesting(false)
                    let km = Tagesspurwahl.kilometertext(kilometer)
                    Label(km.isEmpty ? "Spur des Tages" : "Spur des Tages · \(km)",
                          systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                        .padding(10)
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .topTrailing) { VollbildHinweis() }
                // Die kleine Karte bleibt ein Bild (sie liegt in einer
                // scrollenden Liste); ein Tipp öffnet sie bildschirmfüllend,
                // dort lässt sie sich zoomen und schieben (ab 1.0.15).
                .overlay {
                    Color.clear.contentShape(Rectangle()).onTapGesture { vollbild = true }
                }
                .fullScreenCover(isPresented: $vollbild) {
                    SpurVollbild(titel: "Spur des Tages",
                                 unter: Tag.datum(schluessel: tag).map { Tag.text($0, "EEEE, d. MMMM yyyy", zone: .current) } ?? "",
                                 linien: linien, kilometer: kilometer, marken: [], palette: palette)
                }
            }
        }
        .task(id: tag) { laden() }
        .onReceive(NotificationCenter.default.publisher(
            for: .NSManagedObjectContextObjectsDidChange, object: Persistenz.shared.kontext)) { m in
                let k = [NSInsertedObjectsKey, NSUpdatedObjectsKey, NSRefreshedObjectsKey]
                if k.contains(where: { ((m.userInfo?[$0] as? Set<NSManagedObject>) ?? []).contains { $0 is Spur } }) {
                    laden()
                }
            }
    }

    private func laden() {
        let (neu, km) = Tagesspurwahl.linien(tag: tag, nurReise: nil)
        if neu.map({ "\($0.id):\($0.punkte.count)" }) != linien.map({ "\($0.id):\($0.punkte.count)" }) {
            linien = neu
            kilometer = km
            stand += 1
        }
    }
}

/// Das kleine Zeichen oben rechts: Diese Karte lässt sich vergrößern.
struct VollbildHinweis: View {
    var body: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.caption.weight(.bold))
            .padding(7)
            .background(.regularMaterial, in: Circle())
            .padding(8)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Die Spur bildschirmfüllend (ab 1.0.15, Wunsch des Nutzers 09/2026: „mit
/// Tipp auf die Karte bildschirmfüllend … zoomen und verschieben … und
/// wieder schließen“). Hier ist die Karte bedienbar; geschlossen wird mit
/// dem Knopf oben rechts oder durch Herunterziehen des Kopfes nicht — ein
/// Wisch gehört auf einer Karte dem Verschieben.
struct SpurVollbild: View {
    struct Marke: Identifiable {
        let id = UUID()
        let name: String
        let ort: CLLocationCoordinate2D
        let haupt: Bool
    }

    let titel: String
    let unter: String
    let linien: [Tagesspurkarte.Linie]
    let kilometer: Double
    let marken: [Marke]
    let palette: Palette
    /// Eine Wanderung zeichnet sich grün (ab 1.0.17), sonst in der Farbe
    /// der Reise.
    var linienfarbe: Color? = nil
    /// Uhrzeiten auf der Strecke (ab 1.0.17, Wanderungen): ersetzen die
    /// schlichten Punkte an Start und Ende.
    var zeitmarken: [Zeitmarke] = []

    @Environment(\.dismiss) private var schliessen
    @State private var position: MapCameraPosition = .automatic
    @ObservedObject private var farben = Kartenfarben.shared

    var body: some View {
        Map(position: $position) {
            ForEach(linien) { l in
                MapPolyline(coordinates: l.punkte)
                    .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: l.punkte)
                    .stroke(linienfarbe ?? farben.farbe(l.art, palette: palette), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            ForEach(zeitmarken) { z in
                Annotation(z.text, coordinate: z.ort) { Zeitmarkenbild(marke: z) }
                    .annotationTitles(.hidden)
            }
            ForEach(marken) { m in
                Marker(m.name, systemImage: m.haupt ? "book.pages.fill" : "mappin", coordinate: m.ort)
                    .tint(m.haupt ? palette.haupt : palette.hell)
            }
            // Anfang und Ende der Spur, damit man sieht, in welche Richtung
            // der Tag lief.
            if zeitmarken.isEmpty, let erste = linien.first?.punkte.first {
                Annotation("Start", coordinate: erste) {
                    Circle().fill(.green).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
            if zeitmarken.isEmpty, let letzte = linien.first?.punkte.last {
                Annotation("Ende", coordinate: letzte) {
                    Circle().fill(.red).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
        .ignoresSafeArea(edges: .bottom)
        .safeAreaInset(edge: .top) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel).font(.headline).lineLimit(1)
                    let km = Tagesspurwahl.kilometertext(kilometer)
                    Text([unter, km].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    position = .automatic
                } label: {
                    Image(systemName: "scope")
                        .font(.body.weight(.semibold))
                        .frame(width: 38, height: 38)
                        .background(.regularMaterial, in: Circle())
                }
                .accessibilityLabel("Ganze Spur zeigen")
                Button { schliessen() } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .frame(width: 38, height: 38)
                        .background(.regularMaterial, in: Circle())
                }
                .accessibilityLabel("Schließen")
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
    }
}
