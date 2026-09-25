import SwiftUI
import CoreData

// DAS LEBENSTAGEBUCH (ab 1.0.5, Ansage des Nutzers 09/2026: „die App
// insgesamt für ein Tagebuch nutzen … Bei besonderen Ereignissen wie einer
// Urlaubsreise möchte ich diese natürlich separat aufrufen können. Sie sollen
// aber ja insgesamt in meinem Lebenslauf auch zu sehen sein.“)
//
// Der Stamm ist die Zeit, nicht die Reise: Hier stehen ALLE Einträge, aus
// beiden Speichern — die eigenen ohne Reise, die der eigenen Reisen und die
// der Reisen, zu denen jemand eingeladen hat. Eine Reise ist ein KAPITEL:
// Liegen aufeinanderfolgende Tage in ihrem Zeitraum, stehen sie unter ihrem
// Band, und ein Tipp darauf öffnet die Reise für sich.
//
// Zwei Reisen zur selben Zeit sind erlaubt; ein Tag gehört dann zu der, in
// der die meisten seiner Einträge stehen (sonst zur zuletzt begonnenen). Eine
// „Pause“ ist schlicht eine Lücke im Zeitraum.

struct TagebuchView: View {
    @FetchRequest(fetchRequest: TagebuchView.alleEintraege(), animation: .spring(duration: 0.4))
    private var eintraege: FetchedResults<Eintrag>
    @FetchRequest(fetchRequest: Reise.alle()) private var reisen: FetchedResults<Reise>

    @EnvironmentObject private var aufzeichner: Aufzeichner
    @State private var schreiben: SchreibWunsch?
    @State private var einstellungen = false
    @State private var pfad = NavigationPath()
    /// Welche Tagebücher AUSGEBLENDET sind (ab 1.0.9, vorher genau eines
    /// gezeigt). Gemerkt wird das Ausgeblendete und nicht das Gezeigte: Ein
    /// Tagebuch, das später dazukommt, ist sonst unsichtbar, ohne dass es
    /// jemand so gewollt hat. "" steht für „ohne Tagebuch“. Je Gerät.
    @AppStorage("ausgeblendeteTagebuecher") private var ausgeblendetText = ""
    @State private var tagebuecherZeigen = false
    @State private var sucheZeigen = false
    @ObservedObject private var buecherei = Buecherei.shared
    /// Ans Ende springen, sobald die Gliederung steht (ab 1.0.8): beim ersten
    /// Öffnen, nach einem Wechsel des Tagebuchs und wenn ein Eintrag dazukommt.
    @State private var springen = true

    struct SchreibWunsch: Identifiable {
        let id = UUID()
        let tag: Date?
    }

    private static let ende = "ende"

    /// Aufsteigend: das Älteste oben, das Neueste unten — wie in einem Heft
    /// (ab 1.0.8, Ansage des Nutzers 09/2026: „Ich möchte, dass neue Einträge
    /// unten angefügt werden.“). Damit trotzdem das Aktuelle zuerst zu sehen
    /// ist, springt die Ansicht beim Öffnen ans Ende.
    static func alleEintraege() -> NSFetchRequest<Eintrag> {
        let anfrage = NSFetchRequest<Eintrag>(entityName: "Eintrag")
        anfrage.sortDescriptors = [NSSortDescriptor(key: "datum", ascending: true)]
        return anfrage
    }

    /// Ein Abschnitt der Zeitleiste: Tage in Folge, die zu derselben Reise
    /// gehören — oder zu keiner.
    struct Kapitel: Identifiable {
        let reise: Reise?
        var tage: [TagGruppe]
        var id: String {
            "\(reise?.objectID.uriRepresentation().absoluteString ?? "-")|\(tage.first?.id ?? "")"
        }
    }

    struct TagGruppe: Identifiable {
        let tag: Date
        let eintraege: [Eintrag]
        var id: String { Tag.schluessel(tag) }
    }

    /// Gebaut in `.task` bzw. auf Änderung, nicht als berechnete Eigenschaft
    /// im Körper: Der Lauf geht über alle Einträge und alle Reisen (die Lehre
    /// aus dem Reisebuch — eine berechnete Eigenschaft sieht billig aus).
    @State private var kapitel: [Kapitel] = []
    /// Dieselbe Gliederung als flache Zeilenfolge — das, was der Stapel zeigt.
    @State private var zeilen: [Zeile] = []

    /// Eine Zeile der Zeitleiste. Die Hülle des Reisekapitels wird je Zeile
    /// als STÜCK gezeichnet (`oben`/`unten` sagen, ob hier eine Ecke ist).
    struct Zeile: Identifiable {
        enum Art {
            case band(Reise)
            case tag(Date, String)
            case eintrag(Eintrag, nurFuerDich: Bool)
        }
        let id: String
        let art: Art
        let reise: Reise?
        /// Abstand zur vorigen Zeile, AUSSERHALB der Hülle.
        let davor: CGFloat
        /// Abstand zur vorigen Zeile, INNERHALB der Hülle.
        let innen: CGFloat
        let oben: Bool
        var unten = false
    }

    static func zeilen(_ kapitel: [Kapitel]) -> [Zeile] {
        var ergebnis: [Zeile] = []
        for k in kapitel {
            let kopf = k.id
            let mitHuelle = k.reise != nil
            let anfang = ergebnis.count
            // 18 Punkte vor jedem Kapitel — auch vor dem ersten, zum Kopf hin.
            let aussen: CGFloat = 18
            if let reise = k.reise {
                ergebnis.append(Zeile(id: kopf + "|band", art: .band(reise), reise: reise,
                                      davor: aussen, innen: 12, oben: true))
            }
            for (t, gruppe) in k.tage.enumerated() {
                let erste = ergebnis.count == anfang
                ergebnis.append(Zeile(id: kopf + "|" + gruppe.id, art: .tag(gruppe.tag, gruppe.id), reise: k.reise,
                                      davor: erste ? aussen : 0,
                                      innen: erste ? (mitHuelle ? 12 : 0) : (t == 0 ? 14 : 18),
                                      oben: erste))
                for e in gruppe.eintraege {
                    ergebnis.append(Zeile(id: e.objectID.uriRepresentation().absoluteString,
                                          art: .eintrag(e, nurFuerDich: e.reise == nil && k.reise != nil),
                                          reise: k.reise, davor: 0, innen: 10, oben: false))
                }
            }
            if ergebnis.count > anfang { ergebnis[ergebnis.count - 1].unten = true }
        }
        return ergebnis
    }

    var body: some View {
        NavigationStack(path: $pfad) {
            ScrollViewReader { leser in
            ScrollView {
                // Jede Zeile ein eigenes Kind des faulen Stapels (ab 1.0.12,
                // gemeldet 09/2026: „Einträge werden zuweilen nicht angezeigt;
                // nach dem Drehen sind sie da“). Bis 1.0.11 war ein ganzes
                // KAPITEL ein Kind — ohne Reise also alle Tage zwischen zwei
                // Reisen, nach einem Day-One-Import Hunderte Einträge in
                // einem Block. Einen so großen Block schätzt `LazyVStack`
                // falsch, und nach dem Sprung ans Ende blieb er stellenweise
                // ungezeichnet, bis ein neues Layout kam (das Drehen). Jetzt
                // sind es Band, Tageskopf und Eintrag einzeln.
                LazyVStack(alignment: .leading, spacing: 0) {
                    kopf
                    if kapitel.isEmpty {
                        Group {
                            if gefiltert && !eintraege.isEmpty { nichtsGezeigt } else { leer }
                        }
                        .padding(.top, 18)
                    }
                    ForEach(zeilen) { z in
                        KapitelZeile(zeile: z)
                    }
                    // Unten, weil hier das Neueste steht und der nächste
                    // Eintrag hinzukommt.
                    heuteKarte.padding(.top, 18)
                    Color.clear.frame(height: 1).id(Self.ende)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
            .onChange(of: eintraege.count) { alt, neu in
                if neu > alt { springen = true }
            }
            .onChange(of: ausgeblendetText) { _, _ in springen = true }
            .task(id: stand + "|" + ausgeblendetText) {
                let weg = ausgeblendet
                let gezeigt = Array(eintraege).filter { !weg.contains($0.tagebuchName ?? "") }
                kapitel = Self.gliedern(gezeigt, reisen: Array(reisen))
                zeilen = Self.zeilen(kapitel)
                guard springen else { return }
                springen = false
                // Einen Durchgang warten: Die neuen Kapitel müssen erst im
                // Stapel stehen, sonst gibt es das Ziel noch nicht.
                try? await Task.sleep(for: .milliseconds(60))
                leser.scrollTo(Self.ende, anchor: .bottom)
                // Und ein zweites Mal, wenn die Zeilen am Ende wirklich
                // gemessen sind: Der erste Sprung rechnet mit GESCHÄTZTEN
                // Höhen der Zeilen darüber und landet sonst knapp daneben.
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                leser.scrollTo(Self.ende, anchor: .bottom)
            }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationDestination(for: NSManagedObjectID.self) { kennung in
                if let reise = try? Persistenz.shared.kontext.existingObject(with: kennung) as? Reise {
                    ReiseView(reise: reise)
                } else {
                    ContentUnavailableView("Reise nicht gefunden", systemImage: "suitcase")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { einstellungen = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Einstellungen")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // Suche über alle Tagebücher und Reisen (ab 1.0.11).
                    Button { sucheZeigen = true } label: {
                        Label("Suchen", systemImage: "magnifyingglass")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { tagebuecherZeigen = true } label: {
                        Label("Tagebücher", systemImage: "books.vertical.fill")
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button { schreiben = SchreibWunsch(tag: nil) } label: {
                    Label("Eintrag", systemImage: "square.and.pencil")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 15)
                        .background(Palette.meer.verlauf, in: Capsule())
                        .shadow(color: Palette.meer.haupt.opacity(0.45), radius: 14, y: 8)
                }
                .padding(22)
            }
            .sheet(item: $schreiben) { w in
                EintragEditor(vorgabe: nil, eintrag: nil, tag: w.tag,
                              tagebuchVorgabe: einzigesTagebuch)
            }
            .sheet(isPresented: $einstellungen) { EinstellungenView() }
            .sheet(isPresented: $sucheZeigen) { SuchView() }
            .sheet(isPresented: $tagebuecherZeigen) { TagebuecherView(ausgeblendet: ausgeblendetBindung) }
            .refreshable { aufzeichner.uebertragen() }
        }
    }

    /// Ändert sich, wenn sich an Einträgen oder Reisen etwas ändert, das die
    /// Gliederung betrifft.
    private var stand: String {
        let e = eintraege.map { "\($0.objectID.uriRepresentation().lastPathComponent)\($0.datum?.timeIntervalSince1970 ?? 0)\($0.zeitzone ?? "")\($0.tagebuch ?? "")\($0.reise?.objectID.uriRepresentation().lastPathComponent ?? "")" }
        let r = reisen.map { "\($0.beginn?.timeIntervalSince1970 ?? 0)\($0.ende?.timeIntervalSince1970 ?? 0)" }
        return e.joined() + "|" + r.joined()
    }

    static func gliedern(_ eintraege: [Eintrag], reisen: [Reise]) -> [Kapitel] {
        var jeTag: [String: (Date, [Eintrag])] = [:]
        // Der Tag eines Eintrags ist der in SEINER Zeitzone (ab 1.0.6).
        for e in eintraege {
            guard let s = e.tagSchluessel, let d = e.tagDatum else { continue }
            jeTag[s, default: (d, [])].1.append(e)
        }
        let tage = jeTag.values.sorted { $0.0 < $1.0 }
        var ergebnis: [Kapitel] = []
        for (tag, liste) in tage {
            let chronologisch = liste.sorted { ($0.datum ?? .distantPast) < ($1.datum ?? .distantPast) }
            let reise = kapitelReise(tag: tag, eintraege: liste, reisen: reisen)
            if var letztes = ergebnis.last, letztes.reise == reise {
                letztes.tage.append(TagGruppe(tag: tag, eintraege: chronologisch))
                ergebnis[ergebnis.count - 1] = letztes
            } else {
                ergebnis.append(Kapitel(reise: reise, tage: [TagGruppe(tag: tag, eintraege: chronologisch)]))
            }
        }
        return ergebnis
    }

    private static func kapitelReise(tag: Date, eintraege: [Eintrag], reisen: [Reise]) -> Reise? {
        var zaehler: [NSManagedObjectID: (Reise, Int)] = [:]
        for e in eintraege { if let r = e.reise { zaehler[r.objectID, default: (r, 0)].1 += 1 } }
        if let meiste = zaehler.values.max(by: { $0.1 < $1.1 }) { return meiste.0 }
        // Nur private Einträge an diesem Tag: Liegt er in einer Reise, steht er
        // trotzdem in ihrem Kapitel — er gehört zu dieser Zeit, auch wenn ihn
        // niemand sonst liest.
        return reisen
            .filter { $0.anfang <= tag && Tag.anfang($0.schluss) >= tag && !$0.liegtInZukunft }
            .max { $0.anfang < $1.anfang }
    }

    // MARK: - Teile

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Tag.wochentagLang.string(from: Date()))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(kopftitel)
                .font(Stil.titel(34))
                .foregroundStyle(kopffarbe ?? .primary)
            if let hinweis = filterhinweis {
                // Gefiltert heißt: Nicht alles steht da. Das soll man sehen
                // und mit einem Tipp aufheben können.
                Button { ausgeblendetText = "" } label: {
                    Label(hinweis + " — alle zeigen", systemImage: "xmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((kopffarbe ?? .secondary).opacity(0.14), in: Capsule())
                        .foregroundStyle(kopffarbe ?? .secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            if !buecherei.offen.isEmpty {
                // Geöffnete Tagebücher mit Passwort (ab 1.0.10): Sie gehen beim
                // Verlassen der App von selbst zu — und hier sofort.
                Button { buecherei.alleSperren() } label: {
                    Label(buecherei.offen.count == 1
                          ? "\(buecherei.offen.first ?? "") ist offen — sperren"
                          : "\(buecherei.offen.count) Tagebücher offen — sperren",
                          systemImage: "lock.open.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.14), in: Capsule())
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.top, 4)
    }

    private var ausgeblendet: Set<String> { Tagebuchfilter.lesen(ausgeblendetText) }

    private var ausgeblendetBindung: Binding<Set<String>> {
        Binding(get: { Tagebuchfilter.lesen(ausgeblendetText) },
                set: { ausgeblendetText = Tagebuchfilter.schreiben($0) })
    }

    /// Alle Namen, die es gibt ("" = ohne Tagebuch), und davon die gezeigten.
    /// Eine Aufzählung über die Einträge — gebraucht nur im Kopf und beim
    /// Öffnen des Editors, also nicht bei jedem Bildpunkt.
    private var vorhandene: Set<String> { Set(eintraege.map { $0.tagebuchName ?? "" }) }
    private var gezeigte: Set<String> { vorhandene.subtracting(ausgeblendet) }

    /// Steht genau EIN benanntes Tagebuch da, landet ein neuer Eintrag darin.
    private var einzigesTagebuch: String? {
        let g = gezeigte
        guard g.count == 1, let n = g.first, !n.isEmpty else { return nil }
        return n
    }

    private var gefiltert: Bool { !ausgeblendet.isDisjoint(with: vorhandene) }

    private var filterhinweis: String? {
        guard gefiltert else { return nil }
        let g = gezeigte.count, alle = vorhandene.count
        if g == 0 { return "Alle Tagebücher ausgeblendet" }
        return "\(g) von \(alle) Tagebüchern"
    }

    private var kopftitel: String {
        guard gefiltert else { return "Mein Tagebuch" }
        let g = gezeigte
        if g.count == 1, let n = g.first { return n.isEmpty ? "Ohne Tagebuch" : n }
        return "Mein Tagebuch"
    }

    private var kopffarbe: Color? {
        guard gefiltert, gezeigte.count == 1, let n = gezeigte.first, !n.isEmpty else { return nil }
        return buecherei.farbe(n)
    }

    /// Heute noch nichts geschrieben? Dann steht der Weg dahin ganz oben.
    @ViewBuilder
    private var heuteKarte: some View {
        let heute = Tag.schluessel(Date())
        if !eintraege.contains(where: { $0.tagSchluessel == heute }) {
            Button { schreiben = SchreibWunsch(tag: nil) } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Was hast du heute erlebt?")
                    Spacer()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.meer.haupt)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Palette.meer.haupt.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                )
            }
            .buttonStyle(.plain)
        }
    }

    /// Es gibt Einträge, aber keiner gehört zu einem gezeigten Tagebuch. Ohne
    /// diesen Satz sähe das aus wie ein leeres Tagebuch.
    private var nichtsGezeigt: some View {
        VStack(spacing: 10) {
            Image(systemName: "eye.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("In den gezeigten Tagebüchern steht nichts")
                .font(Stil.titel(20))
                .multilineTextAlignment(.center)
            Button("Alle Tagebücher zeigen") { ausgeblendetText = "" }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private var leer: some View {
        VStack(spacing: 10) {
            Image(systemName: "book.pages.fill")
                .font(.system(size: 48))
                .foregroundStyle(Palette.meer.verlauf)
            Text("Dein Tagebuch ist noch leer")
                .font(Stil.titel(22))
            Text("Schreib auf, was dich bewegt — an gewöhnlichen Tagen genauso wie unterwegs. Reisen stehen hier als Kapitel und lassen sich unter „Reisen“ einzeln aufschlagen.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}

/// Eine Zeile der Zeitleiste samt ihrem Stück der Kapitelhülle.
private struct KapitelZeile: View {
    let zeile: TagebuchView.Zeile

    var body: some View {
        inhalt
            .padding(.top, zeile.innen)
            .padding(.bottom, zeile.unten && zeile.reise != nil ? 12 : 0)
            .padding(.horizontal, zeile.reise == nil ? 0 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if let reise = zeile.reise {
                    KapitelHuelle(oben: zeile.oben, unten: zeile.unten, palette: reise.palette)
                }
            }
            .padding(.top, zeile.davor)
    }

    @ViewBuilder
    private var inhalt: some View {
        switch zeile.art {
        case .band(let reise):
            NavigationLink(value: reise.objectID) {
                KapitelBand(reise: reise)
            }
            .buttonStyle(.plain)
        case .tag(let tag, let schluessel):
            VStack(alignment: .leading, spacing: 10) {
                Text(Tag.wochentagLang.string(from: tag) + jahrZusatz(tag))
                    .font(Stil.titel(19))
                // Die Spur des ganzen Tages (ab 1.0.14) — für Tage im
                // Tagebuch genauso wie für Reisetage.
                Tagesspurleiste(tag: schluessel, palette: zeile.reise?.palette ?? .meer)
            }
        case .eintrag(let e, let nurFuerDich):
            // Ein privater Eintrag mitten in einer Reise: Er steht im
            // Kapitel, gehört aber nicht zur geteilten Reise.
            EintragVerweis(eintrag: e, palette: e.reise?.palette ?? .meer, nurFuerDich: nurFuerDich)
        }
    }

    /// Das Jahr nur dann, wenn es nicht das laufende ist.
    private func jahrZusatz(_ d: Date) -> String {
        let jahr = Tag.kalender.component(.year, from: d)
        return jahr == Tag.kalender.component(.year, from: Date()) ? "" : " \(jahr)"
    }
}

/// Ein Stück der Hülle um ein Reisekapitel: Fläche und Rand, Ecken nur dort,
/// wo das Kapitel anfängt oder aufhört. Der Rand wird OFFEN gezeichnet —
/// zwischen zwei Stücken läge sonst ein Strich quer durch das Kapitel.
private struct KapitelHuelle: View {
    let oben: Bool
    let unten: Bool
    let palette: Palette

    var body: some View {
        let r: CGFloat = 24
        UnevenRoundedRectangle(topLeadingRadius: oben ? r : 0, bottomLeadingRadius: unten ? r : 0,
                               bottomTrailingRadius: unten ? r : 0, topTrailingRadius: oben ? r : 0,
                               style: .continuous)
            .fill(palette.hell.opacity(0.10))
            .overlay(HuellenRand(oben: oben, unten: unten, radius: r)
                .stroke(palette.haupt.opacity(0.25), lineWidth: 1))
    }
}

private struct HuellenRand: Shape {
    let oben: Bool
    let unten: Bool
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: 0.5, dy: 0.5)
        let ro = oben ? min(radius, r.height / 2) : 0
        let ru = unten ? min(radius, r.height / 2) : 0
        var p = Path()
        // Linke Seite von unten nach oben, dann (wenn oben) die Oberkante,
        // dann die rechte Seite hinunter und (wenn unten) die Unterkante.
        p.move(to: CGPoint(x: r.minX + ru, y: r.maxY))
        if unten {
            p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - ru), control: CGPoint(x: r.minX, y: r.maxY))
        } else {
            p.move(to: CGPoint(x: r.minX, y: r.maxY))
        }
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + ro))
        if oben {
            p.addQuadCurve(to: CGPoint(x: r.minX + ro, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX - ro, y: r.minY))
            p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + ro), control: CGPoint(x: r.maxX, y: r.minY))
        } else {
            p.move(to: CGPoint(x: r.maxX, y: r.minY))
        }
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - ru))
        if unten {
            p.addQuadCurve(to: CGPoint(x: r.maxX - ru, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX + ru, y: r.maxY))
        }
        return p
    }
}

private struct KapitelBand: View {
    @ObservedObject var reise: Reise

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(reise.palette.verlauf)
                Reisesymbol.text(reise.emoji, ersatz: "✈️")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(reise.anzeigeTitel).font(.headline)
                Text(Tag.zeitraum(reise.anfang, reise.ende))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Kapitel öffnen")
                .font(.caption.weight(.bold))
                .foregroundStyle(reise.palette.haupt)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(reise.palette.haupt)
        }
        .contentShape(Rectangle())
    }
}
