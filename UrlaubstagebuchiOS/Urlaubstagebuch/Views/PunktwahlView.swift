import MapKit
import SwiftUI

// Einen Reisepunkt auf der Karte wählen — oder einen vorhandenen ändern.
//
// **Ein Bildschirm für beides** (ab 1.0.20, Ansage des Nutzers 09/2026:
// „Ich möchte sie löschen, örtlich und zeitlich verändern können."). Ein
// eigener Editor daneben wäre ein zweiter Weg zu derselben Sache und liefe
// irgendwann auseinander — dieselbe Regel wie bei den Fotostilfeldern.
//
// Gewählt wird auf zwei Arten, und das ist Absicht:
//
// * **Ein Tipp auf die Karte** setzt die Stelle (ausdrücklich gewünscht:
//   „Einen abweichenden Ort möchte ich per Tipp auf eine Karte eingeben
//   können."). Er setzt sie aber nicht blind, sondern rückt sie unter das
//   Fadenkreuz — der Finger verdeckt genau die Stelle, die er trifft, und
//   so sieht man hinterher, wo sie gelandet ist.
// * **Die Karte schieben** stellt fein ein, was der Tipp grob traf.
//
// Die UHRZEIT wird getippt und nicht gedreht (ebenfalls ausdrücklich: „Die
// neue Zeitangabe möchte ich per Hand eingeben."). Angenommen wird alles,
// was eindeutig ist — „9:05", „0905", „9.05", „9".
struct PunktwahlView: View {
    @ObservedObject var werk: Reisewerk
    let tagID: UUID
    // Leer heißt: ein neuer Punkt. Sonst der, der geändert wird.
    var punktID: UUID?
    @Environment(\.dismiss) private var schliessen
    @StateObject private var standort = Standortdienst()

    @State private var kamera: MapCameraPosition = .automatic
    @State private var mitte: Koordinate?
    @State private var name = ""
    @State private var nameGeholt = false
    @State private var zeitSetzen = false
    // Die Uhrzeit als TEXT, so wie sie getippt wird. Ein `DatePicker` stand
    // hier bis 1.0.19 — gedreht wird damit, getippt nicht.
    @State private var zeittext = ""
    // Wie weit die Karte gerade aufgezogen ist. Ein Tipp soll den Maßstab
    // behalten; ohne diesen Wert spränge er bei jedem Tipp auf eine feste
    // Spanne zurück.
    @State private var spanne = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    @State private var geladen = false
    @State private var loeschfrage = false
    @State private var suche = ""
    @State private var treffer: [MKMapItem] = []
    @State private var sucheLaeuft = false

    private var tag: Reisetag? { werk.reise.tage.first { $0.id == tagID } }
    private var punkt: Reisepunkt? {
        guard let punktID else { return nil }
        return tag?.spur.first { $0.id == punktID }
    }
    private var aendert: Bool { punktID != nil }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                karte
                fadenkreuz
                leiste
            }
            .navigationTitle(aendert ? "Reisepunkt ändern" : "Reisepunkt wählen")
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
            .alert("Punkt löschen?", isPresented: $loeschfrage) {
                Button("Löschen", role: .destructive) {
                    if let punktID { werk.punktLoeschen(tagID, punktID: punktID) }
                    schliessen()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Der Punkt wird aus der Tagesspur entfernt. Stammt er aus einem Foto, "
                     + "kommt er beim nächsten „Aus den Fotos neu bauen\u{201C} wieder.")
            }
        }
    }

    private var karte: some View {
        MapReader { leser in
            kartenbild
                // EIN TIPP SETZT DIE STELLE. Umgerechnet wird über den
                // `MapProxy` — welche Koordinate unter einem Bildschirmpunkt
                // liegt, weiß allein die Karte.
                .onTapGesture { stelle in
                    guard let ort = leser.convert(stelle, from: .local) else { return }
                    kamera = .region(MKCoordinateRegion(center: ort, span: spanne))
                }
        }
    }

    private var kartenbild: some View {
        Map(position: $kamera) {
            if let tag, tag.spur.count >= 2 {
                MapPolyline(coordinates: tag.spur.map(\.koordinate.clLocation))
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
            mitte = Koordinate(zusammenhang.region.center)
            spanne = zusammenhang.region.span
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
                HStack(spacing: 10) {
                    TextField("HH:MM", text: $zeittext)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
                        .frame(width: 110)
                    if zeitteile == nil {
                        Text("Bitte als Uhrzeit, z.\u{00A0}B. 9:05")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    } else {
                        Text("Ortszeit \u{2014} so, wie die Uhr am Ort stand.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                // Ehrlich gesagt, statt eine Reihenfolge zu erfinden: Ohne
                // Uhrzeit weiß niemand, wohin der Punkt in der Tagesfolge
                // gehört — auch die App nicht.
                Text("Ohne Uhrzeit hängt der Punkt am Ende der Tagesspur. Verschieben lässt er sich in der Punktliste.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if aendert {
                Text("Eine geänderte Uhrzeit sortiert den Punkt neu in die Spur ein \u{2014} "
                     + "die Reihenfolge der Liste ist die Reihenfolge der gezeichneten Linie.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: 10) {
                if aendert {
                    Button(role: .destructive) {
                        loeschfrage = true
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
                Button {
                    punktSetzen()
                } label: {
                    Label(aendert ? "Übernehmen" : "Punkt hier setzen",
                          systemImage: aendert ? "checkmark" : "mappin.and.ellipse")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(mitte == nil || (zeitSetzen && zeitteile == nil))
            }
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
        // Nur EINMAL: `.task` läuft auch nach einem Wechsel in den
        // Hintergrund noch einmal, und dann stünde die gerade verschobene
        // Karte wieder auf dem Ausgangspunkt.
        guard !geladen else { return }
        geladen = true
        let anfang = punkt ?? tag?.spur.last
        if let anfang {
            kamera = .region(MKCoordinateRegion(
                center: anfang.koordinate.clLocation, span: spanne))
            mitte = anfang.koordinate
        }
        guard let punkt else { return }
        // Beim Ändern steht schon etwas da — und es bleibt stehen: Der
        // Name wird NICHT vom Geocoder überschrieben.
        name = punkt.name
        nameGeholt = true
        if let zeit = punkt.zeit {
            zeitSetzen = true
            zeittext = Self.uhrzeit.string(from: zeit)
        }
    }

    // Dieselbe feste Zone wie überall: Eine Uhrzeit ist die Wanduhr am Ort
    // (siehe `Dienste/Ortszeit.swift`).
    private static let uhrzeit: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    // Was getippt wurde, als Stunde und Minute — oder nil, wenn es keine
    // Uhrzeit ist. Angenommen wird „9:05", „9.05", „0905" und „9".
    private var zeitteile: (stunde: Int, minute: Int)? {
        let roh = zeittext.trimmingCharacters(in: .whitespaces)
        guard !roh.isEmpty else { return nil }
        var stunde = 0
        var minute = 0
        if roh.contains(":") || roh.contains(".") {
            let teile = roh.split(whereSeparator: { $0 == ":" || $0 == "." })
            guard let erste = teile.first, let s = Int(erste) else { return nil }
            stunde = s
            if teile.count > 1 {
                guard let m = Int(teile[1]) else { return nil }
                minute = m
            }
        } else {
            guard roh.allSatisfy(\.isNumber) else { return nil }
            if roh.count <= 2 {
                guard let s = Int(roh) else { return nil }
                stunde = s
            } else {
                guard let s = Int(roh.prefix(roh.count - 2)),
                      let m = Int(roh.suffix(2)) else { return nil }
                stunde = s
                minute = m
            }
        }
        guard (0...23).contains(stunde), (0...59).contains(minute) else { return nil }
        return (stunde, minute)
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
        let wie = name.isEmpty ? "ohne Namen" : name
        if let punktID {
            werk.punktAendern(tagID, punktID: punktID, ort: mitte, name: name, zeit: uhrzeit)
            werk.meldung = .init(text: "Punkt geändert: \(wie)")
            schliessen()
        } else {
            werk.punktHinzufuegen(tagID, ort: mitte, name: name, zeit: uhrzeit)
            werk.meldung = .init(text: "Punkt gesetzt: \(wie)")
        }
    }

    // Die Uhrzeit gehört auf den TAG des Eintrags, nicht auf heute — sonst
    // sortierte sich der Punkt hinter alle Fotos, weil er ein halbes Jahr
    // in der Zukunft läge.
    private func zeitAmTag() -> Date? {
        guard let tag else { return nil }
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        guard let teile = zeitteile else { return nil }
        var werte = DateComponents()
        werte.year = tag.datum.jahr
        werte.month = tag.datum.monat
        werte.day = tag.datum.tag
        werte.hour = teile.stunde
        werte.minute = teile.minute
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
