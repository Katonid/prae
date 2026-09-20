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
            .fahrplanziele()
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
                Toggle(isOn: $planer.filter.nurDeutschlandTicket) {
                    Label("Deutschland-Ticket", systemImage: "ticket")
                        .font(.footnote)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .tint(planer.filter.nurDeutschlandTicket ? .accentColor : .secondary)

                Fusswegknopf()

                // **Ersatzverkehr ausschließen** (ab 1.1.31). Sichtbar in der
                // Leiste und nicht im Menü, aus demselben Grund wie der
                // Ticketschalter: Ein Filter, den man vergisst, lässt eine
                // kurze Liste wie einen schlechten Fahrplan aussehen.
                Toggle(isOn: $planer.filter.ohneErsatzverkehr) {
                    Label("Ohne Ersatzverkehr", systemImage: "arrow.triangle.swap")
                        .font(.footnote)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .tint(planer.filter.ohneErsatzverkehr ? .accentColor : .secondary)

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

            Mittelleiste()
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
                                mitTicketfilter: planer.filter.nurDeutschlandTicket
                            )
                        }
                        .lesebreite()
                    }
                } footer: {
                    Fusszeile(
                        geholtUm: planer.geholtUm,
                        quellen: planer.beteiligteQuellen,
                        filter: planer.filter
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

    /// Wie weit höchstens zu Fuß — als Menü mit festen Stufen.
    ///
    /// **Ein Menü und kein Schieberegler.** Eine Grenze auf den Meter genau
    /// einzustellen täuschte eine Genauigkeit vor, die es nicht gibt: Die
    /// gezeigte Länge ist der Weg, den der Dienst gerechnet hat, nicht der,
    /// den jemand wirklich geht. Und ein Regler in einer schmalen Leiste
    /// trifft ohnehin niemand.
    ///
    /// **Der eingestellte Wert steht AUF dem Knopf**, nicht nur im Menü
    /// dahinter. Ein Filter, den man nur beim Aufklappen sieht, ist ein
    /// Filter, den man vergisst — und dann sähe eine kurze Liste nach einem
    /// schlechten Fahrplan aus. Dieselbe Regel wie beim Ticketschalter
    /// daneben.
    private struct Fusswegknopf: View {
        @EnvironmentObject private var planer: Verbindungsmodell

        var body: some View {
            Menu {
                ForEach(Verbindungsfilter.fussweggrenzen.indices, id: \.self) { stelle in
                    let grenze = Verbindungsfilter.fussweggrenzen[stelle]
                    Button {
                        planer.filter.hoechsterFussweg = grenze
                    } label: {
                        if planer.filter.hoechsterFussweg == grenze {
                            Label(beschriftung(grenze), systemImage: "checkmark")
                        } else {
                            Text(beschriftung(grenze))
                        }
                    }
                }
            } label: {
                Label(beschriftung(planer.filter.hoechsterFussweg), systemImage: "figure.walk")
                    .font(.footnote)
            }
            .buttonStyle(.bordered)
            .tint(planer.filter.hoechsterFussweg == nil ? .secondary : .accentColor)
            .accessibilityLabel("Höchstlänge eines Fußwegs")
        }

        private func beschriftung(_ grenze: Int?) -> String {
            guard let grenze else { return "Fußweg egal" }
            return "max. \(Haltestelle.entfernungstext(Double(grenze)))"
        }
    }

    /// Die Verkehrsmittel-Leiste der Auskunft.
    ///
    /// **Dieselbe Bedienung wie auf der Tafel, mit einem Unterschied, der
    /// dazugesagt gehört:** Dort filtert sie, was schon geladen ist; hier
    /// geht sie in die ANFRAGE und löst eine neue Suche aus. Gemessen
    /// 20.09.2026 (München Hbf → Freising): ohne Filter kommen S-Bahn und
    /// Regionalzug, mit „Busse" eine vollständige Busverbindung über die
    /// Linie 635 — die wäre durch nachträgliches Aussieben nie erschienen.
    ///
    /// **Angeboten werden alle acht und nicht nur die vorkommenden.** Auf der
    /// Tafel steht nur, was in den geladenen Abfahrten wirklich fährt; hier
    /// gibt es vor der Suche noch gar keine Antwort, aus der sich das ablesen
    /// ließe. Ein Mittel, das an dieser Strecke nicht fährt, führt zu einer
    /// ehrlichen Auskunft („dafür findet die Suche nichts") und nicht zu
    /// einem stummen Knopf.
    private struct Mittelleiste: View {
        @EnvironmentObject private var planer: Verbindungsmodell

        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(Verbindungsfilter.waehlbare) { mittel in
                        Mittelkapsel(mittel: mittel, an: planer.filter.mittel.contains(mittel)) {
                            planer.filter.umschalten(mittel)
                        }
                    }
                    if !planer.filter.mittel.isEmpty {
                        // **Ein Weg zurück, und er ist sichtbar.** Ohne ihn
                        // müsste man sich merken, welche Kapseln man
                        // angetippt hat.
                        Button("Alle") { planer.filter.mittel = [] }
                            .font(.caption)
                            .padding(.leading, 3)
                    }
                }
                // Der Rand liegt INNEN und wird außen wieder abgezogen: So
                // scrollt die Leiste von Bildschirmkante zu Bildschirmkante
                // wie die der Tafel, statt am Rand des Formulars abgeschnitten
                // zu werden. Die Leiste wird damit beliebig schmal — ein
                // eigenes Layout für kleine Geräte braucht es nicht.
                .padding(.horizontal, 14)
            }
            .padding(.horizontal, -14)
        }
    }

    /// Woher die Auskunft kommt und wie alt sie ist.
    private struct Fusszeile: View {
        let geholtUm: Date?
        /// Die Quellen, die WIRKLICH beigetragen haben — nicht die
        /// eingebauten.
        let quellen: [String]
        /// Der geltende Filter. Wird hereingereicht und nicht selbst
        /// nachgesehen: Eine verschachtelte Ansicht kennt das Modell der
        /// äußeren nicht, und ein `@EnvironmentObject` an dieser Stelle wäre
        /// ein zweiter Weg zu demselben Wert.
        let filter: Verbindungsfilter

        var body: some View {
            VStack(alignment: .leading, spacing: 3) {
                if let geholtUm {
                    Text("Gesucht um \(geholtUm.formatted(date: .omitted, time: .standard)). Die Liste lädt sich NICHT von selbst nach — zum Auffrischen nach unten ziehen.")
                }
                if !quellen.isEmpty {
                    Text("Auskunft: \(quellen.joined(separator: ", ")).")
                }
                if !filter.mittel.isEmpty {
                    Text("Gesucht wird nur nach \(filter.mittel.sorted { $0.rang < $1.rang }.map(\.mehrzahl).joined(separator: ", ")). Das steht schon in der ANFRAGE und nicht erst in der Liste: Wer erst hinterher aussiebt, bekommt oft gar nichts — der Dienst sucht sonst die schnellste Verbindung und gibt genau die zurück.")
                    Text("Eine Verbindung zählt nur, wenn ALLE ihre Fahrten passen; Fußwege zählen nicht mit. Und der Filter kennt die Art des Verkehrsmittels, nicht die Linie: RE und RB lassen sich nicht trennen — beide kommen aus der Quelle als derselbe Wert (gemessen 20.09.2026, dazu MEX und weitere Marken der Länderbahnen).")
                    Text("Steht auf einem Schild ein Bahnname wie \u{201E}RE1\u{201C} oder \u{201E}S1\u{201C}, obwohl nur Busse gesucht sind, ist das ein SCHIENENERSATZVERKEHR: Er behält den Namen und oft sogar die Farbe der Bahnlinie und ist doch ein Bus. Das Symbol links auf dem Schild sagt, was die Daten als Verkehrsmittel führen.")
                    Text("Nachgemessen am 21.09.2026: Die S1 braucht von Duisburg Hbf nach Großenbaum als Bahn 7 Minuten, als Bus nachts 20 — über Schlenk Bf und Buchholz Bf. Nur: Von 194 Busabschnitten an sechs Strecken schrieb ein EINZIGER Herausgeber seinen Ersatzverkehr auch hin (\u{201E}SEV RE 1\u{201C}). Wo der Satz dasteht, zeigt die App ihn unter der Zeile; wo er fehlt, sagt sie nichts dazu — eine Lücke ist besser als eine erfundene Erklärung.")
                }
                if filter.ohneErsatzverkehr {
                    Text("Verbindungen mit Schienenersatzverkehr sind ausgeblendet. Erkannt wird er auf zwei Wegen: Die Quelle nennt ihn selbst so (\u{201E}SEV RE 1\u{201C}) — oder ein BUS trägt den Namen einer Bahnlinie (RE, RB, S, U, IC, EC, RS, MEX mit Ziffer).")
                    Text("Gemessen am 21.09.2026 an 1559 Busabschnitten in 18 Städten: Das zweite Merkmal traf 130-mal, und jeder Treffer gehörte einem Bahnbetrieb; elf der 18 Linien ließen sich auf derselben Strecke als Schiene nachweisen, bei den übrigen gab die Schienenabfrage gar nichts her — so sieht eine gesperrte Strecke aus. Im Ausland kein einziger Fehltreffer.")
                    Text("Was der Filter NICHT findet: einen Ersatzverkehr unter gewöhnlicher Busnummer, und Kürzel, die sich nicht nachprüfen ließen (ÖBB \u{201E}SV190\u{201C}, DB \u{201E}EBU\u{201C}). Ein Feld dafür gibt es in diesen Daten nicht — der GTFS-Typ 714 kam in keinem einzigen Abschnitt vor. Gesiebt wird deshalb erst nach der Suche: Bleibt nichts übrig, ist das eine Aussage über den Filter, nicht über den Fahrplan.")
                }
                if let grenze = filter.hoechsterFussweg {
                    Text("Gesucht wird nur nach Verbindungen, bei denen der Weg zur ersten und der von der letzten Haltestelle höchstens \(Haltestelle.entfernungstext(Double(grenze))) lang ist. Ohne eigene Grenze lässt der Dienst rund einen Kilometer zu (gemessen).")
                    Text("Ein UMSTIEGSWEG mitten in der Verbindung fällt nicht darunter: Er steht als Fußpfad im Fahrplan und lässt sich beim Dienst nicht begrenzen. Und die Längen sind die gerechneten Wege des Dienstes — wie weit jemand wirklich läuft, hängt davon ab, wo der Zugang zum Bahnsteig liegt.")
                }
                if filter.nurDeutschlandTicket {
                    Text("Der Ticketfilter zeigt nur Verbindungen ohne Fernzug, Fernbus und Nachtzug — das, was ein Deutschland-Ticket abdeckt. Ausnahmen einzelner Linien stehen in keiner Quelle; Fähren bleiben außen vor, weil sich nicht unterscheiden lässt, welche zum Nahverkehr gehören.")
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
