import SwiftUI

/// Wird gezeigt, solange weder ein Zugangsschluessel noch der
/// Beispielmodus eingerichtet ist.
struct Willkommenssicht: View {
    @EnvironmentObject private var daten: Datenhaltung
    @State private var eingabe = ""
    @State private var meldung: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                kopf
                schritte
                eingabefeld
                beispielknopf
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var kopf: some View {
        VStack(spacing: 10) {
            Image(systemName: "soccerball")
                .font(.system(size: 46))
                .foregroundStyle(Gestaltung.rasen)
            Text("Alle fuenf grossen Ligen")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Bundesliga, Premier League, La Liga, Serie A und Ligue 1 — Spieltage, Tabellen und ein Liveticker.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    private var schritte: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Einmal einrichten")
                .font(.headline)
            schritt(1, "Kostenlosen Zugang bei football-data.org anlegen — Name und E-Mail genuegen.")
            schritt(2, "Der Schluessel kommt per E-Mail. Er ist kostenlos und deckt genau diese fuenf Ligen ab.")
            schritt(3, "Schluessel unten einsetzen. Er bleibt im Schluesselbund des Geraets.")
            Link(destination: URL(string: "https://www.football-data.org/client/register")!) {
                Label("Zugang anlegen", systemImage: "arrow.up.right.square")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Gestaltung.ecke))
    }

    private func schritt(_ nummer: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(nummer)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Gestaltung.rasen, in: Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var eingabefeld: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Zugangsschluessel")
                .font(.headline)
            TextField("z. B. 8a4c1f…", text: $eingabe)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.monospaced())
            if let meldung {
                Text(meldung)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Button {
                sichern()
            } label: {
                Text("Schluessel sichern")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Gestaltung.rasen)
            .disabled(eingabe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Gestaltung.ecke))
    }

    private var beispielknopf: some View {
        VStack(spacing: 8) {
            Text("Erst einmal ansehen?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                daten.beispielmodus = true
            } label: {
                Label("Mit Beispieldaten starten", systemImage: "eye")
            }
            .buttonStyle(.bordered)
            Text("Beispieldaten sind erfunden und klar gekennzeichnet.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 20)
    }

    private func sichern() {
        let sauber = eingabe.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sauber.count >= 8 else {
            meldung = "Der Schluessel wirkt zu kurz. Bitte vollstaendig einsetzen."
            return
        }
        meldung = nil
        daten.schluesselSetzen(sauber)
        eingabe = ""
    }
}
