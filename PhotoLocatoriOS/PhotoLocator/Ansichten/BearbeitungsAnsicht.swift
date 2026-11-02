import MapKit
import Photos
import SwiftUI

private enum Adressstand: Equatable {
    case keine, laedt, gefunden(String), unbekannt
}

/// Die Bearbeitungsansicht: Foto oben, Karte unten (Trennlinie ziehbar),
/// Suchfeld über der Karte, Speichern und Blättern immer in Daumennähe.
struct BearbeitungsAnsicht: View {
    @Environment(AppZustand.self) private var app
    @Environment(\.dismiss) private var schliessen

    @State private var modell: BearbeitungsModell
    @State private var steuerung = KartenSteuerung()
    @State private var suche = OrtsSuche()
    @State private var adressen = Adressaufloesung()
    @State private var adresse: Adressstand = .keine
    @State private var vorschlaege: [Nachbarvorschlag] = []
    @State private var entfernenFragen = false
    @AppStorage("bearbeitung.teilung") private var teilung: Double = 0.42
    @FocusState private var suchFokus: Bool

    init(liste: Arbeitsliste, sitzung: Sitzungsspeicher, index: Int) {
        _modell = State(initialValue: BearbeitungsModell(liste: liste, sitzung: sitzung, index: index))
    }

    var body: some View {
        GeometryReader { geo in
            GeteilteAnsicht(
                anteil: suchFokus ? 0.12 : teilung,
                quer: geo.size.width > geo.size.height * 1.15,
                geaendert: { teilung = $0 }
            ) {
                fotoBereich
            } zweiter: {
                kartenBereich
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !suchFokus { aktionsleiste }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { werkzeugleiste }
        .overlay(alignment: .top) {
            if let hinweis = modell.hinweis {
                Hinweisblase(text: hinweis)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay {
            if modell.keinWeiteres { fertigHinweis }
        }
        .animation(.snappy, value: modell.hinweis)
        .animation(.snappy, value: suchFokus)
        .sensoryFeedback(.success, trigger: modell.erfolgZaehler)
        .alert(
            modell.fehler?.titel ?? "Fehler",
            isPresented: Binding(get: { modell.fehler != nil }, set: { if !$0 { modell.fehler = nil } }),
            presenting: modell.fehler
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { fehler in
            Text(fehler.text)
        }
        .confirmationDialog("Standort entfernen?", isPresented: $entfernenFragen, titleVisibility: .visible) {
            Button("Standort entfernen", role: .destructive) {
                Task { await modell.entfernen() }
            }
        } message: {
            Text("Die Ortsangabe wird aus diesem Foto in der Mediathek gelöscht. Mit „Rückgängig“ lässt sie sich wiederherstellen.")
        }
        // Nachbarvorschläge für das aktuelle Foto
        .task(id: modell.asset?.localIdentifier) {
            vorschlaege = []
            modell.vorwaermen()
            guard let asset = modell.asset, let datum = asset.creationDate else { return }
            let gefunden = await Nachbarsuche.suchen(um: datum, ausser: asset.localIdentifier)
            if !Task.isCancelled { vorschlaege = gefunden }
        }
        // Adresse zur Nadel — kurz abwarten, solange sie noch bewegt wird.
        .task(id: modell.nadel.map(Koordinaten.schluessel)) {
            guard let nadel = modell.nadel else {
                adresse = .keine
                return
            }
            adresse = .laedt
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            let text = await adressen.adresse(fuer: nadel)
            guard !Task.isCancelled else { return }
            adresse = text.map { .gefunden($0) } ?? .unbekannt
        }
        // Beim Blättern bleibt der Kartenausschnitt stehen; nur ein Foto mit
        // eigenem Standort wird ins Bild geholt.
        .onChange(of: modell.index) { _, _ in kameraFuerFoto() }
        .onAppear {
            DispatchQueue.main.async { kameraFuerFoto() }
        }
        .onDisappear { modell.aufraeumen() }
        .task(id: modell.hinweisZaehler) {
            guard modell.hinweis != nil else { return }
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            if !Task.isCancelled { modell.hinweis = nil }
        }
        .onChange(of: suchFokus) { _, fokus in
            if fokus, let region = steuerung.region { suche.bereich(region) }
        }
        .onChange(of: app.zugriff.aenderungen) { _, _ in
            // Wurde das Foto außerhalb der App geändert oder gelöscht?
            if let id = modell.asset?.localIdentifier, let frisch = StandortSpeicher.holen(id) {
                modell.liste.ersetzen(frisch)
            }
        }
    }

    private func kameraFuerFoto() {
        if let k = modell.nadel { steuerung.sichtbarMachen(k) }
    }

    private func uebernehmen(_ k: CLLocationCoordinate2D) {
        modell.nadel = k
        steuerung.sichtbarMachen(k, heranzoomen: true)
    }

    // MARK: - Foto

    private var fotoBereich: some View {
        ZStack {
            Color.black
            if let asset = modell.asset {
                VorschauBild(asset: asset)
            }
        }
        .overlay(alignment: .topLeading) {
            if let asset = modell.asset {
                Text(Formate.aufnahme(asset.creationDate))
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(8)
            }
        }
        .overlay(alignment: .topTrailing) {
            fotoMerkmale.padding(8)
        }
        .overlay(alignment: .bottom) {
            if modell.asset != nil && !modell.aenderbar {
                Label("iOS erlaubt für dieses Foto keine Standortänderung (z. B. geteiltes Album).", systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                    .padding(8)
            }
        }
        .clipped()
        .contentShape(Rectangle())
        // Wischen blättert — schneller als die Pfeile.
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { wert in
                    let x = wert.translation.width
                    guard abs(x) > 60, abs(x) > abs(wert.translation.height) * 1.5, !modell.speichert else { return }
                    if x < 0 { modell.vor() } else { modell.zurueck() }
                }
        )
    }

    @ViewBuilder
    private var fotoMerkmale: some View {
        if let asset = modell.asset {
            HStack(spacing: 6) {
                if asset.mediaSubtypes.contains(.photoLive) {
                    merkmal("LIVE", symbol: "livephoto")
                }
                if asset.location == nil {
                    merkmal("Kein Ort", symbol: "mappin.slash", farbe: .red)
                } else {
                    merkmal("Ort", symbol: "mappin", farbe: .green)
                }
            }
        }
    }

    private func merkmal(_ text: String, symbol: String, farbe: Color = .black) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(farbe.opacity(0.7), in: Capsule())
    }

    // MARK: - Karte

    private var kartenBereich: some View {
        ZStack(alignment: .top) {
            KartenAnsicht(
                nadel: modell.nadel,
                typ: app.karte.typ,
                steuerung: steuerung,
                gedaechtnis: app.karte
            ) { k in
                suchFokus = false
                modell.nadel = k
            }

            VStack(spacing: 8) {
                suchzeile
                if suchFokus {
                    vorschlagsliste
                }
                Spacer(minLength: 0)
                if !suchFokus {
                    infokarte
                }
            }
            .padding(10)
        }
    }

    private var suchzeile: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Ort, Adresse oder Koordinaten", text: $suche.text)
                    .focused($suchFokus)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { Task { await freieSuche() } }
                if suche.sucht {
                    ProgressView()
                } else if !suche.text.isEmpty {
                    Button {
                        suche.leeren()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Suche leeren")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            if suchFokus {
                Button("Fertig") { suchFokus = false }
                    .fontWeight(.semibold)
            } else {
                kartenKnoepfe
            }
        }
    }

    private var kartenKnoepfe: some View {
        HStack(spacing: 6) {
            Menu {
                Picker("Kartentyp", selection: Binding(get: { app.karte.typ }, set: { app.karte.typ = $0 })) {
                    ForEach(Kartentyp.allCases) { typ in
                        Label(typ.titel, systemImage: typ.symbol).tag(typ)
                    }
                }
            } label: {
                rundKnopf(app.karte.typ.symbol)
            }
            .accessibilityLabel("Kartentyp: \(app.karte.typ.titel)")

            Menu {
                Button("Nadel in die Kartenmitte setzen", systemImage: "scope") {
                    if let mitte = steuerung.mitte { modell.nadel = mitte }
                }
                Button("Zur Nadel springen", systemImage: "mappin.circle") {
                    if let k = modell.nadel { steuerung.zeige(k) }
                }
                .disabled(modell.nadel == nil)
            } label: {
                rundKnopf("scope")
            }
            .accessibilityLabel("Nadel-Werkzeuge")
        }
    }

    private func rundKnopf(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 44, height: 44)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var vorschlagsliste: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let k = suche.koordinate {
                    vorschlagZeile(symbol: "scope", titel: Koordinaten.text(k), untertitel: "Koordinaten übernehmen") {
                        suchFokus = false
                        modell.nadel = k
                        steuerung.zeige(k, spanne: 0.01)
                    }
                    Divider()
                }
                ForEach(Array(suche.vorschlaege.enumerated()), id: \.offset) { _, vorschlag in
                    vorschlagZeile(
                        symbol: vorschlag.subtitle.isEmpty ? "magnifyingglass" : "mappin.circle.fill",
                        titel: vorschlag.title,
                        untertitel: vorschlag.subtitle
                    ) {
                        Task { await waehlen(vorschlag) }
                    }
                    Divider()
                }
                if suche.vorschlaege.isEmpty && suche.koordinate == nil {
                    Text(suche.text.isEmpty
                         ? "Ort, Adresse, Sehenswürdigkeit oder Koordinaten (z. B. 47.6302, 13.0045) eingeben."
                         : "Keine Vorschläge – mit „Suchen“ frei suchen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(12)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: 300)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func vorschlagZeile(symbol: String, titel: String, untertitel: String, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(.red)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel)
                        .foregroundStyle(.primary)
                    if !untertitel.isEmpty {
                        Text(untertitel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func waehlen(_ vorschlag: MKLocalSearchCompletion) async {
        suchFokus = false
        do {
            let treffer = try await suche.ort(fuer: vorschlag)
            modell.nadel = treffer.koordinate
            steuerung.zeige(treffer.koordinate, spanne: treffer.spanne)
        } catch {
            modell.fehler = Fehlermeldung(error, titel: "Suche fehlgeschlagen")
        }
    }

    private func freieSuche() async {
        suchFokus = false
        guard !suche.text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            let treffer = try await suche.freieSuche()
            modell.nadel = treffer.koordinate
            steuerung.zeige(treffer.koordinate, spanne: treffer.spanne)
        } catch {
            modell.fehler = Fehlermeldung(error, titel: "Suche fehlgeschlagen")
        }
    }

    // MARK: - Infokarte unter der Karte

    private var infokarte: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: modell.nadel == nil ? "hand.tap" : "mappin.and.ellipse")
                    .font(.title3)
                    .foregroundStyle(modell.nadel == nil ? Color.secondary : Color.red)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    if let k = modell.nadel {
                        Text(Koordinaten.text(k))
                            .font(.callout.weight(.semibold).monospacedDigit())
                            .textSelection(.enabled)
                        adresszeile
                    } else {
                        Text("Tippe auf die Karte, um den Aufnahmeort zu setzen.")
                            .font(.callout.weight(.semibold))
                        Text("Oder oben nach einem Ort suchen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                zustandsMarke
            }

            if !vorschlagsKnoepfe.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(vorschlagsKnoepfe) { knopf in
                            Vorschlagsknopf(
                                symbol: knopf.symbol,
                                titel: knopf.titel,
                                untertitel: knopf.untertitel,
                                farbe: knopf.farbe,
                                aktion: knopf.aktion
                            )
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var adresszeile: some View {
        switch adresse {
        case .keine:
            EmptyView()
        case .laedt:
            Text("Adresse wird gesucht …")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .gefunden(let text):
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        case .unbekannt:
            Text("Keine Adresse bekannt – die Position wird trotzdem genau so gespeichert.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var zustandsMarke: some View {
        if modell.nadel != nil {
            if modell.nadelGeaendert {
                Text(modell.gespeichert == nil ? "neu" : "geändert")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.orange, in: Capsule())
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Gespeichert")
            }
        }
    }

    private struct Knopf: Identifiable {
        let id: String
        let symbol: String
        let titel: String
        let untertitel: String?
        let farbe: Color
        let aktion: () -> Void
    }

    private var vorschlagsKnoepfe: [Knopf] {
        var knoepfe: [Knopf] = []
        if modell.nadelGeaendert, let alt = modell.gespeichert {
            knoepfe.append(Knopf(
                id: "zuruecksetzen", symbol: "arrow.uturn.backward", titel: "Zurücksetzen",
                untertitel: "bisheriger Ort", farbe: .orange
            ) {
                modell.nadelZuruecksetzen()
                steuerung.sichtbarMachen(alt)
            })
        }
        if let letzter = app.sitzung.letzterOrt, !Koordinaten.gleich(letzter.koordinate, modell.nadel) {
            knoepfe.append(Knopf(
                id: "letzter", symbol: "arrow.down.to.line", titel: "Letzten Standort übernehmen",
                untertitel: Koordinaten.text(letzter.koordinate), farbe: .accentColor
            ) {
                uebernehmen(letzter.koordinate)
            })
        }
        for v in vorschlaege where !Koordinaten.gleich(v.koordinate, modell.nadel) {
            let richtung = v.richtung == .vorher ? "früher" : "später"
            knoepfe.append(Knopf(
                id: "nachbar-\(v.id)",
                symbol: v.richtung == .vorher ? "clock.arrow.circlepath" : "clock.badge.checkmark",
                titel: "Nachbarfoto · \(Formate.dauer(v.abstand)) \(richtung)",
                untertitel: Formate.datumZeit(v.datum),
                farbe: .purple
            ) {
                uebernehmen(v.koordinate)
            })
        }
        return knoepfe
    }

    // MARK: - Aktionsleiste

    private var aktionsleiste: some View {
        HStack(spacing: 10) {
            Button {
                modell.zurueck()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .disabled(!modell.hatVorheriges || modell.speichert)
            .accessibilityLabel("Vorheriges Foto")

            if modell.art == .ergaenzen {
                Button {
                    modell.ueberspringen()
                } label: {
                    Text("Überspringen")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 34)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(modell.speichert)
            }

            Button {
                Task { await modell.primaer() }
            } label: {
                HStack(spacing: 8) {
                    if modell.speichert {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: modell.primaerTitel == "Weiter" ? "arrow.right" : "checkmark")
                    }
                    Text(modell.primaerTitel)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!modell.primaerMoeglich)

            Button {
                modell.vor()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .disabled(!modell.hatNaechstes || modell.speichert)
            .accessibilityLabel("Nächstes Foto")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Werkzeugleiste

    @ToolbarContentBuilder
    private var werkzeugleiste: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 0) {
                Text(modell.titel)
                    .font(.headline)
                    .monospacedDigit()
                if let untertitel = modell.untertitel {
                    Text(untertitel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .accessibilityElement(children: .combine)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                Task { await modell.rueckgaengig() }
            } label: {
                Image(systemName: "arrow.uturn.backward.circle")
            }
            .disabled(!modell.kannRueckgaengig)
            .accessibilityLabel(modell.rueckgaengigText)

            Menu {
                Button(modell.rueckgaengigText, systemImage: "arrow.uturn.backward") {
                    Task { await modell.rueckgaengig() }
                }
                .disabled(!modell.kannRueckgaengig)

                Button("Nadel zurücksetzen", systemImage: "arrow.counterclockwise") {
                    modell.nadelZuruecksetzen()
                    if let k = modell.nadel { steuerung.sichtbarMachen(k) }
                }
                .disabled(!modell.nadelGeaendert)

                if modell.ursprungWiederherstellbar {
                    Button(
                        modell.ursprung?.ort == nil
                            ? "Ursprünglichen Zustand (ohne Standort) wiederherstellen"
                            : "Ursprünglichen Standort wiederherstellen",
                        systemImage: "clock.arrow.circlepath"
                    ) {
                        Task { await modell.ursprungWiederherstellen() }
                    }
                }

                if let k = modell.nadel {
                    Button("Koordinaten kopieren", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = Koordinaten.text(k)
                        modell.zeigeHinweis("Koordinaten kopiert")
                    }
                }

                if modell.art == .bearbeiten, modell.gespeichert != nil {
                    Divider()
                    Button("Standort entfernen …", systemImage: "mappin.slash", role: .destructive) {
                        entfernenFragen = true
                    }
                    .disabled(!modell.aenderbar || modell.speichert)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Weitere Aktionen")
        }
    }

    // MARK: - Ende der Liste (Modus A)

    private var fertigHinweis: some View {
        let offen = modell.offen ?? 0
        return VStack(spacing: 14) {
            Image(systemName: offen == 0 ? "checkmark.seal.fill" : "forward.fill")
                .font(.system(size: 44))
                .foregroundStyle(offen == 0 ? Color.green : Color.orange)
            Text(offen == 0 ? "Alle Fotos haben jetzt einen Standort" : "Nur noch übersprungene Fotos")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
            Text(offen == 0
                 ? "Diese Sitzung ist abgeschlossen."
                 : "\(Fortschritt.rest(offen: offen).capitalizedFirst) – du hast sie übersprungen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                if offen > 0 {
                    Button("Übersprungene bearbeiten") { modell.erstesOffenes() }
                        .buttonStyle(.borderedProminent)
                }
                Button("Zur Übersicht") {
                    modell.keinWeiteres = false
                    schliessen()
                }
                .buttonStyle(.bordered)
                Button("Hierbleiben") { modell.keinWeiteres = false }
                    .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        .shadow(radius: 20)
        .padding(24)
    }
}

private extension String {
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
