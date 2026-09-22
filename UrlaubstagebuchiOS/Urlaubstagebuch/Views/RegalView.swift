import SwiftUI

struct RegalView: View {
    @EnvironmentObject private var regal: Regal
    @State private var neuerTitel = ""
    @State private var anlegenOffen = false
    @State private var zuLoeschen: Reise?
    @State private var einstellungen = false
    @State private var angebot: Buchdatei.Befund?
    @State private var einlesefehler: String?

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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        einstellungen = true
                    } label: {
                        Label("Einstellungen", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        neuerTitel = ""
                        anlegenOffen = true
                    } label: {
                        Label("Neue Reise", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $einstellungen) {
                EinstellungenView()
                    .environmentObject(regal)
            }
            // Eine hereingereichte Buchdatei — aus „Dateien", per AirDrop
            // oder über den Wähler in den Einstellungen. Die Frage steht
            // hier und nur hier.
            .onChange(of: regal.angeboteneDatei) { _, ort in
                guard let ort else { return }
                do {
                    angebot = try Buchdatei.pruefen(ort)
                } catch {
                    einlesefehler = error.localizedDescription
                    aufraeumen()
                }
            }
            .alert("Buch einlesen", isPresented: .init(
                get: { angebot != nil },
                set: { if !$0 { angebot = nil; aufraeumen() } }
            )) {
                if angebot?.schonVorhanden == true {
                    Button("Vorhandenes ersetzen", role: .destructive) { einlesen(alsKopie: false) }
                    Button("Als Kopie anlegen") { einlesen(alsKopie: true) }
                } else {
                    Button("Einlesen") { einlesen(alsKopie: false) }
                }
                Button("Abbrechen", role: .cancel) { angebot = nil; aufraeumen() }
            } message: {
                if let angebot { Text(einlesetext(angebot)) }
            }
            .alert("Das ging nicht", isPresented: .init(
                get: { einlesefehler != nil },
                set: { if !$0 { einlesefehler = nil } }
            )) {
                Button("Gut") { einlesefehler = nil }
            } message: {
                Text(einlesefehler ?? "")
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

    private func einlesetext(_ befund: Buchdatei.Befund) -> String {
        var satz = "\u{201E}\(befund.reise.titel)\u{201C} mit \(befund.reise.tage.count) Tagen "
            + "und \(befund.bilder) Bildern."
        if befund.fehlendeBilder > 0 {
            satz += " \(befund.fehlendeBilder) Bilder fehlen in der Datei."
        }
        if befund.schonVorhanden {
            satz += "\n\nEin Buch mit derselben Kennung gibt es schon. Ersetzen "
                + "überschreibt es; eine Kopie legt ein zweites daneben."
        }
        return satz
    }

    private func einlesen(alsKopie: Bool) {
        guard let ort = regal.angeboteneDatei else { return }
        angebot = nil
        do {
            _ = try Buchdatei.einlesen(ort, alsKopie: alsKopie)
            regal.neuLesen()
        } catch {
            einlesefehler = error.localizedDescription
        }
        aufraeumen()
    }

    // Was iOS in den Posteingang der App gelegt hat, gehört danach nicht
    // mehr dort hin: Beim nächsten Öffnen läge es sonst noch einmal da.
    private func aufraeumen() {
        if let ort = regal.angeboteneDatei,
           ort.path.contains("/Inbox/")
        {
            try? FileManager.default.removeItem(at: ort)
        }
        regal.angeboteneDatei = nil
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
            // Das TITELFOTO zuerst — das ist das Bild, das auch auf dem
            // Titelblatt steht, und damit das Gesicht dieses Buches. Bis
            // 1.0.19 stand hier das erste Foto der Reise, also ein
            // beliebiges; zwei Bücher mit demselben Anreisetag sahen im
            // Regal gleich aus.
            if let datei = titelbild,
               let bild = Bildarchiv.shared.vorschau(datei, reise: reise.id, kante: 240)
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
        // Hochkant wie ein Buchrücken im Regal, nicht quadratisch: Apple
        // Books und jede Bücher-App zeigen ein Buch als Buch.
        .frame(width: 52, height: 68)
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }

    private var titelbild: String? {
        if let id = reise.titelfoto, let foto = reise.foto(id) { return foto.datei }
        return reise.fotos.first?.datei
    }
}
