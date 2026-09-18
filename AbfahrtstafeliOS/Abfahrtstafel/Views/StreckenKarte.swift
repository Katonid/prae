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
                            eigener: nummer == einstieg,
                            faelltAus: halt.faelltAus
                        )
                    }
                    // Vierzig Beschriftungen nebeneinander sind keine Karte
                    // mehr. Nur die Halte, um die es geht, tragen ihren Namen
                    // — und ein ENTFALLENDER gehört immer dazu: Er ist der
                    // Grund, aus dem jemand diese Karte aufschlägt.
                    .annotationTitles(
                        nummer == 0 || nummer == fahrt.halte.count - 1
                            || nummer == einstieg || halt.faelltAus
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

            // **Der Satz, der diese Karte ehrlich hält.** Ein entfallender
            // Halt heißt: Das Fahrzeug fährt einen anderen Weg. Welchen,
            // sagt keine Quelle — der Linienzug hier ist unverändert der
            // planmäßige (nachgemessen 09/2026 an der Linie 448 in
            // Dortmund). Ohne diesen Hinweis sähe die Karte aus, als führe
            // der Bus weiter mitten durch den ausgelassenen Halt.
            if !fahrt.entfallendeHalte.isEmpty && !istLuftlinie {
                Label(
                    entfalltext,
                    systemImage: "arrow.triangle.branch"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var entfalltext: String {
        let namen = fahrt.entfallendeHalte.map(\.haltestelle.name)
        let liste = namen.joined(separator: ", ")
        let wieviele = namen.count == 1
            ? "Ein Halt entfällt: \(liste)."
            : "\(namen.count) Halte entfallen: \(liste)."
        return wieviele + " Gezeichnet ist trotzdem der PLANMÄSSIGE Linienweg — welchen Weg das Fahrzeug stattdessen fährt, gibt keine Quelle heraus."
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
    var faelltAus: Bool = false

    var body: some View {
        if faelltAus {
            // Ein entfallender Halt ist NICHT derselbe Punkt in einer anderen
            // Farbe: Er wird durchgestrichen und trägt das Warnzeichen. Farbe
            // allein sieht ein farbfehlsichtiger Mensch nicht — dieselbe
            // Regel wie bei der Rückmeldung in der Wörterwerkstatt.
            ZStack {
                Circle()
                    .fill(.background)
                    .frame(width: 17, height: 17)
                Circle()
                    .strokeBorder(.red, lineWidth: 3)
                    .frame(width: 17, height: 17)
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.red)
            }
            .shadow(color: .black.opacity(0.22), radius: 1.5, y: 0.5)
            .accessibilityLabel("Halt entfällt")
        } else {
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
}

#Preview {
    StreckenKarte(fahrt: Musterdienst.beispielfahrt, einstieg: 8, hoehe: 320)
        .padding()
}
