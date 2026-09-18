import MapKit
import SwiftUI

/// Die Karte mit den Linienverläufen aller Linien, die hier verkehren.
///
/// Sie beantwortet eine andere Frage als die Liste: nicht „wann fährt was",
/// sondern **„wohin komme ich von hier"**. Auf dem iPad steht sie neben der
/// Liste — dort ist Breite da, und eine Abfahrtsliste, die sich über 2000
/// Punkte spannt, benutzt sie nicht, sie wird nur auseinandergezogen.
///
/// Gefiltert wird mit DERSELBEN Leiste wie die Liste (`AppModel.filter`): Wer
/// Busse ausblendet, sieht auch keine Buslinien auf der Karte. Zwei Filter für
/// dieselbe Frage wären zwei Antworten.
struct LiniennetzView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var netz: Liniennetz

    @State private var kamera: MapCameraPosition = .automatic
    /// Welche Linie gerade hervorgehoben ist. `nil` heißt „alle gleich".
    @State private var hervorgehoben: String?

    var body: some View {
        VStack(spacing: 0) {
            karte
            fusszeile
        }
        .onAppear { aufbauen() }
        .onChange(of: model.abfahrten.count) { _, _ in aufbauen() }
        .onChange(of: model.filter) { _, _ in aufbauen() }
        .onChange(of: model.punkt) { _, _ in
            netz.leeren()
            aufbauen()
            kamera = .automatic
        }
    }

    private func aufbauen() {
        netz.aufbauen(aus: model.nachZeit, dienst: model.dienst)
    }

    // MARK: - Karte

    private var karte: some View {
        Map(position: $kamera, interactionModes: [.pan, .zoom, .rotate]) {
            ForEach(netz.zuege) { zug in
                MapPolyline(coordinates: zug.punkte)
                    .stroke(
                        zug.linie.anzeigefarbe.opacity(deckkraft(zug)),
                        style: StrokeStyle(
                            lineWidth: hervorgehoben == zug.id ? 7 : 4,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: zug.istLuftlinie ? [2, 7] : []
                        )
                    )
            }

            // Die Haltestellen als Punkte. Sie sind der Anker, an dem man die
            // Linien im Netz wiederfindet — ohne sie ist es ein Liniengewirr
            // ohne Bezug zu dem, was in der Liste steht.
            ForEach(model.gruppen) { gruppe in
                Annotation(gruppe.name, coordinate: gruppe.koordinate, anchor: .center) {
                    ZStack {
                        Circle().fill(.background).frame(width: 13, height: 13)
                        Circle().strokeBorder(.primary, lineWidth: 3).frame(width: 13, height: 13)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 1.5, y: 0.5)
                }
            }

            if let punkt = model.punkt {
                Annotation(punkt.beschriftung, coordinate: punkt.koordinate, anchor: .center) {
                    Image(systemName: punkt.symbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(Circle().fill(Color.accentColor))
                        .shadow(color: .black.opacity(0.28), radius: 3, y: 1)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .overlay(alignment: .topTrailing) { legende }
        .overlay(alignment: .center) {
            if netz.laedt && netz.zuege.isEmpty {
                ProgressView("Linienverläufe werden geholt …")
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .onChange(of: netz.zuege.count) { _, _ in
            guard !netz.zuege.isEmpty else { return }
            kamera = .rect(ausschnitt)
        }
    }

    /// Eine hervorgehobene Linie blendet die anderen zurück — sie verschwinden
    /// aber NICHT. Wer eine Linie verfolgt, will trotzdem sehen, wo sie die
    /// anderen kreuzt.
    private func deckkraft(_ zug: Linienzug) -> Double {
        guard let hervorgehoben else { return 0.85 }
        return zug.id == hervorgehoben ? 1.0 : 0.18
    }

    // MARK: - Legende

    private var legende: some View {
        VStack(alignment: .leading, spacing: 0) {
            if netz.zuege.isEmpty && !netz.laedt {
                Text("Keine Linienverläufe")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(netz.zuege) { zug in
                            Button {
                                // Ein zweiter Tipp hebt die Hervorhebung wieder
                                // auf. Ohne das käme man aus ihr nur über einen
                                // weiteren Knopf heraus, den niemand sucht.
                                hervorgehoben = (hervorgehoben == zug.id) ? nil : zug.id
                            } label: {
                                HStack(spacing: 8) {
                                    Liniensymbol(linie: zug.linie)
                                    Text(zug.richtung)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                }
                                .opacity(hervorgehoben == nil || hervorgehoben == zug.id ? 1 : 0.4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                }
                .frame(maxHeight: 260)
            }
        }
        .frame(maxWidth: 230, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(10)
    }

    // MARK: - Fußzeile

    private var fusszeile: some View {
        VStack(alignment: .leading, spacing: 2) {
            if netz.ohneVerlauf > 0 {
                Label(
                    netz.ohneVerlauf == 1
                        ? "Eine Linie fehlt auf der Karte: Ihre Quelle gibt keinen Linienverlauf heraus."
                        : "\(netz.ohneVerlauf) Linien fehlen auf der Karte: Ihre Quelle gibt keinen Linienverlauf heraus.",
                    systemImage: "exclamationmark.triangle"
                )
            }
            if netz.zuege.contains(where: \.istLuftlinie) {
                Text("Gestrichelte Linien sind Luftlinien zwischen den Halten — für sie kam keine Streckenführung mit.")
            }
            Text("Je Linie ist ein Lauf gezeichnet; die Gegenrichtung fährt denselben Weg zurück. Höchstens zwölf Linien.")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// Der Ausschnitt, der alle gezeichneten Linien zeigt.
    private var ausschnitt: MKMapRect {
        let punkte = netz.zuege.flatMap(\.punkte)
        guard let erster = punkte.first else { return MKMapRect.world }
        var rahmen = MKMapRect(origin: MKMapPoint(erster), size: MKMapSize(width: 0, height: 0))
        for punkt in punkte.dropFirst() {
            rahmen = rahmen.union(MKMapRect(origin: MKMapPoint(punkt), size: MKMapSize(width: 0, height: 0)))
        }
        return rahmen.insetBy(dx: -rahmen.size.width * 0.08 - 300, dy: -rahmen.size.height * 0.08 - 300)
    }
}

#Preview {
    LiniennetzView()
        .environmentObject(AppModel(dienst: Musterdienst()))
        .environmentObject(Liniennetz())
}
