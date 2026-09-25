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
    }

    @State private var linien: [Linie] = []
    @State private var kilometer: Double = 0
    @State private var stand = 0

    var body: some View {
        let orte = eintrag.ortListe
        if eintrag.koordinate != nil || !linien.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Map(initialPosition: .automatic, interactionModes: []) {
                    ForEach(linien) { l in
                        MapPolyline(coordinates: l.punkte)
                            .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                        MapPolyline(coordinates: l.punkte)
                            .stroke(palette.haupt, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
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
            return p.count >= 2 ? Tagesspurkarte.Linie(id: g, punkte: p) : nil
        }
        return (linien, (jeGeraet.values.map(\.distanz).max() ?? 0) / 1000)
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
                                .stroke(palette.haupt, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .mapStyle(.standard(pointsOfInterest: .excludingAll))
                    .id(stand)
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
                .allowsHitTesting(false)
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
