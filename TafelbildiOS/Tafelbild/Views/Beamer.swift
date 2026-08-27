import SwiftUI
import UIKit

// Die Tafel auf dem Beamer — und nur die Tafel.
//
// Bislang spiegelte das iPad seinen ganzen Bildschirm: Wer die App verließ,
// zeigte der Klasse den Startbildschirm, und jede Benachrichtigung eines
// anderen Programms stand groß an der Wand.
//
// Eine App darf den zweiten Bildschirm aber auch selbst bespielen. iOS legt
// dafür eine eigene „Szene“ an (`UIWindowSceneSessionRoleExternal…`), sobald
// die App in ihrer Info.plist sagt, dass sie eine haben möchte. Was dort
// erscheint, entscheidet allein die App — Banner, Dock, Blätter und die
// Bedienleiste bleiben auf dem iPad. Genau so machen es Keynote und Explain
// Everything.
//
// Auf dem Beamer steht deshalb nur: Hintergrund, die Elemente der gerade
// sichtbaren Seite und die Handschrift. Keine Werkzeuge, keine Auswahlrahmen,
// kein Seitenwechsler.

// MARK: - Merker

/// Weiß, ob gerade ein zweiter Bildschirm bespielt wird.
///
/// Nur für den Hinweis in der Bedienleiste — die Übertragung selbst hängt
/// nicht daran.
@MainActor
final class Beamer: ObservableObject {
    static let shared = Beamer()

    /// Ein zweiter Bildschirm ist verbunden und zeigt die Tafel.
    @Published private(set) var angeschlossen = false

    private init() {}

    fileprivate func anmelden() { angeschlossen = true }
    fileprivate func abmelden() { angeschlossen = false }
}

// MARK: - Szene

/// Baut das Fenster auf dem zweiten Bildschirm auf.
///
/// Der Klassenname steht wörtlich in `Config/Info.plist`
/// (`$(PRODUCT_MODULE_NAME).BeamerSceneDelegate`) — wer ihn hier ändert, muss
/// ihn dort mitändern, sonst bleibt der Beamer schwarz.
final class BeamerSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options: UIScene.ConnectionOptions) {
        guard let fensterszene = scene as? UIWindowScene else { return }

        let fenster = UIWindow(windowScene: fensterszene)
        let halter = UIHostingController(
            rootView: BeamerTafelView().environmentObject(BoardStore.shared))
        halter.view.backgroundColor = .black
        // Eine Tafel ist dunkel; das Fenster erbt sonst das Aussehen des
        // Systems und zeichnete auf einem hellen Gerät helle Karten.
        halter.overrideUserInterfaceStyle = .dark
        fenster.rootViewController = halter
        fenster.isHidden = false
        window = fenster

        Beamer.shared.anmelden()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        window = nil
        Beamer.shared.abmelden()
    }
}

// MARK: - Ansicht

/// Die Tafel ohne alles Drumherum, eingepasst in den zweiten Bildschirm.
struct BeamerTafelView: View {
    @EnvironmentObject private var store: BoardStore

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(hex: "#04100f")
                if let board = store.activeBoard {
                    tafel(board, in: geo.size)
                } else {
                    hinweis
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }

    private func tafel(_ board: Board, in flaeche: CGSize) -> some View {
        // Die Tafel ist 16:10, ein Beamer meist 16:9. Der Hintergrund füllt
        // deshalb den ganzen Bildschirm, die Elemente sitzen mittig darauf —
        // so entstehen keine schwarzen Balken.
        let seite = sichtbareSeite(board)
        let hoehe = board.hoehe
        let scale = min(flaeche.width / Layout.canvasWidth,
                        flaeche.height / hoehe)
        return ZStack {
            BoardBackgroundView(background: board.background)
                .ignoresSafeArea()

            ZStack(alignment: .topLeading) {
                // Die Elemente sehen aus wie auf dem iPad — mit ihren
                // eigenen Knöpfen, denn sie sind Teil der Tafel. Weg ist nur,
                // was der App gehört: Kopfleiste, Elementleiste,
                // Seitenwechsler, Auswahlrahmen. `editable: false` sorgt
                // dafür, dass hier nichts verschoben oder gewählt wird.
                //
                // Die Dokumentenkamera läuft dabei in beiden Fenstern aus
                // derselben Aufnahmesitzung (`Kameraquelle.shared`); mehrere
                // Vorschauebenen an einer Sitzung sind erlaubt.
                ForEach(board.widgets(auf: seite)) { widget in
                    WidgetHostView(boardID: board.id, widget: widget, scale: scale,
                                   frames: board.frames, editable: false)
                        .offset(x: widget.x, y: widget.y)
                }

                // Handschrift liegt über den Elementen — hier nur zum Ansehen.
                DrawingLayerView(drawing: .constant(board.handschrift(auf: seite)),
                                 active: false, pencilOnly: false,
                                 dunklerGrund: board.background.wirktDunkel)
                    .frame(width: Layout.canvasWidth, height: hoehe)
                    .allowsHitTesting(false)
            }
            .frame(width: Layout.canvasWidth, height: hoehe,
                   alignment: .topLeading)
            .scaleEffect(scale)
            .frame(width: Layout.canvasWidth * scale, height: hoehe * scale)
        }
        .environment(\.boardStyle, BoardStyle(board: board, editing: false))
    }

    /// Dieselbe Seite wie auf dem iPad — wer dort blättert, blättert an der Wand.
    private func sichtbareSeite(_ board: Board) -> String {
        board.seiten.contains { $0.id == store.aktiveSeitenID }
            ? store.aktiveSeitenID : board.ersteSeitenID
    }

    private var hinweis: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 54, weight: .light))
            Text("Noch keine Tafel gewählt")
                .font(Theme.font(30, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.65))
    }
}
