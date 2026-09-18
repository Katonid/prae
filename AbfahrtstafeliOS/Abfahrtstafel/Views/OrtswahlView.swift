import CoreLocation
import MapKit
import SwiftUI

/// Den Bezugspunkt wählen — auf drei Wegen, weil je einer davon regelmäßig
/// ausfällt:
///
/// 1. **Der eigene Standort.** Gibt es nicht, wenn die Ortung abgelehnt wurde.
/// 2. **Eine Haltestelle suchen.** Geht nicht ohne Netz und nicht, wenn man
///    den Namen nicht weiß („der Platz beim Hotel").
/// 3. **Einen Punkt auf der Karte setzen.** Geht immer, wenn die Karte da ist.
///
/// Der dritte ist der, den die anderen Abfahrts-Apps weglassen — und genau der
/// war die Bitte: „oder eines frei wählbaren Punktes".
struct OrtswahlView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var standort: Standortdienst
    @EnvironmentObject private var merkliste: Merkliste
    @Environment(\.dismiss) private var schliessen

    @State private var suchtext = ""
    @State private var treffer: [Haltestelle] = []
    @State private var suchlauf: Task<Void, Never>?
    @State private var suchfehler: String?
    @State private var kartenmitte: CLLocationCoordinate2D?
    @State private var karteOffen = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        if case .da(let hier) = standort.stand {
                            model.zurueckZumStandort(hier)
                            schliessen()
                        } else {
                            standort.anfangen()
                        }
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Mein Standort")
                                Text(standorttext)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "location.fill")
                        }
                    }
                    .disabled(standortNichtMoeglich)

                    Button {
                        kartenmitte = model.punkt?.koordinate ?? standortKoordinate
                        karteOffen = true
                    } label: {
                        Label("Punkt auf der Karte wählen", systemImage: "mappin.and.ellipse")
                    }
                }

                if !merkliste.haltestellen.isEmpty && suchtext.isEmpty {
                    Section("Gemerkt") {
                        ForEach(merkliste.haltestellen) { halt in
                            Button { waehlen(halt) } label: { Haltestellenzeile(haltestelle: halt) }
                        }
                    }
                }

                if !suchtext.isEmpty {
                    Section("Treffer") {
                        if let suchfehler {
                            Text(suchfehler)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if treffer.isEmpty {
                            Text("Nichts gefunden. Der Fahrplandienst kennt nur Haltestellen — ein Straßenname hilft ihm nicht. Für eine Adresse ist die Karte der Weg.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(treffer) { halt in
                                Button { waehlen(halt) } label: { Haltestellenzeile(haltestelle: halt) }
                            }
                        }
                    }
                }
            }
            .searchable(
                text: $suchtext,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Haltestelle suchen"
            )
            .onChange(of: suchtext) { _, neu in suchen(neu) }
            .navigationTitle("Ausgangspunkt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schließen") { schliessen() }
                }
            }
            .sheet(isPresented: $karteOffen) {
                Kartenwahl(mitte: kartenmitte ?? Musterdienst.marienplatz.koordinate) { punkt, name in
                    model.ortWaehlen(name: name, koordinate: punkt)
                    karteOffen = false
                    schliessen()
                }
            }
        }
    }

    private var standortKoordinate: CLLocationCoordinate2D? {
        if case .da(let hier) = standort.stand { return hier }
        return nil
    }

    private var standortNichtMoeglich: Bool {
        standort.stand == .abgelehnt || standort.stand == .ausgeschaltet
    }

    private var standorttext: String {
        switch standort.stand {
        case .da: return "Bereit"
        case .sucht, .wirdGefragt: return "Wird gesucht …"
        case .nochNichtGefragt: return "Antippen, um die Ortung zu erlauben"
        case .abgelehnt: return "Nicht erlaubt — in den Einstellungen des Geräts freizugeben"
        case .ausgeschaltet: return "Auf diesem Gerät ausgeschaltet"
        }
    }

    private func waehlen(_ haltestelle: Haltestelle) {
        model.ortWaehlen(name: haltestelle.name, koordinate: haltestelle.koordinate)
        schliessen()
    }

    /// Sucht mit kurzer Verzögerung.
    ///
    /// Ohne sie stellte die App bei „Marienplatz" zwölf Anfragen — eine je
    /// Buchstabe —, und die Antwort auf „Marienpl" käme womöglich nach der auf
    /// „Marienplatz" an und überschriebe sie. Der laufende Auftrag wird
    /// deshalb abgebrochen, bevor ein neuer beginnt.
    private func suchen(_ text: String) {
        suchlauf?.cancel()
        suchfehler = nil
        let gekuerzt = text.trimmingCharacters(in: .whitespaces)
        guard gekuerzt.count >= 2 else {
            treffer = []
            return
        }
        suchlauf = Task {
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            do {
                let gefunden = try await model.dienst.haltestellenSuchen(
                    gekuerzt,
                    nahe: model.punkt?.koordinate ?? standortKoordinate
                )
                guard !Task.isCancelled else { return }
                treffer = gefunden
            } catch {
                guard !Task.isCancelled else { return }
                treffer = []
                suchfehler = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

private struct Haltestellenzeile: View {
    let haltestelle: Haltestelle

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: haltestelle.mittel.first?.symbol ?? "mappin.circle")
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(haltestelle.name)
                    .foregroundStyle(.primary)
                if let gegend = haltestelle.gegend {
                    Text(gegend)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

/// Der Punkt auf der Karte.
///
/// **Das Fadenkreuz steht fest, die Karte bewegt sich darunter.** Die
/// naheliegende Lösung wäre ein Tippen auf die Karte; sie ist schlechter, weil
/// der Finger genau die Stelle verdeckt, die er trifft, und weil ein Tipp
/// beim Verschieben leicht ausgelöst wird. Der gewählte Punkt ist hier immer
/// die Mitte des Bildschirms, und die ist zu sehen.
private struct Kartenwahl: View {
    let mitte: CLLocationCoordinate2D
    let uebernehmen: (CLLocationCoordinate2D, String) -> Void

    @Environment(\.dismiss) private var schliessen
    @State private var kamera: MapCameraPosition
    @State private var aktuell: CLLocationCoordinate2D
    @State private var name: String = "Punkt auf der Karte"

    init(mitte: CLLocationCoordinate2D, uebernehmen: @escaping (CLLocationCoordinate2D, String) -> Void) {
        self.mitte = mitte
        self.uebernehmen = uebernehmen
        _kamera = State(
            initialValue: .region(
                MKCoordinateRegion(center: mitte, latitudinalMeters: 1400, longitudinalMeters: 1400)
            )
        )
        _aktuell = State(initialValue: mitte)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $kamera) { }
                    .mapStyle(.standard(pointsOfInterest: .including([.publicTransport])))
                    .onMapCameraChange(frequency: .onEnd) { zustand in
                        aktuell = zustand.camera.centerCoordinate
                        Task { await namenSuchen(aktuell) }
                    }
                    .ignoresSafeArea(edges: .bottom)

                // Das Kreuz liegt in derselben Mitte wie die Karte — beide
                // füllen diesen Stapel. Es darf keine Tipper abfangen, sonst
                // ließe sich die Karte genau dort nicht verschieben, wo man
                // sie am ehesten anfasst.
                Fadenkreuz()
                    .allowsHitTesting(false)

                VStack {
                    Spacer()
                    Uebernahmeleiste(name: name, koordinate: aktuell) {
                        uebernehmen(aktuell, name)
                    }
                }
            }
            .navigationTitle("Punkt wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { schliessen() }
                }
            }
        }
    }

    /// Fragt die Karte, wie die Gegend heißt. Rein für die Beschriftung — die
    /// Abfahrten hängen an der Koordinate und nicht am Namen. Schlägt es fehl,
    /// bleibt „Punkt auf der Karte" stehen; das ist keine schöne, aber eine
    /// richtige Auskunft.
    private func namenSuchen(_ punkt: CLLocationCoordinate2D) async {
        let ort = CLLocation(latitude: punkt.latitude, longitude: punkt.longitude)
        guard let marke = try? await CLGeocoder().reverseGeocodeLocation(ort).first else { return }
        let teile = [marke.thoroughfare, marke.locality ?? marke.subAdministrativeArea]
            .compactMap { $0 }
        name = teile.isEmpty ? "Punkt auf der Karte" : teile.joined(separator: ", ")
    }
}

private struct Fadenkreuz: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.accentColor, lineWidth: 3)
                .background(Circle().fill(Color.accentColor.opacity(0.14)))
                .frame(width: 34, height: 34)
            Circle()
                .fill(Color.accentColor)
                .frame(width: 7, height: 7)
        }
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
    }
}

private struct Uebernahmeleiste: View {
    let name: String
    let koordinate: CLLocationCoordinate2D
    let tat: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(String(format: "%.5f, %.5f", koordinate.latitude, koordinate.longitude))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Button(action: tat) {
                Text("Abfahrten hier anzeigen")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(14)
    }
}

#Preview {
    OrtswahlView()
        .environmentObject(AppModel(dienst: Musterdienst()))
        .environmentObject(Standortdienst())
        .environmentObject(Merkliste())
}
