import SwiftUI
import UIKit
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
    @State private var befunde: [Konfliktbefund] = []
    @State private var geraetename = Geraetename.istSelbstVergeben ? Geraetename.eigener : ""
    @FocusState private var namensfeld: Bool

    var body: some View {
        NavigationStack {
            Form {
                abgleich
                if !befunde.isEmpty { konfliktabschnitt }
                austausch
                ablageort
                fassung
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
            // Je Konflikt werden ZWEI ganze Bücher eingelesen — das
            // gehört in eine Aufgabe und nicht in den Körper einer Ansicht.
            .task { befunde = await Konfliktbefund.alle() }
            .fullScreenCover(isPresented: $waehler) {
                Dateiwahl(typen: buchtypen) { urls in
                    waehler = false
                    guard let erste = urls.first else { return }
                    // Gefragt wird im Regal — dort steht die Frage EINMAL,
                    // und dort kommt auch an, was von außen hereingereicht
                    // wird. Ein Kasten über einem Blatt wäre obendrein
                    // unsichtbar (die Lehre aus Schulalarm 1.0.26).
                    regal.angeboteneDatei = erste
                    schliessen()
                }
                .ignoresSafeArea()
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

    // WELCHE FASSUNG HIER LÄUFT (ab 1.0.101).
    //
    // Bis 1.0.100 stand das NIRGENDS in der App. Gemeldet 09/2026 nach
    // einem Absturz: „es wird nirgendwo etwas eingetragen" — und von hier
    // aus war nicht zu entscheiden, ob auf dem Gerät überhaupt die
    // Fassung lief, über die geredet wurde. Ein Befund ohne seine Fassung
    // ist keine Auskunft, sondern eine Verwechslungsgefahr.
    //
    // Daneben steht die letzte Absturzspur: Sie bleibt liegen, bis jemand
    // sie weglegt — bis 1.0.100 verschwand sie nach dem ersten Blick, und
    // wer in dem Augenblick nicht hinsah, hatte sie für immer verloren.
    @ViewBuilder
    private var fassung: some View {
        Section {
            LabeledContent("Fassung", value: Absturzspur.Fassung.text)
                .textSelection(.enabled)
            if let befund = regal.absturzbefund {
                Text(befund)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                Button("Befund kopieren", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = befund
                }
                Button("Weglegen") {
                    Absturzspur.weglegen()
                    regal.absturzbefund = nil
                }
            }
        } header: {
            Text(regal.absturzbefund == nil ? "Über diese App" : "Letzter Absturz")
        } footer: {
            if regal.absturzbefund == nil {
                Text("Steht hier eine Absturzspur, war der letzte Schritt vor einem Absturz vermerkt. Jetzt steht keine da.")
            } else {
                Text("Der letzte Schritt, den die App vor dem Absturz vermerkt hat. Er bleibt stehen, bis du ihn weglegst.")
            }
        }
    }

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
            // WIE DIESES GERÄT IN EINEM BUCH VERMERKT WIRD (ab 1.0.102).
            // Übernommen wird beim VERLASSEN des Feldes und bei der
            // Eingabetaste: Ein Knopf daneben bräuchte immer zwei Tipps,
            // solange das Feld den Fokus hat (die Lehre aus 1.0.78).
            HStack {
                Text("Dieses Gerät")
                Spacer(minLength: 12)
                TextField(Geraetename.vorschlag, text: $geraetename)
                    .multilineTextAlignment(.trailing)
                    .focused($namensfeld)
                    .submitLabel(.done)
                    .onSubmit { namenUebernehmen() }
            }
            .onChange(of: namensfeld) { _, jetzt in
                if !jetzt { namenUebernehmen() }
            }
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

    // DIE BEIDEN FASSUNGEN SAGEN, WAS SIE SIND (ab 1.0.102).
    //
    // Gemeldet 09/2026: „Ich weiß nicht, von welchem Gerät und von wann
    // diese unterschiedlichen Fassungen sind. Deshalb kann ich auch nicht
    // beurteilen, welches die aktuelle ist, die ich behalten will."
    //
    // Hier stand bis 1.0.101 der DATEINAME — sechsunddreißig Zeichen
    // Kennung und eine Zahl — und daneben zwei Knöpfe, von denen einer
    // löscht. Jetzt steht in der Zeile, wann und wo beide Fassungen
    // gesichert wurden, und dahinter liegt der volle Vergleich.
    @ViewBuilder
    private var konfliktabschnitt: some View {
        Section {
            ForEach(befunde) { befund in
                NavigationLink {
                    Konfliktansicht(befund: befund,
                                    nehmen: { konfliktNehmen(befund.ort) },
                                    verwerfen: { konfliktVerwerfen(befund.ort) })
                } label: {
                    Konfliktzeile(befund: befund)
                }
            }
        } header: {
            Text("Fassungen aus einem Abgleich")
        } footer: {
            Text("Zu diesen Büchern gab es zwei Stände auf einmal. Die jüngere "
                 + "Fassung steht im Regal; das hier ist die andere. Tippe eine an: "
                 + "Dann stehen beide nebeneinander \u{2014} mit Zeitpunkt, Gerät und "
                 + "dem, was sich unterscheidet. Die App hat nur nach dem Zeitpunkt "
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
        } header: {
            Text("Austausch")
        } footer: {
            Text("Eine Datei mit der Endung .\(Buchdatei.endung) enthält ein ganzes "
                 + "Buch samt aller Bilder. Gesichert wird sie im geöffneten Buch "
                 + "unter \u{201E}\u{2026}\u{201C} oben rechts \u{2192} Buch als Datei sichern.")
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
            befunde = await Konfliktbefund.alle()
            regal.wolkeGewechselt()
        }
    }




    private func namenUebernehmen() {
        let vorher = Geraetename.eigener
        Geraetename.setzen(geraetename)
        // Ein Name, der sich nicht geändert hat, wird nicht geschrieben —
        // und ein leeres Feld heißt „wieder der Vorschlag".
        geraetename = Geraetename.istSelbstVergeben ? Geraetename.eigener : ""
        if Geraetename.eigener != vorher { befundeAuffrischen() }
    }

    // DIE GELTENDE FASSUNG WIRD NICHT WEGGEWORFEN (ab 1.0.102). Bis
    // 1.0.101 löschte dieser Weg sie — damit war ein Tausch endgültig,
    // und das ausgerechnet an der Stelle, an der jemand gerade zugegeben
    // hat, dass er es nicht beurteilen kann. Getauscht wird jetzt:
    // `Wolke.fassungNehmen` legt die bisherige ihrerseits beiseite.
    private func konfliktNehmen(_ ort: URL) {
        guard Wolke.fassungNehmen(ort) else {
            bericht = "Die Fassung ließ sich nicht übernehmen. Es hat sich nichts geändert."
            return
        }
        befundeAuffrischen()
        regal.neuLesen()
    }

    private func konfliktVerwerfen(_ ort: URL) {
        try? FileManager.default.removeItem(at: ort)
        befundeAuffrischen()
    }

    private func befundeAuffrischen() {
        Task { befunde = await Konfliktbefund.alle() }
    }
}
