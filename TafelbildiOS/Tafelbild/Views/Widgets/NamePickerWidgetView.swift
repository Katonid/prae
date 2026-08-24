import SwiftUI

/// Zufälliger Name — das meistgenutzte Element.
///
/// Zwei Ziehweisen: „ohne Wiederholung" (jeder kommt erst wieder in den Topf,
/// wenn die Liste durch ist) und „immer alle Namen". Gezogene Namen lassen
/// sich einzeln zurücklegen, aus der Liste löschen — und ein Name kann auch
/// von Hand als gezogen markiert werden, ohne dass der Zufall ihn wählte.
struct NamePickerWidgetView: View {
    @Binding var content: NamePickerContent
    var interactive: Bool
    var list: NameList?
    /// Öffnet die Einstellungen (Liste wählen, Modus).
    var onOpenSettings: () -> Void
    /// Löscht einen Eintrag dauerhaft aus der Namensliste.
    var onDeleteEntry: (NameEntry) -> Void

    @State private var spinText: String?
    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 300
            VStack(spacing: 10) {
                header(width: geo.size.width)

                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                    Text(displayName)
                        .font(Theme.font(nameSize(geo.size), weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .scaleEffect(pulse ? 1.06 : 1.0)
                        .id(displayName)
                        .transition(.opacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                drawButton(width: geo.size.width)

                if content.showHistory && !compact {
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
                .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            if let list {
                Text(content.mode == .withoutRepeat
                     ? "\(remaining.count)/\(list.activeEntries.count) übrig"
                     : "\(list.activeEntries.count) Namen")
                    .font(Theme.font(15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))
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
                Toggle("Gezogene anzeigen", isOn: $content.showHistory)
                Button {
                    onOpenSettings()
                } label: {
                    Label("Liste wechseln ...", systemImage: "slider.horizontal.3")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .disabled(!interactive)
        }
    }

    // MARK: - Ziehen

    private func drawButton(width: CGFloat) -> some View {
        Button {
            guard interactive else { return }
            draw()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: roundComplete ? "arrow.counterclockwise.circle.fill" : "shuffle")
                    .font(.system(size: 22, weight: .bold))
                Text(buttonTitle)
                    .font(Theme.font(22, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background {
                Capsule().fill(list == nil ? Color.white.opacity(0.4) : Color.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(list == nil || spinText != nil)
        .opacity(interactive ? 1 : 0.85)
    }

    private var buttonTitle: String {
        if list == nil { return "Liste wählen" }
        if roundComplete { return "Neue Runde" }
        return "Ziehen"
    }

    // MARK: - Gezogene Namen

    private func history(width: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(drawnEntries) { entry in
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
                        Text(entry.text)
                            .font(Theme.font(17, weight: .semibold))
                            .foregroundStyle(entry.id == content.currentID ? Color.black : .white.opacity(0.9))
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background {
                                Capsule().fill(entry.id == content.currentID
                                               ? Color.white : Color.white.opacity(0.14))
                            }
                    }
                    .disabled(!interactive)
                }
                if drawnEntries.isEmpty {
                    Text("Noch niemand gezogen")
                        .font(Theme.font(16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
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

    private var displayName: String {
        if let spinText { return spinText }
        if let currentID = content.currentID, let entry = entries.first(where: { $0.id == currentID }) {
            return entry.text
        }
        if list == nil { return "Keine Liste" }
        if entries.isEmpty { return "Liste ist leer" }
        return "Bereit"
    }

    private func nameSize(_ size: CGSize) -> Double {
        min(size.width * 0.17, size.height * 0.30)
    }

    // MARK: - Aktionen

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
            for step in 0..<14 {
                spinText = entries.randomElement()?.text ?? winner.text
                try? await Task.sleep(for: .milliseconds(delay))
                delay += 8 + step * 3
            }
            spinText = nil
            commit(winner)
        }
    }

    private func commit(_ entry: NameEntry) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            content.currentID = entry.id
            if !content.drawnIDs.contains(entry.id) {
                content.drawnIDs.append(entry.id)
            }
            pulse = true
        }
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
        if content.currentID == entry.id { content.currentID = nil }
    }

    private func resetRound() {
        content.drawnIDs = []
        content.currentID = nil
        spinText = nil
    }
}
