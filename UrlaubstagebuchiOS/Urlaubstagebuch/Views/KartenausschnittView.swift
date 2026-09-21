import MapKit
import SwiftUI

// Welchen Ausschnitt die Karte auf der Buchseite zeigt.
//
// Den Wert dafür (`Reisetag.kartenausschnitt`) gibt es seit 1.0.0, und bis
// 1.0.10 konnte ihn niemand setzen: Im Inspektor stand einzig der Knopf
// „Wieder automatisch rahmen" — das Rückgängig zu einer Tat, die es nicht
// gab. Gerahmt wurde deshalb immer selbsttätig um die Spur, und bei einem
// einzigen Punkt sind das rund 900 Meter. Genau das war der Befund
// (09/2026: „auf der Karte wird ja quasi nichts dargestellt. Der Ort könnte
// sonst wo sein."): Die Karte war nicht falsch, sie war zu nah.
//
// **Merke: Ein Knopf, der etwas zurücknimmt, setzt voraus, dass es einen
// Weg hin gibt.** Hier ist er.
//
// Gewählt wird auf einer echten Karte — das ist dieselbe Trennung wie bei
// der Punktwahl: Die Karte im Buch ist ein Bild und nimmt keinen Finger an,
// die Karte zum Wählen ist die Hauptsache und darf alles.
struct KartenausschnittView: View {
    @ObservedObject var werk: Reisewerk
    let tagID: UUID
    @Environment(\.dismiss) private var schliessen

    @State private var kamera: MapCameraPosition = .automatic
    @State private var region: MKCoordinateRegion?

    private var tag: Reisetag? { werk.reise.tage.first { $0.id == tagID } }
    private var punkte: [Koordinate] { tag?.spur.map(\.koordinate) ?? [] }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                karte
                rahmenanzeige
                leiste
            }
            .navigationTitle("Kartenausschnitt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { schliessen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") { uebernehmen() }
                        .disabled(region == nil)
                }
            }
            .task { starten() }
        }
    }

    private var karte: some View {
        Map(position: $kamera) {
            if punkte.count >= 2 {
                MapPolyline(coordinates: punkte.map(\.clLocation))
                    .stroke(werk.reise.akzent.farbe, lineWidth: 3)
            }
            ForEach(tag?.spur ?? []) { punkt in
                Marker(punkt.name.isEmpty ? "Punkt" : punkt.name,
                       systemImage: punkt.istAusFoto ? "camera.fill" : "mappin",
                       coordinate: punkt.koordinate.clLocation)
                    .tint(punkt.istAusFoto ? .blue : Color.accentColor)
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { zusammenhang in
            region = zusammenhang.region
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // Ein Fadenkreuz wäre hier falsch: Gewählt wird keine STELLE, sondern
    // ein Ausschnitt. Was das Bild später zeigt, ist das, was jetzt im
    // Fenster steht — deshalb ein Rahmen und kein Kreuz.
    private var rahmenanzeige: some View {
        Rectangle()
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .foregroundStyle(Color.accentColor.opacity(0.7))
            .padding(18)
            .padding(.bottom, 150)
            .allowsHitTesting(false)
    }

    private var leiste: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(breitentext, systemImage: "ruler")
                    .font(.subheadline)
                Spacer()
                Button {
                    zoomen(0.5)
                } label: {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.bordered)
                Button {
                    zoomen(2)
                } label: {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.bordered)
            }
            // Ehrlich gesagt, statt es aussehen zu lassen wie eine
            // Vorschau: Der Block auf der Seite hat sein eigenes
            // Seitenverhältnis, und die Karte füllt ihn — was hier links
            // und rechts noch im Bild steht, kann dort fehlen.
            Text("Übernommen werden Mitte und Breite dieses Fensters. Der Block auf der Seite hat ein eigenes Seitenverhältnis; am Rand kann deshalb etwas mehr oder weniger zu sehen sein.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack {
                Button {
                    uebernehmen()
                } label: {
                    Label("Diesen Ausschnitt nehmen", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(region == nil)
            }
            Button("Wieder automatisch rahmen") {
                guard let stelle = werk.tagIndex(tagID) else { return }
                werk.merken()
                werk.reise.tage[stelle].kartenausschnitt = nil
                werk.meldung = .init(text: "Die Karte rahmt die Spur wieder selbst.")
                schliessen()
            }
            .font(.subheadline)
            .disabled(tag?.kartenausschnitt == nil)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(12)
    }

    // Die Spanne in Kilometern, damit die Zahl etwas bedeutet. Ein Grad
    // Breite sind rund 111 km — das ist eine Umrechnung und keine Messung
    // am Gelände, und für die Frage „wie weit sehe ich hier" genügt sie.
    private var breitentext: String {
        guard let region else { return "Karte bewegen" }
        let km = region.span.latitudeDelta * 111.0
        if km < 1 { return String(format: "%.0f m hoch", km * 1000) }
        if km < 20 { return String(format: "%.1f km hoch", km).replacingOccurrences(of: ".", with: ",") }
        return String(format: "%.0f km hoch", km)
    }

    private func starten() {
        let feld = Kartenwerk.region(punkte, ausschnitt: tag?.kartenausschnitt)
        region = feld
        kamera = .region(feld)
    }

    private func zoomen(_ faktor: Double) {
        guard let jetzt = region else { return }
        // Gedeckelt an beiden Enden: Unter ein paar Metern zeigt keine
        // Karte mehr etwas, und über 90 Grad gibt es keine Erde mehr.
        let neu = min(max(jetzt.span.latitudeDelta * faktor, 0.0006), 90)
        let feld = MKCoordinateRegion(
            center: jetzt.center,
            span: MKCoordinateSpan(latitudeDelta: neu, longitudeDelta: neu)
        )
        region = feld
        kamera = .region(feld)
    }

    private func uebernehmen() {
        guard let region, let stelle = werk.tagIndex(tagID) else { return }
        werk.merken()
        werk.reise.tage[stelle].kartenausschnitt = Kartenausschnitt(
            mitte: Koordinate(region.center),
            spanne: region.span.latitudeDelta
        )
        werk.meldung = .init(text: "Ausschnitt übernommen: \(breitentext).")
        schliessen()
    }
}
