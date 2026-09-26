import SwiftUI
import Photos

/// Fotos einer vergangenen Reise auf einmal übernehmen (ab 1.0.17): alle
/// Aufnahmen im Zeitraum der Reise, nach Tag in Ortszeit, zum Abwählen. Je
/// Tag entsteht EIN Eintrag mit Zeit, Ort, Orten des Tages und Wetter — die
/// Regeln stehen in `Nachtrag.swift`.
struct FotoimportView: View {
    @ObservedObject var reise: Reise
    @EnvironmentObject private var fotodienst: Fotodienst
    @Environment(\.dismiss) private var schliessen

    @State private var gruppen: [Nachtrag.Tagesgruppe] = []
    @State private var abgewaehlt: Set<String> = []
    @State private var laedt = true
    @State private var laeuft = false
    @State private var fertig = 0
    @State private var gesamt = 0
    /// Woher die Fotos kommen (ab 1.0.19): `nil` = alle Fotos im Zeitraum
    /// der Reise, sonst ein Album der Mediathek.
    @State private var album: Fotodienst.Album?
    @State private var alben: [Fotodienst.Album] = []
    @State private var fund = Nachtrag.Fund()

    private var gewaehlt: [Nachtrag.Tagesgruppe] {
        gruppen.map { g in
            var neu = g
            neu.assets = g.assets.filter { !abgewaehlt.contains($0.localIdentifier) }
            return neu
        }.filter { !$0.assets.isEmpty }
    }

    private var anzahl: Int { gewaehlt.reduce(0) { $0 + $1.assets.count } }

    var body: some View {
        NavigationStack {
            Group {
                if !fotodienst.darfLesen {
                    ContentUnavailableView {
                        Label("Kein Zugriff auf Fotos", systemImage: "photo.on.rectangle.angled")
                    } description: {
                        Text("Erlaube Fernweh den Zugriff auf deine Fotos, dann liegen hier die Aufnahmen aus dem Zeitraum der Reise bereit.")
                    } actions: {
                        Button("Fotos erlauben") {
                            Task { await fotodienst.erlaubnisAnfragen(); await laden() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if laedt {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Fotos und Ortszeit werden gesucht …")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    liste
                }
            }
            .navigationTitle("Fotos übernehmen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() }.disabled(laeuft) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") { Task { await uebernehmen() } }
                        .fontWeight(.semibold)
                        .disabled(anzahl == 0 || laeuft)
                }
            }
            .overlay {
                if laeuft {
                    ZStack {
                        Color.black.opacity(0.25).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView(value: Double(fertig), total: Double(max(gesamt, 1))).frame(width: 200)
                            Text("Fotos werden übernommen · \(min(fertig, gesamt)) von \(gesamt)")
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
            }
            .interactiveDismissDisabled(laeuft)
            .task {
                alben = fotodienst.alben()
                await laden()
            }
            // Hundert Fotos übernehmen dauert — dabei soll das Telefon nicht
            // einschlafen.
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        }
    }

    private var liste: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Je Tag entsteht ein Eintrag mit Uhrzeit, Ort und Wetter aus den Fotos. Tippe ein Foto an, um es wegzulassen. Texte — zum Tag und zu jedem Foto — schreibst du danach.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                quellenwahl
                if fund.ausserhalb > 0 { ausserhalbHinweis }
                if gruppen.isEmpty {
                    Label(album == nil
                          ? "Zwischen \(Tag.zeitraum(reise.anfang, reise.schluss)) liegen in deiner Mediathek keine Fotos, die nicht schon in der Reise stehen."
                          : "In diesem Album liegen keine Fotos aus dem Zeitraum der Reise, die nicht schon in ihr stehen.",
                          systemImage: "photo")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if fotodienst.status == .limited {
                    Label("Du hast Fernweh nur einen Teil deiner Fotos freigegeben — hier steht nur, was darin liegt.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                ForEach(gruppen) { g in
                    tagesblock(g)
                }
            }
            .padding(18)
        }
        .safeAreaInset(edge: .bottom) {
            Text(anzahl == 1 ? "1 Foto an \(gewaehlt.count) Tag" : "\(anzahl) Fotos an \(gewaehlt.count) \(gewaehlt.count == 1 ? "Tag" : "Tagen")")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.regularMaterial)
        }
    }

    /// Woher: der Zeitraum der Reise oder ein Album.
    private var quellenwahl: some View {
        Menu {
            Button { waehlen(nil) } label: {
                Label("Alle Fotos im Zeitraum der Reise", systemImage: album == nil ? "checkmark" : "calendar")
            }
            if !alben.isEmpty {
                Section("Aus einem Album") {
                    ForEach(alben) { a in
                        Button { waehlen(a) } label: {
                            Label("\(a.name) (\(a.anzahl))",
                                  systemImage: album?.id == a.id ? "checkmark" : "rectangle.stack")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: album == nil ? "calendar" : "rectangle.stack.fill")
                VStack(alignment: .leading, spacing: 1) {
                    Text("Fotos aus").font(.caption).foregroundStyle(.secondary)
                    Text(album?.name ?? "dem Zeitraum der Reise").font(.headline).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(laedt || laeuft)
    }

    /// Ein Album mit Fotos von vor oder nach der Reise: sagen, wie viele —
    /// und den Weg anbieten, den Zeitraum der Reise daran anzupassen.
    private var ausserhalbHinweis: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(fund.ausserhalb == 1
                  ? "1 Foto des Albums liegt außerhalb der Reise (\(Tag.zeitraum(reise.anfang, reise.ende))) und fehlt hier."
                  : "\(fund.ausserhalb) Fotos des Albums liegen außerhalb der Reise (\(Tag.zeitraum(reise.anfang, reise.ende))) und fehlen hier.",
                  systemImage: "calendar.badge.exclamationmark")
                .font(.callout)
                .foregroundStyle(.orange)
            if let von = fund.ersterTag.flatMap(Tag.datum(schluessel:)),
               let bis = fund.letzterTag.flatMap(Tag.datum(schluessel:)),
               von < reise.anfang || bis > reise.schluss,
               bis <= Tag.anfang(Date()) {
                Button {
                    erweitern(von: von, bis: bis)
                } label: {
                    Label("Reise auf \(Tag.zeitraum(min(von, reise.anfang), max(bis, reise.schluss))) erweitern",
                          systemImage: "arrow.left.and.right")
                }
                .buttonStyle(.bordered)
                .tint(reise.palette.haupt)
            }
        }
    }

    private func waehlen(_ a: Fotodienst.Album?) {
        album = a
        abgewaehlt = []
        Task { await laden() }
    }

    /// Nur ERWEITERN, nie verkürzen — Tage, die schon in der Reise stehen,
    /// verschwinden dadurch nicht.
    private func erweitern(von: Date, bis: Date) {
        if von < reise.anfang { reise.beginn = von }
        if bis > reise.schluss { reise.ende = bis }
        Persistenz.shared.sichern()
        Task { await laden() }
    }

    private func tagesblock(_ g: Nachtrag.Tagesgruppe) -> some View {
        let alleAus = g.assets.allSatisfy { abgewaehlt.contains($0.localIdentifier) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    if let d = g.datum {
                        Text(Tag.wochentagLang.string(from: d)).font(Stil.titel(19))
                    }
                    Text("\(g.assets.count) Fotos" + (g.zone.identifier == TimeZone.current.identifier ? "" : " · Ortszeit \(g.zone.abbreviation() ?? g.zone.identifier)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(alleAus ? "Alle" : "Keine") {
                    withAnimation {
                        for a in g.assets {
                            if alleAus { abgewaehlt.remove(a.localIdentifier) } else { abgewaehlt.insert(a.localIdentifier) }
                        }
                    }
                }
                .font(.subheadline.weight(.semibold))
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 4)], spacing: 4) {
                ForEach(g.assets, id: \.localIdentifier) { asset in
                    let aus = abgewaehlt.contains(asset.localIdentifier)
                    AssetBild(asset: asset, kante: 220)
                        .aspectRatio(1, contentMode: .fit)
                        .opacity(aus ? 0.3 : 1)
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: aus ? "circle" : "checkmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, reise.palette.haupt)
                                .shadow(radius: 2)
                                .padding(4)
                        }
                        .overlay(alignment: .bottomLeading) {
                            if asset.location == nil {
                                Image(systemName: "location.slash.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .shadow(radius: 2)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if aus { abgewaehlt.remove(asset.localIdentifier) } else { abgewaehlt.insert(asset.localIdentifier) }
                        }
                }
            }
        }
    }

    private func laden() async {
        guard fotodienst.darfLesen else { laedt = false; return }
        laedt = true
        fund = await Nachtrag.fotos(fuer: reise, album: album?.sammlung)
        gruppen = fund.gruppen
        laedt = false
    }

    private func uebernehmen() async {
        let auswahl = gewaehlt
        gesamt = auswahl.reduce(0) { $0 + $1.assets.count }
        fertig = 0
        laeuft = true
        _ = await Nachtrag.uebernehmen(auswahl, in: reise) { f, g in
            fertig = f
            gesamt = g
        }
        laeuft = false
        schliessen()
    }
}
