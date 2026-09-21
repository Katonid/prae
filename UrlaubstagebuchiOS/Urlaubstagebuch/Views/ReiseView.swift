import SwiftUI
import UIKit

struct ReiseView: View {
    @ObservedObject var werk: Reisewerk
    @EnvironmentObject private var regal: Regal

    @State private var spalten = NavigationSplitViewVisibility.automatic
    @State private var inspektor = false
    @State private var zoom: Double = 0
    @State private var blatt: Blatt?
    @State private var neuAnordnenFrage: UUID?
    // Derselbe Schlüssel wie in `SeitenflaecheView` — `@AppStorage` teilt
    // sich über den Namen, und zwei Zustände für denselben Schalter liefen
    // auseinander.
    @AppStorage("einrasten") private var einrastenAn = true
    @State private var buchdatei: Buchwunsch?
    // Einzelseiten oder Doppelseiten. `@AppStorage` gehört in eine VIEW
    // und nie ins `Reisewerk` — der Wrapper ist eine `DynamicProperty`.
    @AppStorage("doppelseiten") private var doppelseiten = false
    // Der Maßstab beim Aufsetzen der Zweifingergeste. Gerechnet wird vom
    // Anfangswert aus: `magnification` ist die GESAMTE Bewegung seit dem
    // Aufsetzen, und wer sie aufaddiert, beschleunigt mit jedem Bildpunkt
    // (dieselbe Lehre wie beim Bildausschnitt in 1.0.8).
    @State private var zoomAnfang: Double?
    // Wie breit die Bühne ist. GEMESSEN und gemerkt, nicht geschätzt:
    // Daran hängt der eingepasste Maßstab, und den brauchen die Lupen und
    // die Geste auch außerhalb des `GeometryReader`.
    @State private var buehnenbreite: Double = 0

    // Der Wunsch trägt das Ziel, kein Schalter daneben — dieselbe Regel
    // wie bei den Dateiwählern in Tafelbild. Ein `URL` ist nicht
    // `Identifiable`, und die Zusatzkonformität einer fremden Sorte
    // aufzuzwingen wäre der teurere Weg.
    struct Buchwunsch: Identifiable {
        let id = UUID()
        let ort: URL
    }

    enum Blatt: Identifiable {
        case stil
        case hintergrund
        case textimport
        case fotos
        case dateien
        case tagesspur
        case typografie
        case fotostil
        case textstil
        case gestaltung
        case bedienung
        case ausgabe
        case tagInhalt(UUID)
        case spur(UUID)
        case ablage

        var id: String {
            switch self {
            case .stil: return "stil"
            case .hintergrund: return "hintergrund"
            case .textimport: return "text"
            case .fotos: return "fotos"
            case .dateien: return "dateien"
            case .tagesspur: return "tagesspur"
            case .typografie: return "typo"
            case .fotostil: return "fotostil"
            case .textstil: return "textstil"
            case .gestaltung: return "gestaltung"
            case .bedienung: return "bedienung"
            case .ausgabe: return "ausgabe"
            case let .tagInhalt(id): return "tag-\(id)"
            case let .spur(id): return "spur-\(id)"
            case .ablage: return "ablage"
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $spalten) {
            TagListeView(werk: werk, blatt: $blatt)
        } detail: {
            buehne
        }
        .navigationSplitViewStyle(.balanced)
        .inspector(isPresented: $inspektor) {
            BlockInspektor(werk: werk, blatt: $blatt)
                .inspectorColumnWidth(min: 260, ideal: 310, max: 380)
        }
        .sheet(item: $blatt) { welches in
            blattInhalt(welches)
        }
        .sheet(item: $buchdatei) { wunsch in
            Teilenblatt(gegenstaende: [wunsch.ort])
        }
        .overlay(alignment: .top) { baender }
        .alert("Seiten neu anordnen?", isPresented: .init(
            get: { neuAnordnenFrage != nil },
            set: { if !$0 { neuAnordnenFrage = nil } }
        )) {
            Button("Neu anordnen", role: .destructive) {
                if let id = neuAnordnenFrage { werk.neuAnordnen(id, erzwingen: true) }
                neuAnordnenFrage = nil
            }
            Button("Abbrechen", role: .cancel) { neuAnordnenFrage = nil }
        } message: {
            Text("An diesem Tag wurde von Hand gearbeitet. Beim Neuanordnen gehen die verschobenen und veränderten Blöcke verloren. Mit „Zurück“ oben lässt sich das rückgängig machen.")
        }
        .task { werk.fehlendeSeitenNachholen() }
    }

    // MARK: - Bühne

    private var buehne: some View {
        GeometryReader { raum in
            ScrollView([.horizontal, .vertical]) {
                // LAZY, und das ist der Punkt: Ein gewöhnlicher `VStack`
                // baut JEDES Kind sofort auf, auch das, was weit unterhalb
                // des Bildschirms liegt. Ist kein Tag gewählt, sind das
                // sämtliche Seiten des Buches — mit jedem Textkasten (ein
                // voller CoreText-Satz) und jedem Foto (ein Vorschaubild,
                // das beim ersten Mal von der Platte gelesen und entpackt
                // wird). Bei einem Buch mit zweihundert Fotos ist das die
                // Arbeit eines ganzen PDF-Laufs, und sie fällt an, sobald
                // jemand die Seite wechselt. Ein `LazyVStack` baut nur,
                // was in Sichtweite kommt.
                LazyVStack(spacing: 26) {
                    if doppelseiten {
                        bogenliste
                    } else {
                        einzelseiten
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity)
                // ZWEI FINGER ZOOMEN DIE SEITE (ab 1.0.17).
                //
                // Die Geste hängt am INHALT der Bühne und nicht an einer
                // einzelnen Seite: Gezoomt wird das Blatt, nicht das, was
                // darauf liegt. Sie ist abgeschaltet, solange ein FOTO
                // gewählt ist — dort bedeuten zwei Finger seit 1.0.8 den
                // Bildausschnitt im Rahmen, und eine Geste, die zwei Dinge
                // gleichzeitig tut, ist für den Menschen davor kaputt.
                // Sichtbar ist der Unterschied an den Anfassern; und die
                // Lupen unten links gehen immer.
                .gesture(seitenzoom, including: seitenzoomErlaubt ? .all : .subviews)
            }
            .background(Color(.systemGroupedBackground))
            // Gemessen wird die Breite EINMAL je Änderung, nicht im Körper:
            // Ein `@State`, das während des Zeichnens geschrieben wird,
            // löst das nächste Zeichnen aus.
            .onChange(of: raum.size.width, initial: true) { _, breite in
                buehnenbreite = breite
            }
        }
        .navigationTitle(titelzeile)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { werkzeuge }
    }

    // EINMAL je Durchgang gelesen, nicht zweimal: Bis 1.0.15 stand
    // `sichtbareSeiten` hier zweimal — einmal für die Liste und einmal für
    // die Prüfung auf leer —, und dahinter lag der Aufbau der ganzen
    // Seitenfolge samt Titelblatt.
    @ViewBuilder
    private var einzelseiten: some View {
        let seiten = werk.sichtbareSeiten
        ForEach(seiten) { buchseite in
            VStack(spacing: 6) {
                SeitenflaecheView(werk: werk, buchseite: buchseite, massstab: massstabJetzt)
                Text("Seite \(buchseite.nummer)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        if seiten.isEmpty { hinweisLeer }
    }

    @ViewBuilder
    private var bogenliste: some View {
        let bogen = werk.sichtbareDoppelseiten
        ForEach(bogen) { einer in
            DoppelseiteView(werk: werk, bogen: einer, massstab: massstabJetzt)
        }
        if bogen.isEmpty {
            hinweisLeer
        } else if let hinweis = ungeradeSeitenzahl {
            // Gesagt wird es dort, wo die Frage entsteht: In der
            // Doppelseitenansicht sieht man, dass der letzte Bogen keine
            // Rückseite hat. Die meisten Druckdienste verlangen eine
            // GERADE Seitenzahl; das ist hier NICHT geprüft, sondern
            // gezählt — was ein bestimmter Anbieter annimmt, steht in
            // seinen Angaben und nicht in dieser App.
            Text(hinweis)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
                .padding(.top, 8)
        }
    }

    private var ungeradeSeitenzahl: String? {
        let anzahl = werk.seitenfolge.count
        guard anzahl > 0, anzahl % 2 == 1 else { return nil }
        return "Das Buch hat \(anzahl) Seiten, also eine ungerade Zahl \u{2014} "
            + "die letzte Seite hat keine Rückseite. Viele Druckdienste verlangen "
            + "eine gerade Seitenzahl; ob dieser es tut, steht in seinen Angaben."
    }

    private var hinweisLeer: some View {
        ContentUnavailableView {
            Label("Noch nichts auf dieser Seite", systemImage: "doc")
        } description: {
            Text("Lies Fotos oder einen Tagebuchtext ein — die App legt daraus die Tage an und setzt die Seiten.")
        } actions: {
            Button("Text einlesen") { blatt = .textimport }
            Button("Fotos einlesen") { blatt = .fotos }
        }
        .frame(height: 340)
    }

    // Die Liste selbst steht seit 1.0.16 im `Reisewerk` — sie wird an
    // mehr als einer Stelle gebraucht, und dort liegt auch das gemerkte
    // Titelblatt.
    static let titelseitenKennung = Reisewerk.titelseitenKennung

    private var titelzeile: String {
        if werk.gewaehlterTag == Self.titelseitenKennung { return "Titelseite" }
        return werk.tag?.datum.lang ?? werk.reise.titel
    }

    // Der Maßstab passt die Seite in die Breite ein, solange nicht
    // ausdrücklich gezoomt wurde. Ein Buch, das man erst zurechtschieben
    // muss, bevor man es sieht, ist keines.
    //
    // In der Doppelseitenansicht zählt die DOPPELTE Breite: Was eingepasst
    // werden soll, ist der aufgeschlagene Bogen und nicht die halbe Seite.
    private var passenderMassstab: Double {
        let bogen = werk.reise.gestaltung.bogen(werk.reise.format)
        let breite = bogen.width * (doppelseiten ? 2 : 1)
        let platz = max(buehnenbreite - 56, 120)
        return min(max(platz / breite, 0.12), 1.6)
    }

    // ZWEI FINGER auf der Bühne (ab 1.0.17, Ansage des Nutzers 09/2026:
    // „Eine Zwei-Finger-Geste auf die Seite wäre mir lieber.").
    private var seitenzoom: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { wert in
                let anfang = zoomAnfang ?? massstabJetzt
                if zoomAnfang == nil { zoomAnfang = anfang }
                zoom = min(max(anfang * wert.magnification, 0.12), 4)
            }
            .onEnded { _ in zoomAnfang = nil }
    }

    // Über einem gewählten FOTO gehören die zwei Finger dem Bildausschnitt.
    private var seitenzoomErlaubt: Bool {
        werk.ausschnittsmodus == nil && gewaehlterBlock?.fotoID == nil
    }

    // MARK: - Werkzeuge

    @ToolbarContentBuilder
    private var werkzeuge: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                werk.sofortSichern()
                regal.schliessen()
            } label: {
                Label("Fertig", systemImage: "chevron.left")
            }
        }
        ToolbarItem(placement: .topBarLeading) {
            Button {
                werk.zurueck()
            } label: {
                Label("Zurück", systemImage: "arrow.uturn.backward")
            }
            .disabled(!werk.kannZurueck)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Tagebuchtext einlesen…", systemImage: "text.book.closed") {
                    blatt = .textimport
                }
                Button("Fotos aus der Mediathek…", systemImage: "photo.on.rectangle") {
                    blatt = .fotos
                }
                Button("Bilder aus Dateien…", systemImage: "folder") {
                    blatt = .dateien
                }
                Button("Reisespur aus der Tagesspur…", systemImage: "point.topleft.down.curvedto.point.bottomright.up") {
                    blatt = .tagesspur
                }
                Divider()
                Button("Fotoablage…", systemImage: "tray") { blatt = .ablage }
            } label: {
                Label("Einlesen", systemImage: "square.and.arrow.down")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if let tag = werk.tag {
                    Button("Diesen Tag neu anordnen", systemImage: "wand.and.stars") {
                        if werk.hatHandarbeit(tag.id) {
                            neuAnordnenFrage = tag.id
                        } else {
                            werk.neuAnordnen(tag.id, erzwingen: true)
                        }
                    }
                    Menu("Seitenmuster") {
                        Button("Automatisch wählen") { musterSetzen(nil) }
                        Divider()
                        ForEach(Seitenmuster.allCases) { muster in
                            Button {
                                musterSetzen(muster)
                            } label: {
                                if tag.muster == muster {
                                    Label(muster.name, systemImage: "checkmark")
                                } else {
                                    Text(muster.name)
                                }
                            }
                        }
                    }
                    Divider()
                    Button("Seite anfügen", systemImage: "plus.rectangle.on.rectangle") {
                        werk.seiteHinzufuegen(tag.id)
                    }
                }
                Button("Alle unberührten Tage neu anordnen", systemImage: "arrow.clockwise") {
                    werk.alleNeuAnordnen(nurUnberuehrte: true)
                }
                Divider()
                Toggle("Satzspiegel zeigen", isOn: $werk.zeigeSatzspiegel)
                // Einrasten lässt sich abschalten — die zweite Hälfte des
                // Wunsches nach einem Randindikator, der „im Einzelfall auch
                // veränderbar" ist. Eine Hilfe, aus der man nicht aussteigen
                // kann, ist eine Bevormundung; der genaue Wert in
                // Millimetern steht daneben im Inspektor unter „Lage".
                // `@AppStorage` gehört in eine View und nie ins `Reisewerk`.
                Toggle("An Rand und Nachbarn einrasten", isOn: $einrastenAn)
                Toggle("Bedienung prüfen", isOn: $werk.zeigeGriffprobe)
                // Der Befund wird abgetippt oder abfotografiert, solange er
                // nur auf der Seite steht — und eine Messung, die man
                // abschreiben muss, kommt verkürzt an. Dieselbe Bauweise
                // wie bei „Zustellung prüfen" in Schulalarm: kopierbar,
                // ohne Deutung.
                Button("Befund kopieren", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string =
                        (werk.letzterGriff ?? "noch nichts gegriffen")
                        + "\n" + werk.messer.befund
                    werk.meldung = Reisewerk.Meldung(text: "Der Befund liegt in der Zwischenablage.")
                }
            } label: {
                Label("Anordnen", systemImage: "wand.and.stars")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Stil wählen…", systemImage: "paintpalette") { blatt = .stil }
                Button("Schrift und Ausrichtung…", systemImage: "textformat") {
                    blatt = .typografie
                }
                // Eigener Punkt, und zwar hier oben bei Stil und Schrift.
                // Bis 1.0.9 lag das hinter „Format, Ränder, Karte" — einem
                // Namen, der nach Papiermaßen klingt; gefunden hat es
                // niemand (gemeldet 09/2026: „Kann ich das jetzt für alle
                // Fotos global einstellen und wenn ja, wo?").
                Button("Fotos…", systemImage: "photo.stack") { blatt = .fotostil }
                Button("Textfelder…", systemImage: "text.alignleft") { blatt = .textstil }
                Button("Format, Ränder, Karte…", systemImage: "ruler") { blatt = .gestaltung }
                Button("Hintergrund…", systemImage: "square.fill.on.square.fill") {
                    blatt = .hintergrund
                }
                Divider()
                Button("Als PDF sichern…", systemImage: "square.and.arrow.up") { blatt = .ausgabe }
                Button("Buch als Datei sichern…", systemImage: "shippingbox") { buchSichern() }
            } label: {
                Label("Buch", systemImage: "book")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                inspektor.toggle()
            } label: {
                Label("Block", systemImage: "slider.horizontal.3")
            }
        }
        ToolbarItemGroup(placement: .bottomBar) {
            // Einzelseiten oder Doppelseiten. Der Umschalter steht UNTEN
            // neben den Lupen und nicht in einem Menü: Er gehört zur
            // Ansicht, und wer ihn sucht, sucht ihn dort, wo auch der
            // Maßstab liegt. Ein Knopf in einem Menü wäre einer, den
            // niemand findet.
            Picker("Ansicht", selection: $doppelseiten) {
                Image(systemName: "doc").tag(false)
                Image(systemName: "book.pages").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 104)
            Button { zoom = max(massstabJetzt * 0.8, 0.12) } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            Button("Einpassen") { zoom = 0 }
            Button { zoom = min(massstabJetzt * 1.25, 4) } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            // Die Gesten dieser Seite sind unsichtbar — ein Doppeltipp,
            // zwei Finger, acht Punkte am Rand. Deshalb steht hier ein
            // Fragezeichen und nicht in einem Menü: Wer nicht weiß, wie
            // etwas geht, klappt kein Menü auf, in dem er es vermutet.
            Button {
                blatt = .bedienung
            } label: {
                Label("Bedienung", systemImage: "questionmark.circle")
            }
            Spacer()
            // Solange ein Textfeld offen ist, steht hier der Weg heraus.
            // Bis 1.0.8 gab es keinen: Man musste daneben tippen, und traf
            // man dabei einen anderen Textblock, ging gleich das nächste
            // Feld auf. Ein Zustand ohne sichtbaren Ausgang ist für den
            // Menschen davor ein hängengebliebenes Programm.
            if werk.textBearbeitung != nil {
                Button {
                    werk.textBearbeitung = nil
                } label: {
                    Label("Text fertig", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            // Ist ein Foto gewählt, steht hier der kürzeste Weg zu seiner
            // Unterschrift. Eine Geste, die niemand kennt (der Doppeltipp),
            // ist so wenig wert wie ein Schalter, den niemand findet —
            // deshalb beides.
            if let fotoID = gewaehlterBlock?.fotoID {
                Button {
                    werk.unterschriftOeffnen(fotoID)
                } label: {
                    Label("Bildunterschrift", systemImage: "text.bubble")
                }
            }
            // Steht die Marke auf der Seite, steht hier der Knopf dazu. Ein
            // Hinweis ohne Weg, ihn aufzulösen, ist die Frage von vorhin
            // noch einmal.
            if werk.textUeberlauf != nil, let id = werk.gewaehlterBlock {
                Button {
                    werk.hoeheAnTextAnpassen(id)
                } label: {
                    Label("Rahmen an Text anpassen", systemImage: "arrow.down.to.line")
                }
                .tint(.orange)
                // Der zweite Weg aus demselben Befund: Was nicht
                // hineinpasst, muss nicht in DIESEN Kasten — es kann auf
                // der nächsten Seite weitergehen. Auf einer vollen Seite
                // ist das der einzige, der bleibt.
                if let gewaehlt = gewaehlterBlock, werk.teilbar(gewaehlt) {
                    Button {
                        werk.textTeilen(id)
                    } label: {
                        Label("Rest auf die nächste Seite",
                              systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    .tint(.orange)
                }
            }
            if let tag = werk.tag {
                Button {
                    blatt = .tagInhalt(tag.id)
                } label: {
                    Label("Text und Fotos des Tages", systemImage: "square.and.pencil")
                }
                Button {
                    blatt = .spur(tag.id)
                } label: {
                    Label("Reisepunkte", systemImage: "mappin.and.ellipse")
                }
            }
        }
    }

    // Der Maßstab, der GERADE gilt. Bis 1.0.16 stand hier bei
    // eingepasster Ansicht die feste 0,7 — eine Schätzung, und die Lupen
    // sprangen damit auf einen Wert, der mit dem Bild auf dem Schirm
    // nichts zu tun hatte. Jetzt ist es der gemessene eingepasste Maßstab.
    private var massstabJetzt: Double { zoom == 0 ? passenderMassstab : zoom }

    // DER GEWÄHLTE BLOCK WIRD EINMAL GESUCHT, NICHT ZWEIMAL.
    //
    // `werk.block(_:)` geht durch alle Tage, Seiten und Blöcke. Die
    // Werkzeugleiste zeichnet sich bei jeder Meldung des `Reisewerk`s neu
    // — beim Schieben eines Blocks also bei jedem Bildpunkt. In 1.0.14
    // standen hier zwei solche Suchläufe nebeneinander; einer reicht.
    private var gewaehlterBlock: Block? {
        guard let id = werk.gewaehlterBlock, let stelle = werk.block(id) else { return nil }
        return werk.reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block]
    }

    // Das ganze Buch als eine Datei — samt aller Bilder, zum Sichern, zum
    // Umziehen auf ein anderes Gerät und zum Weitergeben.
    private func buchSichern() {
        werk.sofortSichern()
        do {
            buchdatei = Buchwunsch(ort: try Buchdatei.schreiben(werk.reise))
        } catch {
            werk.meldung = .init(text: "Die Buchdatei ließ sich nicht schreiben: "
                                 + error.localizedDescription, schwer: true)
        }
    }

    private func musterSetzen(_ muster: Seitenmuster?) {
        guard let tag = werk.tag, let stelle = werk.tagIndex(tag.id) else { return }
        werk.merken()
        werk.reise.tage[stelle].muster = muster
        werk.reise.tage[stelle].seiten = werk.automat.seiten(fuer: werk.reise.tage[stelle])
    }

    // MARK: - Bänder

    @ViewBuilder
    private var baender: some View {
        VStack(spacing: 6) {
            if werk.ausschnittsmodus != nil {
                band("Bildausschnitt: Ziehen verschiebt das Bild im Rahmen.",
                     farbe: .accentColor) {
                    werk.ausschnittsmodus = nil
                }
            }
            if let meldung = werk.meldung {
                band(meldung.text, farbe: meldung.schwer ? .red : .secondary) {
                    werk.meldung = nil
                }
            }
            if let arbeit = werk.beschaeftigt {
                HStack(spacing: 9) {
                    ProgressView()
                    Text(arbeit).font(.footnote)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.regularMaterial, in: Capsule())
            }
        }
        .padding(.top, 8)
        .animation(.default, value: werk.meldung?.id)
    }

    private func band(_ text: String, farbe: Color, schliessen: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Text(text)
                .font(.footnote)
                .multilineTextAlignment(.leading)
            Button("Fertig", action: schliessen)
                .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(farbe.opacity(0.5)))
        .padding(.horizontal, 14)
    }

    // MARK: - Blätter

    @ViewBuilder
    private func blattInhalt(_ welches: Blatt) -> some View {
        switch welches {
        case .stil:
            StilView(werk: werk)
        case .hintergrund:
            HintergrundView(werk: werk)
        case .textimport:
            TextimportView(werk: werk)
        case .fotos:
            FotoeinfuhrView(werk: werk)
        case .dateien:
            DateieinfuhrView(werk: werk)
        case .tagesspur:
            SpurimportView(werk: werk)
        case .typografie:
            TypografieView(werk: werk)
        case .fotostil:
            FotostilView(werk: werk)
        case .textstil:
            TextstilView(werk: werk)
        case .gestaltung:
            GestaltungView(werk: werk)
        case .bedienung:
            BedienungView()
        case .ausgabe:
            AusgabeView(werk: werk)
        case let .tagInhalt(id):
            TagInhaltView(werk: werk, tagID: id)
        case let .spur(id):
            SpurView(werk: werk, tagID: id)
        case .ablage:
            AblageView(werk: werk)
        }
    }
}
