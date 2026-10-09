import SwiftUI

extension View {
    /// Rahmen, Ecken und Schatten für ein Foto im Seitenlayout.
    func photoFrame(_ d: Design, unit: CGFloat, rounded: Bool = true) -> some View {
        let radius = rounded ? unit * 3 * d.corner : 0
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white, lineWidth: unit * 1.1 * d.photoBorder))
            .designShadow(d, unit: unit)
    }
}

/// Eine Fotofläche innerhalb des Sicherheitsbereichs, im gewählten Stil.
struct PhotoArea: View {
    let style: PhotoStyle
    let key: String
    let rc: RenderContext
    var showCaption = true

    var body: some View {
        GeometryReader { geo in
            content(geo.size)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var caption: String {
        guard showCaption else { return "" }
        return rc.project.captions[key]?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    @ViewBuilder
    private func content(_ s: CGSize) -> some View {
        let d = rc.design
        let u = rc.unit
        switch style {
        case .full:
            let p = rc.project.placements(for: key, count: 1)
            PhotoFill(placement: p[0], design: d, key: key, index: 0)
                .photoFrame(d, unit: u)
                .overlay(alignment: .bottomLeading) {
                    if !caption.isEmpty {
                        CaptionText(text: caption, rc: rc, onPhoto: true, size: u * 2.4)
                            .padding(u * 2)
                    }
                }
        case .passepartout:
            let p = rc.project.placements(for: key, count: 1)
            let mat = min(s.width, s.height) * 0.06
            let captionH = caption.isEmpty ? 0 : max(mat * 0.9, u * 3)
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Color(white: 0.985))
                    .designShadow(d, unit: u)
                VStack(spacing: 0) {
                    PhotoFill(placement: p[0], design: d, key: key, index: 0)
                        .overlay(Rectangle().strokeBorder(Color.black.opacity(0.12), lineWidth: max(u * 0.08, 0.3)))
                        .frame(width: max(s.width - 2 * mat, 1), height: max(s.height - 2 * mat - captionH, 1))
                        .padding(.top, mat)
                    if !caption.isEmpty {
                        Text(caption)
                            .font(d.fontBody(captionH * 0.45, weight: .medium))
                            .foregroundStyle(Color(white: 0.25))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.horizontal, mat)
                            .frame(height: captionH)
                    }
                }
            }
        case .polaroid:
            let p = rc.project.placements(for: key, count: 1)
            PolaroidView(placement: p[0], key: key, caption: caption, rc: rc)
                .frame(width: s.width * 0.92, height: s.height * 0.92)
        case .collage:
            let p = rc.project.placements(for: key, count: 3)
            let gap = u * 1.4
            HStack(spacing: gap) {
                PhotoFill(placement: p[0], design: d, key: key, index: 0)
                    .photoFrame(d, unit: u)
                    .frame(width: (s.width - gap) * 0.62)
                VStack(spacing: gap) {
                    PhotoFill(placement: p[1], design: d, key: key, index: 1)
                        .photoFrame(d, unit: u)
                    PhotoFill(placement: p[2], design: d, key: key, index: 2)
                        .photoFrame(d, unit: u)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if !caption.isEmpty {
                    CaptionText(text: caption, rc: rc, onPhoto: true, size: u * 2.2)
                        .padding(u * 2)
                }
            }
        }
    }
}

/// Sofortbild: weißer Rahmen, unten breiter, leicht gedreht.
struct PolaroidView: View {
    let placement: PhotoPlacement?
    let key: String
    let caption: String
    let rc: RenderContext
    var angle: Double = -2.5

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            // Seitenverhältnis des Fotos innerhalb des Rahmens ~ 1:1 bis 4:3,
            // je nach Fläche.
            let frameW = min(s.width, s.height * 1.25)
            let frameH = min(s.height, frameW / 1.12)
            let border = frameW * 0.05
            let bottom = frameW * 0.16
            VStack(spacing: 0) {
                PhotoFill(placement: placement, design: rc.design, key: key, index: 0)
                    .frame(width: frameW - 2 * border, height: frameH - border - bottom)
                    .padding([.top, .horizontal], border)
                ZStack {
                    if !caption.isEmpty {
                        Text(caption)
                            .font(FontLibrary.font("Bradley Hand", size: bottom * 0.42, weight: .bold))
                            .foregroundStyle(Color(white: 0.2))
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .padding(.horizontal, border)
                    }
                }
                .frame(width: frameW, height: bottom)
            }
            .background(Color(white: 0.99))
            .rotationEffect(.degrees(angle))
            .shadow(color: .black.opacity(0.18 + 0.3 * rc.design.shadow), radius: rc.unit * 2.2, x: rc.unit * 0.5, y: rc.unit * 1.2)
            .frame(width: s.width, height: s.height)
        }
    }
}

struct CaptionText: View {
    let text: String
    let rc: RenderContext
    let onPhoto: Bool
    let size: CGFloat

    var body: some View {
        Text(text)
            .font(rc.design.fontBody(size, weight: .semibold))
            .foregroundStyle(onPhoto ? Color.white : rc.design.text.color)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .textShadow(rc.design, unit: rc.unit, onPhoto: onPhoto)
    }
}
