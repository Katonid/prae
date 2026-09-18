import SwiftUI

/// Der Lauf einer Fahrt: Karte oben, darunter alle Halte von der Start- bis
/// zur Endhaltestelle.
///
/// Das ist der Bildschirm, um den der Nutzer gebeten hat — „Start- und
/// Endhaltestelle sowie die Zwischenhalte". Deshalb ist die Halteliste hier
/// kein Ausklappbereich, sondern der Inhalt der Seite: Wer diesen Bildschirm
/// öffnet, will die Liste sehen und nicht erst suchen. Dieselbe Lehre wie beim
/// Gruppenchat in Schulalarm — ein Knopf, den niemand findet, ist kein Knopf.
struct FahrtView: View {
    let fahrtId: String
    /// Von welchem Halt aus die Fahrt geöffnet wurde. Danach richtet sich, was
    /// hervorgehoben wird und wohin die Liste springt.
    var einstiegsHaltestelle: Haltestelle?

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var uhr: Uhrwerk

    @State private var fahrt: Fahrt?
    @State private var fehler: String?
    @State private var laedt = true
    @State private var karteGross = false

    var body: some View {
        Group {
            if let fahrt {
                inhalt(fahrt)
            } else if laedt {
                ProgressView("Fahrt wird geladen …")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Hinweisflaeche(
                    symbol: "exclamationmark.triangle",
                    titel: "Der Lauf dieser Fahrt ist nicht zu bekommen",
                    text: fehler ?? "Der Fahrplandienst hat nichts dazu.",
                    knopf: "Noch einmal versuchen",
                    tat: { Task { await laden() } }
                )
            }
        }
        .navigationTitle(fahrt.map { "\($0.linie.name) nach \($0.richtung)" } ?? "Fahrt")
        .navigationBarTitleDisplayMode(.inline)
        .task { await laden() }
    }

    @ViewBuilder
    private func inhalt(_ fahrt: Fahrt) -> some View {
        ScrollViewReader { blatt in
            List {
                Section {
                    StreckenKarte(
                        fahrt: fahrt,
                        einstieg: einstiegIndex(in: fahrt),
                        hoehe: karteGross ? 460 : 230
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))

                    Button {
                        withAnimation(.snappy) { karteGross.toggle() }
                    } label: {
                        Label(
                            karteGross ? "Karte kleiner" : "Karte größer",
                            systemImage: karteGross ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
                        )
                        .font(.footnote)
                    }
                } header: {
                    Kopfzeile(fahrt: fahrt)
                        .textCase(nil)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 10, trailing: 0))
                }

                Section {
                    ForEach(Array(fahrt.halte.enumerated()), id: \.element.id) { nummer, halt in
                        HaltZeile(
                            halt: halt,
                            farbe: fahrt.linie.anzeigefarbe,
                            istErster: nummer == 0,
                            istLetzter: nummer == fahrt.halte.count - 1,
                            istEinstieg: nummer == einstiegIndex(in: fahrt),
                            schonVorbei: nummer < (fahrt.indexErreicht(uhr.jetzt) ?? -1)
                        )
                        .id(nummer)
                    }
                } header: {
                    Text("\(fahrt.halte.count) Halte — \(fahrt.start?.haltestelle.name ?? "?") bis \(fahrt.ziel?.haltestelle.name ?? "?")")
                } footer: {
                    Text("Die Zeiten stammen aus \(model.dienst.quellenname). Wo kein Echtzeitwert vorliegt, steht die Planzeit.")
                }
            }
            .listStyle(.insetGrouped)
            .onAppear {
                // Auf den eigenen Einstieg springen. Bei einer Fahrt, die vor
                // zwanzig Stationen begonnen hat, stünde der Nutzer sonst am
                // Anfang der Liste und müsste seinen Halt suchen.
                guard let ziel = einstiegIndex(in: fahrt), ziel > 2 else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation { blatt.scrollTo(ziel, anchor: .center) }
                }
            }
        }
    }

    /// Welcher Halt der eigene ist.
    ///
    /// Verglichen wird ÜBER DIE KENNUNG und, falls die nicht passt, über den
    /// Namen: Die Abfahrtstafel nennt den Steig (`…:2:51:51`), der Fahrtlauf
    /// oft den Bahnhof (`…:2`). Nur über die Kennung zu gehen ließe die
    /// Hervorhebung bei den meisten Fahrten einfach ausfallen — still und
    /// unbemerkt.
    private func einstiegIndex(in fahrt: Fahrt) -> Int? {
        guard let gesucht = einstiegsHaltestelle else { return nil }
        if let treffer = fahrt.halte.firstIndex(where: { $0.haltestelle.id == gesucht.id }) {
            return treffer
        }
        return fahrt.halte.firstIndex {
            $0.haltestelle.name.caseInsensitiveCompare(gesucht.name) == .orderedSame
        }
    }

    private func laden() async {
        laedt = true
        fehler = nil
        do {
            var geholt = try await model.dienst.fahrt(fahrtId)
            geholt.einstiegIndex = einstiegIndex(in: geholt)
            fahrt = geholt
        } catch {
            fehler = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        laedt = false
    }
}

/// Linie, Ziel und Betrieb über der Karte.
private struct Kopfzeile: View {
    let fahrt: Fahrt

    var body: some View {
        HStack(spacing: 12) {
            Liniensymbol(linie: fahrt.linie, gross: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Richtung \(fahrt.richtung)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                if let betrieb = fahrt.linie.betrieb {
                    Text(betrieb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

/// Ein Halt in der Liste — mit dem senkrechten Strang, der die Fahrt zeigt.
private struct HaltZeile: View {
    let halt: Zwischenhalt
    let farbe: Color
    let istErster: Bool
    let istLetzter: Bool
    let istEinstieg: Bool
    let schonVorbei: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Strang(
                farbe: farbe,
                obenSichtbar: !istErster,
                untenSichtbar: !istLetzter,
                gross: istErster || istLetzter || istEinstieg,
                gefuellt: istEinstieg,
                blass: schonVorbei
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(halt.haltestelle.name)
                    .font(istErster || istLetzter || istEinstieg ? .body.weight(.semibold) : .body)
                    .strikethrough(halt.faelltAus, color: .secondary)
                    .foregroundStyle(schonVorbei ? Color.secondary : Color.primary)

                HStack(spacing: 6) {
                    if istErster { Kennzeichen("Start") }
                    if istLetzter { Kennzeichen("Ziel") }
                    if istEinstieg && !istErster { Kennzeichen("Einstieg") }
                    if let steig = halt.steig { Text(steig) }
                    if halt.faelltAus { Text("Halt entfällt").foregroundStyle(.red) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Haltzeit(halt: halt)
        }
        .padding(.vertical, 2)
        .listRowSeparator(.hidden)
    }
}

private struct Kennzeichen: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.secondary.opacity(0.16)))
    }
}

/// Der senkrechte Strang mit dem Punkt — das Bild, das jeder von einer
/// Liniennetzanzeige kennt. Er trägt die Information „vorher/nachher" ohne
/// ein einziges Wort.
private struct Strang: View {
    let farbe: Color
    let obenSichtbar: Bool
    let untenSichtbar: Bool
    let gross: Bool
    let gefuellt: Bool
    let blass: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(obenSichtbar ? farbe.opacity(blass ? 0.3 : 1) : .clear)
                .frame(width: 4)
            ZStack {
                Circle()
                    .fill(.background)
                Circle()
                    .strokeBorder(farbe.opacity(blass ? 0.35 : 1), lineWidth: gross ? 4 : 3)
                if gefuellt {
                    Circle().fill(farbe).padding(4)
                }
            }
            .frame(width: gross ? 18 : 12, height: gross ? 18 : 12)
            Rectangle()
                .fill(untenSichtbar ? farbe.opacity(blass ? 0.3 : 1) : .clear)
                .frame(width: 4)
        }
        .frame(width: 18)
        // Feste Höhe, damit der Strang lückenlos durchläuft: Ohne sie ist er
        // genau so hoch wie der Text daneben, und bei zweizeiligen Namen
        // entstehen Löcher zwischen den Zeilen.
        .frame(minHeight: 46)
    }
}

/// Ankunft und Abfahrt eines Haltes — mit der Abweichung, wenn es eine gibt.
private struct Haltzeit: View {
    let halt: Zwischenhalt

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if let zeit = halt.geplanteZeit ?? halt.zeit {
                Text(zeit, format: .dateTime.hour().minute())
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                    .strikethrough(halt.verspaetungMinuten != nil, color: .secondary)
            } else {
                Text("—").foregroundStyle(.secondary)
            }

            if let minuten = halt.verspaetungMinuten, let ist = halt.zeit {
                HStack(spacing: 3) {
                    Text(minuten > 0 ? "+\(minuten)" : "\(minuten)")
                    Text(ist, format: .dateTime.hour().minute())
                }
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(minuten > 0 ? Color.red : Color.blue)
            }
        }
    }
}

#Preview {
    NavigationStack {
        FahrtView(fahrtId: "f-s3", einstiegsHaltestelle: Musterdienst.marienplatz)
            .environmentObject(AppModel(dienst: Musterdienst()))
            .environmentObject(Uhrwerk())
    }
}
