import MapKit
import SwiftUI

/// Mehrere Vorschläge auf EINER Karte, zum Vergleichen der Wege.
///
/// **Warum es das gibt** (ab 1.1.20, Ansage des Nutzers 09/2026: „Ich suche
/// nach einer Möglichkeit, diese gemeinsam auf einer Karte anzeigen zu lassen,
/// sodass man die Verläufe vergleichen kann … Auf jeden Fall möchte ich in
/// einem Menü die einzelnen Verbindungen auf der Karte ein- und ausblenden
/// können."). Die Liste sagt, wie lange etwas dauert und wie oft man umsteigt;
/// sie sagt nicht, WO es langgeht. Zwei Vorschläge mit derselben Dauer können
/// über ganz verschiedene Städte laufen, und ob ein Umstieg in Hamm oder in
/// Köln liegt, entscheidet manchmal alles.
///
/// **Drei Dinge, die diese Karte auseinanderhalten muss:**
///
/// 1. **Welches Verkehrsmittel** — dafür trägt jeder Abschnitt seine
///    Linienfarbe, wie überall in dieser App. Ein ICE (Fernzug, fast schwarz)
///    sieht damit anders aus als eine Kette von Regionalzügen (grau), und wo
///    ein Verbund eine eigene Farbe führt, gilt seine.
/// 2. **Welche Verbindung** — dafür die Nummer am Zug und dieselbe Nummer in
///    der Liste daneben. Die Farbe kann das NICHT leisten, sie ist schon für
///    das Verkehrsmittel vergeben; und zwei Vorschläge, die dieselbe Strecke
///    benutzen, liegen ohnehin übereinander.
/// 3. **Was gerade gemeint ist** — ein Tipp auf eine Zeile hebt sie hervor,
///    alles andere wird blass. Das ist dieselbe Bauweise wie die Legende der
///    Netzkarte, und aus demselben Grund: Zwölf Linien nebeneinander sind ein
///    Bündel, eine hervorgehobene ist eine Auskunft.
///
/// **Auf der Karte liegt kein Bedienelement** — die Lehre aus 1.1.18. Alle
/// Punkte sind `.allowsHitTesting(false)`; bedient wird über die Liste.
struct VergleichsKarte: View {
    let verbindungen: [Verbindung]

    @State private var kamera: MapCameraPosition = .automatic
    /// Welche Vorschläge gezeichnet werden. Leer heißt NICHT „keiner" —
    /// `nil` als Anfangszustand hieße das; deshalb wird die Menge beim
    /// Erscheinen ausdrücklich gefüllt.
    @State private var sichtbar: Set<String> = []
    /// Welcher Vorschlag hervorgehoben ist. `nil` heißt „alle gleich".
    @State private var hervorgehoben: String?
    @State private var listeOffen = true
    @Environment(\.dismiss) private var schliessen
    @Environment(\.colorScheme) private var systemdarstellung
    @AppStorage(Kartendarstellung.schluessel) private var kartenwahlRoh = Kartendarstellung.wieApp.rawValue

    var body: some View {
        NavigationStack {
            karte
                .navigationTitle("Wege vergleichen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            schliessen()
                        } label: {
                            Label("Schließen", systemImage: "xmark")
                        }
                    }
                }
        }
        .onAppear {
            // Beim Öffnen sind alle da. Wer vergleichen will, fängt mit dem
            // Gesamtbild an und blendet dann aus — nicht umgekehrt.
            if sichtbar.isEmpty { sichtbar = Set(verbindungen.map(\.id)) }
        }
    }

    private var karte: some View {
        Map(position: $kamera, interactionModes: [.pan, .zoom, .rotate]) {
            // **Erst alle Konturen, dann alle Linien** — dieselbe Reihenfolge
            // wie auf der Netzkarte. Sonst deckt die Kontur der einen Linie
            // die schon gezeichnete andere zu, und gerade hier liegen viele
            // Wege übereinander.
            ForEach(gezeichnete) { zug in
                MapPolyline(coordinates: zug.punkte)
                    .stroke(
                        konturfarbe.opacity(0.5 * deckkraft(zug.verbindungId)),
                        style: StrokeStyle(
                            lineWidth: breite(zug) + 3,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: zug.gestrichelt ? [1, 5] : []
                        )
                    )
            }

            ForEach(gezeichnete) { zug in
                MapPolyline(coordinates: zug.punkte)
                    .stroke(
                        zug.farbe.opacity(deckkraft(zug.verbindungId)),
                        style: StrokeStyle(
                            lineWidth: breite(zug),
                            lineCap: .round,
                            lineJoin: .round,
                            dash: zug.gestrichelt ? [1, 5] : []
                        )
                    )
            }

            // Die Umstiege — aber NUR der hervorgehobenen Verbindung. Alle
            // Umstiege aller Vorschläge auf einmal wären dreißig Punkte, und
            // die Frage „wo steige ich um" hat immer eine bestimmte
            // Verbindung im Sinn.
            ForEach(umstiegspunkte) { punkt in
                Annotation(punkt.name, coordinate: punkt.koordinate, anchor: .center) {
                    ZStack {
                        Circle().fill(.background).frame(width: 13, height: 13)
                        Circle().strokeBorder(punkt.farbe, lineWidth: 3.5).frame(width: 13, height: 13)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 1.5, y: 0.5)
                    .allowsHitTesting(false)
                }
            }

            // Die Nummer am Zug. Gesetzt an einem Anteil des Verlaufs, der
            // sich mit der Stelle in der Liste verschiebt — sonst lägen alle
            // Nummern im gemeinsamen Anfangsstück übereinander. Derselbe
            // Kniff wie bei den Liniennummern der Netzkarte.
            ForEach(nummernmarken) { marke in
                Annotation("", coordinate: marke.punkt, anchor: .center) {
                    Text("\(marke.nummer)")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.accentColor))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                        .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
                        .opacity(deckkraft(marke.verbindungId))
                        .allowsHitTesting(false)
                }
                .annotationTitles(.hidden)
            }

            if let start = randpunkt(\.first), let ziel = randpunkt(\.last) {
                Annotation("Start", coordinate: start, anchor: .center) {
                    randmarke("figure.walk.departure").allowsHitTesting(false)
                }
                Annotation("Ziel", coordinate: ziel, anchor: .center) {
                    randmarke("flag.checkered").allowsHitTesting(false)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .overlay(alignment: .topTrailing) { liste }
        .overlay(alignment: .bottom) { fusszeile }
        .kartendarstellung()
        .onAppear { kamera = .rect(ausschnitt) }
        // Blendet jemand Verbindungen aus, ändert sich, was zu sehen sein
        // muss — die Karte rahmt dann neu. Das ist hier erwünscht und nicht
        // wie auf der Netzkarte ein Eingriff: Der Auslöser ist ein Tipp des
        // Nutzers, keine eintreffende Antwort aus dem Netz.
        .onChange(of: sichtbar) { _, _ in kamera = .rect(ausschnitt) }
    }

    // MARK: - Die Liste, also das Menü

    private var liste: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet")
                    .font(.caption)
                if listeOffen {
                    Text("Verbindungen")
                        .font(.caption.weight(.semibold))
                }
                Spacer(minLength: 0)
                Button {
                    listeOffen.toggle()
                } label: {
                    Image(systemName: listeOffen ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            if listeOffen {
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(verbindungen.enumerated()), id: \.element.id) { nummer, verbindung in
                            zeile(nummer: nummer + 1, verbindung: verbindung)
                            if verbindung.id != verbindungen.last?.id { Divider() }
                        }
                    }
                }
                .frame(maxHeight: 260)

                Divider()
                HStack(spacing: 12) {
                    Button("Alle") { sichtbar = Set(verbindungen.map(\.id)) }
                    Button("Keine") { sichtbar = [] }
                    if hervorgehoben != nil {
                        Button("Nichts hervorheben") { hervorgehoben = nil }
                    }
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
            }
        }
        .frame(maxWidth: 330)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(10)
    }

    private func zeile(nummer: Int, verbindung: Verbindung) -> some View {
        let anIst = sichtbar.contains(verbindung.id)
        return HStack(alignment: .top, spacing: 8) {
            // **Ein- und Ausblenden ist ein eigener Knopf**, nicht dieselbe
            // Geste wie das Hervorheben. Zwei Aufgaben an einem Tipp wären
            // für den Menschen davor ein Knopf, der mal dies und mal jenes
            // tut.
            Button {
                if anIst { sichtbar.remove(verbindung.id) } else { sichtbar.insert(verbindung.id) }
            } label: {
                Image(systemName: anIst ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(anIst ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            Button {
                hervorgehoben = (hervorgehoben == verbindung.id) ? nil : verbindung.id
                if !anIst { sichtbar.insert(verbindung.id) }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("\(nummer)")
                            .font(.caption2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .frame(width: 17, height: 17)
                            .background(Circle().fill(Color.accentColor))
                        Text(verbindung.abfahrt, format: .dateTime.hour().minute())
                            .monospacedDigit()
                        Image(systemName: "arrow.right").font(.caption2)
                        Text(verbindung.ankunft, format: .dateTime.hour().minute())
                            .monospacedDigit()
                        Spacer(minLength: 0)
                        Text(dauertext(verbindung))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .font(.caption)

                    // **Die Schilderkette gehört hierher** (Ansage des
                    // Nutzers: „Es ist ja nicht unerheblich zu sehen, ob die
                    // Verbindung eine reine ICE-Verbindung ist oder fünfmal
                    // umsteigen bei Regionalbahnen bedeutet."). Auf der Karte
                    // wäre dafür kein Platz, in der Liste ist er.
                    HStack(spacing: 4) {
                        ForEach(gezeigteFahrten(verbindung)) { fahrt in
                            if let linie = fahrt.linie {
                                // Kein `mitMittel`: Die Kette ist auf sechs
                                // Schilder gedeckelt, weil die Leiste schmal
                                // ist; jedes Schild breiter zu machen nähme
                                // genau den Platz wieder weg. Wer wissen
                                // will, was fährt, öffnet die Verbindung —
                                // dort steht das Symbol an jedem Abschnitt.
                                Liniensymbol(linie: linie)
                            }
                        }
                        // **Gedeckelt statt gestaucht.** In diese Spalte
                        // passen rund sechs Schilder; wer sie kleiner
                        // zeichnete, machte genau das unlesbar, wofür sie
                        // hier stehen. Was fehlt, wird gezählt — und die
                        // ganze Kette steht ohnehin in der Liste dahinter.
                        if verbindung.fahrten.count > Self.hoechstensSchilder {
                            Text("+\(verbindung.fahrten.count - Self.hoechstensSchilder)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .opacity(anIst ? 1 : 0.45)
        .background(hervorgehoben == verbindung.id ? Color.accentColor.opacity(0.12) : .clear)
    }

    private static let hoechstensSchilder = 6

    private func gezeigteFahrten(_ verbindung: Verbindung) -> [Verbindungsabschnitt] {
        Array(verbindung.fahrten.prefix(Self.hoechstensSchilder))
    }

    private var fusszeile: some View {
        Text(hinweis)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            .lesebreite()
    }

    /// Was unter der Karte steht — und zwar das WICHTIGSTE zuerst, nicht die
    /// Zeichenerklärung. Dieselbe Reihenfolge wie bei der Netzkarte.
    private var hinweis: String {
        if sichtbar.isEmpty {
            return "Keine Verbindung ausgewählt. In der Liste oben rechts lassen sich einzelne wieder einblenden."
        }
        if gezeichnete.contains(where: \.gestrichelt) {
            return "Gestrichelt heißt: Für diesen Abschnitt hat die Quelle keinen Linienweg mitgeschickt — gezeichnet ist dann die Verbindung der Halte. Die Farben sind die der Linien, die Nummern die der Liste."
        }
        return "Die Farben sind die der Linien, die Nummern die der Liste. Ein Tipp auf eine Zeile hebt ihren Weg hervor."
    }

    private func randmarke(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .padding(6)
            .background(Circle().fill(.black.opacity(0.75)))
            .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
    }

    // MARK: - Was gezeichnet wird

    /// Ein Abschnitt, fertig zum Zeichnen. Eigener Typ, weil `ForEach` eine
    /// Kennung braucht, die über ALLE Verbindungen eindeutig ist — die
    /// Abschnittskennungen der Quellen sind es nicht zwingend.
    private struct Zug: Identifiable {
        let id: String
        let verbindungId: String
        let punkte: [CLLocationCoordinate2D]
        let farbe: Color
        let gestrichelt: Bool
        let istFahrt: Bool
    }

    private var gezeichnete: [Zug] {
        verbindungen.filter { sichtbar.contains($0.id) }.flatMap { verbindung in
            verbindung.abschnitte.enumerated().compactMap { stelle, abschnitt -> Zug? in
                let punkte = abschnitt.linienzug
                guard punkte.count >= 2 else { return nil }
                return Zug(
                    id: "\(verbindung.id)#\(stelle)",
                    verbindungId: verbindung.id,
                    punkte: punkte,
                    farbe: abschnitt.linie?.anzeigefarbe ?? .secondary,
                    gestrichelt: abschnitt.gestrichelt,
                    istFahrt: abschnitt.art == .fahrt
                )
            }
        }
    }

    /// Hervorgehobene Verbindungen werden dicker gezeichnet, nicht nur
    /// kräftiger: Auf einer Karte mit sechs Wegen übereinander ist die Breite
    /// das Merkmal, das auch dann noch trägt, wenn zwei Wege dieselbe Farbe
    /// haben.
    private func breite(_ zug: Zug) -> CGFloat {
        let grund: CGFloat = zug.istFahrt ? 5 : 3
        return hervorgehoben == zug.verbindungId ? grund + 2 : grund
    }

    private func deckkraft(_ verbindungId: String) -> Double {
        guard let hervorgehoben else { return 1 }
        return hervorgehoben == verbindungId ? 1 : 0.28
    }

    /// Die Kontur muss die GEGENFARBE zur KARTE sein — nicht zur App. Welche
    /// das ist, löst `Kartendarstellung.geltend` auf, also dieselbe Stelle,
    /// die auch `kartendarstellung()` benutzt.
    private var konturfarbe: Color {
        Kartendarstellung.geltend(kartenwahlRoh, wennWieApp: systemdarstellung) == .dark ? .black : .white
    }

    private struct Umstiegspunkt: Identifiable {
        let id: String
        let name: String
        let koordinate: CLLocationCoordinate2D
        let farbe: Color
    }

    private var umstiegspunkte: [Umstiegspunkt] {
        guard let hervorgehoben,
              let verbindung = verbindungen.first(where: { $0.id == hervorgehoben }),
              sichtbar.contains(hervorgehoben)
        else { return [] }
        return verbindung.abschnitte.compactMap { abschnitt in
            guard abschnitt.art == .fahrt, let von = abschnitt.von else { return nil }
            return Umstiegspunkt(
                id: abschnitt.id,
                name: von.name,
                koordinate: von.koordinate,
                farbe: abschnitt.linie?.anzeigefarbe ?? .secondary
            )
        }
    }

    private struct Nummernmarke: Identifiable {
        let id: String
        let verbindungId: String
        let nummer: Int
        let punkt: CLLocationCoordinate2D
    }

    private var nummernmarken: [Nummernmarke] {
        verbindungen.enumerated().compactMap { stelle, verbindung in
            guard sichtbar.contains(verbindung.id) else { return nil }
            let punkte = verbindung.abschnitte.flatMap(\.linienzug)
            guard !punkte.isEmpty else { return nil }
            // 0,22 bis 0,78 — dieselbe Spanne wie bei den Liniennummern der
            // Netzkarte. Am Anfang und am Ende laufen alle Vorschläge
            // zusammen; dort lägen die Nummern aufeinander.
            let anteil = verbindungen.count > 1
                ? 0.22 + 0.56 * Double(stelle) / Double(verbindungen.count - 1)
                : 0.5
            let stelleImZug = min(Int(Double(punkte.count - 1) * anteil), punkte.count - 1)
            return Nummernmarke(
                id: verbindung.id,
                verbindungId: verbindung.id,
                nummer: stelle + 1,
                punkt: punkte[stelleImZug]
            )
        }
    }

    private func randpunkt(
        _ welcher: KeyPath<[CLLocationCoordinate2D], CLLocationCoordinate2D?>
    ) -> CLLocationCoordinate2D? {
        guard let erste = verbindungen.first else { return nil }
        return erste.abschnitte.flatMap(\.linienzug)[keyPath: welcher]
    }

    /// Gerahmt wird, was SICHTBAR ist. Wer fünf von sechs Vorschlägen
    /// ausblendet, will den sechsten groß sehen und nicht den Ausschnitt von
    /// vorhin.
    private var ausschnitt: MKMapRect {
        let punkte = gezeichnete.flatMap(\.punkte)
        let zuRahmen = punkte.isEmpty
            ? verbindungen.flatMap { $0.abschnitte.flatMap(\.linienzug) }
            : punkte
        guard let erster = zuRahmen.first else { return MKMapRect.world }
        var rahmen = MKMapRect(origin: MKMapPoint(erster), size: MKMapSize(width: 0, height: 0))
        for punkt in zuRahmen.dropFirst() {
            rahmen = rahmen.union(MKMapRect(origin: MKMapPoint(punkt), size: MKMapSize(width: 0, height: 0)))
        }
        return rahmen.insetBy(dx: -rahmen.size.width * 0.18 - 400, dy: -rahmen.size.height * 0.18 - 400)
    }

    private func dauertext(_ verbindung: Verbindung) -> String {
        let minuten = Int((verbindung.dauer / 60).rounded())
        if minuten < 60 { return "\(minuten) min" }
        return "\(minuten / 60) h \(minuten % 60) min"
    }
}

#Preview {
    VergleichsKarte(verbindungen: Musterdienst.beispielverbindungen)
}
