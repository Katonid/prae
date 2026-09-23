import SwiftUI

/// Die Liste der Fahrzeuge und Gangarten. Ein Tipp wählt, der Regler
/// bearbeitet.
struct ProfileView: View {
    @EnvironmentObject private var planer: Planer
    @Environment(\.dismiss) private var schliessen
    @State private var zuruecksetzenFragen = false

    @State private var pfad: [UUID] = []

    var body: some View {
        NavigationStack(path: $pfad) {
            List {
                Section {
                    ForEach(planer.profile) { p in
                        // Zwei Knöpfe in einer Zeile: beide randlos, sonst
                        // löst ein Tipp auf die Zeile BEIDE aus.
                        HStack {
                            Button {
                                planer.profilID = p.id
                                schliessen()
                            } label: {
                                HStack {
                                    Image(systemName: p.symbol).frame(width: 28)
                                    VStack(alignment: .leading) {
                                        Text(p.name).foregroundStyle(.primary)
                                        Text(kurzbeschreibung(p)).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if p.id == planer.profilID {
                                        Image(systemName: "checkmark").foregroundStyle(.tint)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            Button {
                                pfad.append(p.id)
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .padding(.leading, 8)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("\(p.name) bearbeiten")
                        }
                    }
                    .onDelete { stellen in
                        guard planer.profile.count > stellen.count else { return }
                        planer.profile.remove(atOffsets: stellen)
                        if !planer.profile.contains(where: { $0.id == planer.profilID }) {
                            planer.profilID = planer.profile[0].id
                        }
                    }
                } footer: {
                    Text("Tippen wählt das Profil, der Regler rechts öffnet seine Einstellungen. Wischen löscht (eines bleibt immer).")
                }
                Section {
                    Menu {
                        ForEach(Fortbewegung.allCases) { art in
                            Button {
                                planer.profile.append(Fahrzeugprofil(name: "Neu: \(art.name)", art: art))
                            } label: {
                                Label(art.name, systemImage: art.symbol)
                            }
                        }
                    } label: {
                        Label("Neues Profil", systemImage: "plus")
                    }
                    Button("Vorlagen wieder hinzufügen") { zuruecksetzenFragen = true }
                }
            }
            .navigationTitle("Profile")
            .navigationDestination(for: UUID.self) { id in
                if let i = planer.profile.firstIndex(where: { $0.id == id }) {
                    ProfilEditor(profil: $planer.profile[i])
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } }
            }
            .confirmationDialog("Die vier Vorlagen (Zu Fuß, Fahrrad, Pkw, Pkw mit Wohnwagen) werden hinten angefügt. Eigene Profile bleiben.",
                                isPresented: $zuruecksetzenFragen, titleVisibility: .visible) {
                Button("Hinzufügen") {
                    planer.profile += Fahrzeugprofil.vorlagen.map { var v = $0; v.id = UUID(); return v }
                }
            }
        }
    }

    private func kurzbeschreibung(_ p: Fahrzeugprofil) -> String {
        switch p.art {
        case .zuFuss:
            return "\(Anzeige.zahl(p.gehTempo, stellen: 1)) km/h"
        case .fahrrad:
            return "kürzester Weg, \(Int(p.radTempo)) km/h" + (p.schieben ? ", Schieben erlaubt" : ", ohne Schieben")
        case .auto:
            var teile: [String] = []
            if let h = p.hoeheM { teile.append("Höhe \(Anzeige.zahl(h)) m") }
            if let b = p.breiteM { teile.append("Breite \(Anzeige.zahl(b)) m") }
            if p.mitAnhaenger { teile.append(p.tempo100 ? "Anhänger, Tempo 100" : "Anhänger, 80 km/h") }
            if let t = p.hoechsttempo { teile.append("max. \(Int(t)) km/h") }
            return teile.isEmpty ? "ohne Einschränkungen" : teile.joined(separator: ", ")
        }
    }
}

struct ProfilEditor: View {
    @Binding var profil: Fahrzeugprofil

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $profil.name)
                Picker("Art", selection: $profil.art) {
                    ForEach(Fortbewegung.allCases) { Label($0.name, systemImage: $0.symbol).tag($0) }
                }
            }
            switch profil.art {
            case .auto: autoFelder
            case .fahrrad: radFelder
            case .zuFuss: fussFelder
            }
        }
        .navigationTitle(profil.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var autoFelder: some View {
        Section {
            Massfeld(titel: "Höhe", wert: $profil.hoeheM, einheit: "m")
            Massfeld(titel: "Breite", wert: $profil.breiteM, einheit: "m")
        } header: {
            Text("Maße")
        } footer: {
            Text("Leer lassen heißt: nicht beachten. Beim Gespann die GRÖSSTE Höhe und Breite eintragen, meist die des Wohnwagens. Berücksichtigt wird, was in OpenStreetMap als Durchfahrtshöhe oder -breite eingetragen ist; eine Unterführung ohne Eintrag gilt als frei.")
        }
        Section {
            Toggle("Mit Anhänger", isOn: $profil.mitAnhaenger)
            if profil.mitAnhaenger {
                Toggle("Tempo-100-Zulassung", isOn: $profil.tempo100)
            }
            Massfeld(titel: "Eigenes Höchsttempo", wert: $profil.hoechsttempo, einheit: "km/h")
        } header: {
            Text("Tempo")
        } footer: {
            Text("Mit Anhänger: außerorts 80 km/h, Autobahn 80 oder mit Tempo-100-Zulassung 100 km/h (Regeln in Deutschland). Das eigene Höchsttempo gilt zusätzlich, z. B. für ein Wohnmobil.")
        }
        Section {
            Stepper(value: $profil.innerortsAufschlag, in: 0...60, step: 5) {
                LabeledContent("Innerorts langsamer", value: "\(Int(profil.innerortsAufschlag)) %")
            }
            Stepper(value: $profil.abbiegeAufschlag, in: 0...30, step: 1) {
                LabeledContent("Je Abbiegen", value: "+\(Int(profil.abbiegeAufschlag)) s")
            }
        } header: {
            Text("Anfahren")
        } footer: {
            Text("Ein schweres Gespann braucht beim Anfahren länger. Beide Zahlen sind geschätzt, nicht gemessen — wer sie für sein Fahrzeug besser weiß, trägt sie hier ein. Sie gehen nur in die Fahrzeit ein, nicht in die Wahl der Strecke.")
        }
    }

    @ViewBuilder private var radFelder: some View {
        Section {
            Toggle("Schieben erlauben", isOn: $profil.schieben)
        } footer: {
            Text("Erlaubt heißt: Gehwege und Fußgängerzonen ohne Radfreigabe dürfen schiebend benutzt werden, wenn der Weg dadurch kürzer wird. Sie stehen dann gestrichelt orange auf der Karte. Autobahnen, Kraftfahrstraßen und Wege mit Radverbot sind immer ausgeschlossen.")
        }
        Section("Tempo") {
            Stepper(value: $profil.radTempo, in: 8...40, step: 1) {
                LabeledContent("Fahren", value: "\(Int(profil.radTempo)) km/h")
            }
            Stepper(value: $profil.schiebeTempo, in: 2...7, step: 0.5) {
                LabeledContent("Schieben", value: "\(Anzeige.zahl(profil.schiebeTempo, stellen: 1)) km/h")
            }
        }
    }

    @ViewBuilder private var fussFelder: some View {
        Section {
            Stepper(value: $profil.gehTempo, in: 2...7, step: 0.5) {
                LabeledContent("Gehtempo", value: "\(Anzeige.zahl(profil.gehTempo, stellen: 1)) km/h")
            }
        } footer: {
            Text("Wer Treppen meidet oder ein Kind an der Hand hat, geht langsamer.")
        }
    }
}

/// Ein Zahlenfeld für einen Wert, der auch fehlen darf.
struct Massfeld: View {
    let titel: String
    @Binding var wert: Double?
    let einheit: String

    var body: some View {
        LabeledContent(titel) {
            HStack(spacing: 4) {
                TextField("—", value: $wert, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                Text(einheit).foregroundStyle(.secondary)
            }
        }
    }
}
