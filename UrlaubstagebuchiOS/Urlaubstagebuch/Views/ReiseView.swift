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
    // Inhalt und Versatz BEIM AUFSETZEN — für die Probe.
    //
    // Gemessen 09/2026: Der Befund nannte „Inhalt 570×423", während der
    // Rahmen 1046 breit war. `lage` wird durch den `scaleEffect` hindurch
    // gemessen, und am ENDE der Geste steht dort die skalierte Größe. Beim
    // Aufsetzen ist `lupe` noch 1, also stimmt sie — dort wird sie gemerkt.
    // **Eine Probe, die ihre eigene Zahl verzerrt, ist schlimmer als keine.**
    @State private var zoominhalt: CGSize = .zero
    @State private var zoomversatz: CGPoint = .zero
    // Wo der Inhalt nach dem Zoomen stehen MÜSSTE (ab 1.0.24). Gemessen
    // wird dieselbe Zahl kurz danach in `lage.ursprung` — erst der
    // Vergleich sagt, ob `scrollTo` den Anker einlöst. Bis 1.0.23 war das
    // eine Erwartung aus der Dokumentation und stand als offener Punkt da.
    @State private var zoomsoll: CGPoint?
    // Ein gewünschter MASSSTAB aus der Fußleiste. Er reist über den
    // Zustand, weil der `ScrollViewProxy` nur INNERHALB des
    // `ScrollViewReader`s gilt und die Knöpfe in der Werkzeugleiste stehen.
    // Ihn außerhalb zu merken wäre der naheliegende Weg und einer, den
    // SwiftUI nicht zusagt.
    @State private var massstabwunsch: Double?
    // Wohin nach einem Zoom gerollt werden soll. Ein eigener Zustand und
    // kein Aufruf aus der Geste heraus — siehe `onChange(of: rollwunsch)`.
    @State private var rollwunsch: Rollwunsch?
    // Die laufende Nummer sorgt dafür, dass zwei gleiche Wünsche
    // hintereinander BEIDE ankommen: `onChange` meldet sich nur bei einer
    // Änderung, und zweimal derselbe Anker wäre keine.
    @State private var rollnummer = 0
    // WELCHE REIHEN GERADE IM BILD STEHEN (ab 1.0.28) — Reihennummer auf
    // Tageskennung. Seit alle Seiten untereinanderstehen, ist die Frage
    // „welcher Tag ist gewählt" nicht mehr die Frage „was wird gezeigt",
    // sondern „worauf zielt das Tagesmenü unten rechts". Und die muss dem
    // folgen, was man sieht: Wer zum 6. August scrollt und dann „Seiten neu
    // anordnen" tippt, meint den 6. August und nicht den Tag, den er vor
    // zehn Minuten in der Liste angetippt hat.
    //
    // Gemeldet wird über `onAppear`/`onDisappear` der Reihen und nicht aus
    // dem Rollversatz: Das fällt genau EINMAL je Reihe an und nicht bei
    // jedem Bildpunkt — dieselbe Überlegung, aus der `Inhaltslage` kein
    // `@State` ist (die Lehre aus 1.0.16).
    @State private var imBlick: [Int: UUID] = [:]
    // Und dasselbe für die SEITEN: welche Blätter in einer Reihe liegen
    // (ab 1.0.61). Daraus folgt die vorgewählte Seite — dieselbe Regel wie
    // beim gewählten Tag seit 1.0.28: Was oben im Bild steht, ist gemeint.
    // Ein Tipp auf ein Blatt wählt es ausdrücklich und schlägt die Vorwahl.
    @State private var seitenImBlick: [Int: [UUID]] = [:]
    // Der geführte Weg „Buch aufbauen" schickt zum nächsten Blatt und
    // bekommt danach die Bühne zurück. Ein Blatt über einem Blatt wäre auf
    // dem iPad ein Kärtchen auf einem Kärtchen — deshalb macht das eine zu
    // und das nächste auf, im `onDismiss`. Dieselbe Regel wie bei den
    // Dateiwählern in Tafelbild: Der Wunsch trägt das Ziel.
    @State private var alsNaechstes: Blattwunsch?

    // DER WUNSCH TRÄGT DAS ZIEL — UND OB ES ZURÜCKGEHT (ab 1.0.77).
    //
    // Bis 1.0.76 stand hier nur das Ziel, und die Rückkehr wurde im
    // `onDismiss` erschlossen: Alles außer dem Aufbau selbst führte
    // wieder dorthin zurück. Das trug, solange nur der geführte Weg
    // sprang. Das Handbuch springt aber auch — und von dort soll es
    // NICHT in den Aufbau weitergehen. Ein Schalter daneben wäre der
    // naheliegende Griff und der falsche (Regel seit 1.0.9): Der Wunsch
    // trägt beides.
    struct Blattwunsch {
        var ziel: Blatt
        /// Ob nach dem Ziel wieder der Aufbau kommt. Beim geführten Weg
        /// ja, bei einem Sprung aus dem Handbuch nein.
        var zurueckZumAufbau: Bool = false
    }

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
        case wasserzeichen
        case textimport
        case fotos
        case dateien
        // Ein Bild von Hand auf die gewählte Seite (ab 1.0.61) — nicht zu
        // verwechseln mit `.dateien`: Das ist die Fotoeinfuhr, die Tagen
        // zuordnet und nach Datum und Ort fragt.
        case grafik
        case bildAusFotos
        case tagesspur
        case typografie
        case fotostil
        case textstil
        // DIE KARTEN HABEN EINEN EIGENEN MENÜPUNKT (ab 1.0.79). Warum,
        // steht an `KartenstilView`: Bis 1.0.78 lagen sie in der Gestaltung,
        // und deren Menüpunkt heißt seit 1.0.77 nach den Druckzugaben.
        case kartenstil
        case gestaltung
        case umschlag
        case seitenformat
        case bedienung
        case ausgabe
        case ausgabeformat
        case druckpruefung
        case vorlagen
        case handbuch
        case zweiDateien
        case nurUmschlag
        case doppelseiten
        case broschuere
        case neuverteilen
        case tagInhalt(UUID)
        case spur(UUID)
        case seiten(UUID)
        case ablage

        var id: String {
            switch self {
            case .aufbau: return "aufbau"
            case .stil: return "stil"
            case .hintergrund: return "hintergrund"
            case .wasserzeichen: return "wasserzeichen"
            case .textimport: return "text"
            case .fotos: return "fotos"
            case .dateien: return "dateien"
            case .grafik: return "grafik"
            case .bildAusFotos: return "bildausfotos"
            case .tagesspur: return "tagesspur"
            case .typografie: return "typo"
            case .fotostil: return "fotostil"
            case .textstil: return "textstil"
            case .kartenstil: return "kartenstil"
            case .gestaltung: return "gestaltung"
            case .umschlag: return "umschlag"
            case .seitenformat: return "format"
            case .bedienung: return "bedienung"
            case .ausgabe: return "ausgabe"
            case .ausgabeformat: return "ausgabeformat"
            case .druckpruefung: return "druckpruefung"
            case .vorlagen: return "vorlagen"
            case .handbuch: return "handbuch"
            case .zweiDateien: return "zweidateien"
            case .nurUmschlag: return "nurumschlag"
            case .doppelseiten: return "doppelseiten"
            case .broschuere: return "broschuere"
            case .neuverteilen: return "neuverteilen"
            case let .tagInhalt(id): return "tag-\(id)"
            case let .spur(id): return "spur-\(id)"
            case let .seiten(id): return "seiten-\(id)"
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
        .sheet(item: $blatt, onDismiss: {
            guard let wunsch = alsNaechstes else { return }
            // Nach einem Einleseschritt geht es zurück in den Aufbau — dort
            // steht dann, was daraus geworden ist. Ein Sprung aus dem
            // Handbuch endet dagegen an seinem Ziel.
            if wunsch.zurueckZumAufbau {
                alsNaechstes = Blattwunsch(ziel: .aufbau)
            } else {
                alsNaechstes = nil
            }
            blatt = wunsch.ziel
        }) { welches in
            blattInhalt(welches)
        }
        .sheet(item: $buchdatei) { wunsch in
            Teilenblatt(gegenstaende: [wunsch.ort])
        }
        // Wer aus dem Inspektor heraus ein Blatt öffnet (etwa „Für alle
        // Fotos einstellen"), soll nicht ein Blatt über einem Popover
        // bekommen. Verglichen wird die Kennung und nicht der Fall selbst:
        // `Blatt` trägt assoziierte Werte, und `onChange` verlangt
        // Gleichheit.
        .onChange(of: blatt?.id) { _, neu in
            if neu != nil { inspektor = false }
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
        // NACHSEHEN, OB DIE BILDER DA SIND — UND SIE ANSTOSSEN (ab 1.0.71).
        // Wie oft und wie lange, entscheidet `Reisewerk.bilderPruefen`; hier
        // wird es nur angestoßen, wenn ein Buch aufgeht.
        .task(id: werk.reise.id) { werk.bilderPruefen() }
    }

    // MARK: - Bühne

    private var buehne: some View {
        GeometryReader { raum in
            // Wie oft die BÜHNE selbst neu aufgebaut wird. Sie trägt
            // `lupe`, wird also während der Zoomgeste bei jedem Bildpunkt
            // durchlaufen — das ist gewollt und billig, solange die
            // Seiten darin verglichen werden statt neu gebaut (siehe
            // `SeitenflaecheView.==`). Ob das so ist, sagt der Vergleich
            // dieser Zahl mit „Seite" im Befund.
            let _ = werk.messer.melde("B\u{00FC}hne")
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
                    .frame(width: inhaltsbreite, alignment: .center)
                    // DIE GESTE BRAUCHT FLÄCHE (ab 1.0.23, gemessen am Befund
                    // des Nutzers 09/2026: „Inhalt 1046×429 · Bühne 1046×864").
                    //
                    // Die Zweifingergeste hängt am INHALT. Steht die Seite
                    // klein, ist der Inhalt kleiner als das Sichtfeld — bei
                    // 25 % deckte er die oberen 429 von 864 Punkten ab, und
                    // darunter lag nackte Leinwand OHNE Geste. Wer in der
                    // Mitte des Bildschirms aufzieht, greift also ins Leere.
                    // **Die Falle zieht sich zu, je kleiner man zoomt** —
                    // genau der gemeldete Zustand: „klein gezoomt und kann sie
                    // nicht wieder größer bekommen." Dasselbe erklärt das
                    // `hoch 1.00` im Befund: Der Finger lag an der Unterkante
                    // des Inhalts, also außerhalb des Blattes.
                    //
                    // Der Inhalt ist deshalb mindestens so hoch wie das
                    // Sichtfeld. **Oben ausgerichtet**, nicht mittig: Die
                    // Lagen der Elemente gehen in `Zoomanker` ein, und eine
                    // senkrechte Zentrierung verschöbe jede davon.
                    .frame(minHeight: buehnenhoehe > 0 ? CGFloat(buehnenhoehe) : nil,
                           alignment: .top)
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
                    //
                    // `simultaneousGesture` UND NICHT `gesture` (ab 1.0.28;
                    // gemeldet 09/2026: „Die Geste müsste eigentlich allein
                    // der Seite gehören, aber trotzdem muss ich mehrere Male
                    // anfassen.").
                    //
                    // Über dieser Ansicht liegt der `ScrollView` und damit
                    // dessen Schiebeerkenner, und der beginnt schon bei EINEM
                    // Finger. Zwei Finger auf einer Rollfläche sind für ihn
                    // ein Wisch; ohne ausdrückliche Erlaubnis zur
                    // GLEICHZEITIGEN Erkennung muss einer der beiden
                    // verlieren, und welcher, entscheiden die ersten
                    // Millisekunden der Bewegung. Genau das ist „mal beim
                    // ersten, mal beim dritten Versuch".
                    //
                    // Das ist keine Vermutung, sondern ein Vergleich IN
                    // DIESER App: `SeitenflaecheView` hängt den Zoom des
                    // Bildausschnitts seit 1.0.8 mit `simultaneousGesture`
                    // in denselben `ScrollView` — dieselbe Gestenart, dieselbe
                    // Rollfläche —, und der greift. Der Unterschied zwischen
                    // beiden ist dieses eine Wort.
                    .simultaneousGesture(seitenzoom,
                                         including: seitenzoomErlaubt ? .all : .subviews)
                }
                .coordinateSpace(.named(Self.buehnenraum))
                .background(Self.leinwand)
                // WELCHE LINIE WAS BEDEUTET, steht über der Bühne (ab
                // 1.0.80). Gefragt 09/2026: „Auf dem Beispielbild sind noch
                // weitere Linien zu sehen. Welche sind das denn eigentlich?"
                //
                // Es gab die Legende — in der Skizze unter „Ränder und
                // Druckzugaben", also dort, wo man die Zahlen einstellt und
                // nicht dort, wo man die Linien sieht. Sie steht jetzt
                // beides: hier, solange die Linien an sind, und dort
                // weiterhin bei den Zahlen.
                //
                // Als ÜBERLAGERUNG und nicht als Zeile im Stapel: Eine
                // Zeile nähme der Bühne Höhe, und `buehnenhoehe` geht in
                // die Zoomrechnung ein. `allowsHitTesting(false)`, damit
                // sie keine Geste schluckt — die Lehre aus 1.1.18 der
                // Abfahrtstafel.
                .overlay(alignment: .top) {
                    if werk.zeigeSatzspiegel { Linienlegende() }
                }
                // Die Lupen können den Leser nicht selbst erreichen; sie
                // legen ihren Wunsch hier ab.
                .onChange(of: massstabwunsch) { _, wunsch in
                    guard let wunsch else { return }
                    massstabwunsch = nil
                    massstabSetzen(wunsch)
                }
                // ERST DIE NEUE LAGE, DANN ROLLEN (ab 1.0.22).
                //
                // Bis 1.0.21 stand das `scrollTo` in einem
                // `DispatchQueue.main.async` MITTEN im Gestenrückruf. Dort
                // ist die Reihenfolge nicht zugesagt: Der Block wandert
                // sofort in die Hauptschlange, die Zustandsänderung
                // `zoom = neu` dagegen löst einen Durchgang von SwiftUI
                // aus — läuft der Block davor, rechnet `scrollTo` mit der
                // ALTEN Größe des Elements und rollt an eine Stelle, die
                // mit dem neuen Maßstab nichts zu tun hat. Genau so sieht
                // „springt in irgendeine Position" aus. Der Wunsch reist
                // deshalb durch den Zustand: `onChange` läuft garantiert
                // NACH dem Durchgang, der ihn gesetzt hat, und der eine
                // Sprung darin nach dessen Layout.
                .onChange(of: rollwunsch) { _, wunsch in
                    guard let wunsch else { return }
                    rollwunsch = nil
                    DispatchQueue.main.async {
                        leser.scrollTo(wunsch.kennung, anchor: wunsch.anker)
                        // Und danach die Gegenprobe: Steht der Inhalt dort,
                        // wo er stehen sollte? Einmal je Zoom, nicht laufend.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            sollIstNachtragen()
                        }
                    }
                }
            }
            // Gemessen wird das Sichtfeld EINMAL je Änderung, nicht im
            // Körper: Ein `@State`, das während des Zeichnens geschrieben
            // wird, löst das nächste Zeichnen aus.
            .onChange(of: raum.size, initial: true) { _, groesse in
                buehnenbreite = groesse.width
                buehnenhoehe = groesse.height
            }
            // Ein Tipp in der Tagesliste ROLLT zu diesem Tag (ab 1.0.28).
            .onChange(of: werk.gewaehlterTag) { _, _ in springeZuGewaehltem() }
            // Ein Sprung zu einem Befund der Druckprüfung (ab 1.0.93).
            .onChange(of: werk.sprungZuSeite) { _, _ in springeZuBefund() }
            // Passt ein Textkasten nach dem Ziehen wieder, gehört seine
            // rote Marke weg. `textUeberlauf` misst genau diesen Übergang
            // und wird ohnehin je Änderung gerechnet (seit 1.0.8) — hier
            // kostet die Auffrischung also nur einen Lauf je Umschlag, und
            // auch den nur, solange die Marken gezeigt werden.
            .onChange(of: werk.textUeberlauf) { _, _ in werk.befundeAuffrischen() }
            // Und umgekehrt: Was oben im Bild steht, ist der gewählte Tag.
            .onChange(of: tagImBlick) { _, neu in
                guard let neu, neu != werk.gewaehlterTag else { return }
                werk.gewaehlterTag = neu
            }
            // Einzelseiten und Doppelseiten zählen ihre Reihen VERSCHIEDEN
            // (Seitenzahl gegen Bogennummer). Beim Umschalten ist die alte
            // Meldung deshalb nicht bloß veraltet, sondern falsch.
            .onChange(of: doppelseiten) { _, _ in
                imBlick.removeAll()
                seitenImBlick.removeAll()
            }
            // Die Vorwahl folgt dem Bild — aber nur, wenn die gewählte
            // Seite gar nicht mehr zu sehen ist. Sonst nähme das Scrollen
            // innerhalb einer Doppelseite dem Nutzer das Blatt weg, das er
            // eben angetippt hat.
            .onChange(of: seitenImBlick) { _, _ in seitenvorwahl() }
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
                // AN WELCHER KANTE KEIN ANSCHNITT LIEGT, sagt die
                // Gestaltung (ab 1.0.85): Ist er am Bund abgeschaltet,
                // hört das Blatt dort am Endformat auf — und mit ihm die
                // rote Schnittkante. Entschieden wird das HIER und nicht
                // in der Seitenfläche, weil die Doppelseitenansicht die
                // Kante immer offen hat und `==` den Wert vergleicht.
                SeitenflaecheView(werk: werk, buchseite: buchseite,
                                  bogenkante: werk.reise.gestaltung
                                      .offeneKante(buchseite.bundlage),
                                  massstab: massstabJetzt)
                    // Ohne `.equatable()` baut die Zweifingergeste jede
                    // sichtbare Seite bei jedem Bildpunkt neu auf — siehe
                    // `SeitenflaecheView.==`. Wer eine dritte Aufrufstelle
                    // anlegt, hängt es mit dran.
                    .equatable()
                // FESTE Höhe, und das ist keine Kosmetik: `Zoomanker`
                // rechnet mit ihr. Eine Zeile, die sich ihre Höhe selbst
                // sucht, wäre in dieser Rechnung eine Schätzung.
                // Die Beschriftung sagt seit 1.0.61 auch, WELCHE Seite
                // gewählt ist — in der Akzentfarbe und mit Wort. Der
                // Rahmen auf dem Blatt allein reicht nicht: Wer weit
                // herausgezoomt hat, sieht zwei Blätter nebeneinander und
                // muss die Farbe nicht deuten müssen.
                Text(seitenname(buchseite))
                    .font(.caption2)
                    .foregroundStyle(seitenfarbe(buchseite))
                    .frame(height: Buehnenmasse.beschriftung)
            }
            // Die Kennung, auf die `scrollTo` zielt.
            .id("blatt-\(buchseite.id)")
            .onAppear {
                imBlick[buchseite.rang] = tageskennung(buchseite)
                seitenImBlick[buchseite.rang] = einsetzbar(buchseite)
            }
            .onDisappear {
                imBlick[buchseite.rang] = nil
                seitenImBlick[buchseite.rang] = nil
            }
        }
        if seiten.isEmpty { hinweisLeer }
    }

    @ViewBuilder
    private var bogenliste: some View {
        let bogen = werk.sichtbareDoppelseiten
        ForEach(bogen) { einer in
            DoppelseiteView(werk: werk, bogen: einer, massstab: massstabJetzt)
                .id("bogen-\(einer.bogen)")
                // Gemeldet wird die SPÄTERE der beiden Seiten. Beginnt ein
                // Tag auf der rechten Seite eines Bogens, sieht man seinen
                // Anfang — dann ist er der Tag, um den es geht.
                .onAppear {
                    imBlick[einer.bogen] = tageskennung(einer.rechts ?? einer.links)
                    seitenImBlick[einer.bogen] =
                        einsetzbar(einer.links) + einsetzbar(einer.rechts)
                }
                .onDisappear {
                    imBlick[einer.bogen] = nil
                    seitenImBlick[einer.bogen] = nil
                }
        }
        if bogen.isEmpty {
            hinweisLeer
        } else if let hinweis = ausgleichshinweis {
            // Gesagt wird es dort, wo man es sieht: In der
            // Doppelseitenansicht steht die ergänzte Seite als letzte
            // links, und rechts daneben die Innenseite des Umschlags.
            // Ohne diesen Satz fragte sich jeder, woher die Seite kommt.
            Text(hinweis)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
                .padding(.top, 8)
        }
    }

    // Gezählt wird der BUCHBLOCK, nicht die Seitenfolge: Der Umschlag ist
    // seit 1.0.52 ein eigenes Stück Papier und steht in keiner Seitenzahl.
    // Mit ihm gezählt wäre die Zahl um zwei zu hoch — und die Parität,
    // auf die es hier ankommt, bliebe zufällig richtig.
    // WOHER DIE LETZTE SEITE KOMMT (ab 1.0.60).
    //
    // Bis 1.0.59 stand hier die Meldung, der Buchblock habe eine ungerade
    // Zahl. Gemeldet wird ein Zustand, den man ändern kann — diesen kann
    // man nicht ändern: Ein Blatt hat zwei Seiten. Ergänzt wird die
    // fehlende deshalb von selbst (`Reise.seitenfolge`), und hier steht
    // nur noch, dass es geschehen ist.
    private var ausgleichshinweis: String? {
        let seiten = werk.seitenfolge
        guard seiten.contains(where: \.ausgleich) else { return nil }
        let anzahl = seiten.filter { !$0.amUmschlag }.count
        var text = "Der Buchblock hätte \(anzahl - 1) Seiten, also eine ungerade Zahl. "
        text += "Die letzte Seite ist deshalb leer ergänzt \u{2014} ein gebundenes Blatt "
        text += "hat zwei Seiten, und die letzte eines Buches ist immer eine linke. "
        text += "Sie steht so auch in der ausgegebenen Datei."
        return text
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

    // MARK: - Die Tagesliste ist eine Sprungmarke (ab 1.0.28)

    // Zu welchem Tag eine Seite gehört. Die Titelseite gehört zu keinem —
    // sie trägt die eigene Kennung, mit der auch die Liste links sie führt.
    private func tageskennung(_ seite: Buchseite?) -> UUID {
        seite?.tag?.id ?? Self.titelseitenKennung
    }

    // Der Tag, der GERADE OBEN im Bild steht. Die kleinste gemeldete
    // Reihennummer ist die oberste — die Reihen stehen untereinander und
    // sind nach Seitenzahl geordnet.
    // Welche Seite gilt, wenn etwas eingesetzt wird. Steht die bisherige
    // noch im Bild, bleibt sie; sonst wird es das oberste Blatt im Bild.
    private func seitenvorwahl() {
        let sichtbar = Set(seitenImBlick.values.flatMap { $0 })
        if let da = werk.gewaehlteSeite, sichtbar.contains(da) { return }
        // DIE REIHE IN DER MITTE ZUERST (ab 1.0.79) — dieselbe Ursache wie
        // beim gewählten Tag: Eine Reihe, die nur noch mit einem Streifen
        // am Rand hängt, ist anwesend und nicht gemeint.
        if let mitte = reiheInDerMitte(), let erste = seitenImBlick[mitte]?.first {
            werk.gewaehlteSeite = erste
            return
        }
        // Von oben nach unten die erste Reihe, die überhaupt ein Blatt
        // hergibt: Die Ausgleichsseite wird gerechnet, auf sie geht
        // nichts, und eine Vorwahl darauf wäre ein Ziel, das der nächste
        // Knopf nicht annimmt.
        for schluessel in seitenImBlick.keys.sorted() {
            if let erste = seitenImBlick[schluessel]?.first {
                werk.gewaehlteSeite = erste
                return
            }
        }
    }

    // Welche Blätter einer Reihe sich bearbeiten lassen.
    private func einsetzbar(_ buchseite: Buchseite?) -> [UUID] {
        // Der Umschlag zählt seit 1.0.64 mit: Titel- und Rückseite nehmen
        // eigene Felder an (`Umschlag.titelbloecke`, `.rueckbloecke`). Die
        // Ausgleichsseite nicht — sie wird gerechnet und gehört keinem.
        guard let buchseite, !buchseite.ausgleich else { return [] }
        return [buchseite.seite.id]
    }

    // GEZÄHLT WURDE ANWESENHEIT, GEMEINT IST SICHTBARKEIT (ab 1.0.79).
    //
    // Gemeldet 09/2026 mit Bildschirmfoto: „Das Datumsfeld hängt immer
    // mindestens einen Tag hinterher. Im Blickfeld sind eigentlich schon die
    // Seiten des 4. Augustes und auswählbar ist der 3."
    //
    // **Am Quelltext abzuzählen:** Bis 1.0.78 gewann die KLEINSTE anwesende
    // Reihennummer. Ein Bogen, der nur noch mit einem Streifen oben am
    // Bildschirmrand hängt, zählt damit genauso wie der, der den ganzen
    // Schirm füllt — und gewinnt, weil seine Nummer kleiner ist. Auf dem
    // Bildschirmfoto ist das genau zu sehen: oben der untere Zentimeter von
    // „Seiten 0 und 1", darunter vollflächig „Seiten 2 und 3", und im
    // Datumsfeld steht der Tag des ersten.
    //
    // Schlimmer noch: `onAppear` feuert in einem `LazyVStack` nicht am
    // Sichtrand, sondern am Rand des Vorbereitungsbereichs — SwiftUI baut
    // ein Stück im Voraus. Die „oberste anwesende" Reihe ist also oft eine,
    // die gar nicht zu sehen ist.
    //
    // Gewählt wird deshalb die Reihe, welche die MITTE des Sichtfelds
    // überdeckt. Gerechnet wird sie aus derselben Geometrie, an der auch der
    // Zoom hängt (`Zoomanker.griff`) — und zwar erst beim Auslösen, nicht
    // bei jedem Bildpunkt: `Inhaltslage` hat aus gutem Grund kein
    // `@Published` (die Lehre aus 1.0.16). Der Auslöser bleibt
    // `onAppear`/`onDisappear`, also etwas, das selten anfällt.
    private var tagImBlick: UUID? {
        guard !imBlick.isEmpty else { return nil }
        if let mitte = reiheInDerMitte(), let tag = imBlick[mitte] { return tag }
        // Steht die Mitte auf einer Reihe, die sich (noch) nicht gemeldet
        // hat, gilt wie bisher die oberste. Ein Rückfall und keine
        // Behauptung: Lieber der alte Stand als gar keiner.
        guard let oberste = imBlick.keys.min() else { return nil }
        return imBlick[oberste]
    }

    /// Welche Reihe die Mitte des Sichtfelds überdeckt — `nil`, solange die
    /// Bühne sich noch nicht gemeldet hat. Dieselbe Umrechnung wie in
    /// `massstabSetzen`: Bildschirmpunkt minus Ursprung des Inhalts.
    private func reiheInDerMitte() -> Int? {
        guard buehnenhoehe > 1, lage.meldungen > 0 else { return nil }
        // Dieselbe Umrechnung wie in `massstabSetzen`: Bildschirmpunkt
        // minus Ursprung des Inhalts. Gefragt wird `elementmasse` und nicht
        // `massstaebe` — die Zahl der Elemente kostet hier einen Lauf über
        // das ganze Buch und wird für diese Frage nicht gebraucht.
        let imInhalt = buehnenhoehe / 2 - Double(lage.ursprung.y)
        return elementmasse.stelle(bei: imInhalt, massstab: massstabJetzt)
    }

    // Die Reihe, bei der ein Tag anfängt — das Ziel eines Sprungs aus der
    // Tagesliste. Gesucht wird in derselben Liste, die auch gezeigt wird;
    // eine zweite Zählung liefe auseinander.
    private func ersteKennung(fuer tag: UUID) -> String? {
        if doppelseiten {
            let bogen = werk.sichtbareDoppelseiten.first { einer in
                if let links = einer.links, werk.gehoert(links, zu: tag) { return true }
                if let rechts = einer.rechts, werk.gehoert(rechts, zu: tag) { return true }
                return false
            }
            return bogen.map { "bogen-\($0.bogen)" }
        }
        let seite = werk.sichtbareSeiten.first { werk.gehoert($0, zu: tag) }
        return seite.map { "blatt-\($0.id)" }
    }

    // Ein Tipp in der Tagesliste ROLLT hin, er filtert nicht mehr.
    //
    // Steht der Tag schon oben im Bild, ist nichts zu tun — und genau
    // daran erkennt diese Stelle auch, dass die Änderung gar nicht aus der
    // Liste kam, sondern vom Rollen selbst. Ein zweiter Schalter daneben,
    // der „das war ich" sagt, wäre die naheliegende Lösung und eine, die
    // bei jeder Änderung der Reihenfolge wieder danebenliegt.
    // ZU EINER BESTIMMTEN SEITE (ab 1.0.93) — das Ziel eines Sprungs aus
    // der Druckprüfung. Gesucht wird in derselben Liste, die auch gezeigt
    // wird; eine zweite Zählung liefe auseinander.
    private func kennung(fuerSeite seite: UUID) -> String? {
        if doppelseiten {
            let bogen = werk.sichtbareDoppelseiten.first { einer in
                einer.links?.seite.id == seite || einer.rechts?.seite.id == seite
            }
            return bogen.map { "bogen-\($0.bogen)" }
        }
        return werk.sichtbareSeiten.first { $0.seite.id == seite }
            .map { "blatt-\($0.id)" }
    }

    // „Befund 3 von 12" — die Zahl gehört auf den Knopf. Ohne sie weiß
    // niemand, wie viel noch kommt.
    private var befundzaehler: String {
        let gesamt = werk.befundstellen.count
        let jetzt = min(werk.befundzeiger + 1, gesamt)
        return "Befund \(jetzt) von \(gesamt)"
    }

    private func springeZuBefund() {
        guard let seite = werk.sprungZuSeite else { return }
        werk.sprungZuSeite = nil
        guard let kennung = kennung(fuerSeite: seite) else { return }
        rollnummer += 1
        rollwunsch = Rollwunsch(kennung: kennung, anker: .top, nummer: rollnummer)
    }

    private func springeZuGewaehltem() {
        guard let tag = werk.gewaehlterTag, tag != tagImBlick,
              let kennung = ersteKennung(fuer: tag) else { return }
        rollnummer += 1
        rollwunsch = Rollwunsch(kennung: kennung, anker: .top, nummer: rollnummer)
    }

    // Die Liste selbst steht seit 1.0.16 im `Reisewerk` — sie wird an
    // mehr als einer Stelle gebraucht, und dort liegt auch das gemerkte
    // Titelblatt.
    static let titelseitenKennung = Reisewerk.titelseitenKennung

    private var titelzeile: String {
        if werk.gewaehlterTag == Self.titelseitenKennung { return "Titelseite" }
        return werk.tag?.datum.lang ?? werk.reise.anzeigename
    }

    // WIE BREIT DER INHALT DER BÜHNE IST — ausgerechnet, nicht erfragt
    // (ab 1.0.22, gemeldet 09/2026: „Die Seite kann leider nicht verschoben
    // werden.").
    //
    // Bis 1.0.21 stand hier `.frame(maxWidth: .infinity)`. Das ist der
    // übliche Griff in einem SENKRECHTEN `ScrollView`: Dort bietet die
    // Rolle ihre eigene Breite an, das Höchstmaß setzt sie ein, und der
    // Inhalt steht mittig. Diese Bühne rollt aber in BEIDE Richtungen, und
    // dort ist es der falsche Griff — **ein Höchstmaß kann einen Inhalt
    // niemals BREITER machen als das, was ihm angeboten wird**, und wie
    // breit ein `ScrollView` seinen Inhalt auf einer ROLLACHSE anbietet,
    // steht nirgends verbindlich. Genau daran hing, ob sich die Seite über
    // die Breite schieben lässt. Der Kommentar an `Zoomanker.griff` führte
    // das Höchstmaß sogar als Beleg für ein Mindestmaß an — wieder einmal
    // ein Kommentar statt einer Prüfung.
    //
    // Gesetzt wird deshalb eine AUSGERECHNETE Breite: mindestens das
    // Sichtfeld (sonst ließe sich ein schmales Blatt nicht zentrieren) und
    // mindestens das Blatt samt seinen beiden Rändern (sonst gäbe es nichts
    // zu schieben, wo es etwas zu schieben gibt). Beide Zahlen sind
    // bekannt — die eine ist gemessen, die andere ist Bogenbreite mal
    // Maßstab. Damit hängt das Schieben an keiner Zusage mehr, die niemand
    // nachlesen kann.
    // Wie eine einzelne Seite unter ihrem Blatt heißt. Der Umschlag zählt
    // nicht mit: „Seite 0" stünde unter der Rückseite, und die ist keine
    // Seite des Buchblocks, sondern die linke Hälfte des Umschlagbogens.
    private func seitenname(_ buchseite: Buchseite) -> String {
        var name = buchseite.kurzname
        if istGewaehlt(buchseite) { name += " \u{00B7} ausgewählt" }
        // DIE APP MACHT SICH BEMERKBAR (ab 1.0.76).
        //
        // Ansage des Nutzers, 09/2026: „Dann möchte ich, dass die App sich
        // bemerkbar macht, falls an irgendeiner Stelle einer dieser
        // Sicherheitsabstände nicht berücksichtigt wurde."
        //
        // Auf der Seite steht die orange Marke um den Block — die sieht
        // aber nur, wer die Hilfslinien eingeschaltet hat. Diese Zeile
        // steht immer da, und sie kostet nichts: Gefragt wird nur nach den
        // Blöcken DIESER Seite, und der Körper läuft im `LazyVStack` nur
        // für die Blätter, die gerade zu sehen sind.
        // Seit 1.0.81 zählt auch der ANSCHNITT mit: Ein Block, der über
        // die Schnittkante ragt und nicht randabfallend ist, wird im
        // gedruckten Buch angeschnitten. Genannt wird der schlimmere der
        // beiden Fälle zuerst.
        let ueber = werk.reise.ueberDerSchnittkante(buchseite).count
        let zuNah = werk.reise.amRandGefaehrdet(buchseite).count
        if zuNah > 0 {
            name += " \u{00B7} \u{26A0}\u{FE0E} "
            name += zuNah == 1 ? "1 Block" : "\(zuNah) Blöcke"
            name += ueber > 0 ? " ragen über die Schnittkante" : " im Sicherheitsabstand"
        }
        return name
    }

    // Orange schlägt die Auswahlfarbe: Ein Hinweis, der nur dann auffällt,
    // wenn die Seite gerade nicht gewählt ist, wäre ein halber Hinweis.
    private func seitenfarbe(_ buchseite: Buchseite) -> Color {
        if !werk.reise.amRandGefaehrdet(buchseite).isEmpty { return .orange }
        return istGewaehlt(buchseite) ? Color.accentColor : Color.secondary
    }

    private func istGewaehlt(_ buchseite: Buchseite) -> Bool {
        !buchseite.ausgleich && werk.gewaehlteSeite == buchseite.seite.id
    }

    private var inhaltsbreite: CGFloat {
        return max(CGFloat(buehnenbreite),
                   CGFloat(blattbreite(bei: massstabJetzt)) + 2 * Buehnenmasse.rand)
    }

    // Wie breit ein Blatt bei diesem Maßstab ist. Bis 1.0.22 nannte die Probe
    // an dieser Stelle `inhaltsbreite` minus Ränder — und das ist bei einer
    // kleinen Seite die BÜHNE und nicht das Blatt. Eine Probe, die etwas
    // anderes misst, als ihre Beschriftung sagt, führt in die Irre.
    private func blattbreite(bei massstab: Double) -> Double {
        breitesterBogen * massstab
    }

    // Der breiteste Bogen der Bühne. In der Doppelseitenansicht ist das
    // seit 1.0.50 der UMSCHLAG: zwei Seiten plus Rücken. Ohne den Rücken
    // wäre der Inhalt schmaler als das, was darin steht, und das letzte
    // Stück des Umschlags ließe sich nicht heranschieben.
    private var breitesterBogen: Double {
        let bogen = werk.reise.gestaltung.bogen(werk.reise.format)
        guard doppelseiten else { return bogen.width }
        // AM BUND LIEGT KEIN ANSCHNITT (ab 1.0.78). Bis 1.0.77 wurde hier
        // die Breite eines Einzelbogens verdoppelt, also zwei Anschnitte
        // zu viel gerechnet. Das war folgenlos, solange die Ansicht sie
        // auch zeichnete — jetzt wäre die Bühne breiter als ihr Inhalt,
        // und dann stünde beim Hineinzoomen rechts ein leerer Streifen.
        let innen = Double(Bogenlage.doppelbogen(
            format: werk.reise.format.groesse,
            anschnitt: werk.reise.gestaltung.anschnittPt).width)
        guard werk.reise.hatRueckseite else { return innen }
        // DER UMSCHLAG HAT SEIT 1.0.91 SEIN EIGENES MASS. Gefragt wird
        // deshalb `Umschlagmass.bogen` — dieselbe Stelle, die auch das PDF
        // fragt — und genommen wird der breitere der beiden: Die Bühne
        // trägt beides, und was schmaler gerechnet ist als sein Inhalt,
        // lässt sich nicht bis an die Kante heranschieben.
        let umschlag = Umschlagmass.bogen(werk.reise.format,
                                          gestaltung: werk.reise.gestaltung,
                                          umschlag: werk.reise.umschlag,
                                          innenseiten: werk.reise.innenseiten).width
        return max(innen, Double(umschlag))
    }

    // Wohin nach einem Zoom gerollt wird. Die laufende Nummer gehört dazu,
    // damit zweimal derselbe Anker auch zweimal ankommt.
    private struct Rollwunsch: Equatable {
        var kennung: String
        var anker: UnitPoint
        var nummer: Int
    }

    // Der Maßstab passt die Seite in die Breite ein, solange nicht
    // ausdrücklich gezoomt wurde. Ein Buch, das man erst zurechtschieben
    // muss, bevor man es sieht, ist keines.
    //
    // In der Doppelseitenansicht zählt die DOPPELTE Breite: Was eingepasst
    // werden soll, ist der aufgeschlagene Bogen und nicht die halbe Seite.
    private var passenderMassstab: Double {
        let breite = breitesterBogen
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
    private var seitenzoom: some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { wert in
                // GEZÄHLT WIRD DIE GESTE SELBST (ab 1.0.59).
                //
                // Bis 1.0.58 stand im Befund unten der Satz, „Zoomgeste"
                // zähle, wie viele Gesten angekommen sind — und die Zeile
                // konnte gar nicht erscheinen, denn niemand hat je
                // gezählt. Dieselbe Wurzel wie an jeder anderen Stelle
                // dieses Papiers: **Ein Kommentar ersetzt keine Prüfung.**
                //
                // Jetzt zählt sie je BILDPUNKT der Bewegung, und das ist
                // die Zahl, um die es beim Wort „flüssig" geht: Steht
                // „Zoomgeste" bei 60/s und „Seite" bei 0/s, kommt die
                // Geste an und die Seiten zeichnen sich nicht mit; laufen
                // beide gleich hoch, ist es umgekehrt.
                werk.messer.melde("Zoomgeste")
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
                    zoomAuf(neu, griff: gegriffen, brennpunkt: brennpunkt)
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
        zoominhalt = inhalt
        zoomversatz = lage.ursprung
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
    private func zoomAuf(_ wunsch: Double, griff: Zoomanker.Griff, brennpunkt: CGPoint) {
        let alt = massstabJetzt
        let neu = gedeckelt(wunsch)
        let ziel = massstaebe.rollziel(
            fuer: griff, brennpunkt: brennpunkt,
            sichtfeld: CGSize(width: buehnenbreite, height: buehnenhoehe),
            massstab: neu)
        let breiteNachher = max(buehnenbreite,
                                blattbreite(bei: neu) + 2 * Double(Buehnenmasse.rand))
        let soll = massstaebe.sollversatz(fuer: griff, brennpunkt: brennpunkt,
                                          inhaltsbreite: breiteNachher, massstab: neu)
        zoom = neu
        zoomsoll = soll
        werk.letzteBuehne = zoomprobe(griff: griff, brennpunkt: brennpunkt,
                                      ziel: ziel, soll: soll, alt: alt, neu: neu)
        // IMMER rollen (ab 1.0.24). Bis 1.0.23 stand hier ein
        // `guard griff.imBlatt` — und wo nicht gerollt wird, behält die
        // Rolle ihren Versatz, während der Inhalt wächst: der gemeldete
        // Sprung in die linke obere Ecke. Siehe `Zoomanker.Griff.imBlatt`.
        guard let elementkennung = kennung(ziel.stelle) else { return }
        rollnummer += 1
        rollwunsch = Rollwunsch(kennung: elementkennung, anker: ziel.anker,
                                nummer: rollnummer)
    }

    // WAS BEIM ZOOMEN WIRKLICH GERECHNET WURDE (ab 1.0.22), UND WAS
    // DARAUS GEWORDEN IST (ab 1.0.24).
    //
    // Die Regel dieses Hauses lautet: Wo sich eine Ursache nicht
    // erschließen lässt, muss eine Probe entscheiden. Drei Fassungen lang
    // wurde hier gerechnet und die Wirkung nicht gemessen — die Zeile
    // „Soll/Ist" holt das nach: `Soll` ist der Versatz, den der Inhalt nach
    // dem Rollen haben MÜSSTE, `Ist` der, den er kurz danach WIRKLICH hat.
    // Stimmen beide überein, löst `scrollTo` den Anker ein und der Fehler
    // liegt woanders; weichen sie ab, liegt es an genau dieser Stelle.
    // Genannt wird ohne Deutung, was gemessen und was gerechnet wurde.
    private func zoomprobe(griff: Zoomanker.Griff, brennpunkt: CGPoint,
                           ziel: Zoomanker.Rollziel, soll: CGPoint,
                           alt: Double, neu: Double) -> String {
        let freiQuer = Double(zoominhalt.width) - buehnenbreite
        let freiHoch = Double(zoominhalt.height) - buehnenhoehe
        var zeilen: [String] = []
        zeilen.append(String(
            format: "Zoom %.0f %% \u{2192} %.0f %% \u{00B7} Blattbreite %.0f pt \u{00B7} B\u{00FC}hne %.0f\u{00D7}%.0f",
            alt * 100, neu * 100, blattbreite(bei: alt), buehnenbreite, buehnenhoehe))
        zeilen.append(String(
            format: "Inhalt %.0f\u{00D7}%.0f \u{00B7} Versatz %.0f/%.0f \u{00B7} frei \u{21C4}%.0f \u{2195}%.0f",
            Double(zoominhalt.width), Double(zoominhalt.height),
            Double(zoomversatz.x), Double(zoomversatz.y), freiQuer, freiHoch))
        zeilen.append(String(
            format: "Griff #%d quer %.2f hoch %.2f%@ \u{00B7} Brennpunkt %.0f/%.0f",
            griff.index + 1, griff.quer, griff.hoch,
            griff.imBlatt ? "" : " (neben dem Blatt)",
            Double(brennpunkt.x), Double(brennpunkt.y)))
        zeilen.append(String(
            format: "Ziel #%d \u{00B7} Anker %.2f/%.2f \u{00B7} roh %.2f/%.2f%@",
            ziel.stelle + 1, ziel.anker.x, ziel.anker.y, ziel.rohX, ziel.rohY,
            ziel.geklemmt ? " (geklemmt)" : ""))
        zeilen.append(String(format: "Soll %.0f/%.0f \u{00B7} Ist \u{2026}",
                             Double(soll.x), Double(soll.y)))
        return zeilen.joined(separator: "\n")
    }

    // Die Gegenprobe, gelesen NACH dem Rollen (ab 1.0.24).
    //
    // Sie läuft genau einmal je Zoom und nicht laufend: Ein Zustand, der
    // bei jedem Bildpunkt geschrieben wird, zeichnet die Bühne sechzigmal
    // in der Sekunde neu (die Lehre aus 1.0.16). Die Wartezeit ist die
    // Umdrehung, die der `ScrollView` zum Rollen braucht.
    private func sollIstNachtragen() {
        guard let soll = zoomsoll, let text = werk.letzteBuehne else { return }
        let ist = lage.ursprung
        let neu = String(format: "Soll %.0f/%.0f \u{00B7} Ist %.0f/%.0f \u{00B7} Abweichung %.0f/%.0f",
                         Double(soll.x), Double(soll.y),
                         Double(ist.x), Double(ist.y),
                         Double(ist.x) - Double(soll.x), Double(ist.y) - Double(soll.y))
        var zeilen = text.components(separatedBy: "\n")
        if let letzte = zeilen.indices.last, zeilen[letzte].hasPrefix("Soll ") {
            zeilen[letzte] = neu
        } else {
            zeilen.append(neu)
        }
        werk.letzteBuehne = zeilen.joined(separator: "\n")
    }

    // Ein Maßstab aus der Fußleiste wird um die MITTE des Sichtfelds
    // gesetzt, aus demselben Grund wie die Geste um ihren Mittelpunkt: Was
    // man ansieht, soll stehen bleiben.
    private func massstabSetzen(_ ziel: Double) {
        let mitte = CGPoint(x: buehnenbreite / 2, y: buehnenhoehe / 2)
        let imInhalt = CGPoint(x: mitte.x - lage.ursprung.x, y: mitte.y - lage.ursprung.y)
        let gegriffen = massstaebe.griff(bei: imInhalt, inhalt: lage.groesse,
                                         massstab: massstabJetzt)
        zoomAuf(ziel, griff: gegriffen, brennpunkt: mitte)
    }

    // Die Maße, mit denen gerechnet wird. NUR aus einem Handgriff heraus
    // gelesen und nie im Körper: `sichtbareSeiten` geht über das ganze
    // Buch.
    private var massstaebe: Zoomanker {
        var anker = elementmasse
        anker.anzahl = doppelseiten ? werk.sichtbareDoppelseiten.count
                                    : werk.sichtbareSeiten.count
        return anker
    }

    // DIE GEOMETRIE OHNE DIE ZÄHLUNG (ab 1.0.79).
    //
    // `massstaebe` kostet einen Lauf über das ganze Buch, und genau deshalb
    // steht darüber, dass es nur aus einem Handgriff heraus gelesen wird.
    // `reiheInDerMitte` wird aber im KÖRPER gebraucht (über
    // `onChange(of: tagImBlick)`) — und für die Frage „welche Reihe liegt
    // in der Mitte" wird die Zahl der Elemente gar nicht gebraucht.
    // Getrennt, statt die Rechnung ein zweites Mal hinzuschreiben.
    private var elementmasse: Zoomanker {
        let bogen = werk.reise.gestaltung.bogen(werk.reise.format)
        return Zoomanker(blatthoehe: bogen.height,
                         blattbreite: doppelseiten ? breitesterBogen : bogen.width,
                         beiwerk: Buehnenmasse.beiwerk,
                         fuge: Buehnenmasse.fuge,
                         rand: Buehnenmasse.rand,
                         anzahl: 0)
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

        // DER PINSEL GEHÖRT DEM EINZELNEN ELEMENT (ab 1.0.49).
        //
        // Bis 1.0.48 trug dieser Knopf das Reglersymbol und das Menü
        // daneben den Pinsel — also genau andersherum, als es kennt, wer
        // Pages benutzt: Dort öffnet der Pinsel die Einstellungen des
        // GEWÄHLTEN Elements. Gemeldet 09/2026: „Irgendwie habe ich fast
        // sogar das Gefühl, dass die beiden Symbole vertauscht sind." Sie
        // waren es.
        //
        // Der Tausch allein reicht aber nicht, denn schuld war nicht nur
        // das Bild: „Ausgewähltes" und „Gestalten" sagen beide etwas über
        // die TÄTIGKEIT und nichts über den GELTUNGSBEREICH — und der ist
        // hier der ganze Unterschied. Die Beschriftungen nennen ihn seither
        // beim Namen: „Auswahl" gegen „Ganzes Buch".
        //
        // DER INSPEKTOR IST EIN OVERLAY, KEINE SPALTE (ab 1.0.76).
        //
        // Befund des Nutzers, 09/2026: „Sobald ich auf den Pinsel tippe,
        // klappt rechts eine ganze Seite auf, die bewirkt, dass der
        // Bearbeitungsbereich verkleinert wird. Das möchte ich nicht. Bei
        // den anderen Menüpunkten ist es ja auch möglich, dass sich so ein
        // Overlay-Fenster kurz öffnet, bis die entsprechende Option
        // ausgewählt wird."
        //
        // `.inspector` legt auf dem iPad eine feste Spalte NEBEN den
        // Inhalt und nimmt ihm deren Breite — auf einem iPad im Hochformat
        // ist das ein knappes Drittel, und genau dort steht das Blatt, an
        // dem gearbeitet wird. Ein Popover hängt am Knopf, deckt nur einen
        // Teil ab und geht bei einem Tipp daneben wieder zu. Auf dem
        // iPhone macht SwiftUI daraus von selbst ein Blatt — dort wäre ein
        // Popover eine Briefmarke.
        //
        // Der Stapel darum ist kein Zierat: Ohne ihn gäbe es im Blatt auf
        // dem iPhone keinen sichtbaren Ausgang („Wer einen Modus baut,
        // baut den Ausgang mit — und zwar sichtbar", seit 1.0.9).
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                inspektor.toggle()
            } label: {
                Label("Auswahl", systemImage: "paintbrush")
            }
            .popover(isPresented: $inspektor) {
                NavigationStack {
                    BlockInspektor(werk: werk, blatt: $blatt)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Fertig") { inspektor = false }
                            }
                        }
                }
                .frame(idealWidth: 360, idealHeight: 560)
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
            //
            // Seit 1.0.77 führt es ins HANDBUCH statt gleich in die
            // Gestenkarte. Die steht dort als erster Eintrag — ein Tipp
            // weiter, dafür daneben die Antwort auf die andere Hälfte der
            // Frage: nicht nur WIE etwas geht, sondern WO es steht.
            Button {
                blatt = .handbuch
            } label: {
                Label("Hilfe", systemImage: "questionmark.circle")
            }

            // DURCH DIE BEFUNDE BLÄTTERN (ab 1.0.93).
            //
            // Die roten Marken sagen, WO etwas ist; dieser Knopf bringt
            // einen hin. Er steht hier und nicht in einem Menü: Wer eine
            // Prüfung abarbeitet, tippt ihn ein Dutzend Mal, und ein Menü
            // dafür wären ein Dutzend Male zwei Tipps. Am letzten Befund
            // geht es wieder von vorn los — ein Knopf, der plötzlich nichts
            // mehr tut, sieht kaputt aus.
            // DER WORTLOSE KNOPF IST WEG (ab 1.0.96).
            //
            // Hier stand ein rotes Warndreieck mit `Label(befundzaehler,
            // …)` — und eine Werkzeugleiste zeigt von einem `Label` nur
            // das Symbol, sobald es eng wird. Auf dem iPad stand dort also
            // ein rotes Dreieck ohne ein Wort: Es sagte weder, wie viele
            // Befunde es gibt, noch dass ein Tipp weiterspringt, noch wie
            // man die roten Umrandungen wieder loswird (gemeldet 09/2026:
            // „Ich möchte aber auch genauso die Funktion haben, die
            // Umrandungen wieder unsichtbar zu machen."). Alles davon
            // steht jetzt im Befundband über der Bühne, mit Worten.

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
            // Dasselbe für die KARTE (ab 1.0.87) — sie ist auch nur ein
            // Bild, und der Weg dorthin muss derselbe sein.
            // Gefragt wird der Tag des BLOCKS und nie der gewählte: Der
            // folgt seit 1.0.28 dem, was oben im Bild steht — die Lehre
            // aus 1.0.51, wo derselbe Griff am falschen Tag landete.
            if gewaehlterBlock?.inhalt == .karte, let tagID = werk.tagZuBlock(gewaehlterBlock?.id) {
                Button {
                    werk.kartenunterschriftOeffnen(tagID)
                } label: {
                    Label("Kartenunterschrift", systemImage: "text.bubble")
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

            ablageKnopf

            blockMenue
            tagMenue
        }
    }

    // Der eine Knopf, der auch OHNE gewählten Block dasteht.
    //
    // Eine eigene Eigenschaft mit genau EINEM Kind: Ein
    // `ToolbarItemGroup` verteilt seine Kinder auf eigene Plätze, und
    // ein weitergereichter Ausdruck ist für sie eines — mehrere Knöpfe
    // darin stünden zusammengedrängt statt nebeneinander (die Lehre aus
    // Tafelbild). Gebraucht wird sie, damit die Gruppe unter zehn
    // Kindern bleibt.
    @ViewBuilder
    private var ablageKnopf: some View {
        // LIEGT ETWAS IN DER ABLAGE, STEHT DER KNOPF DA (ab 1.0.65).
        //
        // Nicht nur im Menü: Wer gerade ausgeschnitten hat, hat keinen
        // Block mehr gewählt — das Blockmenü ist dann weg, und im
        // Plus-Menü müsste man den Eintrag erst suchen. Ein Weg, den
        // man nicht sieht, ist keiner; dieselbe Lehre wie beim
        // Gruppenchat in Schulalarm und beim Sichtumschalter der
        // Abfahrtstafel.
        if let inhalt = werk.ablage, let ziel = werk.einsetzbareSeite {
            Button {
                werk.blockEinfuegen(auf: ziel)
            } label: {
                Label("\(inhalt.name) einfügen", systemImage: "doc.on.clipboard")
            }
            .tint(.orange)
            .disabled(werk.einfuegenGrund(auf: ziel) != nil)
        }
    }

    // WAS MIT DIESEM BLOCK GESCHEHEN SOLL (ab 1.0.39).
    //
    // Befund des Nutzers, 09/2026: „Ich suche noch nach der Funktion,
    // Elemente auf eine andere Seite zu kopieren oder zu verschieben. Sie
    // ist zu versteckt."
    //
    // Beides trifft zu, und auf zweierlei Weise: VERSCHIEBEN gab es seit
    // 1.0.29 — aber nur im Block-Inspektor, also hinter dem Schieberegler
    // in der Werkzeugleiste und dort ganz unten, hinter Schrift, Wirkung,
    // Lage und Ausschnitt. KOPIEREN gab es überhaupt nicht.
    //
    // Der Inspektor ist der Ort für Einstellungen; was man mit einem Block
    // TUT, gehört dorthin, wo man ihn gerade anfasst. Das Menü steht
    // deshalb unten in der Leiste neben dem Tagesmenü und erscheint nur,
    // solange ein Block gewählt ist — sichtbar beschriftet mit der Art des
    // Blocks, damit klar ist, worauf es zielt.
    //
    // **Zweiter Zugang, EINE Stelle:** Der Abschnitt im Inspektor bleibt,
    // und beide rufen dieselben Funktionen im Werk. Zwei Fassungen
    // derselben Handgriffe liefen auseinander — dieselbe Regel wie bei den
    // Fotostilfeldern (1.0.10).
    @ViewBuilder
    private var blockMenue: some View {
        if let block = gewaehlterBlock {
            Menu {
                // Verschieben und Kopieren brauchen eine NACHBARSEITE, und
                // die gibt es nur im Buchblock. Ein Block auf dem Umschlag
                // (ab 1.0.64) bekommt deshalb nur den letzten Abschnitt —
                // nach vorn holen und entfernen. Ein ausgegrauter Eintrag
                // ohne Grund wäre für den Menschen davor ein kaputter Knopf.
                ablageAbschnitt(block)
                if let lage = werk.seitenlage(block.id) {
                    verschiebenAbschnitt(block, lage: lage)
                    kopierenAbschnitt(block, lage: lage)
                }
                restAbschnitt(block)
            } label: {
                Label(block.inhalt.name, systemImage: "square.on.square")
            }
        }
    }

    // AUSSCHNEIDEN, KOPIEREN, EINFÜGEN (ab 1.0.65).
    //
    // Befund des Nutzers, 09/2026: „Im Moment ist es so, dass ich zum
    // Beispiel ein Foto nur auf eine Seite verschieben kann, die nach der
    // aktuellen Seite neu angelegt wird. Etwas anderes steht mir offenbar
    // nicht zur Verfügung." — Genau so ist es: Die beiden Abschnitte
    // darunter rechnen mit den Seiten DIESES Tages, und ein Tag mit einer
    // einzigen Seite lässt davon nur „Auf eine neue Seite" übrig.
    //
    // Der Abschnitt steht deshalb GANZ OBEN: Er ist der allgemeine Weg,
    // die beiden darunter sind die Abkürzungen für den Nachbarn.
    @ViewBuilder
    private func ablageAbschnitt(_ block: Block) -> some View {
        Section {
            Button("Ausschneiden", systemImage: "scissors") {
                werk.blockAusschneiden(block.id)
            }
            Button("Kopieren", systemImage: "doc.on.doc") {
                werk.blockInDieAblage(block.id)
            }
            einfuegenKnopf
        }
    }

    // Derselbe Knopf an zwei Stellen: im Blockmenü und im Plusmenü. Dort
    // ist er der einzige — wer eingefügt hat und dann eine andere Seite
    // wählt, hat gerade KEINEN Block gewählt, und das Blockmenü ist weg.
    @ViewBuilder
    private var einfuegenKnopf: some View {
        if let inhalt = werk.ablage, let ziel = werk.einsetzbareSeite {
            let grund = werk.einfuegenGrund(auf: ziel)
            Button {
                werk.blockEinfuegen(auf: ziel)
            } label: {
                Label(einfuegenTitel(inhalt, ziel: ziel), systemImage: "doc.on.clipboard")
            }
            // Ausgegraut und NICHT weggelassen: Hier weiß man, warum es
            // nicht geht — der Grund steht im Titel des Menüs daneben, und
            // ein fehlender Eintrag ließe einen raten, ob die Ablage leer
            // ist oder das Ziel nicht passt.
            .disabled(grund != nil)
        }
    }

    private func einfuegenTitel(_ inhalt: Reisewerk.Ablageinhalt, ziel: UUID) -> String {
        if werk.einfuegenGrund(auf: ziel) != nil {
            return "\(inhalt.name) hier nicht einsetzbar"
        }
        guard let name = werk.seitenname(ziel) else { return "\(inhalt.name) einfügen" }
        return "\(inhalt.name) einfügen \u{2014} auf " + name
    }

    // Auf welcher Seite der Block steht und wie viele es gibt.
    private typealias Seitenlage = (jetzt: Int, anzahl: Int)

    // DREI ABSCHNITTE, DREI FUNKTIONEN. Zusammen in einem Menü-Körper wäre
    // das ein verschachtelter Ausdruck aus Sections, Bedingungen und
    // ForEach — also genau das, woran der Typprüfer in 1.0.38 aufgegeben
    // hat. Aufgeteilt ist jeder Teil für sich eindeutig.
    @ViewBuilder
    private func verschiebenAbschnitt(_ block: Block, lage: Seitenlage) -> some View {
        Section("Verschieben") {
            Button("Eine Seite zurück", systemImage: "arrow.up.doc") {
                werk.blockVerschieben(block.id, aufSeite: lage.jetzt - 1)
            }
            .disabled(lage.jetzt == 0)
            if lage.jetzt + 1 < lage.anzahl {
                Button("Eine Seite vor", systemImage: "arrow.down.doc") {
                    werk.blockVerschieben(block.id, aufSeite: lage.jetzt + 1)
                }
            }
            Button("Auf eine neue Seite", systemImage: "doc.badge.plus") {
                werk.blockAufNeueSeite(block.id)
            }
            if lage.anzahl > 2 {
                Menu("Auf Seite \u{2026}") {
                    ForEach(0..<lage.anzahl, id: \.self) { nummer in
                        Button("Seite \(nummer + 1)") {
                            werk.blockVerschieben(block.id, aufSeite: nummer)
                        }
                        .disabled(nummer == lage.jetzt)
                    }
                }
            }
        }
    }

    // Kopieren gibt es nur, wo es sinnvoll ist. Ein ausgegrauter Eintrag
    // ohne Grund wäre für den Menschen davor ein kaputter Knopf; steht er
    // gar nicht da, sucht man ihn auch nicht. Warum ein Tagebuchtext nicht
    // dabei ist, steht im Fußtext des Inspektors.
    @ViewBuilder
    private func kopierenAbschnitt(_ block: Block, lage: Seitenlage) -> some View {
        if werk.kopierbar(block) {
            Section("Kopieren") {
                Button("Auf dieser Seite", systemImage: "plus.square.on.square") {
                    werk.blockKopieren(block.id)
                }
                if lage.jetzt + 1 < lage.anzahl {
                    Button("Auf die nächste Seite", systemImage: "square.on.square.dashed") {
                        werk.blockKopieren(block.id, aufSeite: lage.jetzt + 1)
                    }
                }
                if lage.anzahl > 1 {
                    Menu("Kopie auf Seite \u{2026}") {
                        ForEach(0..<lage.anzahl, id: \.self) { nummer in
                            Button("Seite \(nummer + 1)") {
                                werk.blockKopieren(block.id, aufSeite: nummer)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func restAbschnitt(_ block: Block) -> some View {
        Section {
            if werk.teilbar(block) {
                Button("Rest auf die nächste Seite",
                       systemImage: "text.line.first.and.arrowtriangle.forward")
                {
                    werk.textTeilen(block.id)
                }
            }
            Button("Nach vorn holen", systemImage: "square.3.layers.3d.top.filled") {
                werk.blockNachVorn(block.id)
            }
            Button(role: .destructive) {
                werk.blockLoeschen(block.id)
            } label: {
                Label("Entfernen", systemImage: "trash")
            }
        }
    }


    // WAS KOMMT INS BUCH HINEIN?
    private var hinzufuegenMenue: some View {
        Menu {
            // Zuerst der geführte Weg: Er sagt, in welcher Reihenfolge die
            // drei Schritte zusammengehören, und zeigt hinterher, was
            // zugeordnet wurde.
            // ZUERST DAS, WAS AUF DIE GEWÄHLTE SEITE GEHT (ab 1.0.61).
            //
            // Ansage des Nutzers, 09/2026: „Ich möchte in das Buch manuell
            // Bilder oder Grafiken einfügen können. Dies soll über den
            // Plus-Button geschehen, sowie bei den Textfeldern auch."
            // Den Textblock gab es seit 1.0.0 — im Block-Inspektor unter
            // „Auf die Seite legen", also hinter dem Regler in der
            // Werkzeugleiste und nur, wenn gerade KEIN Block gewählt ist.
            // Gefunden hat ihn niemand. Der Abschnitt nennt deshalb die
            // Seite beim Namen: Ein Menü, das nicht sagt, worauf es wirkt,
            // ist die Frage von vorhin noch einmal.
            if let seite = werk.einsetzbareSeite {
                Section(werk.seitenname(seite).map { "Auf " + $0 } ?? "Auf die gewählte Seite") {
                    einfuegenKnopf
                    Button("Textfeld", systemImage: "text.alignleft") {
                        werk.blockHinzufuegen(.text("Neuer Text"), aufSeite: seite)
                    }
                    // DIE SPUR FÄNGT HIER AN, NICHT ERST IM WÄHLER (ab
                    // 1.0.101). Gemeldet 09/2026: „Jedes Mal stürzt die App
                    // ab, aber es wird nirgendwo etwas eingetragen." Wenn
                    // nichts dasteht, hat der erste vermerkte Schritt noch
                    // nicht gelaufen — also muss der erste Schritt früher
                    // liegen: beim Tippen, vor dem Blatt und vor dem
                    // fremden Fenster.
                    Button("Bild aus Dateien\u{2026}", systemImage: "photo") {
                        Absturzspur.beginnt("Wähler „Bild aus Dateien\u{201C} wird geöffnet "
                            + "(\(werk.seitenname(seite) ?? "?"))")
                        blatt = .grafik
                    }
                    // BILDER AUS DER MEDIATHEK, OHNE DATUMSLOGIK (ab 1.0.65).
                    //
                    // Ansage des Nutzers, 09/2026: „Nachdem dies geschehen
                    // ist, möchte ich über das Plusmenü aber auch Fotos
                    // auswählen können, egal ob von Dateien oder aus der
                    // Fotomediathek, die dann einfach auf der Seite
                    // eingefügt werden, egal welchen Zeitstempel sie
                    // haben."
                    //
                    // Den Weg über DATEIEN gibt es seit 1.0.61, den über
                    // die Mediathek nicht — dort führte jeder Weg durch
                    // die Fotoeinfuhr, also durch Datum, Ort und einen
                    // Bericht darüber, was fehlt. Für ein Bild, das
                    // einfach hier liegen soll, ist das alles keine
                    // Auskunft, sondern Lärm.
                    Button("Bild aus der Mediathek\u{2026}",
                           systemImage: "photo.on.rectangle.angled") {
                        Absturzspur.beginnt("Wähler „Bild aus der Mediathek\u{201C} wird "
                            + "geöffnet (\(werk.seitenname(seite) ?? "?"))")
                        blatt = .bildAusFotos
                    }
                    // EINE KARTE BRAUCHT EINEN TAG. Sie zeichnet die Spur
                    // dieses einen Tages; auf einer gerechneten Seite ohne
                    // Tag — Umschlag, Schmutztitel, Schlussseite — gibt es
                    // keinen, und was dort stünde, wäre ein leerer Rahmen
                    // mit dem Satz „Kartenbild fehlt". Deshalb steht der
                    // Eintrag dort gar nicht erst — ein Knopf, der nichts
                    // tut, ist für den Menschen davor ein kaputter Knopf.
                    if werk.eigenflaeche(seite) == nil {
                        Button("Karte", systemImage: "map") {
                            werk.blockHinzufuegen(.karte, aufSeite: seite)
                        }
                    }
                    Button("Trennlinie", systemImage: "minus") {
                        werk.blockHinzufuegen(.linie, aufSeite: seite)
                    }
                    Button("Farbfläche", systemImage: "square.fill") {
                        werk.blockHinzufuegen(.flaeche, aufSeite: seite)
                    }
                }
            }
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
    //
    // Der Abschnittstitel steht hier nicht als Zierde: Er beantwortet die
    // Frage, mit der der Nutzer vor dem Menü steht — gilt das jetzt für
    // alles oder nur für das, was ich gerade angetippt habe? Dieselbe
    // Frage beantwortet der Pinsel daneben andersherum.
    private var gestaltenMenue: some View {
        Menu {
            Section("Gilt für das ganze Buch") {
                // VORLAGEN STEHEN GANZ OBEN (ab 1.0.95).
                //
                // Sie setzen dasselbe wie die Punkte darunter, nur alles
                // auf einmal und aus einem anderen Buch. Wer für den
                // nächsten Urlaub „dieselben Einstellungen" sucht, sucht
                // sie hier — und nicht in den Einstellungen der App: Dort
                // steht, wie diese App arbeitet, hier steht, wie dieses
                // Buch aussieht.
                Button("Vorlagen: Aussehen und Druckerei…", systemImage: "square.on.square") {
                    blatt = .vorlagen
                }
                Divider()
                Button("Stil wählen…", systemImage: "paintpalette") { blatt = .stil }
                Button("Schrift und Ausrichtung…", systemImage: "textformat") {
                    blatt = .typografie
                }
                Button("Fotos…", systemImage: "photo.stack") { blatt = .fotostil }
                Button("Textfelder…", systemImage: "text.alignleft") { blatt = .textstil }
                Button("Karten…", systemImage: "map") { blatt = .kartenstil }
                Button("Seitenhintergrund…", systemImage: "square.fill.on.square.fill") {
                    blatt = .hintergrund
                }
                // Das Wasserzeichen steht neben dem Hintergrund, weil es
                // dieselbe Frage beantwortet: Was liegt auf jeder Seite, ohne
                // dass es jemand dorthin gestellt hat.
                Button("Wasserzeichen…", systemImage: "drop") { blatt = .wasserzeichen }
                Divider()
                // DER UMSCHLAG HAT SEINE EIGENE GESTALTUNG (ab 1.0.50) —
                // und deshalb einen eigenen Menüpunkt und keine Unterseite
                // der Gestaltung. Er ist nicht eine Seite unter Seiten,
                // sondern das eine Stück Papier, das außen um das Buch
                // liegt: Rückseite, Rücken, Titelseite.
                // ER NENNT SEIT 1.0.84 AUCH DEN TITEL — weil der jetzt
                // dahinterliegt. Ein Menüpunkt, der nicht sagt, was hinter
                // ihm steht, ist so wenig wert wie ein Knopf, den niemand
                // findet (dieselbe Lehre wie 1.0.79, wo eine Umbenennung
                // die Karteneinstellung verschwinden ließ).
                Button("Titel, Umschlag und Rücken…", systemImage: "book.closed.fill") {
                    blatt = .umschlag
                }
                Button("Seitenformat…", systemImage: "square.resize") { blatt = .seitenformat }
                Button("Ränder und Druckzugaben…", systemImage: "ruler") {
                    blatt = .gestaltung
                }
            }
        } label: {
            Label("Ganzes Buch", systemImage: "book.closed")
        }
    }

    // ALLES SELTENE.
    private var mehrMenue: some View {
        Menu {
            // DAS MENÜ IST NACH FRAGEN GEORDNET (ab 1.0.77).
            //
            // Es trug sechzehn Einträge ohne Gliederung — und genau
            // dieses Menü ist der Ort, an dem dreimal etwas lag, das
            // niemand fand (Broschüre 1.0.37, zwei Dateien 1.0.52,
            // Druckprüfung 1.0.76). Die Abschnitte heißen nach dem, was
            // man vorhat, und nicht nach dem Handwerk.
            Section("Vor dem Druck") {
                // WAS GERADE AUSGEGEBEN WIRD (eigener Punkt ab 1.0.75).
                //
                // Ansage des Nutzers, 09/2026: „Das gipfelt jetzt in einer
                // Fülle von Formaten. Vielleicht wäre es gut, sich innerhalb
                // der App irgendwo anzeigen lassen zu können, wie denn jetzt
                // das Ausgabeformat aussieht und wie die einzelnen Werte sind."
                //
                // Er steht VOR dem Ausgeben, weil man ihn davor braucht — und
                // als eigener Punkt, nicht als Zeile im Ausgabeblatt: Das ist
                // der Ort, an dem in 1.0.37 und 1.0.52 zweimal etwas lag, das
                // niemand fand. Vom Ausgabeblatt aus führt trotzdem ein Weg
                // dorthin, mit der dort gewählten Bildgüte.
                // DIE DRUCKPRÜFUNG ALS EIGENER PUNKT (ab 1.0.76).
                //
                // Ansage des Nutzers, 09/2026: „Damit sind wir an der Stelle,
                // wo ich gerne einen Menüpunkt einbauen würde namens
                // Druckprüfung. … Zu diesem Punkt meine ich mich zu erinnern,
                // dass mir die App an irgendeiner Stelle bereits
                // rückgemeldet hat, dass beispielsweise Text nicht ganz in ein
                // Textfeld gepasst hat. Ich finde diesen Menüpunkt leider
                // nicht mehr wieder."
                //
                // Er hat sie gesehen: `Druckpruefung.vorab` läuft seit 1.0.1
                // und zählt abgeschnittenen Text mit. Sie stand aber
                // ausschließlich im Ausgabeblatt, unter der halben Seite
                // Einstellungen — zwölfte Auflage von „es war da, man fand es
                // nicht". Sie steht deshalb GANZ OBEN und heißt nach der
                // Sache.
                Button("Druckprüfung…", systemImage: "checkmark.seal") {
                    blatt = .druckpruefung
                }
                Button("Ausgabeformat und Maße…", systemImage: "doc.text.magnifyingglass") {
                    blatt = .ausgabeformat
                }
            }
            Section("Ausgeben") {
                Button("Als PDF sichern…", systemImage: "square.and.arrow.up") { blatt = .ausgabe }
                // ZWEI DATEIEN FÜR DEN DRUCKDIENST (eigener Punkt ab 1.0.52).
                //
                // Den Weg gibt es seit 1.0.50 — als eine von drei Zeilen in
                // einem Picker hinter „Als PDF sichern…". Gefunden hat ihn
                // niemand: „Ich möchte bei der Exportfunktion Einbauen, dass
                // automatisch ein Export von zwei PDF-Dateien vorgenommen
                // werden soll." (09/2026). Zehnte Auflage von „es war da, man
                // fand es nicht", und dieselbe Antwort wie bei der Broschüre in
                // 1.0.37: derselbe Bildschirm, nur mit Vorwahl und mit einem
                // Namen, der die Sache nennt statt des Werkzeugs.
                if werk.reise.hatRueckseite {
                    Button("Umschlag und Innenteil getrennt…", systemImage: "doc.on.doc") {
                        blatt = .zweiDateien
                    }
                    // NUR DER UMSCHLAG (ab 1.0.67). Ansage des Nutzers,
                    // 09/2026: „damit ich jetzt nicht wieder beide Teile
                    // exportieren muss, denn das PDF für das eigentliche Buch
                    // ist mittlerweile knapp 4 GB groß." Ein eigener Punkt und
                    // nicht nur eine Zeile im Picker: Wer am Umschlag etwas
                    // ändert, sucht genau diesen Weg — und der Picker im Blatt
                    // ist derselbe Ort, an dem in 1.0.52 zehn Fassungen lang
                    // etwas stand, das niemand fand.
                    Button("Nur den Umschlag…", systemImage: "book.closed") {
                        blatt = .nurUmschlag
                    }
                }
                // DOPPELSEITEN (ab 1.0.69). Ansage des Nutzers, 09/2026:
                // „Offenbar will Saal Digital ein Upload eines PDF mit fertig
                // gestalteten Doppelseiten." Ein eigener Punkt aus demselben
                // Grund wie bei den beiden darüber: Der Picker im Blatt ist der
                // Ort, an dem in 1.0.52 zehn Fassungen lang etwas stand, das
                // niemand fand.
                Button("Doppelseiten ausgeben…", systemImage: "rectangle.split.2x1") {
                    blatt = .doppelseiten
                }
                // EIN EIGENER MENÜPUNKT FÜR DIE BROSCHÜRE (ab 1.0.37).
                //
                // Es gibt sie seit 1.0.27, vollständig gebaut — gefunden hat
                // sie niemand (Ansage des Nutzers, 09/2026). Sie lag drei
                // Ebenen tief: hinter „…", darin hinter „Als PDF sichern…"
                // (klingt nach einer Datei, nicht nach einem Drucker) und dort
                // hinter einem zugeklappten Picker namens „Umfang" (klingt nach
                // Seitenzahl). Sechste Auflage von „es war da, man fand es
                // nicht" — dieselbe Lehre wie beim Gruppenchat in Schulalarm,
                // beim Sichtumschalter der Abfahrtstafel und bei den
                // Foto-Einstellungen in 1.0.10.
                //
                // Kein zweiter Bildschirm: derselbe, nur mit Vorwahl.
                Button("Broschüre drucken…", systemImage: "printer") { blatt = .broschuere }
            }
            Section("Das ganze Buch") {
                Button("Buch als Datei sichern…", systemImage: "shippingbox") { buchSichern() }
                // ERST SICHERN, DANN KOPIEREN (ab 1.0.33).
                //
                // `Regal.duplizieren` liest das Buch aus dem Modell, und das
                // Sichern läuft sonst verzögert. Ohne diese Zeile fehlte der
                // Kopie genau das, was man in den letzten Minuten getan hat —
                // und zwar still, denn die Kopie steht ja da.
                Button("Dieses Buch duplizieren", systemImage: "plus.square.on.square") {
                    werk.sofortSichern()
                    let buch = werk.reise
                    Task {
                        let satz = await regal.duplizieren(buch)
                        werk.meldung = Reisewerk.Meldung(text: satz)
                    }
                }
                Divider()
                // ALLES NEU VERTEILEN LASSEN (ab 1.0.38).
                //
                // „Alle unberührten Tage neu anordnen" gab es schon — es
                // überspringt aber jeden Tag mit Handarbeit, und Handarbeit ist
                // bereits ein verschobener Block. Wer eine neue Fassung der
                // Satzmaschine auf ein fertiges Buch anwenden will, kam damit
                // nicht weiter und musste jeden angefassten Tag einzeln über
                // das Tagesmenü nachziehen.
                //
                // Der Menüpunkt heißt nach der SACHE und nicht nach dem
                // Handwerk, und er führt auf eine Vorschau statt sofort
                // loszulegen: Was wegfällt, steht vorher da, Tag für Tag.
                Button("Alles neu verteilen…", systemImage: "arrow.triangle.2.circlepath") {
                    blatt = .neuverteilen
                }
                Button("Alle unberührten Tage neu anordnen", systemImage: "arrow.clockwise") {
                    werk.alleNeuAnordnen(nurUnberuehrte: true)
                }
            }
            Section("Hilfen beim Anordnen") {
                // DER SCHALTER HEISST NACH ALLEN DREI LINIEN (ab 1.0.76).
                //
                // Er schaltet den Satzspiegel (blau), die Schnittkante
                // (rot gestrichelt) und den Sicherheitsabstand (orange
                // gestrichelt) zusammen — hieß aber nach einer von dreien.
                // Wer nach der Schnittlinie sucht, sucht nicht unter
                // „Satzspiegel"; dieselbe Lehre wie bei jedem anderen
                // Menüpunkt dieser App, der nach dem Handwerk statt nach
                // der Sache hieß.
                Toggle("Linien zeigen: Satzspiegel, Schnitt, Sicherheit",
                       isOn: $werk.zeigeSatzspiegel)
                // Einrasten lässt sich abschalten — die zweite Hälfte des
                // Wunsches nach einem Randindikator, der „im Einzelfall auch
                // veränderbar" ist. Eine Hilfe, aus der man nicht aussteigen
                // kann, ist eine Bevormundung; der genaue Wert in
                // Millimetern steht daneben im Inspektor unter „Lage".
                // `@AppStorage` gehört in eine View und nie ins `Reisewerk`.
                Toggle("An Rand und Nachbarn einrasten", isOn: $einrastenAn)
                // DIE BEFUNDE DER DRUCKPRÜFUNG (ab 1.0.93). Eingeschaltet
                // wird er normalerweise dort, wo der Befund steht („Im Buch
                // zeigen"); hier steht er, weil man ihn auch wieder
                // ausschalten können muss, ohne die Prüfung zu öffnen.
                Toggle("Befunde der Druckprüfung rot umranden",
                       isOn: $werk.zeigeBefunde)
            }
            Section("Hilfe und Prüfen") {
                // DIE HILFE STEHT AUCH HIER (ab 1.0.77). Das
                // Fragezeichen unten ist der kurze Weg; wer ein Menü
                // aufklappt und nicht findet, was er sucht, soll von
                // dort aus ins Handbuch kommen statt zurück auf die
                // Bühne.
                Button("Handbuch…", systemImage: "book") { blatt = .handbuch }
                Toggle("Bedienung prüfen", isOn: $werk.zeigeGriffprobe)
                // Der Befund wird abgetippt oder abfotografiert, solange er
                // nur auf der Seite steht — und eine Messung, die man
                // abschreiben muss, kommt verkürzt an. Dieselbe Bauweise
                // wie bei „Zustellung prüfen" in Schulalarm: kopierbar,
                // ohne Deutung.
                Button("Befund kopieren", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = befundtext
                    werk.meldung = Reisewerk.Meldung(text: "Der Befund liegt in der Zwischenablage.")
                }
                // Gezählt wird beim TIPP und nicht im Körper des Menüs: Ein
                // Menü baut seinen Inhalt bei jedem Zeichnen der
                // Werkzeugleiste, und der Lauf geht über alle Seiten und
                // Blöcke des Buches. Dieselbe Falle wie bei der
                // Druckprüfung in 1.0.0.
                Button("Leere Bildunterschriften abschalten",
                       systemImage: "text.bubble") {
                    let zahl = werk.leereUnterschriftenAbschalten()
                    werk.meldung = Reisewerk.Meldung(
                        text: zahl == 0
                            ? "Es gibt keine leeren Bildunterschriften."
                            : "\(zahl) leere Bildunterschrift\(zahl == 1 ? "" : "en") abgeschaltet. Mit \u{201E}Widerrufen\u{201C} zurückzunehmen."
                    )
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
                // WIE DIE SEITEN DIESES TAGES GESETZT WERDEN.
                //
                // Hieß bis 1.0.30 „Seitenmuster" und wurde nicht gefunden
                // (gemeldet 09/2026: „Die angekündigte Option Tagebuch,
                // Text und Bilder im Wechsel finde ich nicht."). Zwei
                // Gründe, und beide sind behoben: Der Menüpunkt nannte
                // ein Fachwort statt einer Frage, und der Knopf darüber
                // trug nur ein Kalendersymbol — man sah dem Menü nicht an,
                // dass DIESER Tag dahintersteckt. Der Name des geltenden
                // Musters steht jetzt daneben; ein Menü, das seinen
                // eigenen Stand verschweigt, lässt einen raten.
                Menu {
                    Button {
                        musterSetzen(nil)
                    } label: {
                        if tag.muster == nil {
                            Label("Automatisch wählen", systemImage: "checkmark")
                        } else {
                            Text("Automatisch wählen")
                        }
                    }
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
                    Divider()
                    Button("Für ALLE Tage übernehmen", systemImage: "square.stack.3d.up") {
                        werk.musterFuerAlle(werk.tag?.muster)
                    }
                } label: {
                    Text("Seiten setzen: \(mustername(tag))")
                }
                // SEITEN AN BESTIMMTEN STELLEN (ab 1.0.33).
                //
                // Bis 1.0.32 stand hier nur „Seite anfügen", und das hängte
                // immer hinten an. Eine Stelle mitten im Tag ließ sich gar
                // nicht ansprechen, und das Entfernen lag im Inspektor —
                // also dort, wo man einen Block bearbeitet.
                Button("Seiten…", systemImage: "rectangle.stack") {
                    blatt = .seiten(tag.id)
                }
                Button("Seite anfügen", systemImage: "plus.rectangle.on.rectangle") {
                    werk.seiteHinzufuegen(tag.id)
                }
            } label: {
                // Der Knopf trägt das DATUM sichtbar. Als reines Symbol war
                // er einer von vier gleich aussehenden Kreisen in der
                // Werkzeugleiste, und dass darin alles zu diesem einen Tag
                // steht, stand nirgends.
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                    Text(tag.datum.kurz)
                }
            }
        }
    }

    // Der ganze Befund für die Zwischenablage.
    //
    // Die JETZIGE Lage der Bühne steht mit drin und wird erst beim Tippen
    // gelesen: Sie ändert sich bei jedem Bildpunkt des Schiebens, und ein
    // Zustand, der dabei mitschriebe, zeichnete die Bühne sechzigmal in der
    // Sekunde neu (die Lehre aus 1.0.16 — `Inhaltslage` steht genau deshalb
    // in einer schlichten Klasse und nicht in `@State`).
    private var befundtext: String {
        let freiQuer = Double(lage.groesse.width) - buehnenbreite
        let freiHoch = Double(lage.groesse.height) - buehnenhoehe
        let jetzt = String(
            format: "Jetzt: Ma\u{00DF}stab %.0f %% \u{00B7} B\u{00FC}hne %.0f\u{00D7}%.0f \u{00B7} "
                  + "Inhalt %.0f\u{00D7}%.0f \u{00B7} Versatz %.0f/%.0f \u{00B7} "
                  + "frei \u{21C4}%.0f \u{2195}%.0f",
            massstabJetzt * 100, buehnenbreite, buehnenhoehe,
            Double(lage.groesse.width), Double(lage.groesse.height),
            Double(lage.ursprung.x), Double(lage.ursprung.y), freiQuer, freiHoch)
        // WANDERT DIE BÜHNE? (ab 1.0.24) Gemeldet 09/2026, zum zweiten Mal:
        // „Ein Verschieben der Arbeitsfläche ist auch nach wie vor nicht
        // möglich." Bleibt die Spanne null, während jemand schiebt, rollt
        // die Bühne nicht — dann ist es keine Frage der Rechnung oben.
        let gewandert = String(
            format: "Gewandert seit dem \u{00D6}ffnen: \u{21C4}%.0f \u{2195}%.0f "
                  + "(%d Meldungen)",
            Double(lage.spanne.width), Double(lage.spanne.height), lage.meldungen)
        // OB DIE GESTE DER SEITE GEHÖRT — und der Verdacht aus 1.0.27 ist
        // WIDERLEGT (ab 1.0.28).
        //
        // 1.0.27 schrieb hier als naheliegenden Grund für „erst beim
        // dritten Versuch" auf, dass zwei Finger über einem gewählten Foto
        // seit 1.0.8 dem Bildausschnitt gehören und ein zu kurzes Aufziehen
        // als Tipp ankommt, der die Auswahl aufhebt. Der Nutzer hat dem
        // ausdrücklich widersprochen (09/2026: „ich kann dir versichern,
        // dass ich kein Bild ausgewählt habe"). Damit ist die Sperre nicht
        // die Ursache — sie wird weiter genannt, weil die Zeile eine
        // MESSUNG ist und keine Erklärung war; sie schließt einen Zweig
        // aus, mehr wollte sie nie. Der Grund steht seit 1.0.28 eine Ebene
        // tiefer, am `simultaneousGesture` der Bühne.
        //
        // „Zoomgeste" unten zählt seit 1.0.59 WIRKLICH mit — bis dahin
        // stand dieser Satz da und kein Aufruf dahinter. Bleibt die Zahl
        // null, während jemand aufzieht, hat der Erkenner nie begonnen;
        // steht sie hoch und „Seite" bei null, kommt die Geste an, ohne
        // dass sich die Seiten mitzeichnen.
        let sperre = seitenzoomErlaubt
            ? "Seitenzoom: erlaubt"
            : (werk.ausschnittsmodus != nil
                ? "Seitenzoom: gesperrt (Ausschnittsmodus)"
                : "Seitenzoom: gesperrt (ein Foto ist gew\u{00E4}hlt)")
        // WO DIE BILDER LIEGEN (ab 1.0.71). Nach der Meldung „Auf dem
        // iPad ist kein Arbeiten möglich" ist das die Zahl, an der sich
        // entscheidet, ob das Buch überhaupt vollständig auf diesem Gerät
        // ist — und „lädt noch" von „fehlt" trennt. Daneben steht, wie
        // viele Namen gerade als nicht lesbar gemerkt sind: Solange die
        // Zahl hoch ist, liegen Bilder nicht auf der Platte.
        let bilder = (werk.bildstand?.befund ?? "Bilder: noch nicht nachgesehen")
            + " · \(Bildarchiv.shared.fehlgriffzahl) als nicht lesbar gemerkt"
        return [werk.letzterGriff ?? "noch nichts gegriffen",
                werk.letzteBuehne ?? "noch nicht gezoomt",
                jetzt,
                gewandert,
                sperre,
                bilder,
                Schaerfeprobe.shared.befund,
                werk.messer.befund].joined(separator: "\n")
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
        guard let id = werk.gewaehlterBlock else { return nil }
        return werk.blockWert(id)
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

    // Was gerade gilt — ausdrücklich gesetzt oder vom Automaten gewählt.
    private func mustername(_ tag: Reisetag) -> String {
        if let muster = tag.muster { return muster.name }
        return "automatisch (\(werk.gewaehltesMuster(tag.id)?.name ?? "—"))"
    }

    private func musterSetzen(_ muster: Seitenmuster?) {
        guard let tag = werk.tag else { return }
        werk.musterSetzen(tag.id, muster: muster)
    }

    // MARK: - Bänder

    @ViewBuilder
    private var baender: some View {
        VStack(spacing: 6) {
            // DAS BEFUNDBAND STEHT OBEN (ab 1.0.96).
            //
            // Wer die roten Umrandungen sieht, sucht hier: wie viele es
            // sind, wie man weiterkommt und wie man sie wieder loswird.
            // **Ein Zustand ohne sichtbaren Ausgang ist ein
            // hängengebliebenes Programm** — die Regel steht seit 1.0.9 im
            // Papier (sie kam damals vom offenen Textfeld) und galt für
            // diesen Modus nicht: Eingeschaltet wurde er mit einem Knopf
            // in der Druckprüfung, ausgeschaltet nur mit einem Schalter
            // drei Ebenen weit weg im Drei-Punkte-Menü.
            if werk.zeigeBefunde, !werk.befundstellen.isEmpty {
                befundband
            }
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
            // WAS NOCH IN iCLOUD LIEGT, STEHT DA (ab 1.0.71).
            //
            // Ein Buch, das von einem anderen Gerät kommt, ist lesbar,
            // bevor seine Bilder da sind — die JSON-Datei ist klein, die
            // Bilder sind es nicht. Ohne diese Zeile sieht ein Bild, das
            // gerade lädt, genauso aus wie eines, das fort ist, und die App
            // sieht aus wie eine, die nichts findet.
            //
            // Rot nur, wenn wirklich etwas fehlt: „lädt noch" ist kein
            // Fehler, sondern ein Zustand, der von selbst vergeht.
            if let stand = werk.bildstand, !stand.vollstaendig {
                band(stand.satz,
                     farbe: stand.fehlt > 0 ? .red : .orange,
                     knopf: "Jetzt holen") {
                    werk.bilderJetztHolen()
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

    // Drei Knöpfe, weil es drei Fragen sind: weiterkommen, auflösen,
    // wegräumen. Die `band`-Funktion darunter trägt nur einen.
    private var befundband: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.footnote)
            Text(befundzaehler)
                .font(.footnote)
            Button("Weiter") { werk.naechsterBefund() }
                .font(.footnote.weight(.semibold))
            if werk.anpassbareBefunde > 0 {
                Button(anpassknopf) { rahmenAnpassen() }
                    .font(.footnote.weight(.semibold))
            }
            Button("Ausblenden") { werk.zeigeBefunde = false }
                .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.red.opacity(0.5)))
        .padding(.horizontal, 14)
    }

    private var anpassknopf: String {
        "Rahmen anpassen (\(werk.anpassbareBefunde))"
    }

    // Der Weg von der Meldung zur Lösung. Ohne ihn nennt die App einen
    // Fehler und lässt einen damit stehen — und genau das war die Meldung.
    private func rahmenAnpassen() {
        let zahl = werk.alleRahmenAnpassen()
        let satz: String
        if zahl == 0 {
            satz = "Kein Rahmen ließ sich anpassen."
        } else if zahl == 1 {
            satz = "Ein Rahmen wurde an seinen Text angepasst. Der Tag gilt damit als von Hand bearbeitet; mit \u{201E}Widerrufen\u{201C} zurückzunehmen."
        } else {
            satz = "\(zahl) Rahmen wurden an ihren Text angepasst. Diese Tage gelten damit als von Hand bearbeitet; mit \u{201E}Widerrufen\u{201C} zurückzunehmen."
        }
        werk.meldung = Reisewerk.Meldung(text: satz)
    }

    private func band(_ text: String, farbe: Color, knopf: String = "Fertig",
                      schliessen: @escaping () -> Void) -> some View
    {
        HStack(spacing: 10) {
            Text(text)
                .font(.footnote)
                .multilineTextAlignment(.leading)
            Button(knopf, action: schliessen)
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
            AufbauView(werk: werk) { ziel in
                // Der geführte Weg kehrt nach jedem Einleseschritt in den
                // Aufbau zurück — außer nach dem Aufbau selbst.
                alsNaechstes = Blattwunsch(ziel: ziel,
                                           zurueckZumAufbau: ziel.id != "aufbau")
            }
        case .stil:
            StilView(werk: werk)
        case .vorlagen:
            VorlagenView(werk: werk)
        case .hintergrund:
            HintergrundView(werk: werk)
        case .wasserzeichen:
            WasserzeichenView(werk: werk)
        case .textimport:
            TextimportView(werk: werk)
        case .fotos:
            FotoeinfuhrView(werk: werk)
        case .dateien:
            DateieinfuhrView(werk: werk)
        case .grafik:
            GrafikEinfuehrView(werk: werk)
        case .bildAusFotos:
            BildAusFotosView(werk: werk)
        case .tagesspur:
            SpurimportView(werk: werk)
        case .typografie:
            TypografieView(werk: werk)
        case .fotostil:
            FotostilView(werk: werk)
        case .textstil:
            TextstilView(werk: werk)
        case .kartenstil:
            KartenstilView(werk: werk)
        case .gestaltung:
            GestaltungView(werk: werk)
        case .umschlag:
            UmschlagView(werk: werk)
        case .seitenformat:
            FormatView(werk: werk)
        case .bedienung:
            BedienungView()
        case .ausgabe:
            AusgabeView(werk: werk)
        case .ausgabeformat:
            Ausgabeformatblatt(werk: werk)
        case .druckpruefung:
            Druckpruefungblatt(werk: werk)
        case .handbuch:
            Handbuchblatt { ziel in alsNaechstes = Blattwunsch(ziel: ziel) }
        case .zweiDateien:
            AusgabeView(werk: werk, vorwahl: .getrennt)
        case .nurUmschlag:
            AusgabeView(werk: werk, vorwahl: .nurUmschlag)
        case .doppelseiten:
            AusgabeView(werk: werk, vorwahl: .doppelseiten)
        case .broschuere:
            AusgabeView(werk: werk, vorwahl: .broschuere)
        case .neuverteilen:
            NeuverteilenView(werk: werk)
        case let .tagInhalt(id):
            TagInhaltView(werk: werk, tagID: id)
        case let .spur(id):
            SpurView(werk: werk, tagID: id)
        case let .seiten(id):
            SeitenView(werk: werk, tagID: id)
        case .ablage:
            AblageView(werk: werk)
        }
    }
}
