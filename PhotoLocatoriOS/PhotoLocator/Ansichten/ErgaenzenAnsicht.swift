import Photos
import SwiftUI

/// Modus A: Zeitraum wählen → durchsuchen → Übersicht → Bearbeitung.
struct ErgaenzenAnsicht: View {
    @Environment(AppZustand.self) private var app
    @State private var ersetzenFragen = false

    var body: some View {
        let modell = app.ergaenzen
        Group {
            switch modell.phase {
            case .auswahl:
                ZeitraumAuswahl(ersetzenFragen: $ersetzenFragen)
            case .suche:
                suchFortschritt
            case .ergebnis:
                ErgebnisAnsicht()
            }
        }
        .navigationTitle("Fehlende Standorte")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Nach einem Neustart direkt die gespeicherte Sitzung zeigen.
            if modell.phase == .auswahl, modell.liste == nil, app.sitzung.laufend != nil {
                _ = await modell.fortsetzen(sitzung: app.sitzung)
            }
        }
        .confirmationDialog("Laufende Bearbeitung ersetzen?", isPresented: $ersetzenFragen, titleVisibility: .visible) {
            Button("Neu durchsuchen", role: .destructive) {
                modell.suchen(sitzung: app.sitzung)
            }
        } message: {
            Text("Der Fortschritt der bisherigen Sitzung wird verworfen. Bereits gespeicherte Standorte bleiben in den Fotos erhalten.")
        }
    }

    private var suchFortschritt: some View {
        VStack(spacing: 20) {
            ProgressView(value: app.ergaenzen.fortschritt)
                .progressViewStyle(.linear)
                .frame(maxWidth: 320)
            Text("Fotos werden durchsucht … \(Int(app.ergaenzen.fortschritt * 100)) %")
                .font(.headline)
                .monospacedDigit()
            Text("Geprüft wird jedes Foto im Zeitraum. Bei großen Mediatheken kann das einige Sekunden dauern.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Button("Abbrechen", role: .cancel) { app.ergaenzen.abbrechen() }
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Schritt 1: Zeitraum.
private struct ZeitraumAuswahl: View {
    @Environment(AppZustand.self) private var app
    @Binding var ersetzenFragen: Bool

    var body: some View {
        @Bindable var modell = app.ergaenzen
        Form {
            if let sitzung = app.sitzung.laufend, sitzung.offen > 0 {
                Section("Laufende Bearbeitung") {
                    Button {
                        Task { _ = await modell.fortsetzen(sitzung: app.sitzung) }
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Fortsetzen – \(Fortschritt.rest(offen: sitzung.offen))")
                                Text(sitzung.zeitraumText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "play.circle.fill")
                        }
                    }
                }
            }

            Section("Schnellauswahl") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                    ForEach(Schnellwahl.allCases) { wahl in
                        Button {
                            modell.waehlen(wahl)
                        } label: {
                            Text(wahl.titel)
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.bordered)
                        .tint(modell.schnellwahl == wahl ? .accentColor : .secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                DatePicker("Von", selection: $modell.von, in: ...modell.bis, displayedComponents: .date)
                DatePicker("Bis", selection: $modell.bis, in: modell.von..., displayedComponents: .date)
            } header: {
                Text("Zeitraum (Aufnahmedatum)")
            } footer: {
                if modell.schnellwahl == .alles {
                    Text("„Gesamter Bestand“ ist gewählt – das Datum wird nicht berücksichtigt.")
                }
            }
            .disabled(modell.schnellwahl == .alles)
            .onChange(of: modell.von) { _, _ in eigenerZeitraumPruefen() }
            .onChange(of: modell.bis) { _, _ in eigenerZeitraumPruefen() }

            Section {
                Button {
                    if let s = app.sitzung.laufend, s.offen > 0, s.ids.count > 0 {
                        ersetzenFragen = true
                    } else {
                        modell.suchen(sitzung: app.sitzung)
                    }
                } label: {
                    Label("Fotos ohne Standort suchen", systemImage: "magnifyingglass")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                Text("Durchsucht werden alle Fotos (keine Videos), deren Aufnahmedatum im Zeitraum liegt. Gefunden werden nur Fotos ohne GPS-Standort.")
            }

            if app.zugriff.eingeschraenkt {
                Section {
                    EingeschraenktHinweis()
                        .listRowInsets(EdgeInsets())
                }
            }
        }
    }

    /// Weicht das Datum von der Schnellwahl ab, gilt es als eigener Zeitraum.
    private func eigenerZeitraumPruefen() {
        let modell = app.ergaenzen
        guard let wahl = modell.schnellwahl, wahl != .alles, let z = wahl.zeitraum() else { return }
        if Zeitraum(von: modell.von, bis: modell.bis) != z {
            modell.schnellwahl = nil
        }
    }
}

/// Schritt 2/3: Ergebnis der Suche und Übersicht.
private struct ErgebnisAnsicht: View {
    @Environment(AppZustand.self) private var app

    var body: some View {
        let modell = app.ergaenzen
        Group {
            if modell.laedt {
                ProgressView("Sitzung wird geladen …")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let liste = modell.liste, let sitzung = app.sitzung.laufend {
                VStack(spacing: 0) {
                    Kennzahlen(sitzung: sitzung)
                    Divider()
                    if liste.anzahl == 0 {
                        ContentUnavailableView(
                            "Keine Fotos ohne Standort",
                            systemImage: "checkmark.seal",
                            description: Text("Im Zeitraum „\(sitzung.zeitraumText)“ hat jedes Foto bereits einen Standort.")
                        )
                    } else {
                        FotoRaster(liste: liste, kennzeichen: kennzeichen) { index in
                            app.pfad.append(.editor(.ergaenzen, index))
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if liste.anzahl > 0 {
                        Button {
                            app.pfad.append(.editor(.ergaenzen, modell.startIndex(sitzung: app.sitzung)))
                        } label: {
                            Label(
                                sitzung.offen == 0 ? "Fotos ansehen" : "Bearbeiten – \(Fortschritt.rest(offen: sitzung.offen))",
                                systemImage: "mappin.and.ellipse"
                            )
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.bar)
                    }
                }
            } else {
                ContentUnavailableView("Keine Sitzung", systemImage: "tray")
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    modell.sortierungUmkehren(sitzung: app.sitzung)
                } label: {
                    Image(systemName: (app.sitzung.laufend?.aufsteigend ?? true) ? "arrow.up" : "arrow.down")
                }
                .accessibilityLabel((app.sitzung.laufend?.aufsteigend ?? true) ? "Älteste zuerst" : "Neueste zuerst")
                .disabled(modell.liste == nil)

                Menu {
                    Button("Neue Suche", systemImage: "magnifyingglass") {
                        modell.neueAuswahl()
                    }
                    Button("Sitzung beenden", systemImage: "xmark.circle", role: .destructive) {
                        modell.verwerfen(sitzung: app.sitzung)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func kennzeichen(_ asset: PHAsset) -> Kennzeichen {
        switch app.sitzung.status(asset.localIdentifier) {
        case .erledigt: return .erledigt
        case .uebersprungen: return .uebersprungen
        default: return asset.location == nil ? .ohneStandort : []
        }
    }
}

private struct Kennzahlen: View {
    let sitzung: ErgaenzenSitzung

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                zahl(sitzung.untersucht, "untersucht", farbe: .primary)
                zahl(sitzung.ohneStandort, "ohne Standort", farbe: .red)
                zahl(sitzung.offen, "noch offen", farbe: .orange)
            }
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text(sitzung.zeitraumText)
                if sitzung.nichtAenderbar > 0 {
                    Text("· \(sitzung.nichtAenderbar) nicht änderbar")
                }
                if !sitzung.uebersprungen.isEmpty {
                    Text("· \(sitzung.uebersprungen.count) übersprungen")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
    }

    private func zahl(_ wert: Int, _ titel: String, farbe: Color) -> some View {
        VStack(spacing: 2) {
            Text(Formate.zahl(wert))
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(farbe)
            Text(titel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
