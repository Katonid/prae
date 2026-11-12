import SwiftUI

// Der INHALT eines Tages — Text, Überschrift, Fotos. Getrennt vom Satz:
// Was hier steht, gehört dem Nutzer; wie es auf der Seite liegt, ist ein
// Vorschlag der App.
struct TagInhaltView: View {
    @ObservedObject var werk: Reisewerk
    let tagID: UUID
    @Environment(\.dismiss) private var schliessen
    @State private var aufraeumBefund: String?
    @State private var bearbeiten: Texteintrag?

    private var stelle: Int? { werk.tagIndex(tagID) }

    var body: some View {
        NavigationStack {
            if let stelle {
                Form {
                    Section {
                        TextField("z. B. Ankunft in Lissabon",
                                  text: binden(stelle, \.ueberschrift))
                        TextField("Zweite Überschrift, z. B. Lissabon — Alfama",
                                  text: binden(stelle, \.unterueberschrift))
                        TextField(werk.reise.gestaltung.datumsstil
                            .text(werk.reise.tage[stelle].datum,
                                  nummer: stelle + 1),
                                  text: Binding(
                            get: { werk.reise.tage[stelle].datumstext ?? "" },
                            set: { werk.reise.tage[stelle].datumstext = $0.isEmpty ? nil : $0 }
                        ))
                        TextField("Wetter, z. B. Vormittag sonnig, 19\u{2013}25 °C",
                                  text: binden(stelle, \.wetter), axis: .vertical)
                        // Die Tabelle aus Fernweh (ab 1.0.116) geht der Zeile
                        // vor. Ohne diesen Knopf wäre die Zeile darüber ein
                        // Feld, dessen Änderung auf der Seite nichts bewirkt.
                        if let tabelle = werk.reise.tage[stelle].geltendeWettertabelle {
                            LabeledContent("Wettertabelle",
                                           value: "\(tabelle.spalten.count) Spalten")
                            WettergroesseRegler(werk: werk)
                            Button(role: .destructive) {
                                werk.merken()
                                werk.reise.tage[stelle].wettertabelle = nil
                            } label: {
                                Label("Tabelle entfernen, Zeile zeigen", systemImage: "tablecells.badge.ellipsis")
                            }
                        }
                        Toggle("Dieses Kapitel ausblenden", isOn: binden(stelle, \.ausgeblendet))
                    } header: {
                        Text("Überschriften und Datumszeile")
                    } footer: {
                        Text("Überschrift und Datumszeile kommen aus dem Zeitraster und lassen sich hier ändern. Die zweite Überschrift ist für ein Schlagwort gedacht. Sie steht unter der ersten, kleiner und kursiv — beim Einlesen eines Tagebuchtextes findet die App sie in der Zeile nach dem Datum. Bleibt die Datumszeile leer, gilt das Format des Buches. Das Wetter steht als eigene Zeile unter den Überschriften, in der Schrift der Datumszeile; leer heißt keine Wetterzeile. Steht eine Wettertabelle aus Fernweh da, wird sie statt der Zeile gezeigt. Auf die Seite kommt es beim nächsten Anordnen des Tages. Ein ausgeblendeter Tag bleibt vollständig erhalten, kommt aber nicht ins Buch.")
                    }
                    // KAPITELWEISE: Der Text eines Kapitels besteht aus
                    // Einträgen mit Zeitstempel. Bearbeitet wird der
                    // EINTRAG; der Kapiteltext entsteht daraus.
                    let eintraege = werk.reise.kapiteleintraege(werk.reise.tage[stelle].datum)
                    Section {
                        ForEach(eintraege) { eintrag in
                            Button { bearbeiten = eintrag } label: { TexteintragZeile(eintrag: eintrag) }
                                .buttonStyle(.plain)
                        }
                        Button {
                            var neu = Texteintrag()
                            neu.zeit = werk.reise.tage[stelle].datum.mittag
                            bearbeiten = neu
                        } label: {
                            Label("Neuer Text in diesem Kapitel", systemImage: "square.and.pencil")
                        }
                        if eintraege.isEmpty {
                            TextEditor(text: binden(stelle, \.text))
                                .frame(minHeight: 160)
                                .font(.system(size: 14))
                        }
                    } header: {
                        Text("Texte")
                    } footer: {
                        Text(eintraege.isEmpty
                             ? "Texte mit eigenem Zeitpunkt legst du über \u{201E}Neuer Text\u{201C} an. Das Feld darüber ist ein freier Kapiteltext ohne Datum."
                             : "\(eintraege.count) Texte, nach der Zeit. Jeder steht mit Überschrift und Datum im Kapitel.")
                    }

                    Section {
                        Toggle("Karte auf der Seite zeigen", isOn: binden(stelle, \.karteZeigen))
                        Picker("Seitenmuster", selection: Binding(
                            get: { werk.reise.tage[stelle].muster },
                            // Gesetzt wird im WERK und nicht hier: Eine
                            // Ansicht, die den Automaten selbst aufruft,
                            // kennt den Wortlaut in den Blöcken nicht und
                            // überschreibt ihn (siehe
                            // `Reisewerk.wortlautSichern`).
                            set: { neu in
                                werk.musterSetzen(werk.reise.tage[stelle].id, muster: neu)
                            }
                        )) {
                            Text("Automatisch").tag(Seitenmuster?.none)
                            ForEach(Seitenmuster.allCases) { muster in
                                Text(muster.name).tag(Seitenmuster?.some(muster))
                            }
                        }
                        if let muster = werk.reise.tage[stelle].muster {
                            Text(muster.beschreibung)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Satz")
                    }

                    fotoAbschnitt(stelle)
                }
                .navigationTitle(werk.reise.tage[stelle].ueberschrift.isEmpty ? werk.reise.tage[stelle].datum.mittel : werk.reise.tage[stelle].ueberschrift)
                .navigationBarTitleDisplayMode(.inline)
                .sheet(item: $bearbeiten) { eintrag in
                    EintragView(werk: werk, eintrag: eintrag)
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") {
                            werk.neuAnordnen(tagID, erzwingen: false)
                            schliessen()
                        }
                    }
                }
            } else {
                Text("Dieses Kapitel gibt es nicht mehr.")
            }
        }
    }

    @ViewBuilder
    private func fotoAbschnitt(_ stelle: Int) -> some View {
        let tag = werk.reise.tage[stelle]
        Section {
            if tag.fotos.isEmpty {
                Text("Noch keine Fotos in diesem Kapitel.")
                    .foregroundStyle(.secondary)
            }
            ForEach(tag.fotos, id: \.self) { id in
                if let foto = werk.reise.foto(id) {
                    FotoZeile(werk: werk, foto: foto)
                }
            }
            .onMove { von, nach in
                werk.merken()
                werk.reise.tage[stelle].fotos.move(fromOffsets: von, toOffset: nach)
            }
            .onDelete { stellen in
                werk.merken()
                // Nur aus dem TAG entfernt, nicht von der Platte: Das Foto
                // liegt danach in der Ablage. Ein Wisch, der ein Bild
                // endgültig löscht, ist in einem Fotobuch zu leicht
                // passiert.
                let betroffen = stellen.map { werk.reise.tage[stelle].fotos[$0] }
                werk.reise.tage[stelle].fotos.remove(atOffsets: stellen)
                for id in betroffen {
                    for t in werk.reise.tage.indices {
                        for s in werk.reise.tage[t].seiten.indices {
                            werk.reise.tage[t].seiten[s].bloecke.removeAll { $0.fotoID == id }
                        }
                    }
                }
                werk.spurAktualisieren(tagID)
            }
        } header: {
            HStack {
                Text("Fotos (\(tag.fotos.count))")
                Spacer()
                EditButton().font(.caption)
            }
        } footer: {
            Text("Die Reihenfolge hier ist die Reihenfolge auf der Seite. Ein Wisch nimmt das Foto aus dem Kapitel \u{2014} es bleibt in der Ablage.")
        }
    }

    private func binden<W>(_ stelle: Int, _ pfad: WritableKeyPath<Reisetag, W>) -> Binding<W> {
        Binding(
            get: { werk.reise.tage[stelle][keyPath: pfad] },
            set: { werk.reise.tage[stelle][keyPath: pfad] = $0 }
        )
    }
}

struct FotoZeile: View {
    @ObservedObject var werk: Reisewerk
    let foto: Foto

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                Ladebild(datei: foto.datei, reise: werk.reise.id, kante: 160) { bild in
                    Image(uiImage: bild)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(beschriftung)
                    .font(.subheadline)
                    .foregroundStyle(foto.unterschrift.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: foto.hatOrt ? "mappin.circle.fill" : "mappin.slash")
                        .font(.caption2)
                        .foregroundStyle(foto.hatOrt ? Color.accentColor : Color.secondary)
                    Text(foto.ortsquelle.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            // Die Unterschrift lässt sich hier ein- und ausschalten, ohne
            // den Block auf der Seite suchen zu müssen. Ein Muss ist sie
            // nicht (Ansage des Nutzers, 09/2026).
            Button {
                werk.unterschriftUmschalten(foto.id, an: !foto.unterschriftZeigen)
            } label: {
                Image(systemName: foto.unterschriftZeigen
                      ? "text.bubble.fill" : "text.bubble")
                    .foregroundStyle(foto.unterschriftZeigen ? Color.accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(foto.unterschriftZeigen
                                ? "Bildunterschrift ausschalten" : "Bildunterschrift zeigen")
        }
    }

    private var beschriftung: String {
        if !foto.unterschrift.isEmpty { return foto.unterschrift }
        return foto.unterschriftZeigen ? "Bildunterschrift noch leer" : "ohne Bildunterschrift"
    }
}
