import SwiftUI

// Alles, was man vom Schloss eines Tagebuchs SIEHT (ab 1.0.10). Die Regeln
// dahinter stehen in `Schloss.swift`.

/// Ein Eintrag in einer Liste — offen als Verweis zum Lesen, zu als gesperrte
/// Karte, die beim Antippen nach dem Passwort fragt. Tagebuch und Reise
/// benutzen beide diese eine Stelle; zwei Fassungen liefen auseinander, und
/// dann läge ein gesperrter Eintrag in einer der beiden Listen offen da.
struct EintragVerweis: View {
    @ObservedObject var eintrag: Eintrag
    let palette: Palette
    /// Ein privater Eintrag mitten in einem Reisekapitel.
    var nurFuerDich = false

    @ObservedObject private var buecherei = Buecherei.shared
    @State private var entsperren = false

    var body: some View {
        if let name = eintrag.tagebuchName, buecherei.istGesperrt(name) {
            Button { entsperren = true } label: { GesperrteKarte(eintrag: eintrag, name: name) }
                .buttonStyle(.plain)
                .sheet(isPresented: $entsperren) { EntsperrBlatt(name: name) }
        } else {
            NavigationLink {
                EintragView(eintrag: eintrag, palette: palette)
            } label: {
                EintragKarte(eintrag: eintrag, palette: palette)
                    .overlay(alignment: .topTrailing) {
                        if nurFuerDich {
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

/// Was von einem gesperrten Eintrag zu sehen ist: das Tagebuch und die
/// Uhrzeit. Kein Titel, kein Text, kein Foto, kein Ort — der Ort allein
/// erzählt oft schon, worum es ging.
struct GesperrteKarte: View {
    @ObservedObject var eintrag: Eintrag
    let name: String
    @ObservedObject private var buecherei = Buecherei.shared

    var body: some View {
        let farbe = buecherei.buchfarbe(name).farbe
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(farbe.opacity(0.16))
                Image(systemName: "lock.fill").foregroundStyle(farbe)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Gesperrter Eintrag").font(.headline)
                HStack(spacing: 6) {
                    Label(name, systemImage: "book.closed.fill")
                        .fontWeight(.semibold)
                        .foregroundStyle(farbe)
                        .lineLimit(1)
                    if eintrag.datum != nil { Text(eintrag.uhrzeitText) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text("Öffnen")
                .font(.caption.weight(.bold))
                .foregroundStyle(farbe)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .overlay(alignment: .leading) { Rectangle().fill(farbe).frame(width: 5) }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Fragt nach dem Passwort des Tagebuchs \(name)")
    }
}

/// Fragt nach dem Passwort. Darf das Tagebuch mit Face ID auf, wird das beim
/// Öffnen einmal von selbst versucht — das Passwortfeld bleibt daneben stehen.
struct EntsperrBlatt: View {
    let name: String
    var danach: (() -> Void)?

    @ObservedObject private var buecherei = Buecherei.shared
    @Environment(\.dismiss) private var schliessen
    @State private var passwort = ""
    @State private var falsch = false
    @State private var pruefe = false
    @State private var versucht = false
    @FocusState private var fokus: Bool

    private var biometrie: String? { buecherei.darfBiometrie(name) ? Biometrie.name : nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle().fill(buecherei.buchfarbe(name).farbe.opacity(0.16))
                            Image(systemName: "lock.fill")
                                .font(.title)
                                .foregroundStyle(buecherei.buchfarbe(name).farbe)
                        }
                        .frame(width: 64, height: 64)
                        Text(name).font(Stil.titel(22)).multilineTextAlignment(.center)
                        Text("Dieses Tagebuch ist mit einem Passwort geschützt.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
                Section {
                    SecureField("Passwort", text: $passwort)
                        .focused($fokus)
                        .textContentType(.password)
                        .submitLabel(.go)
                        .onSubmit { Task { await pruefen() } }
                    Button {
                        Task { await pruefen() }
                    } label: {
                        HStack {
                            Text("Öffnen")
                            if pruefe { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(passwort.isEmpty || pruefe)
                    if let biometrie {
                        Button {
                            Task { await mitBiometrie() }
                        } label: {
                            Label("Mit \(biometrie) öffnen", systemImage: biometrie == "Touch ID" ? "touchid" : "faceid")
                        }
                    }
                } footer: {
                    if falsch {
                        Text("Das Passwort stimmt nicht.").foregroundStyle(.red)
                    } else {
                        Text("Es bleibt offen, bis du die App verlässt oder es wieder sperrst.")
                    }
                }
            }
            .navigationTitle("Tagebuch öffnen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
            }
            .task {
                guard !versucht else { return }
                versucht = true
                if biometrie != nil { await mitBiometrie() }
                if !buecherei.istGesperrt(name) { return }
                fokus = true
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func pruefen() async {
        guard !passwort.isEmpty, !pruefe else { return }
        pruefe = true
        let richtig = await buecherei.oeffnen(name, passwort: passwort)
        pruefe = false
        if richtig { fertig() } else { falsch = true; passwort = ""; fokus = true }
    }

    private func mitBiometrie() async {
        if await Biometrie.pruefen("Tagebuch „\(name)“ öffnen") {
            buecherei.oeffnen(name)
            fertig()
        }
    }

    private func fertig() {
        schliessen()
        danach?()
    }
}

/// Ein Passwort vergeben oder ändern. Zweimal tippen, und vorher steht da,
/// was dieses Schloss kann und was nicht.
struct SchutzBlatt: View {
    let name: String

    @ObservedObject private var buecherei = Buecherei.shared
    @Environment(\.dismiss) private var schliessen
    @State private var eins = ""
    @State private var zwei = ""
    @State private var biometrie = false
    @State private var laeuft = false

    private var aendern: Bool { buecherei.istGeschuetzt(name) }

    private var hinweis: String? {
        if eins.isEmpty { return nil }
        if eins.count < Kennwort.mindestens { return "Mindestens \(Kennwort.mindestens) Zeichen." }
        if !zwei.isEmpty && zwei != eins { return "Die beiden Eingaben stimmen nicht überein." }
        return nil
    }

    private var gueltig: Bool { eins.count >= Kennwort.mindestens && eins == zwei }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(aendern ? "Neues Passwort" : "Passwort", text: $eins)
                        .textContentType(.newPassword)
                    SecureField("Noch einmal", text: $zwei)
                        .textContentType(.newPassword)
                } footer: {
                    if let hinweis { Text(hinweis).foregroundStyle(.red) }
                }

                if let art = Biometrie.name {
                    Section {
                        Toggle("Auch mit \(art) öffnen", isOn: $biometrie)
                    } footer: {
                        Text("Bequemer — aber dann öffnet auch jedes Gesicht bzw. jeder Finger, der auf diesem Gerät eingerichtet ist. Den Gerätecode lässt das Tagebuch nie gelten.")
                    }
                }

                Section {
                    Label("Das Passwort lässt sich nicht wiederherstellen. Die App kennt es nicht, sie kann nur prüfen, ob es stimmt. Vergisst du es, bleiben die Einträge gesperrt.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Label("Es ist ein Schloss in der App, keine Verschlüsselung: Die Einträge liegen weiter in deiner iCloud wie alle anderen.", systemImage: "lock.shield")
                    Label("Steht ein Eintrag dieses Tagebuchs in einer geteilten Reise, lesen ihn die Miturlauber trotzdem. Das Schloss gilt nur für dich.", systemImage: "person.2")
                    Label("Es gilt auf all deinen Geräten, sobald iCloud es übertragen hat.", systemImage: "icloud")
                }
                .font(.callout)
            }
            .navigationTitle(aendern ? "Passwort ändern" : "Mit Passwort schützen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(aendern ? "Ändern" : "Schützen") {
                        Task {
                            laeuft = true
                            await buecherei.schuetzen(name, passwort: eins, biometrie: biometrie && Biometrie.name != nil)
                            laeuft = false
                            schliessen()
                        }
                    }
                    .disabled(!gueltig || laeuft)
                }
            }
            .onAppear { biometrie = buecherei.darfBiometrie(name) }
        }
    }
}
