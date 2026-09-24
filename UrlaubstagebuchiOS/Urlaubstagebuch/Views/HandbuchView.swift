import SwiftUI

// DAS HANDBUCH IN DER APP (ab 1.0.77).
//
// Kapitel zum Blättern, eine Suche zum Finden — und an jedem Eintrag der
// WEG samt einem Knopf, der dorthin springt. Ein Handbuch, das eine
// Funktion beschreibt und einen danach suchen lässt, ist die Frage von
// vorhin noch einmal.
//
// **Der Sprung geht über den Blattwunsch** (`ReiseView.alsNaechstes`):
// Dieses Handbuch ist selbst ein Blatt, und ein Blatt über einem Blatt
// wäre auf dem iPad ein Kärtchen auf einem Kärtchen. Es macht sich also
// zu, und die Wurzel öffnet das Ziel im `onDismiss` — dieselbe Bauweise
// wie beim geführten Weg Buch aufbauen seit 1.0.18.
struct HandbuchView: View {
    /// Wohin gesprungen werden soll. Die Wurzel löst es ein, nachdem
    /// dieses Blatt zu ist.
    var springe: (ReiseView.Blatt) -> Void
    @Environment(\.dismiss) private var schliessen
    @State private var suche = ""

    var body: some View {
        List {
            if suche.isEmpty {
                uebersicht
            } else {
                treffer
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $suche, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Wo finde ich …?")
        .navigationTitle("Handbuch")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Kapitel

    @ViewBuilder
    private var uebersicht: some View {
        Section {
            Text("Jeder Eintrag sagt, WO die Funktion steht. Wo ein Pfeil dabeisteht, springt die App gleich dorthin.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        // Die GESTEN stehen ganz oben und nicht erst im zweiten Kapitel:
        // Wer das Fragezeichen antippt, weiß oft nicht, wie etwas geht —
        // und nicht, wo es steht. Derselbe Eintrag steht daneben im
        // Kapitel; es ist dieselbe Zielangabe, kein zweiter Weg.
        Section {
            Button {
                springen(.bedienung)
            } label: {
                Label("Alle Gesten auf einen Blick", systemImage: "hand.tap")
            }
        } footer: {
            Text("Antippen, doppelt tippen, ziehen, drehen, zwei Finger \u{2014} was auf der Seite geht.")
        }

        ForEach(Handbuch.kapitel) { kapitel in
            Section {
                NavigationLink {
                    KapitelView(kapitel: kapitel, springe: springen)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kapitel.titel)
                            Text(kapitel.einleitung)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: kapitel.symbol)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
    }

    // MARK: - Suche

    @ViewBuilder
    private var treffer: some View {
        let gefunden = Handbuch.suche(suche)
        if gefunden.isEmpty {
            Section {
                // Eine leere Liste ließe einen raten, ob die Suche läuft.
                ContentUnavailableView {
                    Label("Nichts gefunden", systemImage: "magnifyingglass")
                } description: {
                    Text("Gesucht wird in allen Kapiteln \u{2014} auch in den Wegen. Versuch ein einzelnes Wort: Anschnitt, Wasserzeichen, Broschüre, Silbentrennung.")
                }
            }
        } else {
            Section("\(gefunden.count) Treffer") {
                ForEach(gefunden, id: \.eintrag.id) { paar in
                    EintragZeile(eintrag: paar.eintrag, kapitel: paar.kapitel,
                                 springe: springen)
                }
            }
        }
    }

    private func springen(_ ziel: ReiseView.Blatt) {
        springe(ziel)
        schliessen()
    }
}

// Ein Kapitel: seine Einträge untereinander.
private struct KapitelView: View {
    let kapitel: Handbuchkapitel
    var springe: (ReiseView.Blatt) -> Void

    var body: some View {
        List {
            if !kapitel.einleitung.isEmpty {
                Section {
                    Text(kapitel.einleitung)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach(kapitel.eintraege) { eintrag in
                    EintragZeile(eintrag: eintrag, kapitel: nil, springe: springe)
                }
            }
        }
        .navigationTitle(kapitel.titel)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Ein Eintrag: Titel, Text, Weg — und der Sprung, wo es einen gibt.
private struct EintragZeile: View {
    let eintrag: Handbucheintrag
    /// In der Trefferliste steht dazu, aus welchem Kapitel der Eintrag
    /// kommt; im Kapitel selbst wäre das dieselbe Angabe zweimal.
    let kapitel: String?
    var springe: (ReiseView.Blatt) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let kapitel {
                Text(kapitel.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(eintrag.titel)
                .font(.subheadline.weight(.semibold))
            Text(eintrag.text)
                .font(.callout)
                .foregroundStyle(.secondary)
            if !eintrag.weg.isEmpty {
                if let ziel = eintrag.ziel {
                    Button {
                        springe(ziel)
                    } label: {
                        Label(eintrag.weg, systemImage: "arrow.right.circle.fill")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.borderless)
                    .padding(.top, 1)
                } else {
                    Label(eintrag.weg, systemImage: "location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

// Als Blatt, mit eigenem Stapel — wie jedes andere Blatt dieser App.
struct Handbuchblatt: View {
    var springe: (ReiseView.Blatt) -> Void
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            HandbuchView(springe: springe)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { schliessen() }
                    }
                }
        }
    }
}
