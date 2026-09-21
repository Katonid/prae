import SwiftUI

struct GestaltungView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            Form {
                Section("Buch") {
                    TextField("Titel", text: $werk.reise.titel)
                    TextField("Untertitel", text: $werk.reise.untertitel, axis: .vertical)
                    Toggle("Titelseite", isOn: $werk.reise.titelseite)
                }

                Section {
                    Picker("Seitenformat", selection: $werk.reise.format) {
                        ForEach(Seitenformat.allCases) { format in
                            Text(format.name).tag(format)
                        }
                    }
                    LabeledContent("Seitengröße", value:
                        "\(Int(werk.reise.format.groesse.width)) × \(Int(werk.reise.format.groesse.height)) pt")
                } header: {
                    Text("Format")
                } footer: {
                    Text("Die Maße sind PostScript-Punkte — dieselbe Einheit, in der eine PDF-Seite gemessen wird. Was du auf dem Bildschirm siehst, ist deshalb genau die gedruckte Seite.")
                }

                Section("Satzspiegel") {
                    regler("Rand außen", $werk.reise.gestaltung.randAussen, 12...120)
                    regler("Rand oben", $werk.reise.gestaltung.randOben, 12...120)
                    regler("Rand unten", $werk.reise.gestaltung.randUnten, 12...120)
                    regler("Fuge zwischen Bildern", $werk.reise.gestaltung.fuge, 0...40)
                    regler("Eckenradius", $werk.reise.gestaltung.eckenradius, 0...24)
                    ColorPicker("Papierfarbe", selection: Binding(
                        get: { werk.reise.gestaltung.papier.farbe },
                        set: { werk.reise.gestaltung.papier = Farbwert($0) }
                    ))
                }

                Section("Karte") {
                    Picker("Kartenbild", selection: $werk.reise.kartenstil) {
                        ForEach(Kartenstil.allCases) { stil in Text(stil.name).tag(stil) }
                    }
                    ColorPicker("Farbe der Reisespur", selection: Binding(
                        get: { werk.reise.linienfarbe.farbe },
                        set: { werk.reise.linienfarbe = Farbwert($0) }
                    ))
                    VStack(alignment: .leading) {
                        LabeledContent("Breite der Karte im Satz",
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
        }
    }

    private func regler(_ name: String, _ wert: Binding<Double>,
                        _ bereich: ClosedRange<Double>) -> some View
    {
        VStack(alignment: .leading) {
            LabeledContent(name, value: String(format: "%.0f pt", wert.wrappedValue))
            Slider(value: wert, in: bereich)
        }
    }
}
