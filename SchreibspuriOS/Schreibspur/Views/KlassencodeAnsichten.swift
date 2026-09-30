import SwiftUI

/// Kindergerät: Klassencode eingeben, dann Namen und Tier wählen — oder,
/// wenn das Lehrergerät in der Nähe die Klasse schickt, sich aus der Liste
/// wählen (Gast auf dem geteilten iPad, der jede Stunde neu beginnt).
struct KlassencodeEingabe: View {
    /// Zurück zur Wahl beim ersten Start (nil: kein Zurück).
    var zurueck: (() -> Void)?

    @Environment(Klasse.self) private var klasse
    @State private var code = ""
    @State private var info: Klasseninfo?
    /// Frühere Anmeldung dieser Apple-ID in dieser Klasse.
    @State private var frueher: KindKurz?
    @State private var neu = false
    @State private var name = ""
    @State private var tier = Kind.tiere[0]
    @State private var fehler: String?
    @State private var sucht: String?
    @FocusState private var fokus: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if let info {
                    if neu || (info.kinder.isEmpty && frueher == nil) {
                        namenWahl(info)
                    } else {
                        werBistDu(info)
                    }
                } else {
                    codeEingabe
                }
                if let fehler {
                    Text(fehler)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(Farben.markierung)
                        .multilineTextAlignment(.center)
                }
                if let sucht {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(sucht).font(.system(.body, design: .rounded)).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: 620)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Farben.verlauf.ignoresSafeArea())
    }

    private var codeEingabe: some View {
        VStack(spacing: 18) {
            Text("🔑").font(.system(size: 70)).padding(.top, 30)
            Text("Wie heißt der Klassencode?")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Farben.tinteDunkel)
            Text("Er steht an der Tafel.")
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(.secondary)
            TextField("", text: $code)
                .font(.system(size: 46, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($fokus)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 18).fill(.white)
                    .shadow(color: .black.opacity(0.1), radius: 6, y: 3))
                .onChange(of: code) { _, neu in
                    let sauber = Klassencode.lesen(neu)
                    let anzeige = Klassencode.anzeige(String(sauber.prefix(Klassencode.laenge)))
                    if anzeige != neu { code = anzeige }
                    fehler = nil
                }
                .onSubmit(nachschlagen)
            HStack(spacing: 14) {
                if let zurueck {
                    Button("Zurück", action: zurueck).buttonStyle(RundKnopf(farbe: Farben.knopf))
                }
                Button("Weiter", action: nachschlagen)
                    .buttonStyle(RundKnopf(farbe: Farben.akzent))
                    .disabled(Klassencode.lesen(code).count != Klassencode.laenge || sucht != nil)
            }
        }
        .onAppear { fokus = true }
    }

    /// Das Lehrergerät hat die Kinder der Klasse geschickt, oder diese
    /// Apple-ID war schon angemeldet: sich wählen.
    private func werBistDu(_ info: Klasseninfo) -> some View {
        VStack(spacing: 18) {
            Text("Klasse \(info.name)")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Farben.farbe(.woerter))
                .padding(.top, 20)
            Text("Wer bist du?")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(Farben.tinteDunkel)
            let liste = frueher.map { [$0] } ?? info.kinder
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(liste) { k in
                    Button {
                        Wolke.beitreten(info, als: k, name: k.name, tier: k.tier, klasse: klasse)
                    } label: {
                        VStack(spacing: 4) {
                            Text(k.tier).font(.system(size: 48))
                            Text(k.name)
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(Farben.tinteDunkel)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 18).fill(.white)
                            .shadow(color: .black.opacity(0.08), radius: 5, y: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 14) {
                Button("Zurück") { self.info = nil; frueher = nil }
                    .buttonStyle(RundKnopf(farbe: Farben.knopf))
                if info.offen {
                    Button("Ich bin neu") { neu = true }
                        .buttonStyle(RundKnopf(farbe: Farben.akzent))
                }
            }
        }
    }

    private func namenWahl(_ info: Klasseninfo) -> some View {
        VStack(spacing: 18) {
            Text("Klasse \(info.name)")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Farben.farbe(.woerter))
                .padding(.top, 20)
            Text("Wie heißt du?")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(Farben.tinteDunkel)
            TextField("Dein Vorname", text: $name)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 18).fill(.white)
                    .shadow(color: .black.opacity(0.1), radius: 6, y: 3))
            Text("Such dir ein Tier aus:")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(Farben.tinteDunkel)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 10)], spacing: 10) {
                ForEach(Kind.tiere, id: \.self) { t in
                    Button { tier = t } label: {
                        Text(t)
                            .font(.system(size: 40))
                            .frame(width: 64, height: 64)
                            .background(RoundedRectangle(cornerRadius: 16)
                                .fill(tier == t ? Farben.akzent.opacity(0.3) : Color.white))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 14) {
                Button("Zurück") {
                    if neu { neu = false } else { self.info = nil }
                }
                .buttonStyle(RundKnopf(farbe: Farben.knopf))
                Button("Los geht’s!") {
                    Wolke.beitreten(info, als: nil, name: name.trimmingCharacters(in: .whitespaces),
                                    tier: tier, klasse: klasse)
                }
                .buttonStyle(RundKnopf(farbe: Farben.akzent))
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || !info.offen)
            }
        }
    }

    /// Erst im Briefkasten (iCloud) nachsehen; geht das nicht, das
    /// Lehrergerät in der Nähe fragen — das geht auch ohne Apple-ID und
    /// ohne Netz, und es schickt die Namen der Klasse mit.
    private func nachschlagen() {
        guard Klassencode.lesen(code).count == Klassencode.laenge, sucht == nil else { return }
        fehler = nil
        neu = false
        sucht = "Ich suche die Klasse …"
        Task {
            var gefunden: Klasseninfo?
            do {
                gefunden = try await Wolke.klasseNachschlagen(code)
            } catch Wolke.Fehler.unbekannterCode {
                fehler = Wolke.Fehler.unbekannterCode.errorDescription
            } catch Wolke.Fehler.geschlossen {
                fehler = Wolke.Fehler.geschlossen.errorDescription
            } catch {
                // Kein Netz o. Ä. — gleich über Funk.
            }
            // Über Funk kommen die Namen der Klasse mit; das braucht der
            // Gast, der sich jede Stunde neu anmeldet.
            if fehler == nil {
                sucht = "Ich suche das Lehrergerät in der Nähe …"
                if let nah = await Wolke.inDerNaeheSuchen(code, sekunden: gefunden == nil ? 25 : 6) {
                    gefunden = nah
                }
            }
            if let g = gefunden {
                frueher = await Wolke.fruehereAnmeldung(g.code)
                info = g
            } else if fehler == nil {
                fehler = "Die Klasse ist gerade nicht zu finden. Ist das Lehrergerät in der Nähe und Schreibspur dort offen?"
            }
            sucht = nil
        }
    }
}

/// Lehrergerät: Klassen anlegen, ihre Codes zeigen, Anmeldung öffnen und
/// schließen.
struct KlassenVerwaltung: View {
    @Environment(Klasse.self) private var klasse
    @State private var neueKlasse = false
    @State private var fehler: String?
    @State private var arbeitet = false
    @State private var anzeige: Klassenzimmer?
    @State private var frageLoeschen: Klassenzimmer?

    var body: some View {
        Form {
            if let wolke = klasse.wolke {
                Section {
                    ForEach(wolke.klassen) { k in
                        Button { anzeige = k } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Klasse \(k.name)").font(.headline).foregroundStyle(.primary)
                                    Text("\(klasse.kinder.filter { $0.klasse == k.code }.count) Kinder angemeldet")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(Klassencode.anzeige(k.code))
                                    .font(.system(.title3, design: .monospaced, weight: .bold))
                                    .foregroundStyle(k.offen ? Farben.farbe(.woerter) : .secondary)
                            }
                        }
                        .swipeActions {
                            Button("Löschen", role: .destructive) { frageLoeschen = k }
                        }
                    }
                    if wolke.klassen.isEmpty {
                        Text("Noch keine Klasse.").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Deine Klassen")
                } footer: {
                    Text("Schreib den Code an die Tafel. Jedes Kind gibt ihn einmal auf seinem iPad ein und wählt seinen Namen und sein Tier — danach landet alles, was es schreibt, in deiner Klassenübersicht. Tippe auf eine Klasse, um den Code groß zu zeigen.")
                }

                Section {
                    Button {
                        neueKlasse = true
                    } label: {
                        Label("Neue Klasse anlegen …", systemImage: "plus.circle.fill")
                    }
                    .disabled(arbeitet)
                }

                Section {
                    NavigationLink("Auf ein weiteres Lehrergerät übertragen") { UebertragungZeigen() }
                    NavigationLink("Von einem anderen Lehrergerät übernehmen") { UebertragungAnnehmen() }
                } header: {
                    Text("Zweites Lehrergerät")
                } footer: {
                    Text("Z. B. dienstliches und privates iPad: Beide nebeneinander legen, Schreibspur auf beiden öffnen. Das eine zeigt eine Zahl, am anderen gibst du sie ein — dann liest es dieselben Klassen.")
                }

                if let fehler {
                    Section { Text(fehler).foregroundStyle(.red) }
                }
            } else {
                Text("Dieses Gerät ist kein Lehrergerät.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Klassen und Codes")
        .klasseAnlegen(isPresented: $neueKlasse) { name in
            guard let wolke = klasse.wolke else { return }
            ausfuehren { anzeige = try await wolke.klasseAnlegen(name) }
        }
        .sheet(item: $anzeige) { k in
            KlassencodeTafel(klassenzimmer: k)
                .environment(klasse)
        }
        .confirmationDialog("Klasse \(frageLoeschen?.name ?? "") löschen?",
                            isPresented: Binding(get: { frageLoeschen != nil }, set: { if !$0 { frageLoeschen = nil } }),
                            titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let k = frageLoeschen, let wolke = klasse.wolke {
                    ausfuehren { try await wolke.klasseLoeschen(k) }
                }
            }
        } message: {
            Text("Der Code gilt dann nicht mehr. Die angemeldeten Kinder und ihre Seiten bleiben in deiner Übersicht.")
        }
    }

    private func ausfuehren(_ arbeit: @escaping () async throws -> Void) {
        arbeitet = true
        fehler = nil
        Task {
            do { try await arbeit() } catch { fehler = Wolke.klartext(error) }
            arbeitet = false
        }
    }
}

/// Der Code groß — zum Abschreiben an die Tafel oder zum Zeigen am Beamer.
struct KlassencodeTafel: View {
    let klassenzimmer: Klassenzimmer
    @Environment(Klasse.self) private var klasse
    @Environment(\.dismiss) private var dismiss
    @State private var offen = true
    @State private var fehler: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Text("Klasse \(klassenzimmer.name)")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Farben.tinteDunkel)
                Text(Klassencode.anzeige(klassenzimmer.code))
                    .font(.system(size: 96, weight: .black, design: .monospaced))
                    .foregroundStyle(Farben.farbe(.woerter))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("Öffne Schreibspur, tippe auf „Ich übe in meiner Klasse“ und gib diesen Code ein.")
                    .font(.system(.title3, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Farben.tinteDunkel)
                Toggle("Anmeldung offen", isOn: $offen)
                    .frame(maxWidth: 320)
                    .onChange(of: offen) { _, neu in
                        guard let wolke = klasse.wolke else { return }
                        Task {
                            do { try await wolke.anmeldungOeffnen(klassenzimmer, neu) } catch { fehler = Wolke.klartext(error) }
                        }
                    }
                if let fehler { Text(fehler).foregroundStyle(.red) }
                Text("Ist die Anmeldung geschlossen, kann sich niemand mehr mit dem Code anmelden — wer schon angemeldet ist, bleibt.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Spacer()
            }
            .padding(30)
            .frame(maxWidth: .infinity)
            .background(Farben.verlauf.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
            .onAppear { offen = klassenzimmer.offen }
        }
    }
}

/// Erstes Lehrergerät: die Zahl für das zweite.
struct UebertragungZeigen: View {
    @Environment(Klasse.self) private var klasse

    var body: some View {
        VStack(spacing: 20) {
            if let pin = klasse.wolke?.uebertragungsPIN {
                Text("Gib diese Zahl am anderen Lehrergerät ein:")
                    .font(.title3)
                Text(pin)
                    .font(.system(size: 64, weight: .black, design: .monospaced))
                    .foregroundStyle(Farben.farbe(.woerter))
                Text("Beide Geräte in der Nähe, Schreibspur auf beiden offen.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Label("Übertragen", systemImage: "checkmark.circle.fill")
                    .font(.title2).foregroundStyle(Farben.start)
            }
        }
        .padding(30)
        .navigationTitle("Übertragen")
        .onAppear { klasse.wolke?.uebertragungStarten() }
        .onDisappear { klasse.wolke?.uebertragungBeenden() }
    }
}

/// Zweites Lehrergerät: mit der Zahl übernehmen.
struct UebertragungAnnehmen: View {
    @Environment(Klasse.self) private var klasse
    @State private var pin = ""
    @State private var laeuft = false
    @State private var meldung: String?
    @State private var fertig = false

    var body: some View {
        Form {
            Section {
                TextField("Zahl vom anderen Gerät", text: $pin)
                    .keyboardType(.numberPad)
                    .font(.system(.title, design: .monospaced))
                Button(laeuft ? "Suche …" : "Übernehmen") {
                    laeuft = true
                    meldung = nil
                    Task {
                        do {
                            try await klasse.wolke?.uebernehmen(pin: pin)
                            fertig = true
                        } catch {
                            meldung = Wolke.klartext(error)
                        }
                        laeuft = false
                    }
                }
                .disabled(pin.count != 6 || laeuft)
            } footer: {
                if fertig {
                    Text("Übernommen. Die Seiten der Kinder werden jetzt aus dem Briefkasten geholt.").foregroundStyle(Farben.start)
                } else if let meldung {
                    Text(meldung).foregroundStyle(.red)
                } else {
                    Text("Am anderen Lehrergerät: Klassen und Codes → „Auf ein weiteres Lehrergerät übertragen“.")
                }
            }
        }
        .navigationTitle("Übernehmen")
    }
}

/// „Neue Klasse“: der Name in einem eigenen Eingabefenster (seit 1.0.14).
///
/// Lehre aus 1.0.13 (Nutzer, mit Bildschirmfoto: „die Felder sind grau, ich
/// kann nichts eintragen“): Ein Eingabefeld mitten in der Liste der Klassen
/// nahm keine Eingabe an. Die Liste baut sich neu auf, sobald der Abgleich
/// (Minutentakt, Funk) seinen Stand ändert; das Feld verlor dabei den
/// Fokus. Das Eingabefenster (`alert` mit Textfeld) gehört UIKit und
/// bleibt davon unberührt.
private struct KlasseAnlegenFenster: ViewModifier {
    @Binding var isPresented: Bool
    let anlegen: (String) -> Void
    @State private var name = ""

    func body(content: Content) -> some View {
        content.alert("Neue Klasse", isPresented: $isPresented) {
            TextField("Name, z. B. 1b", text: $name)
                .textInputAutocapitalization(.never)
            Button("Anlegen") {
                let n = name.trimmingCharacters(in: .whitespaces)
                name = ""
                if !n.isEmpty { anlegen(n) }
            }
            Button("Abbrechen", role: .cancel) { name = "" }
        } message: {
            Text("Wie heißt die Klasse? Danach zeigt die App ihren Code.")
        }
    }
}

extension View {
    func klasseAnlegen(isPresented: Binding<Bool>, anlegen: @escaping (String) -> Void) -> some View {
        modifier(KlasseAnlegenFenster(isPresented: isPresented, anlegen: anlegen))
    }
}
