import SwiftUI
import MapKit
import CoreData

/// Die Karte einer Reise: die Spuren aller Mitreisenden als Linien, die
/// Einträge als Fotos darauf.
///
/// **Auf der Karte liegt kein Bedienelement** (Lehre aus der Abfahrtstafel
/// 1.1.18): Die Stecknadeln sind Bilder. Im Kopf der Reise ist die Karte
/// ohnehin starr — sie liegt in einer Rolle, und eine schiebbare Karte darin
/// nähme dem Finger das Blättern. Zum Erkunden gibt es die Vollbildkarte.
struct Reisekarte: View {
    @ObservedObject var reise: Reise
    var interaktiv = false
    /// Nur diesen Tag zeigen — `nil` heißt die ganze Reise.
    var tag: Date?
    /// Jedes Foto mit Ort als kleines Bild (ab 1.0.17) — nur in der
    /// Vollbildkarte, im Kopf der Reise wären es zu viele auf zu wenig Platz.
    var fotosZeigen = false

    @State private var linien: [Linie] = []
    @State private var wanderlinien: [Linie] = []
    @State private var fotopunkte: [Fotopunkt] = []
    @State private var position: MapCameraPosition = .automatic

    struct Linie: Identifiable {
        let id: String
        let punkte: [CLLocationCoordinate2D]
        let eigene: Bool
    }

    struct Fotopunkt: Identifiable {
        let id: NSManagedObjectID
        let foto: Foto
        let ort: CLLocationCoordinate2D
    }

    @ObservedObject private var buecherei = Buecherei.shared

    /// Alle Einträge (auch ohne Ort), die man sehen darf — für die Fotos.
    private var sichtbare: [Eintrag] {
        let alle = tag.map { reise.eintraege(am: $0) } ?? reise.eintragListe
        return alle.filter { !buecherei.istGesperrt($0.tagebuchName) }
    }

    /// Einträge aus einem gesperrten Tagebuch bekommen keine Nadel (ab
    /// 1.0.10): Die Nadel trägt das erste Foto, und der Ort allein erzählt
    /// oft schon, worum es ging.
    private var eintraege: [Eintrag] {
        let alle = tag.map { reise.eintraege(am: $0) } ?? reise.eintragListe
        return alle.filter { $0.hatOrt && !buecherei.istGesperrt($0.tagebuchName) }
    }

    var body: some View {
        Map(position: $position, interactionModes: interaktiv ? .all : []) {
            ForEach(linien) { linie in
                MapPolyline(coordinates: linie.punkte)
                    .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: linie.punkte)
                    .stroke(linie.eigene ? reise.palette.haupt : reise.palette.hell,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            // Wanderungen grün (ab 1.0.17) — über der Reisespur, denn sie
            // sind das, was man sucht.
            ForEach(wanderlinien) { linie in
                MapPolyline(coordinates: linie.punkte)
                    .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: linie.punkte)
                    .stroke(Stil.wanderfarbe, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            if fotosZeigen {
                ForEach(fotopunkte) { p in
                    Annotation("", coordinate: p.ort) {
                        FotoBild(foto: p.foto, kante: 120)
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                            .allowsHitTesting(false)
                    }
                    .annotationTitles(.hidden)
                }
            }
            ForEach(eintraege) { eintrag in
                if let ort = eintrag.koordinate {
                    Annotation(eintrag.anzeigeTitel, coordinate: ort, anchor: .bottom) {
                        Stecknadel(eintrag: eintrag, palette: reise.palette)
                    }
                    .annotationTitles(interaktiv ? .automatic : .hidden)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .task(id: schluessel) { await linienLaden() }
    }

    private var schluessel: String {
        let spuren = reise.spurListe.map { "\($0.tag ?? "")\($0.geaendert?.timeIntervalSince1970 ?? 0)" }.sorted().joined()
        let fotos = sichtbare.reduce(0) { $0 + $1.fotoListe.count }
        return "\(tag.map(Tag.schluessel) ?? "alle")|\(spuren.hashValue)|\(eintraege.count)|\(fotos)|\(fotosZeigen)"
    }

    private func linienLaden() async {
        let schluessel = tag.map(Tag.schluessel)
        let spuren = reise.spurListe.filter { schluessel == nil || $0.tag == schluessel }
        let ich = Geraet.kennung
        let pakete = spuren.map { (id: "\($0.tag ?? "")|\($0.geraet ?? "")", daten: $0.punkte, eigene: $0.geraet == ich) }
        let fertig: [Linie] = await Task.detached(priority: .userInitiated) {
            pakete.compactMap { paket in
                // Für die Übersicht genügt ein Punkt je 40 m.
                let punkte = Spurpunkt.ausgeduennt(Spurpunkt.entpacken(paket.daten), abstand: 40)
                guard punkte.count > 1 else { return nil }
                return Linie(id: paket.id, punkte: punkte.map(\.koordinate), eigene: paket.eigene)
            }
        }.value
        linien = fertig

        let wander = eintraege.filter { $0.eintragsart == .wanderung }
            .map { (id: $0.objectID.uriRepresentation().absoluteString, daten: $0.strecke) }
        wanderlinien = await Task.detached(priority: .userInitiated) {
            wander.compactMap { w in
                let punkte = Spurpunkt.ausgeduennt(Spurpunkt.entpacken(w.daten), abstand: 30)
                guard punkte.count > 1 else { return nil }
                return Linie(id: w.id, punkte: punkte.map(\.koordinate), eigene: true)
            }
        }.value

        // Fotos: eines je 25 m, höchstens 300 — sonst liegen an einem
        // Aussichtspunkt vierzig Bilder aufeinander.
        var punkte: [Fotopunkt] = []
        if fotosZeigen {
            var behalten: [CLLocation] = []
            for f in sichtbare.flatMap(\.fotoListe) {
                guard let k = f.koordinate, punkte.count < 300 else { continue }
                let ort = CLLocation(latitude: k.latitude, longitude: k.longitude)
                if behalten.contains(where: { $0.distance(from: ort) < 25 }) { continue }
                behalten.append(ort)
                punkte.append(Fotopunkt(id: f.objectID, foto: f, ort: k))
            }
        }
        fotopunkte = punkte
        position = .automatic
    }
}

/// Die Stecknadel eines Eintrags: sein erstes Foto im Kreis.
struct Stecknadel: View {
    @ObservedObject var eintrag: Eintrag
    let palette: Palette

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let foto = eintrag.fotoListe.first {
                    FotoBild(foto: foto, kante: 120)
                } else {
                    Image(systemName: eintrag.eintragsart == .wanderung ? "figure.hiking"
                          : (eintrag.eintragsart == .seite ? "doc.richtext" : "book.pages.fill"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(palette.verlauf)
                }
            }
            .frame(width: 42, height: 42)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            Image(systemName: "triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(180))
                .offset(y: -3)
        }
        .allowsHitTesting(false)
    }
}

/// Die Karte im Vollbild, mit Tageswahl.
struct Vollkarte: View {
    @ObservedObject var reise: Reise
    @Environment(\.dismiss) private var schliessen
    @State private var tag: Date?
    @State private var fotos = true

    var body: some View {
        NavigationStack {
            Reisekarte(reise: reise, interaktiv: true, tag: tag, fotosZeigen: fotos)
                .id(tag.map(Tag.schluessel) ?? "alle")
                .ignoresSafeArea(edges: .bottom)
                .safeAreaInset(edge: .bottom) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Knopf(text: "Fotos", an: fotos) { fotos.toggle() }
                            Divider().frame(height: 22)
                            Knopf(text: "Ganze Reise", an: tag == nil) { tag = nil }
                            ForEach(Array(reise.bisherigeTage.enumerated()), id: \.offset) { nummer, t in
                                Knopf(text: "Tag \(nummer + 1)", an: tag.map(Tag.schluessel) == Tag.schluessel(t)) { tag = t }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(.ultraThinMaterial)
                }
                .navigationTitle(reise.anzeigeTitel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } }
                }
        }
    }

    private struct Knopf: View {
        let text: String
        let an: Bool
        let aktion: () -> Void
        var body: some View {
            Button(action: aktion) {
                Text(text)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(an ? AnyShapeStyle(Stil.akzent) : AnyShapeStyle(.regularMaterial), in: Capsule())
                    .foregroundStyle(an ? Color.white : Color.primary)
            }
            .buttonStyle(.plain)
        }
    }
}
