import MapKit
import SwiftUI

/// Die Karte mit den Linienverläufen aller Linien, die hier verkehren.
///
/// Sie beantwortet eine andere Frage als die Liste: nicht „wann fährt was",
/// sondern **„wohin komme ich von hier"**. Auf dem iPad steht sie neben der
/// Liste — dort ist Breite da, und eine Abfahrtsliste, die sich über 2000
/// Punkte spannt, benutzt sie nicht, sie wird nur auseinandergezogen.
///
/// Gefiltert wird mit DERSELBEN Leiste wie die Liste (`AppModel.filter`): Wer
/// Busse ausblendet, sieht auch keine Buslinien auf der Karte. Zwei Filter für
/// dieselbe Frage wären zwei Antworten.
struct LiniennetzView: View {
    /// Ob diese Karte schon den ganzen Bildschirm füllt (ab 1.1.11). Sie
    /// zeichnet dann denselben Knopf andersherum — auf und zu ist EINE Sache
    /// und gehört an dieselbe Stelle.
    var imVollbild: Bool = false
    /// Aufziehen bzw. schließen. `nil` heißt „diese Karte lässt sich nicht
    /// umschalten" — dann steht auch kein Knopf da.
    var umschalten: (() -> Void)?

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var netz: Liniennetz
    @EnvironmentObject private var meldungen: Meldungsdienst

    /// Gebraucht für die Farbe der Linienkontur — sie muss die GEGENFARBE zur
    /// Karte sein, und welche das ist, weiß nur die Darstellungsart.
    @Environment(\.colorScheme) private var darstellung
    /// Die Karte darf seit 1.1.12 eine ANDERE Darstellung haben als die App.
    @AppStorage(Kartendarstellung.schluessel) private var kartenwahlRoh = Kartendarstellung.wieApp.rawValue

    @State private var kamera: MapCameraPosition = .automatic
    /// Welche Linie gerade hervorgehoben ist. `nil` heißt „alle gleich".
    @State private var hervorgehoben: String?
    /// Ob die Legende aufgeklappt ist.
    ///
    /// Auf einem iPhone deckt sie gut ein Viertel der Karte ab, und wer das
    /// Netz ansehen will, braucht genau diese Fläche (gemeldet 09/2026). Die
    /// Wahl steht in den Voreinstellungen und gilt beim nächsten Öffnen
    /// weiter — sie über die Ansicht zu halten hieße, sie bei jedem Wechsel
    /// zurückzusetzen. `@AppStorage` gehört dafür in eine VIEW und nie in eine
    /// `ObservableObject`-Klasse; hier ist es an seinem Platz.
    @AppStorage("linienLegendeOffen") private var legendeOffen = true
    /// Ob die Hinweise unter der Karte ausgeklappt sind. **Zu als Vorgabe**:
    /// Sie erklären die Zeichenweise, und die liest man einmal.
    @AppStorage("linienFusszeileOffen") private var fusszeileOffen = false

    var body: some View {
        VStack(spacing: 0) {
            karte
            fusszeile
        }
        .onAppear { aufbauen() }
        .onChange(of: model.abfahrten.count) { _, _ in aufbauen() }
        .onChange(of: model.filter) { _, _ in aufbauen() }
        .onChange(of: model.punkt) { _, _ in
            netz.leeren()
            aufbauen()
            kamera = .automatic
        }
    }

    /// Welche Darstellung die KARTE hat — die eigene Wahl, sonst die der App.
    /// Aufgelöst wird über `Kartendarstellung.geltend`, also über dieselbe
    /// Stelle, die auch `kartendarstellung()` benutzt: Zwei Fassungen liefen
    /// auseinander, und dann läge auf einer dunklen Karte eine weiße Kontur.
    private var kartenschema: ColorScheme {
        Kartendarstellung.geltend(kartenwahlRoh, wennWieApp: darstellung)
    }

    /// Die Farbe der Kontur unter einem Linienzug: dunkel auf heller Karte,
    /// hell auf dunkler. Nicht `Color.primary` — das ist die Farbe für
    /// SCHRIFT und wechselt zwar richtig, ist aber auf der dunklen Karte ein
    /// reines Weiß, das neben einer hellen Linie mehr blendet als trennt.
    private var konturfarbe: Color {
        kartenschema == .dark ? .black : .white
    }

    private func aufbauen() {
        netz.aufbauen(aus: model.nachZeit, dienst: model.dienst)
    }

    // MARK: - Karte

    private var karte: some View {
        Map(position: $kamera, interactionModes: [.pan, .zoom, .rotate]) {
            // **Erst alle Konturen, dann alle Linien** (ab 1.1.9). Zwei
            // Durchgänge, weil sonst die Kontur der einen Linie die andere
            // überdeckt, die schon gezeichnet ist.
            //
            // Warum es sie überhaupt gibt, ist gemessen (18.09.2026): Ein
            // dunkler Ton auf der dunklen Karte kommt auf ein
            // Kontrastverhältnis von 1,8:1, ein heller auf der hellen Karte
            // auf 2,0:1 — beides zu wenig, um einen Strich zu verfolgen. Das
            // galt schon vor der neuen Palette und für jede Farbe, die ein
            // Verbund selbst führt. Die Kontur ist das übliche Mittel der
            // Kartografie dagegen und hilft zugleich dort, wo sich zwei Züge
            // überlagern.
            ForEach(netz.zuege) { zug in
                MapPolyline(coordinates: zug.punkte)
                    .stroke(
                        konturfarbe.opacity(0.55 * deckkraft(zug)),
                        style: StrokeStyle(
                            lineWidth: (hervorgehoben == zug.id ? 7 : 4) + 3,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: zug.istLuftlinie ? [2, 7] : []
                        )
                    )
            }

            ForEach(netz.zuege) { zug in
                MapPolyline(coordinates: zug.punkte)
                    .stroke(
                        zug.linie.anzeigefarbe.opacity(deckkraft(zug)),
                        style: StrokeStyle(
                            lineWidth: hervorgehoben == zug.id ? 7 : 4,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: zug.istLuftlinie ? [2, 7] : []
                        )
                    )
            }

            // Die Halte der gezeichneten Linien.
            ForEach(sichtbareHalte) { halt in
                Annotation(halt.name, coordinate: halt.koordinate, anchor: .center) {
                    // **Ein Tipp öffnet die Tafel dieser Haltestelle.** Das
                    // Ziel ist dasselbe wie in der Liste nebenan — der
                    // `navigationDestination(for: Haltestelle.self)` steht in
                    // `AbfahrtstafelView`, in deren Stapel diese Karte liegt.
                    // Ein eigenes Blatt dafür wäre ein zweiter Weg zu
                    // derselben Ansicht und liefe irgendwann auseinander.
                    NavigationLink(value: halt.haltestelle) {
                        Linienhalt(
                            farbe: halt.farbe,
                            gross: halt.gross,
                            faelltAus: halt.faelltAus,
                            lautMeldungGesperrt: halt.lautMeldungGesperrt
                        )
                        .trefferflaeche()
                    }
                    .buttonStyle(.plain)
                }
                // Beschriftet nur, wenn EINE Linie hervorgehoben ist. Sonst
                // lägen dreihundert Haltestellennamen übereinander und die
                // Karte wäre unlesbar. Ein ENTFALLENDER Halt trägt seinen
                // Namen immer — es sind wenige, und sie sind die Auskunft.
                .annotationTitles(
                    hervorgehoben == nil && !halt.faelltAus && !halt.lautMeldungGesperrt
                        ? .hidden : .automatic
                )
            }

            // Die Liniennummer auf dem Zug selbst. Ohne sie ist die Karte ein
            // Bündel farbiger Striche, und die Legende am Rand zwingt zum
            // Hin- und Herschauen.
            ForEach(beschriftungen) { marke in
                Annotation("", coordinate: marke.punkt, anchor: .center) {
                    // Das Schild ist ein KNOPF und tut dasselbe wie die Zeile
                    // in der Legende. Ohne das wäre die zugeklappte Legende
                    // eine Sackgasse: Das Hervorheben — und damit die
                    // Haltestellennamen — hinge dann daran, sie wieder
                    // aufzuklappen.
                    Button {
                        hervorgehoben = (hervorgehoben == marke.id) ? nil : marke.id
                    } label: {
                        Liniensymbol(linie: marke.linie)
                            .opacity(hervorgehoben == nil || hervorgehoben == marke.id ? 1 : 0.25)
                            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                }
                .annotationTitles(.hidden)
            }

            // Die Haltestellen um den Bezugspunkt — die aus der Liste
            // nebenan. Sie stehen ÜBER den Linienhalten, weil sie die Frage
            // beantworten, mit der jemand die Karte öffnet.
            ForEach(model.gruppen) { gruppe in
                Annotation(gruppe.name, coordinate: gruppe.koordinate, anchor: .center) {
                    NavigationLink(value: gruppe.haltestelle) {
                        ZStack {
                            Circle().fill(.background).frame(width: 13, height: 13)
                            Circle().strokeBorder(.primary, lineWidth: 3).frame(width: 13, height: 13)
                        }
                        .shadow(color: .black.opacity(0.2), radius: 1.5, y: 0.5)
                        .trefferflaeche()
                    }
                    .buttonStyle(.plain)
                }
            }

            if let punkt = model.punkt {
                Annotation(punkt.beschriftung, coordinate: punkt.koordinate, anchor: .center) {
                    Image(systemName: punkt.symbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(Circle().fill(Color.accentColor))
                        .shadow(color: .black.opacity(0.28), radius: 3, y: 1)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        // **Ein Tipp auf die freie Kartenfläche zieht sie auf.** Die Halte und
        // die Liniennummern sind Knöpfe und behalten ihre eigene Aufgabe (ein
        // Tipp auf einen Halt öffnet seit 1.1.7 dessen Abfahrtstafel) — SwiftUI
        // gibt dem inneren Bedienelement den Vorrang. Der Knopf unten links tut
        // dasselbe und ist der Weg, den man SIEHT: Eine Geste, die niemand
        // kennt, ist so wenig wert wie ein Knopf, den niemand findet.
        .onTapGesture { umschalten?() }
        .overlay(alignment: .topTrailing) { legende }
        .overlay(alignment: .bottomLeading) { vollbildknopf }
        .overlay(alignment: .center) {
            if netz.laedt && netz.zuege.isEmpty {
                ProgressView("Linienverläufe werden geholt …")
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        // **Nach den Überlagerungen, nicht davor.** Eine Überlagerung wird
        // von AUSSEN an das fertige Bild gehängt und erbt die Umgebung des
        // äußeren Zusammenhangs — davor gesetzt bliebe die Legende hell auf
        // einer dunklen Karte. Die Legende liegt auf der Karte und gehört zu
        // ihr; die Fußzeile darunter gehört zur App und bleibt außen vor.
        .kartendarstellung()
        .onChange(of: netz.zuege.count) { _, _ in
            guard !netz.zuege.isEmpty else { return }
            kamera = .rect(ausschnitt)
        }
    }

    // MARK: - Was auf der Karte steht

    /// Ein Halt einer gezeichneten Linie.
    private struct Linienhaltpunkt: Identifiable {
        let id: String
        let name: String
        let koordinate: CLLocationCoordinate2D
        /// Die ganze Haltestelle und nicht nur ihr Name: Ein Tipp auf den
        /// Punkt öffnet ihre Tafel, und dafür braucht es die Kennung.
        let haltestelle: Haltestelle
        let farbe: Color
        let gross: Bool
        var faelltAus: Bool = false
        /// Aus dem TEXT einer Betriebsmeldung gelesen, nicht aus den
        /// Fahrplandaten — deshalb eigenes Feld und eigene Zeichnung.
        var lautMeldungGesperrt: Bool = false
    }

    /// **Wie viele Haltepunkte höchstens gezeichnet werden.**
    ///
    /// Eine Buslinie hat leicht sechzig Halte; zwölf Linien ergeben auch nach
    /// dem Zusammenlegen gemeinsamer Halte schnell dreihundert Punkte. Jeder
    /// davon ist in SwiftUI eine eigene Ansicht — ab einigen Hundert wird das
    /// Schieben der Karte zäh. Über der Grenze werden deshalb GAR KEINE
    /// gezeichnet und die Fußzeile sagt, wie man trotzdem an sie kommt: eine
    /// Linie antippen. Ein paar willkürlich ausgewählte zu zeigen wäre
    /// schlechter als keine — man hielte die Lücken für Wirklichkeit.
    private var hoechstzahlHalte: Int { 260 }

    private var sichtbareHalte: [Linienhaltpunkt] {
        let gesperrt = gesperrtJeLinie
        if let hervorgehoben, let zug = netz.zuege.first(where: { $0.id == hervorgehoben }) {
            // Eine Linie hervorgehoben: ihre Halte, und zwar alle. Das ist
            // der Fall, für den die Punkte gebaut sind.
            return zug.halte.enumerated().map { nummer, halt in
                Linienhaltpunkt(
                    id: "\(zug.id)#\(nummer)",
                    name: halt.haltestelle.name,
                    koordinate: halt.haltestelle.koordinate,
                    haltestelle: halt.haltestelle,
                    farbe: zug.linie.anzeigefarbe,
                    gross: nummer == 0 || nummer == zug.halte.count - 1,
                    faelltAus: halt.faelltAus,
                    lautMeldungGesperrt: gemeldet(halt.haltestelle.name, zug.linie, gesperrt)
                )
            }
        }

        var gesehen = Set<String>()
        var punkte: [Linienhaltpunkt] = []
        for zug in netz.zuege {
            for halt in zug.halte {
                guard gesehen.insert(halt.haltestelle.id).inserted else { continue }
                punkte.append(
                    Linienhaltpunkt(
                        id: halt.haltestelle.id,
                        name: halt.haltestelle.name,
                        koordinate: halt.haltestelle.koordinate,
                        haltestelle: halt.haltestelle,
                        farbe: zug.linie.anzeigefarbe,
                        gross: false,
                        faelltAus: halt.faelltAus,
                        lautMeldungGesperrt: gemeldet(halt.haltestelle.name, zug.linie, gesperrt)
                    )
                )
            }
        }
        // **Über der Grenze bleiben die entfallenden Halte stehen.** Weggelassen
        // wird nur das Gewöhnliche: Dreihundert Punkte machen die Karte zäh,
        // aber der eine durchgestrichene ist der Grund, aus dem jemand sie
        // aufschlägt. Ihn mit wegzuräumen hieße, die Umleitung genau dann zu
        // verschweigen, wenn viel los ist.
        if punkte.count > hoechstzahlHalte {
            return punkte.filter { $0.faelltAus || $0.lautMeldungGesperrt }
        }
        return punkte
    }

    private var zuVieleHalte: Bool {
        guard hervorgehoben == nil, !netz.zuege.isEmpty else { return false }
        return !sichtbareHalte.contains { !$0.faelltAus && !$0.lautMeldungGesperrt }
    }

    /// Je Linie die Haltestellennamen, die ihre Meldungen als entfallend
    /// aufzählen.
    ///
    /// **Einmal gebaut und dann nachgeschlagen.** Der erste Entwurf fragte
    /// das je Halt ab und baute diese Tabelle dabei jedes Mal neu — zwölf
    /// Linien mit je sechzig Halten wären siebenhundert Durchgänge durch
    /// die ganze Meldungsliste, bei JEDEM Neuzeichnen der Karte. Dieselbe
    /// Falle wie bei `Liniennetz.gebautAus`, nur eine Ebene tiefer.
    private var gesperrtJeLinie: [String: [String]] {
        var raus: [String: [String]] = [:]
        for zug in netz.zuege where raus[zug.linie.name] == nil {
            let namen = meldungen.gesperrteHalte(zu: zug.linie)
            if !namen.isEmpty { raus[zug.linie.name] = namen }
        }
        return raus
    }

    private func gemeldet(
        _ name: String,
        _ linie: Linienkennung,
        _ tabelle: [String: [String]]
    ) -> Bool {
        guard let namen = tabelle[linie.name] else { return false }
        return namen.contains { Haltsperrung.passt(haltestelle: name, zu: $0) }
    }

    private struct Liniennummer: Identifiable {
        let id: String
        let linie: Linienkennung
        let punkt: CLLocationCoordinate2D
    }

    /// Je Linie EINE Nummer auf der Karte.
    ///
    /// Gesetzt an einer Stelle, die sich mit der Position der Linie in der
    /// Liste verschiebt: Zwölf Linien, die im Stadtzentrum alle
    /// übereinanderliegen, hätten sonst zwölf Schilder auf demselben Fleck.
    /// So verteilen sie sich über den Verlauf.
    private var beschriftungen: [Liniennummer] {
        let anzahl = max(netz.zuege.count - 1, 1)
        return netz.zuege.enumerated().compactMap { nummer, zug in
            let anteil = 0.22 + 0.56 * (Double(nummer) / Double(anzahl))
            guard let punkt = zug.punkt(beiAnteil: anteil) else { return nil }
            return Liniennummer(id: zug.id, linie: zug.linie, punkt: punkt)
        }
    }

    /// Eine hervorgehobene Linie blendet die anderen zurück — sie verschwinden
    /// aber NICHT. Wer eine Linie verfolgt, will trotzdem sehen, wo sie die
    /// anderen kreuzt.
    private func deckkraft(_ zug: Linienzug) -> Double {
        guard let hervorgehoben else { return 0.85 }
        return zug.id == hervorgehoben ? 1.0 : 0.18
    }

    /// Auf- und Zuziehen der Karte. Steht unten links, also dort, wo weder die
    /// Legende (oben rechts) noch Apples eigene Bedienelemente liegen.
    @ViewBuilder
    private var vollbildknopf: some View {
        if let umschalten {
            Button(action: umschalten) {
                Image(systemName: imVollbild
                      ? "arrow.down.right.and.arrow.up.left"
                      : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(.regularMaterial, in: Circle())
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel(imVollbild ? "Karte schließen" : "Karte auf den ganzen Bildschirm")
        }
    }

    // MARK: - Legende

    @ViewBuilder
    private var legende: some View {
        if legendeOffen {
            VStack(alignment: .leading, spacing: 0) {
                legendenkopf
                if netz.zuege.isEmpty && !netz.laedt {
                    Text("Keine Linienverläufe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(netz.zuege) { zug in
                                Button {
                                    // Ein zweiter Tipp hebt die Hervorhebung wieder
                                    // auf. Ohne das käme man aus ihr nur über einen
                                    // weiteren Knopf heraus, den niemand sucht.
                                    hervorgehoben = (hervorgehoben == zug.id) ? nil : zug.id
                                } label: {
                                    HStack(spacing: 8) {
                                        // Das Verkehrsmittel steht als Symbol
                                        // daneben (ab 1.1.9). Seit die Farbe
                                        // eines Schildes ohne eigene Farbe der
                                        // UNTERSCHEIDUNG dient und nicht mehr
                                        // der Familie des Verkehrsmittels,
                                        // wäre es hier sonst gar nicht mehr
                                        // abzulesen — und die Legende ist die
                                        // Stelle, an der Linien nebeneinander
                                        // verglichen werden.
                                        Image(systemName: zug.linie.mittel.symbol)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 16)
                                        Liniensymbol(linie: zug.linie)
                                        Text(zug.richtung)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .foregroundStyle(.primary)
                                    }
                                    .opacity(hervorgehoben == nil || hervorgehoben == zug.id ? 1 : 0.4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                    }
                    .frame(maxHeight: 260)
                }
            }
            .frame(maxWidth: 230, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(10)
        } else {
            // Zugeklappt bleibt ein SICHTBARER Knopf stehen, kein leerer Rand.
            // Eine Legende, die sich spurlos zumacht, ist nicht wiederzufinden
            // — dieselbe Lehre wie beim Schloss des Sitzplans in Tafelbild.
            Button {
                legendeOffen = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                    Text("\(netz.zuege.count)")
                        .monospacedDigit()
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Legende einblenden")
            .padding(10)
        }
    }

    private var legendenkopf: some View {
        HStack(spacing: 6) {
            Text("Linien")
                .font(.caption.weight(.semibold))
            Spacer(minLength: 0)
            if hervorgehoben != nil {
                Button("Alle") { hervorgehoben = nil }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
            }
            Button {
                legendeOffen = false
            } label: {
                Image(systemName: "chevron.up")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Legende ausblenden")
        }
        .padding(.horizontal, 10)
        .padding(.top, 9)
        .padding(.bottom, 7)
    }

    // MARK: - Fußzeile

    /// Eine Zeile unter der Karte.
    private struct Hinweis: Identifiable {
        let id: String
        let symbol: String?
        let text: String
    }

    /// Die Hinweise, **nach Wichtigkeit**.
    ///
    /// Die Reihenfolge ist der ganze Trick: Zugeklappt steht nur der erste da,
    /// und das muss der sein, der etwas über die HEUTIGE Lage sagt — ein
    /// entfallender Halt, eine fehlende Linie. Die Erklärungen zur Zeichenweise
    /// gelten immer und sind deshalb zuletzt: Wer sie einmal gelesen hat,
    /// braucht sie nie wieder, und sie standen bis 1.0.8 trotzdem jedes Mal da.
    private var hinweise: [Hinweis] {
        var liste: [Hinweis] = []
        // Ganz vorn, denn hier steht das Konkreteste über heute: Diese
        // Halte nennt eine Meldung beim Namen, und in den Fahrplandaten
        // stehen sie unverändert als angefahren.
        let gemeldete = sichtbareHalte.filter(\.lautMeldungGesperrt)
        if !gemeldete.isEmpty {
            let namen = gemeldete.map(\.name).joined(separator: ", ")
            var text = "Laut Betriebsmeldung gesperrt (orange): " + namen
            text += ". Das steht im TEXT der Meldung, nicht in den Fahrplandaten"
            text += gemeldete.count == 1 ? "." : " — manche Meldungen gelten nur für eine Richtung."
            liste.append(Hinweis(
                id: "gemeldetGesperrt",
                symbol: "exclamationmark.triangle.fill",
                text: text
            ))
        }
        // Danach die Zeile, die eine
        // Auskunft über die HEUTIGE Lage schwächt: Wo eine Meldung gilt,
        // deren Änderungen nicht in den Fahrplandaten stehen, kann ein
        // gesperrter Halt auf dieser Karte als angefahren dastehen.
        let ungepflegt = netz.zuege
            .filter { !meldungen.nichtImFahrplan(zu: $0.linie).isEmpty }
            .map(\.linie.name)
        if !ungepflegt.isEmpty {
            let namen = Set(ungepflegt).sorted().joined(separator: ", ")
            liste.append(Hinweis(
                id: "ungepflegt",
                symbol: "arrow.triangle.branch",
                text: "Zu \(namen) liegt eine Meldung vor, deren Änderungen NICHT im Fahrplan stehen. Gezeichnet ist deshalb der Planweg — eine gesperrte Haltestelle kann hier als angefahren erscheinen."
            ))
        }
        if netz.entfallendeHalte > 0 {
            liste.append(Hinweis(
                id: "entfallen",
                symbol: "arrow.triangle.branch",
                text: netz.entfallendeHalte == 1
                    ? "Ein Halt entfällt heute (rot durchgestrichen). Der gezeichnete Linienweg bleibt der PLANMÄSSIGE — welchen Weg das Fahrzeug stattdessen fährt, gibt keine Quelle heraus."
                    : "\(netz.entfallendeHalte) Halte entfallen heute (rot durchgestrichen). Die gezeichneten Linienwege bleiben die PLANMÄSSIGEN — welchen Weg die Fahrzeuge stattdessen fahren, gibt keine Quelle heraus."
            ))
        }
        if netz.ohneVerlauf > 0 {
            liste.append(Hinweis(
                id: "ohneVerlauf",
                symbol: "exclamationmark.triangle",
                text: netz.ohneVerlauf == 1
                    ? "Eine Linie fehlt auf der Karte: Ihre Quelle gibt keinen Linienverlauf heraus."
                    : "\(netz.ohneVerlauf) Linien fehlen auf der Karte: Ihre Quelle gibt keinen Linienverlauf heraus."
            ))
        }
        if netz.zuege.contains(where: \.istLuftlinie) {
            liste.append(Hinweis(
                id: "luftlinie",
                symbol: nil,
                text: "Gestrichelte Linien sind Luftlinien zwischen den Halten — für sie kam keine Streckenführung mit."
            ))
        }
        if zuVieleHalte {
            liste.append(Hinweis(
                id: "halte",
                symbol: nil,
                text: "Zu viele Halte für die Übersicht — eine Liniennummer antippen (auf der Karte oder in der Legende) zeigt die Haltestellen dieser Linie mit Namen."
            ))
        } else if hervorgehoben == nil {
            liste.append(Hinweis(
                id: "halte",
                symbol: nil,
                text: "Die kleinen Punkte sind die Halte der gezeichneten Linien. Eine Liniennummer antippen — auf der Karte oder in der Legende — zeigt ihre Halte mit Namen."
            ))
        }
        // **Ein Weg, den niemand sieht, ist keiner.** Der Punkt sieht nicht
        // aus wie ein Knopf, und genau deshalb steht dieser Satz da —
        // dieselbe Lehre wie beim Gruppenchat in Schulalarm und beim
        // Sichtumschalter in 1.0.5. Er steht VOR den Erklärungen zur
        // Zeichenweise: Er sagt, was man tun kann, die anderen nur, was man
        // sieht.
        if !zuVieleHalte || hervorgehoben != nil {
            liste.append(Hinweis(
                id: "haltAntippen",
                symbol: "hand.tap",
                text: "Ein Tipp auf einen Halt öffnet seine Abfahrtstafel — mit allem, was dort sonst noch wegfährt."
            ))
        }
        if !legendeOffen {
            liste.append(Hinweis(
                id: "legende",
                symbol: nil,
                text: "Die Legende ist ausgeblendet; der Knopf oben rechts auf der Karte holt sie zurück."
            ))
        }
        liste.append(Hinweis(
            id: "zeichenweise",
            symbol: nil,
            text: "Je Linie ist ein Lauf gezeichnet; die Gegenrichtung fährt denselben Weg zurück. Höchstens zwölf Linien. Führt der Verbund eine Linienfarbe, gilt seine. Sonst bekommt die Linie eine Farbe, die sie nur von den anderen unterscheidet — sie sagt dann nichts über das Verkehrsmittel; das steht als Symbol in der Legende."
        ))
        return liste
    }

    /// Die Fußzeile — zugeklappt EINE Zeile, aufgeklappt alle.
    ///
    /// Bis 1.0.8 standen hier bis zu sechs Absätze untereinander und nahmen auf
    /// einem iPhone die halbe Karte weg (gemeldet 09/2026: „Der Text verdeckt
    /// einen großen Teil der Darstellung."). Das Missverhältnis ist der Punkt:
    /// Die Erklärungen sind wichtig — aber einmal, nicht bei jedem Blick. Die
    /// Karte ist das, wofür jemand diesen Bildschirm öffnet.
    private var fusszeile: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(fusszeileOffen ? hinweise : Array(hinweise.prefix(1))) { hinweis in
                    if let symbol = hinweis.symbol {
                        Label(hinweis.text, systemImage: symbol)
                            .lineLimit(fusszeileOffen ? nil : 2)
                    } else {
                        Text(hinweis.text)
                            .lineLimit(fusszeileOffen ? nil : 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if hinweise.count > 1 {
                Button {
                    withAnimation(.snappy) { fusszeileOffen.toggle() }
                } label: {
                    HStack(spacing: 3) {
                        if !fusszeileOffen {
                            Text("\(hinweise.count)")
                                .monospacedDigit()
                        }
                        Image(systemName: fusszeileOffen ? "chevron.down" : "chevron.up")
                    }
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.secondary.opacity(0.16)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(fusszeileOffen ? "Hinweise einklappen" : "Alle \(hinweise.count) Hinweise zeigen")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }

    /// Der Ausschnitt, der alle gezeichneten Linien zeigt.
    private var ausschnitt: MKMapRect {
        let punkte = netz.zuege.flatMap(\.punkte)
        guard let erster = punkte.first else { return MKMapRect.world }
        var rahmen = MKMapRect(origin: MKMapPoint(erster), size: MKMapSize(width: 0, height: 0))
        for punkt in punkte.dropFirst() {
            rahmen = rahmen.union(MKMapRect(origin: MKMapPoint(punkt), size: MKMapSize(width: 0, height: 0)))
        }
        return rahmen.insetBy(dx: -rahmen.size.width * 0.08 - 300, dy: -rahmen.size.height * 0.08 - 300)
    }
}

/// Ein Halt auf einem Linienzug — klein, in der Farbe seiner Linie.
private struct Linienhalt: View {
    let farbe: Color
    let gross: Bool
    var faelltAus: Bool = false
    var lautMeldungGesperrt: Bool = false

    var body: some View {
        if lautMeldungGesperrt && !faelltAus {
            // Orange und ein Dreieck — nicht das rote Kreuz: Der rote Halt
            // steht so in den Fahrplandaten, dieser hier ist aus dem Text
            // einer Meldung gelesen. Zwei Herkünfte, zwei Zeichen. Auch hier
            // trägt die Form die Aussage und nicht die Farbe allein.
            ZStack {
                Circle()
                    .fill(.background)
                    .frame(width: 15, height: 15)
                Circle()
                    .strokeBorder(.orange, lineWidth: 2.5)
                    .frame(width: 15, height: 15)
                Image(systemName: "exclamationmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.orange)
            }
            .shadow(color: .black.opacity(0.22), radius: 1.5, y: 0.5)
            .accessibilityLabel("laut Meldung gesperrt")
        } else if faelltAus {
            // Rot UND durchgestrichen: Farbe allein sieht ein
            // farbfehlsichtiger Mensch nicht.
            ZStack {
                Circle()
                    .fill(.background)
                    .frame(width: 15, height: 15)
                Circle()
                    .strokeBorder(.red, lineWidth: 2.5)
                    .frame(width: 15, height: 15)
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.red)
            }
            .shadow(color: .black.opacity(0.22), radius: 1.5, y: 0.5)
            .accessibilityLabel("Halt entfällt")
        } else {
            ZStack {
                Circle()
                    .fill(.background)
                    .frame(width: gross ? 13 : 8, height: gross ? 13 : 8)
                Circle()
                    .strokeBorder(farbe, lineWidth: gross ? 3.5 : 2.5)
                    .frame(width: gross ? 13 : 8, height: gross ? 13 : 8)
            }
        }
    }
}

#Preview {
    LiniennetzView()
        .environmentObject(AppModel(dienst: Musterdienst()))
        .environmentObject(Liniennetz())
        .environmentObject(Meldungsdienst())
}
