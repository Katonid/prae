import SwiftUI
import PhotosUI

// Gemeinsames Fotoalbum. Bilder werden lokal gespeichert und als CKAsset
// über CloudKit an alle Geräte verteilt.

struct PhotoAlbumView: View {
    @EnvironmentObject private var store: AppStore
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var importing = false

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 4)]

    var body: some View {
        ScrollView {
            if store.visiblePhotos.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Noch keine Fotos im Album.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 80)
            }
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(store.visiblePhotos) { photo in
                    NavigationLink {
                        PhotoDetailView(photoId: photo.id)
                    } label: {
                        PhotoThumbnail(photo: photo)
                    }
                }
            }
            .padding(4)
        }
        .navigationTitle("Fotoalbum")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if store.isCrew {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                        if importing {
                            ProgressView()
                        } else {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            importPhotos(items)
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) {
        importing = true
        Task {
            for item in items {
                if let raw = try? await item.loadTransferable(type: Data.self),
                   let jpeg = PhotoAlbumView.downscaledJPEG(from: raw) {
                    _ = store.addPhoto(imageData: jpeg, caption: "")
                }
            }
            pickerItems = []
            importing = false
        }
    }

    /// Bilder auf maximal 1600 px Kantenlänge verkleinern, damit Sync-Uploads klein bleiben.
    static func downscaledJPEG(from data: Data, maxDimension: CGFloat = 1600) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let largest = max(image.size.width, image.size.height)
        guard largest > maxDimension else { return image.jpegData(compressionQuality: 0.8) }
        let scale = maxDimension / largest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}

struct PhotoThumbnail: View {
    @EnvironmentObject private var store: AppStore
    let photo: PhotoItem

    var body: some View {
        GeometryReader { proxy in
            if let image = UIImage(contentsOfFile: store.photoFileURL(photo).path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.width)
                    .clipped()
            } else {
                ZStack {
                    Rectangle().fill(Color(.secondarySystemGroupedBackground))
                    VStack(spacing: 4) {
                        Image(systemName: "icloud.and.arrow.down")
                            .foregroundStyle(.secondary)
                        Text("Lädt ...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.width)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct PhotoDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let photoId: String

    @State private var caption = ""

    private var photo: PhotoItem? {
        store.data.photos.first { $0.id == photoId && !$0.deleted }
    }

    var body: some View {
        ScrollView {
            if let photo {
                VStack(alignment: .leading, spacing: 14) {
                    if let image = UIImage(contentsOfFile: store.photoFileURL(photo).path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    HStack {
                        MemberChip(name: photo.author)
                        Spacer()
                        Text(photo.createdAt, format: .dateTime.day().month().year().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let station = TravelData.station(withId: photo.stationId) {
                        Label(station.name, systemImage: "mappin.and.ellipse")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if canEdit {
                        TextField("Bildunterschrift", text: $caption, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                        Button("Bildunterschrift sichern") {
                            var copy = photo
                            copy.caption = caption
                            store.updatePhoto(copy)
                        }
                        .buttonStyle(.bordered)
                        .disabled(caption == photo.caption)
                    } else if !photo.caption.isEmpty {
                        Text(photo.caption)
                            .font(.body)
                    }

                    if let image = UIImage(contentsOfFile: store.photoFileURL(photo).path) {
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview(photo.caption.isEmpty ? "Canada 2026" : photo.caption, image: Image(uiImage: image))
                        ) {
                            Label("Foto teilen", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }

                    if canEdit {
                        Button(role: .destructive) {
                            store.deletePhoto(photo)
                            dismiss()
                        } label: {
                            Label("Foto löschen", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            } else {
                Text("Foto nicht gefunden.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 60)
            }
        }
        .navigationTitle("Foto")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { caption = photo?.caption ?? "" }
    }

    private var canEdit: Bool {
        guard let photo else { return false }
        return store.isCrew && (photo.author == store.deviceUser.name || store.isAdmin)
    }
}
