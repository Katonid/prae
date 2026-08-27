import SwiftUI
import UIKit
import UserNotifications

/// Einstellungen für Mitteilungen: welche Ereignisse, welche Ligen, welche
/// einzelnen Spiele.
struct Meldungssicht: View {
    @EnvironmentObject private var meldungen: Meldungsverwaltung
    @State private var freigeschaltete: [Spiel] = []

    var body: some View {
        Form {
            erlaubnisTeil
            artenTeil
            erinnerungsTeil
            ligenTeil
            spieleTeil
            nachrichtenartenTeil
            nachrichtenligenTeil
            quellenTeil
            erklaerungsTeil
        }
        .navigationTitle("Mitteilungen")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await meldungen.erlaubnisPruefen()
            freigeschaltete = bekannteSpiele()
        }
    }

    // MARK: Erlaubnis

    @ViewBuilder
    private var erlaubnisTeil: some View {
        Section {
            switch meldungen.erlaubnis {
            case .authorized, .provisional, .ephemeral:
                Label("iOS lässt Mitteilungen zu", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Gestaltung.rasen)
            case .denied:
                Hinweiszeile(text: "iOS blockt Mitteilungen für diese App. Das lässt sich nur in den Systemeinstellungen ändern.", ernst: true)
                Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                    Label("Einstellungen öffnen", systemImage: "gearshape")
                }
            default:
                Text("Damit etwas ankommt, braucht die App einmal deine Erlaubnis.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await meldungen.erlaubnisAnfragen() }
                } label: {
                    Label("Mitteilungen erlauben", systemImage: "bell.badge")
                }
            }
        } header: {
            Text("Erlaubnis")
        }
    }

    // MARK: Arten

    private var artenTeil: some View {
        Section {
            ForEach(Tickermeldung.Art.allCases) { art in
                Toggle(isOn: binding(fuer: art)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(art.name, systemImage: art.symbol)
                        Text(art.beschreibung)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Gestaltung.rasen)
            }
        } header: {
            Text("Wobei melden")
        } footer: {
            Text("Der freie Zugang von football-data.org liefert keine Karten mit. Der Schalter für Platzverweise bleibt trotzdem da — kommen die Daten eines Tages, greift er ohne Zutun.")
        }
    }

    private func binding(fuer art: Tickermeldung.Art) -> Binding<Bool> {
        Binding(
            get: { meldungen.wunsch.arten.contains(art) },
            set: { an in
                if an {
                    meldungen.wunsch.arten.insert(art)
                } else {
                    meldungen.wunsch.arten.remove(art)
                }
            }
        )
    }

    // MARK: Erinnerung

    private var erinnerungsTeil: some View {
        Section {
            Toggle(isOn: $meldungen.wunsch.anstosserinnerung) {
                Label("Vor dem Anpfiff erinnern", systemImage: "alarm")
            }
            .tint(Gestaltung.rasen)

            if meldungen.wunsch.anstosserinnerung {
                Stepper(value: $meldungen.wunsch.vorlaufMinuten, in: 5 ... 120, step: 5) {
                    HStack {
                        Text("Vorlauf")
                        Spacer()
                        Text("\(meldungen.wunsch.vorlaufMinuten) Minuten")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Anpfiff")
        } footer: {
            Text("Diese Erinnerung ist die einzige, die auf die Minute verlässlich ist: Die Anstoßzeit steht vorher fest, iOS stellt den Wecker selbst.")
        }
    }

    // MARK: Ligen

    private var ligenTeil: some View {
        Section {
            ForEach(Liga.allCases) { liga in
                Toggle(isOn: ligaBinding(liga)) {
                    HStack(spacing: 10) {
                        Text(liga.flagge)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(liga.name)
                            Text("Alle Spiele dieser Liga")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(Gestaltung.rasen)
            }
        } header: {
            Text("Ganze Ligen")
        } footer: {
            Text("Achtung: Eine ganze Liga bedeutet an einem Samstag schnell ein paar Dutzend Mitteilungen.")
        }
    }

    private func ligaBinding(_ liga: Liga) -> Binding<Bool> {
        Binding(
            get: { meldungen.wunsch.ganzeLigen.contains(liga) },
            set: { an in
                if an {
                    meldungen.wunsch.ganzeLigen.insert(liga)
                } else {
                    meldungen.wunsch.ganzeLigen.remove(liga)
                }
            }
        )
    }

    // MARK: Einzelne Spiele

    @ViewBuilder
    private var spieleTeil: some View {
        Section {
            if meldungen.wunsch.einzelneSpiele.isEmpty {
                Text("Noch kein einzelnes Spiel freigeschaltet. Die Glocke dafür sitzt in der Spielansicht.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(freigeschaltete) { spiel in
                    HStack(spacing: 10) {
                        Text(spiel.liga.flagge)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(spiel.heim.anzeige) – \(spiel.gast.anzeige)")
                                .font(.subheadline)
                            Text(Zeitformate.kurzdatum.string(from: spiel.anstoss)
                                 + ", " + Zeitformate.uhrzeit.string(from: spiel.anstoss) + " Uhr")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            meldungen.wunsch.einzelneSpiele.remove(spiel.id)
                            freigeschaltete.removeAll { $0.id == spiel.id }
                        } label: {
                            Image(systemName: "bell.slash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                }

                let unbekannt = meldungen.wunsch.einzelneSpiele.count - freigeschaltete.count
                if unbekannt > 0 {
                    Text("Dazu \(unbekannt) Spiele, deren Daten gerade nicht vorliegen.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Button(role: .destructive) {
                    meldungen.wunsch.einzelneSpiele.removeAll()
                    freigeschaltete = []
                } label: {
                    Label("Alle freigeschalteten Spiele entfernen", systemImage: "trash")
                }
            }
        } header: {
            Text("Einzelne Spiele")
        }
    }

    /// Namen zu den freigeschalteten Kennungen: Sie stehen im gesicherten
    /// Spielstand, den der Ticker ohnehin führt.
    private func bekannteSpiele() -> [Spiel] {
        let stand = Standspeicher.laden()
        return meldungen.wunsch.einzelneSpiele
            .compactMap { stand[$0] }
            .sorted { $0.anstoss < $1.anstoss }
    }

    // MARK: Ligameldungen — welche Arten

    private var nachrichtenartenTeil: some View {
        Section {
            ForEach(Nachrichtenart.allCases) { art in
                Toggle(isOn: nachrichtenartBinding(art)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(art.name, systemImage: art.symbol)
                        Text(art.beschreibung)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Gestaltung.rasen)
            }
        } header: {
            Text("Ligameldungen")
        } footer: {
            Text("Transfers und Gerüchte stehen nicht im Spieldatendienst — sie kommen aus den Nachrichtenquellen weiter unten. Welche Art eine Meldung hat, schätzt die App anhand der Wortwahl in Überschrift und Anriss. Das trifft meistens, aber nicht immer.")
        }
    }

    private func nachrichtenartBinding(_ art: Nachrichtenart) -> Binding<Bool> {
        Binding(
            get: { meldungen.wunsch.nachrichtenarten.contains(art) },
            set: { an in
                if an {
                    meldungen.wunsch.nachrichtenarten.insert(art)
                } else {
                    meldungen.wunsch.nachrichtenarten.remove(art)
                }
            }
        )
    }

    // MARK: Ligameldungen — welche Ligen

    private var nachrichtenligenTeil: some View {
        Section {
            ForEach(Liga.allCases) { liga in
                Toggle(isOn: nachrichtenligaBinding(liga)) {
                    HStack(spacing: 10) {
                        Text(liga.flagge)
                        Text(liga.name)
                    }
                }
                .tint(Gestaltung.rasen)
            }
            Toggle(isOn: $meldungen.wunsch.nachrichtenOhneLiga) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auch ohne erkennbare Liga")
                    Text("Sonst fällt weg, was sich keiner der fünf Ligen zuordnen lässt.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Gestaltung.rasen)
        } header: {
            Text("Ligameldungen — welche Ligen")
        } footer: {
            Text("Ist keine Liga angehakt, gelten alle fünf. Zugeordnet wird über die Schlagworte der Quelle und die Vereinsnamen, die die App aus den Tabellen kennt — je öfter du die Tabellen ansiehst, desto besser trifft das.")
        }
    }

    private func nachrichtenligaBinding(_ liga: Liga) -> Binding<Bool> {
        Binding(
            get: { meldungen.wunsch.nachrichtenligen.contains(liga) },
            set: { an in
                if an {
                    meldungen.wunsch.nachrichtenligen.insert(liga)
                } else {
                    meldungen.wunsch.nachrichtenligen.remove(liga)
                }
            }
        )
    }

    // MARK: Quellen

    private var quellenTeil: some View {
        Section {
            ForEach(Nachrichtenquelle.allCases) { quelle in
                Toggle(isOn: quellenBinding(quelle)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(quelle.name)
                        Text(quelle.beschreibung)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Gestaltung.rasen)
            }
        } header: {
            Text("Nachrichtenquellen")
        } footer: {
            Text("Frei zugängliche RSS-Ausgaben, kein Schlüssel nötig. Die App zeigt Überschrift und Anriss und verweist zum Lesen auf die Quelle; ganze Texte holt sie nicht. Abgefragt wird höchstens alle zehn Minuten.")
        }
    }

    private func quellenBinding(_ quelle: Nachrichtenquelle) -> Binding<Bool> {
        Binding(
            get: { meldungen.wunsch.nachrichtenquellen.contains(quelle) },
            set: { an in
                if an {
                    meldungen.wunsch.nachrichtenquellen.insert(quelle)
                } else {
                    meldungen.wunsch.nachrichtenquellen.remove(quelle)
                }
            }
        )
    }

    // MARK: Erklärung

    private var erklaerungsTeil: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Wie schnell das ankommt")
                    .font(.subheadline.weight(.semibold))
                Text("Die App hat keinen eigenen Server. Mitteilungen entstehen dort, wo sie den Spielstand vergleicht:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                punkt("Ist die Ticker-Ansicht offen, alle 45 Sekunden — praktisch sofort.")
                punkt("Ist die App geschlossen, immer dann, wenn iOS ihr eine Auffrischung im Hintergrund gewährt. Das sind je nach Gewohnheit eine Viertelstunde bis mehrere Stunden.")
                punkt("Nach dem Wegschieben aus dem App-Umschalter und im Stromsparmodus lässt iOS gar nichts zu.")
                punkt("Ligameldungen holt die App höchstens alle zehn Minuten — beim Öffnen der Meldungsliste und bei jeder Auffrischung im Hintergrund.")
                Text("Ein Tor kommt also verzögert an, nicht in dem Augenblick, in dem es fällt. Für den Anpfiff gilt das nicht — der wird als Wecker gestellt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func punkt(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
            Text(text)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
