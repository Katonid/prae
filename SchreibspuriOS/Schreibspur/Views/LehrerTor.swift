import SwiftUI

/// Tür zum Lehrerbereich (Klassenübersicht, Einstellungen). Löst die
/// Malaufgabe von 1.0.2 ab — die hielt nur Schulanfänger auf.
///
/// Beim ersten Mal wird ein Code festgelegt, danach mit Code oder Face ID
/// geöffnet. Geht die App in den Hintergrund, schließt sich der Bereich
/// wieder: Am Klassen-iPad soll das nächste Kind ihn nicht offen vorfinden.
struct LehrerTor<Inhalt: View>: View {
    private let titel: String
    private let inhalt: () -> Inhalt

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var szene
    @AppStorage(Lehrerzugang.biometrieSchluessel) private var mitBiometrie = false

    @State private var offen = false
    @State private var modus: Modus = Lehrerzugang.eingerichtet ? .anmelden : .einrichten
    @State private var code = ""
    @State private var wiederholung = ""
    @State private var meldung: String?
    @State private var jetzt = Date()
    @FocusState private var fokus: Bool

    private enum Modus { case einrichten, anmelden, neuerCode }

    init(titel: String = "Lehrerbereich", @ViewBuilder inhalt: @escaping () -> Inhalt) {
        self.titel = titel
        self.inhalt = inhalt
    }

    var body: some View {
        Group {
            if offen {
                inhalt()
            } else {
                NavigationStack {
                    Form { formular }
                        .navigationTitle(titel)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Abbrechen") { dismiss() }
                            }
                        }
                }
            }
        }
        .onChange(of: szene) { _, neu in
            if neu == .background { dismiss() }
        }
        .task {
            if modus == .anmelden, mitBiometrie, Lehrerzugang.biometrieName != nil, Lehrerzugang.gesperrtBis == nil {
                await biometrischOeffnen()
            }
        }
    }

    @ViewBuilder private var formular: some View {
        switch modus {
        case .einrichten, .neuerCode:
            Section {
                SecureField("Neuer Code", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.newPassword)
                    .focused($fokus)
                SecureField("Code wiederholen", text: $wiederholung)
                    .keyboardType(.numberPad)
                    .textContentType(.newPassword)
                if let name = Lehrerzugang.biometrieName {
                    Toggle("Auch mit \(name) öffnen", isOn: $mitBiometrie)
                }
                Button("Code festlegen", action: festlegen)
                    .disabled(code.count < Lehrerzugang.mindestLaenge)
            } header: {
                Text(modus == .einrichten ? "Lehrerbereich einrichten" : "Neuen Code festlegen")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let meldung { Text(meldung).foregroundStyle(.red) }
                    Text("Der Code schützt Klassenübersicht und Einstellungen. Mindestens \(Lehrerzugang.mindestLaenge) Ziffern — besser sechs. Gespeichert wird nur ein verschlüsselter Prüfwert auf diesem Gerät.")
                    Text("Code vergessen? Dann lässt sich mit Face ID bzw. dem Gerätecode dieses iPads ein neuer festlegen.")
                }
            }
            .onAppear { fokus = true }

        case .anmelden:
            Section {
                SecureField("Code", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.password)
                    .focused($fokus)
                    .onSubmit(anmelden)
                    .disabled(gesperrt != nil)
                Button("Öffnen", action: anmelden)
                    .disabled(code.isEmpty || gesperrt != nil)
                if mitBiometrie, let name = Lehrerzugang.biometrieName {
                    Button {
                        Task { await biometrischOeffnen() }
                    } label: {
                        Label("Mit \(name) öffnen", systemImage: name == "Touch ID" ? "touchid" : "faceid")
                    }
                }
            } header: {
                Text("Code des Lehrerbereichs")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if let bis = gesperrt {
                        Text("Zu viele falsche Versuche — gesperrt bis \(bis.formatted(date: .omitted, time: .standard)).")
                            .foregroundStyle(.red)
                    } else if let meldung {
                        Text(meldung).foregroundStyle(.red)
                    }
                }
            }
            .onAppear { fokus = !mitBiometrie }

            Section {
                Button("Code vergessen?") { Task { await vergessen() } }
            } footer: {
                if !Lehrerzugang.geraetecodeVorhanden {
                    Text("Dieses iPad hat keinen Gerätecode. Dann lässt sich der Code nur zurücksetzen, indem die App gelöscht und neu geladen wird — dabei gehen alle Kinder und Aufzeichnungen verloren.")
                }
            }
            // Sperrzeit ablaufen lassen, ohne dass jemand tippen muss.
            .task(id: gesperrt) {
                guard let bis = gesperrt else { return }
                try? await Task.sleep(for: .seconds(max(1, bis.timeIntervalSinceNow)))
                jetzt = Date()
            }
        }
    }

    private var gesperrt: Date? {
        _ = jetzt
        return Lehrerzugang.gesperrtBis
    }

    private func festlegen() {
        guard code.allSatisfy(\.isNumber), code.count >= Lehrerzugang.mindestLaenge else {
            meldung = "Bitte mindestens \(Lehrerzugang.mindestLaenge) Ziffern."
            return
        }
        guard code == wiederholung else {
            meldung = "Die beiden Eingaben sind verschieden."
            wiederholung = ""
            return
        }
        Lehrerzugang.festlegen(code)
        oeffnen()
    }

    private func anmelden() {
        if Lehrerzugang.pruefen(code) {
            oeffnen()
        } else {
            meldung = "Der Code stimmt nicht."
            code = ""
            jetzt = Date()
        }
    }

    private func biometrischOeffnen() async {
        if await Lehrerzugang.biometrisch() { oeffnen() }
    }

    private func vergessen() async {
        guard await Lehrerzugang.geraetebesitzer() else { return }
        code = ""
        wiederholung = ""
        meldung = nil
        modus = .neuerCode
    }

    private func oeffnen() {
        code = ""
        wiederholung = ""
        meldung = nil
        withAnimation { offen = true }
    }
}

/// Code des Lehrerbereichs ändern (in den Einstellungen).
struct CodeAendern: View {
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var wiederholung = ""
    @State private var meldung: String?

    var body: some View {
        Form {
            Section {
                SecureField("Neuer Code", text: $code).keyboardType(.numberPad)
                SecureField("Code wiederholen", text: $wiederholung).keyboardType(.numberPad)
                Button("Speichern") {
                    if !code.allSatisfy(\.isNumber) || code.count < Lehrerzugang.mindestLaenge {
                        meldung = "Bitte mindestens \(Lehrerzugang.mindestLaenge) Ziffern."
                    } else if code != wiederholung {
                        meldung = "Die beiden Eingaben sind verschieden."
                    } else {
                        Lehrerzugang.festlegen(code)
                        dismiss()
                    }
                }
            } footer: {
                if let meldung { Text(meldung).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Code ändern")
    }
}
