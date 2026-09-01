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

    @State private var code = ""
    @State private var name = ""
    @State private var showsScanner = false
    @State private var didPrefill = false

    private var codeFromMDM: Bool { model.suggestedCode != nil }

    var body: some View {
        NavigationStack {
            Form {
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
                         + "die alle in der Leitung sehen — mehr braucht niemand.")
                }

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
                         : "Der Code kommt von der Schulleitung. Er enthält kein I, "
                         + "O, 0 oder 1 — was danach aussieht, ist etwas anderes.")
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
                }

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
            }
        }
    }

    private var canJoin: Bool {
        !model.isWorking
            && InviteCode.normalize(code).count == 6
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

struct JoinView_Previews: PreviewProvider {
    static var previews: some View {
        JoinView().environmentObject(PreviewModels.fresh())
    }
}
