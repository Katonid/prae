import Photos
import SwiftUI

/// Wählt nach dem Stand der Fotoberechtigung, was zu sehen ist.
struct WurzelAnsicht: View {
    @Environment(AppZustand.self) private var app
    @Environment(\.scenePhase) private var szenenphase

    var body: some View {
        @Bindable var app = app
        Group {
            switch app.zugriff.status {
            case .authorized, .limited:
                NavigationStack(path: $app.pfad) {
                    StartAnsicht()
                        .navigationDestination(for: Ziel.self) { ziel in
                            zielAnsicht(ziel)
                        }
                }
            case .notDetermined:
                BerechtigungsAnsicht()
            default:
                ZugriffVerweigertAnsicht()
            }
        }
        // Berechtigung kann sich in den Einstellungen geändert haben.
        .onChange(of: szenenphase) { _, neu in
            if neu == .active { app.zugriff.aktualisieren() }
        }
    }

    @ViewBuilder
    private func zielAnsicht(_ ziel: Ziel) -> some View {
        switch ziel {
        case .ergaenzen:
            ErgaenzenAnsicht()
        case .bearbeiten:
            BearbeitenAnsicht()
        case .editor(let art, let index):
            if let liste = app.liste(fuer: art), liste.anzahl > 0 {
                BearbeitungsAnsicht(liste: liste, sitzung: app.sitzung, index: index)
            } else {
                ContentUnavailableView("Keine Fotos geladen", systemImage: "photo.on.rectangle")
            }
        }
    }
}

/// Erster Start: erklärt, wozu der Zugriff nötig ist, und fragt danach.
struct BerechtigungsAnsicht: View {
    @Environment(AppZustand.self) private var app

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)

                Text("Zugriff auf deine Fotos")
                    .font(.largeTitle.bold())

                Text("PhotoLocator ergänzt und korrigiert die Aufnahmeorte deiner Fotos – direkt in deiner Fotomediathek.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 16) {
                    Punkt(symbol: "eye", text: "Die App liest Aufnahmedatum, Standort und eine Vorschau deiner Fotos.")
                    Punkt(symbol: "mappin.and.ellipse", text: "Sie ändert ausschließlich den Standort – und nur, wenn du auf „Speichern“ tippst.")
                    Punkt(symbol: "doc.on.doc", text: "Es entstehen keine Kopien. Bildqualität, Aufnahmedatum und alle anderen Angaben bleiben unverändert.")
                    Punkt(symbol: "lock.shield", text: "Keine Anmeldung, keine Cloud. Nur die Kartensuche fragt bei Apple Karten nach.")
                }

                Text("Wähle im nächsten Schritt „Vollen Zugriff erlauben“, damit alle Fotos durchsucht werden können. Mit „Zugriff beschränken“ sieht die App nur die Fotos, die du auswählst.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await app.zugriff.anfordern() }
                } label: {
                    Text("Weiter")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }

    private struct Punkt: View {
        let symbol: String
        let text: String

        var body: some View {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 30)
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Zugriff verweigert oder durch Bildschirmzeit/Profil gesperrt.
struct ZugriffVerweigertAnsicht: View {
    @Environment(AppZustand.self) private var app

    var body: some View {
        ContentUnavailableView {
            Label("Kein Zugriff auf Fotos", systemImage: "lock.slash")
        } description: {
            if app.zugriff.status == .restricted {
                Text("Der Zugriff auf die Fotomediathek ist auf diesem Gerät eingeschränkt (z. B. durch Bildschirmzeit oder ein Verwaltungsprofil). PhotoLocator kann deshalb keine Fotos anzeigen oder ändern.")
            } else {
                Text("Du hast PhotoLocator den Zugriff auf deine Fotos nicht erlaubt. Ohne Zugriff kann die App keine Standorte lesen oder ändern.\n\nÖffne die Einstellungen und wähle unter „Fotos“ die Option „Voller Zugriff“.")
            }
        } actions: {
            if app.zugriff.status != .restricted {
                Button("Einstellungen öffnen") { app.zugriff.einstellungenOeffnen() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
