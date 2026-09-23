import PDFKit
import SwiftUI

// AUSGEBEN — und seit 1.0.37 auch DRUCKEN.
//
// Diese eine Ansicht bedient beide Einstiege: „Als PDF sichern…" und
// „Broschüre drucken…". Ein zweiter Bildschirm für die Broschüre wäre ein
// zweiter Weg zu derselben Sache und liefe irgendwann auseinander —
// dieselbe Regel wie bei den Fotostilfeldern (1.0.10). Der Einstieg wählt
// nur vor, was hier oben steht.
struct AusgabeView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    @State private var anteil: Double = 0
    @State private var laeuft = false
    @State private var fertig: URL?
    @State private var befundAmPDF: [Druckpruefung.Zeile] = []
    @State private var fehler: String?
    @State private var teilen = false
    @State private var guete: Bildguete = .druck
    @State private var ohneTransparenz = false
    @State private var umfang: Umfang
    @State private var drucken = false

    // WOMIT DER BILDSCHIRM AUFMACHT. Der Menüpunkt „Broschüre drucken…"
    // reicht `.broschuere` herein; sonst bleibt es bei der einen Datei.
    //
    // Gesetzt wird der Anfangswert HIER und nicht in `.task`: Ein Zustand,
    // den eine Aufgabe nachträglich überschreibt, springt für einen
    // Durchgang lang auf den falschen Wert — und wer in dieser Zeit schon
    // umgestellt hat, sieht seine Wahl zurückgesetzt.
    init(werk: Reisewerk, vorwahl: Umfang = .ganzesBuch) {
        self.werk = werk
        _umfang = State(initialValue: vorwahl)
    }
    @State private var teilenliste: [URL] = []
    @State private var befundVorab: [Druckpruefung.Zeile] = []
    @State private var rueckseitenDrehen = false

    // WIE DIE SEITEN ANGEORDNET WERDEN.
    //
    // Der Picker hieß bis 1.0.36 „Umfang", und die Namen darin sagten
    // nicht, was dahintersteht: Für „Broschüre" musste man wissen, dass es
    // eine gibt. Dass der Nutzer sie nicht gefunden hat (09/2026: „Noch
    // nicht gefunden habe ich die gewünschte Option, das Reisetagebuch auf
    // dem heimischen Drucker doppelseitig als Broschüre drucken zu
    // können"), obwohl sie seit 1.0.27 vollständig gebaut ist, liegt an
    // drei Dingen auf einmal: falsches Menü, ein Wort, das nach Seitenzahl
    // klingt, und ein zugeklappter Picker darüber. Alle drei sind geändert.
    enum Umfang: String, CaseIterable, Identifiable {
        case ganzesBuch
        case getrennt
        case broschuere

        var id: String { rawValue }
        var name: String {
            switch self {
            case .ganzesBuch: return "Buchseiten der Reihe nach"
            case .getrennt: return "Umschlag als eigene Datei"
            case .broschuere: return "Broschüre zum Selberfalten"
            }
        }

        var erklaerung: String {
            switch self {
            case .ganzesBuch:
                return "Eine Datei, Seite für Seite — das, was eine Druckerei oder ein Fotobuchdienst haben will."
            case .getrennt:
                return "Zwei Dateien: Innenteil und Umschlag. Viele Buchdienste verlangen das so. Der Umschlag ist EIN breiter Bogen — links die Rückseite, in der Mitte der Rücken, rechts die Titelseite."
            case .broschuere:
                return "Zwei Seiten nebeneinander auf einen Bogen, in Heftfolge. Für den eigenen Drucker: beidseitig ausdrucken, in der Mitte falten, heften."
            }
        }
    }

    // Was am Umschlagbogen zu wissen ist — die Rückenbreite und dass sie
    // gerechnet und nicht gemessen ist.
    private var umschlagzusatz: String {
        guard werk.reise.hatRueckseite else { return "" }
        let mm = Umschlagmass.rueckenbreite(werk.reise.umschlag,
                                            innenseiten: werk.reise.innenseiten)
        guard mm > 0.05 else { return "" }
        let zahl = String(format: "%.1f", mm).replacingOccurrences(of: ".", with: ",")
        var text = " \u{2014} ein Bogen, Rücken \(zahl) mm. "
        text += "Die Breite ist aus Seitenzahl, Papierstärke und Einband GERECHNET; "
        text += "verbindlich ist die Angabe des Druckdienstes."
        return text
    }

    enum Bildguete: String, CaseIterable, Identifiable {
        case sparsam
        case druck
        case voll

        var id: String { rawValue }

        var kante: Int {
            switch self {
            case .sparsam: return 1600
            case .druck: return 3600
            case .voll: return 6000
            }
        }

        var name: String {
            switch self {
            case .sparsam: return "Zum Ansehen"
            case .druck: return "Für den Druck"
            case .voll: return "Volle Auflösung"
            }
        }

        var erklaerung: String {
            switch self {
            case .sparsam:
                return "Kleine Datei zum Durchsehen und Verschicken. Für den Druck zu wenig."
            case .druck:
                return "Bis 3600 Bildpunkte je Kante — das reicht für 300 dpi auf einer ganzen A4-Seite. Der übliche Fall."
            case .voll:
                return "So groß, wie die Bilder hergeben. Nötig nur bei Formaten über 30 cm; die Datei kann sehr groß werden."
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Seiten", value: "\(werk.reise.seitenzahl)")
                    LabeledContent("Endformat", value: werk.reise.format.masstext)
                    Picker("Bildgüte", selection: $guete) {
                        ForEach(Bildguete.allCases) { g in Text(g.name).tag(g) }
                    }
                    Text(guete.erklaerung)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Anordnung", selection: $umfang) {
                        ForEach(Umfang.allCases) { u in Text(u.name).tag(u) }
                    }
                    Text(umfang.erklaerung)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if umfang == .broschuere {
                        LabeledContent("Bogen", value: broschuerenmass)
                        Toggle("Rückseiten um 180° drehen", isOn: $rueckseitenDrehen)
                        Text(broschuerenhinweis)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Toggle("Ohne Transparenz (PDF/X-1a, X-3)", isOn: $ohneTransparenz)
                    if ohneTransparenz {
                        Text("Schatten fallen weg, der Verlauf unter einer Überschrift auf einem Foto wird zu einem geschlossenen Feld, und ein Wasserzeichen entfällt ganz — deckend gezeichnet wäre es kein Wasserzeichen mehr. Nur nötig, wenn die Druckerei ausdrücklich danach fragt.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Was ausgegeben wird")
                } footer: {
                    Text("Der Text wird als Text gesetzt, nicht als Bild — das PDF bleibt durchsuchbar und wiegt einen Bruchteil. Endformat und Anschnitt stehen als TrimBox und BleedBox darin.")
                }

                Section("Vor dem Ausgeben geprüft") {
                    ForEach(befundVorab) { zeile in BefundZeile(zeile: zeile) }
                }

                if laeuft {
                    Section {
                        ProgressView(value: anteil)
                        Text(anteil < 0.45 ? "Kartenbilder werden geholt…" : "Seiten werden gesetzt…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let fehler {
                    Section {
                        Label(fehler, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                if let fertig {
                    Section("An der fertigen Datei gemessen") {
                        ForEach(befundAmPDF) { zeile in BefundZeile(zeile: zeile) }
                    }
                    Section {
                        PDFVorschau(adresse: fertig)
                            .frame(height: 320)
                            .listRowInsets(EdgeInsets())
                        // DRUCKEN STEHT VOR TEILEN, wenn eine Broschüre
                        // gesetzt wurde (ab 1.0.37). Sie ist für den
                        // eigenen Drucker gebaut und für sonst nichts; eine
                        // Datei, die man erst irgendwohin sichern und dann
                        // von Hand wieder öffnen muss, wäre der Umweg um
                        // genau den Knopf herum, um den gebeten wurde.
                        Button {
                            drucken = true
                        } label: {
                            Label("Drucken\u{2026}", systemImage: "printer")
                        }
                        Button {
                            teilen = true
                        } label: {
                            Label("Sichern oder teilen", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                Section {
                    Button {
                        Task { await ausgeben() }
                    } label: {
                        Label(fertig == nil ? "PDF erzeugen" : "Noch einmal erzeugen",
                              systemImage: "doc.badge.gearshape")
                    }
                    .disabled(laeuft)
                }
            }
            .navigationTitle(umfang == .broschuere ? "Broschüre" : "Als PDF sichern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
            .sheet(isPresented: $teilen) {
                Teilenblatt(gegenstaende: teilenliste)
            }
            .onChange(of: drucken) { _, neu in
                guard neu, let fertig else { return }
                drucken = false
                Druckauftrag.zeigen(fertig, titel: werk.reise.titel,
                                    beidseitig: umfang == .broschuere)
            }
            .task { befundVorab = Druckpruefung.vorab(werk.reise) }
        }
    }

    // MARK: - Broschüre

    private var broschuerenmass: String {
        let end = werk.reise.format
        let b = end.breite * 2
        return "\(ganzzahl(b)) × \(ganzzahl(end.hoehe)) mm (zwei Seiten nebeneinander)"
    }

    private var broschuerenbefund: String {
        let seiten = werk.reise.seitenzahl
        let gefuellt = seiten % 4 == 0 ? seiten : seiten + (4 - seiten % 4)
        let bogen = gefuellt / 2
        let leer = gefuellt - seiten
        var text = "\(bogen) Bogen, beidseitig zu bedrucken"
        if leer > 0 { text += " · \(leer) leere Seite\(leer == 1 ? "" : "n") aufgefüllt" }
        return text
    }

    private var broschuerenhinweis: String {
        "Zwei Seiten kommen nebeneinander auf einen Bogen, in Heftfolge — gefaltet und in der Mitte geheftet liegt daraus ein Heft in der Hand. Die Bogenzahl ist immer durch vier teilbar; fehlende Seiten bleiben weiß.\n\nGedruckt wird beidseitig. Wendet der Drucker über die LANGE Kante, bleibt der Schalter aus; wendet er über die kurze, steht die Rückseite sonst auf dem Kopf. Welche der beiden Einstellungen gilt, sagt kein Dateiformat — das steht im Druckdialog.\n\nOhne Anschnitt: Ein Heimdrucker druckt nicht bis an die Kante, und ein Anschnitt, den niemand wegschneidet, wäre ein Rand aus abgeschnittenem Bild."
    }

    private func ganzzahl(_ wert: Double) -> String {
        String(Int(wert.rounded()))
    }

    private func ausgeben() async {
        laeuft = true
        fehler = nil
        anteil = 0
        befundAmPDF = []
        do {
            if umfang == .broschuere {
                let ziel = try await Buchausgabe.broschuere(
                    werk.reise,
                    auftrag: .init(bildkante: guete.kante, ohneTransparenz: ohneTransparenz,
                                   rueckseitenDrehen: rueckseitenDrehen),
                    fortschritt: { wert in anteil = wert })
                fertig = ziel
                // KEINE Druckprüfung an der Broschüre: Sie misst TrimBox und
                // BleedBox, und die gibt es hier bewusst nicht — ein
                // Heimdrucker schneidet nichts ab. Eine Prüfung, die das
                // Fehlen einer Box beanstandet, die nicht hingehört, wäre
                // eine Fehlmeldung.
                befundAmPDF = [Druckpruefung.Zeile(
                    stufe: .gut, titel: "Broschüre gesetzt",
                    text: broschuerenbefund)]
                teilenliste = [ziel]
            } else if umfang == .getrennt {
                // Viele Buchdienste wollen Umschlag und Innenteil als zwei
                // Dateien. Ausgegeben wird dann der Innenteil als Hauptdatei
                // und der Umschlag daneben — beide liegen im selben Ordner
                // und werden zusammen geteilt.
                let umschlag = try await Buchausgabe.pdf(
                    werk.reise,
                    auftrag: .init(bildkante: guete.kante, ohneTransparenz: ohneTransparenz,
                                   nurUmschlag: true),
                    fortschritt: { _ in })
                let innen = try await Buchausgabe.pdf(
                    werk.reise,
                    auftrag: .init(bildkante: guete.kante, ohneTransparenz: ohneTransparenz,
                                   ohneUmschlag: true),
                    fortschritt: { wert in anteil = wert })
                fertig = innen
                befundAmPDF = Druckpruefung.amPDF(innen)
                    + [Druckpruefung.Zeile(
                        stufe: .gut, titel: "Umschlag getrennt gesichert",
                        text: umschlag.lastPathComponent + umschlagzusatz)]
                teilenliste = [innen, umschlag]
            } else {
                let ziel = try await Buchausgabe.pdf(
                    werk.reise,
                    auftrag: .init(bildkante: guete.kante, ohneTransparenz: ohneTransparenz),
                    fortschritt: { wert in anteil = wert })
                fertig = ziel
                befundAmPDF = Druckpruefung.amPDF(ziel)
                teilenliste = [ziel]
            }
        } catch {
            fehler = error.localizedDescription
        }
        laeuft = false
    }

}

struct BefundZeile: View {
    let zeile: Druckpruefung.Zeile

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: zeile.stufe.symbol)
                .foregroundStyle(farbe)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text(zeile.titel)
                    .font(.subheadline.weight(.medium))
                Text(zeile.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 1)
    }

    private var farbe: Color {
        switch zeile.stufe {
        case .gut: return .green
        case .hinweis: return .secondary
        case .warnung: return .orange
        }
    }
}

struct PDFVorschau: UIViewRepresentable {
    let adresse: URL

    func makeUIView(context: Context) -> PDFView {
        let ansicht = PDFView()
        ansicht.autoScales = true
        ansicht.displayMode = .singlePageContinuous
        ansicht.displayDirection = .vertical
        ansicht.backgroundColor = .systemGroupedBackground
        return ansicht
    }

    func updateUIView(_ ansicht: PDFView, context: Context) {
        if ansicht.document?.documentURL != adresse {
            ansicht.document = PDFDocument(url: adresse)
        }
    }
}
