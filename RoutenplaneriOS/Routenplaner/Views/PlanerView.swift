import SwiftUI
import MapKit

/// Der Hauptbildschirm: die Karte, darunter Start, Ziel, Profil und das
/// Ergebnis in einer Zeile. Alles Weitere steht in der Detailansicht.
struct PlanerView: View {
    @EnvironmentObject private var planer: Planer
    @EnvironmentObject private var standort: Standort
    @State private var kamerawunsch: Kamerawunsch?
    @State private var ortswahl: Ortsfeld?
    @State private var zeigeProfile = false
    @State private var zeigeDetails = false
    /// Die angetippte Stelle. Der WUNSCH trägt den Ort — kein Schalter
    /// daneben (Lehre aus Abfahrtstafel 1.0.9).
    @State private var angetippt: Ort?
    // Die Kartenwahl gehört dem Gerät und steht deshalb in einer VIEW —
    // nie als `@AppStorage` im `Planer` (dort löste sie kein Neuzeichnen aus).
    @AppStorage("verkehrslageZeigen") private var verkehrslage = true
    @AppStorage("kartengrund") private var grundkarte: Grundkarte = .apple
    @AppStorage("kartenhelligkeit") private var helligkeit: Kartenhelligkeit = .geraet
    @AppStorage("radwegeZeigen") private var radwege = false
    @AppStorage("radroutenZeigen") private var radrouten = false
    @AppStorage("belagZeigen") private var belag = false

    private var ansicht: Kartenansicht {
        Kartenansicht(grundkarte: grundkarte, helligkeit: helligkeit, radwege: radwege,
                      radrouten: radrouten, belag: belag, verkehrslage: verkehrslage)
    }

    var body: some View {
        Routenkarte(route: planer.route, start: planer.start, ziel: planer.ziel,
                    markierung: angetippt?.punkt, ansicht: ansicht,
                    kamerawunsch: kamerawunsch, tippen: antippen)
            .ignoresSafeArea(edges: .top)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    kartenmenue
                    if belag, let r = planer.route { Belaglegende(route: r) }
                }
                .padding(.leading, 12)
                .padding(.top, 8)
            }
            .overlay(alignment: .bottomTrailing) {
                if let lizenz = ansicht.lizenz {
                    // Nicht abschaltbar: OSM und CC-BY-SA verlangen den
                    // Hinweis sichtbar auf der Karte.
                    Text(lizenz)
                        .font(.system(size: 9))
                        .multilineTextAlignment(.trailing)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 4))
                        .padding(4)
                        .allowsHitTesting(false)
                }
            }
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
                    kamerawunsch = Kamerawunsch(rahmen: rect)
                }
            }
    }

    // MARK: - Kartenmenü

    /// Der Schalter an der Karte: Grundkarte, Helligkeit, Einblendungen. Die
    /// Verkehrslage wohnt seit 1.0.3 hier und nicht mehr im Bedienfeld —
    /// zwei Schalter für dieselbe Sache wären einer zu viel.
    private var kartenmenue: some View {
        Menu {
            Picker("Karte", selection: $grundkarte) {
                ForEach(Grundkarte.allCases) { g in
                    Label(g.name, systemImage: g.symbol).tag(g)
                }
            }
            .pickerStyle(.inline)
            Picker("Helligkeit", selection: $helligkeit) {
                ForEach(Kartenhelligkeit.allCases) { h in
                    Label(h.name, systemImage: h.symbol).tag(h)
                }
            }
            .pickerStyle(.inline)
            Section("Einblenden") {
                Toggle(isOn: $radwege) {
                    Label(grundkarte == .cyclosm ? "Radwege (in CyclOSM enthalten)" : "Radwege und Radstreifen",
                          systemImage: "bicycle")
                }
                .disabled(grundkarte == .cyclosm)
                Toggle(isOn: $radrouten) {
                    Label("Ausgeschilderte Radrouten", systemImage: "signpost.right")
                }
                Toggle(isOn: $belag) {
                    Label("Belag der Radroute", systemImage: "road.lanes")
                }
                Toggle(isOn: $verkehrslage) {
                    Label(grundkarte.istApple ? "Verkehrslage" : "Verkehrslage (nur Apple-Karte)",
                          systemImage: "car.2.fill")
                }
                .disabled(!grundkarte.istApple)
            }
            Section {
                Text("Dunkel und Verkehrslage gibt es nur auf Apples Karte — die freien Karten liegen nur hell vor.")
            }
        } label: {
            Image(systemName: "square.3.layers.3d")
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityLabel("Kartenansicht")
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

/// Was der Belag der Radroute bedeutet, samt Strecke je Klasse. Ein Bild,
/// kein Knopf: Es liegt auf der Karte und nimmt keinen Finger an.
struct Belaglegende: View {
    let route: Route

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if route.belaege.isEmpty {
                Text("Den Belag kennt die App nur bei Radrouten von BRouter.")
            } else {
                ForEach(Belag.allCases, id: \.self) { b in
                    let meter = route.belaege.filter { $0.belag == b }.reduce(0) { $0 + $1.laengeM }
                    if meter > 0 {
                        HStack(spacing: 6) {
                            Capsule().fill(Color(uiColor: b.uiFarbe)).frame(width: 18, height: 5)
                            Text(b.name)
                            Spacer(minLength: 4)
                            Text(Anzeige.strecke(meter)).foregroundStyle(.secondary)
                        }
                    }
                }
                Text("Schiebestellen stehen in der Übersicht — oder Belag ausblenden.")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption2)
        .padding(8)
        .frame(maxWidth: 250, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .allowsHitTesting(false)
    }
}
