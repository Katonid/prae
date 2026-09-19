import MapKit
import SwiftUI

/// Eine Verbindung im Einzelnen: die Karte über allem, darunter jeder
/// Abschnitt mit Ein- und Ausstieg.
///
/// Die Zwischenhalte stehen ZUGEKLAPPT da. Bei einer Fahrt über zwanzig
/// Stationen wären sie sonst der ganze Bildschirm, und gesucht wird hier
/// zuerst: wo steige ich ein, wo um, wo aus.
struct VerbindungDetailView: View {
    let verbindung: Verbindung

    @State private var offeneAbschnitte: Set<String> = []

    var body: some View {
        List {
            Section {
                VerbindungsKarte(verbindung: verbindung)
                    .frame(height: 240)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                kopf
                    .textCase(nil)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 10, trailing: 0))
            } footer: {
                if ohneStreckenfuehrung {
                    Text("Gestrichelt heißt: Die Quelle hat für diesen Abschnitt keinen Linienweg mitgeschickt. Gezeichnet ist dann die Verbindung der Halte — nicht der Weg, den das Fahrzeug nimmt.")
                        .font(.caption2)
                }
            }

            ForEach(verbindung.abschnitte) { abschnitt in
                Section {
                    if abschnitt.art == .fussweg {
                        Fusswegzeile(abschnitt: abschnitt)
                    } else {
                        Fahrtzeile(
                            abschnitt: abschnitt,
                            offen: offeneAbschnitte.contains(abschnitt.id),
                            umschalten: {
                                if offeneAbschnitte.contains(abschnitt.id) {
                                    offeneAbschnitte.remove(abschnitt.id)
                                } else {
                                    offeneAbschnitte.insert(abschnitt.id)
                                }
                            }
                        )
                    }
                }
            }

            Section {
                Text("Fußwege sind gerechnete Wege, keine gemessenen — wie lange jemand wirklich braucht, hängt vom Gehtempo und davon ab, wo der Zugang zum Bahnsteig liegt. Ein Umstieg, der auf dem Papier drei Minuten hat, kann in einem großen Bahnhof knapp werden.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Verbindung")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Ob irgendeine Fahrt dieser Verbindung ohne Streckenführung dasteht.
    /// Steht unter der Karte — eine Karte, der man ihre Unvollständigkeit
    /// nicht ansieht, ist die schlechtere Karte.
    private var ohneStreckenfuehrung: Bool {
        verbindung.abschnitte.contains { $0.art == .fahrt && $0.strecke.isEmpty }
    }

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbindung.abfahrt, format: .dateTime.hour().minute())
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Image(systemName: "arrow.right").font(.caption)
                Text(verbindung.ankunft, format: .dateTime.hour().minute())
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Spacer(minLength: 0)
            }
            Text("\(verbindung.abschnitte.first?.vonName ?? "Start") → \(verbindung.abschnitte.last?.nachName ?? "Ziel")")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Ein Fußweg

    private struct Fusswegzeile: View {
        let abschnitt: Verbindungsabschnitt

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "figure.walk")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Zu Fuß nach \(abschnitt.nachName)")
                        .font(.subheadline.weight(.medium))
                    HStack(spacing: 6) {
                        Text("\(Int((abschnitt.dauer / 60).rounded())) min")
                        if let meter = abschnitt.meter {
                            Text("· \(Haltestelle.entfernungstext(Double(meter)))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .lesebreite()
        }
    }

    // MARK: - Eine Fahrt

    private struct Fahrtzeile: View {
        let abschnitt: Verbindungsabschnitt
        let offen: Bool
        let umschalten: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    if let linie = abschnitt.linie { Liniensymbol(linie: linie) }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Richtung \(abschnitt.richtung ?? "unbekannt")")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        if !abschnitt.istEchtzeit {
                            Text("Planzeiten — keine Echtzeitmeldung")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }

                halt(name: abschnitt.vonName, zeit: abschnitt.start, plan: abschnitt.geplanterStart, marke: "ein")
                halt(name: abschnitt.nachName, zeit: abschnitt.ende, plan: abschnitt.geplantesEnde, marke: "aus")

                if abschnitt.faelltAus {
                    Label("Diese Fahrt fällt aus", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }
                if !abschnitt.entfallendeHalte.isEmpty {
                    Label(
                        "Unterwegs entfällt: " + abschnitt.entfallendeHalte.map(\.haltestelle.name).joined(separator: ", "),
                        systemImage: "arrow.triangle.branch"
                    )
                    .font(.caption)
                    .foregroundStyle(.red)
                }

                if !abschnitt.zwischenhalte.isEmpty {
                    Button(action: umschalten) {
                        Label(
                            offen
                                ? "Zwischenhalte ausblenden"
                                : "\(abschnitt.zwischenhalte.count) Zwischenhalte zeigen",
                            systemImage: offen ? "chevron.up" : "chevron.down"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)

                    if offen {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(abschnitt.zwischenhalte) { halt in
                                HStack(spacing: 6) {
                                    Text(halt.haltestelle.name)
                                        .strikethrough(halt.faelltAus, color: .secondary)
                                    if halt.faelltAus {
                                        Text("entfällt").foregroundStyle(.red)
                                    }
                                    Spacer(minLength: 4)
                                    if let zeit = halt.zeit {
                                        Text(zeit, format: .dateTime.hour().minute())
                                            .monospacedDigit()
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.leading, 4)
                    }
                }

                // Der ganze Lauf — aber nur, wenn die Quelle eine Fahrtkennung
                // herausgibt. Eine Zeile, die aussieht wie ein Knopf und beim
                // Tippen nichts tut, ist für den Menschen davor ein kaputter
                // Knopf.
                if let fahrtId = abschnitt.fahrtId {
                    NavigationLink(value: Fahrtwunsch(fahrtId: fahrtId, einstieg: abschnitt.von)) {
                        Label("Ganzen Linienlauf ansehen", systemImage: "list.bullet")
                            .font(.caption)
                    }
                }
            }
            .padding(.vertical, 3)
            .lesebreite()
        }

        /// Ein- und Ausstieg mit Zeit. **Die geltende Zeit ist die große** —
        /// dieselbe Regel wie im Fahrtlauf.
        @ViewBuilder
        private func halt(name: String, zeit: Date, plan: Date?, marke: String) -> some View {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(marke)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .leading)
                Text(name)
                    .font(.subheadline)
                    .lineLimit(2)
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 0) {
                    let minuten = plan.map { Int((zeit.timeIntervalSince($0) / 60).rounded()) } ?? 0
                    Text(zeit, format: .dateTime.hour().minute())
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(minuten == 0 ? Color.primary : (minuten > 0 ? Color.red : Color.blue))
                    if let plan, minuten != 0 {
                        Text(plan, format: .dateTime.hour().minute())
                            .font(.caption2)
                            .monospacedDigit()
                            .strikethrough(true, color: .secondary)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// Alle Abschnitte auf einer Karte — Fahrten durchgezogen, Fußwege gepunktet.
private struct VerbindungsKarte: View {
    let verbindung: Verbindung

    @State private var kamera: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $kamera, interactionModes: [.pan, .zoom]) {
            ForEach(verbindung.abschnitte) { abschnitt in
                let punkte = abschnitt.linienzug
                if punkte.count >= 2 {
                    MapPolyline(coordinates: punkte)
                        .stroke(
                            abschnitt.linie?.anzeigefarbe ?? Color.secondary,
                            style: StrokeStyle(
                                lineWidth: abschnitt.art == .fussweg ? 3 : 5,
                                lineCap: .round,
                                lineJoin: .round,
                                // Ein Fußweg ist gepunktet, weil er kein
                                // Linienweg ist. **Und eine Fahrt OHNE
                                // Streckenführung wird gestrichelt** — nicht
                                // durchgezogen: Nicht jede Quelle liefert
                                // Geometrie (die Schweizer gar keine), und
                                // eine durchgezogene Gerade quer über die
                                // Karte sähe aus wie ein Fahrweg. Dieselbe
                                // Regel wie bei der gestrichelten Luftlinie
                                // im Fahrtlauf.
                                dash: abschnitt.gestrichelt ? [1, 5] : []
                            )
                        )
                }
            }

            ForEach(umstiegspunkte) { punkt in
                Annotation(punkt.name, coordinate: punkt.koordinate, anchor: .center) {
                    ZStack {
                        Circle().fill(.background).frame(width: 13, height: 13)
                        Circle().strokeBorder(punkt.farbe, lineWidth: 3.5).frame(width: 13, height: 13)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 1.5, y: 0.5)
                    // Diese Punkte tun nichts — dann nehmen sie auch keine
                    // Berührung an. Was auf einer Karte liegt und keine
                    // Aufgabe hat, fehlt sonst der Zoomgeste (ab 1.1.18).
                    .allowsHitTesting(false)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .kartendarstellung()
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear { kamera = .rect(ausschnitt) }
    }

    private struct Umstiegspunkt: Identifiable {
        let id: String
        let name: String
        let koordinate: CLLocationCoordinate2D
        let farbe: Color
    }

    private var umstiegspunkte: [Umstiegspunkt] {
        verbindung.abschnitte.compactMap { abschnitt in
            guard abschnitt.art == .fahrt, let von = abschnitt.von else { return nil }
            return Umstiegspunkt(
                id: abschnitt.id,
                name: von.name,
                koordinate: von.koordinate,
                farbe: abschnitt.linie?.anzeigefarbe ?? .secondary
            )
        }
    }

    /// Die Streckenführung, und wo sie fehlt, die Verbindung der Halte.


    private var ausschnitt: MKMapRect {
        let punkte = verbindung.abschnitte.flatMap(\.linienzug)
        guard let erster = punkte.first else { return MKMapRect.world }
        var rahmen = MKMapRect(origin: MKMapPoint(erster), size: MKMapSize(width: 0, height: 0))
        for punkt in punkte.dropFirst() {
            rahmen = rahmen.union(MKMapRect(origin: MKMapPoint(punkt), size: MKMapSize(width: 0, height: 0)))
        }
        return rahmen.insetBy(dx: -rahmen.size.width * 0.15 - 350, dy: -rahmen.size.height * 0.15 - 350)
    }
}
