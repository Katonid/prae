import MapKit
import Photos
import SwiftUI

/// Angaben zu einer Aufnahme wie „ⓘ" in der Fotos-App (seit 1.0.15): Datum und Uhrzeit
/// ändern, Ort festlegen, ändern oder entfernen, dazu Dateiname, Format und Favorit.
/// Geschrieben wird in die Fotos-Datenbank (`Aenderungen`) — iCloud gleicht es ab.
struct InfoAnsicht: View {
    @State var asset: PHAsset
    /// Meldet die frisch gelesene Aufnahme nach jeder gespeicherten Änderung.
    var geaendert: (PHAsset) -> Void
    @Environment(\.dismiss) private var schliessen
    @Environment(Notizen.self) private var notizen
    @State private var datum = Date()
    @State private var adresse: String?
    @State private var ortWaehlen = false
    @State private var speichert = false
    @State private var meldung: String?
    @State private var aufloesung = Adressaufloesung()

    private var aenderbar: Bool { asset.canPerform(.properties) }
    private var datumGeaendert: Bool { abs(datum.timeIntervalSince(asset.creationDate ?? datum)) >= 1 }

    var body: some View {
        NavigationStack {
            Form {
                if let t = notizen.titel(asset.localIdentifier) {
                    Section { Text(t).font(.headline) }
                }
                Section("Aufnahmedatum") {
                    DatePicker("Datum und Uhrzeit", selection: $datum, displayedComponents: [.date, .hourAndMinute])
                        .disabled(!aenderbar || speichert)
                    if datumGeaendert {
                        Button("Neues Datum sichern") { Task { await datumSichern() } }
                            .disabled(speichert)
                        Button("Zurücksetzen", role: .cancel) { datum = asset.creationDate ?? Date() }
                    }
                }
                Section("Ort") {
                    if let k = asset.location?.coordinate {
                        Map(initialPosition: .region(MKCoordinateRegion(center: k, latitudinalMeters: 1500, longitudinalMeters: 1500))) {
                            Marker("", systemImage: "camera.fill", coordinate: k)
                        }
                        .frame(height: 170)
                        .listRowInsets(EdgeInsets())
                        .id("\(k.latitude),\(k.longitude)")
                        Text(adresse ?? "Adresse wird gesucht …")
                        Text(Koordinaten.text(k)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Button("Ort ändern …") { ortWaehlen = true }.disabled(!aenderbar || speichert)
                        Button("Ort entfernen", role: .destructive) { Task { await ortSichern(nil) } }.disabled(!aenderbar || speichert)
                    } else {
                        Text("Kein Ort gespeichert").foregroundStyle(.secondary)
                        Button("Ort festlegen …") { ortWaehlen = true }.disabled(!aenderbar || speichert)
                    }
                }
                Section("Details") {
                    LabeledContent("Datei", value: PHAssetResource.assetResources(for: asset).first?.originalFilename ?? "–")
                    LabeledContent("Art", value: art)
                    LabeledContent("Format", value: "\(asset.pixelWidth) × \(asset.pixelHeight) Pixel")
                    if asset.mediaType == .video { LabeledContent("Dauer", value: zeitText(asset.duration)) }
                    LabeledContent("Favorit", value: asset.isFavorite ? "ja" : "nein")
                }
                if !aenderbar {
                    Section {
                        Label("iOS erlaubt für diese Aufnahme keine Änderungen (z. B. aus einem geteilten Album).", systemImage: "lock")
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } }
                if speichert { ToolbarItem(placement: .principal) { ProgressView() } }
            }
            .sheet(isPresented: $ortWaehlen) {
                OrtWahlAnsicht(start: asset.location?.coordinate) { k in Task { await ortSichern(k) } }
            }
            .alert("Hinweis", isPresented: Binding(get: { meldung != nil }, set: { if !$0 { meldung = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(meldung ?? "") }
            .onAppear { datum = asset.creationDate ?? Date() }
            .task(id: asset.location.map { "\($0.coordinate.latitude),\($0.coordinate.longitude)" } ?? "") {
                adresse = nil
                if let k = asset.location?.coordinate { adresse = await aufloesung.adresse(fuer: k) }
            }
        }
    }

    private var art: String {
        let grund: String
        switch asset.mediaType {
        case .video: grund = "Video"
        case .image: grund = asset.mediaSubtypes.contains(.photoLive) ? "Live Photo" : "Foto"
        default: grund = "Aufnahme"
        }
        return asset.ist360 ? "360°-" + grund : grund
    }

    private func datumSichern() async {
        speichert = true
        defer { speichert = false }
        do {
            let neu = try await Aenderungen.datum(asset, datum)
            asset = neu
            geaendert(neu)
        } catch {
            if !Aenderungen.abgebrochen(error) { meldung = error.localizedDescription }
        }
    }

    private func ortSichern(_ k: CLLocationCoordinate2D?) async {
        speichert = true
        defer { speichert = false }
        do {
            let neu = try await Aenderungen.ort(asset, k)
            asset = neu
            geaendert(neu)
        } catch {
            if !Aenderungen.abgebrochen(error) { meldung = error.localizedDescription }
        }
    }
}

/// Album wählen, in das Aufnahmen gelegt werden (eigene Alben und Galerie-Alben).
struct AlbumWahl: View {
    var gewaehlt: (String) -> Void
    @Environment(FotoBibliothek.self) private var bibliothek
    @Environment(\.dismiss) private var schliessen
    @State private var alben: [Knoten] = []
    @State private var filter = ""

    var body: some View {
        NavigationStack {
            List {
                if alben.isEmpty {
                    Text("Kein eigenes Album vorhanden.").foregroundStyle(.secondary)
                }
                ForEach(alben.filter { filter.isEmpty || $0.titel.localizedCaseInsensitiveContains(filter) }) { k in
                    Button {
                        gewaehlt(k.id)
                        schliessen()
                    } label: {
                        Label(k.titel, systemImage: "rectangle.stack").foregroundStyle(.primary)
                    }
                }
            }
            .searchable(text: $filter, prompt: "Album suchen")
            .navigationTitle("Zu Album hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } } }
            .task { alben = bibliothek.zielAlben() }
        }
    }
}
