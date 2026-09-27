import SwiftUI
import MapKit
import Combine

// DEN TAG ABFAHREN (ab 1.0.31, Ansage des Nutzers 09/2026: „die einzelnen
// Punkte des Tages auf der Karte abfahren können, so wie es in der
// Tagesspur-App möglich ist. Hier … soll sich die Karte aber direkt in einer
// 2D-Darstellung öffnen und ein Punkt … langsamer als in der Tagesspur-App
// bewegen. Dabei soll zunächst die gesamte Spur des Tages bildschirmfüllend
// sichtbar sein. … einen Schieberegler bewegen … in der Karte zoomen …, wann
// ich wo war und auf welchem Weg … Die Zeitanzeige … unabhängig von der
// Zoomstufe nicht allzu groß.")
//
// Nach dem Muster von `TrackReplayView` der Tagesspur-App, mit vier
// Unterschieden:
// - **Nur 2D, flach** (kein Neigen, kein Drehen): Die Karte steht, der Punkt
//   wandert; zoomen und verschieben geht jederzeit, auch beim Abspielen.
// - **Langsamer**: 1× heißt zwei Minuten für den ganzen Tag (Tagesspur: 45
//   Sekunden), wählbar ½× bis 4×.
// - **Alle Linien des Tages in EINER Folge** — Spur, Autofahrten,
//   Wanderungen, nach der Zeit, jede in ihrer Farbe. Punkte der Gerätespur
//   INNERHALB einer Fahrt oder Wanderung fallen weg (dieselbe Regel wie im
//   Reisebuch 1.0.114): Zwei Linien auf demselben Weg, nach der Zeit
//   verschränkt, ergäben einen Zickzack.
// - **Die Uhrzeit hängt klein am Punkt** (eine Annotation hat eine feste
//   Bildschirmgröße, gleich welche Zoomstufe) und steht noch einmal klein
//   in der Leiste unten.
//
// Die Position läuft über die STRECKE, nicht über die Uhr (wie in der
// Tagesspur): Sonst stünde der Punkt eine Nacht lang still und raste über
// die Autobahn. Die Uhrzeit dazu kommt aus den beiden Nachbarpunkten.
struct Tagesfahrt: View {
    let titel: String
    let palette: Palette

    @Environment(\.dismiss) private var schliessen
    @ObservedObject private var farben = Kartenfarben.shared
    @State private var fortschritt: Double = 0
    @State private var laeuft = false
    @State private var tempo: Double = 1
    @State private var position: MapCameraPosition = .automatic

    private let pfad: [Zeitpunkt]
    private let summe: [Double]
    private let laenge: Double
    /// Stücke gleicher Art (Anfang, Ende, Art) — für die Farben.
    private let stuecke: [(von: Int, bis: Int, art: Spurart)]
    private static let grunddauer: TimeInterval = 120
    private let takt = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    init(titel: String, linien: [Tagesspurkarte.Linie], zone: TimeZone, palette: Palette) {
        self.titel = titel
        self.palette = palette
        var alle: [Zeitpunkt] = []
        var fenster: [ClosedRange<Double>] = []
        for l in linien where l.zeiten.count == l.punkte.count && l.punkte.count > 1 {
            let punkte = zip(l.punkte, l.zeiten).map {
                Zeitpunkt(breite: $0.latitude, laenge: $0.longitude, zeit: $1, art: l.art, name: l.name, zone: l.zone ?? zone)
            }
            alle += punkte
            if l.art != .reisespur, let a = l.zeiten.min(), let b = l.zeiten.max(), a < b { fenster.append(a...b) }
        }
        let gefiltert = alle
            .filter { p in p.art != .reisespur || !fenster.contains { $0.contains(p.zeit) } }
            .sorted { $0.zeit < $1.zeit }
        let pfad = Self.ausgeduenntFolge(gefiltert, hoechstens: 1500)
        self.pfad = pfad

        var summe: [Double] = [0]
        for i in stride(from: 1, to: pfad.count, by: 1) {
            let a = CLLocation(latitude: pfad[i - 1].breite, longitude: pfad[i - 1].laenge)
            let b = CLLocation(latitude: pfad[i].breite, longitude: pfad[i].laenge)
            summe.append(summe[i - 1] + b.distance(from: a))
        }
        self.summe = summe
        self.laenge = summe.last ?? 0

        var stuecke: [(von: Int, bis: Int, art: Spurart)] = []
        var anfang = 0
        for i in stride(from: 1, through: pfad.count, by: 1) where i == pfad.count || pfad[i].art != pfad[anfang].art {
            // Ein Stück endet am ersten Punkt des nächsten, damit keine
            // Lücke in der Linie bleibt.
            stuecke.append((anfang, min(i, pfad.count - 1), pfad[anfang].art))
            anfang = i
        }
        self.stuecke = pfad.isEmpty ? [] : stuecke
    }

    var body: some View {
        ZStack {
            Map(position: $position, interactionModes: [.zoom, .pan]) {
                // Die ganze Strecke blass, das Gefahrene kräftig.
                ForEach(Array(stuecke.enumerated()), id: \.offset) { _, s in
                    MapPolyline(coordinates: koordinaten(s.von, s.bis))
                        .stroke(farbe(s.art).opacity(0.35), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
                ForEach(Array(gefahreneStuecke.enumerated()), id: \.offset) { _, s in
                    MapPolyline(coordinates: s.punkte)
                        .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                    MapPolyline(coordinates: s.punkte)
                        .stroke(farbe(s.art), style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round))
                }
                if let jetzt = zustand {
                    Annotation("", coordinate: jetzt.ort, anchor: .center) {
                        Fahrpunkt(farbe: farbe(jetzt.art), uhrzeit: Tag.text(jetzt.zeit, "HH:mm", zone: jetzt.zone))
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .mapControls { MapScaleView() }
            .ignoresSafeArea()

            VStack {
                kopf
                Spacer()
                leiste
            }
        }
        .onReceive(takt) { _ in weiter() }
        .task {
            // Erst die ganze Spur zeigen, dann losfahren.
            try? await Task.sleep(for: .milliseconds(900))
            if fortschritt == 0 { laeuft = true }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func farbe(_ art: Spurart) -> Color { farben.farbe(art, palette: palette) }

    private func koordinaten(_ von: Int, _ bis: Int) -> [CLLocationCoordinate2D] {
        guard von <= bis, bis < pfad.count else { return [] }
        return pfad[von...bis].map(\.koordinate)
    }

    // MARK: - Oben und unten

    private var kopf: some View {
        HStack(spacing: 10) {
            Button { schliessen() } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.bold))
                    .frame(width: 38, height: 38)
                    .background(.regularMaterial, in: Circle())
            }
            .accessibilityLabel("Schließen")
            Text(titel)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
            Spacer()
            Button {
                withAnimation { position = .automatic }
            } label: {
                Image(systemName: "scope")
                    .font(.body.weight(.semibold))
                    .frame(width: 38, height: 38)
                    .background(.regularMaterial, in: Circle())
            }
            .accessibilityLabel("Ganze Spur zeigen")
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var leiste: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                if let jetzt = zustand {
                    Image(systemName: jetzt.art.symbol).foregroundStyle(farbe(jetzt.art))
                    Text(Tag.text(jetzt.zeit, "HH:mm", zone: jetzt.zone)).monospacedDigit()
                    if !jetzt.name.isEmpty, jetzt.art != .reisespur {
                        Text("· " + jetzt.name).lineLimit(1).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(Tagesspurwahl.kilometertext(laenge * fortschritt / 1000))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption.weight(.semibold))

            HStack(spacing: 12) {
                Button {
                    if fortschritt >= 1 { fortschritt = 0 }
                    laeuft.toggle()
                } label: {
                    Image(systemName: laeuft ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(palette.haupt)
                }
                .accessibilityLabel(laeuft ? "Anhalten" : "Abspielen")
                regler
                Menu {
                    ForEach([0.5, 1.0, 2.0, 4.0], id: \.self) { t in
                        Button(tempoText(t)) { tempo = t }
                    }
                } label: {
                    Text(tempoText(tempo))
                        .font(.caption.weight(.bold))
                        .frame(width: 38, height: 30)
                        .background(.regularMaterial, in: Capsule())
                }
            }
            HStack {
                Text(pfad.first.map { Tag.text($0.datum, "HH:mm", zone: $0.zone) } ?? "")
                Spacer()
                Text(pfad.last.map { Tag.text($0.datum, "HH:mm", zone: $0.zone) } ?? "")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func tempoText(_ t: Double) -> String { t == 0.5 ? "½×" : "\(Int(t))×" }

    /// Die Zeitleiste: antippen springt, ziehen fährt von Hand. Die Karte
    /// bleibt dabei stehen — wer genauer hinsehen will, zoomt selbst.
    private var regler: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.3)).frame(height: 6)
                Capsule().fill(palette.haupt).frame(width: max(0, geo.size.width * fortschritt), height: 6)
                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .shadow(radius: 2)
                    .offset(x: min(max(geo.size.width * fortschritt - 11, -11), geo.size.width - 11))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { wert in
                    laeuft = false
                    fortschritt = min(max(wert.location.x / max(geo.size.width, 1), 0), 1)
                }
            )
        }
        .frame(height: 32)
        .accessibilityElement()
        .accessibilityLabel("Zeitleiste")
        .accessibilityValue(zustand.map { Tag.text($0.zeit, "HH:mm", zone: $0.zone) } ?? "")
        .accessibilityAdjustableAction { richtung in
            laeuft = false
            fortschritt = min(max(fortschritt + (richtung == .increment ? 0.02 : -0.02), 0), 1)
        }
    }

    // MARK: - Wo der Punkt ist

    private struct Zustand {
        let ort: CLLocationCoordinate2D
        let zeit: Date
        let art: Spurart
        let name: String
        let zone: TimeZone
        let index: Int
    }

    private var zustand: Zustand? {
        guard let erster = pfad.first else { return nil }
        guard pfad.count > 1, laenge > 0 else {
            return Zustand(ort: erster.koordinate, zeit: erster.datum, art: erster.art, name: erster.name,
                           zone: erster.zone, index: 0)
        }
        let ziel = laenge * min(max(fortschritt, 0), 1)
        // Binäre Suche: erster Index mit summe >= ziel.
        var lo = 1, hi = summe.count - 1
        while lo < hi {
            let mitte = (lo + hi) / 2
            if summe[mitte] >= ziel { hi = mitte } else { lo = mitte + 1 }
        }
        let i = lo
        let a = pfad[i - 1], b = pfad[i]
        let stueck = summe[i] - summe[i - 1]
        let f = stueck > 0 ? (ziel - summe[i - 1]) / stueck : 0
        return Zustand(
            ort: CLLocationCoordinate2D(latitude: a.breite + (b.breite - a.breite) * f,
                                        longitude: a.laenge + (b.laenge - a.laenge) * f),
            zeit: Date(timeIntervalSince1970: a.zeit + (b.zeit - a.zeit) * f),
            art: b.art, name: b.name, zone: b.zone, index: i)
    }

    /// Das schon Gefahrene, in Stücken je Art, bis zum Punkt.
    private var gefahreneStuecke: [(punkte: [CLLocationCoordinate2D], art: Spurart)] {
        guard let jetzt = zustand, fortschritt > 0 else { return [] }
        var ergebnis: [(punkte: [CLLocationCoordinate2D], art: Spurart)] = []
        for s in stuecke where s.von < jetzt.index {
            var punkte = koordinaten(s.von, min(s.bis, jetzt.index - 1))
            if s.bis >= jetzt.index { punkte.append(jetzt.ort) }
            if punkte.count > 1 { ergebnis.append((punkte, s.art)) }
        }
        return ergebnis
    }

    private func weiter() {
        guard laeuft else { return }
        fortschritt += (1.0 / 30.0) / Self.grunddauer * tempo
        if fortschritt >= 1 {
            fortschritt = 1
            laeuft = false
        }
    }

    /// Höchstens so viele Punkte, gleichmäßig verteilt — die Zeichnung
    /// bleibt flüssig, die Form der Strecke bleibt.
    private static func ausgeduenntFolge(_ punkte: [Zeitpunkt], hoechstens: Int) -> [Zeitpunkt] {
        guard punkte.count > hoechstens, hoechstens > 2 else { return punkte }
        let schritt = Double(punkte.count - 1) / Double(hoechstens - 1)
        return (0 ..< hoechstens).map { punkte[Int(Double($0) * schritt)] }
    }
}

private extension Zeitpunkt {
    var datum: Date { Date(timeIntervalSince1970: zeit) }
}

/// Der fahrende Punkt mit kleiner Uhrzeit darüber — eine Annotation hat
/// ihre Größe in Bildschirmpunkten, sie wächst beim Zoomen nicht mit.
private struct Fahrpunkt: View {
    let farbe: Color
    let uhrzeit: String

    var body: some View {
        VStack(spacing: 3) {
            Text(uhrzeit)
                .font(.caption2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(farbe, in: Capsule())
                .overlay(Capsule().stroke(.white, lineWidth: 1))
            ZStack {
                Circle().fill(farbe.opacity(0.25)).frame(width: 30, height: 30)
                Circle().fill(.white).frame(width: 16, height: 16)
                Circle().fill(farbe).frame(width: 10, height: 10)
            }
        }
        // Der Kreis liegt auf dem Ort, nicht die Mitte des ganzen Stapels.
        .offset(y: -10)
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        .allowsHitTesting(false)
    }
}

/// Der Knopf „Tag abfahren", wo immer eine Tageskarte steht.
struct AbfahrenKnopf: View {
    let aktion: () -> Void
    var body: some View {
        Button(action: aktion) {
            Label("Abfahren", systemImage: "play.fill")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tag abfahren")
    }
}
