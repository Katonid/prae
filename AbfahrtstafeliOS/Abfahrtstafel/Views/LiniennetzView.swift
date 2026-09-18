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
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var netz: Liniennetz

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

    private func aufbauen() {
        netz.aufbauen(aus: model.nachZeit, dienst: model.dienst)
    }

    // MARK: - Karte

    private var karte: some View {
        Map(position: $kamera, interactionModes: [.pan, .zoom, .rotate]) {
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
                    Linienhalt(farbe: halt.farbe, gross: halt.gross, faelltAus: halt.faelltAus)
                }
                // Beschriftet nur, wenn EINE Linie hervorgehoben ist. Sonst
                // lägen dreihundert Haltestellennamen übereinander und die
                // Karte wäre unlesbar. Ein ENTFALLENDER Halt trägt seinen
                // Namen immer — es sind wenige, und sie sind die Auskunft.
                .annotationTitles(hervorgehoben == nil && !halt.faelltAus ? .hidden : .automatic)
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
                    ZStack {
                        Circle().fill(.background).frame(width: 13, height: 13)
                        Circle().strokeBorder(.primary, lineWidth: 3).frame(width: 13, height: 13)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 1.5, y: 0.5)
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
        .overlay(alignment: .topTrailing) { legende }
        .overlay(alignment: .center) {
            if netz.laedt && netz.zuege.isEmpty {
                ProgressView("Linienverläufe werden geholt …")
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
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
        let farbe: Color
        let gross: Bool
        var faelltAus: Bool = false
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
        if let hervorgehoben, let zug = netz.zuege.first(where: { $0.id == hervorgehoben }) {
            // Eine Linie hervorgehoben: ihre Halte, und zwar alle. Das ist
            // der Fall, für den die Punkte gebaut sind.
            return zug.halte.enumerated().map { nummer, halt in
                Linienhaltpunkt(
                    id: "\(zug.id)#\(nummer)",
                    name: halt.haltestelle.name,
                    koordinate: halt.haltestelle.koordinate,
                    farbe: zug.linie.anzeigefarbe,
                    gross: nummer == 0 || nummer == zug.halte.count - 1,
                    faelltAus: halt.faelltAus
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
                        farbe: zug.linie.anzeigefarbe,
                        gross: false,
                        faelltAus: halt.faelltAus
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
            return punkte.filter(\.faelltAus)
        }
        return punkte
    }

    private var zuVieleHalte: Bool {
        guard hervorgehoben == nil, !netz.zuege.isEmpty else { return false }
        return !sichtbareHalte.contains { !$0.faelltAus }
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

    private var fusszeile: some View {
        VStack(alignment: .leading, spacing: 2) {
            if netz.ohneVerlauf > 0 {
                Label(
                    netz.ohneVerlauf == 1
                        ? "Eine Linie fehlt auf der Karte: Ihre Quelle gibt keinen Linienverlauf heraus."
                        : "\(netz.ohneVerlauf) Linien fehlen auf der Karte: Ihre Quelle gibt keinen Linienverlauf heraus.",
                    systemImage: "exclamationmark.triangle"
                )
            }
            if netz.zuege.contains(where: \.istLuftlinie) {
                Text("Gestrichelte Linien sind Luftlinien zwischen den Halten — für sie kam keine Streckenführung mit.")
            }
            if netz.entfallendeHalte > 0 {
                Label(
                    netz.entfallendeHalte == 1
                        ? "Ein Halt entfällt heute (rot durchgestrichen). Der gezeichnete Linienweg bleibt der PLANMÄSSIGE — welchen Weg das Fahrzeug stattdessen fährt, gibt keine Quelle heraus."
                        : "\(netz.entfallendeHalte) Halte entfallen heute (rot durchgestrichen). Die gezeichneten Linienwege bleiben die PLANMÄSSIGEN — welchen Weg die Fahrzeuge stattdessen fahren, gibt keine Quelle heraus.",
                    systemImage: "arrow.triangle.branch"
                )
            }
            if zuVieleHalte {
                Text("Zu viele Halte für die Übersicht — eine Liniennummer antippen (auf der Karte oder in der Legende) zeigt die Haltestellen dieser Linie mit Namen.")
            } else if hervorgehoben == nil {
                Text("Die kleinen Punkte sind die Halte der gezeichneten Linien. Eine Liniennummer antippen — auf der Karte oder in der Legende — zeigt ihre Halte mit Namen.")
            }
            if !legendeOffen {
                Text("Die Legende ist ausgeblendet; der Knopf oben rechts auf der Karte holt sie zurück.")
            }
            Text("Je Linie ist ein Lauf gezeichnet; die Gegenrichtung fährt denselben Weg zurück. Höchstens zwölf Linien. Wo der Verbund keine Linienfarbe führt, wird die Farbe des Verkehrsmittels je Linie leicht abgewandelt.")
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

    var body: some View {
        if faelltAus {
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
}
