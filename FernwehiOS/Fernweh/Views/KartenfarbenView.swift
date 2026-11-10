import SwiftUI

/// Die Farben der Linien auf den Karten einstellen (ab 1.0.21, Ansage des
/// Nutzers 09/2026: „Insgesamt möchte ich die Farben auf der Karte einstellen
/// können"). Erreichbar aus den Einstellungen und aus der Vollbildkarte einer
/// Reise. Gilt für dieses Gerät und geht mit der Übergabe ins Fotobuch.
struct KartenfarbenView: View {
    /// Nur für die Vorgabe der Reisespur — sie folgt der Farbe der Reise.
    var palette: Palette = .meer
    @ObservedObject private var farben = Kartenfarben.shared
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(Spurart.allCases) { art in
                        zeile(art)
                    }
                } footer: {
                    Text("Die Reisespur folgt ohne eigene Wahl der Farbe der Reise; die Spuren der Miturlauber stehen in einem helleren Ton daneben. Die Farben gelten auf diesem Gerät und gehen mit „Fürs Fotobuch übergeben“ ins Reisebuch.")
                }
                ebenen
                Section("So sieht es aus") {
                    vorschau
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
            }
            .navigationTitle("Kartenfarben und Ebenen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } }
            }
        }
    }

    // MARK: - Ebenen (ab 1.0.38)

    /// Oben in der Liste = oben auf der Karte. Gespeichert wird unten zuerst.
    private var ebenen: some View {
        Section {
            ForEach(farben.folge.reversed()) { art in
                Label(art.name, systemImage: art.symbol)
                    .foregroundStyle(farben.farbe(art, palette: palette))
            }
            .onMove { von, nach in
                var oben = Array(farben.folge.reversed())
                oben.move(fromOffsets: von, toOffset: nach)
                withAnimation { farben.folgeSetzen(oben.reversed()) }
            }
            Toggle(isOn: Binding(get: { farben.spurZuruecknehmen },
                                 set: { an in withAnimation { farben.zuruecknehmenSetzen(an) } })) {
                Label("Reisespur tritt zurück", systemImage: "square.3.layers.3d.bottom.filled")
            }
            if !farben.folgeIstVorgabe {
                Button("Reihenfolge zurücksetzen") {
                    withAnimation { farben.folgeSetzen(Kartenfarben.folgeVorgabe) }
                }
            }
        } header: {
            HStack {
                Text("Ebenen")
                Spacer()
                EditButton().font(.caption.weight(.semibold)).textCase(nil)
            }
        } footer: {
            Text("Oben in der Liste liegt oben auf der Karte — „Bearbeiten“, dann an den Griffen ziehen. „Reisespur tritt zurück“: Solange eine Autofahrt oder Wanderung läuft, zeichnet das Telefon denselben Weg mit; diese Stücke der Reisespur werden dünn und blass gezeichnet, davor und danach bleibt sie kräftig. Beides gilt auf diesem Gerät und geht mit der Übergabe ins Reisebuch.")
        }
    }

    private func zeile(_ art: Spurart) -> some View {
        HStack {
            ColorPicker(selection: Binding(
                get: { farben.farbe(art, palette: palette) },
                set: { farben.setzen(art, $0) }
            ), supportsOpacity: false) {
                Label(art.name, systemImage: art.symbol)
            }
            if farben.istGewaehlt(art) {
                Button {
                    withAnimation { farben.setzen(art, nil) }
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(art.name): Vorgabe")
            }
        }
    }

    private var vorschau: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(farben.folge.reversed()) { art in
                HStack(spacing: 12) {
                    Capsule()
                        .fill(farben.farbe(art, palette: palette))
                        .frame(width: 70, height: 5)
                        .overlay(Capsule().stroke(.white, lineWidth: 1.5).padding(-1.5))
                        .shadow(color: .black.opacity(0.15), radius: 1)
                    Text(art.name).font(.subheadline)
                }
            }
            if farben.spurZuruecknehmen {
                HStack(spacing: 12) {
                    Capsule()
                        .fill(farben.farbe(.reisespur, palette: palette).opacity(0.4))
                        .frame(width: 70, height: 3)
                    Text("Reisespur während einer Fahrt").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }
}
