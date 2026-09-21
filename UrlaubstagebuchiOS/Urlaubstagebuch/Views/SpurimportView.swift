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

            if befund.gerechneteTage > 0 {
                Section {
                    Picker("Zeitzone", selection: $zone) {
                        ForEach(zonen, id: \.identifier) { eine in
                            Text(eine.identifier).tag(eine)
                        }
                    }
                    .onChange(of: zone) { _, _ in nochEinmalLesen() }
                } header: {
                    Text("Zeitzone")
                } footer: {
                    Text("Bei \(befund.gerechneteTage) von \(befund.tage.count) Tagen "
                         + "steht der Tag nicht in der Datei; er wird aus dem "
                         + "Zeitstempel gerechnet. Eine Wanderung, die um 23:40 "
                         + "Ortszeit endet, landet mit der falschen Zone im falschen "
                         + "Tagebucheintrag.")
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
        } catch {
            befund = nil
            gewaehlt = []
            fehler = error.localizedDescription
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
