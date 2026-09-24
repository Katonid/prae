import SwiftUI
import PhotosUI

/// Eine Reise anlegen oder ändern.
struct ReiseFormular: View {
    let reise: Reise?
    var fertig: (Reise?) -> Void = { _ in }

    @Environment(\.dismiss) private var schliessen
    @EnvironmentObject private var aufzeichner: Aufzeichner

    @State private var titel = ""
    @State private var untertitel = ""
    @State private var emoji = "✈️"
    @State private var beginn = Tag.anfang(Date())
    @State private var hatEnde = true
    @State private var ende = Tag.anfang(Date()).addingTimeInterval(6 * 86_400)
    @State private var palette: Palette = .sonne
    @State private var titelbild: Data?
    @State private var bildWahl: PhotosPickerItem?
    @State private var aufzeichnen = true
    @State private var geladen = false

    private let symbole = ["✈️", "🏖️", "🏔️", "🚗", "🚆", "⛺️", "🛳️", "🚲", "🌋", "🏝️", "🗺️", "🌸"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VorschauKarte(titel: titel, emoji: emoji, palette: palette, bild: titelbild,
                                  zeitraum: Tag.zeitraum(beginn, hatEnde ? ende : nil))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section("Reise") {
                    TextField("Titel, z. B. Portugal 2027", text: $titel)
                        .font(.headline)
                    TextField("Untertitel (freiwillig)", text: $untertitel)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(symbole, id: \.self) { s in
                                Text(s)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(emoji == s ? palette.hell.opacity(0.35) : Color.clear, in: Circle())
                                    .onTapGesture { emoji = s }
                            }
                        }
                    }
                }

                Section("Wann") {
                    DatePicker("Abreise", selection: $beginn, displayedComponents: .date)
                    Toggle("Rückreise steht fest", isOn: $hatEnde)
                    if hatEnde {
                        DatePicker("Rückreise", selection: $ende, in: beginn..., displayedComponents: .date)
                    }
                }

                Section("Farbe") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Palette.allCases) { p in
                                Circle()
                                    .fill(p.verlauf)
                                    .frame(width: 38, height: 38)
                                    .overlay(Circle().strokeBorder(.primary, lineWidth: palette == p ? 3 : 0).padding(-4))
                                    .onTapGesture { withAnimation(.spring(duration: 0.3)) { palette = p } }
                                    .accessibilityLabel(p.name)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                    }
                }

                Section {
                    PhotosPicker(selection: $bildWahl, matching: .images) {
                        Label(titelbild == nil ? "Titelbild wählen" : "Anderes Titelbild", systemImage: "photo")
                    }
                    if titelbild != nil {
                        Button("Titelbild entfernen", role: .destructive) { titelbild = nil }
                    }
                } footer: {
                    Text("Ohne Titelbild zeigt die Reise ihr erstes Foto.")
                }

                if reise == nil {
                    Section {
                        Toggle("Reisespur aufzeichnen", isOn: $aufzeichnen)
                    } footer: {
                        Text("Solange die Reise läuft, zeichnet Fernweh deinen Weg auf — daraus entstehen die Orte jedes Tages und die Linie auf der Karte. Die Spur bleibt bei dir und deinen Miturlaubern.")
                    }
                }
            }
            .navigationTitle(reise == nil ? "Neue Reise" : "Reise bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(reise == nil ? "Anlegen" : "Sichern") { sichern() }
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: bildWahl) { _, neu in
                guard let neu else { return }
                Task {
                    if let daten = try? await neu.loadTransferable(type: Data.self) {
                        let klein = await Task.detached { Bildwerk.verkleinert(daten, kante: 1600) }.value
                        titelbild = klein
                    }
                }
            }
            .onAppear(perform: laden)
        }
    }

    private func laden() {
        guard !geladen else { return }
        geladen = true
        guard let reise else { return }
        titel = reise.titel ?? ""
        untertitel = reise.untertitel ?? ""
        emoji = reise.emoji ?? "✈️"
        beginn = reise.anfang
        hatEnde = reise.ende != nil
        if let e = reise.ende { ende = Tag.anfang(e) }
        palette = reise.palette
        titelbild = reise.titelbild
    }

    private func sichern() {
        let persistenz = Persistenz.shared
        let ziel = reise ?? persistenz.anlegen(Reise.self, bei: nil)
        if reise == nil {
            ziel.kennung = UUID()
            ziel.erstellt = Date()
        }
        ziel.titel = titel.trimmingCharacters(in: .whitespacesAndNewlines)
        ziel.untertitel = untertitel.trimmingCharacters(in: .whitespacesAndNewlines)
        ziel.emoji = emoji
        ziel.beginn = Tag.anfang(beginn)
        ziel.ende = hatEnde ? Tag.anfang(max(ende, beginn)) : nil
        ziel.farbe = palette.rawValue
        if ziel.titelbild != titelbild { ziel.titelbild = titelbild }
        persistenz.sichern()
        if reise == nil, aufzeichnen, ziel.laeuft || ziel.liegtInZukunft {
            aufzeichner.eingeschaltet = true
            aufzeichner.erlaubnisAnfragen()
        }
        fertig(reise == nil ? ziel : nil)
        schliessen()
    }
}

private struct VorschauKarte: View {
    let titel: String
    let emoji: String
    let palette: Palette
    let bild: Data?
    let zeitraum: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(palette.verlauf)
                .overlay {
                    if let bild, let ui = UIImage(data: bild) {
                        Image(uiImage: ui).resizable().scaledToFill()
                    } else {
                        Text(emoji).font(.system(size: 80))
                    }
                }
                .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(emoji) \(titel.isEmpty ? "Neue Reise" : titel)")
                    .font(Stil.titel(24))
                Text(zeitraum).font(.caption.weight(.semibold)).opacity(0.9)
            }
            .foregroundStyle(.white)
            .padding(16)
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.spring(duration: 0.4), value: palette)
    }
}
