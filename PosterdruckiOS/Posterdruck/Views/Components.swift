import SwiftUI
import UIKit

/// Eine Posterseite in Vorschaugröße: Bild, Hintergrund und Hilfslinien.
/// Gerechnet wird in Druckpunkten (`PageGeometry`), `scale` verkleinert nur.
struct PosterPageView: View {
    let format: PosterFormat
    let item: PosterItem
    let scale: CGFloat
    var guides = true

    var body: some View {
        let g = PageGeometry(format: format, item: item)
        let r = PosterLayout.imageRect(item: item, geometry: g)
        let odd = item.quarterTurns % 2 == 1
        let w = (odd ? r.height : r.width) * scale
        let h = (odd ? r.width : r.height) * scale
        ZStack(alignment: .topLeading) {
            Rectangle().fill(item.background.color)
            PhotoThumb(id: item.photoID)
                .frame(width: max(w, 1), height: max(h, 1))
                .rotationEffect(.degrees(Double(item.quarterTurns) * 90))
                .position(x: r.midX * scale, y: r.midY * scale)
            if guides {
                GuidesOverlay(g: g, scale: scale)
            }
        }
        .frame(width: g.size.width * scale, height: g.size.height * scale)
        .clipped()
    }

    static func size(format: PosterFormat, item: PosterItem?, scale: CGFloat) -> CGSize {
        let g = PageGeometry(format: format, item: item)
        return CGSize(width: g.size.width * scale, height: g.size.height * scale)
    }
}

/// Beschnitt: leicht abgedunkelter Rand und die Schnittkante als rote
/// gestrichelte Linie. Ein Sicherheitsabstand, falls eingestellt, blau gestrichelt.
struct GuidesOverlay: View {
    let g: PageGeometry
    let scale: CGFloat

    var body: some View {
        let full = rect(g.fullRect)
        let trim = rect(g.trimRect)
        let safe = rect(g.safeRect)
        let lw: CGFloat = max(min(full.width / 220, 1.6), 0.8)
        ZStack(alignment: .topLeading) {
            Path { p in
                p.addRect(full)
                p.addRect(trim)
            }
            .fill(Color.white.opacity(0.35), style: FillStyle(eoFill: true))
            Path { $0.addRect(trim) }
                .stroke(Color.white.opacity(0.9), lineWidth: lw * 1.8)
            Path { $0.addRect(trim) }
                .stroke(Color.red, style: StrokeStyle(lineWidth: lw, dash: [5 * lw, 3.5 * lw]))
            if g.safeRect != g.trimRect {
                Path { $0.addRect(safe) }
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: lw * 0.8, dash: [2 * lw, 2.5 * lw]))
            }
        }
        .frame(width: full.width, height: full.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func rect(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX * scale, y: r.minY * scale, width: r.width * scale, height: r.height * scale)
    }
}

/// Vorschaubild eines Fotos, lädt abseits des Hauptfadens.
struct PhotoThumb: View {
    let id: UUID
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.25))
                    .overlay(ProgressView())
            }
        }
        .task(id: id) {
            let photo = id
            image = await Task.detached(priority: .userInitiated) {
                PhotoStore.shared.preview(photo)
            }.value
        }
    }
}

/// Kleines Schild mit der wirksamen Auflösung.
struct DPIBadge: View {
    let dpi: Double

    var body: some View {
        let q = PosterLayout.quality(dpi: dpi)
        Label("\(Int(dpi.rounded())) dpi", systemImage: q == .low ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color(q)))
            .foregroundStyle(.white)
    }

    private func color(_ q: PosterLayout.Quality) -> Color {
        switch q {
        case .good: return .green
        case .ok: return .orange
        case .low: return .red
        }
    }
}

/// Hintergrund der Arbeitsfläche — dunkel, damit das Poster leuchtet.
struct StudioBackdrop: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.12, green: 0.12, blue: 0.16),
                                Color(red: 0.05, green: 0.05, blue: 0.08)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Eingabefeld für Millimeter mit deutschem Komma.
struct MMField: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField(title, value: $value, format: .number.precision(.fractionLength(0...1)).locale(Locale(identifier: "de_DE")))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
                Text("mm").foregroundStyle(.secondary)
            }
        }
    }
}
