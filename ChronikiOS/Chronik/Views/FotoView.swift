import SwiftUI

struct FotoView: View {
    @Binding var buch: Buch
    let id: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var bild: UIImage?
    @State private var loeschenFragen = false

    var body: some View {
        let foto = Bindungen.foto($buch, id)
        NavigationStack {
            Form {
                Section {
                    ZStack {
                        if let bild {
                            Image(uiImage: bild).resizable().scaledToFit()
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    DatePicker("Aufgenommen", selection: foto.zeit, displayedComponents: [.date, .hourAndMinute])
                    TextField("Bildunterschrift (freiwillig)", text: foto.unterschrift, axis: .vertical)
                } footer: {
                    Text("Kapitel: „\(kapitelname(foto.wrappedValue.zeit))“. Ein anderes Datum verschiebt das Foto in ein anderes Kapitel.")
                }

                Section {
                    Toggle("Titelbild des Buches", isOn: Binding(
                        get: { buch.titelfoto == id },
                        set: { buch.titelfoto = $0 ? id : nil }
                    ))
                }

                Section {
                    Button("Foto aus dem Buch entfernen", role: .destructive) { loeschenFragen = true }
                } footer: {
                    Text("Das Original in der Mediathek bleibt.")
                }
            }
            .navigationTitle("Foto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .task {
                let d = foto.wrappedValue.datei
                bild = await Task.detached(priority: .userInitiated) { Medien.bild(d, maxPixel: 1600) }.value
            }
            .confirmationDialog("Foto entfernen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
                Button("Entfernen", role: .destructive) {
                    buch.fotos.removeAll { $0.id == id }
                    if buch.titelfoto == id { buch.titelfoto = nil }
                    dismiss()
                }
            }
        }
    }

    private func kapitelname(_ zeit: Date) -> String {
        buch.kapitelTitel(buch.raster.kapitel(buch.raster.index(fuer: zeit)))
    }
}
