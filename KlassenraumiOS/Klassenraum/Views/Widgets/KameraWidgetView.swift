import SwiftUI
import UIKit

/// Dokumentenkamera: Das Livebild der Gerätekamera steht auf der Tafel, ein
/// Tipp friert es ein.
///
/// Gedacht für das iPad auf einem Ständer über dem Tisch — Heft aufschlagen,
/// hinlegen, alle sehen es. Eingefroren wird das Bild zu einer gewöhnlichen
/// Bilddatei: Es bleibt nach dem Schließen der App stehen, reist über iCloud
/// mit, und die Handschrift der Tafel liegt ohnehin darüber, sodass sich mit
/// dem Stift direkt hineinschreiben lässt.
struct KameraWidgetView: View {
    @Binding var content: KameraContent
    var interactive: Bool
    /// Legt das Standbild zusätzlich als eigenes Bildelement auf die Tafel.
    var onAblegen: (String) -> Void
    /// Sichert Bilddaten und liefert den Dateinamen zurück.
    var onSichern: (Data) -> String?

    @Environment(\.boardStyle) private var style
    @Environment(\.widgetMetrics) private var metrics

    @ObservedObject private var kamera = Kameraquelle.shared
    /// Dieses Element hat die Kamera angefordert (für ein sauberes Freigeben).
    @State private var angemeldet = false
    @State private var arbeitet = false
    /// Größe der Vorschau — sie bestimmt den Zuschnitt des Standbilds.
    @State private var vorschau: CGSize = .zero

    private var eingefroren: Bool { content.eingefroren != nil }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.widgetCorner, style: .continuous)
                .fill(Color(hex: "#0b1020"))

            inhalt
                .clipShape(RoundedRectangle(cornerRadius: Theme.widgetCorner, style: .continuous))

            // Aufschrift oben, wenn eine gesetzt ist — sie sagt, was da
            // liegt („Merlins Heft“). Wie bei den Klangfeldern hängt sie
            // nicht an der Tafelregel: Wer sie einträgt, will sie sehen.
            if let text = content.caption.nonEmpty {
                VStack {
                    Text(text)
                        .font(Theme.font(metrics.em(style.kopf(0.94)), weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background { Capsule().fill(Color.black.opacity(0.45)) }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
            }

            if interactive {
                VStack {
                    Spacer()
                    knopfleiste
                        .padding(.bottom, 12)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { umschalten() }
        // Die Kamera läuft nur, solange sie gebraucht wird: nicht im
        // Bearbeiten-Modus, nicht bei eingefrorenem Bild. Sonst bliebe die
        // Anzeige „Kamera aktiv" stehen, während längst niemand mehr filmt.
        .onAppear { pruefeBedarf() }
        .onDisappear { abmelden() }
        .onChange(of: eingefroren) { _, _ in pruefeBedarf() }
        .onChange(of: interactive) { _, _ in pruefeBedarf() }
        .onChange(of: kamera.erlaubnis) { _, _ in pruefeBedarf() }
    }

    // MARK: - Bild

    @ViewBuilder
    private var inhalt: some View {
        if let datei = content.eingefroren, let bild = MediaCache.shared.image(datei) {
            Image(uiImage: bild)
                .resizable()
                .aspectRatio(contentMode: content.fuellend ? .fill : .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if kamera.erlaubnis == .erlaubt {
            ZStack {
                Kameravorschau(sitzung: kamera.sitzung)
                if !kamera.laeuft { hinweis("Kamera startet …", symbol: "camera") }
            }
            // Was der Sucher zeigt, ist ein Ausschnitt aus dem Sensorbild.
            // Damit das Standbild genau dieser Ausschnitt wird, muss die
            // Aufnahme wissen, wie breit und hoch das Fenster gerade ist.
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { vorschau = geo.size }
                        .onChange(of: geo.size) { _, neu in vorschau = neu }
                }
            }
        } else {
            hinweis(kamera.erlaubnis == .verweigert
                    ? "Kein Zugriff auf die Kamera — in den iOS-Einstellungen unter Klassenraum erlauben."
                    : "Zum Einschalten antippen.",
                    symbol: "camera.metering.unknown")
        }
    }

    private func hinweis(_ text: String, symbol: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: metrics.em(2.6)))
            Text(text)
                .font(Theme.font(metrics.em(0.94), weight: .semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Color.white.opacity(0.75))
        .padding(24)
    }

    // MARK: - Knöpfe

    private var knopfleiste: some View {
        HStack(spacing: 8) {
            if eingefroren {
                knopf("play.fill", titel: "Weiter") { auftauen() }
                knopf("square.and.arrow.down", titel: "Als Bild ablegen") { ablegen() }
            } else if kamera.erlaubnis == .erlaubt {
                knopf("camera.fill", titel: "Einfrieren", betont: true) { einfrieren() }
                knopf(kamera.vorne ? "arrow.triangle.2.circlepath.camera"
                                   : "arrow.triangle.2.circlepath.camera.fill",
                      titel: nil) { kamera.wechsle() }
                if kamera.lichtMoeglich {
                    knopf(kamera.lichtAn ? "flashlight.on.fill" : "flashlight.off.fill",
                          titel: nil) { kamera.licht(!kamera.lichtAn) }
                }
            }
        }
        .opacity(arbeitet ? 0.5 : 1)
        .disabled(arbeitet)
    }

    private func knopf(_ symbol: String, titel: String?, betont: Bool = false,
                       aktion: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            aktion()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                if let titel {
                    Text(titel)
                        .font(Theme.font(14, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, titel == nil ? 12 : 15)
            .frame(height: 38)
            .background {
                Capsule().fill(betont ? AnyShapeStyle(style.accentGradient)
                                      : AnyShapeStyle(Color.black.opacity(0.45)))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Einfrieren und auftauen

    /// Ein Tipp auf die Fläche: einfrieren, wenn das Bild läuft — sonst
    /// wieder auftauen. Dasselbe, was die Knöpfe tun, nur schneller
    /// erreichbar.
    private func umschalten() {
        guard interactive, !arbeitet else { return }
        switch kamera.erlaubnis {
        case .unbekannt:
            kamera.frageErlaubnis()
        case .verweigert:
            break
        case .erlaubt:
            eingefroren ? auftauen() : einfrieren()
        }
    }

    private func einfrieren() {
        guard !arbeitet else { return }
        arbeitet = true
        let verhaeltnis = vorschau.height > 0 ? vorschau.width / vorschau.height : 0
        kamera.friereEin(verhaeltnis: verhaeltnis, winkel: Videolage.jetzt) { bild in
            defer { arbeitet = false }
            guard let bild, let daten = bild.jpegData(compressionQuality: 0.85),
                  let name = onSichern(daten)
            else { return }
            content.eingefroren = name
            Haptics.success()
        }
    }

    private func auftauen() {
        content.eingefroren = nil
        Haptics.tap()
    }

    /// Das Standbild zusätzlich als eigenes Bildelement ablegen — so bleibt
    /// es auf der Tafel stehen, während die Kamera weiterläuft.
    private func ablegen() {
        guard let datei = content.eingefroren else { return }
        onAblegen(datei)
        content.eingefroren = nil
    }

    // MARK: - Kamera an und aus

    private func pruefeBedarf() {
        let gebraucht = interactive && !eingefroren && kamera.erlaubnis == .erlaubt
        if gebraucht { anmelden() } else { abmelden() }
    }

    private func anmelden() {
        guard !angemeldet else { return }
        angemeldet = true
        kamera.anmelden()
    }

    private func abmelden() {
        guard angemeldet else { return }
        angemeldet = false
        kamera.abmelden()
    }
}
