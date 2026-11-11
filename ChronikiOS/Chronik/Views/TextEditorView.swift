import SwiftUI

struct TextEditorView: View {
    @Binding var buch: Buch
    let id: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var ueberarbeiten = false
    @State private var loeschenFragen = false

    var body: some View {
        let eintrag = Bindungen.text($buch, id)
        NavigationStack {
            Form {
                Section {
                    TextField("Überschrift (freiwillig)", text: eintrag.titel)
                        .font(.headline)
                    DatePicker("Zeitpunkt", selection: eintrag.zeit, displayedComponents: [.date, .hourAndMinute])
                } footer: {
                    Text("Der Zeitpunkt bestimmt Kapitel und Platz im Buch — jetzt: „\(kapitelname(eintrag.wrappedValue.zeit))“.")
                }

                Section("Text") {
                    TextEditor(text: eintrag.text)
                        .frame(minHeight: 260)
                }

                Section {
                    Button {
                        ueberarbeiten = true
                    } label: {
                        Label("Sprachlich überarbeiten …", systemImage: "wand.and.stars")
                    }
                    .disabled(eintrag.wrappedValue.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let alt = eintrag.wrappedValue.vorfassung {
                        Button {
                            let jetzt = eintrag.wrappedValue.text
                            eintrag.wrappedValue.text = alt
                            eintrag.wrappedValue.vorfassung = jetzt
                        } label: {
                            Label("Zur anderen Fassung wechseln", systemImage: "arrow.uturn.backward")
                        }
                    }
                } header: {
                    Text("Sprache")
                } footer: {
                    Text(eintrag.wrappedValue.vorfassung == nil
                         ? "Die Überarbeitung schlägt eine neue Fassung vor; übernommen wird erst auf Wunsch. Ab iOS 18.1 gibt es außerdem Apples Schreibtools: Text markieren → „Schreibtools“."
                         : "Die Fassung vor der letzten Überarbeitung ist aufgehoben und lässt sich jederzeit zurückholen.")
                }

                Section {
                    Button("Text löschen", role: .destructive) { loeschenFragen = true }
                }
            }
            .navigationTitle(eintrag.wrappedValue.titel.isEmpty ? "Text" : eintrag.wrappedValue.titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(isPresented: $ueberarbeiten) {
                UeberarbeitenView(text: eintrag.wrappedValue.text) { neu in
                    let alt = eintrag.wrappedValue.text
                    eintrag.wrappedValue.vorfassung = alt
                    eintrag.wrappedValue.text = neu
                }
            }
            .confirmationDialog("Diesen Text löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    buch.texte.removeAll { $0.id == id }
                    dismiss()
                }
            }
            .onDisappear {
                // Ein neuer Text, in den nichts geschrieben wurde, bleibt nicht liegen.
                if let t = buch.texte.first(where: { $0.id == id }),
                   t.titel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   t.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    buch.texte.removeAll { $0.id == id }
                }
            }
        }
    }

    private func kapitelname(_ zeit: Date) -> String {
        buch.kapitelTitel(buch.raster.kapitel(buch.raster.index(fuer: zeit)))
    }
}

struct UeberarbeitenView: View {
    let text: String
    var uebernehmen: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var art: Sprachhilfe.Art = .glaetten
    @State private var vorschlag = ""
    @State private var laeuft = false
    @State private var fehler: String?
    @State private var kopiert = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Art", selection: $art) {
                        ForEach(Sprachhilfe.Art.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Art der Überarbeitung")
                } footer: {
                    Text(art.beschreibung)
                }

                if Sprachhilfe.aufDemGeraet {
                    Section {
                        Button {
                            starten()
                        } label: {
                            HStack {
                                Label("Auf dem Gerät überarbeiten", systemImage: "wand.and.stars")
                                if laeuft {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(laeuft)
                    } footer: {
                        Text("Mit Apple Intelligence auf diesem Gerät — der Text verlässt es nicht.")
                    }
                } else if let grund = Sprachhilfe.grundOhneGeraet {
                    Section {
                        Text(grund).font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        UIPasteboard.general.string = Sprachhilfe.auftrag(text, art: art)
                        kopiert = true
                    } label: {
                        Label(kopiert ? "Auftrag kopiert ✓" : "Auftrag für einen KI-Chat kopieren", systemImage: "doc.on.doc")
                    }
                    Button {
                        if let s = UIPasteboard.general.string { vorschlag = Sprachhilfe.bereinigen(s) }
                    } label: {
                        Label("Antwort aus der Zwischenablage einsetzen", systemImage: "doc.on.clipboard")
                    }
                } header: {
                    Text("Über einen KI-Chat")
                } footer: {
                    Text("Kopiert Anweisung und Text. In einer KI-App (z. B. ChatGPT oder Claude) einfügen, die Antwort kopieren und hier einsetzen.")
                }

                if let fehler {
                    Section {
                        Text(fehler).foregroundStyle(.red)
                    }
                }

                Section("Vorschlag") {
                    if vorschlag.isEmpty {
                        Text("Noch kein Vorschlag.").foregroundStyle(.secondary)
                    }
                    TextEditor(text: $vorschlag)
                        .frame(minHeight: 200)
                }

                Section("Bisher") {
                    Text(text)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("Überarbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        uebernehmen(vorschlag.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(vorschlag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vorschlag == text)
                }
            }
        }
    }

    private func starten() {
        laeuft = true
        fehler = nil
        let t = text
        let a = art
        Task { @MainActor in
            do {
                vorschlag = try await Sprachhilfe.ueberarbeiten(t, art: a)
            } catch {
                fehler = "Die Überarbeitung ist fehlgeschlagen: \(error.localizedDescription)"
            }
            laeuft = false
        }
    }
}
