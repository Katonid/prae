import Photos
import SwiftUI

/// Modus B: alle Fotos chronologisch, gefiltert nach Zeitraum und Standort.
struct BearbeitenAnsicht: View {
    @Environment(AppZustand.self) private var app
    @State private var eigenerZeitraumZeigen = false

    var body: some View {
        @Bindable var modell = app.bearbeiten
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Picker("Filter", selection: $modell.filter) {
                    ForEach(Standortfilter.allCases) { filter in
                        Text(filter.titel).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    zeitraumMenue
                    Spacer()
                    if let liste = modell.liste, !modell.laedt {
                        Text(liste.anzahl == 1 ? "1 Foto" : "\(Formate.zahl(liste.anzahl)) Fotos")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            inhalt
        }
        .navigationTitle("Standorte bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    modell.sortierungUmkehren()
                } label: {
                    Image(systemName: modell.aufsteigend ? "arrow.up" : "arrow.down")
                }
                .accessibilityLabel(modell.aufsteigend ? "Älteste zuerst" : "Neueste zuerst")

                Button {
                    Task { await modell.laden(sitzung: app.sitzung, erzwingen: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Neu laden")
            }
        }
        .task(id: modell.schluessel(app.sitzung)) {
            await modell.laden(sitzung: app.sitzung)
        }
        .sheet(isPresented: $eigenerZeitraumZeigen) {
            EigenerZeitraum(start: modell.zeitraum) { zeitraum in
                modell.eigenerZeitraum = zeitraum
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private var inhalt: some View {
        let modell = app.bearbeiten
        if modell.laedt {
            VStack(spacing: 12) {
                ProgressView(value: modell.fortschritt)
                    .frame(maxWidth: 260)
                Text("Fotos werden geladen … \(Int(modell.fortschritt * 100)) %")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let liste = modell.liste, liste.anzahl > 0 {
            FotoRaster(liste: liste, kennzeichen: kennzeichen) { index in
                app.pfad.append(.editor(.bearbeiten, index))
            }
        } else if modell.liste != nil {
            ContentUnavailableView(
                "Keine Fotos",
                systemImage: "photo.on.rectangle",
                description: Text(leerText)
            )
        } else {
            Color.clear
        }
    }

    private var leerText: String {
        switch app.bearbeiten.filter {
        case .bearbeitet: return "In dieser Sitzung wurden noch keine Standorte geändert."
        case .ohneStandort: return "Im gewählten Zeitraum haben alle Fotos einen Standort."
        case .mitStandort: return "Im gewählten Zeitraum hat kein Foto einen Standort."
        case .alle: return "Im gewählten Zeitraum gibt es keine Fotos."
        }
    }

    private var zeitraumMenue: some View {
        Menu {
            ForEach(Schnellwahl.allCases) { wahl in
                Button {
                    app.bearbeiten.waehlen(wahl)
                } label: {
                    if app.bearbeiten.eigenerZeitraum == nil && app.bearbeiten.schnellwahl == wahl {
                        Label(wahl.titel, systemImage: "checkmark")
                    } else {
                        Text(wahl.titel)
                    }
                }
            }
            Divider()
            Button("Eigener Zeitraum …", systemImage: "calendar") {
                eigenerZeitraumZeigen = true
            }
        } label: {
            Label(app.bearbeiten.zeitraumText, systemImage: "calendar")
                .font(.subheadline.weight(.medium))
        }
    }

    private func kennzeichen(_ asset: PHAsset) -> Kennzeichen {
        var k: Kennzeichen = asset.location == nil ? .ohneStandort : []
        if app.sitzung.ursprung[asset.localIdentifier] != nil { k.insert(.bearbeitet) }
        return k
    }
}

/// Zwei Datumsfelder für einen frei gewählten Zeitraum.
struct EigenerZeitraum: View {
    @Environment(\.dismiss) private var schliessen
    @State private var von: Date
    @State private var bis: Date
    let uebernehmen: (Zeitraum) -> Void

    init(start: Zeitraum?, uebernehmen: @escaping (Zeitraum) -> Void) {
        let z = start ?? Schnellwahl.monat.zeitraum() ?? Zeitraum(von: Date(), bis: Date())
        _von = State(initialValue: z.von)
        _bis = State(initialValue: z.bis)
        self.uebernehmen = uebernehmen
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Von", selection: $von, in: ...bis, displayedComponents: .date)
                    DatePicker("Bis", selection: $bis, in: von..., displayedComponents: .date)
                } footer: {
                    Text("Maßgeblich ist das Aufnahmedatum. Beide Tage sind eingeschlossen.")
                }
            }
            .navigationTitle("Zeitraum")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        uebernehmen(Zeitraum(von: von, bis: bis))
                        schliessen()
                    }
                }
            }
        }
    }
}
