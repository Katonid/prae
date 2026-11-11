import SwiftUI

// DIE INHALTE NACH KAPITELN.
//
// Was hier steht, ist schon die Gliederung des Buches: Jeder Abschnitt ist
// ein Kapitel des Zeitrasters, darin die Texte und Fotos nach der Zeit.
// Aufeinanderfolgende Fotos stehen als eine Reihe — eine Zeile je Foto
// wäre bei dreihundert Urlaubsbildern keine Übersicht mehr.
struct InhalteView: View {
    @Binding var buch: Buch
    var oeffnen: (Blatt) -> Void

    @State private var umbenennen: Kapitel?
    @State private var neuerTitel = ""

    private enum Zeile: Identifiable {
        case text(Texteintrag)
        case fotos([Fotoeintrag])
        var id: String {
            switch self {
            case .text(let t): return "t" + t.id.uuidString
            case .fotos(let f): return "f" + (f.first?.id.uuidString ?? "")
            }
        }
    }

    var body: some View {
        let gruppen = Seitenbau.gruppen(buch)
        List {
            if gruppen.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Noch leer").font(.headline)
                        Text("Über „+“ kommen Texte und Fotos hinzu. Jeder Inhalt trägt einen Zeitstempel; daraus entstehen die Kapitel (Grundeinstellung: Kalenderjahre — änderbar unter „Mehr → Buch einrichten“).")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            ForEach(gruppen) { g in
                Section {
                    if g.inhalte.isEmpty {
                        Text("Keine Inhalte in diesem Zeitraum")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(zeilen(g.inhalte)) { zeile in
                        switch zeile {
                        case .text(let t):
                            Button { oeffnen(.text(t.id)) } label: { TextZeile(eintrag: t) }
                                .buttonStyle(.plain)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        buch.texte.removeAll { $0.id == t.id }
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                        case .fotos(let fotos):
                            FotoReihe(fotos: fotos) { oeffnen(.foto($0)) }
                                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 0))
                        }
                    }
                } header: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(g.titel)
                            Text(g.kapitel.zeitraum).font(.caption2).textCase(nil)
                        }
                        Spacer()
                        Button {
                            neuerTitel = buch.kapitelTitel(g.kapitel)
                            umbenennen = g.kapitel
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .accessibilityLabel("Kapitelüberschrift ändern")
                    }
                }
            }
            if !buch.freieSeiten.isEmpty {
                Section {
                    ForEach(Array(buch.freieSeiten.enumerated()), id: \.element.id) { n, seite in
                        Button { oeffnen(.frei(seite.id)) } label: {
                            Label("Freie Seite \(n + 1): \(beschreibung(seite))", systemImage: seite.vorlage.symbol)
                        }
                    }
                } header: {
                    Text("Freie Seiten")
                } footer: {
                    Text("Wo eine freie Seite steht, legt man im Reiter „Buch“ fest: lange auf eine Seite drücken und davor oder danach einfügen.")
                }
            }
        }
        .alert("Kapitelüberschrift",
               isPresented: Binding(get: { umbenennen != nil }, set: { if !$0 { umbenennen = nil } })) {
            TextField("Überschrift", text: $neuerTitel)
            Button("Sichern") {
                if let k = umbenennen {
                    let t = neuerTitel.trimmingCharacters(in: .whitespacesAndNewlines)
                    buch.kapitelTitel[k.schluessel] = (t.isEmpty || t == k.standardTitel) ? nil : t
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Leer lassen für die Überschrift aus dem Zeitraster („\(umbenennen?.standardTitel ?? "")“).")
        }
    }

    private func zeilen(_ inhalte: [Inhalt]) -> [Zeile] {
        var liste: [Zeile] = []
        var reihe: [Fotoeintrag] = []
        for inhalt in inhalte {
            switch inhalt {
            case .text(let t):
                if !reihe.isEmpty { liste.append(.fotos(reihe)); reihe = [] }
                liste.append(.text(t))
            case .foto(let f):
                reihe.append(f)
            }
        }
        if !reihe.isEmpty { liste.append(.fotos(reihe)) }
        return liste
    }

    private func beschreibung(_ seite: FreieSeite) -> String {
        (0..<seite.vorlage.anzahl).map { seite.feld($0).name }.joined(separator: ", ")
    }
}

private struct TextZeile: View {
    let eintrag: Texteintrag

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(eintrag.titel.isEmpty ? "Ohne Überschrift" : eintrag.titel)
                .font(.headline)
                .foregroundStyle(eintrag.titel.isEmpty ? .secondary : .primary)
            Text(Textsatz.datumszeile(eintrag.zeit))
                .font(.caption)
                .foregroundStyle(.secondary)
            if !eintrag.text.isEmpty {
                Text(eintrag.text)
                    .font(.callout)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}

private struct FotoReihe: View {
    let fotos: [Fotoeintrag]
    var antippen: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 6) {
                ForEach(fotos) { f in
                    Button { antippen(f.id) } label: {
                        Vorschaubild(datei: f.datei, kante: 72)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.trailing, 12)
        }
        .frame(height: 72)
    }
}
