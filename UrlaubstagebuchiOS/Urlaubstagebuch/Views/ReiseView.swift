import SwiftUI

struct ReiseView: View {
    @ObservedObject var werk: Reisewerk
    @EnvironmentObject private var regal: Regal

    @State private var spalten = NavigationSplitViewVisibility.automatic
    @State private var inspektor = false
    @State private var zoom: Double = 0
    @State private var blatt: Blatt?
    @State private var neuAnordnenFrage: UUID?
    @State private var buchdatei: Buchwunsch?

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
        case gestaltung
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
            case .gestaltung: return "gestaltung"
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
            BlockInspektor(werk: werk)
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
                VStack(spacing: 26) {
                    ForEach(sichtbareSeiten) { buchseite in
                        VStack(spacing: 6) {
                            SeitenflaecheView(werk: werk, buchseite: buchseite,
                                              massstab: massstab(raum.size))
                            Text("Seite \(buchseite.nummer)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if sichtbareSeiten.isEmpty { hinweisLeer }
                }
                .padding(28)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle(titelzeile)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { werkzeuge }
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

    private var sichtbareSeiten: [Buchseite] {
        let alle = werk.reise.seitenfolge
        guard let gewaehlt = werk.gewaehlterTag else { return alle }
        if gewaehlt == Self.titelseitenKennung {
            return alle.filter { $0.tag == nil }
        }
        return alle.filter { $0.tag?.id == gewaehlt }
    }

    static let titelseitenKennung = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var titelzeile: String {
        if werk.gewaehlterTag == Self.titelseitenKennung { return "Titelseite" }
        return werk.tag?.datum.lang ?? werk.reise.titel
    }

    // Der Maßstab passt die Seite in die Breite ein, solange nicht
    // ausdrücklich gezoomt wurde. Ein Buch, das man erst zurechtschieben
    // muss, bevor man es sieht, ist keines.
    private func massstab(_ raum: CGSize) -> Double {
        let bogen = werk.reise.gestaltung.bogen(werk.reise.format)
        let passend = max((raum.width - 56) / bogen.width, 0.12)
        if zoom == 0 { return min(passend, 1.6) }
        return zoom
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
                Toggle("Bedienung prüfen", isOn: $werk.zeigeGriffprobe)
            } label: {
                Label("Satz", systemImage: "wand.and.stars")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Stil wählen…", systemImage: "paintpalette") { blatt = .stil }
                Button("Schrift und Ausrichtung…", systemImage: "textformat") {
                    blatt = .typografie
                }
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
            Button { zoom = max(massstabJetzt * 0.8, 0.12) } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            Button("Einpassen") { zoom = 0 }
            Button { zoom = min(massstabJetzt * 1.25, 4) } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            Spacer()
            // Ist ein Foto gewählt, steht hier der kürzeste Weg zu seiner
            // Unterschrift. Eine Geste, die niemand kennt (der Doppeltipp),
            // ist so wenig wert wie ein Schalter, den niemand findet —
            // deshalb beides.
            if let fotoID = gewaehltesFoto {
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

    private var massstabJetzt: Double { zoom == 0 ? 0.7 : zoom }

    // Welches Foto gerade gewählt ist — oder keines.
    private var gewaehltesFoto: UUID? {
        guard let id = werk.gewaehlterBlock, let stelle = werk.block(id) else { return nil }
        return werk.reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block].fotoID
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
        case .gestaltung:
            GestaltungView(werk: werk)
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
