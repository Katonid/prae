import MapKit
import SwiftUI

/// Ort einer Aufnahme festlegen (seit 1.0.15) — Karte, Suche und Stecknadel aus PhotoLocator:
/// tippen setzt die Nadel genau dorthin, gedrückt halten und ziehen verschiebt sie; im
/// Suchfeld Orte, Adressen oder GPS-Koordinaten (z. B. „47.6, 12.98").
struct OrtWahlAnsicht: View {
    let start: CLLocationCoordinate2D?
    var uebernehmen: (CLLocationCoordinate2D) -> Void
    @Environment(\.dismiss) private var schliessen
    @State private var nadel: CLLocationCoordinate2D?
    @State private var suche = OrtsSuche()
    @State private var gedaechtnis = KartenGedaechtnis()
    @State private var steuerung = KartenSteuerung()
    @State private var aufloesung = Adressaufloesung()
    @State private var adresse: String?
    @State private var bereit = false
    @State private var meldung: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                if bereit {
                    KartenAnsicht(nadel: nadel, typ: gedaechtnis.typ, steuerung: steuerung, gedaechtnis: gedaechtnis) { k in
                        setzen(k, name: nil)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
                if !suche.vorschlaege.isEmpty {
                    List(suche.vorschlaege, id: \.self) { v in
                        Button {
                            Task {
                                do {
                                    let t = try await suche.ort(fuer: v)
                                    setzen(t.koordinate, name: t.name, spanne: t.spanne)
                                } catch { meldung = error.localizedDescription }
                            }
                        } label: {
                            VStack(alignment: .leading) {
                                Text(v.title).foregroundStyle(.primary)
                                if !v.subtitle.isEmpty { Text(v.subtitle).font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .frame(maxHeight: 300)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    if let k = nadel {
                        Text(adresse ?? "Adresse wird gesucht …").font(.subheadline.weight(.semibold))
                        Text(Koordinaten.text(k)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    } else {
                        Text("Auf die Karte tippen, um den Ort zu setzen.").font(.subheadline)
                    }
                    Text("Nadel gedrückt halten und ziehen verschiebt sie.").font(.caption2).foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
            }
            .searchable(text: $suche.text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Ort, Adresse oder Koordinaten")
            .onSubmit(of: .search) {
                Task {
                    do {
                        let t = try await suche.freieSuche()
                        setzen(t.koordinate, name: t.name, spanne: t.spanne)
                    } catch { meldung = error.localizedDescription }
                }
            }
            .navigationTitle("Ort festlegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        if let k = nadel { uebernehmen(k) }
                        schliessen()
                    }
                    .disabled(nadel == nil)
                }
                ToolbarItem(placement: .bottomBar) {
                    Picker("Karte", selection: $gedaechtnis.typ) {
                        ForEach(Kartentyp.allCases) { t in Label(t.titel, systemImage: t.symbol).tag(t) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .alert("Hinweis", isPresented: Binding(get: { meldung != nil }, set: { if !$0 { meldung = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(meldung ?? "") }
            .task {
                // Die Karte öffnet beim bisherigen Ort (sonst beim zuletzt gezeigten Ausschnitt).
                if let k = start, Koordinaten.gueltig(k) {
                    gedaechtnis.merken(MKCoordinateRegion(center: k, latitudinalMeters: 3000, longitudinalMeters: 3000))
                    nadel = k
                    adresse = await aufloesung.adresse(fuer: k)
                }
                bereit = true
            }
            .onChange(of: bereit) { if let r = steuerung.region { suche.bereich(r) } }
        }
    }

    private func setzen(_ k: CLLocationCoordinate2D, name: String?, spanne: CLLocationDegrees? = nil) {
        nadel = k
        adresse = name
        if let spanne { steuerung.zeige(k, spanne: spanne) } else { steuerung.sichtbarMachen(k, heranzoomen: false) }
        if name != nil { suche.leeren() }
        Task {
            let a = await aufloesung.adresse(fuer: k)
            if nadel.map({ Koordinaten.gleich($0, k) }) == true, name == nil || adresse == nil { adresse = a }
        }
    }
}
