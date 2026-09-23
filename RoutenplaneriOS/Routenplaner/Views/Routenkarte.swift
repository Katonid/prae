import SwiftUI
import MapKit

extension Abschnittsart {
    /// Farbe UND Strichelung — Farbe allein sieht ein farbfehlsichtiger
    /// Mensch nicht.
    var farbe: Color {
        switch self {
        case .fahren: return .blue
        case .schieben: return .orange
        case .treppe: return .red
        case .radwegPflicht: return .purple
        }
    }

    var gestrichelt: Bool { self != .fahren }
}

extension Verkehrsmeldung.Art {
    var farbe: Color {
        switch self {
        case .sperrung: return .red
        case .stau: return .orange
        case .baustelle: return .yellow
        case .anschlussGesperrt: return .pink
        }
    }
}

extension Hinweis.Stufe {
    var farbe: Color {
        switch self {
        case .info: return .secondary
        case .warnung: return .orange
        case .gefahr: return .red
        }
    }

    var symbol: String {
        switch self {
        case .info: return "info.circle"
        case .warnung: return "exclamationmark.triangle.fill"
        case .gefahr: return "exclamationmark.octagon.fill"
        }
    }
}

/// Die Karte. Auf ihr liegt KEIN Bedienelement — alle Zeichen sind Bilder
/// (Lehre aus der Abfahrtstafel 1.1.18: Knöpfe auf einer Karte schlucken die
/// Zoomgeste).
struct Routenkarte: View {
    let route: Route?
    let start: Ort?
    let ziel: Ort?
    @Binding var kamera: MapCameraPosition

    var body: some View {
        Map(position: $kamera) {
            UserAnnotation()
            if let route {
                // Erst alle Konturen, dann alle Linien — sonst deckt die Kontur
                // der einen die schon gezeichnete andere zu.
                ForEach(route.abschnitte) { a in
                    MapPolyline(coordinates: a.punkte.map(\.koordinate))
                        .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                }
                ForEach(route.abschnitte) { a in
                    MapPolyline(coordinates: a.punkte.map(\.koordinate))
                        .stroke(a.art.farbe, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round,
                                                                 dash: a.art.gestrichelt ? [8, 6] : []))
                }
                ForEach(route.meldungen) { m in
                    if let mitte = m.mitte {
                        Annotation(m.art.name, coordinate: mitte.koordinate) {
                            Meldungszeichen(art: m.art, umfahren: false)
                        }
                    }
                }
                ForEach(route.umfahren) { m in
                    if let mitte = m.mitte {
                        Annotation("Umfahren", coordinate: mitte.koordinate) {
                            Meldungszeichen(art: m.art, umfahren: true)
                        }
                    }
                }
            }
            if let start {
                Marker("Start", systemImage: "circle.fill", coordinate: start.punkt.koordinate)
                    .tint(.green)
            }
            if let ziel {
                Marker("Ziel", systemImage: "flag.checkered", coordinate: ziel.punkt.koordinate)
                    .tint(.red)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
    }
}

struct Meldungszeichen: View {
    let art: Verkehrsmeldung.Art
    let umfahren: Bool

    var body: some View {
        Image(systemName: art.symbol)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(6)
            .background(Circle().fill(umfahren ? Color.gray : art.farbe))
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .overlay(alignment: .bottomTrailing) {
                if umfahren {
                    Image(systemName: "arrow.uturn.right.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.white, .blue)
                        .offset(x: 4, y: 4)
                }
            }
            .allowsHitTesting(false)
    }
}
