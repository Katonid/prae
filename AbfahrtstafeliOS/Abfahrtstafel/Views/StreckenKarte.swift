import MapKit
import SwiftUI

/// Die Strecke einer Fahrt auf der Karte.
///
/// Zwei Dinge, die diese Ansicht ehrlich halten:
///
/// 1. **Eine fehlende Geometrie wird nicht erfunden.** Schickt der
///    Fahrplandienst keinen Linienzug mit, zeichnet die Karte die Verbindung
///    der Halte — GESTRICHELT, und darunter steht, dass es die Luftlinie ist.
///    Eine durchgezogene Linie quer über einen Berg, wo in Wahrheit ein Tunnel
///    liegt, sieht aus wie eine Auskunft und ist keine.
/// 2. **Die Halte sind Punkte, keine Nadeln.** Eine Nadel je Halt ergäbe bei
///    einer S-Bahn mit vierzig Stationen eine Wand aus Nadeln. Beschriftet
///    sind nur Anfang, Ende und der eigene Einstieg.
struct StreckenKarte: View {
    let fahrt: Fahrt
    /// Wird hervorgehoben: der Halt, an dem der Nutzer einsteigt.
    var einstieg: Int?
    var hoehe: CGFloat?

    @State private var kamera: MapCameraPosition = .automatic

    private var linienpunkte: [CLLocationCoordinate2D] {
        fahrt.strecke.isEmpty ? fahrt.halte.map(\.haltestelle.koordinate) : fahrt.strecke
    }

    private var istLuftlinie: Bool { fahrt.strecke.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Map(position: $kamera, interactionModes: [.pan, .zoom]) {
                if linienpunkte.count >= 2 {
                    MapPolyline(coordinates: linienpunkte)
                        .stroke(
                            fahrt.linie.anzeigefarbe,
                            style: StrokeStyle(
                                lineWidth: 5,
                                lineCap: .round,
                                lineJoin: .round,
                                dash: istLuftlinie ? [2, 8] : []
                            )
                        )
                }

                ForEach(Array(fahrt.halte.enumerated()), id: \.element.id) { nummer, halt in
                    Annotation(
                        halt.haltestelle.name,
                        coordinate: halt.haltestelle.koordinate,
                        anchor: .center
                    ) {
                        Haltepunkt(
                            farbe: fahrt.linie.anzeigefarbe,
                            gross: nummer == 0 || nummer == fahrt.halte.count - 1 || nummer == einstieg,
                            eigener: nummer == einstieg
                        )
                    }
                    // Vierzig Beschriftungen nebeneinander sind keine Karte
                    // mehr. Nur die drei Halte, um die es geht, tragen ihren
                    // Namen.
                    .annotationTitles(
                        nummer == 0 || nummer == fahrt.halte.count - 1 || nummer == einstieg
                            ? .automatic : .hidden
                    )
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .frame(height: hoehe)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onAppear { kamera = .rect(ausschnitt) }

            if istLuftlinie {
                Label(
                    "Der Fahrplandienst hat für diese Fahrt keine Streckenführung mitgeschickt. Gezeigt ist die Luftlinie zwischen den Halten — nicht der wirkliche Weg.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    /// Der Ausschnitt, der die ganze Strecke zeigt, mit etwas Luft ringsum.
    /// Ohne den Rand kleben Anfang und Ende am Bildschirmrand und ihre
    /// Beschriftungen sind abgeschnitten.
    private var ausschnitt: MKMapRect {
        let punkte = linienpunkte.isEmpty ? fahrt.halte.map(\.haltestelle.koordinate) : linienpunkte
        guard let erster = punkte.first else { return MKMapRect.world }
        var rahmen = MKMapRect(origin: MKMapPoint(erster), size: MKMapSize(width: 0, height: 0))
        for punkt in punkte.dropFirst() {
            rahmen = rahmen.union(
                MKMapRect(origin: MKMapPoint(punkt), size: MKMapSize(width: 0, height: 0))
            )
        }
        return rahmen.insetBy(dx: -rahmen.size.width * 0.18 - 400, dy: -rahmen.size.height * 0.18 - 400)
    }
}

/// Der Punkt, der einen Halt auf der Karte markiert.
private struct Haltepunkt: View {
    let farbe: Color
    let gross: Bool
    let eigener: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.background)
                .frame(width: gross ? 17 : 10, height: gross ? 17 : 10)
            Circle()
                .strokeBorder(farbe, lineWidth: gross ? 4 : 3)
                .frame(width: gross ? 17 : 10, height: gross ? 17 : 10)
            if eigener {
                Circle()
                    .fill(farbe)
                    .frame(width: 7, height: 7)
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 1.5, y: 0.5)
    }
}

#Preview {
    StreckenKarte(fahrt: Musterdienst.beispielfahrt, einstieg: 8, hoehe: 320)
        .padding()
}
