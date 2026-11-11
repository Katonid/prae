import SwiftUI

struct BuecherView: View {
    @EnvironmentObject private var bibliothek: Bibliothek
    @State private var pfad: [UUID] = []
    @State private var zuLoeschen: Buch?

    var body: some View {
        NavigationStack(path: $pfad) {
            List {
                if let fehler = bibliothek.ladefehler {
                    Section {
                        Label(fehler, systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
                ForEach(bibliothek.buecher) { buch in
                    NavigationLink(value: buch.id) {
                        BuchZeile(buch: buch)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            zuLoeschen = buch
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
            .overlay {
                if bibliothek.buecher.isEmpty {
                    ContentUnavailableView {
                        Label("Noch kein Buch", systemImage: "books.vertical")
                    } description: {
                        Text("Ein Buch sammelt Texte und Fotos. Die Kapitel entstehen von selbst aus ihren Zeitstempeln — zunächst eines je Kalenderjahr.")
                    } actions: {
                        Button("Neues Buch anlegen") { neu() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Chronik")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        neu()
                    } label: {
                        Label("Neues Buch", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                BuchView(buchID: id)
            }
            .confirmationDialog("Buch löschen?",
                                isPresented: Binding(get: { zuLoeschen != nil },
                                                     set: { if !$0 { zuLoeschen = nil } }),
                                titleVisibility: .visible,
                                presenting: zuLoeschen) { buch in
                Button("„\(buch.titel)“ löschen", role: .destructive) {
                    bibliothek.loeschen(buch.id)
                }
            } message: { buch in
                Text("Alle \(buch.texte.count) Texte, \(buch.fotos.count) Fotos und \(buch.freieSeiten.count) freien Seiten dieses Buches werden gelöscht. Die Fotos in der Mediathek bleiben.")
            }
        }
    }

    private func neu() {
        let id = bibliothek.neuesBuch()
        pfad.append(id)
    }
}

private struct BuchZeile: View {
    let buch: Buch

    var body: some View {
        HStack(spacing: 12) {
            if let foto = Seitenbau.titelbild(buch) ?? buch.fotos.first {
                Vorschaubild(datei: foto.datei, kante: 52)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.18))
                    .frame(width: 52, height: 52)
                    .overlay(Image(systemName: "book.closed").foregroundStyle(Color.accentColor))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(buch.titel.isEmpty ? "Ohne Titel" : buch.titel)
                    .font(.headline)
                Text("\(buch.texte.count) Texte · \(buch.fotos.count) Fotos · \(buch.raster.beschreibung)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
