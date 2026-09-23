import MapKit
import SwiftUI

// Einen Reisepunkt auf der Karte wählen — oder einen vorhandenen ändern.
//
// **Ein Bildschirm für beides** (ab 1.0.20, Ansage des Nutzers 09/2026:
// „Ich möchte sie löschen, örtlich und zeitlich verändern können."). Ein
// eigener Editor daneben wäre ein zweiter Weg zu derselben Sache und liefe
// irgendwann auseinander — dieselbe Regel wie bei den Fotostilfeldern.
//
// Gewählt wird auf zwei Arten, und das ist Absicht:
//
// * **Ein Tipp auf die Karte** setzt die Stelle (ausdrücklich gewünscht:
//   „Einen abweichenden Ort möchte ich per Tipp auf eine Karte eingeben
//   können."). Er setzt sie aber nicht blind, sondern rückt sie unter das
//   Fadenkreuz — der Finger verdeckt genau die Stelle, die er trifft, und
//   so sieht man hinterher, wo sie gelandet ist.
// * **Die Karte schieben** stellt fein ein, was der Tipp grob traf.
//
// Die UHRZEIT wird getippt und nicht gedreht (ebenfalls ausdrücklich: „Die
// neue Zeitangabe möchte ich per Hand eingeben."). Angenommen wird alles,
// was eindeutig ist — „9:05", „0905", „9.05", „9".
// EINEN PUNKT AUF DER KARTE FINDEN — nicht in der Liste (ab 1.0.37).
//
// Befund des Nutzers, 09/2026: „Ich möchte die Reisepunkte auf einer Karte,
// die möglichst bildschirmfüllend ist, auswählen können und verschieben
// können bzw. löschen können. Innerhalb der Liste ist es schwierig, einen
// bestimmten Punkt wiederzufinden."
//
// Die Karte gab es schon, bildschirmfüllend, samt Verschieben und Löschen —
// nur der WEG hinein führte über die Liste: `punktID` war ein `let`, das von
// außen hereingereicht wurde, und wer den Punkt in der Liste nicht fand, kam
// gar nicht erst hierher. Die Punkte auf der Karte waren `Marker`, also
// unantastbar.
//
// Deshalb ist `punktID` jetzt ein ZUSTAND: Ein Tipp auf einen Punkt wählt
// ihn aus, und von da an heißt der Knopf „Übernehmen" statt „Punkt hier
// setzen". Wer beim Öffnen einen Punkt mitbekommt, startet bei dem.
//
// AUF DER KARTE LIEGT KEIN BEDIENELEMENT. Die Geste gehört der Karte; was
// auf ihr liegt, ist ein BILD (`.allowsHitTesting(false)`). Den Tipp nimmt
// die Karte entgegen und sucht HINTERHER den nächsten Punkt — in
// BILDPUNKTEN, nicht in Grad, denn was „nah" heißt, hängt am Maßstab.
// Dieselbe Lehre wie bei der Netzkarte der Abfahrtstafel (1.1.18): Liegen
// Bedienelemente auf einer Karte, schlucken sie die Finger der Zoomgeste.
struct PunktwahlView: View {
    @ObservedObject var werk: Reisewerk
    let tagID: UUID
    // Womit begonnen wird. Leer heißt: ein neuer Punkt.
    var start: UUID?
    // Welcher Punkt gerade bearbeitet wird. Leer heißt: ein neuer.
    @State private var punktID: UUID?
    @Environment(\.dismiss) private var schliessen
    @StateObject private var standort = Standortdienst()

    @State private var kamera: MapCameraPosition = .automatic
    @State private var mitte: Koordinate?
    @State private var name = ""
    @State private var nameGeholt = false
    @State private var zeitSetzen = false
    // Die Uhrzeit als TEXT, so wie sie getippt wird. Ein `DatePicker` stand
    // hier bis 1.0.19 — gedreht wird damit, getippt nicht.
    @State private var zeittext = ""
    // Wie weit die Karte gerade aufgezogen ist. Ein Tipp soll den Maßstab
    // behalten; ohne diesen Wert spränge er bei jedem Tipp auf eine feste
    // Spanne zurück.
    @State private var spanne = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    @State private var geladen = false
    @State private var loeschfrage = false
    @State private var suche = ""
    @State private var treffer: [MKMapItem] = []
    @State private var sucheLaeuft = false
    // Welche Punkte aus der Linie springen (ab 1.0.49). Gerechnet in
    // `.task(id:)` und nicht als berechnete Eigenschaft — der Körper dieser
    // Ansicht läuft bei jeder Kamerabewegung noch einmal.
    @State private var befunde: [Ausreisser.Befund] = []
    // DIE QUITTUNG (ab 1.0.52). Gemeldet 09/2026: „Es wäre schön, wenn
    // hier doch noch eine genauere Bestätigung durch die App erfolgen
    // könnte. Ich bekomme zumindest keine Rückmeldung, wenn ich auf eine
    // neue Uhrzeit gegangen bin und auf den orangenen Button. Normalerweise
    // kann ja dann dieses Fenster im unteren Bereich auch wieder schließen.
    // Das tut es bislang nicht."
    //
    // Gemeldet hat die App sehr wohl — nur an der falschen Stelle:
    // `werk.meldung` wird in `ReiseView` gezeigt, und diese Ansicht liegt
    // seit 1.0.49 als VOLLBILD darüber. Das Band erschien also hinter der
    // Karte, wo es niemand sieht. Dieselbe Lehre wie bei Schulalarm 1.0.26
    // („Ein Fehlerband unter einem Blatt sieht niemand"): **Wer aus einem
    // Vollbild heraus etwas meldet, meldet es IN diesem Vollbild.**
    //
    // Und zugleich der zweite Teil des Befundes: Solange eine Quittung
    // steht, sind die Eingabefelder zu — die Karte ist frei, und zwei
    // Knöpfe führen zurück.
    @State private var quittung: String?

    // Wie weit ein Tipp danebengehen darf, in BILDSCHIRMPUNKTEN. Apple
    // nennt 44 als Mindestmaß für ein Fingerziel; hier darf es großzügiger
    // sein als der gezeichnete Punkt, weil die Suche erst läuft, NACHDEM
    // klar ist, dass ein Tipp gemeint war — sie kostet also keine
    // Kartenfläche. Zu groß wäre sie trotzdem falsch: Dann ließe sich die
    // Karte in der Nähe einer Spur nicht mehr verschieben.
    private static let griffweite: Double = 30

    private var tag: Reisetag? { werk.reise.tage.first { $0.id == tagID } }
    private var punkt: Reisepunkt? {
        guard let punktID else { return nil }
        return tag?.spur.first { $0.id == punktID }
    }
    private var aendert: Bool { punktID != nil }
    private var auffaellige: Set<UUID> { Set(befunde.map(\.id)) }
    private var befundZumPunkt: Ausreisser.Befund? {
        guard let punktID else { return nil }
        return befunde.first { $0.id == punktID }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                karte
                fadenkreuz
                leiste
            }
            .navigationTitle(aendert ? "Reisepunkt ändern" : "Reisepunkt wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { schliessen() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        standort.holen()
                    } label: {
                        Label("Mein Standort", systemImage: "location")
                    }
                }
            }
            .searchable(text: $suche, prompt: "Ort suchen")
            .onSubmit(of: .search) { Task { await ortSuchen() } }
            .overlay(alignment: .top) { trefferliste }
            .onChange(of: standort.ort) { _, neu in
                guard let neu else { return }
                kamera = .region(MKCoordinateRegion(
                    center: neu.clLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)))
            }
            .task { starten() }
            .task(id: tag?.spur) { befunde = Ausreisser.finden(tag?.spur ?? []) }
            .alert("Punkt löschen?", isPresented: $loeschfrage) {
                Button("Löschen", role: .destructive) {
                    guard let alt = punktID else { return }
                    werk.punktLoeschen(tagID, punktID: alt)
                    // NICHT schließen (ab 1.0.37). Wer Punkte auf der Karte
                    // durchsieht, löscht oft mehrere; ein Blatt, das nach
                    // jedem Löschen zugeht, macht aus drei Handgriffen
                    // dreimal denselben Weg. Stattdessen zurück auf „neuer
                    // Punkt" — der gelöschte ist ja weg.
                    punktID = nil
                    name = ""
                    nameGeholt = false
                    zeitSetzen = false
                    zeittext = ""
                    quittung = "Punkt gelöscht."
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Der Punkt wird aus der Tagesspur entfernt. Stammt er aus einem Foto, "
                     + "kommt er beim nächsten „Aus den Fotos neu bauen\u{201C} wieder.")
            }
        }
    }

    private var karte: some View {
        MapReader { leser in
            kartenbild
                // EIN TIPP — zwei Bedeutungen, und welche gilt, entscheidet,
                // was unter dem Finger liegt. Liegt dort ein Reisepunkt,
                // wird der gewählt; sonst rückt die Stelle unter das
                // Fadenkreuz wie bisher.
                //
                // Das ist erlaubt, obwohl diese App sonst verlangt, dass
                // ein Modus sichtbar ist: Es IST sichtbar — die Punkte
                // stehen auf der Karte, der gewählte ist hervorgehoben, und
                // die Leiste unten nennt ihn beim Namen. Dieselbe Bauweise
                // wie ein Tipp auf einen Halt in der Netzkarte der
                // Abfahrtstafel.
                .onTapGesture { stelle in
                    if let getroffen = punktBei(stelle, leser: leser) {
                        waehle(getroffen)
                        return
                    }
                    guard let ort = leser.convert(stelle, from: .local) else { return }
                    kamera = .region(MKCoordinateRegion(center: ort, span: spanne))
                }
        }
    }

    // Welcher Punkt unter dem Finger liegt — gemessen in BILDPUNKTEN.
    //
    // Gerechnet wird erst, NACHDEM ein Tipp angekommen ist; in Grad zu
    // messen ginge nicht, weil ein Grad je nach Maßstab ein Millimeter oder
    // ein Bildschirm ist. Von hinten nach vorn durchgegangen, damit bei
    // gleichem Abstand der gewinnt, der obenauf gezeichnet ist.
    private func punktBei(_ stelle: CGPoint, leser: MapProxy) -> Reisepunkt? {
        guard let spur = tag?.spur, !spur.isEmpty else { return nil }
        var naechster: (punkt: Reisepunkt, abstand: Double)?
        for eintrag in spur.reversed() {
            guard let auf = leser.convert(eintrag.koordinate.clLocation, to: .local) else {
                continue
            }
            // `Double(…)` ist hier Pflicht und keine Zierde: `hypot` über
            // zwei `CGFloat` gibt `CGFloat` zurück, und bei einer
            // TUPEL-Zuweisung rechnet Swift die beiden NICHT ineinander um —
            // obwohl sie auf diesen Geräten dasselbe sind. Bei gewöhnlichen
            // Zuweisungen und Argumenten tut er es; der Fehler zeigt sich
            // also nur an dieser einen Stelle. Dieselbe Falle wie beim
            // Layoutautomaten im ersten Bau, und das zweite Mal.
            let abstand = Double(hypot(auf.x - stelle.x, auf.y - stelle.y))
            guard abstand <= Self.griffweite else { continue }
            if naechster == nil || abstand < naechster!.abstand {
                naechster = (eintrag, abstand)
            }
        }
        return naechster?.punkt
    }

    // Auf einen anderen Punkt wechseln. Die Karte fährt hin, und die Felder
    // übernehmen seine Angaben — sonst stünde im Namensfeld noch der Name
    // des vorigen und würde beim nächsten „Übernehmen" auf den neuen
    // geschrieben.
    private func waehle(_ neu: Reisepunkt) {
        quittung = nil
        guard neu.id != punktID else { return }
        punktID = neu.id
        mitte = neu.koordinate
        kamera = .region(MKCoordinateRegion(center: neu.koordinate.clLocation, span: spanne))
        name = neu.name
        nameGeholt = true
        if let zeit = neu.zeit {
            zeitSetzen = true
            zeittext = Self.uhrzeit.string(from: zeit)
        } else {
            zeitSetzen = false
            zeittext = ""
        }
    }

    private var kartenbild: some View {
        Map(position: $kamera) {
            if let tag, tag.spur.count >= 2 {
                MapPolyline(coordinates: tag.spur.map(\.koordinate.clLocation))
                    .stroke(werk.reise.akzent.farbe, lineWidth: 3)
            }
            ForEach(tag?.spur ?? []) { eintrag in
                Annotation(eintrag.name, coordinate: eintrag.koordinate.clLocation) {
                    Spurmarke(punkt: eintrag,
                              gewaehlt: eintrag.id == punktID,
                              auffaellig: auffaellige.contains(eintrag.id))
                }
                // WAS AUF EINER KARTE LIEGT, IST EIN BILD. Ein antippbarer
                // Punkt schluckt den Finger der Zoomgeste — die Lehre aus
                // 1.1.18 der Abfahrtstafel. Den Tipp nimmt die Karte
                // entgegen (siehe `punktBei`).
                .annotationTitles(.hidden)
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { zusammenhang in
            mitte = Koordinate(zusammenhang.region.center)
            spanne = zusammenhang.region.span
            nameGeholt = false
            Task { await nameHolen() }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var fadenkreuz: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .frame(width: 26, height: 26)
            Circle()
                .fill(Color.accentColor)
                .frame(width: 5, height: 5)
            Rectangle().fill(Color.accentColor).frame(width: 1, height: 40)
            Rectangle().fill(Color.accentColor).frame(width: 40, height: 1)
        }
        .shadow(color: .white.opacity(0.9), radius: 2)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var leiste: some View {
        if let quittung {
            quittungsleiste(quittung)
        } else {
            eingabeleiste
        }
    }

    // DIE QUITTUNG schließt die Eingabe und lässt die Karte frei — genau
    // das, was gemeldet wurde. Sie verschwindet NICHT von selbst nach ein
    // paar Sekunden: Wer gerade eine Uhrzeit übernommen hat, will sie
    // nachlesen können, und ein Band, das währenddessen wegblendet, ist
    // wieder keine Bestätigung. Weggeräumt wird sie durch eine Handlung —
    // einen der beiden Knöpfe oder einen Tipp auf die Karte.
    private func quittungsleiste(_ text: String) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(text)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("Die Spur ist geändert. Ein Tipp auf einen Punkt öffnet ihn, "
                 + "\u{201E}Fertig\u{201C} oben schließt die Karte.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 10) {
                if punkt != nil {
                    Button {
                        quittung = nil
                    } label: {
                        Label("Noch einmal ändern", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                Button {
                    neuerPunkt()
                } label: {
                    Label("Nächster Punkt", systemImage: "mappin.and.ellipse")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(12)
    }

    private var eingabeleiste: some View {
        VStack(spacing: 10) {
            // WELCHER PUNKT GERADE DRAN IST — in Worten. Ein Tipp auf die
            // Karte kann ihn wechseln, und ein Knopf, der dann „Übernehmen"
            // heißt, ohne zu sagen wofür, wäre ein Knopf, dem man nicht
            // traut.
            HStack(spacing: 8) {
                if let punkt {
                    Image(systemName: punkt.istAusFoto ? "camera.fill" : "mappin.circle.fill")
                        .foregroundStyle(punkt.istAusFoto ? Color.blue : Color.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(punkt.name.isEmpty ? "Punkt ohne Namen" : punkt.name)
                            .font(.subheadline.weight(.medium))
                        Text(stellensatz(punkt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        // Warum dieser Punkt orange ist — ein Zeichen ohne
                        // Erklärung ist ein Rätsel. Die Zahl sagt, worum es
                        // geht: was er an zusätzlicher Linie kostet.
                        if let befund = befundZumPunkt {
                            Label("\(befund.grund.satz) \u{00B7} \(befund.umwegtext) zusätzliche Linie",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    // ZURÜCK ZU „NEU". Ohne diesen Weg käme man, einmal auf
                    // einem Punkt gelandet, nie wieder zum Anlegen — und
                    // dass der Knopf unten plötzlich anders heißt, sähe wie
                    // ein Fehler aus.
                    Button("Neuer Punkt") { neuerPunkt() }
                        .font(.caption)
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color.accentColor)
                    Text(tag?.spur.isEmpty == false
                         ? "Neuer Punkt \u{2014} ein Tipp auf einen vorhandenen öffnet ihn."
                         : "Neuer Punkt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            Divider()
            if standort.abgelehnt {
                Text("Ohne Ortung fehlt nur der Knopf „Mein Standort“ — die Karte lässt sich weiter frei bewegen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextField("Name des Ortes", text: $name)
                .textFieldStyle(.roundedBorder)
            Toggle("Uhrzeit angeben", isOn: $zeitSetzen)
                .font(.subheadline)
            if zeitSetzen {
                HStack(spacing: 10) {
                    TextField("HH:MM", text: $zeittext)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
                        .frame(width: 110)
                    if zeitteile == nil {
                        Text("Bitte als Uhrzeit, z.\u{00A0}B. 9:05")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    } else {
                        Text("Ortszeit \u{2014} so, wie die Uhr am Ort stand.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                // Ehrlich gesagt, statt eine Reihenfolge zu erfinden: Ohne
                // Uhrzeit weiß niemand, wohin der Punkt in der Tagesfolge
                // gehört — auch die App nicht.
                Text("Ohne Uhrzeit hängt der Punkt am Ende der Tagesspur. Verschieben lässt er sich in der Punktliste.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if aendert {
                Text("Eine geänderte Uhrzeit sortiert den Punkt neu in die Spur ein \u{2014} "
                     + "die Reihenfolge der Liste ist die Reihenfolge der gezeichneten Linie.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: 10) {
                if aendert {
                    Button(role: .destructive) {
                        loeschfrage = true
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
                Button {
                    punktSetzen()
                } label: {
                    Label(aendert ? "Übernehmen" : "Punkt hier setzen",
                          systemImage: aendert ? "checkmark" : "mappin.and.ellipse")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(mitte == nil || (zeitSetzen && zeitteile == nil))
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(12)
    }

    @ViewBuilder
    private var trefferliste: some View {
        if !treffer.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(treffer, id: \.self) { eintrag in
                    Button {
                        let ort = eintrag.placemark.coordinate
                        kamera = .region(MKCoordinateRegion(
                            center: ort,
                            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)))
                        name = eintrag.name ?? name
                        treffer = []
                        suche = ""
                    } label: {
                        VStack(alignment: .leading) {
                            Text(eintrag.name ?? "Ohne Namen").font(.subheadline)
                            if let gegend = eintrag.placemark.locality {
                                Text(gegend).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
            .padding(.horizontal, 14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(10)
        } else if sucheLaeuft {
            ProgressView().padding(8)
        }
    }

    private func starten() {
        // Nur EINMAL: `.task` läuft auch nach einem Wechsel in den
        // Hintergrund noch einmal, und dann stünde die gerade verschobene
        // Karte wieder auf dem Ausgangspunkt.
        guard !geladen else { return }
        geladen = true
        punktID = start
        let anfang = punkt ?? tag?.spur.last
        if let anfang {
            kamera = .region(MKCoordinateRegion(
                center: anfang.koordinate.clLocation, span: spanne))
            mitte = anfang.koordinate
        }
        guard let punkt else { return }
        // Beim Ändern steht schon etwas da — und es bleibt stehen: Der
        // Name wird NICHT vom Geocoder überschrieben.
        name = punkt.name
        nameGeholt = true
        if let zeit = punkt.zeit {
            zeitSetzen = true
            zeittext = Self.uhrzeit.string(from: zeit)
        }
    }

    // Dieselbe feste Zone wie überall: Eine Uhrzeit ist die Wanduhr am Ort
    // (siehe `Dienste/Ortszeit.swift`).
    private static let uhrzeit: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    // Was getippt wurde, als Stunde und Minute — oder nil, wenn es keine
    // Uhrzeit ist. Angenommen wird „9:05", „9.05", „0905" und „9".
    private var zeitteile: (stunde: Int, minute: Int)? {
        let roh = zeittext.trimmingCharacters(in: .whitespaces)
        guard !roh.isEmpty else { return nil }
        var stunde = 0
        var minute = 0
        if roh.contains(":") || roh.contains(".") {
            let teile = roh.split(whereSeparator: { $0 == ":" || $0 == "." })
            guard let erste = teile.first, let s = Int(erste) else { return nil }
            stunde = s
            if teile.count > 1 {
                guard let m = Int(teile[1]) else { return nil }
                minute = m
            }
        } else {
            guard roh.allSatisfy(\.isNumber) else { return nil }
            if roh.count <= 2 {
                guard let s = Int(roh) else { return nil }
                stunde = s
            } else {
                guard let s = Int(roh.prefix(roh.count - 2)),
                      let m = Int(roh.suffix(2)) else { return nil }
                stunde = s
                minute = m
            }
        }
        guard (0...23).contains(stunde), (0...59).contains(minute) else { return nil }
        return (stunde, minute)
    }

    private func nameHolen() async {
        guard let mitte, !nameGeholt else { return }
        // Der Name wird NACHGETRAGEN und nicht abgewartet. Wer auf den
        // Geocoder wartet, bevor der Punkt gesetzt werden kann, baut einen
        // Knopf, der eine Sekunde lang nichts tut.
        guard let gefunden = await Ortsname.suchen(mitte) else { return }
        if self.mitte == mitte { name = gefunden; nameGeholt = true }
    }

    // Zurück auf „ein neuer Punkt". An EINER Stelle, weil es drei Wege
    // dorthin gibt (der Knopf in der Kopfzeile der Leiste, der nach dem
    // Übernehmen und der nach dem Löschen) und drei Fassungen davon
    // auseinanderliefen — der Name des gelöschten Punktes stünde dann beim
    // nächsten im Feld.
    private func neuerPunkt() {
        quittung = nil
        punktID = nil
        name = ""
        nameGeholt = false
        zeitSetzen = false
        zeittext = ""
        Task { await nameHolen() }
    }

    private func punktSetzen() {
        guard let mitte else { return }
        let uhrzeit: Date? = zeitSetzen ? zeitAmTag() : nil
        let wie = name.isEmpty ? "ohne Namen" : name
        // WAS ÜBERNOMMEN WURDE, steht in der Quittung — und zwar
        // vollständig: Ort, Name und Uhrzeit. „Gespeichert" allein wäre
        // keine Bestätigung, sondern eine Behauptung; wer eine Uhrzeit
        // getippt hat, will genau diese Uhrzeit zurückgelesen bekommen.
        var satz = wie
        if let uhrzeit { satz += " \u{00B7} " + uhrzeittext(uhrzeit) }
        else { satz += " \u{00B7} ohne Uhrzeit" }
        if let punktID {
            werk.punktAendern(tagID, punktID: punktID, ort: mitte, name: name, zeit: uhrzeit)
            quittung = "Übernommen: \(satz)"
        } else {
            werk.punktHinzufuegen(tagID, ort: mitte, name: name, zeit: uhrzeit)
            quittung = "Neuer Punkt gesetzt: \(satz)"
        }
    }

    // Die Uhrzeit so, wie sie am Ort stand — also in derselben festen Zone
    // gelesen, in der `zeitAmTag` sie geschrieben hat. Mit der Zone des
    // Geräts gelesen stünde in der Quittung eine andere Zahl als die
    // getippte, und das sähe wie ein Fehler aus.
    private func uhrzeittext(_ zeitpunkt: Date) -> String {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let teile = kalender.dateComponents([.hour, .minute], from: zeitpunkt)
        return String(format: "%02d:%02d", teile.hour ?? 0, teile.minute ?? 0)
    }

    // Die Uhrzeit gehört auf den TAG des Eintrags, nicht auf heute — sonst
    // sortierte sich der Punkt hinter alle Fotos, weil er ein halbes Jahr
    // in der Zukunft läge.
    private func zeitAmTag() -> Date? {
        guard let tag else { return nil }
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        guard let teile = zeitteile else { return nil }
        var werte = DateComponents()
        werte.year = tag.datum.jahr
        werte.month = tag.datum.monat
        werte.day = tag.datum.tag
        werte.hour = teile.stunde
        werte.minute = teile.minute
        return kalender.date(from: werte)
    }

    private func ortSuchen() async {
        guard suche.count >= 2 else { return }
        sucheLaeuft = true
        let wunsch = MKLocalSearch.Request()
        wunsch.naturalLanguageQuery = suche
        if let mitte {
            wunsch.region = MKCoordinateRegion(
                center: mitte.clLocation,
                span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2))
        }
        let antwort = try? await MKLocalSearch(request: wunsch).start()
        treffer = Array((antwort?.mapItems ?? []).prefix(8))
        sucheLaeuft = false
    }

    // Wo dieser Punkt in der Tagesfolge steht — die Angabe, die in der
    // Liste die Zeile darunter trägt und hier sonst fehlte.
    private func stellensatz(_ eintrag: Reisepunkt) -> String {
        var teile: [String] = []
        if let spur = tag?.spur, let stelle = spur.firstIndex(where: { $0.id == eintrag.id }) {
            teile.append("Punkt \(stelle + 1) von \(spur.count)")
        }
        teile.append(eintrag.zeit.map { Self.uhrzeit.string(from: $0) } ?? "ohne Uhrzeit")
        teile.append(eintrag.quelle.name)
        return teile.joined(separator: " \u{00B7} ")
    }
}

// Ein Reisepunkt auf der Karte — als BILD und nicht als Knopf.
//
// `.allowsHitTesting(false)` ist hier der ganze Punkt: Diese Marke darf
// keinen Finger annehmen, sonst schluckt sie die Zoomgeste der Karte
// (Abfahrtstafel 1.1.18). Den Tipp wertet `PunktwahlView.punktBei` aus.
//
// Der GEWÄHLTE Punkt wird größer und bekommt einen Ring. Das ist keine
// Zierde: Der Knopf unten heißt „Übernehmen" und schreibt auf genau diesen
// Punkt — welcher es ist, muss auf der Karte zu sehen sein.
private struct Spurmarke: View {
    let punkt: Reisepunkt
    let gewaehlt: Bool
    /// Ob dieser Punkt aus der Linie springt. Gezeichnet wird orange UND
    /// mit einem Dreieck — Farbe allein sieht ein farbfehlsichtiger Mensch
    /// nicht; dieselbe Regel wie beim entfallenden Halt in der
    /// Abfahrtstafel.
    var auffaellig = false

    var body: some View {
        ZStack {
            if gewaehlt {
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 2.5)
                    .background(Circle().fill(.white.opacity(0.65)))
                    .frame(width: 30, height: 30)
            }
            Image(systemName: auffaellig
                  ? "exclamationmark.triangle.fill"
                  : (punkt.istAusFoto ? "camera.fill" : "mappin.circle.fill"))
                .font(.system(size: gewaehlt ? 15 : 12))
                .foregroundStyle(auffaellig
                                 ? Color.orange
                                 : (punkt.istAusFoto ? Color.blue : Color.accentColor))
                .shadow(color: .white.opacity(0.9), radius: 1.5)
        }
        .allowsHitTesting(false)
    }
}
