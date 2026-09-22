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
    @State private var buehnenhoehe: Double = 0
    // Wo der Inhalt gerade steht. Kein `@State` — siehe `Inhaltslage`.
    @State private var lage = Inhaltslage()
    // WÄHREND der Geste wird nicht neu gesetzt, sondern skaliert: `lupe`
    // ist der Faktor, `lupenanker` der Punkt, um den skaliert wird. Ein
    // `scaleEffect` mit Anker hält genau diesen Punkt fest — damit steht
    // der Mittelpunkt der Geste, ohne dass irgendetwas nachgerechnet
    // werden müsste. Erst am Ende wird der Maßstab wirklich gesetzt.
    @State private var lupe: Double = 1
    @State private var lupenanker: UnitPoint = .center
    // Was der Finger beim Aufsetzen gegriffen hat, und wo dieser Punkt auf
    // dem Bildschirm lag. Beides wird EINMAL bestimmt, beim ersten
    // Bildpunkt der Geste — dieselbe Regel wie beim Griff an einem Block.
    @State private var zoomgriff: Zoomanker.Griff?
    @State private var brennpunkt: CGPoint = .zero
    // Ein gewünschter MASSSTAB aus der Fußleiste. Er reist über den
    // Zustand, weil der `ScrollViewProxy` nur INNERHALB des
    // `ScrollViewReader`s gilt und die Knöpfe in der Werkzeugleiste stehen.
    // Ihn außerhalb zu merken wäre der naheliegende Weg und einer, den
    // SwiftUI nicht zusagt.
    @State private var massstabwunsch: Double?
    // Der geführte Weg „Buch aufbauen" schickt zum nächsten Blatt und
    // bekommt danach die Bühne zurück. Ein Blatt über einem Blatt wäre auf
    // dem iPad ein Kärtchen auf einem Kärtchen — deshalb macht das eine zu
    // und das nächste auf, im `onDismiss`. Dieselbe Regel wie bei den
    // Dateiwählern in Tafelbild: Der Wunsch trägt das Ziel.
    @State private var alsNaechstes: Blatt?

    // Der Wunsch trägt das Ziel, kein Schalter daneben — dieselbe Regel
    // wie bei den Dateiwählern in Tafelbild. Ein `URL` ist nicht
    // `Identifiable`, und die Zusatzkonformität einer fremden Sorte
    // aufzuzwingen wäre der teurere Weg.
    struct Buchwunsch: Identifiable {
        let id = UUID()
        let ort: URL
    }

    enum Blatt: Identifiable {
        case aufbau
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
            case .aufbau: return "aufbau"
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
        .sheet(item: $blatt, onDismiss: {
            guard let naechstes = alsNaechstes else { return }
            // Nach einem Einleseschritt geht es zurück in den Aufbau — dort
            // steht dann, was daraus geworden ist. Nach dem Aufbau selbst
            // endet die Kette.
            alsNaechstes = naechstes.id == "aufbau" ? nil : .aufbau
            blatt = naechstes
        }) { welches in
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
            // Der Leser gibt den einzigen Weg her, mit dem sich ein
            // SwiftUI-`ScrollView` unter iOS 17 gezielt bewegen lässt:
            // `scrollTo` auf ein Element, mit einem Anker. Einen Versatz
            // zum Setzen gibt es nicht — deshalb rechnet `Zoomanker` den
            // Anker aus, statt eine Zahl zu schieben.
            ScrollViewReader { leser in
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
                    LazyVStack(spacing: Buehnenmasse.fuge) {
                        if doppelseiten {
                            bogenliste
                        } else {
                            einzelseiten
                        }
                    }
                    .padding(Buehnenmasse.rand)
                    .frame(maxWidth: .infinity)
                    // Wo der Inhalt steht und wie groß er ist. Gelesen im
                    // KÖRPER des `GeometryReader`s und in ein Merkfeld
                    // geschrieben — nicht über `@State` und nicht über eine
                    // Preference: Beides schriebe bei jedem Bildpunkt des
                    // Scrollens einen Zustand und zeichnete damit die ganze
                    // Bühne neu (die Lehre aus 1.0.16).
                    .background(
                        GeometryReader { raster in
                            let _ = lage.merken(raster.frame(in: .named(Self.buehnenraum)))
                            Color.clear
                        }
                    )
                    // Der Zoom WÄHREND der Geste ist eine reine Skalierung um
                    // den Punkt, auf den die Finger zeigen. Damit steht dieser
                    // Punkt fest, ohne dass etwas gerechnet wird — und die
                    // Seiten werden nicht bei jedem Bildpunkt neu gesetzt.
                    .scaleEffect(lupe, anchor: lupenanker)
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
                    .gesture(seitenzoom(leser),
                             including: seitenzoomErlaubt ? .all : .subviews)
                }
                .coordinateSpace(.named(Self.buehnenraum))
                .background(Self.leinwand)
                // Die Lupen können den Leser nicht selbst erreichen; sie
                // legen ihren Wunsch hier ab.
                .onChange(of: massstabwunsch) { _, wunsch in
                    guard let wunsch else { return }
                    massstabwunsch = nil
                    massstabSetzen(wunsch, leser: leser)
                }
            }
            // Gemessen wird das Sichtfeld EINMAL je Änderung, nicht im
            // Körper: Ein `@State`, das während des Zeichnens geschrieben
            // wird, löst das nächste Zeichnen aus.
            .onChange(of: raum.size, initial: true) { _, groesse in
                buehnenbreite = groesse.width
                buehnenhoehe = groesse.height
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
            VStack(spacing: Buehnenmasse.beschriftungsabstand) {
                SeitenflaecheView(werk: werk, buchseite: buchseite, massstab: massstabJetzt)
                // FESTE Höhe, und das ist keine Kosmetik: `Zoomanker`
                // rechnet mit ihr. Eine Zeile, die sich ihre Höhe selbst
                // sucht, wäre in dieser Rechnung eine Schätzung.
                Text("Seite \(buchseite.nummer)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(height: Buehnenmasse.beschriftung)
            }
            // Die Kennung, auf die `scrollTo` zielt.
            .id("blatt-\(buchseite.id)")
        }
        if seiten.isEmpty { hinweisLeer }
    }

    @ViewBuilder
    private var bogenliste: some View {
        let bogen = werk.sichtbareDoppelseiten
        ForEach(bogen) { einer in
            DoppelseiteView(werk: werk, bogen: einer, massstab: massstabJetzt)
                .id("bogen-\(einer.bogen)")
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
            Button("Buch aufbauen") { blatt = .aufbau }
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
    // „Eine Zwei-Finger-Geste auf die Seite wäre mir lieber.") — und seit
    // 1.0.18 um den MITTELPUNKT der Geste (Ansage des Nutzers 09/2026).
    //
    // Zwei Hälften: Solange die Finger auf dem Glas sind, skaliert ein
    // `scaleEffect` mit Anker; danach wird der Maßstab gesetzt und der
    // Inhalt so gerollt, dass derselbe Punkt wieder unter dem Finger liegt.
    // Die erste Hälfte kann gar nicht danebenliegen — sie ist eine
    // Abbildung und keine Rechnung. Die zweite ist die Rechnung, und sie
    // fällt genau einmal an statt sechzigmal in der Sekunde.
    private func seitenzoom(_ leser: ScrollViewProxy) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { wert in
                if zoomAnfang == nil { gesteBeginnen(wert) }
                let anfang = zoomAnfang ?? massstabJetzt
                // `magnification` ist die GESAMTE Bewegung seit dem
                // Aufsetzen — gerechnet wird vom Anfangswert aus, sonst
                // beschleunigt der Zoom mit jedem Bildpunkt (die Lehre aus
                // 1.0.8, und dort stand sie schon zweimal).
                lupe = gedeckelt(anfang * wert.magnification) / anfang
            }
            .onEnded { wert in
                let anfang = zoomAnfang ?? massstabJetzt
                let neu = gedeckelt(anfang * wert.magnification)
                lupe = 1
                lupenanker = .center
                zoomAnfang = nil
                if let gegriffen = zoomgriff {
                    zoomAuf(neu, griff: gegriffen, brennpunkt: brennpunkt, leser: leser)
                } else {
                    zoom = neu
                }
                zoomgriff = nil
            }
    }

    private func gesteBeginnen(_ wert: MagnifyGesture.Value) {
        let anfang = massstabJetzt
        zoomAnfang = anfang
        let inhalt = lage.groesse
        zoomgriff = massstaebe.griff(bei: wert.startLocation, inhalt: inhalt,
                                     massstab: anfang)
        brennpunkt = CGPoint(x: lage.ursprung.x + wert.startLocation.x,
                             y: lage.ursprung.y + wert.startLocation.y)
        // Der Anker wird SELBST gerechnet und nicht aus `startAnchor`
        // genommen: Worauf sich diese Zahl genau bezieht, steht nirgends
        // verbindlich, und der Punkt im Inhalt ist hier ohnehin bekannt.
        lupenanker = UnitPoint(
            x: inhalt.width > 0 ? wert.startLocation.x / inhalt.width : 0.5,
            y: inhalt.height > 0 ? wert.startLocation.y / inhalt.height : 0.5
        )
    }

    private func gedeckelt(_ wert: Double) -> Double { min(max(wert, 0.12), 4) }

    // Den Maßstab setzen UND den Brennpunkt halten.
    private func zoomAuf(_ wunsch: Double, griff: Zoomanker.Griff, brennpunkt: CGPoint,
                         leser: ScrollViewProxy) {
        let neu = gedeckelt(wunsch)
        let anker = massstaebe.anker(
            fuer: griff, brennpunkt: brennpunkt,
            sichtfeld: CGSize(width: buehnenbreite, height: buehnenhoehe),
            massstab: neu)
        zoom = neu
        guard let elementkennung = kennung(griff.index) else { return }
        // Erst stehen lassen, dann rollen: `scrollTo` rechnet mit der
        // Größe, die das Element GERADE hat — und die entsteht erst im
        // nächsten Durchgang.
        DispatchQueue.main.async { leser.scrollTo(elementkennung, anchor: anker) }
    }

    // Ein Maßstab aus der Fußleiste wird um die MITTE des Sichtfelds
    // gesetzt, aus demselben Grund wie die Geste um ihren Mittelpunkt: Was
    // man ansieht, soll stehen bleiben.
    private func massstabSetzen(_ ziel: Double, leser: ScrollViewProxy) {
        let mitte = CGPoint(x: buehnenbreite / 2, y: buehnenhoehe / 2)
        let imInhalt = CGPoint(x: mitte.x - lage.ursprung.x, y: mitte.y - lage.ursprung.y)
        let gegriffen = massstaebe.griff(bei: imInhalt, inhalt: lage.groesse,
                                         massstab: massstabJetzt)
        zoomAuf(ziel, griff: gegriffen, brennpunkt: mitte, leser: leser)
    }

    // Die Maße, mit denen gerechnet wird. NUR aus einem Handgriff heraus
    // gelesen und nie im Körper: `sichtbareSeiten` geht über das ganze
    // Buch.
    private var massstaebe: Zoomanker {
        let bogen = werk.reise.gestaltung.bogen(werk.reise.format)
        return Zoomanker(blatthoehe: bogen.height,
                         blattbreite: bogen.width * (doppelseiten ? 2 : 1),
                         beiwerk: Buehnenmasse.beiwerk,
                         fuge: Buehnenmasse.fuge,
                         rand: Buehnenmasse.rand,
                         anzahl: doppelseiten ? werk.sichtbareDoppelseiten.count
                                              : werk.sichtbareSeiten.count)
    }

    private func kennung(_ stelle: Int) -> String? {
        if doppelseiten {
            let liste = werk.sichtbareDoppelseiten
            guard liste.indices.contains(stelle) else { return nil }
            return "bogen-\(liste[stelle].bogen)"
        }
        let liste = werk.sichtbareSeiten
        guard liste.indices.contains(stelle) else { return nil }
        return "blatt-\(liste[stelle].id)"
    }

    private static let buehnenraum = "buehne"

    // DIE LEINWAND, auf der das Blatt liegt (ab 1.0.20).
    //
    // Bis 1.0.19 war es `systemGroupedBackground` — ein sehr helles Grau,
    // und darauf ist ein weißes Blatt kaum ein Blatt. So macht es keine App,
    // die Seiten zeigt: Pages und Keynote stellen das Papier auf einen
    // deutlich dunkleren Grund, Apple Books auf einen ganz dunklen. Der
    // Grund ist kein Geschmack — nur vor einem neutralen Mittelton lässt
    // sich beurteilen, wie hell ein Foto auf dem Papier wirklich steht.
    private static let leinwand = Color(uiColor: UIColor { stil in
        stil.userInterfaceStyle == .dark
            ? UIColor(white: 0.11, alpha: 1)
            : UIColor(white: 0.82, alpha: 1)
    })

    // Über einem gewählten FOTO gehören die zwei Finger dem Bildausschnitt.
    private var seitenzoomErlaubt: Bool {
        werk.ausschnittsmodus == nil && gewaehlterBlock?.fotoID == nil
    }

    // MARK: - Werkzeuge
    //
    // DIE MENÜS BEANTWORTEN JE EINE FRAGE (ab 1.0.20, Befund des Nutzers
    // 09/2026: „Ich finde, dass viele Funktionen nicht selbsterklärend in
    // verschachtelten Menüs abgelegt wurden.").
    //
    // Bis 1.0.19 standen oben drei gleich aussehende Menüs — „Einlesen",
    // „Anordnen", „Buch" —, und wo etwas lag, ergab sich aus der Geschichte
    // und nicht aus der Sache: Der Satzspiegel (eine Ansichtssache) lag
    // unter „Anordnen", das PDF (eine Ausgabe) unter „Buch" neben der
    // Stilwahl, und die Sachen DIESES Tages verteilten sich auf zwei Menüs
    // und die Fußleiste. Jetzt gibt es vier Orte, und jeder beantwortet
    // genau eine Frage:
    //
    // * `+`   — Was kommt ins Buch hinein?
    // * Pinsel — Wie sieht das Buch aus?
    // * `…`   — Alles Seltene: ausgeben, prüfen, Hilfen.
    // * „Tag" unten — Alles zu DIESEM Tag, an einer Stelle.
    //
    // **Nichts steht an zwei Stellen.** Wer eine Funktion hinzufügt, sucht
    // zuerst die Frage, die sie beantwortet, und hängt sie dorthin.
    @ToolbarContentBuilder
    private var werkzeuge: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                werk.sofortSichern()
                regal.schliessen()
            } label: {
                Label("Bücher", systemImage: "chevron.left")
            }
        }
        ToolbarItem(placement: .topBarLeading) {
            // „Zurück" hieß dieser Knopf bis 1.0.19 — direkt neben einem
            // Zurück-Pfeil, der das Buch schließt. Zwei Dinge mit demselben
            // Wort sind eines zu viel.
            Button {
                werk.zurueck()
            } label: {
                Label("Widerrufen", systemImage: "arrow.uturn.backward")
            }
            .disabled(!werk.kannZurueck)
        }

        ToolbarItem(placement: .topBarTrailing) { hinzufuegenMenue }
        ToolbarItem(placement: .topBarTrailing) { gestaltenMenue }
        ToolbarItem(placement: .topBarTrailing) { mehrMenue }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                inspektor.toggle()
            } label: {
                Label("Ausgewähltes", systemImage: "slider.horizontal.3")
            }
        }

        ToolbarItemGroup(placement: .bottomBar) {
            // Einzelseiten oder Doppelseiten. Der Umschalter steht UNTEN und
            // nicht in einem Menü: Er gehört zur Ansicht, und wer ihn sucht,
            // sucht ihn dort, wo auch der Maßstab liegt.
            Picker("Ansicht", selection: $doppelseiten) {
                Image(systemName: "doc").tag(false)
                Image(systemName: "book.pages").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 104)

            // EIN Maßstab-Knopf statt Lupe-minus, „Einpassen" und Lupe-plus
            // (Ansage des Nutzers 09/2026: „Es ist auch nicht nötig, Funktionen
            // doppelt auszustatten, wie zum Beispiel das Zoomen mit der
            // Fingergeste … und trotzdem noch die Plus-Minus-Buttons zu
            // belassen."). Stufenweises Zoomen können zwei Finger besser; was
            // sie NICHT können, ist ein bestimmter Maßstab — und genau das
            // steht hier. Die Beschriftung ist zugleich die Auskunft, wie groß
            // die Seite gerade steht.
            Menu {
                Button("Einpassen", systemImage: "arrow.down.forward.and.arrow.up.backward") {
                    zoom = 0
                }
                Button("100 % (Originalgröße)", systemImage: "1.square") { massstabwunsch = 1 }
            } label: {
                Text(massstabtext)
                    .font(.subheadline.monospacedDigit())
            }

            // Die Gesten dieser Seite sind unsichtbar — ein Doppeltipp, zwei
            // Finger, acht Punkte am Rand. Deshalb steht hier ein Fragezeichen
            // und nicht in einem Menü: Wer nicht weiß, wie etwas geht, klappt
            // kein Menü auf, in dem er es vermutet.
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

            tagMenue
        }
    }

    // WAS KOMMT INS BUCH HINEIN?
    private var hinzufuegenMenue: some View {
        Menu {
            // Zuerst der geführte Weg: Er sagt, in welcher Reihenfolge die
            // drei Schritte zusammengehören, und zeigt hinterher, was
            // zugeordnet wurde.
            Button("Buch aufbauen…", systemImage: "wand.and.sparkles") { blatt = .aufbau }
            Divider()
            Button("Tagebuchtext…", systemImage: "text.book.closed") { blatt = .textimport }
            Button("Fotos aus der Mediathek…", systemImage: "photo.on.rectangle") {
                blatt = .fotos
            }
            Button("Bilder aus Dateien…", systemImage: "folder") { blatt = .dateien }
            Button("Reisespur…", systemImage: "point.topleft.down.curvedto.point.bottomright.up") {
                blatt = .tagesspur
            }
            Divider()
            Button {
                blatt = .ablage
            } label: {
                // Die Zahl gehört auf den Eintrag: Fotos ohne Tag liegen
                // sonst unbemerkt in der Ablage.
                Label(werk.reise.heimatlose.isEmpty
                      ? "Fotoablage…"
                      : "Fotoablage (\(werk.reise.heimatlose.count))…",
                      systemImage: "tray")
            }
        } label: {
            Label("Hinzufügen", systemImage: "plus")
        }
    }

    // WIE SIEHT DAS BUCH AUS?
    private var gestaltenMenue: some View {
        Menu {
            Button("Stil wählen…", systemImage: "paintpalette") { blatt = .stil }
            Button("Schrift und Ausrichtung…", systemImage: "textformat") { blatt = .typografie }
            Button("Fotos…", systemImage: "photo.stack") { blatt = .fotostil }
            Button("Textfelder…", systemImage: "text.alignleft") { blatt = .textstil }
            Button("Seitenhintergrund…", systemImage: "square.fill.on.square.fill") {
                blatt = .hintergrund
            }
            Divider()
            Button("Format, Ränder, Karte…", systemImage: "ruler") { blatt = .gestaltung }
        } label: {
            Label("Gestalten", systemImage: "paintbrush")
        }
    }

    // ALLES SELTENE.
    private var mehrMenue: some View {
        Menu {
            Button("Als PDF sichern…", systemImage: "square.and.arrow.up") { blatt = .ausgabe }
            Button("Buch als Datei sichern…", systemImage: "shippingbox") { buchSichern() }
            Divider()
            Button("Alle unberührten Tage neu anordnen", systemImage: "arrow.clockwise") {
                werk.alleNeuAnordnen(nurUnberuehrte: true)
            }
            Divider()
            Section("Hilfen beim Anordnen") {
                Toggle("Satzspiegel zeigen", isOn: $werk.zeigeSatzspiegel)
                // Einrasten lässt sich abschalten — die zweite Hälfte des
                // Wunsches nach einem Randindikator, der „im Einzelfall auch
                // veränderbar" ist. Eine Hilfe, aus der man nicht aussteigen
                // kann, ist eine Bevormundung; der genaue Wert in
                // Millimetern steht daneben im Inspektor unter „Lage".
                // `@AppStorage` gehört in eine View und nie ins `Reisewerk`.
                Toggle("An Rand und Nachbarn einrasten", isOn: $einrastenAn)
            }
            Divider()
            Section("Prüfen") {
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
            }
        } label: {
            Label("Mehr", systemImage: "ellipsis.circle")
        }
    }

    // ALLES ZU DIESEM TAG — an EINER Stelle.
    //
    // Bis 1.0.19 lagen „Text und Fotos" und „Reisepunkte" als zwei Knöpfe in
    // der Fußleiste, das Neuanordnen und das Seitenmuster dagegen oben unter
    // „Anordnen". Dass beides denselben Tag betrifft, war nirgends zu sehen.
    @ViewBuilder
    private var tagMenue: some View {
        if let tag = werk.tag {
            Menu {
                Button("Text und Fotos…", systemImage: "square.and.pencil") {
                    blatt = .tagInhalt(tag.id)
                }
                Button("Reisepunkte…", systemImage: "mappin.and.ellipse") {
                    blatt = .spur(tag.id)
                }
                Divider()
                Button("Seiten neu anordnen", systemImage: "wand.and.stars") {
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
                Button("Seite anfügen", systemImage: "plus.rectangle.on.rectangle") {
                    werk.seiteHinzufuegen(tag.id)
                }
            } label: {
                Label(tag.datum.kurz, systemImage: "calendar")
            }
        }
    }

    private var massstabtext: String {
        "\(Int((massstabJetzt * 100).rounded())) %"
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
        case .aufbau:
            AufbauView(werk: werk) { ziel in alsNaechstes = ziel }
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
