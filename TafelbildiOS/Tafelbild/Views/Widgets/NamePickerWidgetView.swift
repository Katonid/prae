import SwiftUI

/// Zufälliger Name — das meistgenutzte Element.
///
/// Zwei Ziehweisen: „ohne Wiederholung" (jeder kommt erst wieder in den Topf,
/// wenn die Liste durch ist) und „immer alle Namen". Gezogene Namen lassen
/// sich einzeln zurücklegen, aus der Liste löschen — und ein Name kann auch
/// von Hand als gezogen markiert werden, ohne dass der Zufall ihn wählte.
///
/// Der gezogene Name kann schrittweise aufgedeckt werden (Mosaik, Unschärfe
/// oder Buchstabe für Buchstabe), damit die Klasse mitraten darf.
struct NamePickerWidgetView: View {
    @Binding var content: NamePickerContent
    var interactive: Bool
    var list: NameList?
    /// Öffnet die Einstellungen (Liste wählen, Modus).
    var onOpenSettings: () -> Void
    /// Löscht einen Eintrag dauerhaft aus der Namensliste.
    var onDeleteEntry: (NameEntry) -> Void

    @Environment(\.boardStyle) private var style

    @State private var spinText: String?
    @State private var pulse = false
    @State private var confettiTrigger = 0

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 300
            VStack(spacing: 10) {
                if style.showLabels { header(width: geo.size.width) }

                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(style.wash)
                    nameBox(size: geo.size)
                    ConfettiView(trigger: confettiTrigger)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .onTapGesture {
                    guard interactive else { return }
                    step()
                }

                if style.showLabels {
                    Text(hint)
                        .font(Theme.font(Double(min(geo.size.width * 0.045, 17)), weight: .medium))
                        .foregroundStyle(style.inkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                actionRow(width: geo.size.width)

                if showsDrawnList && !compact {
                    history(width: geo.size.width)
                        .frame(height: min(84, geo.size.height * 0.24))
                }
            }
        }
        .padding(18)
    }

    // MARK: - Kopfzeile

    private func header(width: CGFloat) -> some View {
        HStack(spacing: 8) {
            Button {
                guard interactive else { return }
                onOpenSettings()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle")
                    Text(list?.name ?? "Liste wählen")
                        .lineLimit(1)
                }
                .font(Theme.font(16, weight: .semibold))
                .foregroundStyle(style.inkSoft)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            if let list {
                Text(content.mode == .withoutRepeat
                     ? "\(remaining.count)/\(list.activeEntries.count) übrig"
                     : "\(list.activeEntries.count) Namen")
                    .font(Theme.font(15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(style.inkSoft)
            }

            Menu {
                Button {
                    withAnimation { resetRound() }
                } label: {
                    Label("Alle Namen zurücklegen", systemImage: "arrow.counterclockwise")
                }
                Menu("Als gezogen markieren") {
                    ForEach(remaining) { entry in
                        Button(entry.text) { markDrawn(entry) }
                    }
                }
                .disabled(remaining.isEmpty)
                Picker("Ziehweise", selection: $content.mode) {
                    ForEach(NamePickerContent.DrawMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Picker("Aufdecken", selection: $content.reveal) {
                    ForEach(RevealMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Picker("Gezogene anzeigen", selection: $content.showDrawn) {
                    ForEach(ShowRule.allCases) { rule in
                        Text(rule.title).tag(rule)
                    }
                }
                Button {
                    onOpenSettings()
                } label: {
                    Label("Liste wechseln ...", systemImage: "slider.horizontal.3")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(style.inkSoft)
            }
            .disabled(!interactive)
        }
    }

    // MARK: - Namensfeld

    @ViewBuilder
    private func nameBox(size: CGSize) -> some View {
        let text = displayName
        ZStack {
            Text(hidden && revealMode == .letters ? maskedLetters(text) : text)
                .font(Theme.font(nameSize(size), weight: .bold))
                .foregroundStyle(hasName ? AnyShapeStyle(style.accentGradient)
                                         : AnyShapeStyle(style.inkSoft))
                .lineLimit(2)
                .minimumScaleFactor(0.3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .blur(radius: blurRadius(size: size))
                .scaleEffect(pulse ? 1.06 : 1.0)
                .animation(.easeOut(duration: 0.25), value: content.revealParts.count)

            if hidden && revealMode == .mosaik {
                mosaic
                    .padding(6)
            }
        }
    }

    /// Feines Kachelraster über dem Namen — jede Kachel verschwindet einzeln.
    private var mosaic: some View {
        let open = Set(content.revealParts)
        return VStack(spacing: 2) {
            ForEach(0..<RevealLayout.mosaicRows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<RevealLayout.mosaicColumns, id: \.self) { column in
                        let index = row * RevealLayout.mosaicColumns + column
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(style.accent.opacity(open.contains(index) ? 0 : 0.92))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.22), value: content.revealParts.count)
    }

    /// Die Unschärfe richtet sich nach der Schriftgröße — sonst bliebe ein
    /// großer Name auch mit festem Wert lesbar.
    private func blurRadius(size: CGSize) -> Double {
        guard hidden, revealMode == .blur else { return 0 }
        let progress = min(1, Double(content.revealParts.count) / Double(RevealLayout.blurSteps))
        return nameSize(size) * 0.42 * pow(1 - progress, 1.5) + 1.5
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

    // MARK: - Ziehen und Aufdecken

    private func actionRow(width: CGFloat) -> some View {
        HStack(spacing: 8) {
            Button {
                guard interactive else { return }
                step()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: mainSymbol)
                        .font(.system(size: 22, weight: .bold))
                    Text(buttonTitle)
                        .font(Theme.font(22, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background {
                    Capsule().fill(style.accentGradient)
                        .opacity(list == nil ? 0.45 : 1)
                }
                .shadow(color: style.accentGlow, radius: 16, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(list == nil || spinText != nil)
            .opacity(interactive ? 1 : 0.85)

            if hidden {
                Button {
                    guard interactive else { return }
                    revealAll()
                } label: {
                    Image(systemName: "eye")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(style.ink)
                        .frame(width: 58, height: 58)
                        .background { Circle().fill(style.wash) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Namen ganz aufdecken")
            }
        }
    }

    private var mainSymbol: String {
        if hidden { return "sparkles" }
        return roundComplete ? "arrow.counterclockwise.circle.fill" : "shuffle"
    }

    private var buttonTitle: String {
        if list == nil { return "Liste wählen" }
        if hidden { return "Aufdecken" }
        if roundComplete { return "Neue Runde" }
        return "Ziehen"
    }

    private var hint: String {
        if list == nil { return "Einstellungen öffnen und eine Liste wählen." }
        if entries.isEmpty { return "Die Liste ist noch leer." }
        if hidden {
            let perTap = revealMode == .mosaik ? RevealLayout.mosaicPerTap : 1
            let total = max(1, Int(ceil(Double(revealTotal) / Double(perTap))))
            let done = min(total, Int(ceil(Double(content.revealParts.count) / Double(perTap))))
            return "Aufdecken — Schritt \(done) von \(total)"
        }
        if roundComplete { return "Alle Namen gezogen." }
        return "Karte antippen zieht den nächsten Namen"
    }

    // MARK: - Gezogene Namen

    private var showsDrawnList: Bool {
        // Im Unterricht bleibt die Liste bei „Beim Bearbeiten" verborgen —
        // so lässt sich nicht ablesen, wer noch fehlt.
        content.showDrawn.applies(editing: !interactive)
    }

    private func history(width: CGFloat) -> some View {
        // Der aktuelle Name bleibt verborgen, solange er nicht aufgedeckt ist.
        let shown = hidden ? drawnEntries.filter { $0.id != content.currentID } : drawnEntries
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
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
                            .font(Theme.font(17, weight: .semibold))
                            .foregroundStyle(current ? Color.white : style.ink)
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background {
                                Capsule().fill(current
                                               ? AnyShapeStyle(style.accentGradient)
                                               : AnyShapeStyle(style.wash))
                            }
                    }
                    .disabled(!interactive)
                }
                if shown.isEmpty {
                    Text("Noch niemand gezogen")
                        .font(Theme.font(16, weight: .medium))
                        .foregroundStyle(style.inkSoft)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollDisabled(!interactive)
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
        if entries.isEmpty { return "Liste ist leer" }
        return "Bereit"
    }

    private func nameSize(_ size: CGSize) -> Double {
        Double(min(size.width * 0.17, size.height * 0.30))
    }

    // MARK: - Aufdecken

    private var revealMode: RevealMode { content.reveal }

    private var revealTotal: Int {
        switch revealMode {
        case .instant: return 0
        case .mosaik:  return RevealLayout.mosaicTiles
        case .blur:    return RevealLayout.blurSteps
        case .letters: return max(1, Self.maskableIndexes(currentEntry?.text ?? "").count)
        }
    }

    /// Ist gerade ein Name im Spiel, der noch nicht ganz zu sehen ist?
    private var hidden: Bool {
        guard spinText == nil, currentEntry != nil, revealMode != .instant else { return false }
        return content.revealParts.count < revealTotal
    }

    /// Zeichen, die verdeckt werden können (Buchstaben und Ziffern).
    private static func maskableIndexes(_ name: String) -> [Int] {
        Array(name).enumerated().compactMap { position, character in
            character.isLetter || character.isNumber ? position : nil
        }
    }

    // MARK: - Aktionen

    /// Ein Tipp: entweder den nächsten Teil aufdecken oder neu ziehen.
    private func step() {
        if hidden {
            revealStep()
        } else {
            draw()
        }
    }

    private func revealStep() {
        let total = revealTotal
        var done = Set(content.revealParts)
        let open = (0..<total).filter { !done.contains($0) }
        guard !open.isEmpty else { return }
        let count = revealMode == .mosaik ? RevealLayout.mosaicPerTap : 1
        for value in open.shuffled().prefix(count) { done.insert(value) }
        content.revealParts = Array(done).sorted()
        if content.revealParts.count >= total {
            celebrate()
        } else {
            Haptics.tap()
        }
    }

    private func revealAll() {
        guard hidden else { return }
        content.revealParts = Array(0..<revealTotal)
        celebrate()
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
        // Kurzes „Durchrattern" der Namen, dann bleibt der Gewinner stehen.
        Task { @MainActor in
            var delay = 45
            for stepIndex in 0..<14 {
                spinText = entries.randomElement()?.text ?? winner.text
                try? await Task.sleep(for: .milliseconds(delay))
                delay += 8 + stepIndex * 3
            }
            spinText = nil
            commit(winner)
        }
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

    private func markDrawn(_ entry: NameEntry) {
        guard !content.drawnIDs.contains(entry.id) else { return }
        withAnimation { content.drawnIDs.append(entry.id) }
        Haptics.tap()
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
