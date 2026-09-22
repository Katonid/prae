import SwiftUI
import UniformTypeIdentifiers

// Die Reisespuren aus der Tagesspur-App einlesen.
//
// Gezeigt wird, was in der Datei steht, BEVOR etwas übernommen wird: je Tag
// die Zahl der Punkte, die Zahl der Aufenthalte und ob der Tag abgelesen
// oder aus einer Zeitzone gerechnet wurde. Ein Einlesen, das gleich
// losschreibt, nimmt dem Nutzer die einzige Stelle, an der er den Fehler
// noch sieht — dieselbe Bauweise wie beim Textimport.
struct SpurimportView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    @State private var waehler = false
    @State private var rohdaten: Data?
    @State private var dateiname = ""
    @State private var befund: Spureinfuhr.Befund?
    @State private var fehler: String?
    @State private var gewaehlt: Set<String> = []
    @State private var fehlendeAnlegen = true
    @State private var zone: TimeZone = .current
    // Läuft gerade das Nachschlagen der Zeitzonen? Es braucht Netz und
    // dauert einen Augenblick je Tag; eine Vorschau, die sich ohne ein Wort
    // dazu ändert, sieht aus wie ein Wackler.
    @State private var sucht = false

    var body: some View {
        NavigationStack {
            Form {
                if befund == nil {
                    einstieg
                } else {
                    vorschau
                }
            }
            .navigationTitle("Aus der Tagesspur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") { uebernehmen() }
                        .disabled(gewaehlt.isEmpty)
                }
            }
            .fullScreenCover(isPresented: $waehler) {
                Dateiwahl(typen: typen) { urls in
                    waehler = false
                    if let erste = urls.first { einlesen(erste) }
                }
                .ignoresSafeArea()
            }
        }
    }

    private var typen: [UTType] {
        var liste: [UTType] = [.json, .xml]
        if let gpx = UTType(filenameExtension: "gpx") { liste.append(gpx) }
        // `.data` steht mit drin, weil eine über Umwege geteilte Sicherung
        // gern ohne brauchbare Endung ankommt. Was wirklich darin steht,
        // entscheidet ohnehin der Inhalt.
        liste.append(.data)
        return liste
    }

    @ViewBuilder
    private var einstieg: some View {
        Section {
            Button {
                waehler = true
            } label: {
                Label("Datei wählen", systemImage: "folder")
            }
        } footer: {
            // Zusammengesetzte Sätze sind für SwiftUI kein Textschlüssel
            // mehr — Sternchen für Fettdruck stünden hier wörtlich da.
            Text("Die Tagesspur gibt zwei Formate aus. Die JSON-Sicherung ist die "
                 + "bessere Wahl: In ihr steht zu jedem Tag der Tagesschlüssel, also "
                 + "der Tag, den du erlebt hast. Bei GPX steht er nur dann dabei, "
                 + "wenn die Datei aus der Tagesspur stammt \u{2014} sonst muss der "
                 + "Tag aus dem Zeitstempel gerechnet werden, und dafür braucht es "
                 + "eine Zeitzone.")
        }

        if let fehler {
            Section {
                Label(fehler, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }

        Section("Was dabei passiert") {
            Text("Die Punkte werden ausgedünnt wie die aus den Fotos "
                 + "(\(Int(werk.reise.gestaltung.mindestabstandSpur)) m Mindestabstand, "
                 + "einstellbar unter Reisepunkte). Aufenthalte behalten ihren Namen "
                 + "und werden nie zusammengefasst.")
                .font(.footnote)
            Text("Punkte aus Fotos und von Hand gesetzte bleiben stehen. Was bei "
                 + "einem früheren Einlesen hereinkam, wird ersetzt \u{2014} zweimal "
                 + "dieselbe Datei ergibt nicht die doppelte Spur.")
                .font(.footnote)
        }
    }

    @ViewBuilder
    private var vorschau: some View {
        if let befund {
            Section {
                LabeledContent("Format", value: befund.art)
                LabeledContent("Tage", value: "\(befund.tage.count)")
                LabeledContent("Punkte", value: "\(befund.rohpunkte) \u{2192} \(befund.punkte)")
                if befund.aufenthalte > 0 {
                    LabeledContent("Aufenthalte", value: "\(befund.aufenthalte)")
                }
            } header: {
                Text(dateiname)
            } footer: {
                Text("Der Pfeil zeigt, was das Ausdünnen übrig lässt.")
            }

            Section {
                if sucht {
                    HStack(spacing: 9) {
                        ProgressView()
                        Text("Zeitzonen werden nachgeschlagen\u{2026}")
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Nachgeschlagen",
                               value: "\(nachgeschlagene) von \(befund.tage.count) Tagen")
                Picker("Sonst gilt", selection: $zone) {
                    ForEach(zonen, id: \.identifier) { eine in
                        Text(eine.identifier).tag(eine)
                    }
                }
                .onChange(of: zone) { _, _ in nochEinmalLesen() }
            } header: {
                Text("Uhrzeiten")
            } footer: {
                // Was hier steht, ist der Grund für den ganzen Umbau von
                // 1.0.19: In der Datei stehen Augenblicke auf der Weltuhr,
                // im Buch stehen Uhrzeiten am Ort.
                VStack(alignment: .leading, spacing: 6) {
                    Text("In der Datei stehen die Zeiten als Augenblick auf der "
                         + "Weltuhr. Gezeigt und gespeichert wird die Uhrzeit AM ORT "
                         + "\u{2014} in Deutschland also die mitteleuropäische "
                         + "Sommerzeit, in Kanada die von Toronto. Welche Zone gilt, "
                         + "wird je Tag am ersten Ort nachgeschlagen; das braucht Netz.")
                    // Der Satz wird als TEXT gebaut und nicht im
                    // ViewBuilder zusammengerechnet: Eine Verkettung aus
                    // fünf Teilen mit einem Bedingungsausdruck darin
                    // bekommt der Typprüfer nicht in vertretbarer Zeit
                    // auseinander („unable to type-check this expression
                    // in reasonable time").
                    Text(zonensatz(befund))
                }
            }

            Section {
                Toggle("Fehlende Tage anlegen", isOn: $fehlendeAnlegen)
            } footer: {
                Text("Aus ergibt: Spuren zu Tagen, die es im Buch noch nicht gibt, "
                     + "werden übersprungen statt angelegt.")
            }

            Section {
                ForEach(befund.tage) { tag in
                    zeile(tag)
                }
            } header: {
                HStack {
                    Text("\(gewaehlt.count) von \(befund.tage.count) gewählt")
                    Spacer()
                    Button(gewaehlt.count == befund.tage.count ? "Keinen" : "Alle") {
                        gewaehlt = gewaehlt.count == befund.tage.count
                            ? []
                            : Set(befund.tage.map(\.id))
                    }
                    .font(.caption)
                }
            }

            Section {
                Button("Andere Datei wählen", systemImage: "folder") { waehler = true }
            }
        }
    }

    private func zeile(_ tag: Spureinfuhr.Tagesspur) -> some View {
        Button {
            if gewaehlt.contains(tag.id) { gewaehlt.remove(tag.id) } else { gewaehlt.insert(tag.id) }
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: gewaehlt.contains(tag.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(gewaehlt.contains(tag.id) ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(tag.datum.mittel)
                        if !imBuch(tag.datum) {
                            Text("neu")
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.accentColor.opacity(0.18), in: Capsule())
                        }
                    }
                    Text(untertitel(tag))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let zeile = zonenzeile(tag) {
                        Text(zeile)
                            .font(.caption2)
                            .foregroundStyle(tag.zoneNachgeschlagen ? Color.secondary : Color.orange)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func untertitel(_ tag: Spureinfuhr.Tagesspur) -> String {
        var teile = ["\(tag.punkte.count) Punkte"]
        if tag.aufenthalte > 0 { teile.append("\(tag.aufenthalte) Aufenthalte") }
        teile.append(tag.gerechnet ? "Tag gerechnet" : "Tag abgelesen")
        return teile.joined(separator: " \u{00B7} ")
    }

    private func zonensatz(_ befund: Spureinfuhr.Befund) -> String {
        let anfang = "Wo sich keine ermitteln lässt, gilt die hier eingestellte. "
            + "Sie entscheidet außerdem über den TAG bei Dateien ohne Tagesschlüssel"
        guard befund.gerechneteTage > 0 else {
            return anfang + "; in dieser Datei steht er überall dabei."
        }
        return anfang + " \u{2014} das betrifft \(befund.gerechneteTage) von "
            + "\(befund.tage.count) Tagen dieser Datei."
    }

    // Welche Zone für diesen Tag gilt — und ob sie nachgeschlagen oder
    // angenommen ist. Eine angenommene Zone steht orange da: Sie ist keine
    // Auskunft über den Ort, sondern eine Einstellung.
    private func zonenzeile(_ tag: Spureinfuhr.Tagesspur) -> String? {
        guard let zone = tag.zone else { return nil }
        let name = Ortszeit.beschreibung(zone, am: tag.datum.mittag)
        return tag.zoneNachgeschlagen ? name : "\(name) \u{2014} angenommen"
    }

    private var nachgeschlagene: Int {
        befund?.tage.filter(\.zoneNachgeschlagen).count ?? 0
    }

    private func imBuch(_ datum: Tagesdatum) -> Bool {
        werk.reise.tage.contains { $0.datum == datum }
    }

    // Die Liste der Zonen beginnt mit der des Geräts — das ist in neun von
    // zehn Fällen die richtige, und sie soll nicht zwischen vierhundert
    // Kennungen gesucht werden müssen.
    private var zonen: [TimeZone] {
        var liste = [TimeZone.current]
        if let utc = TimeZone(identifier: "UTC") { liste.append(utc) }
        liste += TimeZone.knownTimeZoneIdentifiers.sorted().compactMap(TimeZone.init(identifier:))
        var gesehen = Set<String>()
        return liste.filter { gesehen.insert($0.identifier).inserted }
    }

    // MARK: - Tun

    private func einlesen(_ ort: URL) {
        fehler = nil
        dateiname = ort.lastPathComponent
        guard let daten = try? Data(contentsOf: ort) else {
            fehler = "Die Datei ließ sich nicht öffnen."
            return
        }
        rohdaten = daten
        nochEinmalLesen()
    }

    private func nochEinmalLesen() {
        guard let rohdaten else { return }
        do {
            let neu = try Spureinfuhr.lesen(rohdaten, name: dateiname, zone: zone,
                                            mindestabstand: werk.reise.gestaltung.mindestabstandSpur)
            befund = neu
            // Vorgewählt ist, was zum Buch passt: Eine Sicherung über ein
            // ganzes Jahr enthält dreihundert Tage, und von denen gehören
            // die wenigsten in diese Reise.
            let vorhandene = neu.tage.filter { imBuch($0.datum) }
            gewaehlt = Set((vorhandene.isEmpty ? neu.tage : vorhandene).map(\.id))
            fehler = nil
            zonenNachschlagen(neu)
        } catch {
            befund = nil
            gewaehlt = []
            fehler = error.localizedDescription
        }
    }

    // Das Nachschlagen läuft NACH dem Anzeigen: Die Vorschau steht damit
    // sofort da, und die Zonen tragen sich nach. Wer ohne Netz einliest,
    // bekommt trotzdem eine vollständige Vorschau — nur eben mit der
    // eingestellten Zone.
    private func zonenNachschlagen(_ roh: Spureinfuhr.Befund) {
        sucht = true
        Task {
            let fertig = await Spureinfuhr.ortszeitenSetzen(roh)
            await MainActor.run {
                // Nur übernehmen, wenn inzwischen keine andere Datei und
                // keine andere Zone gewählt wurde — eine späte Antwort darf
                // nicht den Stand von vorhin zurückbringen (dieselbe Regel
                // wie beim nachgetragenen Ortsnamen in der Abfahrtstafel).
                guard befund?.art == roh.art,
                      befund?.tage.map(\.id) == roh.tage.map(\.id) else { return }
                befund = fertig
                sucht = false
            }
        }
    }

    private func uebernehmen() {
        guard let befund else { return }
        let ausgewaehlt = befund.tage.filter { gewaehlt.contains($0.id) }
        let satz = werk.spurUebernehmen(ausgewaehlt, fehlendeAnlegen: fehlendeAnlegen)
        werk.meldung = .init(text: satz)
        schliessen()
    }
}
