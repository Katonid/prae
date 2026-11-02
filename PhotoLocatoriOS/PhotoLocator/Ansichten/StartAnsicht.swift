import SwiftUI

struct StartAnsicht: View {
    @Environment(AppZustand.self) private var app
    @State private var verlaufLoeschenFragen = false
    @State private var laedtFortsetzung = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if app.zugriff.eingeschraenkt {
                    EingeschraenktHinweis()
                }

                if let sitzung = app.sitzung.laufend, sitzung.offen > 0, !sitzung.ids.isEmpty {
                    fortsetzenKarte(sitzung)
                }

                NavigationLink(value: Ziel.ergaenzen) {
                    ModusKarte(
                        titel: "Fehlende Standorte ergänzen",
                        text: "Fotos ohne GPS-Angabe in einem Zeitraum finden und der Reihe nach verorten.",
                        symbol: "mappin.slash",
                        farbe: .orange
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(value: Ziel.bearbeiten) {
                    ModusKarte(
                        titel: "Standorte bearbeiten",
                        text: "Alle Fotos durchsehen, vorhandene Standorte verschieben, ergänzen oder entfernen.",
                        symbol: "map",
                        farbe: .blue
                    )
                }
                .buttonStyle(.plain)

                if !app.sitzung.verlauf.isEmpty {
                    Label(
                        "\(Formate.zahl(app.sitzung.verlauf.count)) Änderungen gespeichert – rückgängig machbar in der Bearbeitung",
                        systemImage: "clock.arrow.circlepath"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("Änderungen werden direkt in deiner Fotomediathek gespeichert. Es entstehen keine Kopien; Bild, Aufnahmedatum und übrige Angaben bleiben unverändert.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("PhotoLocator")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if app.zugriff.eingeschraenkt {
                        Button("Freigegebene Fotos ändern", systemImage: "photo.badge.plus") {
                            app.zugriff.auswahlAendern()
                        }
                    }
                    Button("Einstellungen öffnen", systemImage: "gear") {
                        app.zugriff.einstellungenOeffnen()
                    }
                    Button("Bearbeitungsverlauf löschen", systemImage: "trash", role: .destructive) {
                        verlaufLoeschenFragen = true
                    }
                    .disabled(app.sitzung.verlauf.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Weitere Optionen")
            }
        }
        .confirmationDialog("Bearbeitungsverlauf löschen?", isPresented: $verlaufLoeschenFragen, titleVisibility: .visible) {
            Button("Verlauf löschen", role: .destructive) { app.sitzung.verlaufLoeschen() }
        } message: {
            Text("Die gespeicherten Standorte bleiben in den Fotos. Gelöschte Einträge lassen sich danach aber nicht mehr rückgängig machen.")
        }
    }

    private func fortsetzenKarte(_ sitzung: ErgaenzenSitzung) -> some View {
        Button {
            Task { await fortsetzen() }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white, .green)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Bearbeitung fortsetzen")
                        .font(.headline)
                    Text("\(Fortschritt.rest(offen: sitzung.offen)) von \(Formate.zahl(sitzung.ids.count))")
                        .font(.subheadline)
                    Text(sitzung.zeitraumText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ProgressView(value: Double(sitzung.ids.count - sitzung.offen), total: Double(max(sitzung.ids.count, 1)))
                        .tint(.green)
                }
                Spacer(minLength: 0)
                if laedtFortsetzung {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(laedtFortsetzung)
    }

    private func fortsetzen() async {
        laedtFortsetzung = true
        defer { laedtFortsetzung = false }
        if let index = await app.ergaenzen.fortsetzen(sitzung: app.sitzung),
           let liste = app.ergaenzen.liste, liste.anzahl > 0 {
            app.pfad = [.ergaenzen, .editor(.ergaenzen, index)]
        } else {
            app.pfad = [.ergaenzen]
        }
    }
}

private struct ModusKarte: View {
    let titel: String
    let text: String
    let symbol: String
    let farbe: Color

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(farbe.gradient, in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 6) {
                Text(titel)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }
}

/// Hinweis bei eingeschränktem Zugriff („Ausgewählte Fotos“).
struct EingeschraenktHinweis: View {
    @Environment(AppZustand.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Eingeschränkter Zugriff", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("PhotoLocator sieht nur die Fotos, die du freigegeben hast. Alle anderen werden weder durchsucht noch angezeigt.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Auswahl ändern") { app.zugriff.auswahlAendern() }
                    .buttonStyle(.bordered)
                Button("Vollen Zugriff erlauben") { app.zugriff.einstellungenOeffnen() }
                    .buttonStyle(.bordered)
            }
            .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}
