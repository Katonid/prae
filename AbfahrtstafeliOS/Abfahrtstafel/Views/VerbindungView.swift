import CoreLocation
import SwiftUI

/// Die Verbindungsauskunft: von hier nach dort, mit Alternativen.
///
/// Sie beantwortet die andere Hälfte der Frage, mit der man eine ÖPNV-App
/// öffnet. Die Tafel sagt, was hier wegfährt; dieser Bildschirm sagt, wie man
/// irgendwo hinkommt.
struct VerbindungView: View {
    @EnvironmentObject private var planer: Verbindungsmodell
    @EnvironmentObject private var standort: Standortdienst
    @EnvironmentObject private var uhr: Uhrwerk

    @State private var suchfeld: Suchfeld?

    /// Welches der beiden Felder gerade getippt wird. Als Aufzählung, weil
    /// beide dieselbe Vorschlagsliste benutzen und sie sonst zweimal im
    /// Quelltext stünde.
    enum Suchfeld: String, Identifiable {
        case start, ziel
        var id: String { rawValue }
        var titel: String { self == .start ? "Startpunkt" : "Ziel" }
    }

    /// Ob die Vergleichskarte offen ist. Sie liegt als Vollbild über allem
    /// und nicht als Blatt: Auf dem iPad wäre ein Blatt ein Kärtchen in der
    /// Mitte, und eine Karte lebt von Fläche — dieselbe Lehre wie beim
    /// Platz-Editor in Tafelbild.
    @State private var vergleichOffen = false

    private var standortKoordinate: CLLocationCoordinate2D? {
        if case .da(let hier) = standort.stand { return hier }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                eingabe
                Divider()
                inhalt
            }
            .navigationTitle("Verbindung")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Verbindung.self) { verbindung in
                VerbindungDetailView(verbindung: verbindung)
            }
            .fullScreenCover(isPresented: $vergleichOffen) {
                VergleichsKarte(verbindungen: planer.verbindungen)
            }
            // Auch von hier aus führt ein Weg zu einer Haltestelle: Der
            // Fahrtlauf eines Abschnitts zeichnet seine Halte auf die Karte,
            // und die sind seit 1.1.7 antippbar. Ohne dieses Ziel täte der
            // Verweis in DIESEM Stapel nichts — und ein Verweis, der nichts
            // tut, ist für den Menschen davor ein kaputter Knopf.
            .navigationDestination(for: Haltestelle.self) { halt in
                HaltestelleView(haltestelle: halt)
            }
            .navigationDestination(for: Fahrtwunsch.self) { wunsch in
                FahrtView(fahrtId: wunsch.fahrtId, einstiegsHaltestelle: wunsch.einstieg)
            }
            .sheet(item: $suchfeld) { feld in
                OrtssucheView(
                    titel: feld.titel,
                    nahe: planer.bezugFuerVorschlaege(standort: standortKoordinate),
                    darfStandort: feld == .start
                ) { treffer in
                    if feld == .start { planer.von = treffer } else { planer.nach = treffer }
                    suchfeld = nil
                    if planer.nach != nil { planer.suchen(standort: standortKoordinate) }
                }
            }
        }
    }

    // MARK: - Die beiden Felder

    private var eingabe: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                VStack(spacing: 6) {
                    feldknopf(
                        symbol: planer.von == nil ? "location.fill" : "smallcircle.filled.circle",
                        text: planer.startname(standortBekannt: standortKoordinate != nil),
                        blass: planer.von == nil && standortKoordinate == nil
                    ) { suchfeld = .start }

                    feldknopf(
                        symbol: "mappin.circle.fill",
                        text: planer.nach?.name ?? "Wohin?",
                        blass: planer.nach == nil
                    ) { suchfeld = .ziel }
                }

                Button {
                    planer.tauschen(standort: standortKoordinate)
                    if planer.nach != nil { planer.suchen(standort: standortKoordinate) }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.subheadline.weight(.semibold))
                        .padding(9)
                        .background(Circle().fill(Color.secondary.opacity(0.14)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start und Ziel tauschen")
            }

            Zeitleiste()

            HStack(spacing: 10) {
                // **Ein Schalter, kein Menüpunkt.** Wer ein
                // Deutschland-Ticket hat, stellt das einmal um und sieht
                // danach an der Leiste, dass es an ist. In einem Menü
                // versteckt wäre es ein Filter, den man vergisst — und dann
                // sähe eine kurze Liste nach einem schlechten Fahrplan aus.
                Toggle(isOn: $planer.nurDeutschlandTicket) {
                    Label("Deutschland-Ticket", systemImage: "ticket")
                        .font(.footnote)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .tint(planer.nurDeutschlandTicket ? .accentColor : .secondary)

                Spacer(minLength: 0)

                if planer.verbindungen.count > 1 {
                    Button {
                        vergleichOffen = true
                    } label: {
                        Label("Wege vergleichen", systemImage: "map")
                            .font(.footnote)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func feldknopf(
        symbol: String,
        text: String,
        blass: Bool,
        tat: @escaping () -> Void
    ) -> some View {
        Button(action: tat) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .foregroundStyle(.tint)
                Text(text)
                    .lineLimit(1)
                    .foregroundStyle(blass ? Color.secondary : Color.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.secondary.opacity(0.13))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ergebnis

    @ViewBuilder
    private var inhalt: some View {
        switch planer.stand {
        case .leer:
            Hinweisflaeche(
                symbol: "arrow.triangle.turn.up.right.diamond",
                titel: "Wohin soll es gehen?",
                text: "Tippe ein Ziel ein — von deinem Standort aus, oder von einem Startpunkt, den du selbst setzt. Vorgeschlagen werden zuerst Haltestellen in der Nähe.",
                knopf: "Ziel eingeben",
                tat: { suchfeld = .ziel }
            )
        case .laedt:
            ProgressView("Verbindungen werden gesucht …")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .fehler(let text, let zeitHilft):
            Hinweisflaeche(
                symbol: zeitHilft ? "clock.badge.exclamationmark" : "wifi.exclamationmark",
                titel: zeitHilft ? "Keine Verbindung um diese Zeit" : "Die Auskunft antwortet nicht",
                text: text,
                knopf: zeitHilft ? "Zeit ändern" : "Noch einmal versuchen",
                tat: {
                    if zeitHilft {
                        planer.abJetzt = false
                    } else {
                        planer.suchen(standort: standortKoordinate)
                    }
                }
            )
        case .da:
            List {
                Section {
                    ForEach(planer.verbindungen) { verbindung in
                        NavigationLink(value: verbindung) {
                            VerbindungsZeile(
                                verbindung: verbindung,
                                jetzt: uhr.jetzt,
                                laengsteDauer: planer.laengsteDauer,
                                mitTicketfilter: planer.nurDeutschlandTicket
                            )
                        }
                        .lesebreite()
                    }
                } footer: {
                    Fusszeile(
                        geholtUm: planer.geholtUm,
                        quellen: planer.beteiligteQuellen,
                        mitFilter: planer.nurDeutschlandTicket
                    )
                        .lesebreite()
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { planer.suchen(standort: standortKoordinate) }
        }
    }

    /// „Jetzt" oder ein Zeitpunkt — und dann ab oder an.
    private struct Zeitleiste: View {
        @EnvironmentObject private var planer: Verbindungsmodell
        @EnvironmentObject private var standort: Standortdienst

        var body: some View {
            HStack(spacing: 8) {
                Button {
                    planer.abJetzt.toggle()
                    if !planer.abJetzt { planer.zeitpunkt = Date() }
                    neuSuchen()
                } label: {
                    Label(planer.abJetzt ? "Jetzt" : (planer.alsAnkunft ? "Ankunft" : "Abfahrt"),
                          systemImage: "clock")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.secondary.opacity(0.14)))
                }
                .buttonStyle(.plain)

                if !planer.abJetzt {
                    DatePicker(
                        "Zeitpunkt",
                        selection: Binding(
                            get: { planer.zeitpunkt },
                            set: { planer.zeitpunkt = $0; neuSuchen() }
                        )
                    )
                    .labelsHidden()
                    .font(.caption)

                    Button {
                        planer.alsAnkunft.toggle()
                        neuSuchen()
                    } label: {
                        Text(planer.alsAnkunft ? "an" : "ab")
                            .font(.caption.weight(.bold))
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.accentColor.opacity(0.18)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(planer.alsAnkunft ? "Als Ankunftszeit — umschalten auf Abfahrt" : "Als Abfahrtszeit — umschalten auf Ankunft")
                }

                Spacer(minLength: 0)
            }
        }

        private func neuSuchen() {
            guard planer.nach != nil else { return }
            if case .da(let hier) = standort.stand {
                planer.suchen(standort: hier)
            } else {
                planer.suchen(standort: nil)
            }
        }
    }

    /// Woher die Auskunft kommt und wie alt sie ist.
    private struct Fusszeile: View {
        let geholtUm: Date?
        /// Die Quellen, die WIRKLICH beigetragen haben — nicht die
        /// eingebauten.
        let quellen: [String]
        /// Ob der Deutschland-Ticket-Filter an ist. Wird hereingereicht und
        /// nicht selbst nachgesehen: Eine verschachtelte Ansicht kennt das
        /// Modell der äußeren nicht, und ein `@EnvironmentObject` an dieser
        /// Stelle wäre ein zweiter Weg zu demselben Wert.
        let mitFilter: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 3) {
                if let geholtUm {
                    Text("Gesucht um \(geholtUm.formatted(date: .omitted, time: .standard)). Die Liste lädt sich NICHT von selbst nach — zum Auffrischen nach unten ziehen.")
                }
                if !quellen.isEmpty {
                    Text("Auskunft: \(quellen.joined(separator: ", ")).")
                }
                if mitFilter {
                    Text("Der Filter zeigt nur Verbindungen ohne Fernzug, Fernbus und Nachtzug — das, was ein Deutschland-Ticket abdeckt. Ausnahmen einzelner Linien stehen in keiner Quelle; Fähren bleiben außen vor, weil sich nicht unterscheiden lässt, welche zum Nahverkehr gehören.")
                    Text("Führt eine Verbindung über die Grenze, steht das an ihrer Zeile. Ob das Deutschland-Ticket dort noch gilt, sagt eine kurze, von Hand gepflegte Liste bekannter Grenzabschnitte — ein maschinenlesbares Verzeichnis dafür gibt es nicht. Die Liste ist also eine Gedächtnisstütze und keine Fahrkartenauskunft.")
                }
                Text("Der Balken unter jeder Verbindung zeigt ihre Dauer im Verhältnis zur längsten dieser Liste. Die farbigen Stücke sind die Fahrten, die blassen dazwischen die Wartezeit — verglichen wird die Länge, nicht die Uhrzeit.")
                Text("Fußwege sind gerechnete Wege, keine gemessenen; die Gehzeit hängt davon ab, wie schnell jemand geht. Wo keine Echtzeit vorliegt, steht „Plan“ — die App behauptet dann nichts über Pünktlichkeit.")
            }
            .font(.caption2)
        }
    }
}

#Preview {
    VerbindungView()
        .environmentObject(Verbindungsmodell(dienst: Musterdienst()))
        .environmentObject(Standortdienst())
        .environmentObject(Uhrwerk())
}
