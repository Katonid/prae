import SwiftUI
import UniformTypeIdentifiers

/// Einrichtung des Pass-Type-ID-Zertifikats und Anleitung.
struct SettingsView: View {
    @EnvironmentObject private var certStore: CertStore
    @Environment(\.dismiss) private var dismiss

    @State private var showsImporter = false
    @State private var pendingP12: Data?
    @State private var password = ""
    @State private var showsPasswordPrompt = false
    @State private var message: String?
    @State private var messageIsError = false

    var body: some View {
        NavigationStack {
            Form {
                certSection
                wwdrSection
                howToSection
                privacySection
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showsImporter,
                allowedContentTypes: [UTType.pkcs12, UTType.data],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .alert("Passwort der .p12-Datei", isPresented: $showsPasswordPrompt) {
                SecureField("Passwort", text: $password)
                Button("Importieren") { importPending() }
                Button("Abbrechen", role: .cancel) {
                    pendingP12 = nil
                    password = ""
                }
            } message: {
                Text("Das Passwort, das du beim Export der Datei vergeben hast.")
            }
            .task {
                await certStore.ensureWWDR()
            }
        }
    }

    private var certSection: some View {
        Section("Pass-Zertifikat") {
            if let meta = certStore.meta {
                LabeledContent("Zertifikat", value: meta.commonName)
                LabeledContent("Pass-Type-ID", value: meta.passTypeIdentifier)
                LabeledContent("Team-ID", value: meta.teamIdentifier)
                LabeledContent("Organisation", value: meta.organizationName)
                Button("Zertifikat entfernen", role: .destructive) {
                    certStore.removeCertificate()
                    message = nil
                }
            } else {
                Text("Noch kein Zertifikat eingerichtet. Ohne Pass-Type-ID-Zertifikat kann Apple Wallet keine Pässe von dir annehmen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button {
                showsImporter = true
            } label: {
                Label(certStore.meta == nil ? "Zertifikat (.p12) importieren" : "Anderes Zertifikat importieren",
                      systemImage: "key.fill")
            }
            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(messageIsError ? .red : .green)
            }
        }
    }

    private var wwdrSection: some View {
        Section("Apple-Zwischenzertifikat (WWDR)") {
            HStack {
                Image(systemName: certStore.wwdrAvailable ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                    .foregroundStyle(certStore.wwdrAvailable ? .green : .orange)
                Text(certStore.wwdrAvailable
                     ? "Vorhanden — Pässe können vollständig signiert werden."
                     : "Wird bei Internetverbindung automatisch von Apple geladen.")
                    .font(.footnote)
            }
            if !certStore.wwdrAvailable {
                Button("Jetzt laden") {
                    Task { await certStore.ensureWWDR() }
                }
            }
        }
    }

    private var howToSection: some View {
        Section("So bekommst du das Zertifikat (einmalig)") {
            VStack(alignment: .leading, spacing: 10) {
                step(1, "Apple-Developer-Konto: Du brauchst eine Mitgliedschaft im Apple Developer Program (developer.apple.com).")
                step(2, "Unter „Certificates, Identifiers & Profiles“ → „Identifiers“ eine neue Pass Type ID anlegen, z. B. pass.de.familie.kartenwallet.")
                step(3, "Für diese Pass Type ID ein Zertifikat erstellen (Certificate Signing Request kommt aus der Schlüsselbundverwaltung am Mac).")
                step(4, "Das erstellte Zertifikat am Mac in die Schlüsselbundverwaltung laden, dort Zertifikat samt privatem Schlüssel auswählen und als .p12 mit Passwort exportieren.")
                step(5, "Die .p12-Datei z. B. über iCloud Drive oder AirDrop aufs iPhone bringen und hier importieren. Fertig — alle Pässe werden ab jetzt direkt auf dem Gerät signiert.")
            }
            .padding(.vertical, 4)
        }
    }

    private var privacySection: some View {
        Section("Datenschutz") {
            Text("Alle Karten, Fotos und das Zertifikat bleiben ausschließlich auf diesem Gerät (Zertifikat im Schlüsselbund). Es gibt keinen Server; nur das öffentliche Apple-Zwischenzertifikat wird einmalig von apple.com geladen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.footnote.bold())
                .frame(width: 22, height: 22)
                .background(.tint.opacity(0.15), in: Circle())
            Text(text)
                .font(.footnote)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            message = error.localizedDescription
            messageIsError = true
        case .success(let urls):
            guard let url = urls.first else { return }
            let secured = url.startAccessingSecurityScopedResource()
            defer { if secured { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                message = "Die Datei konnte nicht gelesen werden."
                messageIsError = true
                return
            }
            pendingP12 = data
            password = ""
            showsPasswordPrompt = true
        }
    }

    private func importPending() {
        guard let data = pendingP12 else { return }
        do {
            try certStore.importP12(data: data, password: password)
            message = "Zertifikat erfolgreich eingerichtet."
            messageIsError = false
        } catch {
            message = error.localizedDescription
            messageIsError = true
        }
        pendingP12 = nil
        password = ""
    }
}
