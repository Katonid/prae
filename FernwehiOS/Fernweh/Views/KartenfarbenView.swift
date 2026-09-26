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
                Section("So sieht es aus") {
                    vorschau
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
            }
            .navigationTitle("Kartenfarben")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } }
            }
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
            ForEach(Spurart.allCases) { art in
                HStack(spacing: 12) {
                    Capsule()
                        .fill(farben.farbe(art, palette: palette))
                        .frame(width: 70, height: 5)
                        .overlay(Capsule().stroke(.white, lineWidth: 1.5).padding(-1.5))
                        .shadow(color: .black.opacity(0.15), radius: 1)
                    Text(art.name).font(.subheadline)
                }
            }
        }
    }
}
