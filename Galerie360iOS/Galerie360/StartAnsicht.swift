import SwiftUI
import UniformTypeIdentifiers

/// Startseite: Speicherort und die Galerien darin.
struct StartAnsicht: View {
    @Environment(Bibliothek.self) private var bibliothek
    @State private var ordnerWaehlen = false
    @State private var neuFragen = false
    @State private var neuerTitel = ""
    @State private var offen: Galerie?
    @State private var passwortFuer: PasswortAnfrage?
    @State private var meldung: String?

    var body: some View {
        NavigationStack {
            Group {
                if bibliothek.wurzel == nil { willkommen } else { liste }
            }
            .navigationTitle("Galerie 360")
            .toolbar {
                if bibliothek.wurzel != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button { neuerTitel = ""; neuFragen = true } label: { Label("Neue Galerie", systemImage: "plus") }
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Menu {
                            Button { ordnerWaehlen = true } label: { Label("Anderen Ordner wählen …", systemImage: "folder") }
                            Button { bibliothek.aufDiesemGeraet() } label: { Label("Auf diesem Gerät speichern", systemImage: "iphone") }
                        } label: { Label("Speicherort", systemImage: "externaldrive") }
                    }
                }
            }
            .refreshable { await bibliothek.aktualisieren() }
        }
        .fileImporter(isPresented: $ordnerWaehlen, allowedContentTypes: [.folder]) { ergebnis in
            if case .success(let url) = ergebnis { bibliothek.ordnerGewaehlt(url) }
        }
        .alert("Neue Galerie", isPresented: $neuFragen) {
            TextField("Name, z. B. Berchtesgaden 2026", text: $neuerTitel)
            Button("Abbrechen", role: .cancel) {}
            Button("Anlegen") { neueGalerie() }
        } message: {
            Text("Die Galerie wird als Ordner in „\(bibliothek.ortName)“ angelegt.")
        }
        .alert("Hinweis", isPresented: Binding(get: { meldung != nil }, set: { if !$0 { meldung = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(meldung ?? "") }
        .sheet(item: $passwortFuer) { anfrage in
            PasswortAnsicht(anfrage: anfrage) { galerie in
                passwortFuer = nil
                offen = galerie
            }
        }
        .fullScreenCover(item: $offen, onDismiss: { Task { await bibliothek.aktualisieren() } }) { g in
            GalerieAnsicht(galerie: g) { g.jetztSpeichern(); offen = nil }
        }
        .task { await bibliothek.aktualisieren() }
    }

    private var willkommen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "globe.europe.africa")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                Text("Deine 360°-Fotos und -Videos, ringsum ansehen.")
                    .font(.title2.bold())
                Text("Wähle zuerst, wo die Galerien liegen sollen. Am besten ein Ordner in **iCloud Drive** — dann sind sie auf allen Geräten da und gesichert. Galerien aus der Web-App Galerie 360 (auch entpackte Sicherungen) in diesem Ordner erscheinen hier ebenfalls.")
                    .foregroundStyle(.secondary)
                Button { ordnerWaehlen = true } label: {
                    Label("Ordner wählen (z. B. iCloud Drive) …", systemImage: "icloud")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button { bibliothek.aufDiesemGeraet() } label: {
                    Label("Nur auf diesem Gerät speichern", systemImage: "iphone")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                Text("Tipp: In der Dateien-App unter iCloud Drive einen Ordner „Galerie 360“ anlegen und diesen wählen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    private var liste: some View {
        List {
            Section {
                if bibliothek.eintraege.isEmpty && !bibliothek.laedt {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Noch keine Galerie hier.").font(.headline)
                        Text("Mit + eine neue anlegen. Oder eine Sicherung (ZIP) aus der Web-App in der Dateien-App in diesen Ordner legen und dort antippen — sie wird entpackt und erscheint dann hier.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                ForEach(bibliothek.eintraege) { e in
                    Button { oeffnen(e) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: e.geschuetzt ? "lock.fill" : "photo.stack")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.titel).font(.headline).foregroundStyle(.primary)
                                if e.geschuetzt {
                                    Text(Schluesselbund.holen(e.konto) == nil ? "Mit Passwort geschützt" : "Geschützt · auf diesem Gerät angemeldet")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                    }
                    .contextMenu {
                        if e.geschuetzt && Schluesselbund.holen(e.konto) != nil {
                            Button { Schluesselbund.vergessen(e.konto); Task { await bibliothek.aktualisieren() } } label: {
                                Label("Auf diesem Gerät abmelden", systemImage: "lock")
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Label(bibliothek.ortName, systemImage: bibliothek.ortName == "Auf diesem Gerät" ? "iphone" : "folder")
                    if bibliothek.laedt { ProgressView().controlSize(.mini) }
                }
            } footer: {
                Text("Galerie 360 · Fassung \(App.fassung)")
            }
        }
    }

    private func oeffnen(_ e: GalerieEintrag) {
        Task {
            do {
                let ergebnis = try await Task.detached(priority: .userInitiated) { try Bibliothek.oeffnen(e) }.value
                switch ergebnis {
                case .offen(let g): offen = g
                case .passwortNoetig(let huelle): passwortFuer = PasswortAnfrage(eintrag: e, huelle: huelle)
                }
            } catch {
                meldung = "„\(e.titel)“ lässt sich nicht öffnen: \(error.localizedDescription)"
            }
        }
    }

    private func neueGalerie() {
        let t = neuerTitel.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        do {
            let ordner = try bibliothek.neueGalerie(titel: t)
            Task {
                await bibliothek.aktualisieren()
                if let e = bibliothek.eintraege.first(where: { $0.ordner.standardizedFileURL == ordner.standardizedFileURL }) { oeffnen(e) }
            }
        } catch {
            meldung = "Die Galerie ließ sich nicht anlegen: \(error.localizedDescription)"
        }
    }
}

struct PasswortAnfrage: Identifiable {
    let eintrag: GalerieEintrag
    let huelle: JSONObjekt
    var id: URL { eintrag.ordner }
}

/// Passwort für eine geschützte Galerie — mit „Auf diesem Gerät angemeldet bleiben".
struct PasswortAnsicht: View {
    let anfrage: PasswortAnfrage
    let geoeffnet: (Galerie) -> Void
    @Environment(\.dismiss) private var schliessen
    @State private var passwort = ""
    @State private var merken = true
    @State private var fehler = ""
    @State private var pruefe = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Passwort", text: $passwort)
                        .textContentType(.password)
                        .onSubmit(oeffnen)
                    Toggle("Auf diesem Gerät angemeldet bleiben", isOn: $merken)
                } footer: {
                    Text(fehler.isEmpty ? "Gemerkt wird nicht das Passwort, sondern ein daraus berechneter Schlüssel im Schlüsselbund dieses Geräts." : fehler)
                        .foregroundStyle(fehler.isEmpty ? Color.secondary : Color.red)
                }
            }
            .navigationTitle(anfrage.eintrag.titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    if pruefe { ProgressView() } else { Button("Öffnen", action: oeffnen).disabled(passwort.isEmpty) }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func oeffnen() {
        guard !passwort.isEmpty, !pruefe else { return }
        pruefe = true
        fehler = ""
        let pw = passwort, huelle = anfrage.huelle, e = anfrage.eintrag, behalten = merken
        Task {
            do {
                let (klar, s) = try await Task.detached(priority: .userInitiated) { try Krypto.entschluesseln(huelle, passwort: pw) }.value
                guard let p = try JSONSerialization.jsonObject(with: klar) as? JSONObjekt else { throw KryptoFehler.kaputt }
                if behalten { Schluesselbund.merken(s, fuer: e.konto) } else { Schluesselbund.vergessen(e.konto) }
                geoeffnet(Galerie(ordner: e.ordner, daten: p, schluessel: s))
            } catch {
                fehler = error.localizedDescription
                pruefe = false
            }
        }
    }
}
