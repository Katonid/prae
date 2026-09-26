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
    /// Die Messpunkte als kleine Kreise (ab 1.0.24) — nur im Vollbild.
    var punkteZeigen = false

    @State private var linien: [Linie] = []
    @State private var wanderlinien: [Linie] = []
    @State private var fotopunkte: [Fotopunkt] = []
    /// Alle Punkte der Linien mit Uhrzeit (ab 1.0.24) — für den Tipp.
    @State private var zeitpunkte: [Zeitpunkt] = []
    /// Die gezeigten Messpunkte, höchstens 400.
    @State private var messpunkte: [Zeitpunkt] = []
    @State private var gewaehlt: Zeitpunkt?
    @State private var position: MapCameraPosition = .automatic

    struct Linie: Identifiable {
        let id: String
        let punkte: [CLLocationCoordinate2D]
        let eigene: Bool
        /// Reisespur oder Autofahrt (ab 1.0.21).
        var art: Spurart = .reisespur
    }

    struct Fotopunkt: Identifiable {
        let id: NSManagedObjectID
        let foto: Foto
        let ort: CLLocationCoordinate2D
    }

    @ObservedObject private var buecherei = Buecherei.shared
    /// Die Farben der Linien (ab 1.0.21) — einstellbar, siehe
    /// `Kartenfarben`.
    @ObservedObject private var farben = Kartenfarben.shared
    /// Welche Ebenen gezeigt werden (ab 1.0.26, siehe `Kartenebenen.swift`).
    @AppStorage(Kartenebene.reisespur.schluessel) private var zeigeSpur = true
    @AppStorage(Kartenebene.fahrt.schluessel) private var zeigeFahrten = true
    @AppStorage(Kartenebene.wanderung.schluessel) private var zeigeWanderungen = true
    @AppStorage(Kartenebene.fotos.schluessel) private var zeigeFotos = true

    private func sichtbar(_ art: Spurart) -> Bool {
        switch art {
        case .reisespur: return zeigeSpur
        case .fahrt: return zeigeFahrten
        case .wanderung: return zeigeWanderungen
        }
    }

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
        // Den Tipp nimmt die Karte NUR im Vollbild: Im Kopf der Reise
        // öffnet ein Tipp die Vollkarte (Geste des Umgebenden), und eine
        // eigene Geste hier schluckte ihn.
        Group {
            if interaktiv {
                MapReader { proxy in
                    karte.onTapGesture { ort in antippen(ort, proxy: proxy) }
                }
            } else {
                karte
            }
        }
        .task(id: schluessel) { await linienLaden() }
        .onChange(of: punkteZeigen) { _, an in
            messpunkte = an ? Zeitsuche.auswahl(zeitpunkte, hoechstens: 400) : []
        }
    }

    /// Ein Tipp auf die Karte: der nächste Punkt einer Linie samt Uhrzeit —
    /// oder, daneben, die Blase schließen.
    private func antippen(_ ort: CGPoint, proxy: MapProxy) {
        guard let ziel = proxy.convert(ort, from: .local),
              let toleranz = Zeitsuche.toleranz(proxy, bei: ort) else { return }
        withAnimation(.snappy(duration: 0.2)) {
            gewaehlt = Zeitsuche.naechster(zu: ziel, in: zeitpunkte.filter { sichtbar($0.art) }, toleranz: toleranz)
        }
    }

    private func linienfarbe(_ art: Spurart) -> Color {
        farben.farbe(art, palette: reise.palette)
    }

    private var karte: some View {
        Map(position: $position, interactionModes: interaktiv ? .all : []) {
            ForEach(linien.filter { $0.art == .reisespur && zeigeSpur }) { linie in
                MapPolyline(coordinates: linie.punkte)
                    .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: linie.punkte)
                    .stroke(linie.eigene ? farben.farbe(.reisespur, palette: reise.palette) : farben.fremdeSpur(palette: reise.palette),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            // Autofahrten (ab 1.0.21) in ihrer eigenen Farbe, über der
            // Reisespur — sie liegen oft auf derselben Straße.
            ForEach(linien.filter { $0.art == .fahrt && zeigeFahrten }) { linie in
                MapPolyline(coordinates: linie.punkte)
                    .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: linie.punkte)
                    .stroke(farben.fahrt, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            // Wanderungen grün (ab 1.0.17) — über der Reisespur, denn sie
            // sind das, was man sucht.
            ForEach(zeigeWanderungen ? wanderlinien : []) { linie in
                MapPolyline(coordinates: linie.punkte)
                    .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: linie.punkte)
                    .stroke(farben.wanderung, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            if fotosZeigen && zeigeFotos {
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
            ForEach(messpunkte.filter { sichtbar($0.art) }) { p in
                Annotation("", coordinate: p.koordinate) { Messpunkt(farbe: linienfarbe(p.art)) }
                    .annotationTitles(.hidden)
            }
            ForEach(eintraege) { eintrag in
                if let ort = eintrag.koordinate {
                    Annotation(eintrag.anzeigeTitel, coordinate: ort, anchor: .bottom) {
                        Stecknadel(eintrag: eintrag, palette: reise.palette)
                    }
                    .annotationTitles(interaktiv ? .automatic : .hidden)
                }
            }
            if let gewaehlt, sichtbar(gewaehlt.art) {
                Annotation("", coordinate: gewaehlt.koordinate, anchor: .bottom) {
                    Zeitblase(punkt: gewaehlt, farbe: linienfarbe(gewaehlt.art), mitTag: tag == nil)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
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
        // Name und Ortszeit je Linie (ab 1.0.24) — für die Uhrzeit im
        // Tipp: eine Fahrt trägt ihre Zone, eine Gerätespur nimmt die des
        // Tages (`Reise.zone(am:)`).
        let pakete = spuren.map { s in
            (id: "\(s.tag ?? "")|\(s.geraet ?? "")", daten: s.punkte, eigene: s.geraet == ich, art: s.spurart,
             name: s.istFahrt ? Fahrtenimport.anzeigename(s) : (s.reisender ?? ""),
             zone: s.istFahrt ? Fahrtenimport.zone(s) : reise.zone(am: s.tag ?? ""))
        }
        let (fertig, spurzeiten): ([Linie], [Zeitpunkt]) = await Task.detached(priority: .userInitiated) {
            var linien: [Linie] = []
            var zeiten: [Zeitpunkt] = []
            for paket in pakete {
                // Für die Übersicht genügt ein Punkt je 40 m.
                let punkte = Spurpunkt.ausgeduennt(Spurpunkt.entpacken(paket.daten), abstand: 40)
                guard punkte.count > 1 else { continue }
                linien.append(Linie(id: paket.id, punkte: punkte.map(\.koordinate), eigene: paket.eigene, art: paket.art))
                zeiten += Zeitsuche.punkte(punkte, art: paket.art, name: paket.name, zone: paket.zone)
            }
            return (linien, zeiten)
        }.value
        linien = fertig

        let wander = eintraege.filter { $0.eintragsart == .wanderung }
            .map { (id: $0.objectID.uriRepresentation().absoluteString, daten: $0.strecke,
                    name: $0.anzeigeTitel, zone: $0.zone) }
        let (wanderfertig, wanderzeiten): ([Linie], [Zeitpunkt]) = await Task.detached(priority: .userInitiated) {
            var linien: [Linie] = []
            var zeiten: [Zeitpunkt] = []
            for w in wander {
                let punkte = Spurpunkt.ausgeduennt(Spurpunkt.entpacken(w.daten), abstand: 30)
                guard punkte.count > 1 else { continue }
                linien.append(Linie(id: w.id, punkte: punkte.map(\.koordinate), eigene: true))
                zeiten += Zeitsuche.punkte(punkte, art: .wanderung, name: w.name, zone: w.zone)
            }
            return (linien, zeiten)
        }.value
        wanderlinien = wanderfertig
        zeitpunkte = (spurzeiten + wanderzeiten).sorted { $0.zeit < $1.zeit }
        messpunkte = punkteZeigen ? Zeitsuche.auswahl(zeitpunkte, hoechstens: 400) : []
        gewaehlt = nil

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
    @State private var farbenZeigen = false

    /// `startTag` (ab 1.0.26): aus der Karte eines Tages geöffnet, steht
    /// die Vollkarte gleich auf diesem Tag.
    init(reise: Reise, startTag: Date? = nil) {
        _reise = ObservedObject(wrappedValue: reise)
        _tag = State(initialValue: startTag)
    }
    /// Messpunkte zeigen (ab 1.0.24) — gemerkt je Gerät.
    @AppStorage("fernweh.kartenpunkte") private var punkte = false

    var body: some View {
        NavigationStack {
            Reisekarte(reise: reise, interaktiv: true, tag: tag, fotosZeigen: true, punkteZeigen: punkte)
                .id(tag.map(Tag.schluessel) ?? "alle")
                .ignoresSafeArea(edges: .bottom)
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 0) {
                    // Die Ebenen (ab 1.0.26): Spur, Autofahrten,
                    // Wanderungen, Fotos — einzeln schaltbar.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Ebenenwahl(palette: reise.palette)
                            Divider().frame(height: 22)
                            Knopf(text: "Punkte", an: punkte) { punkte.toggle() }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Knopf(text: "Ganze Reise", an: tag == nil) { tag = nil }
                            ForEach(Array(reise.bisherigeTage.enumerated()), id: \.offset) { nummer, t in
                                Knopf(text: "Tag \(nummer + 1)", an: tag.map(Tag.schluessel) == Tag.schluessel(t)) { tag = t }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    }
                    .background(.ultraThinMaterial)
                }
                // Ein Hinweis, dass die Linie antwortet (ab 1.0.24).
                .safeAreaInset(edge: .top) {
                    Label("Tippe auf eine Linie: Wann warst du dort?", systemImage: "hand.tap")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 6)
                        .allowsHitTesting(false)
                }
                .navigationTitle(reise.anzeigeTitel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { farbenZeigen = true } label: { Label("Farben", systemImage: "paintpalette") }
                    }
                    ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } }
                }
                .sheet(isPresented: $farbenZeigen) {
                    KartenfarbenView(palette: reise.palette)
                        .presentationDetents([.medium, .large])
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
