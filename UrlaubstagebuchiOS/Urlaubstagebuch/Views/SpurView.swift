import MapKit
import SwiftUI

// Die Reisepunkte eines Tages: was auf der Karte steht, in Worten.
struct SpurView: View {
    @ObservedObject var werk: Reisewerk
    let tagID: UUID
    @Environment(\.dismiss) private var schliessen
    @State private var punktwahl = false

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
                        Text("Beim Neubauen bleiben die von Hand gesetzten Punkte erhalten; die Fotopunkte werden ersetzt.")
                    }

                    Section {
                        if tag.spur.isEmpty {
                            Text("Noch keine Punkte. Fotos mit Aufnahmeort bringen sie von selbst mit — sonst setzt du sie auf der Karte.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(tag.spur) { punkt in
                            PunktZeile(punkt: punkt)
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
                        if tag.hatStrecke {
                            Text("\(Spurbau.laengeText(tag.spur)). Gezeichnet wird die Verbindung der Punkte, nicht der gefahrene Weg — welche Straße es war, steht in keinem Foto.")
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
        }
    }

    private func vorschau(_ tag: Reisetag) -> some View {
        Map(initialPosition: .automatic, interactionModes: [.pan, .zoom]) {
            if tag.spur.count >= 2 {
                MapPolyline(coordinates: tag.spur.map(\.koordinate.clLocation))
                    .stroke(werk.reise.linienfarbe.farbe, lineWidth: 3)
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
