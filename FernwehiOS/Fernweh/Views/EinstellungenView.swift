import SwiftUI
import CloudKit
import Photos

struct EinstellungenView: View {
    @Environment(\.dismiss) private var schliessen
    @EnvironmentObject private var aufzeichner: Aufzeichner
    @EnvironmentObject private var fotodienst: Fotodienst
    @AppStorage("fernweh.eingefuehrt") private var eingefuehrt = true
    @State private var name = Geraet.name
    @State private var konto = "Wird geprüft …"
    @State private var schemaMeldung: String?
    @State private var dayOne = false
    @State private var kartenfarben = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Dein Vorname", text: $name)
                        .onSubmit { Geraet.name = name }
                } header: {
                    Text("Du")
                } footer: {
                    Text("So erscheinen deine Einträge bei den Miturlaubern.")
                }

                Section {
                    Toggle("Reisespur aufzeichnen", isOn: $aufzeichner.eingeschaltet)
                    Zeile(titel: "Ortung", wert: ortung, gut: aufzeichner.hatImmer)
                    if !aufzeichner.hatImmer {
                        Button(aufzeichner.darfOrten ? "Auf „Immer“ umstellen" : "Ortung erlauben") {
                            aufzeichner.erlaubnisAnfragen()
                        }
                    }
                    if aufzeichner.darfOrten && !aufzeichner.genau {
                        Button("Genauen Standort erlauben") { aufzeichner.genauAnfragen() }
                    }
                    if aufzeichner.erlaubnis == .denied {
                        Button("iOS-Einstellungen öffnen") { systemEinstellungen() }
                    }
                    Zeile(titel: "Punkte heute", wert: "\(aufzeichner.punkteHeute)", gut: aufzeichner.punkteHeute > 0)
                } header: {
                    Text("Reisespur")
                } footer: {
                    Text("Aufgezeichnet wird, solange eine Reise läuft. Mit „Immer“ nimmt iOS die Spur auch wieder auf, nachdem die App beendet wurde. Bei Stillstand schaltet die Ortung auf grob, um den Akku zu schonen.")
                }

                Section {
                    Zeile(titel: "Zugriff", wert: fotoStatus, gut: fotodienst.darfLesen)
                    if fotodienst.status == .notDetermined {
                        Button("Fotos erlauben") { Task { await fotodienst.erlaubnisAnfragen() } }
                    } else if !fotodienst.darfLesen {
                        Button("iOS-Einstellungen öffnen") { systemEinstellungen() }
                    }
                    if let a = fotodienst.letzterAbgleich {
                        Zeile(titel: "Bearbeitete Fotos",
                              wert: a.erneuert == 0 ? "aktuell · \(Tag.uhrzeit.string(from: a.zeit))" : "\(a.erneuert) erneuert · \(Tag.uhrzeit.string(from: a.zeit))",
                              gut: true)
                    }
                    Button("Bearbeitete Fotos jetzt abgleichen") { Task { await fotodienst.abgleichen() } }
                } header: {
                    Text("Fotos")
                } footer: {
                    Text("Bearbeitest du ein Foto in der Fotos-App, zeigt das Tagebuch auf deinen Geräten sofort die neue Fassung. Für deine Miturlauber wird die Kopie in der Reise erneuert, sobald Fernweh das nächste Mal geöffnet ist.")
                }

                Section {
                    Button { kartenfarben = true } label: {
                        Label("Kartenfarben …", systemImage: "paintpalette")
                    }
                } header: {
                    Text("Karte")
                } footer: {
                    Text("Die Farben von Reisespur, Wanderungen und Autofahrten auf allen Karten — und im Fotobuch.")
                }

                Section {
                    Button { dayOne = true } label: {
                        Label("Aus Day One übernehmen …", systemImage: "square.and.arrow.down.on.square")
                    }
                } header: {
                    Text("Übernehmen")
                } footer: {
                    Text("Liest den JSON-Export von Day One ein — mit Fotos, Ort, Wetter und der Zeitzone jedes Eintrags. Alles landet privat in deinem Lebenstagebuch.")
                }

                Section {
                    Zeile(titel: "iCloud", wert: konto, gut: konto == "Angemeldet")
                    if let fehler = Persistenz.shared.ladefehler {
                        Text(fehler).font(.caption.monospaced()).foregroundStyle(.red).textSelection(.enabled)
                    }
#if DEBUG
                    Button("CloudKit-Schema anlegen (Entwicklung)") {
                        do {
                            try Persistenz.shared.schemaAnlegen()
                            schemaMeldung = "Schema angelegt. Jetzt in der CloudKit-Konsole „Deploy Schema Changes to Production“."
                        } catch {
                            schemaMeldung = "Fehlgeschlagen: \(error)"
                        }
                    }
                    if let schemaMeldung { Text(schemaMeldung).font(.caption).textSelection(.enabled) }
#endif
                } header: {
                    Text("Abgleich")
                } footer: {
                    Text("Reisen liegen in deiner privaten iCloud. Eine geteilte Reise liegt in der iCloud derjenigen, die sie angelegt hat, und ist nur für die Eingeladenen sichtbar.")
                }

                Section {
                    Button("Einführung noch einmal zeigen") {
                        schliessen()
                        eingefuehrt = false
                    }
                    Zeile(titel: "Fassung", wert: fassung, gut: true)
                }
            }
            .sheet(isPresented: $dayOne) { DayOneView() }
            .sheet(isPresented: $kartenfarben) { KartenfarbenView() }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        Geraet.name = name
                        schliessen()
                    }
                }
            }
            .task { await kontoPruefen() }
        }
    }

    private var ortung: String {
        switch aufzeichner.erlaubnis {
        case .authorizedAlways: return aufzeichner.genau ? "Immer · genau" : "Immer · ungefähr"
        case .authorizedWhenInUse: return "Beim Verwenden"
        case .denied: return "Abgelehnt"
        case .restricted: return "Gesperrt"
        default: return "Noch nicht gefragt"
        }
    }

    private var fotoStatus: String {
        switch fotodienst.status {
        case .authorized: return "Alle Fotos"
        case .limited: return "Ausgewählte Fotos"
        case .denied: return "Abgelehnt"
        case .restricted: return "Gesperrt"
        default: return "Noch nicht gefragt"
        }
    }

    private var fassung: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }

    private func kontoPruefen() async {
        do {
            let status = try await Persistenz.shared.ckContainer.accountStatus()
            switch status {
            case .available: konto = "Angemeldet"
            case .noAccount: konto = "Nicht angemeldet — Reisen bleiben auf diesem Gerät"
            case .restricted: konto = "Eingeschränkt"
            case .temporarilyUnavailable: konto = "Vorübergehend nicht erreichbar"
            default: konto = "Unbekannt"
            }
        } catch {
            konto = "Fehler: \(error.localizedDescription)"
        }
    }

    private func systemEinstellungen() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }

    private struct Zeile: View {
        let titel: String
        let wert: String
        let gut: Bool
        var body: some View {
            HStack {
                Text(titel)
                Spacer()
                Text(wert)
                    .foregroundStyle(gut ? Color.secondary : Color.orange)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
