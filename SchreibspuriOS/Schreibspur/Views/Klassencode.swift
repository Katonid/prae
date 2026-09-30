import SwiftUI

/// Kindergerät: Klassencode eingeben, dann Namen und Tier wählen
/// (seit 1.0.12). Groß und einfach — die Lehrkraft schreibt den Code an
/// die Tafel.
struct KlassencodeEingabe: View {
    /// Zurück zur Wahl beim ersten Start (nil: kein Zurück).
    var zurueck: (() -> Void)?

    @Environment(Klasse.self) private var klasse
    @State private var code = ""
    @State private var klassenName: String?
    @State private var name = ""
    @State private var tier = Kind.tiere[0]
    @State private var fehler: String?
    @State private var arbeitet = false
    @FocusState private var fokus: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if let klassenName {
                    namenWahl(klassenName)
                } else {
                    codeEingabe
                }
                if let fehler {
                    Text(fehler)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(Farben.markierung)
                        .multilineTextAlignment(.center)
                }
                if arbeitet { ProgressView().controlSize(.large) }
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
                    .disabled(Klassencode.lesen(code).count != Klassencode.laenge || arbeitet)
            }
        }
        .onAppear { fokus = true }
    }

    private func namenWahl(_ klassenName: String) -> some View {
        VStack(spacing: 18) {
            Text("Klasse \(klassenName)")
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
                Button("Zurück") { self.klassenName = nil }
                    .buttonStyle(RundKnopf(farbe: Farben.knopf))
                Button("Los geht’s!", action: beitreten)
                    .buttonStyle(RundKnopf(farbe: Farben.akzent))
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || arbeitet)
            }
        }
    }

    private func nachschlagen() {
        guard Klassencode.lesen(code).count == Klassencode.laenge else { return }
        arbeitet = true
        fehler = nil
        Task {
            do {
                klassenName = try await Wolke.klasseNachschlagen(code)
            } catch {
                fehler = Wolke.klartext(error)
            }
            arbeitet = false
        }
    }

    private func beitreten() {
        arbeitet = true
        fehler = nil
        let n = name.trimmingCharacters(in: .whitespaces)
        Task {
            do {
                try await Wolke.beitreten(code: code, name: n, tier: tier, klasse: klasse)
            } catch {
                fehler = Wolke.klartext(error)
            }
            arbeitet = false
        }
    }
}

/// Lehrergerät: Klassen anlegen, ihre Codes zeigen, Anmeldung öffnen und
/// schließen.
struct KlassenVerwaltung: View {
    @Environment(Klasse.self) private var klasse
    @State private var neuerName = ""
    @State private var vorhandenerCode = ""
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

                Section("Neue Klasse") {
                    TextField("Name, z. B. 1b", text: $neuerName)
                    Button("Klasse anlegen") {
                        let name = neuerName.trimmingCharacters(in: .whitespaces)
                        ausfuehren {
                            anzeige = try await wolke.klasseAnlegen(name)
                            neuerName = ""
                        }
                    }
                    .disabled(neuerName.trimmingCharacters(in: .whitespaces).isEmpty || arbeitet)
                }

                Section {
                    TextField("Klassencode", text: $vorhandenerCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Button("Hinzufügen") {
                        ausfuehren {
                            try await wolke.klasseHinzufuegen(vorhandenerCode)
                            vorhandenerCode = ""
                        }
                    }
                    .disabled(Klassencode.lesen(vorhandenerCode).count != Klassencode.laenge || arbeitet)
                } header: {
                    Text("Vorhandene Klasse auf dieses Gerät holen")
                } footer: {
                    Text("Für ein neues Lehrergerät oder nach dem Neuladen der App. Geht nur mit deiner eigenen Apple-ID.")
                }

                if let fehler {
                    Section { Text(fehler).foregroundStyle(.red) }
                }
            } else {
                Text("Dieses Gerät ist kein Lehrergerät.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Klassen und Codes")
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
