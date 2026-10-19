import SwiftUI

struct CameraEditView: View {
    @Environment(CameraStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State var camera: Camera
    let isNew: Bool

    @State private var showPassword = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $camera.name)
                }

                Section {
                    Picker("Protokoll", selection: $camera.scheme) {
                        Text("rtsp").tag("rtsp")
                        Text("rtsps").tag("rtsps")
                    }
                    LabeledContent("Host/IP") {
                        TextField("192.168.0.10", text: $camera.host)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    LabeledContent("Port") {
                        TextField("554", value: $camera.port, format: .number.grouping(.never))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                    LabeledContent("Pfad") {
                        TextField("/stream1", text: $camera.path)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("Adresse")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Verbindung über \(camera.displayURL)")
                        HStack {
                            Text("Tapo:")
                            Button("HD (/stream1)") { camera.path = "/stream1" }
                            Button("SD (/stream2)") { camera.path = "/stream2" }
                        }
                        .font(.footnote)
                    }
                }

                Section("Anmeldung") {
                    Toggle("Aktiv", isOn: $camera.loginEnabled)
                    if camera.loginEnabled {
                        LabeledContent("Benutzer") {
                            TextField("Benutzername", text: $camera.username)
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textContentType(.username)
                        }
                        LabeledContent("Passwort") {
                            HStack {
                                Group {
                                    if showPassword {
                                        TextField("Passwort", text: $camera.password)
                                    } else {
                                        SecureField("Passwort", text: $camera.password)
                                    }
                                }
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                                Button { showPassword.toggle() } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }

                Section("Bild") {
                    Toggle("Horizontal spiegeln", isOn: $camera.mirrorHorizontal)
                    Toggle("Vertikal spiegeln", isOn: $camera.mirrorVertical)
                    Toggle("Bildschirm füllen", isOn: $camera.fillScreen)
                }

                Section {
                    Toggle("RTSP über TCP", isOn: $camera.forceTCP)
                    Stepper(value: $camera.networkCaching, in: 0...3000, step: 100) {
                        LabeledContent("Puffer", value: "\(camera.networkCaching) ms")
                    }
                } header: {
                    Text("Erweitert")
                } footer: {
                    Text("Weniger Puffer = weniger Verzögerung. Ruckelt das Bild, den Puffer erhöhen.")
                }

                if !isNew {
                    Section {
                        Button {
                            _ = store.duplicate(camera)
                            dismiss()
                        } label: {
                            Label("Kamera duplizieren", systemImage: "plus.square.on.square")
                        }
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("Kamera löschen", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Neue Kamera" : camera.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        store.save(camera)
                        dismiss()
                    }
                    .disabled(!camera.isValid)
                }
            }
            .confirmationDialog("„\(camera.name)“ löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    Thumbnails.delete(for: camera.id)
                    store.delete(camera)
                    dismiss()
                }
            }
        }
    }
}
