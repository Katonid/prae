import SwiftUI
import Photos
import CoreLocation

/// Einen Tagebucheintrag schreiben.
///
/// Drei Dinge liegen schon bereit, wenn das Blatt aufgeht:
/// * **Der Titel** — der Name des Ortes, an dem du gerade bist (bei einem
///   vergangenen Tag der erste wichtige Ort dieses Tages). Er ist ein
///   Vorschlag und als solcher markiert; wer tippt, ersetzt ihn.
/// * **Die Orte des Tages** — aus der Reisespur: wo du länger warst. Ein
///   Tipp übernimmt einen Ort in den Eintrag (und, solange der Titel noch
///   der Vorschlag ist, auch als Titel).
/// * **Die Fotos des Tages** — alle Aufnahmen dieses Kalendertages aus der
///   Mediathek, zum Antippen.
struct EintragEditor: View {
    /// Die Reise, aus der heraus geschrieben wird — `nil` heißt: aus dem
    /// Lebenstagebuch. Wohin der Eintrag wirklich geht, steht in `zielReise`.
    let vorgabe: Reise?
    let eintrag: Eintrag?
    let tag: Date?
    /// Das Tagebuch, das beim Schreiben schon gewählt ist — wer im Reiter
    /// „Tagebuch“ gerade nur eines ansieht, schreibt meist auch dorthin
    /// (ab 1.0.8).
    var tagebuchVorgabe: String? = nil

    @ObservedObject private var buecherei = Buecherei.shared
    @FetchRequest(fetchRequest: Reise.alle()) private var reisen: FetchedResults<Reise>
    @FetchRequest(fetchRequest: TagebuchView.alleEintraege()) private var alleEintraege: FetchedResults<Eintrag>
    @State private var tagebuch = ""
    @State private var neuesTagebuch = false
    @State private var neuerName = ""
    @State private var zielReise: Reise?

    @Environment(\.dismiss) private var schliessen
    @EnvironmentObject private var fotodienst: Fotodienst
    @EnvironmentObject private var aufzeichner: Aufzeichner

    @State private var datum = Date()
    @State private var titel = ""
    @State private var titelIstVorschlag = false
    @State private var text = ""
    @State private var hier: Tagesort?
    @State private var hierLand = ""
    @State private var ort: Tagesort?
    @State private var tagesorte: [Tagesort] = []
    @State private var gewaehlteOrte: [Tagesort] = []
    @State private var sucheOrte = false
    @State private var assets: [PHAsset] = []
    @State private var auswahl: [String] = []
    @State private var entfernt: Set<NSManagedObjectIDKey> = []
    @State private var speichert = false
    @State private var fortschritt = 0
    @State private var vorbereitet = false
    @State private var wetter: Tageswetter?
    @State private var wetterLaedt = false
    @State private var wetterFehler: String?
    @State private var wetterAn = true
    @State private var zielVonHand = false
    /// Die Zone, in der dieser Eintrag gilt (ab 1.0.6). Neu: die des Geräts
    /// jetzt — unterwegs also die des Urlaubsorts. Bestehend: seine eigene;
    /// dann zeigt und nimmt der Zeitwähler die Uhrzeit von DORT.
    @State private var zone: TimeZone = .current
    @StateObject private var diktat = Diktat()
    @FocusState private var textFokus: Bool

    /// Hashbarer Schlüssel für ein Foto, das entfernt werden soll.
    struct NSManagedObjectIDKey: Hashable { let uri: String }

    private var istNeu: Bool { eintrag == nil }

    /// Ohne Reise trägt das Tagebuch das Blau des Meeres.
    private var palette: Palette { zielReise?.palette ?? .meer }

    /// Reisen, in die ein Eintrag an diesem Tag gehen kann: Der Tag liegt in
    /// ihrem Zeitraum, und ich darf dort schreiben (Betrachter nicht).
    private var moeglicheReisen: [Reise] {
        let tagAnfang = Tag.anfang(datum)
        return reisen.filter { r in
            r.anfang <= tagAnfang && Tag.anfang(r.schluss) >= tagAnfang && Persistenz.shared.darfBearbeiten(r)
        }
    }

    /// Die Vorgabe beim Schreiben aus dem Lebenstagebuch: Läuft an diesem Tag
    /// eine Reise, gehört der Eintrag dorthin — genau so, wie man es erwartet,
    /// wenn man unterwegs abends schreibt. Laufen zwei, die zuletzt begonnene.
    /// Umzustellen ist es immer, und die Zeile sagt, wer mitliest.
    private var automatischeReise: Reise? {
        moeglicheReisen.max { $0.anfang < $1.anfang }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    titelFeld
                    zielBlock
                    tagebuchBlock
                    orteLeiste
                    wetterBlock
                    textFeld
                    if let eintrag, !eintrag.fotoListe.isEmpty { vorhandeneFotos(eintrag) }
                    fotoAuswahl
                    zeitWahl
                }
                .padding(18)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(istNeu ? "Neuer Eintrag" : "Eintrag bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() }.disabled(speichert) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { Task { await sichern() } }
                        .fontWeight(.semibold)
                        .disabled(speichert)
                }
            }
            .overlay { if speichert { Speicherhinweis(fertig: fortschritt, gesamt: auswahl.count) } }
            .task { await vorbereiten() }
            .task(id: wetterSchluessel) { await wetterLaden() }
            // Wach bleiben, solange geschrieben oder diktiert wird (ab 1.0.14,
            // gemeldet 09/2026: Beim Diktieren wollte das Telefon nach der
            // eingestellten Zeit in den Ruhezustand). Diktieren ist Reden,
            // nicht Tippen — für iOS sieht das nach Untätigkeit aus.
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
                Task { await diktat.stoppen() }
            }
            .onChange(of: Tag.schluessel(datum)) { _, _ in
                // Aus dem Lebenstagebuch folgt die Reise dem Tag: Gehört der
                // neue Tag nicht mehr zu ihr, gilt wieder die Vorgabe.
                if istNeu, vorgabe == nil, let r = zielReise, !moeglicheReisen.contains(r) {
                    zielReise = automatischeReise
                } else if istNeu, vorgabe == nil, zielReise == nil, !zielVonHand {
                    zielReise = automatischeReise
                }
                Task { await tagLaden(neu: false) }
            }
            .interactiveDismissDisabled(speichert)
        }
    }

    // MARK: - Wohin der Eintrag gehört

    /// Eine Reise ist ein KAPITEL im Lebenstagebuch (ab 1.0.5). Ein Eintrag
    /// gehört entweder in eine Reise — dann sehen ihn alle, mit denen sie
    /// geteilt ist — oder nur ins eigene Tagebuch. Das steht hier ausdrücklich,
    /// denn es ist die eine Entscheidung, die sich hinterher nicht mehr ändern
    /// lässt: Ein Eintrag wechselt nicht den Speicher.
    @ViewBuilder
    private var zielBlock: some View {
        let geteilt = zielReise.map { Persistenz.shared.freigabe(fuer: $0) != nil } ?? false
        VStack(alignment: .leading, spacing: 6) {
            if istNeu && (vorgabe == nil || moeglicheReisen.count > 1) {
                Menu {
                    Button {
                        zielReise = nil
                        zielVonHand = true
                    } label: { Label("Nur für mich", systemImage: "lock.fill") }
                    ForEach(moeglicheReisen, id: \.objectID) { r in
                        Button {
                            zielReise = r
                            zielVonHand = true
                        } label: { Label(r.anzeigeTitel, systemImage: "suitcase.fill") }
                    }
                } label: {
                    zielZeile(geteilt: geteilt, pfeil: true)
                }
            } else {
                zielZeile(geteilt: geteilt, pfeil: false)
            }
            Text(zielReise == nil
                 ? "Nur für dich — der Eintrag steht in deinem Lebenstagebuch und wird mit niemandem geteilt."
                 : geteilt
                    ? "In der Reise — alle, mit denen sie geteilt ist, lesen ihn. In deinem Lebenstagebuch steht er trotzdem."
                    : "In der Reise und damit auch in deinem Lebenstagebuch.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Tagebuch (ab 1.0.7)

    /// Die Namen, die es schon gibt — aus Day One übernommen oder selbst
    /// vergeben. Eine eigene Liste gibt es nicht: Ein Tagebuch existiert,
    /// solange ein Eintrag seinen Namen trägt.
    private var tagebuchNamen: [String] {
        Set(alleEintraege.compactMap(\.tagebuchName)).sorted()
    }

    @ViewBuilder
    private var tagebuchBlock: some View {
            Menu {
                Button { tagebuch = "" } label: { Label("Kein Tagebuch", systemImage: "minus.circle") }
                ForEach(tagebuchNamen, id: \.self) { n in
                    // Ein Tagebuch mit Passwort trägt sein Schloss auch hier
                    // (ab 1.0.10): Wer hineinschreibt, während es zu ist, sieht
                    // den Eintrag danach nur als gesperrte Karte.
                    Button { tagebuch = n } label: {
                        Label(n, systemImage: buecherei.istGeschuetzt(n) ? "lock.fill" : "book.closed.fill")
                    }
                }
                Button { neuerName = ""; neuesTagebuch = true } label: { Label("Neues Tagebuch …", systemImage: "plus") }
            } label: {
                let farbe = buecherei.farbe(tagebuch) ?? palette.haupt
                HStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                    Text(tagebuch.isEmpty ? "Kein Tagebuch" : tagebuch).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(farbe)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(farbe.opacity(0.14), in: Capsule())
            }
            .alert("Neues Tagebuch", isPresented: $neuesTagebuch) {
                TextField("Name", text: $neuerName)
                Button("Abbrechen", role: .cancel) {}
                Button("Übernehmen") {
                    let n = neuerName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !n.isEmpty { tagebuch = n }
                }
            }
    }

    private func zielZeile(geteilt: Bool, pfeil: Bool) -> some View {
        HStack(spacing: 8) {
            if let r = zielReise {
                Reisesymbol.mitTitel(r.emoji, r.anzeigeTitel).lineLimit(1)
                if geteilt { Image(systemName: "person.2.fill").font(.caption) }
            } else {
                Label("Nur für mich", systemImage: "lock.fill")
            }
            if pfeil { Image(systemName: "chevron.up.chevron.down").font(.caption2) }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(palette.haupt)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(palette.hell.opacity(0.16), in: Capsule())
    }

    // MARK: - Titel und Orte

    private var titelFeld: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(Tag.text(datum, "EEEE, d. MMMM", zone: zone))
                    .font(.caption.weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(palette.haupt)
                if titelIstVorschlag && !titel.isEmpty {
                    Label("Vorschlag aus deinem Standort", systemImage: "sparkles")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            TextField("Wo warst du?", text: $titel, axis: .vertical)
                .font(Stil.titel(28))
                .onChange(of: titel) { alt, neu in
                    // Wer selbst tippt, hat keinen Vorschlag mehr vor sich.
                    if titelIstVorschlag, alt != neu, neu != ort?.name { titelIstVorschlag = false }
                }
            if let ort {
                Label(ort.name, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var orteLeiste: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Orte des Tages").font(.headline)
                if sucheOrte { ProgressView().controlSize(.small) }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let hier {
                        Ortsknopf(ort: hier, symbol: "location.fill", an: ort?.id == hier.id, farbe: palette.haupt) {
                            waehlen(hier)
                        }
                    }
                    ForEach(tagesorte) { t in
                        let an = gewaehlteOrte.contains(t)
                        Ortsknopf(ort: t, symbol: an ? "checkmark.circle.fill" : "mappin", an: an, farbe: palette.haupt) {
                            umschalten(t)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            if !sucheOrte && tagesorte.isEmpty && hier == nil {
                // Die Spur ist NICHT die Bedingung: Der eigene Standort geht
                // auch ohne sie, und die Spur eines anderen Geräts reist über
                // die Reise mit. Fehlt ein Ort, liegt es meist an der Erlaubnis.
                if aufzeichner.erlaubnis == .denied || aufzeichner.erlaubnis == .restricted {
                    Text("Fernweh darf den Standort dieses Geräts nicht sehen — deshalb gibt es hier keinen Ort und kein Wetter. Die Reisespur kann trotzdem aus bleiben.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Standort in den Einstellungen erlauben") { aufzeichner.genauAnfragen() }
                        .font(.caption.weight(.semibold))
                } else {
                    Text("Der Standort ließ sich gerade nicht bestimmen, und die Reisespur hat für diesen Tag noch keine Orte — auch nicht von einem anderen Gerät.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if !gewaehlteOrte.isEmpty {
                Text("\(gewaehlteOrte.count) \(gewaehlteOrte.count == 1 ? "Ort" : "Orte") im Eintrag")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private struct Ortsknopf: View {
        let ort: Tagesort
        let symbol: String
        let an: Bool
        let farbe: Color
        let aktion: () -> Void

        var body: some View {
            Button(action: aktion) {
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(ort.name).lineLimit(1)
                        if let zeit = ort.zeit {
                            Text(Tag.uhrzeit.string(from: zeit)).font(.caption2).opacity(0.75)
                        }
                    }
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(an ? Color.white : Color.primary)
                .background(an ? AnyShapeStyle(farbe.gradient) : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground)),
                            in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func waehlen(_ t: Tagesort) {
        withAnimation(.spring(duration: 0.3)) {
            ort = t
            if titel.isEmpty || titelIstVorschlag {
                titel = t.name
                titelIstVorschlag = true
            }
        }
    }

    private func umschalten(_ t: Tagesort) {
        withAnimation(.spring(duration: 0.3)) {
            if let i = gewaehlteOrte.firstIndex(of: t) {
                gewaehlteOrte.remove(at: i)
            } else {
                gewaehlteOrte.append(t)
                gewaehlteOrte.sort { ($0.zeit ?? .distantPast) < ($1.zeit ?? .distantPast) }
                if ort == nil || titelIstVorschlag || titel.isEmpty { waehlen(t) }
            }
        }
    }

    // MARK: - Text

    private var textFeld: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Was ist heute passiert? Was hast du gegessen, wen getroffen, worüber gelacht?")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $text)
                .focused($textFokus)
                .frame(minHeight: 160)
                .scrollContentBackground(.hidden)
            }
            .font(.body)
            .padding(10)
            .padding(.bottom, 44)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .bottomTrailing) { diktatKnopf.padding(10) }

            if diktat.laeuft || !diktat.zwischentext.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Pulspunkt(farbe: .red)
                    Text(diktat.zwischentext.isEmpty ? "Ich höre zu …" : diktat.zwischentext)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .italic()
                }
                .transition(.opacity)
            }
            if let fehler = diktat.fehler {
                Text(fehler).font(.caption).foregroundStyle(.red)
            } else if diktat.laeuft {
                Text(diktat.motor + " · Orte des Tages sind als Hinweise hinterlegt")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .animation(.easeOut(duration: 0.2), value: diktat.laeuft)
        .onAppear {
            diktat.anhaengen = { neu in
                let trenner = text.isEmpty || text.hasSuffix(" ") || text.hasSuffix("\n") ? "" : " "
                text += trenner + neu
            }
        }
    }

    private var diktatKnopf: some View {
        Button {
            textFokus = false
            Task { await diktat.umschalten(hinweise: diktatHinweise) }
        } label: {
            Group {
                if diktat.bereitet {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: diktat.laeuft ? "stop.fill" : "mic.fill")
                        .font(.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(diktat.laeuft ? AnyShapeStyle(Color.red.gradient) : AnyShapeStyle(palette.verlauf), in: Circle())
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(diktat.laeuft ? "Diktat beenden" : "Diktieren")
    }

    /// Wörter, die die Erkennung erwarten soll: die Orte des Tages und der
    /// Name der Reise.
    private var diktatHinweise: [String] {
        var liste = tagesorte.map(\.name) + gewaehlteOrte.map(\.name)
        if let hier { liste.append(hier.name) }
        if let ort { liste.append(ort.name) }
        if let zielReise { liste.append(zielReise.anzeigeTitel) }
        // „Alfama · Lissabon" sind zwei Hinweise.
        return liste.flatMap { $0.components(separatedBy: " · ") }
    }

    // MARK: - Wetter

    private var wetterOrt: CLLocationCoordinate2D? {
        ort?.koordinate ?? tagesorte.first?.koordinate ?? eintrag?.koordinate
    }

    private var wetterSchluessel: String {
        guard let k = wetterOrt else { return "kein Ort" }
        return "\(Tag.schluessel(datum))|\(String(format: "%.2f,%.2f", k.latitude, k.longitude))"
    }

    @ViewBuilder
    private var wetterBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Wetter").font(.headline)
                if wetterLaedt { ProgressView().controlSize(.small) }
                Spacer()
                if wetter != nil {
                    Toggle("Im Eintrag", isOn: $wetterAn)
                        .labelsHidden()
                        .tint(palette.haupt)
                }
            }
            if let wetter {
                WetterLeiste(wetter: wetter)
                    .opacity(wetterAn ? 1 : 0.35)
            } else if let wetterFehler {
                Text(wetterFehler).font(.caption).foregroundStyle(.secondary)
            } else if wetterOrt == nil && !wetterLaedt {
                Text("Sobald der Eintrag einen Ort hat, steht hier das Wetter dieses Tages.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func wetterLaden() async {
        guard let k = wetterOrt else { return }
        // Ein schon gespeichertes Wetter desselben Tages nicht neu holen —
        // es sei denn, es war eine Vorhersage und der Tag ist vorbei.
        if let alt = eintrag?.tageswetter, Tag.schluessel(eintrag?.datum ?? .distantPast) == Tag.schluessel(datum),
           !(alt.vorhersage && Tag.ende(datum).addingTimeInterval(5 * 3600) < Date()) {
            if wetter == nil { wetter = alt }
            return
        }
        wetterLaedt = true
        defer { wetterLaedt = false }
        do {
            let neu = try await Wetterdienst.wetter(am: datum, bei: k)
            withAnimation { wetter = neu; wetterFehler = nil }
        } catch is CancellationError {
        } catch {
            if (error as? URLError)?.code == .cancelled { return }
            wetterFehler = error.localizedDescription
        }
    }

    // MARK: - Fotos

    private func vorhandeneFotos(_ eintrag: Eintrag) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Im Eintrag").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(eintrag.fotoListe) { foto in
                        let schluessel = NSManagedObjectIDKey(uri: foto.objectID.uriRepresentation().absoluteString)
                        let weg = entfernt.contains(schluessel)
                        FotoBild(foto: foto, kante: 240)
                            .frame(width: 92, height: 92)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .opacity(weg ? 0.3 : 1)
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    if weg { entfernt.remove(schluessel) } else { entfernt.insert(schluessel) }
                                } label: {
                                    Image(systemName: weg ? "arrow.uturn.backward.circle.fill" : "xmark.circle.fill")
                                        .font(.title3)
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, .black.opacity(0.6))
                                }
                                .padding(4)
                            }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var fotoAuswahl: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Fotos vom \(Tag.kurz.string(from: datum))").font(.headline)
                Spacer()
                if !assets.isEmpty {
                    Button(auswahl.count == assets.count ? "Keine" : "Alle") {
                        withAnimation {
                            auswahl = auswahl.count == assets.count ? [] : assets.map(\.localIdentifier)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            if !fotodienst.darfLesen {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Erlaube den Zugriff auf deine Fotos, dann liegen hier die Aufnahmen dieses Tages bereit.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Fotos erlauben") {
                        Task {
                            await fotodienst.erlaubnisAnfragen()
                            await tagLaden(neu: false)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if assets.isEmpty {
                Text("An diesem Tag gibt es keine Fotos in deiner Mediathek.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 4)], spacing: 4) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        let stelle = auswahl.firstIndex(of: asset.localIdentifier)
                        AssetBild(asset: asset)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if stelle != nil {
                                    RoundedRectangle(cornerRadius: 6).strokeBorder(palette.haupt, lineWidth: 3)
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                ZStack {
                                    Circle()
                                        .fill(stelle != nil ? AnyShapeStyle(palette.haupt) : AnyShapeStyle(Color.black.opacity(0.25)))
                                    Circle().strokeBorder(.white, lineWidth: 1.5)
                                    if let stelle { Text("\(stelle + 1)").font(.caption2.weight(.bold)).foregroundStyle(.white) }
                                }
                                .frame(width: 24, height: 24)
                                .padding(5)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                            .onTapGesture { fotoUmschalten(asset) }
                    }
                }
                if fotodienst.status == .limited {
                    Text("Du hast Fernweh nur einen Teil deiner Fotos freigegeben — hier steht nur, was darin liegt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func fotoUmschalten(_ asset: PHAsset) {
        withAnimation(.spring(duration: 0.25)) {
            if let i = auswahl.firstIndex(of: asset.localIdentifier) {
                auswahl.remove(at: i)
            } else {
                auswahl.append(asset.localIdentifier)
            }
        }
    }

    @ViewBuilder
    private var zeitWahl: some View {
        Group {
            if istNeu && vorgabe == nil {
                // Aus dem Lebenstagebuch: jeder Tag bis heute. Die Reise folgt
                // dem Tag, nicht umgekehrt.
                DatePicker("Zeitpunkt", selection: $datum, in: ...Date().addingTimeInterval(3600))
            } else if let r = zielReise {
                DatePicker("Zeitpunkt", selection: $datum,
                           in: r.anfang...max(r.anfang, Tag.ende(r.schluss).addingTimeInterval(-60)))
            } else {
                DatePicker("Zeitpunkt", selection: $datum, in: ...Date().addingTimeInterval(3600))
            }
        }
            .environment(\.timeZone, zone)
            .font(.subheadline)
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Laden

    private func vorbereiten() async {
        guard !vorbereitet else { return }
        vorbereitet = true
        zielReise = eintrag?.reise ?? vorgabe
        if let eintrag { zone = eintrag.zone; tagebuch = eintrag.tagebuchName ?? "" }
        else if let tagebuchVorgabe { tagebuch = tagebuchVorgabe }
        if let eintrag {
            datum = eintrag.datum ?? Date()
            titel = eintrag.titel ?? ""
            text = eintrag.text ?? ""
            gewaehlteOrte = eintrag.ortListe
            if let k = eintrag.koordinate {
                ort = Tagesort(name: eintrag.ortsname ?? "", breite: k.latitude, laenge: k.longitude, zeit: nil)
            }
            hierLand = eintrag.land ?? ""
            wetter = eintrag.tageswetter
            wetterAn = eintrag.tageswetter != nil || (eintrag.wetter ?? "").isEmpty
        } else if let tag, Tag.schluessel(tag) != Tag.schluessel(Date()) {
            // Ein vergangener Tag: am frühen Abend, dann steht der Eintrag
            // hinter allem, was tagsüber passiert ist.
            datum = Tag.kalender.date(bySettingHour: 19, minute: 0, second: 0, of: tag) ?? tag
        } else {
            datum = Date()
        }
        if istNeu, vorgabe == nil { zielReise = automatischeReise }
        await tagLaden(neu: istNeu)
    }

    private func tagLaden(neu: Bool) async {
        aufzeichner.uebertragen()
        assets = fotodienst.fotos(am: datum)
        let vorhanden = Set(eintrag?.fotoListe.compactMap(\.assetID) ?? [])
        assets.removeAll { vorhanden.contains($0.localIdentifier) }
        auswahl.removeAll { id in !assets.contains { $0.localIdentifier == id } }

        let heute = Tag.schluessel(datum) == Tag.schluessel(Date())
        sucheOrte = true
        if heute, neu, let standort = await aufzeichner.einmalOrten(),
           let name = await Ortsnamen.shared.name(fuer: standort.coordinate) {
            let t = Tagesort(name: name.titel, breite: standort.coordinate.latitude,
                             laenge: standort.coordinate.longitude, zeit: Date())
            hier = t
            hierLand = name.land
            if titel.isEmpty { waehlen(t) }
        }
        tagesorte = await Tagesorte.orte(von: zielReise, am: datum)
            .filter { t in hier.map { $0.name != t.name } ?? true }
        sucheOrte = false
        if neu, titel.isEmpty, let erster = tagesorte.first { waehlen(erster) }
    }

    // MARK: - Sichern

    private func sichern() async {
        await diktat.stoppen()
        speichert = true
        let persistenz = Persistenz.shared
        // Ohne Reise liegt der Eintrag im PRIVATEN Speicher (`anlegen` mit
        // `nil`) — er erscheint nur im eigenen Lebenstagebuch und reist mit
        // keiner Freigabe mit.
        let ziel = eintrag ?? persistenz.anlegen(Eintrag.self, bei: zielReise)
        if eintrag == nil {
            ziel.kennung = UUID()
            ziel.erstellt = Date()
            ziel.autor = Geraet.name
            ziel.reise = zielReise
            ziel.zeitzone = zone.identifier
        }
        ziel.datum = datum
        ziel.titel = titel.trimmingCharacters(in: .whitespacesAndNewlines)
        ziel.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        ziel.ortListe = gewaehlteOrte
        ziel.tagebuch = tagebuch
        ziel.geaendert = Date()
        if let ort {
            ziel.breite = ort.breite
            ziel.laenge = ort.laenge
            ziel.hatOrt = true
            ziel.ortsname = ort.name
        }
        if !hierLand.isEmpty, ort?.id == hier?.id { ziel.land = hierLand }
        ziel.tageswetter = wetterAn ? (wetter ?? ziel.tageswetter) : nil

        for foto in ziel.fotoListe
        where entfernt.contains(NSManagedObjectIDKey(uri: foto.objectID.uriRepresentation().absoluteString)) {
            persistenz.kontext.delete(foto)
        }
        persistenz.sichern()

        let gewaehlt = auswahl.compactMap { id in assets.first { $0.localIdentifier == id } }
        await fotodienst.uebernehmen(gewaehlt, in: ziel) { fertig in fortschritt = fertig }

        // Ohne eigenen Ort nimmt der Eintrag den seines ersten Fotos.
        if !ziel.hatOrt, let k = ziel.fotoListe.compactMap(\.koordinate).first {
            ziel.breite = k.latitude
            ziel.laenge = k.longitude
            ziel.hatOrt = true
            if let name = await Ortsnamen.shared.name(fuer: k) {
                ziel.ortsname = name.titel
                ziel.land = name.land
                if ziel.titel?.isEmpty ?? true { ziel.titel = name.titel }
            }
        } else if (ziel.land ?? "").isEmpty, let k = ziel.koordinate,
                  let name = await Ortsnamen.shared.name(fuer: k) {
            ziel.land = name.land
        }
        persistenz.sichern()
        // Die Spur des Tages sofort mitgeben (ab 1.0.14): Bis dahin kam sie
        // erst mit der nächsten Übertragung, also bis zu zehn Minuten später
        // — wer den Eintrag gleich öffnete, sah keine.
        Aufzeichner.shared.uebertragen()
        speichert = false
        schliessen()
    }
}

private struct Speicherhinweis: View {
    let fertig: Int
    let gesamt: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView(value: gesamt == 0 ? 1 : Double(fertig), total: Double(max(gesamt, 1)))
                    .frame(width: 180)
                Text(gesamt == 0 ? "Wird gesichert …" : "Fotos werden übernommen · \(min(fertig, gesamt)) von \(gesamt)")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}
