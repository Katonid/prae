import SwiftUI

// Der Hintergrund — für das ganze Buch oder für eine einzelne Seite.
//
// Beides führt auf dieselbe Ansicht, weil es dieselbe Entscheidung ist. Der
// Unterschied steht in der Fußzeile: was hier gilt und was es überschreibt.
// Zwei getrennte Bildschirme für dieselbe Sache liefen unweigerlich
// auseinander.
struct HintergrundView: View {
    @ObservedObject var werk: Reisewerk
    // Leer heißt: Es geht um das ganze Buch.
    var seite: (tag: UUID, stelle: Int)?
    @Environment(\.dismiss) private var schliessen
    @State private var fotowahl = false

    private var istBuch: Bool { seite == nil }

    private var grund: Seitenhintergrund {
        if let seite, let t = werk.tagIndex(seite.tag),
           werk.reise.tage[t].seiten.indices.contains(seite.stelle),
           let eigener = werk.reise.tage[t].seiten[seite.stelle].hintergrund
        {
            return eigener
        }
        return werk.reise.gestaltung.hintergrund
    }

    private var eigenerGesetzt: Bool {
        guard let seite, let t = werk.tagIndex(seite.tag),
              werk.reise.tage[t].seiten.indices.contains(seite.stelle) else { return false }
        return werk.reise.tage[t].seiten[seite.stelle].hintergrund != nil
    }

    private var aenderbar: Bool { istBuch || eigenerGesetzt }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    probe
                        .frame(height: 140)
                        .listRowInsets(EdgeInsets())
                }

                if !istBuch {
                    Section {
                        Toggle("Eigener Hintergrund für diese Seite", isOn: Binding(
                            get: { eigenerGesetzt },
                            set: { an in setzen(an ? werk.reise.gestaltung.hintergrund : nil) }
                        ))
                    } footer: {
                        Text(eigenerGesetzt
                             ? "Diese Seite weicht vom Buch ab. Ausschalten stellt den Hintergrund des Buches wieder her."
                             : "Diese Seite folgt dem Hintergrund des Buches.")
                    }
                }

                if aenderbar {
                    Section("Art") {
                        Picker("Hintergrund", selection: binden(\.art)) {
                            ForEach(Seitenhintergrund.Art.allCases) { art in
                                Text(art.name).tag(art)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("Farbe") {
                        ColorPicker("Grundfarbe", selection: Binding(
                            get: { grund.farbe.farbe },
                            set: { neu in aendern { $0.farbe = Farbwert(neu) } }
                        ))
                        if grund.art == .verlauf {
                            ColorPicker("Zweite Farbe", selection: Binding(
                                get: { grund.zweitfarbe.farbe },
                                set: { neu in aendern { $0.zweitfarbe = Farbwert(neu) } }
                            ))
                            VStack(alignment: .leading) {
                                LabeledContent("Richtung",
                                               value: "\(Int(grund.winkel))°")
                                Slider(value: binden(\.winkel), in: 0...360, step: 15)
                            }
                        }
                        if grund.dunkel {
                            Label("Dunkler Grund — helle Schrift wählen, sonst verschwindet der Text.",
                                  systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    if grund.art == .papierstruktur {
                        Section("Struktur") {
                            VStack(alignment: .leading) {
                                LabeledContent("Körnung",
                                               value: String(format: "%.0f %%", grund.koernung * 100))
                                Slider(value: binden(\.koernung), in: 0...0.25)
                            }
                            Text("Ein feines Korn nimmt einer Farbfläche das Bildschirmhafte. Im Druck wirkt es schwächer als auf dem Schirm.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if grund.art == .foto {
                        Section("Bild") {
                            Button {
                                fotowahl = true
                            } label: {
                                LabeledContent("Foto",
                                               value: grund.fotoID == nil ? "keines gewählt" : "gewählt")
                            }
                            VStack(alignment: .leading) {
                                LabeledContent("Schleier",
                                               value: String(format: "%.0f %%", grund.schleier * 100))
                                Slider(value: binden(\.schleier), in: 0...0.95)
                            }
                            Text("Ohne Schleier steht der Text auf dem Bild und ist nicht zu lesen. Ein Hintergrundfoto ist nicht das, worauf man schauen soll.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(istBuch ? "Hintergrund des Buches" : "Hintergrund der Seite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
            .sheet(isPresented: $fotowahl) {
                HintergrundfotoView(werk: werk) { id in
                    aendern { $0.fotoID = id }
                }
            }
        }
    }

    private var probe: some View {
        ZStack(alignment: .topLeading) {
            HintergrundFlaeche(werk: werk, hintergrund: grund, seite: Seite())
            VStack(alignment: .leading, spacing: 6) {
                Text(werk.reise.gestaltung.datumsstil
                    .text(Tagesdatum(Date()), nummer: 3).uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(werk.reise.akzent.farbe)
                Text("Über den Pass")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(grund.dunkel ? Color.white : Color.primary)
                Text("So sieht die Seite mit diesem Hintergrund aus.")
                    .font(.system(size: 10))
                    .foregroundStyle(grund.dunkel ? Color.white.opacity(0.85) : Color.secondary)
            }
            .padding(16)
        }
    }

    private func binden<W>(_ pfad: WritableKeyPath<Seitenhintergrund, W>) -> Binding<W> {
        Binding(
            get: { grund[keyPath: pfad] },
            set: { neu in aendern { $0[keyPath: pfad] = neu } }
        )
    }

    private func aendern(_ arbeit: (inout Seitenhintergrund) -> Void) {
        var neu = grund
        arbeit(&neu)
        setzen(neu)
    }

    private func setzen(_ neu: Seitenhintergrund?) {
        if let seite, let t = werk.tagIndex(seite.tag),
           werk.reise.tage[t].seiten.indices.contains(seite.stelle)
        {
            werk.reise.tage[t].seiten[seite.stelle].hintergrund = neu
            // Die alte Einzelfarbe je Seite geht im Hintergrund auf. Beides
            // nebeneinander zu führen hieße, zwei Wahrheiten über dieselbe
            // Fläche zu haben.
            werk.reise.tage[t].seiten[seite.stelle].papier = nil
        } else if let neu {
            werk.reise.gestaltung.hintergrund = neu
            werk.reise.gestaltung.papier = neu.farbe
        }
    }
}

struct HintergrundfotoView: View {
    @ObservedObject var werk: Reisewerk
    var gewaehlt: (UUID?) -> Void
    @Environment(\.dismiss) private var schliessen

    private let raster = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: raster, spacing: 8) {
                    ForEach(werk.reise.fotos.filter { !$0.abgelegt }) { foto in
                        Button {
                            gewaehlt(foto.id)
                            schliessen()
                        } label: {
                            if let bild = Bildarchiv.shared.vorschau(foto.datei,
                                                                     reise: werk.reise.id,
                                                                     kante: 300)
                            {
                                Image(uiImage: bild)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 100)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                            } else {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 100)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Hintergrundbild")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Ohne Bild") {
                        gewaehlt(nil)
                        schliessen()
                    }
                }
            }
        }
    }
}
