import SwiftUI
import CoreData
import CoreLocation

// ALLE PUNKTE DES TAGES ALS LISTE (ab 1.0.33, Ansage des Nutzers 09/2026:
// „dass alle Punkte auf einer Liste aufgeführt werden, bei der ich schnell
// auch durch Wischen Punkte löschen kann").
//
// Je Linie (Spur, Autofahrt, Wanderung) ein Abschnitt, jeder Punkt eine
// Zeile mit Uhrzeit und Abstand zum vorigen — ein Ausreißer fällt an einem
// großen Sprung auf. Wischen löscht, „Auswählen" löscht mehrere auf einmal,
// ein Tipp zeigt den Punkt auf der Karte (das Blatt steht halb hoch, die
// Karte bleibt darüber bedienbar). Gelöscht wird über `Spurbearbeitung` —
// dieselben Regeln wie beim Tipp auf die Karte, samt Rohspur und Rückgängig.
struct Punkteliste: View {
    let titel: String
    let palette: Palette
    /// Holt die Linien des Tages frisch — nach jedem Löschen neu.
    let laden: () -> [Tagesspurkarte.Linie]
    let zone: TimeZone
    /// Ein Tipp auf eine Zeile: diesen Punkt auf der Karte zeigen.
    var zeigen: (Zeitpunkt) -> Void = { _ in }

    @Environment(\.dismiss) private var schliessen
    @ObservedObject private var farben = Kartenfarben.shared
    @ObservedObject private var rueckgaengig = Rueckgaengig.shared
    @State private var abschnitte: [Abschnitt] = []
    @State private var auswahl: Set<String> = []
    @State private var bearbeiten: EditMode = .inactive

    struct Zeile: Identifiable {
        let punkt: Zeitpunkt
        let abstand: Double?
        var id: String { punkt.id }
    }

    struct Abschnitt: Identifiable {
        let id: String
        let art: Spurart
        let name: String
        let darf: Bool
        var zeilen: [Zeile]
    }

    var body: some View {
        NavigationStack {
            List(selection: $auswahl) {
                if abschnitte.isEmpty {
                    Text("An diesem Tag gibt es keine Punkte mit Uhrzeit.").foregroundStyle(.secondary)
                }
                ForEach(abschnitte) { a in
                    Section {
                        ForEach(a.zeilen) { z in
                            zeile(z, in: a)
                                .tag(z.id)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if a.darf {
                                        Button(role: .destructive) { entfernen([z.punkt]) } label: {
                                            Label("Entfernen", systemImage: "trash")
                                        }
                                    }
                                }
                        }
                    } header: {
                        Label(a.name.isEmpty ? a.art.name : "\(a.art.name) · \(a.name)", systemImage: a.art.symbol)
                            .foregroundStyle(farben.farbe(a.art, palette: palette))
                    } footer: {
                        if !a.darf { Text("Nur lesbar — diese Linie darfst du nicht bearbeiten.") }
                    }
                }
            }
            .environment(\.editMode, $bearbeiten)
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { schliessen() } }
                ToolbarItemGroup(placement: .primaryAction) {
                    if rueckgaengig.letzter != nil {
                        Button {
                            rueckgaengig.zuruecknehmen()
                            neuLaden()
                        } label: { Image(systemName: "arrow.uturn.backward") }
                        .accessibilityLabel("Rückgängig: \(rueckgaengig.letzter?.titel ?? "")")
                    }
                    Button(bearbeiten.isEditing ? "Fertig wählen" : "Auswählen") {
                        withAnimation { bearbeiten = bearbeiten.isEditing ? .inactive : .active }
                        auswahl = []
                    }
                }
                if bearbeiten.isEditing {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            let punkte = abschnitte.flatMap(\.zeilen).filter { auswahl.contains($0.id) }.map(\.punkt)
                            entfernen(punkte)
                            auswahl = []
                        } label: {
                            Label(auswahl.count == 1 ? "1 Punkt entfernen" : "\(auswahl.count) Punkte entfernen",
                                  systemImage: "trash")
                        }
                        .disabled(auswahl.isEmpty)
                    }
                }
            }
            .task { neuLaden() }
        }
    }

    private func zeile(_ z: Zeile, in a: Abschnitt) -> some View {
        HStack(spacing: 10) {
            Circle().fill(farben.farbe(a.art, palette: palette)).frame(width: 8, height: 8)
            Text(Tag.text(Date(timeIntervalSince1970: z.punkt.zeit), "HH:mm:ss", zone: z.punkt.zone))
                .monospacedDigit()
            Spacer()
            if let d = z.abstand {
                Text(d >= 1000 ? String(format: "+%.1f km", d / 1000) : String(format: "+%.0f m", d))
                    .font(.caption.monospacedDigit())
                    // Ein großer Sprung ist verdächtig — ein Ausreißer.
                    .foregroundStyle(d > 2000 ? Color.orange : Color.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !bearbeiten.isEditing else { return }
            zeigen(z.punkt)
        }
    }

    private func entfernen(_ punkte: [Zeitpunkt]) {
        for p in punkte where Spurbearbeitung.darf(p) { Spurbearbeitung.punktEntfernen(p) }
        neuLaden()
    }

    private func neuLaden() {
        abschnitte = laden().compactMap { l in
            guard l.zeiten.count == l.punkte.count, !l.punkte.isEmpty else { return nil }
            var zeilen: [Zeile] = []
            var vorher: CLLocation?
            for (k, t) in zip(l.punkte, l.zeiten) {
                let ort = CLLocation(latitude: k.latitude, longitude: k.longitude)
                let p = Zeitpunkt(breite: k.latitude, laenge: k.longitude, zeit: t, art: l.art, name: l.name,
                                  zone: l.zone ?? zone, quelle: l.quelle)
                zeilen.append(Zeile(punkt: p, abstand: vorher.map { ort.distance(from: $0) }))
                vorher = ort
            }
            let erster = zeilen.first?.punkt
            return Abschnitt(id: l.id, art: l.art, name: l.name,
                             darf: erster.map { Spurbearbeitung.darf($0) } ?? false, zeilen: zeilen)
        }
        .sorted { ($0.zeilen.first?.punkt.zeit ?? 0) < ($1.zeilen.first?.punkt.zeit ?? 0) }
    }
}

/// Der Rückgängig-Knopf für die Karten (ab 1.0.33) — rund, wie die Knöpfe
/// daneben; nur sichtbar, wenn es etwas zurückzunehmen gibt.
struct RueckgaengigKnopf: View {
    @ObservedObject private var rueckgaengig = Rueckgaengig.shared
    var nachher: () -> Void = {}

    var body: some View {
        if let letzter = rueckgaengig.letzter {
            Button {
                rueckgaengig.zuruecknehmen()
                nachher()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.body.weight(.semibold))
                    .frame(width: 38, height: 38)
                    .background(.regularMaterial, in: Circle())
            }
            .accessibilityLabel("Rückgängig: \(letzter.titel)")
            .contextMenu {
                Text("Zuletzt: \(letzter.titel)")
            }
        }
    }
}

/// Rückgängig als schlichter Knopf in einer Werkzeugleiste (ab 1.0.33).
struct RueckgaengigLeiste: View {
    @ObservedObject private var rueckgaengig = Rueckgaengig.shared

    var body: some View {
        if let letzter = rueckgaengig.letzter {
            Button { rueckgaengig.zuruecknehmen() } label: {
                Label("Rückgängig", systemImage: "arrow.uturn.backward")
            }
            .accessibilityLabel("Rückgängig: \(letzter.titel)")
        }
    }
}

/// Der Hinweis am unteren Rand nach jedem Schritt, der sich zurücknehmen
/// lässt: „Punkt 14:32 entfernt · Rückgängig" (ab 1.0.33).
struct RueckgaengigHinweis: View {
    @ObservedObject private var rueckgaengig = Rueckgaengig.shared

    var body: some View {
        VStack {
            if let neu = rueckgaengig.neu {
                hinweis(neu)
            }
        }
        .animation(.spring(duration: 0.4), value: rueckgaengig.neu?.id)
    }

    private func hinweis(_ neu: Rueckgaengig.Schritt) -> some View {
        HStack(spacing: 12) {
            Text(neu.titel).font(.callout.weight(.medium)).lineLimit(1)
            Button("Rückgängig") { rueckgaengig.zuruecknehmen() }
                .font(.callout.weight(.bold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial, in: Capsule())
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
