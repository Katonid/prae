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

    // MEHRERE PUNKTE AUF EINMAL (ab 1.0.21).
    //
    // Der Modus ist SICHTBAR: Die Überschrift zählt mit, der Knopf heißt
    // „Fertig", und vor jeder Zeile steht ein Kreis statt eines Pfeils. Ein
    // Modus, den man nicht sieht, darf die Bedeutung eines Tipps nicht
    // ändern — dieselbe Regel wie beim Fußwegmesser der Abfahrtstafel.
    @State private var auswahlmodus = false
    @State private var auswahl: Set<UUID> = []
    @State private var verschieben = false

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
                        // DER WEG ZUR KARTE HEISST JETZT NACH DEM, WAS
                        // DORT GEHT (ab 1.0.37). „Punkt auf der Karte
                        // setzen" klang nach einem Weg, der nur hinzufügt —
                        // dabei lässt sich auf derselben Karte seit 1.0.37
                        // jeder vorhandene Punkt antippen, verschieben und
                        // löschen. Ein Menüpunkt, der nicht sagt, was
                        // dahinter liegt, ist so wenig wert wie ein Knopf,
                        // den niemand findet.
                        Button {
                            punktwahl = true
                        } label: {
                            Label("Punkte auf der Karte\u{2026}", systemImage: "map")
                        }
                        Button {
                            werk.spurAktualisieren(tagID)
                            werk.meldung = .init(text: "Spur aus den Fotos neu gebaut.")
                        } label: {
                            Label("Aus den Fotos neu bauen", systemImage: "arrow.clockwise")
                        }
                    } footer: {
                        Text("Auf der Karte lässt sich jeder Punkt antippen, verschieben und "
                             + "löschen \u{2014} dort findet man ihn leichter wieder als in der "
                             + "Liste. Ein Tipp auf eine Zeile hier öffnet denselben Bildschirm "
                             + "bei diesem Punkt. Beim Neubauen aus den Fotos bleiben die von "
                             + "Hand gesetzten Punkte erhalten; die Fotopunkte werden ersetzt.")
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
                                if auswahlmodus {
                                    if auswahl.contains(punkt.id) {
                                        auswahl.remove(punkt.id)
                                    } else {
                                        auswahl.insert(punkt.id)
                                    }
                                } else {
                                    bearbeiten = Punktwunsch(id: punkt.id)
                                }
                            } label: {
                                PunktZeile(punkt: punkt,
                                           gewaehlt: auswahlmodus ? auswahl.contains(punkt.id) : nil)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { stellen in werk.punkteLoeschen(tagID, stellen: stellen) }
                        .onMove { von, nach in werk.punkteVerschieben(tagID, von: von, nach: nach) }
                    } header: {
                        HStack {
                            Text(auswahlmodus
                                 ? "\(auswahl.count) von \(tag.spur.count) gewählt"
                                 : "\(tag.spur.count) Punkte")
                            Spacer()
                            Button(auswahlmodus ? "Fertig" : "Auswählen") {
                                auswahlmodus.toggle()
                                if !auswahlmodus { auswahl = [] }
                            }
                            .font(.caption)
                            // Das Ordnen und das Auswählen sind zwei Modi.
                            // Beide gleichzeitig anzubieten hieße, dass ein
                            // Tipp drei Bedeutungen hätte.
                            if !auswahlmodus { EditButton().font(.caption) }
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

                    if auswahlmodus {
                        Section {
                            Button(auswahl.count == tag.spur.count ? "Keinen wählen" : "Alle wählen") {
                                auswahl = auswahl.count == tag.spur.count
                                    ? []
                                    : Set(tag.spur.map(\.id))
                            }
                            Button {
                                verschieben = true
                            } label: {
                                Label("Zeiten verschieben\u{2026}", systemImage: "clock.arrow.2.circlepath")
                            }
                            .disabled(auswahl.isEmpty)
                            Button(role: .destructive) {
                                werk.punkteLoeschen(tagID, ids: auswahl)
                                auswahl = []
                            } label: {
                                Label("Gewählte löschen", systemImage: "trash")
                            }
                            .disabled(auswahl.isEmpty)
                        } footer: {
                            Text("Alle gewählten Punkte werden um denselben Betrag verschoben "
                                 + "\u{2014} zum Beispiel, wenn die Kamera auf der Uhrzeit von "
                                 + "zu Hause stand.")
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
                PunktwahlView(werk: werk, tagID: tagID, start: wunsch.id)
            }
            .sheet(isPresented: $verschieben) {
                Zeitverschiebung(werk: werk, tagID: tagID, punkte: auswahl) {
                    auswahl = []
                    auswahlmodus = false
                }
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
    /// Leer heißt: kein Auswahlmodus. Dann steht rechts ein Pfeil, und ein
    /// Tipp öffnet den Punkt.
    var gewaehlt: Bool?

    var body: some View {
        HStack(spacing: 10) {
            if let gewaehlt {
                Image(systemName: gewaehlt ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(gewaehlt ? Color.accentColor : .secondary)
            }
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
            if gewaehlt == nil {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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
