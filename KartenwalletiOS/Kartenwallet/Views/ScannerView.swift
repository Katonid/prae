import SwiftUI
import VisionKit

/// Live-Barcode-Scanner über die Kamera (VisionKit DataScanner).
struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onFound: (Barcode.DetectionResult) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    DataScannerRepresentable(onFound: onFound)
                        .ignoresSafeArea()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.on.rectangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Der Kamera-Scanner ist auf diesem Gerät nicht verfügbar. Du kannst den Code stattdessen aus einem Foto erkennen lassen oder eintippen.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
            }
            .navigationTitle("Code scannen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onFound: (Barcode.DetectionResult) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFound: onFound)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onFound: (Barcode.DetectionResult) -> Void
        private var reported = false

        init(onFound: @escaping (Barcode.DetectionResult) -> Void) {
            self.onFound = onFound
        }

        func dataScanner(_ scanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            report(items: addedItems)
        }

        func dataScanner(_ scanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            report(items: [item])
        }

        private func report(items: [RecognizedItem]) {
            guard !reported else { return }
            for item in items {
                guard case .barcode(let barcode) = item,
                      let payload = barcode.payloadStringValue, !payload.isEmpty,
                      let result = Barcode.map(symbology: barcode.observation.symbology, payload: payload) else {
                    continue
                }
                reported = true
                onFound(result)
                return
            }
        }
    }
}
