import SwiftUI

struct GestaltungView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen
    @State private var titelfotoWahl = false
    @State private var hintergrundOffen = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Buch") {
                    TextField("Titel", text: $werk.reise.titel)
                    TextField("Untertitel", text: $werk.reise.untertitel, axis: .vertical)
                    Toggle("Titelseite", isOn: $werk.reise.titelseite)
                    if werk.reise.titelseite {
                        Button {
                            titelfotoWahl = true
                        } label: {
                            LabeledContent("Titelbild",
                                           value: werk.reise.titelfoto == nil ? "ohne" : "gewählt")
                        }
                    }
                }

                Section {
                    Picker("Seitenformat", selection: $werk.reise.format) {
                        ForEach(Seitenformat.allCases) { format in
                            Text("\(format.name) · \(format.masstext)").tag(format)
                        }
                    }
                    LabeledContent("Bogen mit Anschnitt", value: bogentext)
                } header: {
                    Text("Format")
                } footer: {
                    Text("Das Endformat ist die Seite, wie sie nach dem Schneiden in der Hand liegt. Der Bogen ist das, was im PDF steht — Endformat plus Anschnitt. Beide Maße stehen als TrimBox und BleedBox in der Datei, daran erkennt der Druckdienst, wo geschnitten wird.")
                }

                Section {
                    mmRegler("Anschnitt", $werk.reise.gestaltung.anschnitt, 0...8, schritt: 1)
                    mmRegler("Bundsteg", $werk.reise.gestaltung.bundsteg, 0...15, schritt: 1)
                } header: {
                    Text("Druckzugaben")
                } footer: {
                    Text("Anschnitt: 3 mm sind der Standard, manche Buchdienste verlangen 5 mm. Ohne ihn kann kein Bild bis an die Papierkante laufen.\n\nBundsteg: zusätzlicher Rand zur Heftung. Er wird auf beide Seitenränder gerechnet — welche Seite innen liegt, hängt an der laufenden Seitenzahl, und die verschiebt sich, sobald ein Tag eine Seite mehr braucht.")
                }

                Section {
                    Button {
                        hintergrundOffen = true
                    } label: {
                        LabeledContent("Hintergrund",
                                       value: werk.reise.gestaltung.hintergrund.art.name)
                    }
                    Picker("Datumszeile", selection: $werk.reise.gestaltung.datumsstil) {
                        ForEach(Datumsstil.allCases) { stil in
                            Text(stil.name).tag(stil)
                        }
                    }
                } header: {
                    Text("Aussehen")
                } footer: {
                    Text("Beides gilt für das ganze Buch. Eine einzelne Seite darf einen anderen Hintergrund haben, und ein einzelner Tag eine andere Datumszeile — beides über den Inspektor rechts.")
                }

                Section("Satzspiegel") {
                    mmRegler("Rand außen", $werk.reise.gestaltung.randAussen, 5...45)
                    mmRegler("Rand oben", $werk.reise.gestaltung.randOben, 5...45)
                    mmRegler("Rand unten", $werk.reise.gestaltung.randUnten, 5...45)
                    mmRegler("Fuge zwischen Bildern", $werk.reise.gestaltung.fuge, 0...15,
                             schritt: 0.5)
                    mmRegler("Eckenradius", $werk.reise.gestaltung.eckenradius, 0...10,
                             schritt: 0.5)
                    Toggle("Seitenzahlen", isOn: $werk.reise.gestaltung.seitenzahlen)
                    Toggle("Kopfzeile mit Datum", isOn: $werk.reise.gestaltung.kopfzeile)
                }

                KartenbildWahl(titel: "Kartenbild", bild: $werk.reise.kartenbild)

                Section("Karte im Satz") {
                    ColorPicker("Akzentfarbe", selection: Binding(
                        get: { werk.reise.akzent.farbe },
                        set: { werk.reise.akzent = Farbwert($0) }
                    ))
                    VStack(alignment: .leading) {
                        LabeledContent("Breite der Karte",
                                       value: "\(Int(werk.reise.gestaltung.kartenanteil * 100)) %")
                        Slider(value: $werk.reise.gestaltung.kartenanteil, in: 0.2...0.6)
                    }
                }

                Section {
                    LabeledContent("Tage", value: "\(werk.reise.tage.count)")
                    LabeledContent("Fotos", value: "\(werk.reise.fotos.count)")
                    LabeledContent("Seiten", value: "\(werk.reise.seitenzahl)")
                    LabeledContent("Bilder auf der Platte",
                                   value: String(format: "%.1f MB",
                                                 Bildarchiv.shared.groesseInMB(reise: werk.reise.id)))
                } header: {
                    Text("Bestand")
                }
            }
            .navigationTitle("Gestaltung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        // Ein anderes Format heißt ein anderer Satzspiegel.
                        // Die unberührten Tage werden neu gesetzt; wer von
                        // Hand gearbeitet hat, behält seine Arbeit — auch
                        // wenn sie dann über den neuen Rand ragt. Sie ohne
                        // Rückfrage wegzurechnen wäre der größere Schaden.
                        werk.alleNeuAnordnen(nurUnberuehrte: true)
                        Task { await Kartenwerk.shared.vergessen() }
                        schliessen()
                    }
                }
            }
            .sheet(isPresented: $titelfotoWahl) {
                TitelfotoView(werk: werk)
            }
            .sheet(isPresented: $hintergrundOffen) {
                HintergrundView(werk: werk)
            }
        }
    }

    private var bogentext: String {
        let bogen = werk.reise.gestaltung.bogen(werk.reise.format)
        return "\(Druckmass.mmText(bogen.width)) x \(Druckmass.mmText(bogen.height))"
    }

    private func mmRegler(_ name: String, _ wert: Binding<Double>,
                          _ bereich: ClosedRange<Double>, schritt: Double = 1) -> some View
    {
        VStack(alignment: .leading) {
            LabeledContent(name, value: String(format: schritt < 1 ? "%.1f mm" : "%.0f mm",
                                               wert.wrappedValue)
                .replacingOccurrences(of: ".", with: ","))
            Slider(value: wert, in: bereich, step: schritt)
        }
    }
}

// Das Bild für die Titelseite. Ohne eines ist sie ein ruhiges Textblatt,
// mit einem ein Plakat — beides ist richtig, ein kleines Bildchen über
// einem großen Titel wäre es nicht.
struct TitelfotoView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    private let raster = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: raster, spacing: 8) {
                    ForEach(werk.reise.fotos.filter { !$0.abgelegt }) { foto in
                        Button {
                            werk.merken()
                            werk.reise.titelfoto = werk.reise.titelfoto == foto.id ? nil : foto.id
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                if let bild = Bildarchiv.shared.vorschau(
                                    foto.datei, reise: werk.reise.id, kante: 300)
                                {
                                    Image(uiImage: bild)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 96)
                                        .clipped()
                                } else {
                                    Rectangle().fill(Color(.systemGray5)).frame(height: 96)
                                }
                                if werk.reise.titelfoto == foto.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.white, Color.accentColor)
                                        .padding(5)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Titelbild")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Ohne Bild") {
                        werk.merken()
                        werk.reise.titelfoto = nil
                        schliessen()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
    }
}
