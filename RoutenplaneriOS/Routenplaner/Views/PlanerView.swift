import SwiftUI
import MapKit

/// Der Hauptbildschirm: die Karte, darunter Start, Ziel, Profil und das
/// Ergebnis in einer Zeile. Alles Weitere steht in der Detailansicht.
struct PlanerView: View {
    @EnvironmentObject private var planer: Planer
    @EnvironmentObject private var standort: Standort
    @State private var kamera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var ortswahl: Ortsfeld?
    @State private var zeigeProfile = false
    @State private var zeigeDetails = false
    /// Die angetippte Stelle. Der WUNSCH trägt den Ort — kein Schalter
    /// daneben (Lehre aus Abfahrtstafel 1.0.9).
    @State private var angetippt: Ort?
    @AppStorage("verkehrslageZeigen") private var verkehrslage = true

    var body: some View {
        Routenkarte(route: planer.route, start: planer.start, ziel: planer.ziel,
                    markierung: angetippt?.punkt, verkehrslage: verkehrslage,
                    kamera: $kamera, tippen: antippen)
            .ignoresSafeArea(edges: .top)
            .confirmationDialog(angetippt?.name ?? "Punkt auf der Karte",
                                isPresented: Binding(get: { angetippt != nil },
                                                     set: { if !$0 { angetippt = nil } }),
                                titleVisibility: .visible,
                                presenting: angetippt) { ort in
                Button("Route hierhin – von meinem Standort") { routeHierhin(ort) }
                if planer.start != nil {
                    Button("Als Ziel übernehmen") { uebernehmen(ort, als: .ziel) }
                }
                Button("Als Start übernehmen") { uebernehmen(ort, als: .start) }
                Button("Abbrechen", role: .cancel) {}
            }
            .safeAreaInset(edge: .bottom) { bedienfeld }
            .sheet(item: $ortswahl) { feld in
                OrtswahlView(feld: feld) { ort in
                    if feld == .start { planer.start = ort } else { planer.ziel = ort }
                    planer.berechnen()
                }
                .environmentObject(standort)
            }
            // Neu gerechnet wird beim SCHLIESSEN der Profile — nicht bei jedem
            // Tastendruck im Namensfeld.
            .sheet(isPresented: $zeigeProfile, onDismiss: { planer.berechnen() }) {
                ProfileView().environmentObject(planer)
            }
            .sheet(isPresented: $zeigeDetails) {
                RoutenDetailView().environmentObject(planer)
            }
            .onChange(of: planer.route?.punkte) { _, punkte in
                if let punkte, let rect = Geo.rahmen(punkte) {
                    withAnimation { kamera = .rect(rect) }
                }
            }
    }

    // MARK: - Tipp auf die Karte

    private func antippen(_ p: Punkt) {
        // Erst die Frage, dann der Name: Der Geocoder braucht eine Sekunde,
        // und ein Tipp, auf den eine Sekunde lang nichts geschieht, sieht
        // aus wie einer, der nicht angekommen ist. Die späte Antwort schreibt
        // nur, wenn noch DERSELBE Punkt gemeint ist.
        angetippt = Ort(name: "Punkt auf der Karte", punkt: p)
        Task {
            guard let name = await Ortsname.nachschlagen(p), angetippt?.punkt == p else { return }
            angetippt = Ort(name: name, punkt: p)
        }
    }

    private func routeHierhin(_ ort: Ort) {
        planer.ziel = ort
        if let hier = standort.punkt {
            planer.start = Ort(name: "Mein Standort", punkt: hier)
            planer.berechnen()
        } else {
            // Nicht raten und nicht still auf einem alten Start rechnen:
            // Ohne Ortung gibt es kein „von hier".
            standort.anfragen()
            planer.start = nil
            planer.berechnen()
            planer.fehler = standort.abgelehnt
                ? "Das Ziel ist gesetzt, aber die Ortung ist abgelehnt. Den Start oben eintippen — oder die Ortung in den Einstellungen erlauben."
                : "Das Ziel ist gesetzt, der eigene Standort ist aber noch nicht bekannt. Einen Augenblick warten und noch einmal tippen — oder den Start oben eintippen."
        }
    }

    private func uebernehmen(_ ort: Ort, als feld: Ortsfeld) {
        if feld == .start { planer.start = ort } else { planer.ziel = ort }
        planer.berechnen()
    }

    private var bedienfeld: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                VStack(spacing: 6) {
                    ortsknopf(.start, planer.start, farbe: .green)
                    ortsknopf(.ziel, planer.ziel, farbe: .red)
                }
                Button {
                    planer.tauschen()
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Start und Ziel tauschen")
                .disabled(planer.start == nil && planer.ziel == nil)
            }

            HStack {
                Button {
                    zeigeProfile = true
                } label: {
                    Label(planer.profil.name, systemImage: planer.profil.symbol)
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)
                Spacer()
                Toggle(isOn: $verkehrslage) {
                    Image(systemName: "car.2.fill")
                }
                .toggleStyle(.button)
                .accessibilityLabel("Verkehrslage auf der Karte")
                .accessibilityValue(verkehrslage ? "an" : "aus")
                if planer.profil.art == .auto {
                    Toggle(isOn: $planer.verkehrBeachten) {
                        Label("Meldungen", systemImage: "exclamationmark.triangle")
                    }
                    .toggleStyle(.button)
                    .onChange(of: planer.verkehrBeachten) { _, _ in planer.berechnen() }
                }
                if planer.profil.art == .fahrrad {
                    // Sichtbar im Bedienfeld und nicht nur im Profil: Ob
                    // geschoben werden darf, entscheidet man je Fahrt.
                    Toggle(isOn: Binding(get: { planer.profil.schieben },
                                         set: { planer.schiebenSetzen($0) })) {
                        Label(planer.profil.schieben ? "Schieben erlaubt" : "Ohne Schieben",
                              systemImage: planer.profil.schieben ? "figure.walk" : "bicycle")
                    }
                    .toggleStyle(.button)
                    .accessibilityHint("Schaltet um, ob Gehwege und Fußgängerzonen schiebend benutzt werden dürfen.")
                }
            }

            ergebnis
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
        .frame(maxWidth: 620)
    }

    private func ortsknopf(_ feld: Ortsfeld, _ ort: Ort?, farbe: Color) -> some View {
        Button {
            ortswahl = feld
        } label: {
            HStack(spacing: 8) {
                Circle().fill(farbe).frame(width: 10, height: 10)
                Text(ort?.name ?? "\(feld.titel) wählen")
                    .foregroundStyle(ort == nil ? Color.secondary : Color.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var ergebnis: some View {
        if planer.laedt {
            HStack(spacing: 8) {
                ProgressView()
                Text(planer.profil.art == .auto && planer.verkehrBeachten
                     ? "Route und Verkehrsmeldungen werden geholt …"
                     : "Route wird berechnet …")
                    .foregroundStyle(.secondary)
            }
        } else if let f = planer.fehler {
            VStack(alignment: .leading, spacing: 6) {
                Label(f, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
                Button("Noch einmal versuchen") { planer.berechnen() }
                    .font(.callout)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let r = planer.route {
            Button {
                zeigeDetails = true
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(Anzeige.dauer(r.zeitS)).font(.title2.bold())
                    Text(Anzeige.strecke(r.laengeM)).foregroundStyle(.secondary)
                    Spacer()
                    zusammenfassungZeichen(r)
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else if !planer.bereit {
            Text("Auf die Karte tippen oder Start und Ziel oben eintippen — die Route wird dann sofort berechnet.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private func zusammenfassungZeichen(_ r: Route) -> some View {
        let gefahr = r.hinweise.filter { $0.stufe == .gefahr }.count
        let warnung = r.hinweise.filter { $0.stufe == .warnung }.count
        HStack(spacing: 8) {
            if !r.umfahren.isEmpty {
                Label("\(r.umfahren.count)", systemImage: "arrow.uturn.right")
                    .foregroundStyle(.blue)
            }
            if gefahr > 0 {
                Label("\(gefahr)", systemImage: Hinweis.Stufe.gefahr.symbol).foregroundStyle(.red)
            }
            if warnung > 0 {
                Label("\(warnung)", systemImage: Hinweis.Stufe.warnung.symbol).foregroundStyle(.orange)
            }
        }
        .font(.callout)
        .labelStyle(.titleAndIcon)
    }
}
