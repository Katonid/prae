import SwiftUI

// Der INHALT eines Tages — Text, Überschrift, Fotos. Getrennt vom Satz:
// Was hier steht, gehört dem Nutzer; wie es auf der Seite liegt, ist ein
// Vorschlag der App.
struct TagInhaltView: View {
    @ObservedObject var werk: Reisewerk
    let tagID: UUID
    @Environment(\.dismiss) private var schliessen
    @State private var aufraeumBefund: String?

    private var stelle: Int? { werk.tagIndex(tagID) }

    var body: some View {
        NavigationStack {
            if let stelle {
                Form {
                    Section {
                        TextField("z. B. Ankunft in Lissabon",
                                  text: binden(stelle, \.ueberschrift))
                        TextField(werk.reise.gestaltung.datumsstil
                            .text(werk.reise.tage[stelle].datum,
                                  nummer: stelle + 1),
                                  text: Binding(
                            get: { werk.reise.tage[stelle].datumstext ?? "" },
                            set: { werk.reise.tage[stelle].datumstext = $0.isEmpty ? nil : $0 }
                        ))
                        Toggle("Diesen Tag ausblenden", isOn: binden(stelle, \.ausgeblendet))
                    } header: {
                        Text("Überschrift und Datumszeile")
                    } footer: {
                        Text("Bleibt die Datumszeile leer, gilt das Format des Buches. Ein ausgeblendeter Tag bleibt vollständig erhalten, kommt aber nicht ins Buch.")
                    }
                    Section {
                        TextEditor(text: binden(stelle, \.text))
                            .frame(minHeight: 220)
                            .font(.system(size: 14))
                        Button {
                            let befund = werk.absaetzeAufraeumen(tagID)
                            aufraeumBefund = befund?.beschreibung
                        } label: {
                            Label("Absätze aufräumen", systemImage: "text.alignleft")
                        }
                        if let aufraeumBefund {
                            Text(aufraeumBefund)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Tagebuchtext")
                    } footer: {
                        Text("\(werk.reise.tage[stelle].text.count) Zeichen. „Absätze aufräumen“ führt hart umbrochene Zeilen wieder zusammen — daran, dass viele Zeilen an derselben Grenze enden, erkennt die App den Umbruch. Frei geschriebener Text bleibt unangetastet.")
                    }

                    Section {
                        Toggle("Karte auf der Seite zeigen", isOn: binden(stelle, \.karteZeigen))
                        Picker("Seitenmuster", selection: Binding(
                            get: { werk.reise.tage[stelle].muster },
                            set: { neu in
                                werk.merken()
                                werk.reise.tage[stelle].muster = neu
                                werk.reise.tage[stelle].seiten =
                                    werk.automat.seiten(fuer: werk.reise.tage[stelle])
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
                .navigationTitle(werk.reise.tage[stelle].datum.mittel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") {
                            werk.neuAnordnen(tagID, erzwingen: false)
                            schliessen()
                        }
                    }
                }
            } else {
                Text("Diesen Tag gibt es nicht mehr.")
            }
        }
    }

    @ViewBuilder
    private func fotoAbschnitt(_ stelle: Int) -> some View {
        let tag = werk.reise.tage[stelle]
        Section {
            if tag.fotos.isEmpty {
                Text("Noch keine Fotos an diesem Tag.")
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
            Text("Die Reihenfolge hier ist die Reihenfolge auf der Seite. Ein Wisch nimmt das Foto vom Tag — es bleibt in der Ablage.")
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
            if let bild = Bildarchiv.shared.vorschau(foto.datei, reise: werk.reise.id, kante: 160) {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 52, height: 52)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(foto.unterschrift.isEmpty ? "ohne Bildunterschrift" : foto.unterschrift)
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
        }
    }
}
