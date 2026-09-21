import SwiftUI

struct RegalView: View {
    @EnvironmentObject private var regal: Regal
    @State private var neuerTitel = ""
    @State private var anlegenOffen = false
    @State private var zuLoeschen: Reise?

    var body: some View {
        NavigationStack {
            Group {
                if regal.reisen.isEmpty {
                    leer
                } else {
                    liste
                }
            }
            .navigationTitle("Reisetagebücher")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        neuerTitel = ""
                        anlegenOffen = true
                    } label: {
                        Label("Neue Reise", systemImage: "plus")
                    }
                }
            }
            .alert("Neue Reise", isPresented: $anlegenOffen) {
                TextField("Titel", text: $neuerTitel)
                Button("Anlegen") {
                    let neu = regal.anlegen(titel: neuerTitel)
                    regal.oeffnen(neu)
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Wie soll das Buch heißen? Der Titel lässt sich später ändern.")
            }
            .alert("Reise löschen?", isPresented: .init(
                get: { zuLoeschen != nil },
                set: { if !$0 { zuLoeschen = nil } }
            )) {
                Button("Löschen", role: .destructive) {
                    if let reise = zuLoeschen { regal.loeschen(reise.id) }
                    zuLoeschen = nil
                }
                Button("Abbrechen", role: .cancel) { zuLoeschen = nil }
            } message: {
                Text("Alle Seiten, Texte und Fotos dieser Reise werden vom Gerät gelöscht. Das lässt sich nicht rückgängig machen.")
            }
        }
        .fullScreenCover(item: $regal.offen) { werk in
            ReiseView(werk: werk)
                .environmentObject(regal)
        }
    }

    private var leer: some View {
        ContentUnavailableView {
            Label("Noch kein Reisetagebuch", systemImage: "book.closed")
        } description: {
            Text("Leg eine Reise an, wirf die Fotos hinein und lies deinen Tagebuchtext ein. Die App verteilt beides auf die Tage und setzt daraus Seiten.")
        } actions: {
            Button("Reise anlegen") {
                neuerTitel = ""
                anlegenOffen = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var liste: some View {
        List {
            if regal.unlesbar > 0 {
                // Eine Reise, die sich nicht lesen lässt, wird gezählt und
                // nicht verschwiegen. Eine Liste, die stillschweigend kürzer
                // ist, sieht aus wie Datenverlust — und ohne die Zahl wüsste
                // niemand, ob sie einer ist.
                Section {
                    Label("\(regal.unlesbar) Datei(en) im Reisenordner ließen sich nicht lesen.",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            ForEach(regal.reisen) { reise in
                Button {
                    regal.oeffnen(reise)
                } label: {
                    ReiseZeile(reise: reise)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Löschen", role: .destructive) { zuLoeschen = reise }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct ReiseZeile: View {
    let reise: Reise

    var body: some View {
        HStack(spacing: 14) {
            Vorschaubild(reise: reise)
            VStack(alignment: .leading, spacing: 3) {
                Text(reise.titel)
                    .font(.headline)
                if !reise.zeitraum.isEmpty {
                    Text(reise.zeitraum)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(zusammenfassung)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var zusammenfassung: String {
        var teile: [String] = []
        teile.append(reise.tage.count == 1 ? "1 Tag" : "\(reise.tage.count) Tage")
        teile.append(reise.fotos.count == 1 ? "1 Foto" : "\(reise.fotos.count) Fotos")
        teile.append("\(reise.seitenzahl) Seiten")
        return teile.joined(separator: " · ")
    }
}

private struct Vorschaubild: View {
    let reise: Reise

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(reise.gestaltung.papier.farbe)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
            if let erstes = reise.fotos.first,
               let bild = Bildarchiv.shared.vorschau(erstes.datei, reise: reise.id, kante: 200)
            {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 58, height: 58)
    }
}
