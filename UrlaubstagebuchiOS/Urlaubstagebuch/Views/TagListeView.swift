import SwiftUI

struct TagListeView: View {
    @ObservedObject var werk: Reisewerk
    @Binding var blatt: ReiseView.Blatt?
    @State private var neuerTag = false
    @State private var neuesDatum = Date()

    var body: some View {
        List(selection: auswahl) {
            Section("Buch") {
                if werk.reise.titelseite {
                    Label(werk.reise.titel, systemImage: "book.closed")
                        .tag(ReiseView.titelseitenKennung)
                }
                if !werk.reise.heimatlose.isEmpty {
                    Button {
                        blatt = .ablage
                    } label: {
                        Label("\(werk.reise.heimatlose.count) Fotos ohne Tag",
                              systemImage: "tray.full")
                            .foregroundStyle(.orange)
                    }
                }
            }
            Section("Tage") {
                ForEach(werk.reise.tage) { tag in
                    TagZeile(tag: tag, reise: werk.reise)
                        .tag(tag.id)
                        .swipeActions {
                            Button("Löschen", role: .destructive) { werk.tagLoeschen(tag.id) }
                        }
                }
            }
        }
        .navigationTitle(werk.reise.titel)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    neuesDatum = werk.reise.tage.last?.datum.naechster().mittag ?? Date()
                    neuerTag = true
                } label: {
                    Label("Tag anlegen", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $neuerTag) {
            NavigationStack {
                Form {
                    DatePicker("Datum", selection: $neuesDatum, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
                .navigationTitle("Tag anlegen")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { neuerTag = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Anlegen") {
                            werk.tagHinzufuegen(Tagesdatum(neuesDatum))
                            neuerTag = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var auswahl: Binding<UUID?> {
        Binding(get: { werk.gewaehlterTag }, set: { werk.gewaehlterTag = $0 })
    }
}

private struct TagZeile: View {
    let tag: Reisetag
    let reise: Reise

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(tag.datum.mittel)
                .font(.subheadline.weight(.semibold))
            if !tag.ueberschrift.isEmpty {
                Text(tag.ueberschrift)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 8) {
                marke("photo", "\(tag.fotos.count)")
                marke("mappin", "\(tag.spur.count)")
                marke("doc", "\(tag.seiten.count)")
                if tag.seiten.contains(where: \.vonHand) {
                    // Wer von Hand gearbeitet hat, muss das sehen — sonst
                    // ordnet er ahnungslos neu an und verliert es.
                    Image(systemName: "hand.draw")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.accentColor)
                }
                if tag.text.isEmpty {
                    Image(systemName: "text.badge.xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func marke(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: symbol).font(.system(size: 9))
            Text(text).font(.system(size: 10))
        }
        .foregroundStyle(.tertiary)
    }
}
