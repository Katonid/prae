import SwiftUI

struct EinstellungenAnsicht: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Fortschritt.self) private var fortschritt

    @AppStorage(Schluessel.genauigkeit) private var genauigkeit = Genauigkeit.normal
    @AppStorage(Schluessel.vorfuehren) private var vorfuehren = true
    @AppStorage(Schluessel.hilfen) private var hilfen = true
    @AppStorage(Schluessel.stift) private var stift = Stift.regenbogen
    @AppStorage(Schluessel.nurStift) private var nurStift = false

    @State private var frageZuruecksetzen = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Genauigkeit", selection: $genauigkeit) {
                        ForEach(Genauigkeit.allCases) { Text($0.titel).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Wie genau muss geschrieben werden?")
                } footer: {
                    Text("Angenommen wird nur, was am roten Pfeil beginnt, in Pfeilrichtung läuft, in der Spur bleibt und erst am Zielkreis abgesetzt wird. „Streng“ verlangt eine ruhigere Hand, „Locker“ passt für die ersten Versuche.")
                }

                Section {
                    Toggle("Erst vorführen, dann schreiben", isOn: $vorfuehren)
                    Toggle("Führungslinie und Zielkreis zeigen", isOn: $hilfen)
                } header: {
                    Text("Hilfen")
                } footer: {
                    Text("Ohne Hilfen bleibt nur der Startpunkt sichtbar — gut, wenn ein Zeichen schon sitzt.")
                }

                Section {
                    Picker("Stiftfarbe", selection: $stift) {
                        ForEach(Stift.allCases) { Text($0.titel).tag($0) }
                    }
                    Toggle("Nur mit Apple Pencil schreiben", isOn: $nurStift)
                } header: {
                    Text("Stift")
                } footer: {
                    Text("Mit Apple Pencil werden Finger und Handballen auf dem Bildschirm übergangen.")
                }

                Section {
                    Button("Alle Sterne zurücksetzen", role: .destructive) { frageZuruecksetzen = true }
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .confirmationDialog("Alle Sterne zurücksetzen?", isPresented: $frageZuruecksetzen,
                                titleVisibility: .visible) {
                Button("Zurücksetzen", role: .destructive) { fortschritt.allesZuruecksetzen() }
            } message: {
                Text("Der Fortschritt aller Zeichen wird gelöscht.")
            }
        }
    }
}
