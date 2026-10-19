import SwiftUI
import MapKit

// EINE AUTOFAHRT UNTER IHREM TAG (neu gebaut in 1.0.36, gemeldet 09/2026
// mit Bildschirmfoto: „Ist leider nicht mehr zu erkennen, man kann sie weder
// von rechts nach links wischen, noch ausklappen und Genaueres erfahren").
//
// Bis 1.0.35 eine Zeile roter Text auf dunkelrotem Grund, auf eine Zeile
// gekürzt („Ramsau bei Berchtesgaden → Ramsau b…"), löschen nur per
// langem Druck. Jetzt:
// - **Zwei Zeilen**: der Weg in normaler Schrift (bis zu zwei Zeilen), darunter
//   Uhrzeit, Kilometer und Dauer grau. Nur das Auto-Zeichen trägt die Farbe
//   der Fahrten.
// - **Wischen nach links** zeigt „Entfernen"; weit gewischt entfernt es
//   gleich. Die Zeile liegt in einer ScrollView, nicht in einer `List` —
//   `.swipeActions` gibt es dort nicht. Die Geste ist `simultaneousGesture`
//   und reagiert nur, wenn waagerecht gezogen wird, sonst schluckte sie das
//   Blättern (iOS 18).
// - **Tippen** öffnet `Fahrtdetail`: Karte der Fahrt, Start, Ziel, Zeiten,
//   Länge, Dauer, Schnitt, „Fahrt abfahren", „Fahrt entfernen".
// Entfernen geht über `Fahrtenimport.loeschen` — mit Rückgängig.
struct Fahrtzeile: View {
    @ObservedObject var spur: Spur
    let darf: Bool
    let palette: Palette
    @ObservedObject private var farben = Kartenfarben.shared
    @State private var versatz: CGFloat = 0
    @State private var offen = false
    @State private var detail = false

    private static let knopfbreite: CGFloat = 96

    var body: some View {
        // Gelöscht (auch über Rückgängig-Wege oder iCloud): nichts mehr
        // aus dem Objekt lesen.
        if spur.isDeleted || spur.managedObjectContext == nil {
            EmptyView()
        } else {
            zeile
        }
    }

    private var zeile: some View {
        inhalt
            .background(Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .offset(x: versatz)
            .onTapGesture {
                if offen { zuklappen() } else { detail = true }
            }
            .simultaneousGesture(wischen, including: darf ? .all : .subviews)
            // Der Knopf liegt HINTER der Zeile und wird beim Wischen frei.
            .background(alignment: .trailing) {
                if darf && versatz < 0 {
                    Button(role: .destructive) { entfernen() } label: {
                        Label("Entfernen", systemImage: "trash")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: Self.knopfbreite)
                            .frame(maxHeight: .infinity)
                            .background(Color.red, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        .contextMenu {
            Button { detail = true } label: { Label("Einzelheiten", systemImage: "info.circle") }
            if darf {
                Button(role: .destructive) { Fahrtenimport.loeschen(spur) } label: {
                    Label("Fahrt entfernen", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $detail) {
            Fahrtdetail(spur: spur, darf: darf, palette: palette)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Einzelheiten") { detail = true }
        .accessibilityAction(named: "Fahrt entfernen") { if darf { Fahrtenimport.loeschen(spur) } }
    }

    private var inhalt: some View {
        let d = Fahrtdaten(spur)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "car.fill")
                .font(.subheadline)
                .foregroundStyle(farben.fahrt)
                .frame(width: 24)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(d.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(d.unterzeile)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var wischen: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { w in
                // Nur waagerecht — senkrecht gehört dem Blättern.
                guard abs(w.translation.width) > abs(w.translation.height) * 1.5 else { return }
                let start: CGFloat = offen ? -Self.knopfbreite : 0
                versatz = min(0, start + w.translation.width)
            }
            .onEnded { w in
                guard abs(w.translation.width) > abs(w.translation.height) * 1.5 else {
                    withAnimation(.snappy) { versatz = offen ? -Self.knopfbreite : 0 }
                    return
                }
                let start: CGFloat = offen ? -Self.knopfbreite : 0
                let ende = start + w.predictedEndTranslation.width
                if ende < -220 {
                    entfernen()
                } else if ende < -Self.knopfbreite / 2 {
                    withAnimation(.snappy) { versatz = -Self.knopfbreite; offen = true }
                } else {
                    zuklappen()
                }
            }
    }

    private func zuklappen() {
        withAnimation(.snappy) { versatz = 0; offen = false }
    }

    private func entfernen() {
        withAnimation(.snappy) { versatz = 0; offen = false }
        Fahrtenimport.loeschen(spur)
    }
}

/// Was sich aus einer Fahrt ablesen lässt — an einer Stelle für Zeile und
/// Einzelheiten.
struct Fahrtdaten {
    let name: String
    let start: String?
    let ziel: String?
    let punkte: [Spurpunkt]
    let zone: TimeZone
    let meter: Double

    init(_ spur: Spur) {
        name = Fahrtenimport.anzeigename(spur)
        let teile = name.components(separatedBy: " → ")
        start = teile.count == 2 ? teile[0] : nil
        ziel = teile.count == 2 ? teile[1] : nil
        punkte = spur.punktListe
        zone = Fahrtenimport.zone(spur)
        meter = spur.distanz
    }

    var anfang: Date? { punkte.first?.datum }
    var ende: Date? { punkte.last?.datum }
    var dauer: TimeInterval? {
        guard let a = anfang, let e = ende, e > a else { return nil }
        return e.timeIntervalSince(a)
    }

    func uhr(_ d: Date?) -> String { d.map { Tag.text($0, "HH:mm", zone: zone) } ?? "" }

    var zeitspanne: String {
        guard anfang != nil else { return "" }
        return uhr(anfang) + (ende.map { _ in "–" + uhr(ende) } ?? "")
    }

    var dauertext: String? {
        guard let dauer else { return nil }
        let min = Int((dauer / 60).rounded())
        return min >= 60 ? "\(min / 60) h \(String(format: "%02d", min % 60)) min" : "\(min) min"
    }

    var schnitt: String? {
        guard let dauer, dauer > 60, meter > 0 else { return nil }
        return String(format: "%.0f km/h", meter / 1000 / (dauer / 3600))
    }

    var unterzeile: String {
        [zeitspanne, Tagesspurwahl.kilometertext(meter / 1000), dauertext ?? ""]
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// Einzelheiten einer Autofahrt (ab 1.0.36).
struct Fahrtdetail: View {
    @ObservedObject var spur: Spur
    let darf: Bool
    let palette: Palette
    @Environment(\.dismiss) private var schliessen
    @ObservedObject private var farben = Kartenfarben.shared
    @State private var abfahren = false

    var body: some View {
        if spur.isDeleted || spur.managedObjectContext == nil {
            Color.clear
        } else {
            inhalt
        }
    }

    private var inhalt: some View {
        let d = Fahrtdaten(spur)
        return NavigationStack {
            List {
                if d.punkte.count > 1 {
                    Section {
                        Map(initialPosition: .automatic, interactionModes: [.zoom, .pan]) {
                            MapPolyline(coordinates: d.punkte.map(\.koordinate))
                                .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                            MapPolyline(coordinates: d.punkte.map(\.koordinate))
                                .stroke(farben.fahrt, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                            if let a = d.punkte.first {
                                Annotation("Start", coordinate: a.koordinate) {
                                    Circle().fill(.green).frame(width: 13, height: 13)
                                        .overlay(Circle().stroke(.white, lineWidth: 2))
                                }
                            }
                            if let b = d.punkte.last {
                                Annotation("Ziel", coordinate: b.koordinate) {
                                    Circle().fill(.red).frame(width: 13, height: 13)
                                        .overlay(Circle().stroke(.white, lineWidth: 2))
                                }
                            }
                        }
                        .mapStyle(.standard(pointsOfInterest: .excludingAll))
                        .frame(height: 240)
                        .listRowInsets(EdgeInsets())
                    }
                }
                Section {
                    if let start = d.start, let ziel = d.ziel {
                        zeile("Start", start + (d.anfang.map { _ in " · " + d.uhr(d.anfang) } ?? ""))
                        zeile("Ziel", ziel + (d.ende.map { _ in " · " + d.uhr(d.ende) } ?? ""))
                    } else {
                        zeile("Fahrt", d.name)
                        if !d.zeitspanne.isEmpty { zeile("Zeit", d.zeitspanne) }
                    }
                    if let t = d.dauertext { zeile("Dauer", t) }
                    let km = Tagesspurwahl.kilometertext(d.meter / 1000)
                    if !km.isEmpty { zeile("Strecke", km) }
                    if let v = d.schnitt { zeile("Schnitt", v) }
                    zeile("Messpunkte", "\(d.punkte.count)")
                    if d.zone.identifier != TimeZone.current.identifier {
                        zeile("Ortszeit", d.zone.abbreviation(for: d.anfang ?? Date()) ?? d.zone.identifier)
                    }
                }
                Section {
                    if d.punkte.count > 1 {
                        Button { abfahren = true } label: { Label("Fahrt abfahren", systemImage: "play.fill") }
                    }
                    if darf {
                        Button(role: .destructive) {
                            Fahrtenimport.loeschen(spur)
                            schliessen()
                        } label: { Label("Fahrt entfernen", systemImage: "trash") }
                    }
                } footer: {
                    if darf { Text("Entfernen lässt sich rückgängig machen.") }
                }
            }
            .navigationTitle("Autofahrt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } }
            }
            .fullScreenCover(isPresented: $abfahren) {
                Tagesfahrt(titel: d.name,
                           linien: [Tagesspurkarte.Linie(id: "fahrt", punkte: d.punkte.map(\.koordinate), art: .fahrt,
                                                         zeiten: d.punkte.map(\.zeit), name: d.name, zone: d.zone)],
                           zone: d.zone, palette: palette)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func zeile(_ titel: String, _ wert: String) -> some View {
        LabeledContent(titel) {
            Text(wert).multilineTextAlignment(.trailing)
        }
    }
}
