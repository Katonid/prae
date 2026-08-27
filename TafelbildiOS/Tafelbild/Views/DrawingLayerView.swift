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
    /// Liegt die Ebene auf dunklem Grund?
    ///
    /// PencilKit dreht schwarze Tinte in dunkler Umgebung selbsttätig ins
    /// Helle. Ohne diesen Hinweis erbte die Schreibebene das Aussehen der
    /// App — und die ist hell. Auf einer dunklen Tafel schrieb man dann mit
    /// schwarzer Tinte auf dunkelblauem Grund: Der Strich war da, aber
    /// nicht zu sehen. Auf dem iPhone fiel das besonders auf, weil dort die
    /// ganze Tafel auf ein Viertel verkleinert ist und der dünne Strich
    /// ohnehin kaum auffällt.
    var dunklerGrund: Bool = true

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
        canvas.overrideUserInterfaceStyle = dunklerGrund ? .dark : .light
        // Ein Stift, mit dem man sofort schreiben kann — ohne erst in der
        // Werkzeugauswahl etwas zu wählen. Die Breite ist in Tafelpunkten
        // gedacht: Auf dem Telefon steht die Tafel auf einem Viertel, ein
        // feiner Strich wäre dort ein Haar.
        canvas.tool = PKInkingTool(.pen, color: .black, width: 12)
        context.coordinator.canvas = canvas
        context.coordinator.letzterStand = drawing
        context.coordinator.gesetzterStand = Self.encode(canvas.drawing)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        canvas.drawingPolicy = pencilOnly ? .pencilOnly : .anyInput
        canvas.isUserInteractionEnabled = active
        canvas.overrideUserInterfaceStyle = dunklerGrund ? .dark : .light

        // Von außen (iCloud, Tafel- oder Seitenwechsel) geänderte Striche
        // übernehmen — aber nur die, und nie mitten im eigenen Strich.
        //
        // Verglichen wird der gespeicherte Text mit dem, was diese Ebene
        // zuletzt selbst gelesen oder geschrieben hat. Vorher wurden die
        // Rohdaten zweier PKDrawing-Objekte verglichen; die sind aber selbst
        // bei gleichem Inhalt nicht Byte für Byte gleich. Also galt jede
        // Neuzeichnung als fremde Änderung, und die Ebene setzte ihre
        // Zeichnung neu — bei jedem Sekundentakt der Uhr. Genau das war das
        // Flackern: Buchstaben verschwanden und kamen wieder.
        if !context.coordinator.writing, drawing != context.coordinator.letzterStand {
            context.coordinator.letzterStand = drawing
            canvas.drawing = Self.decode(drawing)
            // Was PencilKit daraus zurückschreibt, ist nicht Byte für Byte
            // derselbe Text. Ohne diese Notiz hielte die Ebene ihren eigenen,
            // gleich aussehenden Stand für eine Änderung und schöbe ihn in
            // die Cloud — hin und her zwischen den Geräten.
            context.coordinator.gesetzterStand = Self.encode(canvas.drawing)
        }

        context.coordinator.showTools(active)
    }

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        // Beim Seiten- oder Tafelwechsel darf nichts verlorengehen, was noch
        // auf seine Sicherung wartet.
        coordinator.sichereJetzt()
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
        /// Der Stand, den diese Ebene zuletzt gelesen oder geschrieben hat.
        var letzterStand: String = ""
        /// Was PencilKit unmittelbar nach einem Übernehmen von außen
        /// zurückliefert — das ist keine eigene Änderung.
        var gesetzterStand: String = ""
        /// Zählt die geplanten Sicherungen; nur die jüngste zählt.
        private var sicherungsNummer = 0
        private var toolsVisible = false
        private var beobachtet = false
        /// Eigene Werkzeugauswahl — die geteilte ist seit iOS 16 abgelöst.
        private let picker = PKToolPicker()

        init(_ parent: DrawingLayerView) {
            self.parent = parent
        }

        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            writing = true
            sicherungsNummer &+= 1
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            writing = false
            plane(canvasView)
        }

        /// **Der eigentliche Auslöser zum Sichern.**
        ///
        /// Vorher wurde nur am Ende eines Strichs gesichert — und genau da
        /// lag der Fehler beim Radieren: PencilKit trägt das Löschen zum
        /// Teil erst NACH `canvasViewDidEndUsingTool` in die Zeichnung ein.
        /// Gesichert wurde also der Stand von vorher. Auf dem Bildschirm war
        /// das Weggewischte weg, im Speicher stand es weiter — und kam beim
        /// nächsten Abgleich oder Seitenwechsel zurück. Genauso ging es dem
        /// Rückgängig-Knopf der Werkzeugauswahl, der gar keinen Strich
        /// beendet.
        ///
        /// `canvasViewDrawingDidChange` meldet jede Änderung, auch diese
        /// späten. Gesichert wird mit kurzem Abstand, damit ein Strich nicht
        /// zehnmal in die Cloud wandert.
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !writing else { return }
            plane(canvasView)
        }

        private func plane(_ canvasView: PKCanvasView) {
            sicherungsNummer &+= 1
            let meine = sicherungsNummer
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                [weak self, weak canvasView] in
                guard let self, let canvasView, self.sicherungsNummer == meine else { return }
                self.sichere(canvasView)
            }
        }

        private func sichere(_ canvasView: PKCanvasView) {
            let neu = DrawingLayerView.encode(canvasView.drawing)
            guard neu != letzterStand, neu != gesetzterStand else { return }
            letzterStand = neu
            parent.drawing = neu
        }

        /// Alles Wartende sofort sichern — beim Verlassen der Seite.
        func sichereJetzt() {
            sicherungsNummer &+= 1
            guard let canvas else { return }
            sichere(canvas)
        }

        /// Blendet die Werkzeugauswahl von iOS ein oder aus (Farben, Stifte,
        /// Radierer, Rückgängig).
        func showTools(_ show: Bool) {
            guard let canvas, toolsVisible != show else { return }
            toolsVisible = show
            if !beobachtet {
                picker.addObserver(canvas)
                beobachtet = true
            }
            picker.setVisible(show, forFirstResponder: canvas)
            if show {
                // Beim ersten Einschalten hängt die Ansicht gelegentlich noch
                // nicht im Fenster; dann geht der Erstantwortende ins Leere
                // und die Werkzeugauswahl bleibt weg. Ein zweiter Versuch im
                // nächsten Durchlauf reicht.
                if !canvas.becomeFirstResponder() {
                    DispatchQueue.main.async { [weak canvas] in
                        guard let canvas else { return }
                        canvas.becomeFirstResponder()
                    }
                }
            } else {
                canvas.resignFirstResponder()
            }
        }
    }
}
