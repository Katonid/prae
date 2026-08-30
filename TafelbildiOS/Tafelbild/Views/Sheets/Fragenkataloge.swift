import SwiftUI

/// Die Fragenkataloge einer Tafel: welcher gilt, und was darin steht.
///
/// **Warum mehrere.** Der mitgelieferte Katalog ist für eine vierte Klasse
/// gemacht. „Was kannst du heute besser als vor einem Jahr?" geht in der
/// ersten Klasse ins Leere, und „Was ist deine Lieblingsfarbe?" ist in der
/// vierten keine Frage mehr. Vier Vorlagen nach Klassenstufe liegen bei —
/// als Vorlagen, nicht als Vorschrift: Sie werden beim ersten Öffnen in die
/// Tafel kopiert und lassen sich dort ändern, erweitern und löschen.
struct FragenkatalogeSeite: View {
    @EnvironmentObject private var store: BoardStore
    let boardID: String

    private var board: Board? { store.board(boardID) }

    var body: some View {
        List {
            if let board {
                Section {
                    ForEach(board.fragenkataloge) { katalog in
                        NavigationLink {
                            FragenkatalogEditor(boardID: boardID, katalogID: katalog.id)
                        } label: {
                            HStack {
                                Image(systemName: gewaehlt(board) == katalog.id
                                      ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(gewaehlt(board) == katalog.id
                                                     ? Color.accentColor : .secondary)
                                    .onTapGesture { waehle(katalog.id) }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(katalog.name.nonEmpty ?? "Ohne Namen")
                                    Text("\(katalog.fragen.count) Fragen")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { stellen in
                        aendere { $0.fragenkataloge.remove(atOffsets: stellen) }
                    }

                    Button {
                        aendere {
                            $0.fragenkataloge.append(Fragenkatalog(name: "Neuer Katalog"))
                        }
                    } label: {
                        Label("Katalog hinzufügen", systemImage: "plus")
                    }
                } header: {
                    Text("Kataloge")
                } footer: {
                    Text("Der Punkt links wählt aus, welcher Katalog beim "
                         + "Geburtstagsritual gezogen wird. Antippen des Namens "
                         + "öffnet die Fragen.")
                }

                Section {
                    Button {
                        aendere { $0.fragenkataloge += Geburtstagsfragen.vorlagen() }
                    } label: {
                        Label("Vorlagen noch einmal einfügen", systemImage: "tray.and.arrow.down")
                    }
                } footer: {
                    Text("Legt die vier mitgelieferten Kataloge (1. bis 4. Klasse) "
                         + "zusätzlich an. Vorhandene bleiben unangetastet.")
                }
            }
        }
        .navigationTitle("Fragenkataloge")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .onAppear {
            // Beim ersten Öffnen die Vorlagen hineinkopieren. Erst hier und
            // nicht beim Anlegen der Tafel: Wer das Ritual nie benutzt,
            // soll auch keine hundertvierzig Fragen mit sich herumtragen.
            guard let board, board.fragenkataloge.isEmpty else { return }
            aendere { tafel in
                tafel.fragenkataloge = Geburtstagsfragen.vorlagen()
                tafel.fragenkatalog = tafel.fragenkataloge.last?.id ?? ""
            }
        }
    }

    private func gewaehlt(_ board: Board) -> String {
        board.fragenkataloge.contains { $0.id == board.fragenkatalog }
            ? board.fragenkatalog
            : (board.fragenkataloge.first?.id ?? "")
    }

    private func waehle(_ id: String) {
        aendere { $0.fragenkatalog = id }
        Haptics.tap()
    }

    private func aendere(_ arbeit: (inout Board) -> Void) {
        guard var kopie = board else { return }
        arbeit(&kopie)
        store.updateBoard(kopie)
    }
}

/// Die Fragen eines Katalogs — anlegen, ändern, löschen, umsortieren.
struct FragenkatalogEditor: View {
    @EnvironmentObject private var store: BoardStore
    let boardID: String
    let katalogID: String

    private var board: Board? { store.board(boardID) }
    private var katalog: Fragenkatalog? {
        board?.fragenkataloge.first { $0.id == katalogID }
    }

    var body: some View {
        List {
            if let katalog {
                Section {
                    TextField("Name des Katalogs", text: Binding(
                        get: { katalog.name },
                        set: { neu in aendere { $0.name = neu } }
                    ))
                }

                Section {
                    ForEach(Array(katalog.fragen.enumerated()), id: \.offset) { stelle, frage in
                        // Mehrzeilig: Manche Fragen sind lang, und wer sie
                        // ändern will, muss sie ganz sehen.
                        TextField("Frage", text: Binding(
                            get: { frage },
                            set: { neu in
                                aendere { katalog in
                                    guard stelle < katalog.fragen.count else { return }
                                    katalog.fragen[stelle] = neu
                                }
                            }
                        ), axis: .vertical)
                        .lineLimit(1...4)
                    }
                    .onDelete { stellen in
                        aendere { $0.fragen.remove(atOffsets: stellen) }
                    }
                    .onMove { quelle, ziel in
                        aendere { $0.fragen.move(fromOffsets: quelle, toOffset: ziel) }
                    }

                    Button {
                        aendere { $0.fragen.append("") }
                    } label: {
                        Label("Frage hinzufügen", systemImage: "plus")
                    }
                } header: {
                    Text("\(katalog.fragen.count) Fragen")
                } footer: {
                    Text("Gezogen werden zwei davon, zufällig. Leere Fragen "
                         + "werden übersprungen.")
                }
            } else {
                Text("Den Katalog gibt es nicht mehr.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(katalog?.name.nonEmpty ?? "Katalog")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
    }

    private func aendere(_ arbeit: (inout Fragenkatalog) -> Void) {
        guard var kopie = board,
              let stelle = kopie.fragenkataloge.firstIndex(where: { $0.id == katalogID })
        else { return }
        arbeit(&kopie.fragenkataloge[stelle])
        store.updateBoard(kopie)
    }
}
