import MapKit
import SwiftUI

// Die Reisepunkte eines Tages: was auf der Karte steht, in Worten.
struct SpurView: View {
    @ObservedObject var werk: Reisewerk
    let tagID: UUID
    @Environment(\.dismiss) private var schliessen
    @State private var punktwahl = false
    // Welcher Punkt gerade geändert wird. Der WUNSCH trägt das Ziel, kein
    // Schalter daneben — dieselbe Regel wie bei den Dateiwählern.
    @State private var bearbeiten: Punktwunsch?

    struct Punktwunsch: Identifiable { let id: UUID }

    private var tag: Reisetag? { werk.reise.tage.first { $0.id == tagID } }

    var body: some View {
        NavigationStack {
            List {
                if let tag {
                    Section {
                        vorschau(tag)
                            .frame(height: 200)
                            .listRowInsets(EdgeInsets())
                    }
                    Section {
                        Button {
                            punktwahl = true
                        } label: {
                            Label("Punkt auf der Karte setzen", systemImage: "mappin.and.ellipse")
                        }
                        Button {
                            werk.spurAktualisieren(tagID)
                            werk.meldung = .init(text: "Spur aus den Fotos neu gebaut.")
                        } label: {
                            Label("Aus den Fotos neu bauen", systemImage: "arrow.clockwise")
                        }
                    } footer: {
                        Text("Beim Neubauen bleiben die von Hand gesetzten Punkte erhalten; "
                             + "die Fotopunkte werden ersetzt. Ein Tipp auf einen Punkt in der "
                             + "Liste öffnet ihn zum Ändern \u{2014} Ort, Name, Uhrzeit, Löschen.")
                    }

                    Section {
                        if tag.spur.isEmpty {
                            Text("Noch keine Punkte. Fotos mit Aufnahmeort bringen sie von selbst mit — sonst setzt du sie auf der Karte.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(tag.spur) { punkt in
                            // Die ZEILE ist der Weg zum Ändern. Ein Punkt,
                            // den man nur wegwischen kann, lässt sich nicht
                            // berichtigen — und ein Knopf in einem Menü wäre
                            // einer, den niemand findet.
                            Button {
                                bearbeiten = Punktwunsch(id: punkt.id)
                            } label: {
                                PunktZeile(punkt: punkt)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { stellen in werk.punkteLoeschen(tagID, stellen: stellen) }
                        .onMove { von, nach in werk.punkteVerschieben(tagID, von: von, nach: nach) }
                    } header: {
                        HStack {
                            Text("\(tag.spur.count) Punkte")
                            Spacer()
                            EditButton().font(.caption)
                        }
                    } footer: {
                        VStack(alignment: .leading, spacing: 6) {
                            if tag.hatStrecke {
                                Text("\(Spurbau.laengeText(tag.spur)). Gezeichnet wird die Verbindung der Punkte, nicht der gefahrene Weg — welche Straße es war, steht in keinem Foto.")
                            }
                            // Eine Uhrzeit ohne Angabe, worauf sie sich
                            // bezieht, ist in einem Reisetagebuch eine
                            // Zumutung: Dieselbe Reise hat Tage in zwei
                            // Zonen. Dieselbe Regel wie beim Wort „Plan"
                            // an einer Abfahrt ohne Echtzeit.
                            Text(zeitsatz(tag))
                        }
                    }

                    Section("Ausdünnen") {
                        VStack(alignment: .leading) {
                            LabeledContent("Mindestabstand",
                                           value: "\(Int(werk.reise.gestaltung.mindestabstandSpur)) m")
                            Slider(value: Binding(
                                get: { werk.reise.gestaltung.mindestabstandSpur },
                                set: { werk.reise.gestaltung.mindestabstandSpur = $0 }
                            ), in: 0...2000, step: 25)
                        }
                        Text("Fotos, die näher als dieser Abstand beieinander liegen, werden zu einem Punkt zusammengefasst. Ohne das wäre eine Stadtbesichtigung ein einziger Fleck.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Reisepunkte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
            .sheet(isPresented: $punktwahl) {
                PunktwahlView(werk: werk, tagID: tagID)
            }
            .sheet(item: $bearbeiten) { wunsch in
                PunktwahlView(werk: werk, tagID: tagID, punktID: wunsch.id)
            }
        }
    }

    // Worauf sich die Uhrzeiten dieses Tages beziehen.
    private func zeitsatz(_ tag: Reisetag) -> String {
        let grundsatz = "Alle Uhrzeiten sind Ortszeiten: bei Fotos so, wie die Kamera "
            + "sie geschrieben hat, bei einer eingelesenen Reisespur umgerechnet."
        guard let kennung = tag.zeitzone, let zone = TimeZone(identifier: kennung) else {
            return grundsatz
        }
        return grundsatz + " Für diesen Tag gilt "
            + Ortszeit.beschreibung(zone, am: tag.datum.mittag) + "."
    }

    private func vorschau(_ tag: Reisetag) -> some View {
        Map(initialPosition: .automatic, interactionModes: [.pan, .zoom]) {
            if tag.spur.count >= 2 {
                MapPolyline(coordinates: tag.spur.map(\.koordinate.clLocation))
                    .stroke(werk.reise.akzent.farbe, lineWidth: 3)
            }
            ForEach(tag.spur) { punkt in
                Marker(punkt.name.isEmpty ? "Punkt" : punkt.name,
                       systemImage: punkt.istAusFoto ? "camera.fill" : "mappin",
                       coordinate: punkt.koordinate.clLocation)
                    .tint(punkt.istAusFoto ? .blue : Color.accentColor)
            }
        }
    }
}

private struct PunktZeile: View {
    let punkt: Reisepunkt

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: punkt.istAusFoto ? "camera.fill" : "mappin.circle.fill")
                .foregroundStyle(punkt.istAusFoto ? Color.blue : Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(punkt.name.isEmpty ? koordinatentext : punkt.name)
                    .font(.subheadline)
                HStack(spacing: 6) {
                    if let zeit = punkt.zeit {
                        Text(uhr.string(from: zeit))
                    } else {
                        Text("ohne Uhrzeit")
                    }
                    Text("·")
                    Text(punkt.quelle.name)
                    if punkt.zusammengefasst > 1 {
                        Text("· \(punkt.zusammengefasst) Fotos")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var koordinatentext: String {
        String(format: "%.4f, %.4f", punkt.koordinate.breite, punkt.koordinate.laenge)
    }

    private var uhr: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }
}
