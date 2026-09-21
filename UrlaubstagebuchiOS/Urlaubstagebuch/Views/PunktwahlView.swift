import MapKit
import SwiftUI

// Einen Reisepunkt auf der Karte wählen.
//
// Gewählt wird über ein festes Fadenkreuz in der Mitte, die Karte bewegt
// sich darunter. Ein Tippen auf die Karte wäre naheliegend und schlechter:
// Der Finger verdeckt genau die Stelle, die er trifft, und ein Tipp löst
// beim Verschieben leicht aus. (Dieselbe Bauweise wie in der Abfahrtstafel.)
struct PunktwahlView: View {
    @ObservedObject var werk: Reisewerk
    let tagID: UUID
    @Environment(\.dismiss) private var schliessen
    @StateObject private var standort = Standortdienst()

    @State private var kamera: MapCameraPosition = .automatic
    @State private var mitte: Koordinate?
    @State private var name = ""
    @State private var nameGeholt = false
    @State private var zeitSetzen = false
    @State private var zeit = Date()
    @State private var suche = ""
    @State private var treffer: [MKMapItem] = []
    @State private var sucheLaeuft = false

    private var tag: Reisetag? { werk.reise.tage.first { $0.id == tagID } }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                karte
                fadenkreuz
                leiste
            }
            .navigationTitle("Reisepunkt wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { schliessen() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        standort.holen()
                    } label: {
                        Label("Mein Standort", systemImage: "location")
                    }
                }
            }
            .searchable(text: $suche, prompt: "Ort suchen")
            .onSubmit(of: .search) { Task { await ortSuchen() } }
            .overlay(alignment: .top) { trefferliste }
            .onChange(of: standort.ort) { _, neu in
                guard let neu else { return }
                kamera = .region(MKCoordinateRegion(
                    center: neu.clLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
            }
            .task { starten() }
        }
    }

    private var karte: some View {
        Map(position: $kamera) {
            if let tag, tag.spur.count >= 2 {
                MapPolyline(coordinates: tag.spur.map(\.koordinate.clLocation))
                    .stroke(werk.reise.linienfarbe.farbe, lineWidth: 3)
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
            mitte = Koordinate(zusammenhang.region.center)
            nameGeholt = false
            Task { await nameHolen() }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var fadenkreuz: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .frame(width: 26, height: 26)
            Circle()
                .fill(Color.accentColor)
                .frame(width: 5, height: 5)
            Rectangle().fill(Color.accentColor).frame(width: 1, height: 40)
            Rectangle().fill(Color.accentColor).frame(width: 40, height: 1)
        }
        .shadow(color: .white.opacity(0.9), radius: 2)
        .allowsHitTesting(false)
    }

    private var leiste: some View {
        VStack(spacing: 10) {
            if standort.abgelehnt {
                Text("Ohne Ortung fehlt nur der Knopf „Mein Standort“ — die Karte lässt sich weiter frei bewegen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextField("Name des Ortes", text: $name)
                .textFieldStyle(.roundedBorder)
            Toggle("Uhrzeit angeben", isOn: $zeitSetzen)
                .font(.subheadline)
            if zeitSetzen {
                DatePicker("Zeit", selection: $zeit, displayedComponents: [.hourAndMinute])
                    .font(.subheadline)
            } else {
                // Ehrlich gesagt, statt eine Reihenfolge zu erfinden: Ohne
                // Uhrzeit weiß niemand, wohin der Punkt in der Tagesfolge
                // gehört — auch die App nicht.
                Text("Ohne Uhrzeit hängt der Punkt am Ende der Tagesspur. Verschieben lässt er sich in der Punktliste.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Button {
                punktSetzen()
            } label: {
                Label("Punkt hier setzen", systemImage: "mappin.and.ellipse")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(mitte == nil)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(12)
    }

    @ViewBuilder
    private var trefferliste: some View {
        if !treffer.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(treffer, id: \.self) { eintrag in
                    Button {
                        let ort = eintrag.placemark.coordinate
                        kamera = .region(MKCoordinateRegion(
                            center: ort,
                            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)))
                        name = eintrag.name ?? name
                        treffer = []
                        suche = ""
                    } label: {
                        VStack(alignment: .leading) {
                            Text(eintrag.name ?? "Ohne Namen").font(.subheadline)
                            if let gegend = eintrag.placemark.locality {
                                Text(gegend).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
            .padding(.horizontal, 14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(10)
        } else if sucheLaeuft {
            ProgressView().padding(8)
        }
    }

    private func starten() {
        if let vorhanden = tag?.spur.last {
            kamera = .region(MKCoordinateRegion(
                center: vorhanden.koordinate.clLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
            mitte = vorhanden.koordinate
        }
    }

    private func nameHolen() async {
        guard let mitte, !nameGeholt else { return }
        // Der Name wird NACHGETRAGEN und nicht abgewartet. Wer auf den
        // Geocoder wartet, bevor der Punkt gesetzt werden kann, baut einen
        // Knopf, der eine Sekunde lang nichts tut.
        guard let gefunden = await Ortsname.suchen(mitte) else { return }
        if self.mitte == mitte { name = gefunden; nameGeholt = true }
    }

    private func punktSetzen() {
        guard let mitte else { return }
        let uhrzeit: Date? = zeitSetzen ? zeitAmTag() : nil
        werk.punktHinzufuegen(tagID, ort: mitte, name: name, zeit: uhrzeit)
        werk.meldung = .init(text: "Punkt gesetzt: \(name.isEmpty ? "ohne Namen" : name)")
    }

    // Die Uhrzeit gehört auf den TAG des Eintrags, nicht auf heute — sonst
    // sortierte sich der Punkt hinter alle Fotos, weil er ein halbes Jahr
    // in der Zukunft läge.
    private func zeitAmTag() -> Date? {
        guard let tag else { return nil }
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let uhr = Calendar.current.dateComponents([.hour, .minute], from: zeit)
        var werte = DateComponents()
        werte.year = tag.datum.jahr
        werte.month = tag.datum.monat
        werte.day = tag.datum.tag
        werte.hour = uhr.hour
        werte.minute = uhr.minute
        return kalender.date(from: werte)
    }

    private func ortSuchen() async {
        guard suche.count >= 2 else { return }
        sucheLaeuft = true
        let wunsch = MKLocalSearch.Request()
        wunsch.naturalLanguageQuery = suche
        if let mitte {
            wunsch.region = MKCoordinateRegion(
                center: mitte.clLocation,
                span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2))
        }
        let antwort = try? await MKLocalSearch(request: wunsch).start()
        treffer = Array((antwort?.mapItems ?? []).prefix(8))
        sucheLaeuft = false
    }
}
