import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// EINE FREIE SEITE GESTALTEN: Aufteilung wählen, jedes Feld mit Text,
// Foto oder einer PDF-Seite belegen, die Seite verschieben.
//
// Fotos auf freien Seiten sind KEINE Inhalte des Buches: Sie haben kein
// Datum und rutschen in kein Kapitel. Wer ein Foto des Buches hier noch
// einmal zeigen will, nimmt „Foto aus diesem Buch" — dieselbe Datei.
struct FreieSeiteView: View {
    @Binding var buch: Buch
    let id: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var fotoFeld: Int?
    @State private var buchfotoFeld: Int?
    @State private var dateiFeld = 0
    @State private var dateiPDF = false
    @State private var dateiwahl = false
    @State private var loeschenFragen = false
    @State private var meldung: String?

    var body: some View {
        let seite = Bindungen.frei($buch, id)
        NavigationStack {
            Form {
                Section {
                    Seitenbild(seite: Seitenbau.freiSeite(seite.wrappedValue).mitSignatur(buch), buch: buch, breite: 520)
                        .frame(maxHeight: 300)
                        .frame(maxWidth: .infinity)
                        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                        .padding(.vertical, 8)
                }

                Section("Aufteilung") {
                    Picker("Aufteilung", selection: seite.vorlage) {
                        ForEach(Vorlage.allCases) { v in
                            Label(v.name, systemImage: v.symbol).tag(v)
                        }
                    }
                }

                ForEach(0..<seite.wrappedValue.vorlage.anzahl, id: \.self) { i in
                    Section {
                        feld(i, seite: seite)
                    } header: {
                        Text("Feld \(i + 1)")
                    } footer: {
                        if case .text = seite.wrappedValue.feld(i) {
                            Text("Eine Zeile, die mit „# “ beginnt, wird als Überschrift gesetzt.")
                        }
                    }
                }

                Section {
                    Button { _ = buch.verschieben(id, frueher: true) } label: {
                        Label("Eine Seite nach vorn", systemImage: "arrow.backward")
                    }
                    Button { _ = buch.verschieben(id, frueher: false) } label: {
                        Label("Eine Seite nach hinten", systemImage: "arrow.forward")
                    }
                } header: {
                    Text("Platz im Buch")
                } footer: {
                    Text("Eine freie Seite bleibt hinter dem Inhalt stehen, hinter dem sie eingefügt wurde — auch wenn davor neue Seiten dazukommen.")
                }

                Section {
                    Button("Freie Seite löschen", role: .destructive) { loeschenFragen = true }
                }
            }
            .navigationTitle("Freie Seite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .onChange(of: seite.wrappedValue.vorlage) { _, neu in
                var s = seite.wrappedValue
                while s.felder.count < neu.anzahl { s.felder.append(.leer) }
                seite.wrappedValue = s
            }
            .sheet(isPresented: Binding(get: { fotoFeld != nil }, set: { if !$0 { fotoFeld = nil } })) {
                Fotowahl(hoechstzahl: 1) { ergebnisse in
                    let ziel = fotoFeld
                    fotoFeld = nil
                    guard let ziel, let r = ergebnisse.first else { return }
                    Task { @MainActor in
                        if let d = await Fotoeinfuhr.datei(r.itemProvider) {
                            setzen(.foto(d), feld: ziel)
                        } else {
                            meldung = "Das Foto ließ sich nicht übernehmen."
                        }
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: Binding(get: { buchfotoFeld != nil }, set: { if !$0 { buchfotoFeld = nil } })) {
                Buchfotowahl(fotos: buch.fotos) { datei in
                    if let ziel = buchfotoFeld { setzen(.foto(datei), feld: ziel) }
                    buchfotoFeld = nil
                }
            }
            .fileImporter(isPresented: $dateiwahl, allowedContentTypes: dateiPDF ? [.pdf] : [.image]) { ergebnis in
                ausDatei(ergebnis)
            }
            .confirmationDialog("Freie Seite löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    buch.freieSeiten.removeAll { $0.id == id }
                    dismiss()
                }
            }
            .alert("Hinweis", isPresented: Binding(get: { meldung != nil }, set: { if !$0 { meldung = nil } })) {
                Button("OK") {}
            } message: {
                Text(meldung ?? "")
            }
        }
    }

    @ViewBuilder
    private func feld(_ i: Int, seite: Binding<FreieSeite>) -> some View {
        let inhalt = seite.wrappedValue.feld(i)
        switch inhalt {
        case .leer:
            Text("leer").foregroundStyle(.secondary)
        case .text(let t):
            TextEditor(text: Binding(get: { t }, set: { setzen(.text($0), feld: i) }))
                .frame(minHeight: 120)
        case .foto(let d):
            HStack {
                Vorschaubild(datei: d, kante: 64)
                Text("Foto")
            }
        case .pdf(let d, let n):
            let anzahl = max(1, Medien.pdfSeitenzahl(d))
            HStack {
                Image(uiImage: Medien.pdfVorschau(d, seite: n, kante: 64))
                    .resizable()
                    .frame(width: 64, height: 64)
                Stepper("PDF-Seite \(n) von \(anzahl)",
                        value: Binding(get: { n }, set: { setzen(.pdf(d, $0), feld: i) }),
                        in: 1...anzahl)
            }
        }
        Menu {
            Button { setzen(.text(""), feld: i) } label: { Label("Text", systemImage: "text.alignleft") }
            Button { fotoFeld = i } label: { Label("Foto aus der Mediathek", systemImage: "photo") }
            Button { buchfotoFeld = i } label: { Label("Foto aus diesem Buch", systemImage: "photo.stack") }
                .disabled(buch.fotos.isEmpty)
            Button {
                dateiFeld = i
                dateiPDF = false
                dateiwahl = true
            } label: { Label("Foto aus Dateien", systemImage: "folder") }
            Button {
                dateiFeld = i
                dateiPDF = true
                dateiwahl = true
            } label: { Label("PDF-Datei", systemImage: "doc.richtext") }
            Divider()
            Button(role: .destructive) { setzen(.leer, feld: i) } label: { Label("Feld leeren", systemImage: "xmark") }
        } label: {
            Label(inhalt == .leer ? "Inhalt wählen" : "Inhalt ersetzen", systemImage: "square.and.pencil")
        }
    }

    private func setzen(_ inhalt: Feldinhalt, feld i: Int) {
        guard let n = buch.freieSeiten.firstIndex(where: { $0.id == id }) else { return }
        var s = buch.freieSeiten[n]
        while s.felder.count <= i { s.felder.append(.leer) }
        s.felder[i] = inhalt
        buch.freieSeiten[n] = s
    }

    private func ausDatei(_ ergebnis: Result<URL, Error>) {
        guard case .success(let adresse) = ergebnis else { return }
        let zugriff = adresse.startAccessingSecurityScopedResource()
        defer { if zugriff { adresse.stopAccessingSecurityScopedResource() } }
        guard let datei = try? Medien.ablegen(kopieVon: adresse) else {
            meldung = "Die Datei ließ sich nicht übernehmen."
            return
        }
        if dateiPDF {
            guard Medien.pdfSeitenzahl(datei) > 0 else {
                meldung = "Die PDF-Datei hat keine lesbaren Seiten."
                return
            }
            setzen(.pdf(datei, 1), feld: dateiFeld)
        } else {
            setzen(.foto(datei), feld: dateiFeld)
        }
    }
}

private struct Buchfotowahl: View {
    let fotos: [Fotoeintrag]
    var gewaehlt: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], spacing: 6) {
                    ForEach(fotos.sorted { $0.zeit < $1.zeit }) { f in
                        Button { gewaehlt(f.datei) } label: {
                            Vorschaubild(datei: f.datei, kante: 90)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Foto aus diesem Buch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}

extension Seite {
    /// Eine einzeln gebaute Seite (Vorschau im Editor) mit Signatur, damit
    /// sie bei jeder Änderung neu gemalt wird.
    func mitSignatur(_ buch: Buch) -> Seite {
        var s = self
        if let f = freieSeite {
            s.signatur = "\(buch.format.rawValue)|\(f.vorlage.rawValue)|\(String(describing: f.felder))"
        }
        return s
    }
}
