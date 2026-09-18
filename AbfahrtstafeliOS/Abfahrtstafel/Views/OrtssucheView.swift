import CoreLocation
import SwiftUI

/// Die Vorschlagsliste beim Eintippen — Haltestellen zuerst, Adressen danach.
///
/// Drei Dinge, die sie ehrlich halten:
///
/// 1. **Unter drei Zeichen wird gar nicht gefragt.** Der Dienst antwortet
///    darunter mit einer LEEREN Liste und nicht mit einem Fehler (gemessen
///    09/2026: „k" und „kl" geben null Treffer, „kle" zehn). Eine leere Liste
///    sähe aus wie „nichts gefunden" — deshalb steht dort der Satz, wie viele
///    Zeichen noch fehlen.
/// 2. **Was ein Treffer IST, steht an der Zeile.** Ein Vorschlag, der aussieht
///    wie eine Haltestelle und eine Adresse ist, wäre eine Falle: Die Auskunft
///    setzt dort einen Fußweg an, und der kann lang sein.
/// 3. **Die Entfernung ist eine Luftlinie**, und das steht dabei — dieselbe
///    Regel wie an jeder Haltestelle dieser App.
struct OrtssucheView: View {
    let titel: String
    /// Der Punkt, um den herum vorgeschlagen wird.
    let nahe: CLLocationCoordinate2D?
    /// Ob „Mein Standort" als Zeile angeboten wird. Beim Ziel wäre sie
    /// unsinnig — von hier nach hier.
    var darfStandort = false
    let gewaehlt: (Ortstreffer?) -> Void

    @EnvironmentObject private var planer: Verbindungsmodell
    @EnvironmentObject private var merkliste: Merkliste
    @Environment(\.dismiss) private var schliessen

    @State private var text = ""
    @State private var treffer: [Ortstreffer] = []
    @State private var laeuft = false
    @State private var fehler: String?
    @State private var suchlauf: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if darfStandort && nahe != nil && text.isEmpty {
                    Section {
                        Button {
                            gewaehlt(nil)
                        } label: {
                            Label("Mein Standort", systemImage: "location.fill")
                        }
                    }
                }

                if !merkliste.haltestellen.isEmpty && text.isEmpty {
                    Section("Gemerkt") {
                        ForEach(merkliste.haltestellen) { halt in
                            Button {
                                gewaehlt(
                                    Ortstreffer(
                                        id: halt.id,
                                        name: halt.name,
                                        gegend: halt.gegend,
                                        koordinate: halt.koordinate,
                                        istHaltestelle: true
                                    )
                                )
                            } label: {
                                Trefferzeile(
                                    treffer: Ortstreffer(
                                        id: halt.id,
                                        name: halt.name,
                                        gegend: halt.gegend,
                                        koordinate: halt.koordinate,
                                        istHaltestelle: true
                                    ),
                                    nahe: nahe
                                )
                            }
                        }
                    }
                }

                if !text.isEmpty {
                    Section {
                        if text.trimmingCharacters(in: .whitespaces).count < planer.dienst.kuerzesteSuche {
                            Hinweiszeile(
                                "Noch \(planer.dienst.kuerzesteSuche - text.trimmingCharacters(in: .whitespaces).count) Zeichen — darunter sucht die Auskunft nicht."
                            )
                        } else if laeuft && treffer.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Wird gesucht …").foregroundStyle(.secondary)
                            }
                        } else if let fehler {
                            Hinweiszeile(fehler)
                        } else if treffer.isEmpty {
                            Hinweiszeile("Dazu findet die Auskunft nichts. Eine Stadt davorzusetzen hilft oft — „Dortmund Kley“ statt „Kley“.")
                        } else {
                            ForEach(treffer) { eintrag in
                                Button { gewaehlt(eintrag) } label: {
                                    Trefferzeile(treffer: eintrag, nahe: nahe)
                                }
                            }
                        }
                    } footer: {
                        if nahe != nil && !treffer.isEmpty {
                            Text("Vorgeschlagen wird zuerst, was in der Nähe des Startpunkts liegt. Weiter entfernte Orte stehen darunter — sie sind damit nicht ausgeschlossen.")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(
                text: $text,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Haltestelle oder Adresse"
            )
            .onChange(of: text) { _, neu in suchen(neu) }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Abbrechen") { schliessen() }
                }
            }
        }
    }

    /// Gesucht wird mit kurzer Verzögerung, und der laufende Auftrag wird
    /// abgebrochen. Ohne das stellte „Dortmund" acht Anfragen — eine je
    /// Buchstabe —, und die Antwort auf „Dortmu" käme womöglich nach der auf
    /// „Dortmund" an und überschriebe sie.
    private func suchen(_ eingabe: String) {
        suchlauf?.cancel()
        fehler = nil
        let gekuerzt = eingabe.trimmingCharacters(in: .whitespacesAndNewlines)
        guard gekuerzt.count >= planer.dienst.kuerzesteSuche else {
            treffer = []
            laeuft = false
            return
        }
        laeuft = true
        suchlauf = Task {
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            do {
                let gefunden = try await planer.dienst.orteSuchen(gekuerzt, nahe: nahe)
                guard !Task.isCancelled else { return }
                treffer = gefunden
            } catch {
                guard !Task.isCancelled else { return }
                treffer = []
                fehler = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            laeuft = false
        }
    }

    private struct Hinweiszeile: View {
        let text: String
        init(_ text: String) { self.text = text }
        var body: some View {
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private struct Trefferzeile: View {
        let treffer: Ortstreffer
        let nahe: CLLocationCoordinate2D?

        var body: some View {
            HStack(spacing: 11) {
                Image(systemName: treffer.symbol)
                    .foregroundStyle(treffer.istHaltestelle ? Color.accentColor : Color.secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(treffer.name)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        if let gegend = treffer.gegend { Text(gegend) }
                        if !treffer.istHaltestelle { Text("· Adresse") }
                        if let meter = treffer.entfernung(von: nahe) {
                            Text("· \(Haltestelle.entfernungstext(meter)) Luftlinie")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
        }
    }
}
