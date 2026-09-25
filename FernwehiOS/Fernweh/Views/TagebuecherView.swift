import SwiftUI
import CoreData

/// Die Tagebücher im Überblick (ab 1.0.8): jedes mit Farbe, Zahl der
/// Einträge und Zeitraum. Ein Tipp zeigt nur dieses Tagebuch, der Pinsel
/// daneben ändert Farbe und Namen.
///
/// Bis 1.0.7 gab es die Tagebücher nur als Zeilen in einem Filtermenü —
/// „weitgehend verschwunden“, wie der Nutzer schrieb. Hier stehen sie als
/// eigene Dinge da.
struct TagebuecherView: View {
    @Binding var auswahl: String?
    @Environment(\.dismiss) private var schliessen
    @ObservedObject private var buecherei = Buecherei.shared

    @FetchRequest(fetchRequest: TagebuchView.alleEintraege()) private var eintraege: FetchedResults<Eintrag>

    struct Info: Identifiable {
        let name: String
        let anzahl: Int
        let erster: Date?
        let letzter: Date?
        var id: String { name }
    }

    /// In `.task` gerechnet, nicht im Körper — der Lauf geht über alle Einträge.
    @State private var infos: [Info] = []
    @State private var ohneTagebuch = 0
    @State private var bearbeiten: Info?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    zeile(titel: "Alle Einträge", unter: "\(eintraege.count) Einträge",
                          symbol: "books.vertical.fill", farbe: Palette.meer.haupt, gewaehlt: auswahl == nil) {
                        auswahl = nil; schliessen()
                    }
                }
                Section {
                    ForEach(infos) { i in
                        HStack(spacing: 0) {
                            zeile(titel: i.name, unter: unterzeile(i), symbol: "book.closed.fill",
                                  farbe: buecherei.buchfarbe(i.name).farbe, gewaehlt: auswahl == i.name) {
                                auswahl = i.name; schliessen()
                            }
                            Button { bearbeiten = i } label: {
                                Image(systemName: "paintbrush.pointed.fill")
                                    .font(.body)
                                    .foregroundStyle(buecherei.buchfarbe(i.name).farbe)
                                    .padding(.leading, 12)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Farbe und Namen ändern")
                        }
                    }
                    if ohneTagebuch > 0 {
                        zeile(titel: "Ohne Tagebuch", unter: "\(ohneTagebuch) Einträge", symbol: "minus.circle",
                              farbe: .secondary, gewaehlt: auswahl == "") {
                            auswahl = ""; schliessen()
                        }
                    }
                } header: {
                    Text("Tagebücher")
                } footer: {
                    Text(infos.isEmpty
                         ? "Noch kein Tagebuch. Beim Schreiben eines Eintrags lässt sich oben eines anlegen — oder du übernimmst deine Tagebücher aus Day One (Einstellungen)."
                         : "Ein Tipp zeigt nur dieses Tagebuch. Mit dem Pinsel wählst du seine Farbe — sie steht an jedem Eintrag und gilt auf all deinen Geräten.")
                }
            }
            .navigationTitle("Tagebücher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } }
            }
            .navigationDestination(item: $bearbeiten) { i in
                BuchBearbeiten(name: i.name) { neu in
                    if auswahl == i.name { auswahl = neu }
                }
            }
            .task(id: eintraege.map { $0.tagebuch ?? "" }.joined(separator: "\u{1F}")) { zaehlen() }
        }
    }

    private func zaehlen() {
        var jeName: [String: (Int, Date?, Date?)] = [:]
        var ohne = 0
        for e in eintraege {
            guard let n = e.tagebuchName else { ohne += 1; continue }
            var w = jeName[n] ?? (0, nil, nil)
            w.0 += 1
            if let d = e.datum {
                w.1 = min(w.1 ?? d, d)
                w.2 = max(w.2 ?? d, d)
            }
            jeName[n] = w
        }
        infos = jeName.map { Info(name: $0.key, anzahl: $0.value.0, erster: $0.value.1, letzter: $0.value.2) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        ohneTagebuch = ohne
    }

    private func unterzeile(_ i: Info) -> String {
        var s = i.anzahl == 1 ? "1 Eintrag" : "\(i.anzahl) Einträge"
        if let a = i.erster, let b = i.letzter { s += " · " + Tag.zeitraum(Tag.anfang(a), Tag.anfang(b)) }
        return s
    }

    private func zeile(titel: String, unter: String, symbol: String, farbe: Color,
                       gewaehlt: Bool, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).fill(farbe.opacity(0.18))
                    Image(systemName: symbol).foregroundStyle(farbe)
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel).font(.headline).foregroundStyle(.primary)
                    Text(unter).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if gewaehlt {
                    Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(farbe)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension TagebuecherView.Info: Hashable {
    static func == (a: Self, b: Self) -> Bool { a.name == b.name }
    func hash(into h: inout Hasher) { h.combine(name) }
}

/// Farbe und Namen eines Tagebuchs ändern.
private struct BuchBearbeiten: View {
    let name: String
    let umbenannt: (String) -> Void

    @ObservedObject private var buecherei = Buecherei.shared
    @Environment(\.dismiss) private var zurueck
    @State private var neuerName = ""
    @State private var meldung: String?

    private let spalten = [GridItem(.adaptive(minimum: 64), spacing: 14)]

    var body: some View {
        Form {
            Section("Farbe") {
                LazyVGrid(columns: spalten, spacing: 14) {
                    ForEach(Buchfarbe.allCases) { f in
                        let gewaehlt = buecherei.buchfarbe(name) == f
                        Button { buecherei.setzen(f, fuer: name) } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle().fill(f.farbe)
                                    if gewaehlt {
                                        Image(systemName: "checkmark").font(.headline.weight(.bold)).foregroundStyle(.white)
                                    }
                                }
                                .frame(width: 40, height: 40)
                                .overlay(Circle().strokeBorder(Color.primary.opacity(gewaehlt ? 0.5 : 0), lineWidth: 2).padding(-4))
                                Text(f.name).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(f.name + (gewaehlt ? ", gewählt" : ""))
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                TextField("Name", text: $neuerName)
                    .textInputAutocapitalization(.sentences)
                Button("Umbenennen") { umbenennen() }
                    .disabled(bereinigt.isEmpty || bereinigt == name)
                if let meldung {
                    Text(meldung).font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text("Name")
            } footer: {
                Text("Heißt schon ein anderes Tagebuch so, werden die beiden zusammengelegt. Einträge in Reisen, die du nur liest, behalten ihren Namen.")
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if neuerName.isEmpty { neuerName = name } }
    }

    private var bereinigt: String { neuerName.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func umbenennen() {
        let neu = bereinigt
        let ergebnis = buecherei.umbenennen(name, zu: neu)
        umbenannt(neu)
        if ergebnis.gesperrt > 0 {
            // Nicht still zurückspringen: Ein Teil ist geblieben, und das
            // soll dastehen.
            meldung = "\(ergebnis.umbenannt) Einträge umbenannt. \(ergebnis.gesperrt) stehen in Reisen, die du nur lesen darfst, und behalten „\(name)“."
        } else {
            zurueck()
        }
    }
}
