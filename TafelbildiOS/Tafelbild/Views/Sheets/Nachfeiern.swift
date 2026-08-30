import SwiftUI

/// Geburtstage nachholen, die während der Ferien waren.
///
/// **Warum das nicht von selbst passiert.** Der Geburtstagsdienst sieht
/// immer nur den heutigen Tag an, und das ist richtig so: Ein iPad, das
/// sechs Wochen im Schrank stand, bekäme beim Einschalten sonst zwanzig
/// Seiten auf einmal, darunter Kinder, die längst nicht mehr in der Klasse
/// sind. Am ersten Schultag entscheidet deshalb ein Mensch, wer nachfeiert
/// (gemeldet 08/2026).
///
/// **Vorbelegt sind sechs Wochen.** Das ist die längste Ferienzeit im
/// Schuljahr; kürzere Ferien sind damit mit abgedeckt, und der Zeitraum
/// lässt sich ohnehin verschieben.
struct NachfeiernSheet: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.dismiss) private var dismiss
    let boardID: String

    @State private var seit: Date = Calendar.current.date(byAdding: .day, value: -42,
                                                          to: Date()) ?? Date()
    @State private var gewaehlt: Set<String> = []
    @State private var vorbelegt = false

    private var board: Board? { store.board(boardID) }

    private var liste: NameList? {
        guard let board,
              let id = board.geburtstagslisteID(vorhanden: store.nameLists)
        else { return nil }
        return store.nameLists.first { $0.id == id }
    }

    private var vergangene: [Geburtstage.Vergangen] {
        guard let liste else { return [] }
        return Geburtstage.vergangene(in: liste, seit: seit)
    }

    var body: some View {
        List {
            Section {
                DatePicker("Seit", selection: $seit, displayedComponents: .date)
            } header: {
                Text("Zeitraum")
            } footer: {
                Text("Alle Geburtstage von diesem Tag an bis heute stehen "
                     + "unten zur Auswahl. Voreingestellt sind sechs Wochen — "
                     + "die längsten Ferien im Schuljahr.")
            }

            if vergangene.isEmpty {
                Section {
                    Text(liste == nil
                         ? "Für diese Tafel ist keine Namensliste eingestellt."
                         : "In diesem Zeitraum hatte niemand Geburtstag.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(vergangene) { fall in
                        Button {
                            if gewaehlt.contains(fall.id) { gewaehlt.remove(fall.id) }
                            else { gewaehlt.insert(fall.id) }
                        } label: {
                            HStack {
                                Image(systemName: gewaehlt.contains(fall.id)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(gewaehlt.contains(fall.id)
                                                     ? Color.accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fall.eintrag.text.nonEmpty ?? "Ohne Namen")
                                        .foregroundStyle(.primary)
                                    HStack(spacing: 8) {
                                        Text(fall.tag.formatted(.dateTime.day().month(.wide)))
                                        if let alter = alterVon(fall) {
                                            Text("wurde \(alter)")
                                        }
                                        if schonAngelegt(fall) {
                                            Text("Seite steht schon")
                                                .foregroundStyle(Color(hex: "#f59e0b"))
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Wer nachfeiert")
                        Spacer()
                        Button(gewaehlt.count == vergangene.count ? "Keine" : "Alle") {
                            gewaehlt = gewaehlt.count == vergangene.count
                                ? [] : Set(vergangene.map(\.id))
                        }
                        .font(.caption)
                    }
                } footer: {
                    Text("Für jedes gewählte Kind entsteht eine eigene Seite mit "
                         + "dem Datum des Geburtstags und dem Alter, das es an "
                         + "**diesem** Tag geworden ist — nicht dem von heute.\n\n"

                         + "Die Feier und die Fanfare werden abgewechselt, damit "
                         + "nicht bei jedem Kind dasselbe läuft.")
                }
            }
        }
        .navigationTitle("Nachfeiern")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Anlegen") {
                    let wen = vergangene.filter { gewaehlt.contains($0.id) }
                    store.legeNachfeierAn(boardID: boardID, wen: wen)
                    Haptics.success()
                    dismiss()
                }
                .disabled(gewaehlt.isEmpty)
            }
        }
        .onAppear {
            // Beim ersten Öffnen alles ankreuzen, was noch keine Seite hat:
            // Der Regelfall nach den Ferien ist „alle".
            guard !vorbelegt else { return }
            vorbelegt = true
            gewaehlt = Set(vergangene.filter { !schonAngelegt($0) }.map(\.id))
        }
    }

    private func alterVon(_ fall: Geburtstage.Vergangen) -> Int? {
        guard let geboren = Geburtstage.datum(fall.eintrag.geburtstag) else { return nil }
        let jahre = Calendar.current.dateComponents([.year], from: geboren, to: fall.tag).year
        guard let jahre, (1...130).contains(jahre) else { return nil }
        return jahre
    }

    /// Steht für dieses Kind und dieses Jahr schon eine Seite?
    private func schonAngelegt(_ fall: Geburtstage.Vergangen) -> Bool {
        guard let board else { return false }
        return board.widgets.contains { widget in
            guard case .geburtstag(let inhalt) = widget.content else { return false }
            return inhalt.eintragID == fall.eintrag.id
                && inhalt.jahr == fall.jahr && !inhalt.hinweis
        }
    }
}
