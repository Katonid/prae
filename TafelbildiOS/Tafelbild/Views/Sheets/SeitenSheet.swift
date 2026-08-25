import SwiftUI

/// Seiten einer Tafel verwalten: umbenennen, sortieren, kopieren, löschen.
///
/// Gewechselt wird unten auf der Tafel; hier geht es um alles, was seltener
/// gebraucht wird und dort nur im Weg wäre.
struct SeitenSheet: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.dismiss) private var dismiss
    let boardID: String

    /// Welche Seite gerade umbenannt wird — nil, wenn keine.
    @State private var umbenennen: String?
    @State private var neuerName: String = ""

    private var board: Board { store.board(boardID) ?? Board() }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(board.seiten) { seite in
                        zeile(seite)
                    }
                    .onMove { quelle, ziel in
                        store.seitenVerschieben(from: quelle, to: ziel, boardID: boardID)
                    }
                } header: {
                    Text("Seiten")
                } footer: {
                    Text("Jede Seite hat eigene Elemente und eine eigene Handschrift. "
                         + "Hintergrund, Farbschema und Namenslisten gelten für die ganze "
                         + "Tafel. Gewechselt wird unten auf der Tafel.")
                }

                Section {
                    Button {
                        store.seiteAnlegen(boardID: boardID)
                        Haptics.tap()
                    } label: {
                        Label("Seite hinzufügen", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Seiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .alert("Seite umbenennen", isPresented: Binding(
                get: { umbenennen != nil },
                set: { if !$0 { umbenennen = nil } }
            )) {
                TextField("Name der Seite", text: $neuerName)
                Button("Sichern") {
                    if let seite = umbenennen {
                        store.seiteUmbenennen(seite, auf: neuerName, boardID: boardID)
                    }
                    umbenennen = nil
                }
                Button("Abbrechen", role: .cancel) { umbenennen = nil }
            } message: {
                Text("Ohne Namen heißt sie nach ihrer Reihenfolge — „Seite 1“, „Seite 2“ …")
            }
        }
    }

    private func zeile(_ seite: BoardPage) -> some View {
        let anzahl = board.widgets(auf: seite.id).count
        let aktiv = seite.id == store.aktiveSeitenID
            || (store.aktiveSeitenID.isEmpty && seite.id == board.ersteSeitenID)
        return HStack(spacing: 12) {
            Image(systemName: aktiv ? "doc.fill" : "doc")
                .foregroundStyle(aktiv ? Theme.accent : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(board.seitenName(seite.id))
                    .font(.system(size: 16, weight: aktiv ? .semibold : .regular))
                Text(anzahl == 1 ? "1 Element" : "\(anzahl) Elemente")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            // Sichtbarer Knopf statt nur einer Wischgeste: Umbenennen ist
            // das, wofür diese Ansicht am häufigsten geöffnet wird.
            Button {
                neuerName = seite.name
                umbenennen = seite.id
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            store.zeigeSeite(seite.id)
            dismiss()
        }
        .swipeActions(edge: .trailing) {
            // Die letzte Seite bleibt stehen — eine Tafel ohne Seite gibt es nicht.
            if board.seiten.count > 1 {
                Button(role: .destructive) {
                    store.seiteLoeschen(seite.id, boardID: boardID)
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
            Button {
                neuerName = seite.name
                umbenennen = seite.id
            } label: {
                Label("Umbenennen", systemImage: "pencil")
            }
            .tint(Theme.accent)
        }
        .swipeActions(edge: .leading) {
            Button {
                store.seiteDuplizieren(seite.id, boardID: boardID)
            } label: {
                Label("Kopieren", systemImage: "plus.square.on.square")
            }
            .tint(Theme.mint)
        }
    }
}
