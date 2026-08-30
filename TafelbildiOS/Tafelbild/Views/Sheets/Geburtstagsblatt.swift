import SwiftUI

/// Alles zu den Geburtstagen einer Tafel — als eigenes Blatt.
///
/// **Warum ein eigenes.** Bis 1.3.14 hing dieser Abschnitt hinten an
/// „Tafel teilen". Historisch gewachsen: Die Geburtstage kamen zusammen
/// mit dem Löschrecht, und das gehört tatsächlich neben die Einladung.
/// Die Geburtstage nicht — wer den Fragenkatalog sucht, sucht ihn nicht
/// unter „Teilen" (gemeldet 08/2026: „Das Einzige, was ich nicht finde,
/// ist, wo ich die Fragenkataloge auswählen kann.").
///
/// Ein Menüpunkt heißt jetzt „Geburtstage", und darunter steht, was zu
/// Geburtstagen gehört. Eine Funktion, die man nicht findet, gibt es
/// nicht.
///
/// Die Einstellung gehört zur **Tafel**, nicht zur Namensliste: Eine
/// Liste kann auf mehreren Tafeln liegen; wäre sie dort, tauchten die
/// Seiten überall auf. Die gewählte Liste reist beim Teilen mit (siehe
/// `Board.referencedListIDs`).
struct GeburtstagsSheet: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.dismiss) private var dismiss
    let boardID: String

    private var board: Board? { store.board(boardID) }

    var body: some View {
        NavigationStack {
            Form {
                if let board {
                    geburtstagsAbschnitt(board)
                } else {
                    Text("Diese Tafel gibt es nicht mehr.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Geburtstage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func geburtstagsAbschnitt(_ board: Board) -> some View {
        let regel = Geburtstagserinnerung.aus(board.geburtstagsErinnerung)
        Section {
            Toggle("Geburtstage feiern", isOn: Binding(
                get: { board.geburtstage },
                set: { an in
                    var neu = board
                    neu.geburtstage = an
                    if an, neu.geburtstagsliste.isEmpty,
                       let vorschlag = neu.geburtstagslisteID(vorhanden: store.visibleNameLists) {
                        neu.geburtstagsliste = vorschlag
                    }
                    store.updateBoard(neu)
                    store.pruefeGeburtstage()
                }
            ))

            if board.geburtstage {
                Picker("Namensliste", selection: Binding(
                    get: { board.geburtstagslisteID(vorhanden: store.visibleNameLists) ?? "" },
                    set: { neueListe in
                        var neu = board
                        neu.geburtstagsliste = neueListe
                        store.updateBoard(neu)
                        store.pruefeGeburtstage()
                    }
                )) {
                    Text("Keine").tag("")
                    ForEach(store.visibleNameLists) { liste in
                        Text(liste.name).tag(liste.id)
                    }
                }

                Picker("Erinnern", selection: Binding(
                    get: { regel },
                    set: { neueRegel in
                        var neu = board
                        neu.geburtstagsErinnerung = neueRegel.rawValue
                        store.updateBoard(neu)
                        store.planeGeburtstagsmeldungen()
                    }
                )) {
                    ForEach(Geburtstagserinnerung.allCases) { moeglichkeit in
                        Text(moeglichkeit.titel).tag(moeglichkeit)
                    }
                }

                NavigationLink {
                    FragenkatalogeSeite(boardID: board.id)
                } label: {
                    LabeledContent {
                        Text(board.fragenkataloge.first { $0.id == board.fragenkatalog }?
                            .name.nonEmpty
                            ?? board.fragenkataloge.first?.name.nonEmpty
                            ?? "4. Klasse")
                    } label: {
                        Label("Fragenkatalog", systemImage: "text.book.closed")
                    }
                }

                NavigationLink {
                    NachfeiernSheet(boardID: board.id)
                } label: {
                    Label("Nachfeiern", systemImage: "calendar.badge.clock")
                }

                if !board.geburtstagWeg.isEmpty {
                    Button {
                        store.geburtstageWiederAnlegen(boardID: board.id)
                    } label: {
                        Label("Weggeräumte wieder anlegen",
                              systemImage: "arrow.uturn.backward")
                    }
                }

                if regel != .aus {
                    DatePicker("Uhrzeit", selection: Binding(
                        get: { uhrzeit(regel == .amVortag ? board.geburtstagsZeitVortag
                                                          : board.geburtstagsZeit) },
                        set: { zeit in
                            var neu = board
                            let minuten = minutenAusUhrzeit(zeit)
                            if regel == .amVortag { neu.geburtstagsZeitVortag = minuten }
                            else { neu.geburtstagsZeit = minuten }
                            store.updateBoard(neu)
                            store.planeGeburtstagsmeldungen()
                        }
                    ), displayedComponents: .hourAndMinute)

                    Text(regel.hinweis)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Geburtstage")
        } footer: {
            Text("Trage die Geburtstage bei den Namen ein — in den "
                 + "Namenslisten, je Name der kleine Kalenderknopf. "
                 + "Wer keinen hat, macht "
                 + "nichts anders.\n\n"

                 + "Am Geburtstag entsteht von selbst eine Seite mit dem Namen, "
                 + "dem Alter und einer Feier zum Antippen. Feiern mehrere am "
                 + "selben Tag, entsteht für jedes Kind eine eigene Seite, und "
                 + "jede bekommt eine andere Feier. Auf der ersten Seite steht "
                 + "oben rechts ein Hinweis, der dorthin führt.\n\n"

                 + "Die Seiten bleiben stehen, bis du sie löschst — und dann "
                 + "bleiben sie weg. Auch am Geburtstag selbst: Gelöschtes wird "
                 + "nicht noch einmal angelegt. Versehentlich? Dann hilft "
                 + "„Weggeräumte wieder anlegen“, solange der Tag läuft.\n\n"

                 + "Waren Geburtstage in den Ferien, holt „Nachfeiern“ sie "
                 + "am ersten Schultag nach — du wählst aus, wer dran ist.")
        }
    }

    private func uhrzeit(_ minuten: Int) -> Date {
        let kalender = Calendar.current
        return kalender.date(bySettingHour: minuten / 60, minute: minuten % 60,
                             second: 0, of: Date()) ?? Date()
    }

    private func minutenAusUhrzeit(_ zeit: Date) -> Int {
        let s = Calendar.current.dateComponents([.hour, .minute], from: zeit)
        return (s.hour ?? 8) * 60 + (s.minute ?? 0)
    }
}
