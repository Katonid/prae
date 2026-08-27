import SwiftUI

/// Zufälliger Name — das meistgenutzte Element.
///
/// Aufbau und Maße folgen der Web-App (`.w-random` im Stylesheet): oben eine
/// Zeile mit Listenname und Zähler, darunter frei der Name, unten ein
/// Hinweis und wahlweise die Liste der gezogenen Namen. **Bewusst ohne
/// Knöpfe** — gezogen und aufgedeckt wird durch Tippen auf die Karte.
///
/// Damit niemand versehentlich zieht, braucht der erste Tipp nur die
/// Aufmerksamkeit des Elements („scharf"), erst der zweite zieht.
///
/// Zwei Ziehweisen: „ohne Wiederholung" (jeder kommt erst wieder in den Topf,
/// wenn die Liste durch ist) und „immer alle Namen". Der gezogene Name kann
/// schrittweise aufgedeckt werden (Mosaik, Unschärfe oder Buchstabe für
/// Buchstabe), damit die Klasse mitraten darf.
struct NamePickerWidgetView: View {
    @Binding var content: NamePickerContent
    var interactive: Bool
    var list: NameList?
    /// Öffnet die Einstellungen (Liste wählen, Modus).
    var onOpenSettings: () -> Void
    /// Löscht einen Eintrag dauerhaft aus der Namensliste.
    var onDeleteEntry: (NameEntry) -> Void

    @Environment(\.boardStyle) private var style
    @Environment(\.widgetMetrics) private var metrics

    @State private var spinText: String?
    @State private var pulse = false
    @State private var confettiTrigger = 0
    /// Erster Tipp macht scharf, zweiter zieht.
    @State private var armed = false

    var body: some View {
        // Der Modus entscheidet, was zu sehen ist. Die Einzelziehung ist die
        // alte Ansicht; Gruppen und Tagesgruppe teilen sich eine eigene.
        switch content.modus {
        case .einzel:
            einzelAnsicht
        case .gruppen, .tagesgruppe:
            GruppenAnsicht(content: $content, interactive: interactive,
                           list: list, onOpenSettings: onOpenSettings)
        }
    }

    private var einzelAnsicht: some View {
        GeometryReader { geo in
            VStack(spacing: metrics.em(0.55)) {
                // `.w-random__display` — Überschrift, Name und Hinweis
                // stehen als EINE Gruppe in der Mitte. Vorher klebte die
                // Überschrift oben am Rand und der Name schwebte weit
                // darunter; zusammengehörendes gehört zusammen.
                VStack(spacing: metrics.em(0.3)) {
                    if zeigtKopf { ueberschrift }
                    nameBox(size: freierRaum(geo))
                    if style.showLabels {
                        Text(hint)
                            .font(Theme.font(metrics.em(0.84), weight: .medium))
                            .foregroundStyle(armed && style.bare ? style.accent : style.inkSoft)
                            .opacity(armed ? 1 : 0.8)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay { ConfettiView(trigger: confettiTrigger) }

                if showsDrawnList && !drawnEntries.isEmpty {
                    history
                        .frame(maxHeight: geo.size.height * 0.36)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Der Zähler bleibt oben rechts stehen, wo ihn die Web-App auch
            // hat (`.w-random__count`) — er gehört zur Liste, nicht zum Namen.
            .overlay(alignment: .topTrailing) {
                if style.showLabels { zaehler }
            }
        }
        // `.w-random { padding: 1.05em 1.2em 0.95em }`
        .padding(.top, metrics.em(1.05))
        .padding(.horizontal, metrics.em(1.2))
        .padding(.bottom, metrics.em(0.95))
        .contentShape(Rectangle())
        .onTapGesture { tap() }
        .overlay {
            // `.widget.is-armed` — ein Ring in der Akzentfarbe zeigt, dass
            // der nächste Tipp zieht.
            RoundedRectangle(cornerRadius: Theme.widgetCorner, style: .continuous)
                .strokeBorder(style.accent.opacity(armed && !style.bare ? 0.9 : 0), lineWidth: 3)
                .animation(.easeInOut(duration: 0.2), value: armed)
        }
    }

    // MARK: - Kopfzeile

    /// Ist eine Überschrift zu sehen?
    ///
    /// Eine selbst gesetzte immer — sie benennt das Element und gehört damit
    /// zum Inhalt, nicht zur Zier. Wer mehrere Ziehungen nebeneinander hat,
    /// muss sie auseinanderhalten können, auch wenn die Tafel unter
    /// „Aussehen“ keine Beschriftungen zeigt. Ohne eigene Überschrift steht
    /// dort der Listenname — der folgt weiter der Tafelregel, wie
    /// `.w-random__head` in der Web-App.
    private var zeigtKopf: Bool { eigeneUeberschrift != nil || style.showLabels }

    private var eigeneUeberschrift: String? { content.title.nonEmpty }

    /// Die Überschrift über dem Namen.
    ///
    /// Deutlich größer als die Zeile in der Web-App (dort 0,77em, gedacht
    /// als beiläufiger Listenname). Sobald sie selbst gesetzt wird, ist sie
    /// die Aufschrift des Elements und muss aus der letzten Reihe zu lesen
    /// sein. Eine eigene Überschrift steht so da, wie sie eingetippt wurde;
    /// der Listenname bleibt in Großbuchstaben, wie im Web.
    private var ueberschrift: some View {
        Text(eigeneUeberschrift ?? listTitle.uppercased())
            .font(Theme.font(kopfGroesse, weight: .bold))
            .tracking(kopfGroesse * 0.05)
            .foregroundStyle(style.inkSoft)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
    }

    private var kopfGroesse: Double { metrics.em(style.kopf(1.25)) }

    /// Wie viel Höhe die Überschrift der Namenszeile wegnimmt.
    private func freierRaum(_ geo: GeometryProxy) -> CGSize {
        guard zeigtKopf else { return geo.size }
        return CGSize(width: geo.size.width,
                      height: max(60, geo.size.height - kopfGroesse * 1.6))
    }

    /// `.w-random__count`: Pille in der ruhigen Füllung.
    private var zaehler: some View {
        Text(countText)
            .font(Theme.font(metrics.em(0.84), weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(style.inkSoft)
            .padding(.horizontal, metrics.em(0.84 * 0.7))
            .padding(.vertical, metrics.em(0.84 * 0.2))
            .background { Capsule().fill(style.wash) }
            .lineLimit(1)
    }

    private var listTitle: String {
        if let list { return list.name }
        return content.listID == nil ? "Keine Liste" : "Liste wird geladen"
    }

    private var countText: String {
        guard let list else { return "—" }
        let all = list.activeEntries.count
        return content.mode == .withoutRepeat ? "\(remaining.count)/\(all)" : "\(all) Namen"
    }

    // MARK: - Namensfeld

    /// `.w-random__namebox` — der Name, darüber bei Bedarf das Mosaik.
    @ViewBuilder
    private func nameBox(size: CGSize) -> some View {
        let text = displayName
        let fontSize = nameSize(size, text: text)
        ZStack {
            Text(hidden && revealMode == .letters ? maskedLetters(text) : text)
                .font(Theme.font(fontSize, weight: .heavy))
                .tracking(-fontSize * 0.02)
                .lineSpacing(fontSize * 0.05)
                .foregroundStyle(hasName ? style.bigText
                                         : AnyShapeStyle(style.inkSoft.opacity(style.bare ? 0.6 : 0.55)))
                .lineLimit(2)
                .minimumScaleFactor(0.4)
                .multilineTextAlignment(.center)
                .blur(radius: blurRadius(fontSize: fontSize))
                .scaleEffect(pulse ? 1.06 : 1.0)
                .animation(.easeOut(duration: 0.25), value: content.revealParts.count)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .overlay {
                    if hidden && revealMode == .mosaik {
                        // `.w-random__mask { inset: -8px -6px }`
                        mosaic.padding(.horizontal, -6).padding(.vertical, -8)
                    }
                }
        }
        .frame(maxWidth: .infinity)
        // Jeder gezogene Name bekommt eine eigene Identität.
        //
        // Sonst blendet SwiftUI die Verdeckung ein: Unschärfe und Mosaik
        // hängen an der Zahl der aufgedeckten Teile, und die springt beim
        // Ziehen von „alles aufgedeckt" auf „nichts aufgedeckt". Das ist
        // eine Wertänderung wie jede andere — also lief die Bewegung
        // rückwärts ab, und der neue Name stand für eine Viertelsekunde
        // scharf und offen da. Mit neuer Identität beginnt die Ansicht
        // beim Zielzustand: verdeckt ab dem ersten Bild.
        .id(content.currentID ?? "leer")
    }

    /// Feines Kachelraster über dem Namen — jede Kachel verschwindet einzeln.
    private var mosaic: some View {
        let open = Set(content.revealParts)
        return VStack(spacing: 0) {
            ForEach(0..<MosaikMasse.zeilen, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<MosaikMasse.spalten, id: \.self) { column in
                        let index = row * MosaikMasse.spalten + column
                        Rectangle()
                            .fill(mosaicFill)
                            .opacity(open.contains(index) ? 0 : 1)
                            // Leichte Überlappung: sonst blitzt der Name in
                            // den Fugen des Rasters durch.
                            .scaleEffect(open.contains(index) ? 0.5 : 1.08)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.easeOut(duration: 0.4), value: content.revealParts.count)
    }

    /// Helle Kacheln wie in der Web-App — sie verdecken, ohne zu schreien.
    private var mosaicFill: LinearGradient {
        LinearGradient(colors: (style.isDarkCard || style.bare)
                       ? [Color(hex: "#334155"), Color(hex: "#1e293b")]
                       : [Color(hex: "#e6e9f5"), Color(hex: "#cdd5f3")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Schriftgröße wie `fitName()` in der Web-App: Sie richtet sich nach der
    /// Elementgröße und der Länge des Namens, nicht nach dem Maßstab.
    private func nameSize(_ size: CGSize, text: String) -> Double {
        let boxWidth = max(140, Double(size.width) - 70 + metrics.em(2.4))
        let fitted = min(Double(size.height) * 0.29 + metrics.em(2),
                         boxWidth / max(4, Double(text.count) * 0.6))
        return max(20, min(fitted, 128))
    }

    /// Die Unschärfe richtet sich nach der Schriftgröße — sonst bliebe ein
    /// großer Name auch mit festem Wert lesbar.
    private func blurRadius(fontSize: Double) -> Double {
        guard hidden, revealMode == .blur else { return 0 }
        let progress = min(1, Double(content.revealParts.count) / Double(RevealLayout.blurSteps))
        return fontSize * 0.42 * pow(1 - progress, 1.5) + 1.5
    }

    private func maskedLetters(_ name: String) -> String {
        let indexes = Self.maskableIndexes(name)
        let openSlots = Set(content.revealParts.compactMap { slot -> Int? in
            indexes.indices.contains(slot) ? indexes[slot] : nil
        })
        return String(Array(name).enumerated().map { position, character in
            (indexes.contains(position) && !openSlots.contains(position)) ? "•" : character
        })
    }

    private var hint: String {
        if list == nil { return "Einstellungen öffnen und eine Liste wählen." }
        if entries.isEmpty { return "Einstellungen öffnen und Namen eintragen." }
        if hidden {
            let perTap = revealMode == .mosaik ? MosaikMasse.proTipp : 1
            let total = max(1, Int(ceil(Double(revealTotal) / Double(perTap))))
            let done = min(total, Int(ceil(Double(content.revealParts.count) / Double(perTap))))
            return "Tippen deckt auf — Schritt \(done) von \(total)"
        }
        if roundComplete { return "Alle Namen gezogen." }
        return armed ? "Bereit — der nächste Tipp zieht"
                     : "Antippen, dann nochmal tippen zum Ziehen"
    }

    // MARK: - Gezogene Namen

    private var showsDrawnList: Bool {
        // Im Unterricht bleibt die Liste bei „Beim Bearbeiten" verborgen —
        // so lässt sich nicht ablesen, wer noch fehlt.
        content.showDrawn.applies(editing: !interactive)
    }

    /// `.w-random__drawn` — durch eine Linie abgesetzt, darüber die
    /// Überschrift mit der Anzahl.
    private var history: some View {
        // Der aktuelle Name bleibt verborgen, solange er nicht aufgedeckt ist.
        let shown = hidden ? drawnEntries.filter { $0.id != content.currentID } : drawnEntries
        return VStack(alignment: .leading, spacing: 7) {
            Rectangle().fill(style.line).frame(height: 1)
            HStack {
                Text("GEZOGEN (\(shown.count))")
                    .font(Theme.font(metrics.em(0.77), weight: .heavy))
                    .tracking(metrics.em(0.77) * 0.08)
                    .foregroundStyle(style.inkSoft)
                Spacer(minLength: 0)
                Button {
                    guard interactive else { return }
                    withAnimation { resetRound() }
                } label: {
                    Text("Zurücksetzen")
                        .font(Theme.font(metrics.em(0.77), weight: .semibold))
                        .foregroundStyle(style.accent)
                }
                .buttonStyle(.plain)
                .disabled(!interactive)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: metrics.em(0.4)) {
                    ForEach(shown) { entry in
                        Menu {
                            Button {
                                withAnimation { putBack(entry) }
                            } label: {
                                Label("Zurück in den Topf", systemImage: "arrow.uturn.backward")
                            }
                            Button(role: .destructive) {
                                withAnimation {
                                    putBack(entry)
                                    onDeleteEntry(entry)
                                }
                            } label: {
                                Label("Aus Liste löschen", systemImage: "trash")
                            }
                        } label: {
                            let current = entry.id == content.currentID
                            Text(entry.text)
                                .font(Theme.font(metrics.em(0.84), weight: .semibold))
                                .foregroundStyle(current ? Color.white : style.ink)
                                .lineLimit(1)
                                .padding(.horizontal, metrics.em(0.7))
                                .padding(.vertical, metrics.em(0.32))
                                .background {
                                    Capsule().fill(current
                                                   ? AnyShapeStyle(style.accentGradient)
                                                   : AnyShapeStyle(style.wash))
                                }
                        }
                        .disabled(!interactive)
                    }
                }
                .padding(.bottom, 2)
            }
            .scrollDisabled(!interactive)
        }
    }

    // MARK: - Ableitungen

    private var entries: [NameEntry] { list?.activeEntries ?? [] }

    /// Noch nicht gezogene Namen (bei „immer alle Namen" die ganze Liste).
    private var remaining: [NameEntry] {
        guard content.mode == .withoutRepeat else { return entries }
        let drawn = Set(content.drawnIDs)
        return entries.filter { !drawn.contains($0.id) }
    }

    private var drawnEntries: [NameEntry] {
        Array(content.drawnIDs.compactMap { id in entries.first { $0.id == id } }.reversed())
    }

    private var roundComplete: Bool {
        content.mode == .withoutRepeat && !entries.isEmpty && remaining.isEmpty
    }

    private var currentEntry: NameEntry? {
        guard let currentID = content.currentID else { return nil }
        return entries.first { $0.id == currentID }
    }

    private var hasName: Bool { spinText != nil || currentEntry != nil }

    private var displayName: String {
        if let spinText { return spinText }
        if let entry = currentEntry { return entry.text }
        // Die Tafel nennt eine Liste, die hier noch fehlt — sie wird geholt.
        if list == nil, content.listID != nil { return "Liste wird geladen ..." }
        if list == nil { return "Keine Liste" }
        if entries.isEmpty { return "Keine Namen" }
        return "Bereit"
    }

    // MARK: - Aufdecken

    private var revealMode: RevealMode { content.reveal }

    private var revealTotal: Int {
        content.aufdeckSchritte(name: currentEntry?.text ?? "")
    }

    /// Ist gerade ein Name im Spiel, der noch nicht ganz zu sehen ist?
    private var hidden: Bool {
        guard spinText == nil, let entry = currentEntry else { return false }
        return content.istVerdeckt(name: entry.text)
    }

    /// Zeichen, die verdeckt werden können (Buchstaben und Ziffern).
    private static func maskableIndexes(_ name: String) -> [Int] {
        NamePickerContent.verdeckbareStellen(name)
    }

    // MARK: - Aktionen

    /// Ein Tipp auf die Karte. Beim Aufdecken wirkt er sofort; zum Ziehen
    /// braucht es zwei — sonst zieht ein Wischer versehentlich neu.
    private func tap() {
        guard interactive else { return }
        if hidden {
            revealStep()
            return
        }
        guard !entries.isEmpty else {
            onOpenSettings()
            return
        }
        if armed {
            armed = false
            draw()
        } else {
            withAnimation(.easeOut(duration: 0.18)) { armed = true }
            Haptics.tap()
        }
    }

    private func revealStep() {
        let total = revealTotal
        var done = Set(content.revealParts)
        let open = (0..<total).filter { !done.contains($0) }
        guard !open.isEmpty else { return }
        let count = revealMode == .mosaik ? MosaikMasse.proTipp : 1
        for value in open.shuffled().prefix(count) { done.insert(value) }
        content.revealParts = Array(done).sorted()
        if content.revealParts.count >= total {
            celebrate()
        } else {
            Haptics.tap()
        }
    }

    private func draw() {
        guard !entries.isEmpty else { return }
        if roundComplete {
            // Alle waren dran: Runde zurücksetzen und gleich neu ziehen.
            content.drawnIDs = []
            content.currentID = nil
        }
        let pool = remaining
        guard let winner = pool.randomElement() else { return }
        Haptics.heavy()

        guard content.animate, pool.count > 1 else {
            commit(winner)
            return
        }
        // Das Auslosen läuft wie ein Glücksrad aus: erst schnell, dann immer
        // langsamer — Schrittzahl und Kurve stehen in `ZiehLauf`, damit die
        // Zeiten mit dem Klang zusammenpassen.
        // Der Klang ist eine durchgehende Aufnahme über den ganzen Zug,
        // nicht mehr ein Ton je Schritt. Beide dauern 1,72 s, also endet er
        // genau dann, wenn der Name steht.
        Ziehklang.shared.starte(content.spinSound)
        // Im Durchlauf erscheint jeder Name AUSSER dem gezogenen.
        //
        // Vorher wurde blind aus allen gewürfelt — mal stand der Gewinner
        // mittendrin, mal ausgerechnet zuletzt, und dann war die Ziehung
        // verraten, bevor sie zu Ende war. Auch zweimal derselbe Name
        // hintereinander sieht aus, als hinge das Bild.
        let kandidaten = entries.filter { $0.id != winner.id }
        Task { @MainActor in
            var vorher: String?
            for stufe in 0..<ZiehLauf.schritte {
                spinText = naechsterDurchlauf(kandidaten, ausser: vorher) ?? winner.text
                vorher = spinText
                try? await Task.sleep(for: .seconds(ZiehLauf.pause(schritt: stufe)))
            }
            spinText = nil
            commit(winner)
        }
    }

    /// Ein Name für den Durchlauf — nicht derselbe wie eben.
    private func naechsterDurchlauf(_ kandidaten: [NameEntry], ausser vorher: String?) -> String? {
        guard !kandidaten.isEmpty else { return nil }
        let frei = kandidaten.filter { $0.text != vorher }
        return (frei.isEmpty ? kandidaten : frei).randomElement()?.text
    }

    private func commit(_ entry: NameEntry) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            content.currentID = entry.id
            content.revealParts = []
            if !content.drawnIDs.contains(entry.id) {
                content.drawnIDs.append(entry.id)
            }
        }
        if revealMode == .instant {
            celebrate()
        } else {
            Haptics.tap()
        }
    }

    /// Kleiner Jubel, wenn der Name ganz zu sehen ist.
    private func celebrate() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { pulse = true }
        confettiTrigger += 1
        Haptics.success()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.easeOut(duration: 0.2)) { pulse = false }
        }
    }

    private func putBack(_ entry: NameEntry) {
        content.drawnIDs.removeAll { $0 == entry.id }
        if content.currentID == entry.id {
            content.currentID = nil
            content.revealParts = []
        }
    }

    private func resetRound() {
        content.drawnIDs = []
        content.currentID = nil
        content.revealParts = []
        spinText = nil
    }
}
