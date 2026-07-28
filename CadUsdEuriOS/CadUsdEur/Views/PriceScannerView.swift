import SwiftUI
import VisionKit

// MARK: - Preis aus erkanntem Kameratext herauslesen

enum PriceParser {
    struct Candidate {
        let value: Double
        let score: Int
        let prominence: CGFloat
    }

    /// Zahlengruppen (mit Komma-/Punkt-Trennern) aus einem Textstück holen.
    /// Liefert Wert und Anzahl der Nachkommastellen.
    static func numberCandidates(in text: String) -> [(value: Double, decimals: Int)] {
        var results: [(Double, Int)] = []
        var current = ""
        func flush() {
            if !current.isEmpty {
                if let parsed = parseNumber(current) { results.append(parsed) }
                current = ""
            }
        }
        for character in text {
            if character.isNumber {
                current.append(character)
            } else if (character == "." || character == ",") && !current.isEmpty {
                current.append(character)
            } else {
                flush()
            }
        }
        flush()
        return results
    }

    /// "12.99", "12,99" und "1.234,56" richtig deuten: der letzte Trenner mit
    /// höchstens zwei Folgeziffern ist das Dezimalzeichen, drei Ziffern sind
    /// ein Tausenderblock.
    static func parseNumber(_ input: String) -> (value: Double, decimals: Int)? {
        var raw = input
        while let last = raw.last, last == "." || last == "," {
            raw.removeLast()
        }
        guard !raw.isEmpty else { return nil }
        guard let lastSeparator = raw.lastIndex(where: { $0 == "." || $0 == "," }) else {
            guard let value = Double(raw), value.isFinite else { return nil }
            return (value, 0)
        }
        let fraction = String(raw[raw.index(after: lastSeparator)...])
        if fraction.count <= 2 {
            let integerDigits = raw[..<lastSeparator].filter { $0.isNumber }
            guard let value = Double(integerDigits + "." + fraction), value.isFinite else { return nil }
            return (value, fraction.count)
        }
        let digits = raw.filter { $0.isNumber }
        guard let value = Double(digits), value.isFinite else { return nil }
        return (value, 0)
    }

    /// Bewertet ein Textstück: Centbetrag und Währungszeichen sprechen für
    /// einen Preis, die Bildgröße (prominence) für das Hauptpreisschild.
    static func candidate(in text: String, prominence: CGFloat) -> Candidate? {
        let hasCurrency = text.contains("$") || text.contains("€")
            || text.localizedCaseInsensitiveContains("cad")
            || text.localizedCaseInsensitiveContains("usd")
            || text.localizedCaseInsensitiveContains("eur")
        var best: Candidate?
        for (value, decimals) in numberCandidates(in: text) {
            guard value > 0, value < 100_000 else { continue }
            var score = 0
            if decimals == 2 { score += 2 }
            if hasCurrency { score += 2 }
            if value >= 0.5 && value <= 20_000 { score += 1 }
            let next = Candidate(value: value, score: score, prominence: prominence)
            if let current = best {
                if (next.score, next.prominence, next.value) > (current.score, current.prominence, current.value) {
                    best = next
                }
            } else {
                best = next
            }
        }
        return best
    }

    /// Bester automatisch erkannter Preis: verlangt Centbetrag oder
    /// Währungszeichen, bevorzugt den größten Schriftzug im Bild.
    static func bestPrice(from items: [(text: String, prominence: CGFloat)]) -> Double? {
        var best: Candidate?
        for item in items {
            guard let next = candidate(in: item.text, prominence: item.prominence), next.score >= 3 else { continue }
            if let current = best {
                if (next.score, next.prominence) > (current.score, current.prominence) {
                    best = next
                }
            } else {
                best = next
            }
        }
        return best?.value
    }

    /// Beim gezielten Antippen genügt jede plausible Zahl.
    static func tappedPrice(in text: String) -> Double? {
        candidate(in: text, prominence: 0)?.value
    }
}

// MARK: - Scanner-Ansicht

struct PriceScannerView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var candidate: Double?

    var body: some View {
        ZStack {
            if DataScannerViewController.isSupported {
                ScannerContainer(
                    onItems: { items in
                        candidate = PriceParser.bestPrice(from: items)
                    },
                    onTap: { text in
                        if let value = PriceParser.tappedPrice(in: text) {
                            apply(value)
                        }
                    }
                )
                .ignoresSafeArea()
            } else {
                unsupportedView
            }
        }
        .overlay(alignment: .top) { header }
        .overlay(alignment: .bottom) { bottomBar }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Text("Preis scannen")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Color.white)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.white.opacity(0.9))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Scanner schließen")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.45))
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if let candidate {
                Button {
                    apply(candidate)
                } label: {
                    Text("\(model.prettyMoney(candidate, model.mode.code)) übernehmen")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .contentTransition(.numericText())
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(Theme.ink)
                        .background(Theme.goldGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Theme.gold.opacity(0.4), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .animation(.snappy, value: candidate)
            }
            Text(candidate == nil
                 ? "Preisschild in den Sucher halten – der erkannte Preis erscheint hier. Antippen im Bild geht auch."
                 : "Oder einen anderen Preis direkt im Bild antippen.")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var unsupportedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.slash")
                .font(.system(size: 44))
            Text("Die Kamera-Preiserkennung wird auf diesem Gerät nicht unterstützt.")
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Color.white)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private func apply(_ value: Double) {
        model.applyScannedPrice(value)
        dismiss()
    }
}

// MARK: - VisionKit-Scanner einbetten

private struct ScannerContainer: UIViewControllerRepresentable {
    var onItems: ([(text: String, prominence: CGFloat)]) -> Void
    var onTap: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onItems: onItems, onTap: onTap)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        context.coordinator.onItems = onItems
        context.coordinator.onTap = onTap
        if !controller.isScanning {
            try? controller.startScanning()
        }
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onItems: ([(text: String, prominence: CGFloat)]) -> Void
        var onTap: (String) -> Void

        init(onItems: @escaping ([(text: String, prominence: CGFloat)]) -> Void,
             onTap: @escaping (String) -> Void) {
            self.onItems = onItems
            self.onTap = onTap
        }

        private func report(_ allItems: [RecognizedItem]) {
            let items: [(text: String, prominence: CGFloat)] = allItems.compactMap { item in
                guard case .text(let text) = item else { return nil }
                let bounds = item.bounds
                let height = abs(bounds.bottomLeft.y - bounds.topLeft.y)
                return (text.transcript, height)
            }
            onItems(items)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            report(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            report(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            report(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .text(let text) = item {
                onTap(text.transcript)
            }
        }
    }
}
