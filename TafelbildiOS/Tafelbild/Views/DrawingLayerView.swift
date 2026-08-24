import SwiftUI
import PencilKit

/// Schreiben und Markieren auf der Tafel — mit Apple Pencil oder Finger.
///
/// Die Striche gehören zur Tafel: Sie werden mitgespeichert und wandern über
/// iCloud auf die anderen Geräte. Solange nicht geschrieben wird, liegt die
/// Ebene durchsichtig und ohne Berührungsfang über den Elementen.
struct DrawingLayerView: UIViewRepresentable {
    /// Handschrift als Base64 (PencilKit-Daten).
    @Binding var drawing: String
    /// Schreiben ist eingeschaltet — nur dann nimmt die Ebene Berührungen an.
    var active: Bool
    /// Nur der Stift schreibt; der Finger bleibt zum Bedienen frei.
    var pencilOnly: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        // PKCanvasView ist eine Bildlaufansicht — auf der Tafel soll sie
        // weder scrollen noch zoomen.
        canvas.isScrollEnabled = false
        canvas.bouncesZoom = false
        canvas.delegate = context.coordinator
        canvas.drawing = Self.decode(drawing)
        canvas.drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        canvas.isUserInteractionEnabled = active
        context.coordinator.canvas = canvas
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        canvas.drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        canvas.isUserInteractionEnabled = active

        // Von außen (iCloud, Tafelwechsel) geänderte Striche übernehmen —
        // aber nie mitten im eigenen Strich.
        if !context.coordinator.writing {
            let incoming = Self.decode(drawing)
            if incoming.dataRepresentation() != canvas.drawing.dataRepresentation() {
                canvas.drawing = incoming
            }
        }

        context.coordinator.showTools(active)
    }

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        coordinator.showTools(false)
    }

    // MARK: - Umwandlung

    static func decode(_ value: String) -> PKDrawing {
        guard let data = Data(base64Encoded: value),
              let drawing = try? PKDrawing(data: data) else { return PKDrawing() }
        return drawing
    }

    static func encode(_ drawing: PKDrawing) -> String {
        drawing.strokes.isEmpty ? "" : drawing.dataRepresentation().base64EncodedString()
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingLayerView
        weak var canvas: PKCanvasView?
        /// Solange gezeichnet wird, nichts von außen überschreiben.
        var writing = false
        private var toolsVisible = false
        /// Eigene Werkzeugauswahl — die geteilte ist seit iOS 16 abgelöst.
        private let picker = PKToolPicker()

        init(_ parent: DrawingLayerView) {
            self.parent = parent
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            writing = true
        }

        /// Erst am Ende eines Strichs sichern — sonst schriebe jede Bewegung
        /// einen neuen Stand in die Cloud.
        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            writing = false
            parent.drawing = DrawingLayerView.encode(canvasView.drawing)
        }

        /// Blendet die Werkzeugauswahl von iOS ein oder aus (Farben, Stifte,
        /// Radierer, Rückgängig).
        func showTools(_ show: Bool) {
            guard let canvas, toolsVisible != show else { return }
            toolsVisible = show
            picker.addObserver(canvas)
            picker.setVisible(show, forFirstResponder: canvas)
            if show {
                canvas.becomeFirstResponder()
            } else {
                canvas.resignFirstResponder()
            }
        }
    }
}
