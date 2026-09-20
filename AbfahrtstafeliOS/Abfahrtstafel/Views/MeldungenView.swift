import SwiftUI

/// Das Band über der Tafel, wenn Betriebsmeldungen vorliegen.
///
/// Heißt `Betriebsmeldungsband` und nicht `Meldungsband`: Das gibt es schon
/// (`Views/Hinweisflaeche.swift`) und meint etwas anderes — einen Fehler der
/// App selbst. Zwei gleichnamige Bänder, von denen eines „kein Netz" und das
/// andere „Straße gesperrt" bedeutet, wären beim Lesen des Quelltextes eine
/// Falle.
///
/// Es steht da, weil eine Umleitung die Zeiten darunter fragwürdig macht —
/// und zwar auf eine Art, die man den Zeiten nicht ansieht. Ein Bus, der eine
/// gesperrte Straße umfährt, meldet vielleicht pünktlich zu sein und hält
/// trotzdem nicht dort, wo jemand wartet.
struct Betriebsmeldungsband: View {
    let anzahl: Int
    let dringend: Bool
    let oeffnen: () -> Void

    var body: some View {
        Button(action: oeffnen) {
            HStack(spacing: 8) {
                Image(systemName: dringend ? "exclamationmark.octagon.fill" : "exclamationmark.bubble.fill")
                    .foregroundStyle(dringend ? .red : .orange)
                Text(anzahl == 1 ? "Eine Betriebsmeldung" : "\(anzahl) Betriebsmeldungen")
                    .font(.footnote.weight(.medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background((dringend ? Color.red : Color.orange).opacity(0.13))
        }
        .buttonStyle(.plain)
    }
}

/// Das Band, das sagt: Diese Meldung steht NICHT in den Fahrplandaten.
///
/// **Der Grund, aus dem es dieses Band gibt** (gemeldet 09/2026 zur Linie 470
/// in Dortmund): Über der Halteliste stand eine Meldung über gesperrte
/// Haltestellen, in der Liste stand jeder Halt als angefahren. Beides war
/// richtig — die Meldung kommt vom Verbund, die Halte aus den Fahrplandaten,
/// und der Verbund hatte die Umleitung nur beschrieben und nicht eingepflegt.
/// Nebeneinander gelesen sah es aus wie ein Fehler der App.
///
/// Es ist KEIN Knopf. Die Meldung selbst steht einen Fingerbreit darüber und
/// ist einer; zwei Trefferflächen übereinander lösen zuverlässig die falsche
/// aus.
struct Planwegband: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(.orange)
            Text("Diese Änderungen stehen NICHT im Fahrplan. Unten steht deshalb der Planweg — eine gesperrte Haltestelle kann dort als angefahren erscheinen.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10))
    }
}

/// Die kleine Marke an einer Abfahrtszeile, deren Linie eine Meldung hat.
///
/// Sie ist der Grund, warum die Meldungen überhaupt je Linie zugeordnet
/// werden: Eine Liste von acht Meldungen über der Tafel liest niemand. Ein
/// Dreieck neben der EIGENEN Linie sieht jeder.
struct Meldungsmarke: View {
    let dringend: Bool

    var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.caption2)
            .foregroundStyle(dringend ? .red : .orange)
            .accessibilityLabel("Betriebsmeldung zu dieser Linie")
    }
}

/// Die Liste der Betriebsmeldungen.
struct MeldungenListe: View {
    /// Wenn gesetzt, werden nur die Meldungen dieser Linie gezeigt — der Weg
    /// von der einzelnen Fahrt aus.
    var nurFuer: Linienkennung?

    @EnvironmentObject private var dienst: Meldungsdienst
    @Environment(\.dismiss) private var schliessen

    private var sichtbare: [Betriebsmeldung] {
        guard let nurFuer else { return dienst.meldungen }
        return dienst.meldungen(zu: nurFuer)
    }

    var body: some View {
        NavigationStack {
            Group {
                if sichtbare.isEmpty {
                    Hinweisflaeche(
                        symbol: "checkmark.circle",
                        titel: "Keine Meldungen",
                        text: dienst.quelle == nil
                            ? "Für diese Gegend gibt es keine Quelle für Betriebsmeldungen. Das heißt NICHT, dass alles planmäßig fährt — es heißt, dass niemand nachgesehen hat."
                            : "\(dienst.quelle ?? "Der Verbund") meldet gerade nichts."
                    )
                } else {
                    List {
                        ForEach(sichtbare) { meldung in
                            Meldungszeile(meldung: meldung)
                        }
                        Section {
                            EmptyView()
                        } footer: {
                            fusszeile
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(nurFuer.map { "Meldungen \($0.name)" } ?? "Betriebsmeldungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schließen") { schliessen() }
                }
            }
        }
    }

    private var fusszeile: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let quelle = dienst.quelle, let geholt = dienst.geholtUm {
                Text("Von \(quelle), geholt um \(geholt.formatted(date: .omitted, time: .shortened)).")
            }
            Text("Die Meldungen kommen vom Verkehrsverbund vor Ort, nicht von der Quelle der Abfahrtszeiten — die führt keine. Wo kein Verbund zuständig ist, gibt es hier nichts zu sehen, auch wenn etwas los ist.")
        }
        .font(.caption2)
    }
}

private struct Meldungszeile: View {
    let meldung: Betriebsmeldung
    @State private var ausgeklappt = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Image(systemName: meldung.dringend ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(meldung.dringend ? .red : .orange)
                    .font(.footnote)
                Text(meldung.titel)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !meldung.linien.isEmpty {
                Text("Betrifft: \(meldung.linien.sorted().joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !meldung.text.isEmpty {
                Text(meldung.text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    // Lange Meldungen sind wirklich lang (eine Sperrung mit
                    // Ersatzhaltestellen füllt eine halbe Seite). Erst
                    // angerissen, auf Tipp ganz.
                    .lineLimit(ausgeklappt ? nil : 4)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture { withAnimation(.snappy) { ausgeklappt.toggle() } }
            }

            // Der Satz des Herausgebers dazu, ob die beschriebene Änderung
            // im Fahrplan steht. Er steht WÖRTLICH da und wird nicht
            // zusammengefasst: Die Deutung darüber (`aenderungenImFahrplan`)
            // liest ein einzelnes Wort — wer den Satz daneben liest, sieht
            // sofort, ob sie stimmt.
            if !meldung.fahrplanhinweis.isEmpty {
                Label {
                    Text(meldung.fahrplanhinweis)
                } icon: {
                    Image(systemName: meldung.aenderungenImFahrplan == false
                          ? "exclamationmark.triangle.fill"
                          : "info.circle")
                }
                .font(.caption)
                .foregroundStyle(meldung.aenderungenImFahrplan == false ? .orange : .secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            if let adresse = meldung.adresse {
                Link(destination: adresse) {
                    Label("Beim Verbund nachlesen", systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 3)
        .lesebreite()
    }
}

#Preview {
    MeldungenListe()
        .environmentObject(Meldungsdienst())
        .environmentObject(Standortdienst())
        .environmentObject(Fusswegmesser(quelle: Musterdienst()))
}
