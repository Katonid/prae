import SwiftUI

/// Ein Element oder eine ganze Seite auf eine andere Tafel legen.
///
/// Was dazugehört, kommt von selbst mit: Namenslisten liegen ohnehin neben
/// den Tafeln und gelten für alle; Klang-, Bild- und Kameradateien liegen
/// unter ihrem Namen im Ordner der App, und die Zieltafel stellt sie neu in
/// die Warteschlange zum Hochladen. Es gibt also nichts anzuhaken.
struct UebertragenSheet: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.dismiss) private var dismiss

    let quelle: String
    let gut: Gut
    /// Wird das hier als eigenes Blatt gezeigt? Dann braucht es einen Weg
    /// zurück; wird es geschoben, gibt es schon den Pfeil oben links.
    var alsBlatt: Bool = false

    enum Gut: Equatable {
        case element(String)
        case seite(String)
    }

    @State private var kopieren = false

    private var tafel: Board? { store.board(quelle) }

    /// Wohin es gehen kann.
    ///
    /// Bei einem Element gehört **die eigene Tafel dazu**: Ihre anderen
    /// Seiten sind das häufigste Ziel überhaupt. Eine ganze Seite auf
    /// dieselbe Tafel zu legen ist dagegen „Seite kopieren“ und steht in der
    /// Seitenverwaltung.
    private var ziele: [Board] {
        switch gut {
        case .element:
            guard let tafel, tafel.seiten.count > 1 else {
                return store.visibleBoards.filter { $0.id != quelle }
            }
            return [tafel] + store.visibleBoards.filter { $0.id != quelle }
        case .seite:
            return store.visibleBoards.filter { $0.id != quelle }
        }
    }

    /// Auf welcher Seite das Element gerade liegt.
    private var eigeneSeite: String? {
        guard case .element(let id) = gut, let tafel,
              let widget = tafel.widgets.first(where: { $0.id == id })
        else { return nil }
        return widget.pageID.nonEmpty ?? tafel.ersteSeitenID
    }

    /// Die letzte Seite einer Tafel darf nur kopiert werden — eine Tafel
    /// ohne Seite gibt es nicht.
    private var darfVerschieben: Bool {
        guard case .seite = gut, let tafel else { return true }
        return tafel.seiten.count > 1
    }

    var body: some View {
        List {
            Section {
                Picker("", selection: $kopieren) {
                    Text("Verschieben").tag(false)
                    Text("Kopieren").tag(true)
                }
                .pickerStyle(.segmented)
                .disabled(!darfVerschieben)
            } header: {
                Text(kopfzeile)
            } footer: {
                Text(darfVerschieben
                     ? (kopieren
                        ? "Hier bleibt alles stehen; drüben entsteht eine Kopie."
                        : "Hier verschwindet es, drüben taucht es auf.")
                     : "Das ist die letzte Seite dieser Tafel — sie lässt sich nur "
                       + "kopieren. Eine Tafel ohne Seite gibt es nicht.")
            }

            if ziele.isEmpty {
                Section {
                    Text("Es gibt nichts, wohin es gehen könnte: keine zweite Tafel "
                         + "und keine zweite Seite. Eine neue Tafel legst du oben links "
                         + "über den Tafelnamen an, eine neue Seite unter Menü → "
                         + "„Seiten verwalten“.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(ziele) { ziel in
                        zielZeile(ziel)
                    }
                } header: {
                    Text("Wohin?")
                } footer: {
                    Text("Namenslisten, Klänge und Bilder, die dazugehören, kommen "
                         + "von selbst mit.\n\nAuf einer geteilten Tafel kann auch die "
                         + "Kollegin ein Element von dort auf ihre eigene Tafel "
                         + "übernehmen — derselbe Weg, an ihrem Gerät.")
                }
            }
        }
        .navigationTitle("Übertragen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if alsBlatt {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .onAppear { if !darfVerschieben { kopieren = true } }
    }

    private var kopfzeile: String {
        switch gut {
        case .element(let id):
            let name = tafel?.widgets.first { $0.id == id }?.kind.title ?? "Element"
            return name
        case .seite(let id):
            return tafel?.seitenName(id) ?? "Seite"
        }
    }

    @ViewBuilder
    private func zielZeile(_ ziel: Board) -> some View {
        // Bei einem Element mit mehreren Seiten wird erst gefragt, auf
        // welche — sonst landete es womöglich auf einer Seite, die gerade
        // gar nicht gemeint war.
        if case .element = gut, ziel.seiten.count > 1 {
            NavigationLink {
                seitenwahl(ziel)
            } label: {
                zielBeschriftung(ziel)
            }
        } else {
            Button {
                fuehreAus(ziel: ziel.id, seite: nil)
            } label: {
                zielBeschriftung(ziel)
            }
        }
    }

    private func zielBeschriftung(_ ziel: Board) -> some View {
        HStack(spacing: 12) {
            Text(ziel.emoji)
                .font(.system(size: 20))
            VStack(alignment: .leading, spacing: 2) {
                Text(ziel.id == quelle ? ziel.name + " (diese Tafel)" : ziel.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(untertitel(ziel))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private func untertitel(_ ziel: Board) -> String {
        let seiten = ziel.seiten.count
        let elemente = ziel.widgets.count
        return (seiten == 1 ? "1 Seite" : "\(seiten) Seiten")
            + " · " + (elemente == 1 ? "1 Element" : "\(elemente) Elemente")
    }

    private func seitenwahl(_ ziel: Board) -> some View {
        // Die Seite, auf der das Element schon liegt, steht nicht zur Wahl.
        let seiten = ziel.seiten.filter { !($0.id == eigeneSeite && ziel.id == quelle) }
        return List {
            Section {
                ForEach(seiten) { seite in
                    Button {
                        fuehreAus(ziel: ziel.id, seite: seite.id)
                    } label: {
                        HStack {
                            Text(ziel.seitenName(seite.id))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(ziel.widgets(auf: seite.id).count)")
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                }
            } header: {
                Text("Auf welche Seite?")
            }
        }
        .navigationTitle(ziel.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fuehreAus(ziel: String, seite: String?) {
        let name = store.board(ziel)?.name ?? "Tafel"
        let geschafft: Bool
        switch gut {
        case .element(let id):
            geschafft = store.uebertrageWidget(id, von: quelle, nach: ziel,
                                               seite: seite, kopieren: kopieren)
        case .seite(let id):
            geschafft = store.uebertrageSeite(id, von: quelle, nach: ziel,
                                              kopieren: kopieren)
        }
        if geschafft {
            Haptics.success()
            store.showStatus(kopieren ? "Kopie liegt auf „\(name)\u{201C}."
                                      : "Verschoben auf „\(name)\u{201C}.")
        }
        dismiss()
    }
}
