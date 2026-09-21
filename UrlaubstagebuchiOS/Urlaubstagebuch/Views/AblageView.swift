import SwiftUI

// Fotos, die zu keinem Tag gehören.
//
// Sie entstehen bei jedem Import: Bilder ohne Aufnahmedatum, aus einem
// Scanner, aus einer Nachricht weitergeleitet. Sie hier zu zeigen ist keine
// Bequemlichkeit — ohne diese Liste verschwänden sie stillschweigend, und
// niemand käme je wieder an sie heran.
struct AblageView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen
    @State private var gewaehlt: Set<UUID> = []
    @State private var zielTag: UUID?

    private var heimatlose: [Foto] { werk.reise.heimatlose }

    var body: some View {
        NavigationStack {
            Group {
                if heimatlose.isEmpty {
                    ContentUnavailableView {
                        Label("Nichts in der Ablage", systemImage: "tray")
                    } description: {
                        Text("Jedes Foto gehört zu einem Tag.")
                    }
                } else {
                    liste
                }
            }
            .navigationTitle("Fotoablage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
    }

    private var liste: some View {
        List {
            Section {
                Picker("Einem Tag zuordnen", selection: $zielTag) {
                    Text("Tag wählen").tag(UUID?.none)
                    ForEach(werk.reise.tage) { tag in
                        Text(tag.datum.mittel).tag(UUID?.some(tag.id))
                    }
                }
                Button("\(gewaehlt.count) Fotos zuordnen") {
                    guard let ziel = zielTag else { return }
                    for id in gewaehlt { werk.fotoZuTag(id, tag: ziel) }
                    werk.neuAnordnen(ziel, erzwingen: false)
                    gewaehlt = []
                }
                .disabled(zielTag == nil || gewaehlt.isEmpty)
            } footer: {
                Text("Danach stehen die Fotos in der Reihenfolge ihrer Aufnahme am Ende des Tages.")
            }

            Section("\(heimatlose.count) Fotos ohne Tag") {
                ForEach(heimatlose) { foto in
                    HStack {
                        Image(systemName: gewaehlt.contains(foto.id)
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(gewaehlt.contains(foto.id)
                                             ? Color.accentColor : Color.secondary)
                        FotoZeile(werk: werk, foto: foto)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if gewaehlt.contains(foto.id) { gewaehlt.remove(foto.id) }
                        else { gewaehlt.insert(foto.id) }
                    }
                    .swipeActions {
                        Button("Endgültig löschen", role: .destructive) {
                            werk.fotoEntfernen(foto.id)
                        }
                    }
                }
            }
        }
    }
}
