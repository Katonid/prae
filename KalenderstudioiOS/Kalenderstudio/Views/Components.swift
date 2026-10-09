import SwiftUI
import UIKit

/// Eine Seite verkleinert dargestellt. Ohne Hilfslinien wird nur das
/// Endformat gezeigt (wie nach dem Zuschnitt), mit Hilfslinien die ganze
/// Druckdatei samt Beschnitt.
struct ScaledPageView: View {
    let project: CalendarProject
    let page: PageSpec
    let marks: CalendarMarks
    let scale: CGFloat
    var showGuides = false

    var body: some View {
        let g = PageGeometry(project.format)
        if showGuides {
            PageView(project: project, page: page, marks: marks)
                .overlay(alignment: .topLeading) { GuidesOverlay(g: g, scale: scale) }
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: g.size.width * scale, height: g.size.height * scale, alignment: .topLeading)
        } else {
            PageView(project: project, page: page, marks: marks)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: g.size.width * scale, height: g.size.height * scale, alignment: .topLeading)
                .offset(x: -g.bleed * scale, y: -g.bleed * scale)
                .frame(width: g.trimRect.width * scale, height: g.trimRect.height * scale, alignment: .topLeading)
                .clipped()
        }
    }

    static func displaySize(_ format: PageFormat, scale: CGFloat, guides: Bool) -> CGSize {
        let g = PageGeometry(format)
        let s = guides ? g.size : g.trimRect.size
        return CGSize(width: s.width * scale, height: s.height * scale)
    }
}

/// Beschnitt (rot), Endformat (Linie) und Sicherheitsbereich (blau gestrichelt).
struct GuidesOverlay: View {
    let g: PageGeometry
    let scale: CGFloat

    var body: some View {
        let lw = 1.2 / max(scale, 0.05)
        ZStack(alignment: .topLeading) {
            Path { p in
                p.addRect(g.fullRect)
                p.addRect(g.trimRect)
            }
            .fill(Color.red.opacity(0.28), style: FillStyle(eoFill: true))
            Path { $0.addRect(g.trimRect) }
                .stroke(Color.red, lineWidth: lw)
            Path { $0.addRect(g.safeRect) }
                .stroke(Color.blue, style: StrokeStyle(lineWidth: lw, dash: [6 * lw, 4 * lw]))
        }
        .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

/// Hintergrund der Arbeitsfläche — dunkel wie ein Fotostudio.
struct StudioBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.10, blue: 0.14),
                                    Color(red: 0.05, green: 0.05, blue: 0.08)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color.white.opacity(0.08), .clear],
                           center: UnitPoint(x: 0.5, y: 0.35), startRadius: 10, endRadius: 600)
        }
        .ignoresSafeArea()
    }
}

/// Spiralbindung als Zierde der Vorschau.
struct SpiralBinding: View {
    let width: CGFloat
    var body: some View {
        let count = max(Int(width / 14), 6)
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                Capsule()
                    .fill(LinearGradient(colors: [Color(white: 0.85), Color(white: 0.45), Color(white: 0.8)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 4, height: 16)
                    .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(width: width * 0.94, height: 16)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Auswahlkachel mit Symbol — für Layouts und Stile.
struct ChoiceTile: View {
    let title: String
    let symbol: String
    var detail: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .medium))
                    .frame(height: 28)
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, minHeight: detail == nil ? 70 : 110)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .foregroundStyle(selected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

/// Kleine Vorschau einer Stilvorlage.
struct DesignSwatch: View {
    let design: Design
    let name: String
    let selected: Bool

    var body: some View {
        let format = PageFormat(widthMM: 120, heightMM: 85, bleedMM: 0, safetyMM: 6)
        let g = PageGeometry(format)
        let scale: CGFloat = 130 / g.size.width
        VStack(spacing: 6) {
            ZStack {
                PageBackground(design: design, geometry: g, seed: name)
                VStack(spacing: 2) {
                    Text(design.titleText("Januar"))
                        .font(design.fontTitle(g.unit * 14))
                        .tracking(design.titleTracking * g.unit * 12)
                        .foregroundStyle(design.text.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    HStack(spacing: g.unit * 3) {
                        ForEach([5, 6, 7], id: \.self) { n in
                            Text("\(n)")
                                .font(design.fontNumber(g.unit * 11))
                                .foregroundStyle(n == 7 ? design.holiday.color : design.text.color)
                        }
                    }
                    .padding(.horizontal, g.unit * 5)
                    .padding(.vertical, g.unit * 2)
                    .card(design, unit: g.unit)
                }
                .padding(g.unit * 6)
            }
            .frame(width: g.size.width, height: g.size.height)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: g.size.width * scale, height: g.size.height * scale, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : Color.black.opacity(0.1), lineWidth: selected ? 3 : 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            Text(name)
                .font(.caption.weight(selected ? .bold : .regular))
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
        }
    }
}
