import SwiftUI
import CoreData

/// Texte zu den Fotos eines Eintrags schreiben (ab 1.0.17, Ansage des Nutzers
/// 09/2026: „Texte zu den Fotos erstellen"). Jedes Foto mit einem Feld
/// darunter; im Fotobuch wird der Text zur Bildunterschrift.
struct BildtexteView: View {
    @ObservedObject var eintrag: Eintrag
    /// Mit diesem Foto beginnen (Tipp auf „Text zum Foto" unter einem Bild).
    var start: NSManagedObjectID?

    @Environment(\.dismiss) private var schliessen
    @State private var texte: [NSManagedObjectID: String] = [:]
    @FocusState private var fokus: NSManagedObjectID?

    var body: some View {
        NavigationStack {
            ScrollViewReader { leser in
                List {
                    ForEach(eintrag.fotoListe) { foto in
                        VStack(alignment: .leading, spacing: 10) {
                            FotoBild(foto: foto, kante: 900)
                                .aspectRatio(foto.seitenverhaeltnis, contentMode: .fit)
                                .frame(maxHeight: 320)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            TextField("Text zu diesem Foto", text: binding(foto), axis: .vertical)
                                .focused($fokus, equals: foto.objectID)
                                .lineLimit(1...8)
                            if let d = foto.aufnahme {
                                Text(Tag.text(d, "d. MMMM yyyy, HH:mm", zone: eintrag.zone))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                        .id(foto.objectID)
                    }
                }
                .onAppear {
                    for f in eintrag.fotoListe { texte[f.objectID] = f.bildtext ?? "" }
                    if let start {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            leser.scrollTo(start, anchor: .top)
                            fokus = start
                        }
                    }
                }
            }
            .navigationTitle("Texte zu den Fotos")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { sichern() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func binding(_ foto: Foto) -> Binding<String> {
        Binding(get: { texte[foto.objectID] ?? "" }, set: { texte[foto.objectID] = $0 })
    }

    private func sichern() {
        var geaendert = false
        for f in eintrag.fotoListe {
            let neu = (texte[f.objectID] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if neu != (f.bildtext ?? "") {
                f.bildtext = neu
                geaendert = true
            }
        }
        if geaendert {
            eintrag.geaendert = Date()
            Persistenz.shared.sichern()
        }
        schliessen()
    }
}
