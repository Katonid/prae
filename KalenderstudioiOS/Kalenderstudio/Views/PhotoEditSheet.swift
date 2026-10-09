import SwiftUI

/// Foto einer Fläche tauschen, zoomen und verschieben — mit Live-Vorschau
/// der ganzen Seite.
struct PhotoEditSheet: View {
    @Binding var project: CalendarProject
    let target: PhotoTarget

    @Environment(\.dismiss) private var dismiss
    @State private var dragStart: PhotoPlacement?

    private var current: PhotoPlacement? {
        project.placement(key: target.key, index: target.index)
    }

    private var captionBinding: Binding<String> {
        Binding(
            get: { project.captions[target.key] ?? "" },
            set: { project.captions[target.key] = $0.isEmpty ? nil : $0 }
        )
    }

    private var zoomBinding: Binding<Double> {
        Binding(
            get: { current?.zoom ?? 1 },
            set: { z in project.updatePlacement(key: target.key, index: target.index) { $0.zoom = z } }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                preview
                    .frame(maxHeight: .infinity)
                    .background(StudioBackdrop())
                controls
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Automatisch") {
                        project.placements[target.key] = nil
                    }
                }
            }
        }
    }

    private var title: String {
        project.photoSlots.first(where: { $0.key == target.key })?.label ?? "Foto"
    }

    private var preview: some View {
        GeometryReader { geo in
            if let page = project.page(forPhotoKey: target.key) {
                let marks = CalendarMarks.build(for: project)
                let size = ScaledPageView.displaySize(project.format, scale: 1, guides: false)
                let scale = min((geo.size.width - 32) / size.width, (geo.size.height - 32) / size.height)
                ScaledPageView(project: project, page: page, marks: marks, scale: scale)
                    .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(scale: scale, pageWidth: size.width))
                    .overlay(alignment: .top) {
                        Text("Zum Verschieben ziehen")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(.black.opacity(0.5)))
                            .foregroundStyle(.white)
                            .padding(.top, 8)
                    }
            }
        }
    }

    private func dragGesture(scale: CGFloat, pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if dragStart == nil { dragStart = current }
                guard let start = dragStart else { return }
                // Ein Viertel der Seitenbreite Weg = voller Verschiebeweg.
                let range = max(pageWidth * scale * 0.25, 40) * CGFloat(start.zoom)
                let dx = Double(value.translation.width / range)
                let dy = Double(value.translation.height / range)
                project.updatePlacement(key: target.key, index: target.index) {
                    $0.offsetX = min(max(start.offsetX + dx, -1), 1)
                    $0.offsetY = min(max(start.offsetY + dy, -1), 1)
                }
            }
            .onEnded { _ in dragStart = nil }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(project.photos) { photo in
                        Button {
                            project.setPhoto(photo.id, key: target.key, index: target.index)
                        } label: {
                            ThumbImage(id: photo.id)
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(current?.photoID == photo.id ? Color.accentColor : .clear, lineWidth: 3))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "minus.magnifyingglass")
                    Slider(value: zoomBinding, in: 1...4)
                    Image(systemName: "plus.magnifyingglass")
                }
                .disabled(current == nil)
                HStack {
                    Button {
                        project.updatePlacement(key: target.key, index: target.index) {
                            $0.zoom = 1
                            $0.offsetX = 0
                            $0.offsetY = 0
                        }
                    } label: {
                        Label("Ausschnitt zurücksetzen", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(current == nil)
                    Spacer()
                }
                TextField("Bildunterschrift (optional)", text: captionBinding)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 14)
        .background(.regularMaterial)
    }
}
