import SwiftUI

/// Startseite: Zugriff auf die Fotos-Mediathek und die Galerien darin.
struct StartAnsicht: View {
    @Environment(FotoBibliothek.self) private var bibliothek
    @Environment(\.openURL) private var oeffnen
    @State private var neuFragen = false
    @State private var neuerTitel = ""
    @State private var offen: GalerieInfo?
    @State private var meldung: String?

    var body: some View {
        NavigationStack {
            Group {
                switch bibliothek.zugriff {
                case .erlaubt, .eingeschraenkt: liste
                case .verweigert: verweigert
                case .unbekannt: willkommen
                }
            }
            .navigationTitle("Galerie 360")
            .toolbar {
                if bibliothek.zugriff == .erlaubt || bibliothek.zugriff == .eingeschraenkt {
                    ToolbarItem(placement: .primaryAction) {
                        Button { neuerTitel = ""; neuFragen = true } label: { Label("Neue Galerie", systemImage: "plus") }
                    }
                }
            }
        }
        .alert("Neue Galerie", isPresented: $neuFragen) {
            TextField("Name, z. B. Berchtesgaden 2026", text: $neuerTitel)
            Button("Abbrechen", role: .cancel) {}
            Button("Anlegen") { anlegen() }
        } message: {
            Text("Die Galerie wird ein Ordner in der Fotos-App unter Alben › Galerie 360.")
        }
        .alert("Hinweis", isPresented: Binding(get: { meldung != nil }, set: { if !$0 { meldung = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(meldung ?? "") }
        .fullScreenCover(item: $offen) { g in
            GalerieAnsicht(galerie: g) { offen = nil }
        }
    }

    private var willkommen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "globe.europe.africa")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                Text("Deine 360°-Fotos und -Videos, ringsum ansehen.")
                    .font(.title2.bold())
                Text("Galerie 360 arbeitet direkt mit deiner **Fotos-Mediathek** (iCloud Fotos). Galerien und Alben sind Ordner und Alben in der Fotos-App, die Aufnahmen bleiben, wo sie sind — die App legt keine Kopien an.")
                    .foregroundStyle(.secondary)
                Button {
                    Task { await bibliothek.zugriffAnfragen() }
                } label: {
                    Label("Zugriff auf Fotos erlauben", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Text("Bitte „Vollzugriff“ wählen: Die App liest deine Aufnahmen und legt Alben an, löscht aber nie ein Foto oder Video.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    private var verweigert: some View {
        ContentUnavailableView {
            Label("Kein Zugriff auf Fotos", systemImage: "lock")
        } description: {
            Text("Galerie 360 zeigt deine Aufnahmen aus der Fotos-Mediathek. Bitte in den Einstellungen unter Galerie 360 › Fotos „Vollzugriff“ erlauben.")
        } actions: {
            Button("Einstellungen öffnen") {
                if let url = URL(string: UIApplication.openSettingsURLString) { oeffnen(url) }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var liste: some View {
        List {
            if bibliothek.zugriff == .eingeschraenkt {
                Section {
                    Label("Nur ausgewählte Fotos freigegeben. Für eigene Alben braucht die App Vollzugriff.", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                    Button("In den Einstellungen ändern") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { oeffnen(url) }
                    }
                }
            }
            Section {
                if bibliothek.galerien.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Noch keine Galerie.").font(.headline)
                        Text("Mit + eine anlegen. Sie erscheint in der Fotos-App unter Alben › Galerie 360; darin legst du Alben an und fügst Aufnahmen aus deiner Mediathek hinzu.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                ForEach(bibliothek.galerien) { g in
                    Button { offen = g } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "photo.stack")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 32)
                            Text(g.titel).font(.headline).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            } header: {
                Label("Fotos › Alben › Galerie 360", systemImage: "photo.on.rectangle")
            } footer: {
                Text("Fotos und Videos bleiben in deiner Mediathek (iCloud Fotos); die App speichert keine Kopien. Galerie 360 · Fassung \(AppInfo.fassung)")
            }
        }
        .refreshable { bibliothek.aktualisieren() }
    }

    private func anlegen() {
        let t = neuerTitel.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        Task {
            do {
                if let id = try await bibliothek.galerieAnlegen(t) {
                    offen = GalerieInfo(id: id, titel: t)
                }
            } catch {
                meldung = "Die Galerie ließ sich nicht anlegen: \(error.localizedDescription)"
            }
        }
    }
}

enum AppInfo {
    static var fassung: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?" }
}
