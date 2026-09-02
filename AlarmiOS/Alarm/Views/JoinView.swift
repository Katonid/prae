//  JoinView.swift
//  The first screen on a fresh iPad.
//
//  Three ways in, in the order they should be tried:
//
//  1. Managed App Configuration. If Jamf School delivered a code with the app,
//     the only question left is the handle. Thirty iPads, thirty times not
//     typing a code, thirty times not mistyping it.
//  2. QR code — the code is on the beamer in the staff meeting.
//  3. Typed by hand. The fallback that always works, and the one that has to
//     tolerate a code read aloud across a room.

import SwiftUI

struct JoinView: View {

    @EnvironmentObject private var model: AppModel

    /// Which of the two ways in the person is taking.
    ///
    /// A segmented control and not a hidden link: exactly one person per
    /// school takes the left path, and everybody else takes the right one —
    /// but that one person must find theirs on the first try, because until
    /// they do, nobody else can get in at all.
    private enum Weg: String, CaseIterable {
        case beitreten
        case anlegen

        var titel: String {
            switch self {
            case .beitreten: return "Beitreten"
            case .anlegen: return "Schule einrichten"
            }
        }
    }

    @State private var weg = Weg.beitreten
    @State private var code = ""
    @State private var name = ""
    @State private var schule = ""
    @State private var showsScanner = false
    @State private var didPrefill = false

    private var codeFromMDM: Bool { model.suggestedCode != nil }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Weg", selection: $weg) {
                    ForEach(Weg.allCases, id: \.self) { Text($0.titel).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if let school = model.managedConfiguration.schoolName {
                    Section {
                        Label(school, systemImage: "building.columns")
                            .font(.headline)
                    } header: {
                        Text("Von der Geräteverwaltung vorgegeben")
                    }
                }

                Section {
                    TextField("Kürzel, z. B. MÜ oder Kl. 3b", text: $name)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    Text("Dein Kürzel")
                } footer: {
                    Text("Kein voller Name. Das Kürzel steht in den Rückmeldungen, "
                         + "die die Admins sehen — mehr braucht niemand.")
                }

                if weg == .anlegen { anlegen } else { beitreten }

                if !model.availability.isReady {
                    Section {
                        Text(model.availability.explanation)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Anmelden")
            .sheet(isPresented: $showsScanner) {
                NavigationStack {
                    QRScannerView { value in
                        code = InviteCode.normalize(value)
                        showsScanner = false
                    }
                    .ignoresSafeArea()
                    .navigationTitle("Code scannen")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") { showsScanner = false }
                        }
                    }
                }
            }
            .task {
                guard !didPrefill else { return }
                didPrefill = true
                code = model.suggestedCode ?? code
                name = model.suggestedName ?? name
                // Hat die Geräteverwaltung einen Code mitgegeben, ist die
                // Schule längst eingerichtet — dann darf der Anlege-Weg nicht
                // als Erstes zu sehen sein.
                if codeFromMDM { weg = .beitreten }
            }
        }
    }

    /// Der Weg für alle anderen: Kürzel und Code.
    @ViewBuilder
    private var beitreten: some View {
        Section {
            TextField("6-stelliger Code", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(.title2, design: .monospaced))
                .disabled(codeFromMDM)
            if !codeFromMDM {
                Button {
                    showsScanner = true
                } label: {
                    Label("Code scannen", systemImage: "qrcode.viewfinder")
                }
            }
        } header: {
            Text("Beitrittscode")
        } footer: {
            Text(codeFromMDM
                 ? "Der Code kam mit der App von der Geräteverwaltung."
                 : "Der Code kommt von einem Admin. Er enthält kein I, O, 0 "
                 + "oder 1 — was danach aussieht, ist etwas anderes.")
        }

        Section {
            Button {
                Task { _ = await model.join(code: code, displayName: name) }
            } label: {
                if model.isWorking {
                    ProgressView()
                } else {
                    Text("Beitreten").fontWeight(.semibold)
                }
            }
            .disabled(!canJoin)
        } footer: {
            Text("Noch keine Schule eingerichtet? Dann oben auf "
                 + "„Schule einrichten“ wechseln — das macht eine Person, einmal.")
        }
    }

    /// Der Weg für die eine Person, die anfängt.
    @ViewBuilder
    private var anlegen: some View {
        Section {
            TextField("Name der Schule", text: $schule)
        } header: {
            Text("Schule")
        } footer: {
            Text("Diesen Namen sehen alle im Kollegium oben auf dem Startbildschirm.")
        }

        Section {
            Button {
                Task { _ = await model.createGroup(name: schule, displayName: name) }
            } label: {
                if model.isWorking {
                    ProgressView()
                } else {
                    Text("Schule einrichten und Admin werden").fontWeight(.semibold)
                }
            }
            .disabled(!canCreate)
        } footer: {
            Text("Das macht genau EINE Person je Schule. Du wirst damit der "
                 + "erste Admin: Du vergibst die Beitrittscodes, pflegst Standorte und "
                 + "Handlungstexte und darfst Entwarnung geben. Den Code für das "
                 + "Kollegium bekommst du gleich danach angezeigt.\n\nRichtet eine "
                 + "zweite Person noch einmal eine Schule ein, entsteht ein "
                 + "zweiter, getrennter Alarmkreis — die beiden sehen einander "
                 + "nicht.")
        }
    }

    private var canJoin: Bool {
        !model.isWorking
            && InviteCode.normalize(code).count == 6
            && hatKuerzel
    }

    private var canCreate: Bool {
        !model.isWorking
            && hatKuerzel
            && !schule.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hatKuerzel: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

struct JoinView_Previews: PreviewProvider {
    static var previews: some View {
        JoinView().environmentObject(PreviewModels.fresh())
    }
}
