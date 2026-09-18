import CoreLocation
import SwiftUI

/// Wohin eine Fahrt geöffnet wird. Als eigener Typ, weil
/// `navigationDestination(for:)` einen braucht — die Fahrtkennung allein
/// verlöre den Einstiegshalt, und ohne den weiß die Fahrtansicht nicht, welche
/// Zeile sie hervorheben soll.
struct Fahrtwunsch: Hashable {
    let fahrtId: String
    let einstieg: Haltestelle?
}

/// Die Abfahrtstafel — der Bildschirm, mit dem die App aufgeht.
///
/// Zwei Sichten auf dieselben Daten, umschaltbar:
///
/// - **Nach Haltestellen** (Vorgabe): je Haltestelle ein Abschnitt, die
///   nächste zuerst. So ist die Frage „von wo komme ich hier weg?"
///   beantwortet.
/// - **Nach Zeit**: alles in einer Liste. So ist die Frage „was fährt als
///   Nächstes?" beantwortet.
///
/// Beide aus einer einzigen Abfrage. Ein Umschalter, der nachlädt, wäre
/// langsamer und brächte nichts.
struct AbfahrtstafelView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var uhr: Uhrwerk

    @AppStorage("tafelNachZeit") private var nachZeit = false
    @State private var pfad = NavigationPath()
    @State private var ortswahlOffen = false

    var body: some View {
        NavigationStack(path: $pfad) {
            VStack(spacing: 0) {
                Ortsleiste(oeffnen: { ortswahlOffen = true })

                if !model.vorhandeneMittel.isEmpty {
                    Filterleiste()
                }

                if let meldung = model.meldung {
                    Meldungsband(text: meldung) { model.meldung = nil }
                }

                inhalt
            }
            .navigationTitle("Abfahrten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Sicht", selection: $nachZeit) {
                        Label("Nach Haltestellen", systemImage: "mappin.and.ellipse").tag(false)
                        Label("Nach Zeit", systemImage: "clock").tag(true)
                    }
                    .pickerStyle(.menu)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.laden()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Abfahrten neu laden")
                }
            }
            .navigationDestination(for: Haltestelle.self) { halt in
                HaltestelleView(haltestelle: halt)
            }
            .navigationDestination(for: Fahrtwunsch.self) { wunsch in
                FahrtView(fahrtId: wunsch.fahrtId, einstiegsHaltestelle: wunsch.einstieg)
            }
            .sheet(isPresented: $ortswahlOffen) {
                OrtswahlView()
            }
            // Der Gegenpart zu `Notification.Name.ortswahlOeffnen`: Die
            // Hinweisfläche liegt tief in der Ansicht und darf das Blatt nicht
            // selbst öffnen — aufgemacht wird es hier, an der Wurzel.
            .onReceive(NotificationCenter.default.publisher(for: .ortswahlOeffnen)) { _ in
                ortswahlOffen = true
            }
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        switch model.stand {
        case .leer where model.punkt == nil:
            Standortlage()
        case .laedt:
            ProgressView("Abfahrten werden geholt …")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .fehler(let text, let ortswahlHilft):
            Hinweisflaeche(
                symbol: ortswahlHilft ? "mappin.slash" : "wifi.exclamationmark",
                titel: ortswahlHilft ? "Hier ist keine Haltestelle" : "Keine Abfahrten",
                text: text,
                knopf: ortswahlHilft ? "Anderen Ort wählen" : "Noch einmal versuchen",
                tat: {
                    if ortswahlHilft {
                        ortswahlOffen = true
                    } else {
                        model.laden()
                    }
                }
            )
        default:
            if model.gruppen.isEmpty {
                Hinweisflaeche(
                    symbol: "tram",
                    titel: "Hier fährt gerade nichts",
                    text: model.filter.isEmpty
                        ? "Im Umkreis von \(model.umkreis) m meldet der Fahrplandienst keine Abfahrten. Nachts und auf dem Land ist das kein Fehler — mit einem größeren Umkreis findet sich meist doch etwas."
                        : "Mit dem gesetzten Filter bleibt nichts übrig. Ohne Filter stehen \(model.abfahrten.count) Abfahrten in der Liste.",
                    knopf: model.filter.isEmpty ? "Umkreis auf \(naechsterUmkreis) m" : "Filter aufheben",
                    tat: {
                        if model.filter.isEmpty {
                            model.umkreis = naechsterUmkreis
                            model.laden()
                        } else {
                            model.filter = []
                        }
                    }
                )
            } else {
                liste
            }
        }
    }

    private var naechsterUmkreis: Int {
        min(model.umkreis * 2, 3000)
    }

    private var liste: some View {
        List {
            if nachZeit {
                Section {
                    ForEach(model.nachZeit) { abfahrt in
                        zeile(abfahrt, mitHaltestelle: true)
                    }
                } footer: {
                    Fusszeile()
                }
            } else {
                ForEach(model.gruppen) { gruppe in
                    Section {
                        ForEach(gruppe.abfahrten.prefix(6)) { abfahrt in
                            zeile(abfahrt, mitHaltestelle: false)
                        }
                        if gruppe.abfahrten.count > 6 {
                            NavigationLink(value: gruppe.haltestelle) {
                                Label(
                                    "Alle \(gruppe.abfahrten.count) Abfahrten",
                                    systemImage: "list.bullet"
                                )
                                .font(.footnote)
                            }
                        }
                    } header: {
                        Gruppenkopf(gruppe: gruppe)
                    } footer: {
                        if gruppe.id == model.gruppen.last?.id {
                            Fusszeile()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { model.laden() }
    }

    /// Eine Zeile — als Verweis, WENN es einen Fahrtlauf dazu gibt.
    ///
    /// Nicht jede Quelle liefert eine Fahrtkennung (die EFA-Schnittstellen der
    /// Verbünde geben eine Tafel heraus und keinen Lauf). Eine Zeile, die aussieht
    /// wie ein Knopf und beim Tippen nichts tut, ist für den Menschen davor
    /// ein kaputter Knopf — solche Zeilen stehen deshalb ohne Pfeil da.
    @ViewBuilder
    private func zeile(_ abfahrt: Abfahrt, mitHaltestelle: Bool) -> some View {
        let inhalt = AbfahrtsZeile(
            abfahrt: abfahrt,
            jetzt: uhr.jetzt,
            zeigtHaltestelle: mitHaltestelle,
            standIstAlt: model.standIstAlt,
            zeigtQuelle: model.beteiligteQuellen.count > 1
        )
        if abfahrt.hatFahrtlauf {
            NavigationLink(value: Fahrtwunsch(fahrtId: abfahrt.fahrtId, einstieg: abfahrt.haltestelle)) {
                inhalt
            }
        } else {
            inhalt
        }
    }

    /// Kopf eines Haltestellenabschnitts: Name, Entfernung, Merken.
    private struct Gruppenkopf: View {
        let gruppe: Haltestellengruppe
        @EnvironmentObject private var merkliste: Merkliste

        var body: some View {
            HStack(spacing: 8) {
                NavigationLink(value: gruppe.haltestelle) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(gruppe.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        HStack(spacing: 5) {
                            Image(systemName: "figure.walk")
                            // „Luftlinie" steht ausdrücklich dabei: Die Zahl
                            // ist keine Gehstrecke, und wer sie für eine hält,
                            // verpasst den Bus.
                            Text("\(Haltestelle.entfernungstext(gruppe.entfernung)) Luftlinie")
                            if let gegend = gruppe.gegend {
                                Text("· \(gegend)")
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    merkliste.umschalten(gruppe.haltestelle)
                } label: {
                    Image(systemName: merkliste.istGemerkt(gruppe.haltestelle) ? "star.fill" : "star")
                        .foregroundStyle(merkliste.istGemerkt(gruppe.haltestelle) ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(merkliste.istGemerkt(gruppe.haltestelle) ? "Merken aufheben" : "Haltestelle merken")
            }
            .textCase(nil)
            .padding(.vertical, 2)
        }
    }

    /// Woher die Zahlen kommen und wie alt sie sind.
    private struct Fusszeile: View {
        @EnvironmentObject private var model: AppModel

        var body: some View {
            VStack(alignment: .leading, spacing: 3) {
                if let geholt = model.geholtUm {
                    if model.standIstAlt {
                        Text("Diese Zeiten sind von \(geholt.formatted(date: .omitted, time: .standard)) und zählen nicht weiter — sie kommen aus dem Zwischenspeicher, weil gerade keine Quelle erreichbar ist.")
                    } else {
                        Text("Zuletzt geholt um \(geholt.formatted(date: .omitted, time: .standard)).")
                    }
                }
                if !model.beteiligteQuellen.isEmpty {
                    Text("Daten: \(model.beteiligteQuellen.joined(separator: ", ")).")
                }
                Text("Entfernungen sind Luftlinien. Wo keine Echtzeit vorliegt, steht die Planzeit — die App behauptet dann keine Pünktlichkeit. Zeilen ohne Pfeil stammen aus einer Quelle, die keinen Fahrtlauf herausgibt.")
            }
            .font(.caption2)
        }
    }

    /// Was zu sehen ist, solange es keinen Bezugspunkt gibt.
    ///
    /// Eine Ortung, die abgelehnt wurde, ist kein Fehlerzustand: Es gibt den
    /// Weg über die Ortswahl, und der steht hier gleich daneben. Eine App, die
    /// an dieser Stelle nur „Zugriff verweigert" sagt, ist für jemanden ohne
    /// Ortung zu Ende.
    private struct Standortlage: View {
        @EnvironmentObject private var standort: Standortdienst
        @EnvironmentObject private var model: AppModel

        var body: some View {
            switch standort.stand {
            case .abgelehnt, .ausgeschaltet:
                Hinweisflaeche(
                    symbol: "location.slash",
                    titel: "Ohne Ortung geht es auch",
                    text: "Die App darf den Standort nicht lesen. Du kannst den Ausgangspunkt stattdessen von Hand wählen — über die Leiste ganz oben. Erlauben lässt sich die Ortung in den Einstellungen des Geräts.",
                    knopf: "Ort wählen",
                    tat: { NotificationCenter.default.post(name: .ortswahlOeffnen, object: nil) }
                )
            default:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Der Standort wird gesucht …")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Stattdessen einen Ort wählen") {
                        NotificationCenter.default.post(name: .ortswahlOeffnen, object: nil)
                    }
                    .font(.footnote)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

extension Notification.Name {
    /// Der Weg von einer tief liegenden Ansicht zum Blatt an der Wurzel.
    ///
    /// Ein Blatt gehört an die WURZEL und nicht in die Zeile, die es öffnet —
    /// dieselbe Lehre wie bei Tafelbilds Dateiwähler. Damit die Hinweisfläche
    /// es trotzdem aufmachen kann, geht sie diesen kurzen Weg.
    static let ortswahlOeffnen = Notification.Name("ortswahlOeffnen")
}

/// Die Leiste ganz oben: worauf sich die Tafel bezieht — und ein Tipp darauf
/// ändert es.
///
/// Sie steht IMMER da, auch beim eigenen Standort. Ein Bezugspunkt, der nur
/// sichtbar wird, wenn er vom Standort abweicht, lässt niemanden wissen, dass
/// er sich ändern lässt.
private struct Ortsleiste: View {
    let oeffnen: () -> Void

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var standort: Standortdienst

    var body: some View {
        HStack(spacing: 10) {
            Button(action: oeffnen) {
                HStack(spacing: 7) {
                    Image(systemName: model.punkt?.symbol ?? "location.magnifyingglass")
                    Text(model.punkt?.beschriftung ?? "Ort wählen")
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.secondary.opacity(0.14)))
            }
            .buttonStyle(.plain)

            if let punkt = model.punkt, !punkt.istEigenerStandort {
                Button {
                    if case .da(let hier) = standort.stand {
                        model.zurueckZumStandort(hier)
                    } else {
                        standort.anfangen()
                    }
                } label: {
                    Label("Zurück zu mir", systemImage: "location.fill")
                        .labelStyle(.iconOnly)
                        .padding(8)
                        .background(Circle().fill(Color.secondary.opacity(0.14)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zurück zum eigenen Standort")
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

/// Die Verkehrsmittel-Filter. Gezeigt werden nur die, die in den geladenen
/// Daten wirklich vorkommen — ein Haken für „Fähre" mitten im Bayerischen Wald
/// ist eine Bedienung, die nie etwas tut.
private struct Filterleiste: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(model.vorhandeneMittel) { mittel in
                    let an = model.filter.contains(mittel)
                    Button {
                        model.filterUmschalten(mittel)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: mittel.symbol)
                            Text(mittel.mehrzahl)
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(an ? mittel.rueckfallfarbe.opacity(0.9) : Color.secondary.opacity(0.13))
                        )
                        .foregroundStyle(an ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
                if !model.filter.isEmpty {
                    Button("Alle") { model.filter = [] }
                        .font(.caption)
                        .padding(.leading, 3)
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 7)
    }
}

#Preview {
    AbfahrtstafelView()
        .environmentObject(vorschaumodell())
        .environmentObject(Uhrwerk())
        .environmentObject(Standortdienst())
        .environmentObject(Merkliste())
}

@MainActor
private func vorschaumodell() -> AppModel {
    let model = AppModel(dienst: Musterdienst())
    model.ortWaehlen(name: "Marienplatz", koordinate: Musterdienst.marienplatz.koordinate)
    return model
}
