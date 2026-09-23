import MapKit
import SwiftUI

// Die Reisepunkte eines Tages: was auf der Karte steht, in Worten.
struct SpurView: View {
    @ObservedObject var werk: Reisewerk
    let tagID: UUID
    @Environment(\.dismiss) private var schliessen
    @State private var punktwahl = false
    // Welcher Punkt gerade geändert wird. Der WUNSCH trägt das Ziel, kein
    // Schalter daneben — dieselbe Regel wie bei den Dateiwählern.
    @State private var bearbeiten: Punktwunsch?

    struct Punktwunsch: Identifiable { let id: UUID }

    // MEHRERE PUNKTE AUF EINMAL (ab 1.0.21).
    //
    // Der Modus ist SICHTBAR: Die Überschrift zählt mit, der Knopf heißt
    // „Fertig", und vor jeder Zeile steht ein Kreis statt eines Pfeils. Ein
    // Modus, den man nicht sieht, darf die Bedeutung eines Tipps nicht
    // ändern — dieselbe Regel wie beim Fußwegmesser der Abfahrtstafel.
    @State private var auswahlmodus = false
    @State private var auswahl: Set<UUID> = []
    @State private var verschieben = false

    // WAS AUS DER LINIE SPRINGT (ab 1.0.49).
    //
    // Gerechnet wird in `.task(id:)` und NICHT als berechnete Eigenschaft:
    // Der Lauf geht über jeden Punkt und misst je drei Entfernungen, und
    // der Körper dieser Ansicht läuft bei jeder Meldung des Werks noch
    // einmal. Eine berechnete Eigenschaft sieht billig aus — dieselbe
    // Falle wie bei der Netzkarte der Abfahrtstafel und bei der
    // Druckprüfung in 1.0.0.
    @State private var befunde: [Ausreisser.Befund] = []
    @State private var ausreisserFrage = false

    private var tag: Reisetag? { werk.reise.tage.first { $0.id == tagID } }

    var body: some View {
        NavigationStack {
            List {
                if let tag {
                    Section {
                        // DIE VORSCHAU IST EIN BILD, KEINE KARTE ZUM
                        // ARBEITEN (ab 1.0.49). Sie war bis dahin schieb-
                        // und zoombar — auf 200 Punkten Höhe in einem
                        // Kärtchen ist das eine Karte, an der sich nichts
                        // machen lässt, und sie schluckte den Tipp, mit dem
                        // man die richtige öffnen wollte. Jetzt öffnet ein
                        // Tipp darauf die volle Karte: dieselbe Regel wie
                        // überall in diesem Repo — was auf einer Karte
                        // liegt, ist ein Bild, und was etwas tut, ist ein
                        // Knopf.
                        Button {
                            punktwahl = true
                        } label: {
                            vorschau(tag)
                                .frame(height: 240)
                                .overlay(alignment: .bottomTrailing) {
                                    Label("Auf der Karte öffnen", systemImage: "arrow.up.left.and.arrow.down.right")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(.regularMaterial, in: Capsule())
                                        .padding(8)
                                }
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets())
                    }
                    Section {
                        // DER WEG ZUR KARTE HEISST JETZT NACH DEM, WAS
                        // DORT GEHT (ab 1.0.37). „Punkt auf der Karte
                        // setzen" klang nach einem Weg, der nur hinzufügt —
                        // dabei lässt sich auf derselben Karte seit 1.0.37
                        // jeder vorhandene Punkt antippen, verschieben und
                        // löschen. Ein Menüpunkt, der nicht sagt, was
                        // dahinter liegt, ist so wenig wert wie ein Knopf,
                        // den niemand findet.
                        Button {
                            punktwahl = true
                        } label: {
                            Label("Punkte auf der Karte\u{2026}", systemImage: "map")
                        }
                        Button {
                            werk.spurAktualisieren(tagID)
                            werk.meldung = .init(text: "Spur aus den Fotos neu gebaut.")
                        } label: {
                            Label("Aus den Fotos neu bauen", systemImage: "arrow.clockwise")
                        }
                    } footer: {
                        Text("Auf der Karte lässt sich jeder Punkt antippen, verschieben und "
                             + "löschen \u{2014} dort findet man ihn leichter wieder als in der "
                             + "Liste. Ein Tipp auf eine Zeile hier öffnet denselben Bildschirm "
                             + "bei diesem Punkt. Beim Neubauen aus den Fotos bleiben die von "
                             + "Hand gesetzten Punkte erhalten; die Fotopunkte werden ersetzt.")
                    }

                    if !befunde.isEmpty {
                        ausreisserabschnitt
                    }

                    Section {
                        if tag.spur.isEmpty {
                            Text("Noch keine Punkte. Fotos mit Aufnahmeort bringen sie von selbst mit — sonst setzt du sie auf der Karte.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(tag.spur) { punkt in
                            // Die ZEILE ist der Weg zum Ändern. Ein Punkt,
                            // den man nur wegwischen kann, lässt sich nicht
                            // berichtigen — und ein Knopf in einem Menü wäre
                            // einer, den niemand findet.
                            Button {
                                if auswahlmodus {
                                    if auswahl.contains(punkt.id) {
                                        auswahl.remove(punkt.id)
                                    } else {
                                        auswahl.insert(punkt.id)
                                    }
                                } else {
                                    bearbeiten = Punktwunsch(id: punkt.id)
                                }
                            } label: {
                                PunktZeile(punkt: punkt,
                                           gewaehlt: auswahlmodus ? auswahl.contains(punkt.id) : nil,
                                           auffaellig: auffaellige.contains(punkt.id))
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { stellen in werk.punkteLoeschen(tagID, stellen: stellen) }
                        .onMove { von, nach in werk.punkteVerschieben(tagID, von: von, nach: nach) }
                    } header: {
                        HStack {
                            Text(auswahlmodus
                                 ? "\(auswahl.count) von \(tag.spur.count) gewählt"
                                 : "\(tag.spur.count) Punkte")
                            Spacer()
                            Button(auswahlmodus ? "Fertig" : "Auswählen") {
                                auswahlmodus.toggle()
                                if !auswahlmodus { auswahl = [] }
                            }
                            .font(.caption)
                            // Das Ordnen und das Auswählen sind zwei Modi.
                            // Beide gleichzeitig anzubieten hieße, dass ein
                            // Tipp drei Bedeutungen hätte.
                            if !auswahlmodus { EditButton().font(.caption) }
                        }
                    } footer: {
                        VStack(alignment: .leading, spacing: 6) {
                            if tag.hatStrecke {
                                Text("\(Spurbau.laengeText(tag.spur)). Gezeichnet wird die Verbindung der Punkte, nicht der gefahrene Weg — welche Straße es war, steht in keinem Foto.")
                            }
                            // Eine Uhrzeit ohne Angabe, worauf sie sich
                            // bezieht, ist in einem Reisetagebuch eine
                            // Zumutung: Dieselbe Reise hat Tage in zwei
                            // Zonen. Dieselbe Regel wie beim Wort „Plan"
                            // an einer Abfahrt ohne Echtzeit.
                            Text(zeitsatz(tag))
                        }
                    }

                    if auswahlmodus {
                        Section {
                            Button(auswahl.count == tag.spur.count ? "Keinen wählen" : "Alle wählen") {
                                auswahl = auswahl.count == tag.spur.count
                                    ? []
                                    : Set(tag.spur.map(\.id))
                            }
                            Button {
                                verschieben = true
                            } label: {
                                Label("Zeiten verschieben\u{2026}", systemImage: "clock.arrow.2.circlepath")
                            }
                            .disabled(auswahl.isEmpty)
                            Button(role: .destructive) {
                                werk.punkteLoeschen(tagID, ids: auswahl)
                                auswahl = []
                            } label: {
                                Label("Gewählte löschen", systemImage: "trash")
                            }
                            .disabled(auswahl.isEmpty)
                        } footer: {
                            Text("Alle gewählten Punkte werden um denselben Betrag verschoben "
                                 + "\u{2014} zum Beispiel, wenn die Kamera auf der Uhrzeit von "
                                 + "zu Hause stand.")
                        }
                    }

                    Section("Ausdünnen") {
                        VStack(alignment: .leading) {
                            LabeledContent("Mindestabstand",
                                           value: "\(Int(werk.reise.gestaltung.mindestabstandSpur)) m")
                            Slider(value: Binding(
                                get: { werk.reise.gestaltung.mindestabstandSpur },
                                set: { werk.reise.gestaltung.mindestabstandSpur = $0 }
                            ), in: 0...2000, step: 25)
                        }
                        Text("Fotos, die näher als dieser Abstand beieinander liegen, werden zu einem Punkt zusammengefasst. Ohne das wäre eine Stadtbesichtigung ein einziger Fleck.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Reisepunkte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
            // DIE KARTE BEKOMMT DEN GANZEN BILDSCHIRM (ab 1.0.49).
            //
            // Gemeldet 09/2026: „Ich möchte die Punkte auf der Karte
            // auswählen und merke, dass diese viel zu klein öffnet. Diese
            // Karte könnte sich ja tatsächlich über einen großen Teil des
            // Bildschirms erstrecken."
            //
            // Die Karte war nicht klein gebaut — sie war ein BLATT IN EINEM
            // BLATT: Diese Liste ist selbst ein `.sheet`, und auf dem iPad
            // ist ein Sheet ein Kärtchen in der Bildschirmmitte. Ein zweites
            // darauf ist höchstens so groß wie das erste. Dieselbe Lehre wie
            // beim Platz-Editor in Tafelbild, wo der Grundriss aus demselben
            // Grund ein Drittel der Höhe bekam. Ein `fullScreenCover` hängt
            // sich nicht in das Kärtchen, sondern über alles.
            .fullScreenCover(isPresented: $punktwahl) {
                PunktwahlView(werk: werk, tagID: tagID)
            }
            .fullScreenCover(item: $bearbeiten) { wunsch in
                PunktwahlView(werk: werk, tagID: tagID, start: wunsch.id)
            }
            .sheet(isPresented: $verschieben) {
                Zeitverschiebung(werk: werk, tagID: tagID, punkte: auswahl) {
                    auswahl = []
                    auswahlmodus = false
                }
            }
            .task(id: tag?.spur) { befunde = Ausreisser.finden(tag?.spur ?? []) }
            .alert("\(befunde.count) Punkte entfernen?", isPresented: $ausreisserFrage) {
                Button("Entfernen", role: .destructive) {
                    werk.punkteLoeschen(tagID, ids: Set(befunde.map(\.id)))
                    auswahl = []
                    auswahlmodus = false
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Die Punkte werden aus der Tagesspur entfernt. Stammen sie aus Fotos, "
                     + "kommen sie beim nächsten \u{201E}Aus den Fotos neu bauen\u{201C} wieder "
                     + "\u{2014} die Fotos selbst bleiben in jedem Fall unberührt.")
            }
        }
    }

    private var auffaellige: Set<UUID> { Set(befunde.map(\.id)) }

    // GEFUNDEN, GEZEIGT, GEZÄHLT — UND NICHT GELÖSCHT.
    //
    // Ein Ausreißer kann echt sein: Ein Abstecher zum Aussichtspunkt und
    // zurück sieht von außen genauso aus wie ein Messfehler, und welcher
    // von beidem es war, weiß nur, wer dabei war. Deshalb steht hier eine
    // Liste mit Zahlen und kein Automatismus — dieselbe Regel wie bei
    // jeder Einfuhr dieser App: erst zeigen, dann übernehmen.
    private var ausreisserabschnitt: some View {
        Section {
            ForEach(befunde) { befund in
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(befund.stelle + 1). Punkt \u{2014} \(befund.name)")
                            .font(.subheadline)
                        Text("\(befund.grund.satz) \u{00B7} \(befund.umwegtext) zusätzliche Linie")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Button {
                auswahlmodus = true
                auswahl = auffaellige
            } label: {
                Label("Diese Punkte auswählen", systemImage: "checkmark.circle")
            }
            Button(role: .destructive) {
                ausreisserFrage = true
            } label: {
                Label(befunde.count == 1
                      ? "Diesen Punkt entfernen"
                      : "Alle \(befunde.count) entfernen",
                      systemImage: "trash")
            }
        } header: {
            Text(befunde.count == 1
                 ? "1 Punkt springt aus der Linie"
                 : "\(befunde.count) Punkte springen aus der Linie")
        } footer: {
            Text("Gemessen wird der UMWEG: was der Punkt an zusätzlicher Linie kostet, "
                 + "verglichen mit dem mittleren Schritt DIESER Spur \u{2014} in einer "
                 + "Stadtbesichtigung ist ein Kilometer viel, auf einer Autofahrt nichts. "
                 + "Entfernt wird nichts von selbst: Ein Abstecher hin und zurück sieht "
                 + "genauso aus wie ein Messfehler, und welcher von beidem es war, weiß "
                 + "nur, wer dabei war. Der erste und der letzte Punkt haben nur einen "
                 + "Nachbarn und werden deshalb nicht geprüft.")
        }
    }

    // Worauf sich die Uhrzeiten dieses Tages beziehen.
    private func zeitsatz(_ tag: Reisetag) -> String {
        let grundsatz = "Alle Uhrzeiten sind Ortszeiten: bei Fotos so, wie die Kamera "
            + "sie geschrieben hat, bei einer eingelesenen Reisespur umgerechnet."
        guard let kennung = tag.zeitzone, let zone = TimeZone(identifier: kennung) else {
            return grundsatz
        }
        return grundsatz + " Für diesen Tag gilt "
            + Ortszeit.beschreibung(zone, am: tag.datum.mittag) + "."
    }

    private func vorschau(_ tag: Reisetag) -> some View {
        Map(initialPosition: .automatic, interactionModes: []) {
            if tag.spur.count >= 2 {
                MapPolyline(coordinates: tag.spur.map(\.koordinate.clLocation))
                    .stroke(werk.reise.akzent.farbe, lineWidth: 3)
            }
            ForEach(tag.spur) { punkt in
                Marker(punkt.name.isEmpty ? "Punkt" : punkt.name,
                       systemImage: punkt.istAusFoto ? "camera.fill" : "mappin",
                       coordinate: punkt.koordinate.clLocation)
                    .tint(auffaellige.contains(punkt.id)
                          ? .orange
                          : (punkt.istAusFoto ? .blue : Color.accentColor))
            }
        }
    }
}

private struct PunktZeile: View {
    let punkt: Reisepunkt
    /// Leer heißt: kein Auswahlmodus. Dann steht rechts ein Pfeil, und ein
    /// Tipp öffnet den Punkt.
    var gewaehlt: Bool?
    /// Ob dieser Punkt aus der Linie springt. Die Marke steht AN der Zeile
    /// und nicht nur im Abschnitt darüber: Wer die Liste durchgeht, soll
    /// nicht zwischen zwei Abschnitten hin- und herzählen müssen.
    var auffaellig = false

    var body: some View {
        HStack(spacing: 10) {
            if let gewaehlt {
                Image(systemName: gewaehlt ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(gewaehlt ? Color.accentColor : .secondary)
            }
            Image(systemName: punkt.istAusFoto ? "camera.fill" : "mappin.circle.fill")
                .foregroundStyle(punkt.istAusFoto ? Color.blue : Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text(punkt.name.isEmpty ? koordinatentext : punkt.name)
                        .font(.subheadline)
                    if auffaellig {
                        // Zeichen UND Farbe, nie Farbe allein — ein
                        // farbfehlsichtiger Mensch sähe sonst nichts.
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                HStack(spacing: 6) {
                    if let zeit = punkt.zeit {
                        Text(uhr.string(from: zeit))
                    } else {
                        Text("ohne Uhrzeit")
                    }
                    Text("·")
                    Text(punkt.quelle.name)
                    if punkt.zusammengefasst > 1 {
                        Text("· \(punkt.zusammengefasst) Fotos")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if gewaehlt == nil {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var koordinatentext: String {
        String(format: "%.4f, %.4f", punkt.koordinate.breite, punkt.koordinate.laenge)
    }

    private var uhr: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }
}
