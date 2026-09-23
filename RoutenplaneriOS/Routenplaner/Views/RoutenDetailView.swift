import SwiftUI

/// Alles zur Route: wie die Zeit zustande kommt, was zu beachten ist, welche
/// Verkehrsmeldungen berücksichtigt wurden, wo geschoben wird.
struct RoutenDetailView: View {
    @EnvironmentObject private var planer: Planer
    @Environment(\.dismiss) private var schliessen
    @State private var gpx: URL?

    var body: some View {
        NavigationStack {
            Group {
                if let r = planer.route {
                    liste(r)
                } else {
                    ContentUnavailableView("Keine Route", systemImage: "map",
                                           description: Text(planer.fehler ?? "Start und Ziel wählen."))
                }
            }
            .navigationTitle("Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } }
                ToolbarItem(placement: .topBarLeading) {
                    if let gpx {
                        ShareLink(item: gpx) { Label("GPX", systemImage: "square.and.arrow.up") }
                    }
                }
            }
            .task(id: "\(planer.gewaehlt)-\(planer.route?.punkte.count ?? 0)") { gpx = GPX.datei(planer.route, profil: planer.profil) }
        }
    }

    private func liste(_ r: Route) -> some View {
        List {
            Section {
                LabeledContent("Strecke", value: Anzeige.strecke(r.laengeM))
                LabeledContent("Zeit", value: Anzeige.dauer(r.zeitS))
                ForEach(r.posten) { p in
                    LabeledContent(p.text, value: "+" + Anzeige.dauer(p.sekunden))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if let d = r.zeitDienstS {
                    LabeledContent("Zum Vergleich: Routendienst", value: Anzeige.dauer(d))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(planer.profil.name)
            } footer: {
                Text("Quelle: \(r.quelle). Die Zeit ist selbst gerechnet; jede Zeile sagt, woher sie kommt.")
            }

            if !r.hinweise.isEmpty {
                Section("Zu beachten") {
                    ForEach(r.hinweise) { h in
                        Label {
                            Text(h.text).font(.callout)
                        } icon: {
                            Image(systemName: h.stufe.symbol).foregroundStyle(h.stufe.farbe)
                        }
                    }
                }
            }

            if !r.umfahren.isEmpty {
                Section {
                    ForEach(r.umfahren) { m in
                        meldungszeile(m)
                            .swipeActions {
                                if planer.eigeneSperren.contains(m) {
                                    Button("Nicht mehr meiden") { planer.nichtMehrMeiden(m) }
                                }
                            }
                    }
                } header: {
                    Text("Umfahren")
                } footer: {
                    Text("Gemieden wird ein Feld von rund 250 m um die Mitte der Meldung — in BEIDEN Richtungen und samt jeder Straße, die es kreuzt. Genauer lässt sich eine Fläche nicht ziehen.")
                }
            }

            if !r.meldungen.isEmpty {
                Section {
                    ForEach(r.meldungen) { m in
                        meldungszeile(m)
                            .swipeActions {
                                Button("Meiden") { planer.meiden(m) }.tint(.blue)
                            }
                    }
                } header: {
                    Text("Auf der Route")
                } footer: {
                    Text("Nach links wischen, um eine Stelle zu meiden. Ein Stau verlängert die Zeit, verlegt die Route aber nicht von selbst.")
                }
            } else if r.verkehrGeprueft {
                Section("Verkehr") {
                    Text("Auf den Autobahnen dieser Route liegt keine gültige Meldung der Autobahn GmbH. Andere Straßen sind darin nicht enthalten.")
                        .font(.callout)
                }
            }

            if !r.angekuendigt.isEmpty {
                Section("Angekündigt, noch nicht gültig") {
                    ForEach(r.angekuendigt) { meldungszeile($0) }
                }
            }

            if !r.schiebestrecken.isEmpty {
                Section("Absteigen") {
                    ForEach(r.schiebestrecken) { a in
                        HStack {
                            Image(systemName: a.art == .treppe ? "stairs" : "figure.walk")
                                .foregroundStyle(a.art.farbe)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text(a.art.name)
                                if let w = a.wegart { Text(w).font(.caption).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            Text(Anzeige.strecke(a.laengeM)).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !r.anweisungen.isEmpty {
                Section("Wegbeschreibung") {
                    ForEach(r.anweisungen) { a in
                        HStack(alignment: .firstTextBaseline) {
                            Text(a.text).font(.callout)
                            Spacer()
                            if a.laengeM > 0 {
                                Text(Anzeige.strecke(a.laengeM)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func meldungszeile(_ m: Verkehrsmeldung) -> some View {
        DisclosureGroup {
            ForEach(Array(m.beschreibung.enumerated()), id: \.offset) { _, zeile in
                if !zeile.isEmpty { Text(zeile).font(.caption) }
            }
        } label: {
            HStack(alignment: .top) {
                Image(systemName: m.art.symbol).foregroundStyle(m.art.farbe).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(m.art.name): \(m.titel)").font(.callout)
                    if !m.richtung.isEmpty {
                        Text(m.richtung).font(.caption).foregroundStyle(.secondary)
                    }
                    if let v = m.verzoegerungMin, v > 0 {
                        Text("Zeitverlust laut Meldung: \(Int(v)) min").font(.caption).foregroundStyle(.orange)
                    }
                    if let b = m.hoechstbreiteM {
                        Text("Durchfahrtsbreite \(Anzeige.zahl(b)) m").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// Die Route als GPX-Datei — zum Übertragen in ein Navi oder eine andere App.
enum GPX {
    static func datei(_ route: Route?, profil: Fahrzeugprofil) -> URL? {
        guard let route, !route.punkte.isEmpty else { return nil }
        var text = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        text += "<gpx version=\"1.1\" creator=\"Routenplaner\" xmlns=\"http://www.topografix.com/GPX/1/1\">\n"
        text += "<trk><name>\(maskiert(profil.name))</name><trkseg>\n"
        for p in route.punkte {
            text += "<trkpt lat=\"\(p.breite)\" lon=\"\(p.laenge)\"/>\n"
        }
        text += "</trkseg></trk></gpx>\n"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Route.gpx")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private static func maskiert(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
