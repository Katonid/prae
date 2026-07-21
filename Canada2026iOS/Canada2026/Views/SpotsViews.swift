import SwiftUI
import MapKit

// Wetter, Fotospots, "Heute in der Nähe" und "Interessantes" – die
// Katalog- und Live-Daten-Bereiche der PWA in nativer Umsetzung.

// MARK: - Wetter

struct WeatherView: View {
    @State private var selectedStationId = TravelData.currentStation()?.id ?? TravelData.stations.first?.id ?? ""
    @State private var report: WeatherReport?
    @State private var errorMessage = ""
    @State private var loading = false

    private var selectedStation: Station? {
        TravelData.station(withId: selectedStationId)
    }

    var body: some View {
        List {
            Section {
                Picker("Ort", selection: $selectedStationId) {
                    ForEach(TravelData.stations) { station in
                        Text(station.name).tag(station.id)
                    }
                }
                .pickerStyle(.menu)
            } footer: {
                Text("Wetterdaten von Open-Meteo für den gewählten Reiseort, 45 Minuten zwischengespeichert.")
            }

            if loading {
                Section { ProgressView("Wetter wird geladen ...") }
            } else if !errorMessage.isEmpty {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Button("Erneut versuchen") { load() }
                }
            } else if let report {
                Section("Heute in \(report.placeName)") {
                    ForEach(report.dayparts) { part in
                        WeatherDaypartRow(part: part)
                    }
                    Text("Stand: \(report.fetchedAt, format: .dateTime.hour().minute()) Uhr")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Wetter")
        .onAppear { load() }
        .onChange(of: selectedStationId) { _, _ in load() }
    }

    private func load() {
        guard let station = selectedStation else { return }
        loading = true
        errorMessage = ""
        Task {
            do {
                let result = try await WeatherService.shared.fetchWeather(
                    lat: station.lat,
                    lng: station.lng,
                    placeName: station.name,
                    cacheId: station.id
                )
                await MainActor.run {
                    report = result
                    loading = false
                }
            } catch {
                await MainActor.run {
                    report = WeatherService.shared.cachedReport(cacheId: station.id, maxAge: 7 * 24 * 3600)
                    errorMessage = report == nil ? "Wetter derzeit nicht verfügbar – Internetverbindung prüfen." : ""
                    loading = false
                }
            }
        }
    }
}

struct WeatherDaypartRow: View {
    let part: WeatherDaypart

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: part.symbolName)
                .font(.title3)
                .foregroundStyle(Theme.lakeBlue)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(part.label)
                    .font(.subheadline.weight(.semibold))
                Text(part.condition)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let max = part.maxTemp, let min = part.minTemp {
                    Text(min == max ? "\(max)°" : "\(min)° – \(max)°")
                        .font(.subheadline.weight(.semibold))
                }
                if let wind = part.windSpeed {
                    Text("Wind bis \(wind) km/h")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Fotospots

struct PhotoSpotsView: View {
    @State private var selectedRegion = "Alle"
    @State private var showsMap = false

    private var regions: [String] { ["Alle"] + SpotsData.photoSpotRegions }
    private var filteredSpots: [PhotoSpot] {
        selectedRegion == "Alle"
            ? SpotsData.photoSpots
            : SpotsData.photoSpots.filter { $0.region == selectedRegion }
    }

    var body: some View {
        List {
            Section {
                Picker("Region", selection: $selectedRegion) {
                    ForEach(regions, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                Toggle("Karte anzeigen", isOn: $showsMap)
            } footer: {
                Text("\(filteredSpots.count) kuratierte Fotospots entlang der Route.")
            }

            if showsMap {
                Section {
                    Map(initialPosition: .region(TripMapView.initialRegion)) {
                        ForEach(filteredSpots) { spot in
                            Marker(spot.name, systemImage: "camera.fill", coordinate: spot.coordinate)
                                .tint(Theme.lakeBlue)
                        }
                    }
                    .frame(height: 280)
                    .listRowInsets(EdgeInsets())
                }
            }

            ForEach(regions.dropFirst().filter { selectedRegion == "Alle" || $0 == selectedRegion }, id: \.self) { region in
                Section(region) {
                    ForEach(SpotsData.photoSpots.filter { $0.region == region }) { spot in
                        PhotoSpotRow(spot: spot)
                    }
                }
            }
        }
        .navigationTitle("Fotospots")
    }
}

struct PhotoSpotRow: View {
    let spot: PhotoSpot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(spot.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let url = spot.mapsUrl {
                    Link(destination: url) {
                        Image(systemName: "mappin.and.ellipse")
                    }
                }
            }
            Text(spot.category)
                .font(.caption)
                .foregroundStyle(Theme.lakeBlue)
            Text(spot.description)
                .font(.footnote)
            Label(spot.bestTime, systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !spot.tips.isEmpty {
                Label(spot.tips, systemImage: "lightbulb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Heute in der Nähe

struct NearbyView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var locationProvider = LocationProvider()

    @State private var places: [NearbyPlace] = []
    @State private var category: NearbyCategory = .all
    @State private var loading = false
    @State private var statusText = "Wähle einen Ort oder nutze deinen Standort."
    @State private var centerName = ""

    private var filteredPlaces: [NearbyPlace] {
        var parkingCount = 0
        return places.filter { place in
            guard category == .all || place.category == category.rawValue else { return false }
            if place.category == NearbyCategory.parking.rawValue {
                parkingCount += 1
                return parkingCount <= 20
            }
            return true
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Kategorie", selection: $category) {
                    ForEach(NearbyCategory.allCases) { entry in
                        Text(entry.label).tag(entry)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    loadFromCurrentLocation()
                } label: {
                    Label("Um meinen Standort suchen", systemImage: "location")
                }
                Menu {
                    ForEach(TravelData.stations) { station in
                        Button(station.name) {
                            load(lat: station.lat, lng: station.lng, name: station.name)
                        }
                    }
                } label: {
                    Label("Um eine Station suchen", systemImage: "mappin.circle")
                }
            } footer: {
                Text("Live-Daten von OpenStreetMap (Overpass) im Umkreis von 3 km: Parken, Essen, Cafés, Supermärkte, Shopping und Tankstellen.")
            }

            Section(centerName.isEmpty ? "Ergebnisse" : "In der Nähe von \(centerName)") {
                if loading {
                    ProgressView("Orte werden gesucht ...")
                } else if filteredPlaces.isEmpty {
                    Text(statusText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(filteredPlaces.prefix(60)) { place in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .font(.subheadline.weight(.semibold))
                            Text([place.categoryLabel, place.detail].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.1f km", place.distanceKm))
                                .font(.caption.weight(.semibold))
                            if let url = place.mapsUrl {
                                Link(destination: url) {
                                    Image(systemName: "arrow.triangle.turn.up.right.circle")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("In der Nähe")
    }

    private func loadFromCurrentLocation() {
        loading = true
        statusText = "Standort wird ermittelt ..."
        locationProvider.requestLocation { location in
            DispatchQueue.main.async {
                guard let location else {
                    loading = false
                    statusText = "Standort nicht verfügbar – Berechtigung prüfen oder Station wählen."
                    return
                }
                load(lat: location.coordinate.latitude, lng: location.coordinate.longitude, name: "meinem Standort")
            }
        }
    }

    private func load(lat: Double, lng: Double, name: String) {
        loading = true
        centerName = name
        Task {
            do {
                let result = try await NearbyService.shared.fetchNearby(lat: lat, lng: lng)
                await MainActor.run {
                    places = result
                    loading = false
                    statusText = result.isEmpty ? "Keine Orte im Umkreis gefunden." : ""
                }
            } catch {
                await MainActor.run {
                    loading = false
                    statusText = "Overpass-Abfrage fehlgeschlagen – später erneut versuchen."
                }
            }
        }
    }
}

// MARK: - Interessantes (nach Interessen der Crew)

struct InterestingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedInterest = "Alle"

    private var allInterests: [String] {
        ["Alle"] + SpotsData.interestGroups.flatMap { $0.interests }
    }

    private var filteredPlaces: [InterestingPlace] {
        selectedInterest == "Alle"
            ? SpotsData.interestingPlaces
            : SpotsData.interestingPlaces.filter { $0.interests.contains(selectedInterest) }
    }

    private var myInterests: [String] {
        TravelData.memberInterests[store.deviceUser.name] ?? []
    }

    var body: some View {
        List {
            Section {
                Picker("Interesse", selection: $selectedInterest) {
                    ForEach(allInterests, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)

                if !myInterests.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Text("Deine Interessen:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(myInterests, id: \.self) { interest in
                                Button {
                                    selectedInterest = interest
                                } label: {
                                    Text(interest)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Theme.warmBeige)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            } footer: {
                Text("Kuratierte Orte passend zu den Interessen der Canada Crew – Sneaker, Sport, Technik, Shopping und mehr.")
            }

            Section("\(filteredPlaces.count) Orte") {
                ForEach(filteredPlaces) { place in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(place.name)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            if let url = place.mapsUrl {
                                Link(destination: url) {
                                    Image(systemName: "mappin.and.ellipse")
                                }
                            }
                        }
                        Text("\(place.region) · \(place.category)")
                            .font(.caption)
                            .foregroundStyle(Theme.lakeBlue)
                        Text(place.description)
                            .font(.footnote)
                        HStack(spacing: 4) {
                            ForEach(place.interests, id: \.self) { interest in
                                Text(interest)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Theme.warmBeige)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Interessantes")
    }
}
