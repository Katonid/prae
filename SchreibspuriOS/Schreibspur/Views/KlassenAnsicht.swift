import SwiftUI

/// Klassenübersicht für die Lehrkraft (seit 1.0.9, Ansage des Nutzers
/// 09/2026): welche Buchstaben jedes Kind schon bearbeitet hat, wie viele
/// Anläufe und Fehlversuche es dafür brauchte — freiwillige Wiederholungen
/// nicht mitgezählt — und jede bearbeitete Seite zum Nachsehen, neu
/// gezeichnet aus den gespeicherten Spuren.
struct KlassenAnsicht: View {
    @Environment(Klasse.self) private var klasse
    @Environment(\.dismiss) private var dismiss
    /// Welche Klasse gezeigt wird (nil: alle).
    @State private var klassencode: String?

    private var kinder: [Kind] {
        guard let klassencode else { return klasse.kinder }
        return klasse.kinder.filter { $0.klasse == klassencode }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Tippe auf ein Kind, um seine Buchstaben, Stufen und Seiten zu sehen.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    if let wolke = klasse.wolke {
                        Label(wolke.status, systemImage: "icloud").font(.footnote).foregroundStyle(.secondary)
                    }
                    if let wolke = klasse.wolke, wolke.klassen.count > 1 {
                        Picker("Klasse", selection: $klassencode) {
                            Text("Alle Klassen").tag(String?.none)
                            ForEach(wolke.klassen) { k in Text("Klasse \(k.name)").tag(String?.some(k.code)) }
                        }
                        .pickerStyle(.segmented)
                    }
                    Klassenraster(kinder: kinder)
                    Legende()
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Klassenübersicht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
                if let wolke = klasse.wolke {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            Task { await wolke.abgleichen() }
                        } label: {
                            Label("Aktualisieren", systemImage: "arrow.clockwise")
                        }
                        .disabled(wolke.arbeitet)
                    }
                }
            }
            // Was die Kinder auf ihren iPads geschrieben haben, holen.
            .refreshable { await klasse.wolke?.abgleichen() }
            .task { await klasse.wolke?.abgleichen() }
        }
    }
}

// MARK: - Raster: Kinder × Buchstaben

/// Eine Zeile je Kind, eine Spalte je Lektion (A a, M m …); je Buchstabe
/// fünf Punkte für die fünf Stufen.
private struct Klassenraster: View {
    let kinder: [Kind]
    @Environment(Klasse.self) private var klasse

    var body: some View {
        let lektionen = Zeichenvorrat.lehrgang.map(\.zeichen)
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: 6) {
                GridRow {
                    Text("")
                    ForEach(lektionen.indices, id: \.self) { i in
                        Text(lektionen[i].map(\.text).joined(separator: " "))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(Farben.tinteDunkel)
                            .frame(width: 56)
                    }
                }
                ForEach(kinder) { kind in
                    let je = Auswertung.je(klasse.protokoll.bearbeitungen(von: kind.id))
                    GridRow {
                        NavigationLink {
                            KindProtokollAnsicht(kindID: kind.id)
                        } label: {
                            HStack(spacing: 6) {
                                Text(kind.tier).font(.title2)
                                Text(kind.name)
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                    .lineLimit(1)
                                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                            }
                            .frame(minWidth: 150, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        ForEach(lektionen.indices, id: \.self) { i in
                            VStack(spacing: 3) {
                                ForEach(lektionen[i], id: \.id) { z in
                                    Stufenpunkte(kind: kind, zeichen: z, je: je)
                                }
                            }
                            .frame(width: 56, height: 34)
                            .background(RoundedRectangle(cornerRadius: 8).fill(.white))
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.6)))
    }
}

/// Fünf Punkte je Buchstabe: voll = mit drei Sternen gemeistert, hell =
/// geschafft, Ring = begonnen, grau = noch nicht bearbeitet.
private struct Stufenpunkte: View {
    let kind: Kind
    let zeichen: Zeichen
    let je: [String: Auswertung]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Stufe.stufen(fuer: zeichen)) { s in
                let sterne = kind.sterne[Kind.schluessel(zeichen, s)] ?? 0
                let begonnen = (je["\(zeichen.id)#\(s.rawValue)"]?.alle ?? 0) > 0
                ZStack {
                    Circle().fill(sterne == 3 ? Farben.start
                                  : sterne > 0 ? Farben.start.opacity(0.35)
                                  : Color.gray.opacity(0.15))
                    if sterne == 0 && begonnen {
                        Circle().strokeBorder(Farben.akzent, lineWidth: 1.5)
                    }
                }
                .frame(width: 8, height: 8)
            }
        }
    }
}

private struct Legende: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Je Buchstabe fünf Punkte für die Stufen 1 (Nachspuren) bis 5 (Heftseite):")
            HStack(spacing: 16) {
                eintrag(Circle().fill(Farben.start), "gemeistert (3 Sterne)")
                eintrag(Circle().fill(Farben.start.opacity(0.35)), "geschafft")
                eintrag(Circle().strokeBorder(Farben.akzent, lineWidth: 1.5), "begonnen")
                eintrag(Circle().fill(Color.gray.opacity(0.15)), "noch nicht")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func eintrag(_ form: some View, _ text: String) -> some View {
        HStack(spacing: 5) {
            form.frame(width: 10, height: 10)
            Text(text)
        }
    }
}

// MARK: - Ein Kind

/// Alles zu einem Kind: je Buchstabe und Stufe Sterne, Anläufe und
/// Fehlversuche; darunter die zuletzt bearbeiteten Seiten.
struct KindProtokollAnsicht: View {
    let kindID: UUID
    @Environment(Klasse.self) private var klasse
    @State private var auswahl: Auswahl?
    @State private var frageLoeschen = false

    /// Welche Bearbeitungen die Liste zeigt.
    struct Auswahl: Hashable {
        let titel: String
        let seiten: [String]
        let stufe: Int?
    }

    var body: some View {
        if let kind = klasse.kinder.first(where: { $0.id == kindID }) {
            inhalt(kind)
        } else {
            ContentUnavailableView("Kind nicht mehr vorhanden", systemImage: "person.slash")
        }
    }

    private func inhalt(_ kind: Kind) -> some View {
        let liste = klasse.protokoll.bearbeitungen(von: kind.id)
        let je = Auswertung.je(liste)
        let einzeln = Set(Zeichenvorrat.buchstaben.keys)
            .union(Zeichenvorrat.ziffern.map(\.id)).union(Zeichenvorrat.schwuenge.map(\.id))
        let seiten = liste.filter { $0.stufe == Stufe.heft.rawValue && !einzeln.contains($0.zeichen) }
        return List {
            Section {
                zusammenfassung(kind, liste)
            }

            Section {
                ForEach(Zeichenvorrat.lehrgang.indices, id: \.self) { i in
                    let lektion = Zeichenvorrat.lehrgang[i]
                    if lektion.schritt <= klasse.bekannterSchritt
                        || lektion.zeichen.contains(where: { z in geuebt(z, kind, je) }) {
                        ForEach(lektion.zeichen, id: \.id) { z in zeile(kind, z, je) }
                    }
                }
            } header: {
                kopf("Buchstaben")
            } footer: {
                Text("Sterne: bestes Ergebnis. „2 Anl.“: so oft angefangen, bis die Stufe gemeistert war — freiwillige Wiederholungen danach zählen nicht. „F“: Fehlversuche bis zur erfüllten Pflicht (auf der Heftseite zählt nicht, was das Kind danach freiwillig weiterschreibt). Tippe auf eine Stufe, um die Seiten zu sehen.")
            }

            let ziffern = Zeichenvorrat.ziffern.filter { z in geuebt(z, kind, je) }
            if !ziffern.isEmpty {
                Section { ForEach(ziffern, id: \.id) { zeile(kind, $0, je) } } header: { kopf("Ziffern") }
            }
            let schwuenge = Zeichenvorrat.schwuenge.filter { z in geuebt(z, kind, je) }
            if !schwuenge.isEmpty {
                Section { ForEach(schwuenge, id: \.id) { zeile(kind, $0, je) } } header: { kopf("Schwünge") }
            }
            if !seiten.isEmpty {
                Section("Wörter und Gemischt") {
                    ForEach(seiten.reversed()) { b in
                        NavigationLink { SeitenAnsicht(kindID: kind.id, bearbeitung: b) } label: {
                            BearbeitungsZeile(b: b)
                        }
                    }
                }
            }
            if !liste.isEmpty {
                Section("Zuletzt bearbeitet") {
                    ForEach(liste.suffix(15).reversed()) { b in
                        NavigationLink { SeitenAnsicht(kindID: kind.id, bearbeitung: b) } label: {
                            BearbeitungsZeile(b: b)
                        }
                    }
                    Button("Alle \(liste.count) Bearbeitungen") {
                        auswahl = Auswahl(titel: "Alle Bearbeitungen", seiten: [], stufe: nil)
                    }
                }
                Section {
                    Button("Aufzeichnungen dieses Kindes löschen", role: .destructive) { frageLoeschen = true }
                } footer: {
                    Text("Löscht die gespeicherten Seiten und Zählungen. Die Sterne bleiben (die löschst du unter Einstellungen → Kind).")
                }
            }
        }
        .navigationTitle("\(kind.tier) \(kind.name)")
        .navigationDestination(item: $auswahl) { a in
            BearbeitungsListe(kindID: kind.id, auswahl: a)
        }
        .confirmationDialog("Aufzeichnungen von \(kind.name) löschen?", isPresented: $frageLoeschen,
                            titleVisibility: .visible) {
            Button("Löschen", role: .destructive) { klasse.protokoll.loeschen(kind: kind.id) }
        }
    }

    private func kopf(_ text: String) -> some View {
        HStack {
            Text(text)
            Spacer()
            ForEach(1...5, id: \.self) { s in
                Text("\(s)").frame(width: Self.zellenBreite)
            }
        }
    }

    private static let zellenBreite: CGFloat = 62

    private func geuebt(_ z: Zeichen, _ kind: Kind, _ je: [String: Auswertung]) -> Bool {
        Stufe.stufen(fuer: z).contains { s in
            (kind.sterne[Kind.schluessel(z, s)] ?? 0) > 0 || je["\(z.id)#\(s.rawValue)"] != nil
        }
    }

    private func zusammenfassung(_ kind: Kind, _ liste: [Bearbeitung]) -> some View {
        let buchstaben = Zeichenvorrat.lehrgang.flatMap(\.zeichen)
        let begonnen = buchstaben.filter { z in
            liste.contains { b in b.zeichen == z.id || (b.stufe == 5 && Zeichenvorrat.seitenpartner(b.zeichen).contains(z.id)) }
                || Stufe.allCases.contains { (kind.sterne[Kind.schluessel(z, $0)] ?? 0) > 0 }
        }
        let fertig = buchstaben.filter { z in (kind.sterne[Kind.schluessel(z, .heft)] ?? 0) == 3 }
        let zeit = liste.reduce(0) { $0 + $1.dauer }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 24) {
                kennzahl("\(begonnen.count)", "Buchstaben begonnen")
                kennzahl("\(fertig.count)", "bis Stufe 5 gemeistert")
                kennzahl("\(liste.count)", "Bearbeitungen")
                kennzahl("\(Int((zeit / 60).rounded()))", "Minuten geschrieben")
            }
            if let letzte = liste.last {
                Text("Zuletzt: \(letzte.beginn.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Text("Genauigkeit: \(kind.genauigkeit.titel)").font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func kennzahl(_ wert: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(wert).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(Farben.tinteDunkel)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }

    /// Ein Buchstabe mit seinen Stufen; jede Stufe öffnet die Liste ihrer Seiten.
    private func zeile(_ kind: Kind, _ z: Zeichen, _ je: [String: Auswertung]) -> some View {
        HStack {
            ZeichenBild(zeichen: z)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(z.text).font(.system(.title3, design: .rounded, weight: .semibold))
            Spacer()
            ForEach(Stufe.allCases) { s in
                if Stufe.stufen(fuer: z).contains(s) {
                    let a = je["\(z.id)#\(s.rawValue)"]
                    let seiten = s == .heft ? Zeichenvorrat.seitenpartner(z.id) : [z.id]
                    Button {
                        auswahl = Auswahl(titel: "\(z.text) – Stufe \(s.rawValue)", seiten: seiten, stufe: s.rawValue)
                    } label: {
                        StufenZelle(sterne: kind.sterne[Kind.schluessel(z, s)] ?? 0, auswertung: a)
                            .frame(width: Self.zellenBreite)
                    }
                    .buttonStyle(.borderless)
                    .disabled(a == nil)
                } else {
                    Color.clear.frame(width: Self.zellenBreite, height: 1)
                }
            }
        }
    }
}

/// Sterne, Anläufe und Fehlversuche einer Stufe.
private struct StufenZelle: View {
    let sterne: Int
    let auswertung: Auswertung?

    var body: some View {
        VStack(spacing: 2) {
            if sterne == 0 && auswertung == nil {
                Text("–").foregroundStyle(.tertiary)
            } else {
                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < sterne ? "star.fill" : "star")
                            .foregroundStyle(i < sterne ? Farben.stern : Color.gray.opacity(0.4))
                    }
                }
                .font(.system(size: 10, weight: .bold))
                if let a = auswertung, a.anlaeufe > 0 {
                    Text("\(a.anlaeufe) Anl. · \(a.fehler) F")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else if auswertung != nil {
                    Text("freiwillig").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 34)
    }
}

// MARK: - Liste der Bearbeitungen

struct BearbeitungsListe: View {
    let kindID: UUID
    let auswahl: KindProtokollAnsicht.Auswahl
    @Environment(Klasse.self) private var klasse

    var body: some View {
        let alle = klasse.protokoll.bearbeitungen(von: kindID).filter { b in
            (auswahl.stufe == nil || b.stufe == auswahl.stufe)
                && (auswahl.seiten.isEmpty || auswahl.seiten.contains(b.zeichen))
        }
        List {
            if alle.isEmpty {
                Text("Noch nichts bearbeitet.").foregroundStyle(.secondary)
            }
            ForEach(alle.reversed()) { b in
                NavigationLink { SeitenAnsicht(kindID: kindID, bearbeitung: b) } label: {
                    BearbeitungsZeile(b: b)
                }
            }
        }
        .navigationTitle(auswahl.titel)
    }
}

struct BearbeitungsZeile: View {
    let b: Bearbeitung

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(b.titel).font(.headline).lineLimit(1)
                Spacer()
                Text(b.beginn.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                marke("Stufe \(b.stufe)", Farben.knopf)
                if b.geschafft {
                    marke("geschafft", Farben.start)
                } else {
                    marke("nicht fertig", Color.gray)
                }
                marke("\(b.fehler) Fehler", b.fehler == 0 ? Farben.start : Farben.markierung)
                if b.sterne > 0 {
                    HStack(spacing: 1) {
                        ForEach(0..<b.sterne, id: \.self) { _ in Image(systemName: "star.fill") }
                    }
                    .font(.caption2).foregroundStyle(Farben.stern)
                }
                if let h = b.hilfen, h > 0 { marke("Hilfe \(h)×", Farben.warnung) }
                if b.freiwillig { marke("freiwillig", Farben.ziel) }
                if b.kuer > 0 { marke("+\(b.kuer) freiwillig", Farben.ziel) }
                Spacer()
                Text(Self.dauer(b.dauer)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func marke(_ text: String, _ farbe: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(farbe)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(farbe.opacity(0.12)))
    }

    static func dauer(_ t: TimeInterval) -> String {
        t < 60 ? "\(Int(t)) s" : "\(Int((t / 60).rounded())) min"
    }
}

// MARK: - Eine Seite nachsehen

/// Die Seite, wie das Kind sie bearbeitet hat: Hintergrund der Stufe
/// (Lineatur, Spur bzw. Muster) und darauf die gespeicherten Spuren.
/// Verworfene Versuche rot gestrichelt; mit dem Regler lässt sich die
/// Seite Strich für Strich nachspielen.
struct SeitenAnsicht: View {
    let kindID: UUID
    let bearbeitung: Bearbeitung
    @Environment(Klasse.self) private var klasse
    @AppStorage(Schluessel.stift) private var stift = Stift.blau

    @State private var spuren: Blattspuren?
    @State private var zeigeVerworfen = true
    @State private var bis: Double = 0
    @State private var spielt = false

    private var anzahl: Int {
        spuren?.reihen.reduce(0) { $0 + $1.linien.count } ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                BearbeitungsZeile(b: bearbeitung)
                if let spuren {
                    Seitenbild(spuren: spuren, stufe: bearbeitung.stufe, bis: Int(bis),
                               zeigeVerworfen: zeigeVerworfen, stift: stift)
                        .background(Farben.blatt)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    regler
                    Toggle("Nicht angenommene Versuche zeigen (rot gestrichelt)", isOn: $zeigeVerworfen)
                    Text("Orange: dort lief der Strich aus der Form. Ein roter Kreis: dort wurde falsch angesetzt.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    ContentUnavailableView("Keine Spuren gespeichert", systemImage: "scribble")
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(bearbeitung.titel)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            spuren = klasse.protokoll.spuren(bearbeitung, kind: kindID)
            bis = Double(anzahl)
        }
        .task(id: spielt) {
            guard spielt else { return }
            if Int(bis) >= anzahl { bis = 0 }
            while spielt, Int(bis) < anzahl {
                try? await Task.sleep(for: .seconds(0.5))
                if Task.isCancelled { return }
                bis += 1
            }
            spielt = false
        }
    }

    private var regler: some View {
        HStack(spacing: 12) {
            Button {
                spielt.toggle()
            } label: {
                Image(systemName: spielt ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Farben.akzent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(spielt ? "Anhalten" : "Nachspielen"))
            if anzahl > 0 {
                Slider(value: $bis, in: 0...Double(anzahl), step: 1)
            }
            Text("\(Int(bis)) / \(anzahl) Striche")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

/// Zeichnet eine gespeicherte Bearbeitung. Stufe 1–4: das große Blatt mit
/// der Hilfe der Stufe (Spur, Punktlinie, blasse Vorlage, Schreibfeld);
/// Stufe 5: die Heftseite mit ihren Reihen und Mustern.
struct Seitenbild: View {
    let spuren: Blattspuren
    let stufe: Int
    /// Nur die ersten `bis` Striche in der Reihenfolge des Schreibens.
    let bis: Int
    let zeigeVerworfen: Bool
    let stift: Stift

    private static let heftTinte: CGFloat = 0.075

    /// Welche Striche (Reihe, Linie) sichtbar sind.
    private var sichtbar: Set<[Int]> {
        var alle: [(r: Int, l: Int, t: Double)] = []
        for (r, reihe) in spuren.reihen.enumerated() {
            for (l, linie) in reihe.linien.enumerated() { alle.append((r, l, linie.t)) }
        }
        let sortiert = alle.enumerated().sorted { a, b in
            a.element.t == b.element.t ? a.offset < b.offset : a.element.t < b.element.t
        }
        return Set(sortiert.prefix(bis).map { [$0.element.r, $0.element.l] })
    }

    var body: some View {
        if stufe == Stufe.heft.rawValue {
            heft
        } else {
            Canvas { ctx, groesse in blatt(&ctx, groesse) }
                .aspectRatio(1.3, contentMode: .fit)
        }
    }

    // Stufe 1–4
    private func blatt(_ ctx: inout GraphicsContext, _ groesse: CGSize) {
        guard let reihe = spuren.reihen.first, let id = reihe.teile.first,
              let z = Zeichenvorrat.zeichen(id: id) else { return }
        let a = Abbildung(groesse: groesse, zeichen: z)
        Zeichner.blatt(&ctx, groesse: groesse, lineatur: z.lineatur, a)
        switch Stufe(rawValue: stufe) ?? .spur {
        case .spur: Zeichner.spur(&ctx, zeichen: z, a)
        case .punkte: Zeichner.punktlinie(&ctx, zeichen: z, a)
        case .startZiel: Zeichner.spur(&ctx, zeichen: z, a, farbe: Farben.spur.opacity(0.5))
        case .frei, .heft: Zeichner.schreibfeld(&ctx, zeichen: z, a)
        }
        tinte(&ctx, reihe, 0, a, breite: Zeichner.tintenBreite)
    }

    // Stufe 5
    private var heft: some View {
        let muster = spuren.reihen.map { r in Heftseite.Vorgabe.aus(teile: r.teile, art: r.art)?.muster }
        let hoehe = CGFloat(max(spuren.reihen.count - 1, 0)) * Heftseite.zeilenabstand + 1.78
        var breite: CGFloat = 8
        for (i, r) in spuren.reihen.enumerated() {
            if let m = muster[i] { breite = max(breite, Heftseite.musterEnde(m) + 3) }
            for l in r.linien { for p in l.punkte { breite = max(breite, p.p.x + 0.5) } }
        }
        let rand: CGFloat = 0.3
        return Canvas { ctx, groesse in
            let m = groesse.width / (breite + rand)
            for (r, reihe) in spuren.reihen.enumerated() {
                let a = Abbildung(massstab: m, verschiebung: CGPoint(
                    x: rand * m, y: (0.28 + CGFloat(r) * Heftseite.zeilenabstand) * m))
                if let mu = muster[r] {
                    Zeichner.heftreihe(&ctx, breite: groesse.width, muster: mu, a)
                } else {
                    Zeichner.linien(&ctx, breite: groesse.width, lineatur: .buchstaben, a)
                }
                tinte(&ctx, reihe, r, a, breite: Self.heftTinte)
            }
        }
        .aspectRatio((breite + rand) / hoehe, contentMode: .fit)
    }

    private func tinte(_ ctx: inout GraphicsContext, _ reihe: Blattspuren.Reihe, _ r: Int,
                       _ a: Abbildung, breite: CGFloat) {
        let zeigen = sichtbar
        for (l, linie) in reihe.linien.enumerated() where zeigen.contains([r, l]) {
            let punkte = linie.punkte
            if linie.verworfen {
                guard zeigeVerworfen else { continue }
                if punkte.count == 1 {
                    // Falscher Ansatz: roter Kreis.
                    let m = a.ansicht(punkte[0].p), rr = 0.06 * a.massstab
                    ctx.stroke(Path(ellipseIn: CGRect(x: m.x - rr, y: m.y - rr, width: 2 * rr, height: 2 * rr)),
                               with: .color(Farben.markierung), lineWidth: 2)
                } else {
                    ctx.stroke(Zeichner.pfad(punkte.map(\.p), a), with: .color(Farben.markierung.opacity(0.75)),
                               style: StrokeStyle(lineWidth: max(1.5, breite * 0.45 * a.massstab), lineCap: .round,
                                                  lineJoin: .round, dash: [5, 5]))
                }
            } else {
                Zeichner.tinte(&ctx, punkte: punkte, stift: stift, a, breite: breite)
            }
        }
    }
}
