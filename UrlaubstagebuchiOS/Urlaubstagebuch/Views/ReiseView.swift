import SwiftUI

struct ReiseView: View {
    @ObservedObject var werk: Reisewerk
    @EnvironmentObject private var regal: Regal

    @State private var spalten = NavigationSplitViewVisibility.automatic
    @State private var inspektor = false
    @State private var zoom: Double = 0
    @State private var blatt: Blatt?
    @State private var neuAnordnenFrage: UUID?

    enum Blatt: Identifiable {
        case textimport
        case fotos
        case dateien
        case typografie
        case gestaltung
        case ausgabe
        case tagInhalt(UUID)
        case spur(UUID)
        case ablage

        var id: String {
            switch self {
            case .textimport: return "text"
            case .fotos: return "fotos"
            case .dateien: return "dateien"
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
        let format = werk.reise.format.groesse
        let passend = max((raum.width - 56) / format.width, 0.12)
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
            } label: {
                Label("Satz", systemImage: "wand.and.stars")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Schrift und Ausrichtung…", systemImage: "textformat") {
                    blatt = .typografie
                }
                Button("Format, Ränder, Karte…", systemImage: "ruler") { blatt = .gestaltung }
                Divider()
                Button("Als PDF sichern…", systemImage: "square.and.arrow.up") { blatt = .ausgabe }
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
        case .textimport:
            TextimportView(werk: werk)
        case .fotos:
            FotoeinfuhrView(werk: werk)
        case .dateien:
            DateieinfuhrView(werk: werk)
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
