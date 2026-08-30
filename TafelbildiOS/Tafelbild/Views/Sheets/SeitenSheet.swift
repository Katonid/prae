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
    /// Welche Seite gerade auf eine andere Tafel gelegt wird.
    @State private var uebertragen: String?

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
                         + "Tafel. Gewechselt wird unten auf der Tafel.\n\n"
                         + "Die Pfeile ändern die Reihenfolge, der Stift benennt um. "
                         + "Langes Drücken bietet an, die Seite auf eine andere Tafel "
                         + "zu legen.")
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
            .navigationDestination(item: $uebertragen) { seite in
                UebertragenSheet(quelle: boardID, gut: .seite(seite))
            }
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
        let stelle = board.seiten.firstIndex { $0.id == seite.id } ?? 0
        let letzte = board.seiten.count - 1
        return HStack(spacing: 12) {
            Image(systemName: aktiv ? "doc.fill" : "doc")
                .foregroundStyle(aktiv ? Theme.accent : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(board.seitenName(seite.id))
                    .font(.system(size: 16, weight: aktiv ? .semibold : .regular))
                    .foregroundStyle(seite.versteckt ? .secondary : .primary)
                HStack(spacing: 6) {
                    Text(anzahl == 1 ? "1 Element" : "\(anzahl) Elemente")
                    if seite.versteckt {
                        Label("Ausgeblendet", systemImage: "eye.slash.fill")
                            .foregroundStyle(Color(hex: "#f59e0b"))
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            // Sichtbare Knöpfe statt nur Wischgesten und „Bearbeiten“:
            // Umbenennen und Umsortieren sind das, wofür diese Ansicht am
            // häufigsten geöffnet wird.
            zeilenKnopf("chevron.up", aus: stelle == 0, label: "Nach oben") {
                store.seitenVerschieben(from: IndexSet(integer: stelle),
                                        to: stelle - 1, boardID: boardID)
            }
            zeilenKnopf("chevron.down", aus: stelle == letzte, label: "Nach unten") {
                store.seitenVerschieben(from: IndexSet(integer: stelle),
                                        to: stelle + 2, boardID: boardID)
            }
            zeilenKnopf(seite.versteckt ? "eye.slash.fill" : "eye",
                        aus: false,
                        label: seite.versteckt ? "Wieder zeigen"
                                               : "Nur für mich ausblenden") {
                store.seiteVerstecken(seite.id, boardID: boardID,
                                      versteckt: !seite.versteckt)
            }
            zeilenKnopf("pencil", aus: false, label: "Umbenennen") {
                neuerName = seite.name
                umbenennen = seite.id
            }
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
        .contextMenu {
            Button {
                uebertragen = seite.id
            } label: {
                Label("Auf eine andere Tafel …", systemImage: "arrow.right.square")
            }
            Button {
                store.seiteDuplizieren(seite.id, boardID: boardID)
            } label: {
                Label("Seite kopieren", systemImage: "plus.square.on.square")
            }
            Button {
                neuerName = seite.name
                umbenennen = seite.id
            } label: {
                Label("Umbenennen", systemImage: "pencil")
            }
            Button {
                store.seiteVerstecken(seite.id, boardID: boardID,
                                      versteckt: !seite.versteckt)
            } label: {
                Label(seite.versteckt ? "Wieder zeigen" : "Nur für mich ausblenden",
                      systemImage: seite.versteckt ? "eye" : "eye.slash")
            }
        }
    }

    private func zeilenKnopf(_ symbol: String, aus: Bool, label: String,
                             aktion: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            aktion()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 32, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(aus)
        .opacity(aus ? 0.3 : 1)
        .accessibilityLabel(label)
    }
}
