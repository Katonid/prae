import SwiftUI

/// Die gesicherten Aufzeichnungen. Ein Tipp führt zur Fahrt; dort lässt sie
/// sich auf die Karte legen, als GPX weitergeben, umbenennen und löschen.
struct FahrtenView: View {
    @EnvironmentObject private var aufzeichner: Aufzeichner
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            List {
                if aufzeichner.fahrten.isEmpty {
                    Text("Noch nichts aufgezeichnet. Der runde Knopf an der Karte startet eine Aufzeichnung.")
                        .foregroundStyle(.secondary)
                }
                ForEach(aufzeichner.fahrten) { f in
                    NavigationLink(value: f) { FahrtZeile(fahrt: f) }
                }
                .onDelete { stellen in
                    for i in stellen { aufzeichner.loeschen(aufzeichner.fahrten[i]) }
                }
            }
            .navigationTitle("Aufzeichnungen")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Fahrt.self) { f in
                FahrtDetailView(fahrt: f) { schliessen() }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schließen") { schliessen() }
                }
            }
        }
    }
}

struct FahrtZeile: View {
    let fahrt: Fahrt

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: fahrt.art.symbol)
                .frame(width: 28)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(fahrt.name).lineLimit(1)
                HStack(spacing: 8) {
                    Text(Anzeige.strecke(fahrt.laengeM))
                    Text(Anzeige.uhr(fahrt.dauerS))
                    if fahrt.ende == nil { Text("unterbrochen").foregroundStyle(.orange) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct FahrtDetailView: View {
    @EnvironmentObject private var aufzeichner: Aufzeichner
    let fahrt: Fahrt
    let zurKarte: () -> Void
    @State private var name = ""
    @State private var gpx: URL?
    @State private var loeschenFragen = false
    @Environment(\.dismiss) private var zurueck

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $name)
                    .onSubmit { aufzeichner.umbenennen(fahrt, name) }
            }
            Section {
                zeile("Strecke", Anzeige.strecke(fahrt.laengeM))
                zeile("Dauer (ohne Pausen)", Anzeige.uhr(fahrt.dauerS))
                if fahrt.dauerS > 60 {
                    zeile("Schnitt", "\(Anzeige.zahl(fahrt.laengeM / fahrt.dauerS * 3.6, stellen: 1)) km/h")
                }
                zeile("Beginn", fahrt.beginn.formatted(date: .abbreviated, time: .shortened))
                if let ende = fahrt.ende {
                    zeile("Ende", ende.formatted(date: .abbreviated, time: .shortened))
                }
                zeile("Messungen", "\(fahrt.messungen), davon \(fahrt.genaue) genau genug")
            } footer: {
                Text("In Strecke und Linie gehen nur Messungen ein, die auf \(Int(Spurrechner.grenzeM)) m oder genauer sind; gezählt wird erst, wenn die Bewegung größer ist als die Messunsicherheit — sonst wüchse die Strecke an jeder Ampel. Die GPX-Datei enthält alle genauen Messungen mit Zeit und Höhe, ungeglättet.")
            }
            Section {
                Button {
                    aufzeichner.zeigen(fahrt)
                    zurKarte()
                } label: {
                    Label("Auf der Karte zeigen", systemImage: "map")
                }
                if let gpx {
                    ShareLink(item: gpx) { Label("Als GPX weitergeben", systemImage: "square.and.arrow.up") }
                }
                Button(role: .destructive) {
                    loeschenFragen = true
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
        }
        .navigationTitle(fahrt.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { name = fahrt.name }
        .onDisappear { if name != fahrt.name { aufzeichner.umbenennen(fahrt, name) } }
        .task { gpx = Fahrtenablage.gpx(fahrt) }
        .confirmationDialog("Diese Aufzeichnung löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                aufzeichner.loeschen(fahrt)
                zurueck()
            }
        }
    }

    private func zeile(_ titel: String, _ wert: String) -> some View {
        HStack {
            Text(titel)
            Spacer()
            Text(wert).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
    }
}
