import SwiftUI

/// Zugangsschlüssel, Beispielmodus und Auskunft über die Herkunft der
/// Daten.
struct Einstellungssicht: View {
    @EnvironmentObject private var daten: Datenhaltung
    @State private var eingabe = ""
    @State private var loeschfrage = false

    var body: some View {
        NavigationStack {
            Form {
                zugang
                anzeige
                herkunft
                ueber
            }
            .navigationTitle("Einstellungen")
        }
    }

    // MARK: Zugang

    private var zugang: some View {
        Section {
            if daten.schluesselVorhanden {
                HStack {
                    Label("Schlüssel hinterlegt", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Gestaltung.rasen)
                    Spacer()
                    Text(verdeckt)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Button(role: .destructive) {
                    loeschfrage = true
                } label: {
                    Label("Schlüssel entfernen", systemImage: "trash")
                }
            } else {
                Text("Ohne Schlüssel zeigt die App nur Beispieldaten.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            TextField(daten.schluesselVorhanden ? "Neuen Schlüssel einsetzen" : "Zugangsschlüssel", text: $eingabe)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.monospaced())

            Button("Schlüssel sichern") {
                daten.schluesselSetzen(eingabe)
                eingabe = ""
            }
            .disabled(eingabe.trimmingCharacters(in: .whitespacesAndNewlines).count < 8)

            Link(destination: URL(string: "https://www.football-data.org/client/register")!) {
                Label("Kostenlosen Zugang anlegen", systemImage: "arrow.up.right.square")
            }
        } header: {
            Text("Zugang zu football-data.org")
        } footer: {
            Text("Der freie Zugang erlaubt zehn Abfragen je Minute. Die App hält sich daran und frischt laufende Spiele etwa alle 45 Sekunden auf.")
        }
        .alert("Schlüssel entfernen?", isPresented: $loeschfrage) {
            Button("Entfernen", role: .destructive) { daten.schluesselLoeschen() }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Danach zeigt die App keine echten Ergebnisse mehr.")
        }
    }

    private var verdeckt: String {
        let text = daten.schluessel
        guard text.count > 6 else { return String(repeating: "•", count: max(text.count, 4)) }
        return String(text.prefix(4)) + String(repeating: "•", count: 6) + String(text.suffix(2))
    }

    // MARK: Anzeige

    private var anzeige: some View {
        Section {
            Toggle(isOn: Binding(get: { daten.beispielmodus },
                                 set: { daten.beispielmodus = $0 })) {
                Label("Beispieldaten", systemImage: "eye")
            }
            .tint(Gestaltung.rasen)
        } header: {
            Text("Anzeige")
        } footer: {
            Text("Beispieldaten sind erfunden. Sie zeigen, wie Spieltage, Tabelle und Ticker aussehen — ohne Zugang und ohne Netz.")
        }
    }

    // MARK: Herkunft

    private var herkunft: some View {
        Section {
            ForEach(Liga.allCases) { liga in
                HStack {
                    Text(liga.flagge)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(liga.name)
                            .font(.subheadline)
                        Text("\(liga.land) · \(liga.spieltage) Spieltage")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let tag = daten.laufenderSpieltag[liga] {
                        Text("\(tag).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Ligen")
        }
    }

    // MARK: Über

    private var ueber: some View {
        Section {
            HStack {
                Text("Fassung")
                Spacer()
                Text(fassung)
                    .foregroundStyle(.secondary)
            }
            Link(destination: URL(string: "https://www.football-data.org")!) {
                Label("Daten von football-data.org", systemImage: "globe")
            }
        } header: {
            Text("Über die App")
        } footer: {
            Text("Anstoß speichert nichts außer dem Zugangsschlüssel und den zuletzt gesehenen Meldungen — beides bleibt auf dem Gerät.")
        }
    }

    private var fassung: String {
        let nummer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let bau = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(nummer) (\(bau))"
    }
}
