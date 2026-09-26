import SwiftUI
import CoreData

/// Die Tagebücher im Überblick (ab 1.0.8): jedes mit Farbe, Zahl der
/// Einträge und Zeitraum. Ein Tipp schaltet es ein oder aus (ab 1.0.9 —
/// vorher zeigte ein Tipp NUR dieses eine, und mehrere zugleich gingen nicht),
/// der Pinsel daneben ändert Farbe und Namen.
///
/// Bis 1.0.7 gab es die Tagebücher nur als Zeilen in einem Filtermenü —
/// „weitgehend verschwunden“, wie der Nutzer schrieb. Hier stehen sie als
/// eigene Dinge da.
struct TagebuecherView: View {
    /// Ausgeblendete Tagebücher; "" steht für „ohne Tagebuch“.
    @Binding var ausgeblendet: Set<String>
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
    /// Pinsel an einem gesperrten Tagebuch: erst das Passwort, dann die
    /// Einstellungen. Sonst ließe sich über „Schutz entfernen“ jedes Schloss
    /// ohne Passwort abnehmen.
    @State private var vorBearbeiten: Info?
    @State private var entsperren: String?
    /// Ein Tagebuch sichern (ab 1.0.22) — lange drücken → „Sichern …".
    @State private var sichern: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    zeile(titel: "Alle zeigen", unter: "\(eintraege.count) Einträge",
                          symbol: "books.vertical.fill", farbe: Palette.meer.haupt,
                          gewaehlt: ausgeblendet.isEmpty) {
                        ausgeblendet = []
                    }
                }
                Section {
                    ForEach(infos) { i in
                        HStack(spacing: 0) {
                            zeile(titel: i.name, unter: unterzeile(i), symbol: "book.closed.fill",
                                  farbe: buecherei.buchfarbe(i.name).farbe, gewaehlt: !ausgeblendet.contains(i.name),
                                  schloss: schlossstand(i.name)) {
                                umschalten(i.name)
                            }
                            .contextMenu {
                                Button { nurDieses(i.name) } label: {
                                    Label("Nur dieses zeigen", systemImage: "eye")
                                }
                                Button { sichern = i.name } label: {
                                    Label("Sichern …", systemImage: "externaldrive.badge.plus")
                                }
                                if buecherei.istGesperrt(i.name) {
                                    Button { entsperren = i.name } label: {
                                        Label("Öffnen", systemImage: "lock.open")
                                    }
                                } else if buecherei.istGeschuetzt(i.name) {
                                    Button { buecherei.sperren(i.name) } label: {
                                        Label("Wieder sperren", systemImage: "lock")
                                    }
                                }
                            }
                            Button {
                                if buecherei.istGesperrt(i.name) { vorBearbeiten = i } else { bearbeiten = i }
                            } label: {
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
                              farbe: .secondary, gewaehlt: !ausgeblendet.contains("")) {
                            umschalten("")
                        }
                    }
                } header: {
                    Text("Tagebücher")
                } footer: {
                    Text(infos.isEmpty
                         ? "Noch kein Tagebuch. Beim Schreiben eines Eintrags lässt sich oben eines anlegen — oder du übernimmst deine Tagebücher aus Day One (Einstellungen)."
                         : "Mit Häkchen steht ein Tagebuch in deiner Liste, ohne Häkchen ist es ausgeblendet — ein Tipp schaltet um. Lange drücken zeigt nur dieses eine. Mit dem Pinsel wählst du Farbe, Namen und ein Passwort; sie gelten auf all deinen Geräten, die Auswahl nur auf diesem. Ein Tagebuch mit Schloss steht in der Liste als gesperrte Karten, bis du es öffnest.")
                }
            }
            .navigationTitle("Tagebücher")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } }
                if !buecherei.offen.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { buecherei.alleSperren() } label: {
                            Label("Alle sperren", systemImage: "lock.fill")
                        }
                    }
                }
            }
            .sheet(item: $vorBearbeiten) { i in
                EntsperrBlatt(name: i.name) {
                    // Einen Durchgang warten, bis das Blatt weg ist — sonst
                    // verschluckt der Stapel den Schritt.
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        bearbeiten = i
                    }
                }
            }
            .sheet(item: Binding(get: { entsperren.map(Entsperrwunsch.init) },
                                 set: { entsperren = $0?.name })) { w in
                EntsperrBlatt(name: w.name)
            }
            .sheet(item: Binding(get: { sichern.map(Entsperrwunsch.init) },
                                 set: { sichern = $0?.name })) { w in
                SicherungView(vorgabe: .tagebuch(w.name))
            }
            .navigationDestination(item: $bearbeiten) { i in
                BuchBearbeiten(name: i.name) { neu in
                    // Ausgeblendet bleibt ausgeblendet, auch unter neuem Namen.
                    if ausgeblendet.remove(i.name) != nil { ausgeblendet.insert(neu) }
                }
            }
            .task(id: eintraege.map { $0.tagebuch ?? "" }.joined(separator: "\u{1F}")) { zaehlen() }
        }
    }

    private struct Entsperrwunsch: Identifiable {
        let name: String
        var id: String { name }
    }

    /// nil = kein Schloss, true = zu, false = offen.
    private func schlossstand(_ name: String) -> Bool? {
        buecherei.istGeschuetzt(name) ? buecherei.istGesperrt(name) : nil
    }

    private func umschalten(_ name: String) {
        if ausgeblendet.contains(name) { ausgeblendet.remove(name) } else { ausgeblendet.insert(name) }
    }

    private func nurDieses(_ name: String) {
        var alle = Set(infos.map(\.name))
        if ohneTagebuch > 0 { alle.insert("") }
        alle.remove(name)
        ausgeblendet = alle
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
                       gewaehlt: Bool, schloss: Bool? = nil, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).fill(farbe.opacity(0.18))
                    Image(systemName: symbol).foregroundStyle(farbe)
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(titel).font(.headline).foregroundStyle(.primary)
                        if let schloss {
                            Image(systemName: schloss ? "lock.fill" : "lock.open.fill")
                                .font(.caption)
                                .foregroundStyle(schloss ? Color.secondary : Color.orange)
                                .accessibilityLabel(schloss ? "gesperrt" : "offen")
                        }
                    }
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
    @State private var schutz = false
    @State private var entfernenFragen = false

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

            passwortAbschnitt
        }
        .sheet(isPresented: $schutz) { SchutzBlatt(name: name) }
        .confirmationDialog("Passwort entfernen?", isPresented: $entfernenFragen, titleVisibility: .visible) {
            Button("Passwort entfernen", role: .destructive) { buecherei.schutzEntfernen(name) }
        } message: {
            Text("Die Einträge in „\(name)“ stehen danach offen da — auf all deinen Geräten.")
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if neuerName.isEmpty { neuerName = name } }
    }

    // MARK: - Passwort (ab 1.0.10)

    @ViewBuilder
    private var passwortAbschnitt: some View {
        Section {
            if buecherei.istGeschuetzt(name) {
                Label("Mit Passwort geschützt", systemImage: "lock.fill")
                Button("Passwort ändern …") { schutz = true }
                if let art = Biometrie.name {
                    Toggle("Auch mit \(art) öffnen", isOn: Binding(
                        get: { buecherei.darfBiometrie(name) },
                        set: { buecherei.biometrieSetzen(name, $0) }))
                }
                Button("Jetzt sperren") { buecherei.sperren(name); zurueck() }
                Button("Passwort entfernen", role: .destructive) { entfernenFragen = true }
            } else {
                Button { schutz = true } label: {
                    Label("Mit Passwort schützen …", systemImage: "lock")
                }
            }
        } header: {
            Text("Passwort")
        } footer: {
            Text(buecherei.istGeschuetzt(name)
                 ? "Beim Verlassen der App geht das Tagebuch von selbst wieder zu. Das Passwort gilt auf all deinen Geräten."
                 : "Gesperrt stehen die Einträge nur als verschlossene Karten da — ohne Titel, Text, Fotos und Ort —, bis du das Tagebuch mit dem Passwort öffnest.")
        }
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

/// Die Auswahl steht als JSON in den Voreinstellungen: Eine Liste mit einem
/// Trennzeichen könnte "" (ohne Tagebuch) nicht von „nichts“ unterscheiden.
enum Tagebuchfilter {
    static func lesen(_ text: String) -> Set<String> {
        guard let d = text.data(using: .utf8),
              let liste = try? JSONDecoder().decode([String].self, from: d) else { return [] }
        return Set(liste)
    }

    static func schreiben(_ menge: Set<String>) -> String {
        guard !menge.isEmpty,
              let d = try? JSONEncoder().encode(menge.sorted()) else { return "" }
        return String(decoding: d, as: UTF8.self)
    }
}
