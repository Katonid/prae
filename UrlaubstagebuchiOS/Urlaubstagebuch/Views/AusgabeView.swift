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
    // WAS BEI DIESER GÜTE WIRKLICH IN DER DATEI LANDET (ab 1.0.59).
    //
    // Gerechnet und nicht behauptet — und gerechnet in einer Aufgabe und
    // nicht im Körper: Der Lauf geht über jede Seite und jedes Bild des
    // Buches, und der Körper einer Ansicht läuft bei jedem Neuzeichnen
    // (dieselbe Falle wie bei der Druckprüfung in 1.0.0).
    @State private var gueteBefund = ""
    @State private var groessenbefund = ""
    @State private var ohneTransparenz = false
    @State private var umfang: Umfang
    @State private var drucken = false

    // WOMIT DER BILDSCHIRM AUFMACHT. Die Menüpunkte „Broschüre drucken…"
    // und „Umschlag und Innenteil getrennt…" reichen ihren Umfang herein;
    // ohne Vorgabe entscheidet das BUCH.
    //
    // Hat es einen Umschlagbogen, sind ZWEI Dateien die Vorwahl (ab
    // 1.0.52, Ansage des Nutzers 09/2026: „dass automatisch ein Export von
    // zwei PDF-Dateien vorgenommen werden soll"). Das ist nicht bloß
    // Bequemlichkeit: Ein Bogen ist doppelt so breit wie eine Seite, und
    // mitten in einer Datei mit Buchseiten hätte er dort nichts zu suchen.
    // Umstellen lässt es sich weiterhin mit einem Tipp — der Picker steht
    // sichtbar darüber, und still weglassen tut diese Vorwahl nichts:
    // Ausgegeben wird in jedem Fall alles, nur eben in zwei Dateien.
    //
    // Gesetzt wird der Anfangswert HIER und nicht in `.task`: Ein Zustand,
    // den eine Aufgabe nachträglich überschreibt, springt für einen
    // Durchgang lang auf den falschen Wert — und wer in dieser Zeit schon
    // umgestellt hat, sieht seine Wahl zurückgesetzt.
    init(werk: Reisewerk, vorwahl: Umfang? = nil) {
        self.werk = werk
        let ausDemBuch: Umfang = werk.reise.hatRueckseite ? .getrennt : .ganzesBuch
        _umfang = State(initialValue: vorwahl ?? ausDemBuch)
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
    // NUR DER UMSCHLAG, NUR DER INNENTEIL (ab 1.0.67).
    //
    // Ansage des Nutzers, 09/2026: „Ich versuche herauszufinden, woran das
    // liegen könnte, damit ich jetzt nicht wieder beide Teile exportieren
    // muss, denn das PDF für das eigentliche Buch ist mittlerweile knapp
    // 4 GB groß." Das ist der Grund, und er wiegt schwer: Ein Umschlagbogen
    // ist in Sekunden gesetzt, der Innenteil braucht mit zweihundert Fotos
    // seine Zeit und seinen Platz. Wer am Umschlag etwas ändert, soll nicht
    // vier Gigabyte mitschreiben lassen, die er schon hat.
    //
    // Gebaut wird dafür KEIN zweiter Weg: Es sind dieselben zwei Aufträge,
    // die `getrennt` nacheinander stellt — hier eben einzeln.
    enum Umfang: String, CaseIterable, Identifiable {
        case ganzesBuch
        case getrennt
        case nurUmschlag
        case nurInnenteil
        case doppelseiten
        case broschuere

        var id: String { rawValue }
        var name: String {
            switch self {
            case .ganzesBuch: return "Buchseiten der Reihe nach"
            case .getrennt: return "Umschlag als eigene Datei"
            case .nurUmschlag: return "Nur der Umschlagbogen"
            case .nurInnenteil: return "Nur die Buchseiten"
            case .doppelseiten: return "Doppelseiten (zwei auf einen Bogen)"
            case .broschuere: return "Broschüre zum Selberfalten"
            }
        }

        var erklaerung: String {
            switch self {
            case .ganzesBuch:
                return "Eine Datei, Seite für Seite — das, was eine Druckerei oder ein Fotobuchdienst haben will."
            case .getrennt:
                return "Zwei Dateien: Innenteil und Umschlag. Viele Buchdienste verlangen das so. Der Umschlag ist EIN breiter Bogen — links die Rückseite, in der Mitte der Rücken, rechts die Titelseite."
            case .nurUmschlag:
                return "Nur der Umschlagbogen, ohne eine einzige Buchseite. Für den Fall, dass am Umschlag etwas zu ändern war und der Innenteil schon liegt — der ist bei einem vollen Buch mehrere Gigabyte groß und braucht seine Zeit."
            case .nurInnenteil:
                return "Nur die Buchseiten, ohne den Umschlagbogen. Die Gegenrichtung zu „Nur der Umschlagbogen“: Beide zusammen ergeben dasselbe wie „Umschlag als eigene Datei“, nur eben zu zwei Zeitpunkten."
            case .doppelseiten:
                return "Zwei Buchseiten auf eine PDF-Seite, links die gerade Nummer — so, wie das aufgeschlagene Buch aussieht. Der Bogen ist doppelt so breit wie eine Seite. Manche Fotobuchdienste wollen genau das. Der Umschlag gehört nicht hinein; den gibt es einzeln."
            case .broschuere:
                return "Zwei Seiten nebeneinander auf einen Bogen, in Heftfolge. Für den eigenen Drucker: beidseitig ausdrucken, in der Mitte falten, heften."
            }
        }
    }

    // WAS AUS DER PAARUNG GEWORDEN IST — als Zahl, nicht als Zusage.
    //
    // Ein halber erster und ein halber letzter Bogen sind Buchbinderei und
    // sehen trotzdem wie ein Fehler aus, wenn niemand sie benennt. Gebaut
    // wird der Satz Stück für Stück und nicht als Kette aus `?:`, `+` und
    // Interpolation — daran hat sich in 1.0.38 der Typprüfer verschluckt.
    private var doppelseitenzeile: Druckpruefung.Zeile {
        let befund = Buchausgabe.doppelseitenbefund(werk.reise)
        // `Double(…)` ausdrücklich — die Falle aus 1.0.37: Wo ein Wert
        // aus einem `CGSize` in eine eigene Größe geht, steht die
        // Umwandlung in diesem Repo dabei.
        let breite = Double(werk.reise.format.groesse.width) * 2
        let hoehe = Double(werk.reise.format.groesse.height)
        var titel = "\(befund.bogen) Doppelseiten"
        if befund.bogen == 1 { titel = "1 Doppelseite" }
        titel += ", je \(Druckmass.mmText(breite)) x \(Druckmass.mmText(hoehe))"
        var text = "Links steht immer die gerade Seitenzahl, rechts die "
        text += "ungerade \u{2014} so, wie das Buch aufgeschlagen daliegt. "
        text += "Der Umschlag steht nicht darin."
        var stufe = Druckpruefung.Stufe.gut
        if befund.halbe > 0 {
            stufe = .hinweis
            var wieviele = "\(befund.halbe) davon tragen"
            if befund.halbe == 1 { wieviele = "Eine davon trägt" }
            text += " " + wieviele
            text += " nur eine Buchseite: Seite 1 hat links von sich die "
            text += "Innenseite des Umschlags, und am Ende des Buches ist es "
            text += "ebenso. Diese Hälfte bleibt weiß \u{2014} sie kommt von der "
            text += "Druckerei und steht in keinem PDF."
        }
        return Druckpruefung.Zeile(stufe: stufe, titel: titel, text: text)
    }

    // Was am Umschlagbogen zu wissen ist — die Rückenbreite und dass sie
    // gerechnet und nicht gemessen ist.
    private var umschlagzusatz: String {
        guard werk.reise.hatRueckseite else { return "" }
        let mm = Umschlagmass.rueckenbreite(werk.reise.umschlag,
                                            format: werk.reise.format,
                                            innenseiten: werk.reise.innenseiten)
        guard mm > 0.05 else { return "" }
        let zahl = String(format: "%.1f", mm).replacingOccurrences(of: ".", with: ",")
        var text = " \u{2014} ein Bogen, Rücken \(zahl) mm. "
        text += "Die Breite ist "
        text += Umschlagmass.rueckenherkunft(werk.reise.umschlag,
                                             format: werk.reise.format,
                                             innenseiten: werk.reise.innenseiten)
        text += "; verbindlich ist die Angabe des Druckdienstes."
        return text
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
                    if !gueteBefund.isEmpty {
                        Text(gueteBefund)
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                    // WIE GROSS DIE DATEI WIRD, BEVOR sie geschrieben ist
                    // (ab 1.0.70). Vorher stand die Zahl erst danach da —
                    // nach zwanzig Minuten Rechnen und mit einer Datei, die
                    // kein Druckdienst annimmt.
                    if !groessenbefund.isEmpty {
                        Text(groessenbefund)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
            .navigationTitle(titel)
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
            // Bei JEDEM Wechsel der Güte neu, denn genau sie ist die
            // zweite Zahl in der Rechnung.
            .task(id: guete) {
                gueteBefund = Ausgabeguete.satz(werk.reise, guete: guete)
                groessenbefund = Ausgabeguete.groessenschaetzung(werk.reise, guete: guete)
            }
        }
    }

    // MARK: - Broschüre

    private var titel: String {
        switch umfang {
        case .broschuere: return "Broschüre"
        case .getrennt: return "Zwei Dateien"
        case .nurUmschlag: return "Nur der Umschlag"
        case .nurInnenteil: return "Nur der Innenteil"
        case .doppelseiten: return "Doppelseiten"
        case .ganzesBuch: return "Als PDF sichern"
        }
    }

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

    // DER AUFTRAG STEHT AN EINER STELLE (ab 1.0.70).
    //
    // An der Güte hängen seither drei Zahlen und nicht mehr eine: die
    // Höchstkante, die Ziel-dpi und die JPEG-Güte. Sechsmal derselbe
    // Aufruf mit drei Feldern wäre sechsmal die Gelegenheit, eines zu
    // vergessen — und ein vergessenes `jpegGuete` fällt erst an der
    // Dateigröße auf.
    private func auftrag(nurUmschlag: Bool = false, ohneUmschlag: Bool = false,
                         rueckseitenDrehen: Bool = false) -> Buchausgabe.Auftrag
    {
        Buchausgabe.Auftrag(bildkante: guete.kante,
                            zieldpi: guete.zieldpi,
                            jpegGuete: guete.jpegGuete,
                            ohneTransparenz: ohneTransparenz,
                            nurUmschlag: nurUmschlag,
                            ohneUmschlag: ohneUmschlag,
                            rueckseitenDrehen: rueckseitenDrehen)
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
                    auftrag: auftrag(rueckseitenDrehen: rueckseitenDrehen),
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
            } else if umfang == .doppelseiten {
                let ziel = try await Buchausgabe.doppelseitenPdf(
                    werk.reise,
                    auftrag: auftrag(),
                    fortschritt: { wert in anteil = wert })
                fertig = ziel
                befundAmPDF = Druckpruefung.amPDF(ziel) + [doppelseitenzeile]
                teilenliste = [ziel]
            } else if umfang == .getrennt {
                // Viele Buchdienste wollen Umschlag und Innenteil als zwei
                // Dateien. Ausgegeben wird dann der Innenteil als Hauptdatei
                // und der Umschlag daneben — beide liegen im selben Ordner
                // und werden zusammen geteilt.
                let umschlag = try await Buchausgabe.pdf(
                    werk.reise,
                    auftrag: auftrag(nurUmschlag: true),
                    fortschritt: { _ in })
                let innen = try await Buchausgabe.pdf(
                    werk.reise,
                    auftrag: auftrag(ohneUmschlag: true),
                    fortschritt: { wert in anteil = wert })
                fertig = innen
                befundAmPDF = Druckpruefung.amPDF(innen)
                    + [Druckpruefung.Zeile(
                        stufe: .gut, titel: "Umschlag getrennt gesichert",
                        text: umschlag.lastPathComponent + umschlagzusatz)]
                teilenliste = [innen, umschlag]
            } else if umfang == .nurUmschlag || umfang == .nurInnenteil {
                // DIESELBEN ZWEI AUFTRÄGE wie bei `getrennt`, nur einzeln
                // gestellt. Ein eigener Weg daneben liefe irgendwann
                // auseinander — dieselbe Regel wie bei den Fotostilfeldern.
                let nur = umfang == .nurUmschlag
                let ziel = try await Buchausgabe.pdf(
                    werk.reise,
                    auftrag: auftrag(nurUmschlag: nur, ohneUmschlag: !nur),
                    fortschritt: { wert in anteil = wert })
                fertig = ziel
                // Am Umschlagbogen misst die Druckprüfung TrimBox und
                // BleedBox — die gibt es dort, anders als bei der
                // Broschüre, und sie sind genau die Angaben, an denen eine
                // Druckerei den Falz und den Schnitt festmacht.
                //
                // Der Satz wird Stück für Stück gebaut und nicht als
                // `?:`-Kette mit `+` in einen Ausdruck geschrieben: Genau
                // daran hat sich in 1.0.38 der Typprüfer verschluckt.
                var einzeltitel = "Nur die Buchseiten"
                var einzeltext = "In dieser Datei steht kein Umschlagbogen. "
                einzeltext += "Den gibt es mit \u{201E}Nur der Umschlagbogen\u{201C} "
                einzeltext += "als eigene Datei."
                if nur {
                    einzeltitel = "Nur der Umschlag"
                    einzeltext = "In dieser Datei steht keine einzige Buchseite."
                    einzeltext += umschlagzusatz
                }
                let einzelzeile = Druckpruefung.Zeile(stufe: .hinweis, titel: einzeltitel,
                                                      text: einzeltext)
                befundAmPDF = Druckpruefung.amPDF(ziel) + [einzelzeile]
                teilenliste = [ziel]
            } else {
                let ziel = try await Buchausgabe.pdf(
                    werk.reise,
                    auftrag: auftrag(),
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
