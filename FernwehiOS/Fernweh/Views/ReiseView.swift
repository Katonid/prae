import SwiftUI
import CloudKit
import CoreData

/// Eine Reise: oben die Karte, darunter Zahlen, Beteiligte und die Tage.
struct ReiseView: View {
    @ObservedObject var reise: Reise
    @EnvironmentObject private var aufzeichner: Aufzeichner
    @Environment(\.dismiss) private var schliessen

    @State private var freigabe: CKShare?
    @State private var darf = true
    @State private var besitzer = true
    @State private var editor: EditorWunsch?
    @State private var bearbeiten = false
    @State private var vollkarte = false
    @State private var beteiligte = false
    @State private var uebergabe = false
    @State private var loeschenFragen = false
    @State private var verlassenFragen = false
    @State private var fotoimport = false
    @State private var wanderimport = false
    @State private var fahrtenimport = false
    @State private var sicherung = false
    @State private var texte = false

    /// Ein Wunsch trägt sein Ziel — kein Schalter daneben (Lehre aus
    /// Tafelbild und der Abfahrtstafel: `.sheet(item:)`, sonst baut SwiftUI
    /// das Blatt aus dem Stand des vorigen Durchgangs).
    struct EditorWunsch: Identifiable {
        let id = UUID()
        let tag: Date?
        var art: Eintragsart = .eintrag
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                kopf
                VStack(alignment: .leading, spacing: 22) {
                    titelBlock
                    kennzahlen
                    if reise.laeuft && darf { SpurKarte(reise: reise) }
                    if freigabe != nil { beteiligtenZeile }
                    if !darf { betrachterHinweis }
                    if reise.liegtInZukunft { Vorfreude(reise: reise) }
                    if darf && !reise.laeuft && !reise.liegtInZukunft && reise.eintragListe.isEmpty {
                        nachtragKarte
                    }
                    tage
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 110)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                        .shadow(color: .black.opacity(0.12), radius: 16, y: -6)
                )
                .offset(y: -30)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color(uiColor: .systemBackground))
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar { werkzeuge }
        .overlay(alignment: .bottomTrailing) {
            if darf && !reise.liegtInZukunft {
                Button { editor = EditorWunsch(tag: nil) } label: {
                    Label("Eintrag", systemImage: "square.and.pencil")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 15)
                        .background(reise.palette.verlauf, in: Capsule())
                        .shadow(color: reise.palette.haupt.opacity(0.45), radius: 14, y: 8)
                }
                .padding(22)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(item: $editor) { wunsch in
            EintragEditor(vorgabe: reise, eintrag: nil, tag: wunsch.tag, art: wunsch.art)
        }
        .sheet(isPresented: $fotoimport) { FotoimportView(reise: reise) }
        .sheet(isPresented: $wanderimport) { WanderungImportView(reise: reise) }
        .sheet(isPresented: $fahrtenimport) { FahrtenImportView(reise: reise) }
        .sheet(isPresented: $bearbeiten) { ReiseFormular(reise: reise) }
        .sheet(isPresented: $beteiligte) { BeteiligteView(reise: reise) }
        .sheet(isPresented: $uebergabe) { UebergabeView(reise: reise) }
        .sheet(isPresented: $sicherung) { SicherungView(vorgabe: .reise(reise.objectID)) }
        .sheet(isPresented: $texte) { TexteView(reise: reise) }
        .fullScreenCover(isPresented: $vollkarte) { Vollkarte(reise: reise) }
        .confirmationDialog("Reise löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
            Button("Löschen — auf allen Geräten", role: .destructive) { loeschen() }
        } message: {
            Text(freigabe == nil
                 ? "Alle Einträge, Fotos und Spuren dieser Reise verschwinden auf allen deinen Geräten."
                 : "Die Reise verschwindet auch bei allen Miturlaubern und Betrachtern.")
        }
        .confirmationDialog("Reise verlassen?", isPresented: $verlassenFragen, titleVisibility: .visible) {
            Button("Verlassen", role: .destructive) {
                Persistenz.shared.verlassen(reise)
                schliessen()
            }
        } message: {
            Text("Die Reise verschwindet von deinen Geräten. Bei den anderen bleibt sie, wie sie ist.")
        }
        .task {
            rechtePruefen()
            // Fehlendes Wetter nachholen (ab 1.0.18): alte Einträge,
            // Vorhersagen vergangener Tage, Einträge ohne Netz.
            if darf { await Wetternachtrag.nachtragen(reise.eintragListe) }
        }
        .onAppear { aufzeichner.uebertragen() }
    }

    private func rechtePruefen() {
        let persistenz = Persistenz.shared
        freigabe = persistenz.freigabe(fuer: reise)
        darf = persistenz.darfBearbeiten(reise)
        besitzer = !persistenz.liegtImGeteiltenSpeicher(reise)
    }

    // MARK: - Kopf

    private var kopf: some View {
        ZStack(alignment: .bottomLeading) {
            Reisekarte(reise: reise)
                .frame(height: 380)
                .overlay(alignment: .top) {
                    LinearGradient(colors: [.black.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 120)
                        .allowsHitTesting(false)
                }
            Button { vollkarte = true } label: {
                Label("Karte", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.leading, 16)
            .padding(.bottom, 46)
        }
        .contentShape(Rectangle())
        .onTapGesture { vollkarte = true }
    }

    private var titelBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if reise.laeuft {
                    HStack(spacing: 5) {
                        Pulspunkt(farbe: .white)
                        Text("Unterwegs · Tag \(Tag.abstand(von: reise.anfang, bis: Date()) + 1)")
                    }
                    .etikett(reise.palette.haupt)
                }
                Text(Tag.zeitraum(reise.anfang, reise.ende))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Reisesymbol.mitTitel(reise.emoji, reise.anzeigeTitel)
                .font(Stil.titel(32))
            if let u = reise.untertitel, !u.isEmpty {
                Text(u).font(.title3).foregroundStyle(.secondary)
            }
        }
    }

    private var kennzahlen: some View {
        HStack(spacing: 0) {
            Kennzahl(wert: "\(max(reise.bisherigeTage.count, 0))", beschriftung: "Tage", symbol: "sun.max.fill")
            Kennzahl(wert: reise.kilometer < 10 ? String(format: "%.1f", reise.kilometer) : "\(Int(reise.kilometer))",
                     beschriftung: "Kilometer", symbol: "point.topleft.down.to.point.bottomright.curvepath")
            Kennzahl(wert: "\(reise.eintragListe.count)", beschriftung: "Einträge", symbol: "book.pages.fill")
            Kennzahl(wert: "\(reise.fotoAnzahl)", beschriftung: "Fotos", symbol: "photo.fill")
            if reise.laender.count > 1 {
                Kennzahl(wert: "\(reise.laender.count)", beschriftung: "Länder", symbol: "globe.europe.africa.fill")
            }
        }
        .padding(.vertical, 14)
        .background(reise.palette.hell.opacity(0.14), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var beteiligtenZeile: some View {
        let liste = Beteiligte.lesen(freigabe)
        return Button { beteiligte = true } label: {
            HStack(spacing: 12) {
                HStack(spacing: -8) {
                    ForEach(liste.prefix(5)) { b in
                        Monogramm(name: b.name, groesse: 32,
                                  farbe: b.rolle == .betrachter ? .gray : reise.palette.haupt)
                            .overlay(Circle().strokeBorder(Color(uiColor: .systemBackground), lineWidth: 2))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    let mit = liste.filter { $0.rolle != .betrachter }.count
                    let zu = liste.filter { $0.rolle == .betrachter }.count
                    Text(mit > 1 ? "\(mit) reisen mit" : "Geteilte Reise")
                        .font(.subheadline.weight(.semibold))
                    Text(zu == 1 ? "1 Person schaut zu" : (zu > 1 ? "\(zu) Personen schauen zu" : "Noch niemand schaut zu"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var betrachterHinweis: some View {
        Label("Du verfolgst diese Reise als Betrachter. Schreiben können nur die Mitreisenden.", systemImage: "eye.fill")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Nachtragen (ab 1.0.17)

    /// Eine vergangene Reise ohne Einträge: die drei Wege, sie nachträglich
    /// zu füllen, gleich sichtbar — nicht versteckt im Menü.
    private var nachtragKarte: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reise nachtragen").font(.headline)
            Text("Die Fotos aus dem Zeitraum der Reise werden je Tag zu einem Eintrag mit Uhrzeit, Ort und Wetter. Texte schreibst du danach — zum Tag und zu jedem Foto.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button { fotoimport = true } label: {
                Label("Fotos übernehmen", systemImage: "photo.stack").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(reise.palette.haupt)
            HStack {
                Button { editor = EditorWunsch(tag: nil, art: .seite) } label: {
                    Label("Freie Seite", systemImage: "doc.richtext").frame(maxWidth: .infinity)
                }
                Button { wanderimport = true } label: {
                    Label("Wanderung", systemImage: "figure.hiking").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .tint(reise.palette.haupt)
            Button { fahrtenimport = true } label: {
                Label("Autofahrten aus GPX-Dateien", systemImage: "car.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(reise.palette.haupt)
        }
        .padding(16)
        .background(reise.palette.hell.opacity(0.14), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Tage

    @ViewBuilder
    private var tage: some View {
        let alle = reise.bisherigeTage
        if alle.isEmpty && !reise.liegtInZukunft {
            Text("Noch keine Tage.").foregroundStyle(.secondary)
        }
        // Während der Reise steht der heutige Tag oben; danach liest man sie
        // wie ein Buch, vom ersten Tag an.
        let nummeriert = Array(alle.enumerated())
        let reihe = reise.laeuft ? Array(nummeriert.reversed()) : nummeriert
        ForEach(reihe, id: \.offset) { nummer, tag in
            TagAbschnitt(reise: reise, tag: tag, nummer: nummer + 1, darf: darf) {
                editor = EditorWunsch(tag: tag)
            }
        }
    }

    // MARK: - Werkzeuge

    @ToolbarContentBuilder
    private var werkzeuge: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if darf {
                    Button { bearbeiten = true } label: { Label("Reise bearbeiten", systemImage: "pencil") }
                }
                if darf && !reise.liegtInZukunft {
                    Section("Hinzufügen") {
                        Button { fotoimport = true } label: { Label("Fotos übernehmen …", systemImage: "photo.stack") }
                        Button { editor = EditorWunsch(tag: nil, art: .seite) } label: {
                            Label("Freie Seite", systemImage: "doc.richtext")
                        }
                        Button { wanderimport = true } label: {
                            Label("Wanderung aus Komoot …", systemImage: "figure.hiking")
                        }
                        Button { fahrtenimport = true } label: {
                            Label("Autofahrten (GPX) …", systemImage: "car.fill")
                        }
                    }
                }
                if besitzer {
                    Section("Einladen") {
                        Button {
                            Task { await Teilen.zeigen(reise: reise, als: .mitreisende); rechtePruefen() }
                        } label: { Label("Miturlauber einladen", systemImage: "person.badge.plus") }
                        Button {
                            Task { await Teilen.zeigen(reise: reise, als: .betrachter); rechtePruefen() }
                        } label: { Label("Betrachter einladen", systemImage: "eye") }
                    }
                }
                if freigabe != nil {
                    Button { beteiligte = true } label: { Label("Wer ist dabei?", systemImage: "person.2") }
                }
                Section("Weitergeben") {
                    Button { uebergabe = true } label: { Label("Fürs Fotobuch übergeben", systemImage: "book.closed") }
                    Button { sicherung = true } label: { Label("Reise sichern …", systemImage: "externaldrive.badge.plus") }
                    Button { texte = true } label: { Label("Texte überarbeiten (KI) …", systemImage: "text.badge.checkmark") }
                }
                Section {
                    if besitzer {
                        Button(role: .destructive) { loeschenFragen = true } label: { Label("Reise löschen", systemImage: "trash") }
                    } else {
                        Button(role: .destructive) { verlassenFragen = true } label: { Label("Reise verlassen", systemImage: "rectangle.portrait.and.arrow.right") }
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .frame(width: 34, height: 34)
                    .background(.regularMaterial, in: Circle())
            }
        }
    }

    private func loeschen() {
        let persistenz = Persistenz.shared
        persistenz.kontext.delete(reise)
        persistenz.sichern()
        schliessen()
    }
}

// MARK: - Die Reisespur

private struct SpurKarte: View {
    @ObservedObject var reise: Reise
    @EnvironmentObject private var aufzeichner: Aufzeichner

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $aufzeichner.eingeschaltet) {
                HStack(spacing: 10) {
                    if aufzeichner.eingeschaltet && aufzeichner.darfOrten {
                        Pulspunkt(farbe: reise.palette.haupt)
                    } else {
                        Image(systemName: "location.slash").foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reisespur").font(.headline)
                        Text(zustand).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .tint(reise.palette.haupt)
            .onChange(of: aufzeichner.eingeschaltet) { _, an in
                if an { aufzeichner.erlaubnisAnfragen() }
            }

            if aufzeichner.eingeschaltet && !aufzeichner.hatImmer {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(aufzeichner.darfOrten
                         ? "Nur „Beim Verwenden“ erlaubt: Die Spur reißt ab, sobald iOS die App beendet."
                         : "Die Ortung ist nicht erlaubt.")
                        .font(.caption)
                    Spacer(minLength: 4)
                    Button(aufzeichner.darfOrten ? "„Immer“" : "Erlauben") { aufzeichner.erlaubnisAnfragen() }
                        .font(.caption.weight(.bold))
                        .buttonStyle(.bordered)
                }
            } else if aufzeichner.eingeschaltet && !aufzeichner.genau {
                HStack {
                    Image(systemName: "scope").foregroundStyle(.orange)
                    Text("Nur ungefähre Ortung — die Spur liegt daneben.").font(.caption)
                    Spacer(minLength: 4)
                    Button("Genau") { aufzeichner.genauAnfragen() }
                        .font(.caption.weight(.bold))
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var zustand: String {
        guard aufzeichner.eingeschaltet else { return "Aus — heute entsteht keine Spur." }
        guard aufzeichner.darfOrten else { return "Wartet auf die Ortungserlaubnis." }
        let punkte = aufzeichner.punkteHeute
        let teil = punkte == 0 ? "noch keine Punkte heute" : "\(punkte) Punkte heute"
        return aufzeichner.ruht ? "Pause, du bewegst dich nicht · \(teil)" : "Läuft · \(teil)"
    }
}

// MARK: - Vorfreude

private struct Vorfreude: View {
    @ObservedObject var reise: Reise

    var body: some View {
        let tage = Tag.abstand(von: Date(), bis: reise.anfang)
        VStack(spacing: 6) {
            Text("\(tage)")
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(reise.palette.verlauf)
                .contentTransition(.numericText())
            Text(tage == 1 ? "Tag bis zur Abreise" : "Tage bis zur Abreise")
                .font(.headline)
            Text("Am ersten Reisetag beginnt die Spur von selbst, wenn die Aufzeichnung eingeschaltet ist.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(reise.palette.hell.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Ein Tag

private struct TagAbschnitt: View {
    @ObservedObject var reise: Reise
    let tag: Date
    let nummer: Int
    let darf: Bool
    var schreiben: () -> Void
    @State private var wetter: Wetternachtrag.Tageswahl?
    @State private var karteOffen = false

    /// Ändert sich, sobald ein Eintrag des Tages Wetter bekommt.
    private var wetterStand: String {
        Tag.schluessel(tag) + reise.eintraege(am: tag).map { $0.wetter ?? "" }.joined()
            + "\(reise.spuren(am: tag).count)"
    }

    var body: some View {
        let eintraege = reise.eintraege(am: tag)
        // Spur, Autofahrten und Wanderungen (ab 1.0.21) — wie die Summe oben.
        let km = reise.meter(am: Tag.schluessel(tag))
        let fahrten = reise.fahrten(am: Tag.schluessel(tag))
        let heute = Tag.schluessel(tag) == Tag.schluessel(Date())
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(heute ? "Heute · Tag \(nummer)" : "Tag \(nummer)")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(reise.palette.haupt)
                        .textCase(.uppercase)
                    Text(Tag.wochentagLang.string(from: tag))
                        .font(Stil.titel(21))
                }
                Spacer()
                if km >= 100 {
                    Label(km >= 10_000 ? "\(Int(km / 1000)) km" : String(format: "%.1f km", km / 1000),
                          systemImage: "figure.walk")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            // Das Wetter des Tages am Ort (ab 1.0.18) — auch an einem Tag,
            // an dem nur eine Spur entstand.
            if let wetter {
                HStack(spacing: 8) {
                    WetterLeiste(wetter: wetter.wetter, kompakt: true)
                    if !wetter.ortName.isEmpty {
                        Text("in \(wetter.ortName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if wetter.wetter.vorhersage {
                        Text("Vorhersage").font(.caption2).foregroundStyle(.orange)
                    }
                }
            }

            // Die Karte des Tages (ab 1.0.26, Ansage des Nutzers 09/2026:
            // „Wenn ich mir einen einzelnen Urlaubstag … auswähle, sehe ich
            // dort aber nur die Komoot-Karten"). Spur, Autofahrten,
            // Wanderungen und Fotos dieses Tages, dieselben Schalter wie in
            // der Gesamtkarte. Ein BILD in der Rolle (kein Wisch geschluckt);
            // ein Tipp öffnet die Vollkarte auf diesem Tag.
            if !reise.spuren(am: tag).isEmpty
                || eintraege.contains(where: { $0.hatOrt || $0.eintragsart == .wanderung
                    || $0.fotoListe.contains { $0.koordinate != nil } }) {
                VStack(alignment: .leading, spacing: 8) {
                    Reisekarte(reise: reise, tag: tag, fotosZeigen: true)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .allowsHitTesting(false)
                        .overlay(alignment: .topTrailing) { VollbildHinweis() }
                        .overlay {
                            Color.clear.contentShape(Rectangle()).onTapGesture { karteOffen = true }
                        }
                    ScrollView(.horizontal, showsIndicators: false) {
                        Ebenenwahl(palette: reise.palette)
                    }
                }
                .fullScreenCover(isPresented: $karteOffen) { Vollkarte(reise: reise, startTag: tag) }
            }

            // Die Autofahrten des Tages (ab 1.0.21), je eine Zeile.
            if !fahrten.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(fahrten) { f in
                        Fahrtzeile(spur: f, darf: darf)
                    }
                }
            }

            ForEach(eintraege) { eintrag in
                EintragVerweis(eintrag: eintrag, palette: reise.palette)
            }

            if darf && eintraege.isEmpty {
                Button(action: schreiben) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(heute ? "Was hast du heute erlebt?" : "Von diesem Tag erzählen")
                        Spacer()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(reise.palette.haupt)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(reise.palette.haupt.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    )
                }
                .buttonStyle(.plain)
            } else if darf {
                Button(action: schreiben) {
                    Label("Weiterer Eintrag", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(reise.palette.haupt)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
        .task(id: wetterStand) {
            wetter = await Wetternachtrag.tag(Tag.schluessel(tag), in: reise)
        }
    }
}

/// Eine Autofahrt unter ihrem Tag: Name, Uhrzeit, Kilometer. Lange drücken
/// → löschen.
private struct Fahrtzeile: View {
    @ObservedObject var spur: Spur
    let darf: Bool
    @ObservedObject private var farben = Kartenfarben.shared

    var body: some View {
        let punkte = spur.punktListe
        let zone = Fahrtenimport.zone(spur)
        let zeit = punkte.first.map { a in
            Tag.text(a.datum, "HH:mm", zone: zone) + (punkte.last.map { "–" + Tag.text($0.datum, "HH:mm", zone: zone) } ?? "")
        } ?? ""
        let teile = [Fahrtenimport.anzeigename(spur), zeit, Tagesspurwahl.kilometertext(spur.distanz / 1000)]
        Label(teile.filter { !$0.isEmpty }.joined(separator: " · "), systemImage: "car.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(farben.fahrt)
            .lineLimit(1)
            .contextMenu {
                if darf {
                    Button(role: .destructive) { Fahrtenimport.loeschen(spur) } label: {
                        Label("Fahrt entfernen", systemImage: "trash")
                    }
                }
            }
    }
}

/// Ein Eintrag in der Liste: Fotos, Titel, Ort, Anfang des Textes.
struct EintragKarte: View {
    @ObservedObject var eintrag: Eintrag
    let palette: Palette
    @ObservedObject private var buecherei = Buecherei.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !eintrag.fotoListe.isEmpty {
                Collage(fotos: eintrag.fotoListe)
            } else if eintrag.eintragsart == .wanderung {
                Wanderkarte(eintrag: eintrag, palette: palette, hoehe: 150, antippbar: false)
            }
            VStack(alignment: .leading, spacing: 6) {
                if eintrag.eintragsart == .seite {
                    Label("Seite", systemImage: "doc.richtext")
                        .font(.caption2.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(palette.haupt)
                }
                Text(eintrag.anzeigeTitel)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if eintrag.eintragsart == .wanderung {
                    WanderZeile(eintrag: eintrag)
                }
                HStack(spacing: 6) {
                    if let buch = eintrag.tagebuchName {
                        Label(buch, systemImage: "book.closed.fill")
                            .fontWeight(.semibold)
                            .foregroundStyle(buecherei.buchfarbe(buch).farbe)
                            .lineLimit(1)
                    }
                    if let ort = eintrag.ortsname, !ort.isEmpty, ort != eintrag.anzeigeTitel {
                        Label(ort, systemImage: "mappin.and.ellipse").lineLimit(1)
                    }
                    if eintrag.datum != nil && eintrag.eintragsart == .eintrag {
                        Text(eintrag.uhrzeitText)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let wetter = eintrag.tageswetter {
                    WetterLeiste(wetter: wetter, kompakt: true)
                }
                if let text = eintrag.text, !text.isEmpty {
                    Text(text)
                        .font(.callout)
                        .foregroundStyle(Color.primary.opacity(0.85))
                        .lineLimit(4)
                }
                if let autor = eintrag.autor, !autor.isEmpty {
                    HStack(spacing: 6) {
                        Monogramm(name: autor, groesse: 20, farbe: palette.haupt)
                        Text(autor).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        // Die Farbe des Tagebuchs als Streifen am Rand (ab 1.0.8) — so sieht
        // man beim Durchblättern, wohin ein Eintrag gehört, ohne zu lesen.
        .overlay(alignment: .leading) {
            if let farbe = buecherei.farbe(eintrag.tagebuchName) {
                Rectangle().fill(farbe).frame(width: 5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
