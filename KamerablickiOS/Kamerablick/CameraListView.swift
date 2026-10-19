import SwiftUI

struct CameraListView: View {
    @Environment(CameraStore.self) private var store
    @State private var playing: CameraRef?
    @State private var editing: Camera?
    @State private var isNew = false
    @State private var thumbnailRefresh = 0

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 14)]

    var body: some View {
        NavigationStack {
            Group {
                if store.cameras.isEmpty {
                    ContentUnavailableView {
                        Label("Noch keine Kameras", systemImage: "web.camera")
                    } description: {
                        Text("Füge deine erste IP-Kamera mit RTSP-Adresse hinzu.")
                    } actions: {
                        Button("Kamera hinzufügen") { addCamera() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(store.cameras) { camera in
                                CameraTile(camera: camera, refresh: thumbnailRefresh)
                                    .overlay(alignment: .topTrailing) {
                                        // Sichtbarer Weg zu Bearbeiten/Löschen – das
                                        // Kontextmenü (langer Druck) findet man nicht.
                                        Menu { menu(for: camera) } label: {
                                            Image(systemName: "ellipsis")
                                                .font(.body.weight(.bold))
                                                .foregroundStyle(.white)
                                                .frame(width: 36, height: 36)
                                                .background(.black.opacity(0.35), in: Circle())
                                        }
                                        .padding(6)
                                    }
                                    .onTapGesture { playing = CameraRef(id: camera.id) }
                                    .contextMenu { menu(for: camera) }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Kameras")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addCamera() } label: { Image(systemName: "plus") }
                }
            }
            .fullScreenCover(item: $playing, onDismiss: { thumbnailRefresh += 1 }) { ref in
                PlayerView(cameraID: ref.id)
            }
            .sheet(item: $editing) { camera in
                CameraEditView(camera: camera, isNew: isNew)
            }
        }
    }

    @ViewBuilder private func menu(for camera: Camera) -> some View {
        Button { isNew = false; editing = camera } label: {
            Label("Bearbeiten", systemImage: "pencil")
        }
        Button { _ = store.duplicate(camera) } label: {
            Label("Duplizieren", systemImage: "plus.square.on.square")
        }
        Button(role: .destructive) {
            Thumbnails.delete(for: camera.id)
            store.delete(camera)
        } label: {
            Label("Löschen", systemImage: "trash")
        }
    }

    private func addCamera() {
        isNew = true
        editing = Camera()
    }
}

struct CameraRef: Identifiable { let id: UUID }

private struct CameraTile: View {
    let camera: Camera
    let refresh: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let image = Thumbnails.image(for: camera.id) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(x: camera.mirrorHorizontal ? -1 : 1,
                                     y: camera.mirrorVertical ? -1 : 1)
                } else {
                    LinearGradient(colors: [Color.accentGreen, Color.accentGreen.opacity(0.7)],
                                   startPoint: .top, endPoint: .bottom)
                    Image(systemName: "web.camera.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .id(refresh)

            Text(camera.name)
                .font(.headline)
                .lineLimit(1)
            Text(camera.host)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }
}
