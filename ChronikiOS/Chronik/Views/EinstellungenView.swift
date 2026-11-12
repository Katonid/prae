import SwiftUI

struct EinstellungenView: View {
    @Binding var buch: Buch
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Buch") {
                    TextField("Titel", text: $buch.titel)
                    TextField("Untertitel (freiwillig)", text: $buch.untertitel)
                }

                Section {
                    Picker("Ein Kapitel je", selection: Binding(
                        get: { buch.raster.vorgabe },
                        set: { buch.raster.anwenden($0) }
                    )) {
                        ForEach(Zeitraster.Vorgabe.allCases) { Text($0.name).tag($0) }
                    }
                    if buch.raster.vorgabe == .eigene {
                        Stepper("Länge: \(buch.raster.anzahl) \(buch.raster.einheit.name(buch.raster.anzahl))",
                                value: $buch.raster.anzahl, in: 1...100)
                        Picker("Einheit", selection: $buch.raster.einheit) {
                            ForEach(Zeitraster.Einheit.allCases) { Text($0.name(2)).tag($0) }
                        }
                        DatePicker("Ein Kapitel beginnt am", selection: $buch.raster.beginn, displayedComponents: .date)
                    }
                    Toggle("Auch leere Zeitabschnitte als Kapitel", isOn: $buch.leereKapitelZeigen)
                } header: {
                    Text("Kapitel")
                } footer: {
                    Text(rasterHinweis)
                }

                Section {
                    Picker("Stil", selection: $buch.stil) {
                        ForEach(Buchstil.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Gestaltung")
                } footer: {
                    Text(buch.stil.beschreibung)
                }

                Section {
                    Picker("Format", selection: $buch.format) {
                        ForEach(Seitenformat.allCases) { Text($0.name).tag($0) }
                    }
                    Stepper("Höchstens \(buch.fotosJeSeite) \(buch.fotosJeSeite == 1 ? "Foto" : "Fotos") je Seite",
                            value: $buch.fotosJeSeite, in: 1...6)
                } header: {
                    Text("Seiten")
                } footer: {
                    Text("Ein Text nimmt die unmittelbar folgenden Fotos auf seine erste Seite (bis zu drei, klassisch zwei). Weitere Fotos füllen eigene Seiten, Tag für Tag, im Wechsel aus vollen Seiten und einzelnen großen Bildern. Jedes Kapitel öffnet mit seinem ersten Querformat. Das Titelbild wählt man beim Foto selbst.")
                }
            }
            .navigationTitle("Buch einrichten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private var rasterHinweis: String {
        var satz = buch.raster.vorgabe == .eigene
            ? "Das Raster beginnt am gewählten Tag und läuft von dort in gleichen Schritten vor und zurück."
            : "Die Kapitel entstehen aus den Zeitstempeln der Texte und Fotos."
        let g = Seitenbau.gruppen(buch)
        if !g.isEmpty {
            let namen = g.prefix(5).map(\.titel).joined(separator: " · ")
            satz += "\n\nErgibt \(g.count) Kapitel: \(namen)" + (g.count > 5 ? " …" : "")
        }
        return satz
    }
}
