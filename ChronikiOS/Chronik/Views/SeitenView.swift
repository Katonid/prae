import SwiftUI
import UniformTypeIdentifiers

// DAS BUCH, SEITE FÜR SEITE.
//
// Gesetzt wird abseits des Hauptfadens (der Textsatz misst jeden Text),
// gemalt wird jede Seite einzeln und nur, wenn sie ins Bild kommt. Neu
// gemalt wird eine Seite, wenn sich ihre `signatur` ändert — nicht bei
// jeder Änderung irgendwo im Buch.
//
// Freie Seiten kommen über das Kontextmenü (lange drücken) davor oder
// dahinter — an jede Stelle, auch zwischen zwei Seiten desselben Kapitels.
struct SeitenView: View {
    @Binding var buch: Buch
    var oeffnen: (Blatt) -> Void

    @State private var seiten: [Seite] = []
    @State private var gesetzt = false
    @State private var pdfNach: String?
    @State private var pdfWahl = false
    @State private var meldung: String?

    var body: some View {
        ScrollView {
            if gesetzt {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Stil", selection: $buch.stil) {
                        ForEach(Buchstil.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 420)
                    .padding(.bottom, 6)
                    Text("\(seiten.count) Seiten · \(buch.format.name)")
                        .font(.subheadline)
                    Text("Antippen zum Bearbeiten. Lange drücken, um freie Seiten davor oder danach einzufügen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 280), spacing: 18)], spacing: 22) {
                ForEach(Array(seiten.enumerated()), id: \.element.id) { index, seite in
                    VStack(spacing: 5) {
                        Seitenbild(seite: seite, buch: buch)
                            .overlay(
                                Rectangle().stroke(seite.freieSeite != nil ? Color.accentColor : Color.black.opacity(0.12),
                                                   lineWidth: seite.freieSeite != nil ? 2 : 0.5)
                            )
                            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                            .onTapGesture { antippen(seite) }
                            .contextMenu { menue(seite, index: index) }
                        Text(unterzeile(seite))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding()
        }
        .overlay {
            if !gesetzt { ProgressView("Seiten werden gesetzt …") }
        }
        .task(id: buch) {
            let b = buch
            let neu = await Task.detached(priority: .userInitiated) { Seitenbau.seiten(b) }.value
            if Task.isCancelled { return }
            seiten = neu
            gesetzt = true
        }
        .fileImporter(isPresented: $pdfWahl, allowedContentTypes: [.pdf]) { ergebnis in
            pdfEinfuegen(ergebnis)
        }
        .alert("Hinweis", isPresented: Binding(get: { meldung != nil }, set: { if !$0 { meldung = nil } })) {
            Button("OK") {}
        } message: {
            Text(meldung ?? "")
        }
    }

    private func unterzeile(_ s: Seite) -> String {
        switch s.art {
        case .titel: return "Titelseite"
        case .kapitel(let titel, _, _, _, _): return "\(s.nummer) · Kapitel \(titel)"
        case .inhalt: return "\(s.nummer)"
        case .frei: return "\(s.nummer) · freie Seite"
        }
    }

    @ViewBuilder
    private func menue(_ seite: Seite, index: Int) -> some View {
        if let f = seite.freieSeite {
            Button { oeffnen(.frei(f.id)) } label: { Label("Bearbeiten", systemImage: "pencil") }
            Button { _ = buch.verschieben(f.id, frueher: true) } label: { Label("Eine Seite nach vorn", systemImage: "arrow.backward") }
                .disabled(index <= 1)
            Button { _ = buch.verschieben(f.id, frueher: false) } label: { Label("Eine Seite nach hinten", systemImage: "arrow.forward") }
                .disabled(index >= seiten.count - 1)
            Divider()
        }
        if index > 0 {
            Button { einfuegen(nach: seiten[index - 1]) } label: {
                Label("Freie Seite davor einfügen", systemImage: "doc.badge.plus")
            }
        }
        Button { einfuegen(nach: seite) } label: {
            Label("Freie Seite danach einfügen", systemImage: "doc.badge.plus")
        }
        Button {
            pdfNach = seite.id
            pdfWahl = true
        } label: {
            Label("PDF-Datei danach einfügen …", systemImage: "doc.richtext")
        }
        if let f = seite.freieSeite {
            Divider()
            Button(role: .destructive) {
                buch.freieSeiten.removeAll { $0.id == f.id }
            } label: {
                Label("Freie Seite löschen", systemImage: "trash")
            }
        }
    }

    private func antippen(_ s: Seite) {
        switch s.art {
        case .titel:
            oeffnen(.einstellungen)
        case .kapitel(_, _, _, _, let foto):
            if let foto { oeffnen(.foto(foto.id)) }
        case .inhalt(let text, let fotos, _):
            if let text {
                oeffnen(.text(text.eintrag))
            } else if let f = fotos.first {
                oeffnen(.foto(f.id))
            }
        case .frei(let f):
            oeffnen(.frei(f.id))
        }
    }

    private func einfuegen(nach seite: Seite) {
        let neu = FreieSeite()
        buch.freieSeitenEinfuegen([neu], nach: seite)
        oeffnen(.frei(neu.id))
    }

    /// Jede Seite der PDF wird eine eigene freie Seite, in ihrer Reihenfolge.
    private func pdfEinfuegen(_ ergebnis: Result<URL, Error>) {
        guard case .success(let adresse) = ergebnis,
              let ziel = pdfNach, let seite = seiten.first(where: { $0.id == ziel }) else { return }
        let zugriff = adresse.startAccessingSecurityScopedResource()
        defer { if zugriff { adresse.stopAccessingSecurityScopedResource() } }
        guard let datei = try? Medien.ablegen(kopieVon: adresse) else {
            meldung = "Die PDF-Datei ließ sich nicht übernehmen."
            return
        }
        let anzahl = Medien.pdfSeitenzahl(datei)
        guard anzahl > 0 else {
            meldung = "Die PDF-Datei hat keine lesbaren Seiten."
            return
        }
        let neue = (1...anzahl).map { FreieSeite(vorlage: .eins, felder: [.pdf(datei, $0)]) }
        buch.freieSeitenEinfuegen(neue, nach: seite)
    }
}
