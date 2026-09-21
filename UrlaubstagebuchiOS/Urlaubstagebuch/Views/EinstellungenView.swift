import SwiftUI
import UniformTypeIdentifiers

// Was für die ganze App gilt und nicht für ein einzelnes Buch: wo die
// Bücher liegen, wie sie hereinkommen und wie sie hinauskommen.
struct EinstellungenView: View {
    @EnvironmentObject private var regal: Regal
    @Environment(\.dismiss) private var schliessen

    @State private var wolkeAn = Wolke.gewuenscht
    @State private var arbeitet = false
    @State private var bericht: String?
    @State private var waehler = false
    @State private var befund: Buchdatei.Befund?
    @State private var gewaehlteDatei: URL?
    @State private var fehler: String?
    @State private var konflikte: [URL] = []

    var body: some View {
        NavigationStack {
            Form {
                abgleich
                if !konflikte.isEmpty { konfliktabschnitt }
                austausch
                ablageort
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
            .task { konflikte = Wolke.konfliktdateien() }
            .fullScreenCover(isPresented: $waehler) {
                Dateiwahl(typen: buchtypen) { urls in
                    waehler = false
                    if let erste = urls.first { pruefen(erste) }
                }
                .ignoresSafeArea()
            }
            .alert("Buch einlesen", isPresented: .init(
                get: { befund != nil },
                set: { if !$0 { befund = nil } }
            )) {
                if let befund, befund.schonVorhanden {
                    Button("Vorhandenes ersetzen", role: .destructive) { einlesen(alsKopie: false) }
                    Button("Als Kopie anlegen") { einlesen(alsKopie: true) }
                } else {
                    Button("Einlesen") { einlesen(alsKopie: false) }
                }
                Button("Abbrechen", role: .cancel) { befund = nil }
            } message: {
                if let befund {
                    Text(einlesetext(befund))
                }
            }
        }
    }

    private var buchtypen: [UTType] {
        var liste: [UTType] = []
        if let eigen = UTType(filenameExtension: Buchdatei.endung) { liste.append(eigen) }
        liste.append(.data)
        return liste
    }

    // MARK: - Abgleich

    @ViewBuilder
    private var abgleich: some View {
        Section {
            // Kein `onChange` auf einem gespiegelten Zustand: Schlägt das
            // Einschalten fehl, muss der Schalter zurückspringen — und das
            // löste dann sein eigenes Ereignis aus. Der Binding-Setzer tut
            // beides an einer Stelle und kennt keine Rückkopplung.
            Toggle("Über iCloud abgleichen", isOn: Binding(
                get: { wolkeAn },
                set: { neu in
                    wolkeAn = neu
                    umschalten(neu)
                }
            ))
            .disabled(arbeitet)
            LabeledContent("Zustand", value: Wolke.stand.text)
            if arbeitet {
                HStack {
                    ProgressView()
                    Text("Bücher werden kopiert…")
                        .foregroundStyle(.secondary)
                }
            }
            if let bericht {
                Text(bericht)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Abgleich")
        } footer: {
            Text("Eingeschaltet liegen die Bücher in deinem iCloud-Laufwerk und "
                 + "erscheinen von selbst auf jedem Gerät, das mit derselben Apple-ID "
                 + "angemeldet ist. Den Abgleich macht iOS \u{2014} die App fragt beim "
                 + "Öffnen nach, was noch fehlt.\n\n"
                 + "Umschalten KOPIERT und löscht nichts. Wer zurückschaltet, findet "
                 + "seine Bücher auf dem Gerät vor.\n\n"
                 + "Ändern zwei Geräte dasselbe Buch, ohne sich dazwischen zu sehen, "
                 + "gilt die jüngere Fassung; die andere bleibt liegen und steht hier.")
        }
    }

    @ViewBuilder
    private var konfliktabschnitt: some View {
        Section {
            ForEach(konflikte, id: \.self) { ort in
                VStack(alignment: .leading, spacing: 4) {
                    Text(ort.lastPathComponent)
                        .font(.footnote)
                        .lineLimit(2)
                    HStack {
                        Button("Diese Fassung nehmen") { konfliktNehmen(ort) }
                            .buttonStyle(.bordered)
                        Button("Verwerfen", role: .destructive) { konfliktVerwerfen(ort) }
                            .buttonStyle(.bordered)
                    }
                    .font(.caption)
                }
            }
        } header: {
            Text("Fassungen aus einem Abgleich")
        } footer: {
            Text("Zu diesen Büchern gab es zwei Stände auf einmal. Die jüngere "
                 + "Fassung steht im Regal; das hier ist die andere. Sieh sie dir an, "
                 + "bevor du eine verwirfst \u{2014} die App hat nur nach dem Zeitpunkt "
                 + "entschieden, nicht nach dem Inhalt.")
        }
    }

    // MARK: - Austausch

    @ViewBuilder
    private var austausch: some View {
        Section {
            Button {
                waehler = true
            } label: {
                Label("Buchdatei einlesen…", systemImage: "square.and.arrow.down")
            }
            if let fehler {
                Label(fehler, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Austausch")
        } footer: {
            Text("Eine Datei mit der Endung .\(Buchdatei.endung) enthält ein ganzes "
                 + "Buch samt aller Bilder. Gesichert wird sie im geöffneten Buch "
                 + "unter Buch \u{2192} Buch als Datei sichern.")
        }
    }

    @ViewBuilder
    private var ablageort: some View {
        Section("Bestand") {
            LabeledContent("Bücher", value: "\(regal.reisen.count)")
            if regal.unlesbar > 0 {
                LabeledContent("Nicht lesbar", value: "\(regal.unlesbar)")
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Tun

    private func umschalten(_ an: Bool) {
        arbeitet = true
        bericht = nil
        Task {
            let umzug = await Wolke.umschalten(an)
            arbeitet = false
            bericht = umzug.satz
            // Ist iCloud nicht zu haben, hat `Wolke` den Wunsch selbst
            // zurückgenommen — der Schalter folgt, statt etwas zu zeigen,
            // was nicht gilt.
            wolkeAn = Wolke.gewuenscht
            konflikte = Wolke.konfliktdateien()
            regal.wolkeGewechselt()
        }
    }

    private func pruefen(_ ort: URL) {
        fehler = nil
        do {
            gewaehlteDatei = ort
            befund = try Buchdatei.pruefen(ort)
        } catch {
            gewaehlteDatei = nil
            fehler = error.localizedDescription
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
        guard let ort = gewaehlteDatei else { return }
        befund = nil
        do {
            _ = try Buchdatei.einlesen(ort, alsKopie: alsKopie)
            regal.neuLesen()
            bericht = "Buch eingelesen."
        } catch {
            fehler = error.localizedDescription
        }
        gewaehlteDatei = nil
    }

    private func konfliktNehmen(_ ort: URL) {
        // Der Name der Konfliktdatei trägt die Kennung des Buches vorn — so
        // findet die Fassung zurück an ihren Platz, und die Bilder, die
        // unter dieser Kennung liegen, passen weiter dazu.
        let name = ort.lastPathComponent
        guard let strich = name.range(of: Wolke.konfliktmarke) else { return }
        let ziel = ort.deletingLastPathComponent()
            .appendingPathComponent(String(name[name.startIndex..<strich.lowerBound]) + ".json")
        try? FileManager.default.removeItem(at: ziel)
        try? FileManager.default.moveItem(at: ort, to: ziel)
        konflikte = Wolke.konfliktdateien()
        regal.neuLesen()
    }

    private func konfliktVerwerfen(_ ort: URL) {
        try? FileManager.default.removeItem(at: ort)
        konflikte = Wolke.konfliktdateien()
    }
}
