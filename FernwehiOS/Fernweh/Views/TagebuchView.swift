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
    /// Nur ein Tagebuch zeigen (ab 1.0.7). `nil`: alle; "" : ohne Tagebuch.
    @State private var nurTagebuch: String?

    struct SchreibWunsch: Identifiable {
        let id = UUID()
        let tag: Date?
    }

    private var tagebuchNamen: [String] { Set(eintraege.compactMap(\.tagebuchName)).sorted() }

    static func alleEintraege() -> NSFetchRequest<Eintrag> {
        let anfrage = NSFetchRequest<Eintrag>(entityName: "Eintrag")
        anfrage.sortDescriptors = [NSSortDescriptor(key: "datum", ascending: false)]
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

    var body: some View {
        NavigationStack(path: $pfad) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    kopf
                    heuteKarte
                    if kapitel.isEmpty {
                        leer
                    }
                    ForEach(kapitel) { k in
                        KapitelBlock(kapitel: k)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
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
                if !tagebuchNamen.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button { nurTagebuch = nil } label: { Label("Alle Einträge", systemImage: nurTagebuch == nil ? "checkmark" : "books.vertical") }
                            ForEach(tagebuchNamen, id: \.self) { n in
                                Button { nurTagebuch = n } label: { Label(n, systemImage: nurTagebuch == n ? "checkmark" : "book.closed") }
                            }
                            Button { nurTagebuch = "" } label: { Label("Ohne Tagebuch", systemImage: nurTagebuch == "" ? "checkmark" : "minus.circle") }
                        } label: {
                            Label(nurTagebuch.map { $0.isEmpty ? "Ohne Tagebuch" : $0 } ?? "Alle", systemImage: "line.3.horizontal.decrease.circle")
                        }
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
                EintragEditor(vorgabe: nil, eintrag: nil, tag: w.tag)
            }
            .sheet(isPresented: $einstellungen) { EinstellungenView() }
            .refreshable { aufzeichner.uebertragen() }
            .task(id: stand + "|" + (nurTagebuch ?? "*")) {
                let gezeigt = Array(eintraege).filter { e in
                    guard let nur = nurTagebuch else { return true }
                    return (e.tagebuchName ?? "") == nur
                }
                kapitel = Self.gliedern(gezeigt, reisen: Array(reisen))
            }
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
        let tage = jeTag.values.sorted { $0.0 > $1.0 }
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
            Text("Mein Tagebuch")
                .font(Stil.titel(34))
        }
        .padding(.top, 4)
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

/// Ein Kapitel: das Band der Reise (oder nichts), darunter seine Tage.
private struct KapitelBlock: View {
    let kapitel: TagebuchView.Kapitel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let reise = kapitel.reise {
                NavigationLink(value: reise.objectID) {
                    KapitelBand(reise: reise)
                }
                .buttonStyle(.plain)
            }
            ForEach(kapitel.tage) { gruppe in
                VStack(alignment: .leading, spacing: 10) {
                    Text(Tag.wochentagLang.string(from: gruppe.tag) + jahrZusatz(gruppe.tag))
                        .font(Stil.titel(19))
                    ForEach(gruppe.eintraege) { e in
                        let palette = e.reise?.palette ?? .meer
                        NavigationLink {
                            EintragView(eintrag: e, palette: palette)
                        } label: {
                            EintragKarte(eintrag: e, palette: palette)
                                .overlay(alignment: .topTrailing) {
                                    if e.reise == nil && kapitel.reise != nil {
                                        // Ein privater Eintrag mitten in einer
                                        // Reise: Er steht im Kapitel, gehört aber
                                        // nicht zur geteilten Reise.
                                        Label("Nur für dich", systemImage: "lock.fill")
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.regularMaterial, in: Capsule())
                                            .padding(10)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(kapitel.reise == nil ? 0 : 12)
        .background {
            if let reise = kapitel.reise {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(reise.palette.hell.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(reise.palette.haupt.opacity(0.25), lineWidth: 1))
            }
        }
    }

    /// Das Jahr nur dann, wenn es nicht das laufende ist.
    private func jahrZusatz(_ d: Date) -> String {
        let jahr = Tag.kalender.component(.year, from: d)
        return jahr == Tag.kalender.component(.year, from: Date()) ? "" : " \(jahr)"
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
