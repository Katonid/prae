import SwiftUI
import MapKit

// Karte: alle Einträge mit Standort als Pins, unten Summe + Liste.

struct MapScreen: View {
    @EnvironmentObject var store: AppStore
    @State private var showList = true
    @State private var editorExpense: Expense?

    var body: some View {
        ZStack(alignment: .top) {
            if let trip = store.activeTrip {
                let located = store.expenses(for: trip.id).filter { $0.latitude != nil && $0.longitude != nil }

                Map(initialPosition: startPosition(located)) {
                    ForEach(located) { expense in
                        Annotation(expense.title, coordinate: CLLocationCoordinate2D(
                            latitude: expense.latitude ?? 0,
                            longitude: expense.longitude ?? 0
                        )) {
                            Button {
                                editorExpense = expense
                            } label: {
                                CategoryBadge(category: expense.category, size: 34)
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                                    .shadow(radius: 3)
                            }
                        }
                    }
                    UserAnnotation()
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .ignoresSafeArea(edges: .top)

                header(trip)

                VStack {
                    Spacer()
                    if showList {
                        summarySheet(trip: trip, located: located)
                    } else {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation { showList = true }
                            } label: {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(width: 48, height: 48)
                                    .background(Circle().fill(Theme.card))
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
        }
        .sheet(item: $editorExpense) { expense in
            EntryEditorView(existing: expense)
        }
    }

    private func header(_ trip: Trip) -> some View {
        HStack {
            HStack(spacing: 8) {
                Text(trip.name)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textDim)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.background.opacity(0.7)))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func startPosition(_ located: [Expense]) -> MapCameraPosition {
        guard !located.isEmpty else { return .userLocation(fallback: .automatic) }
        let latitudes = located.compactMap(\.latitude)
        let longitudes = located.compactMap(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: latitudes.reduce(0, +) / Double(latitudes.count),
            longitude: longitudes.reduce(0, +) / Double(longitudes.count)
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.5, (latitudes.max()! - latitudes.min()!) * 1.6),
            longitudeDelta: max(0.5, (longitudes.max()! - longitudes.min()!) * 1.6)
        )
        return .region(MKCoordinateRegion(center: center, span: span))
    }

    private func summarySheet(trip: Trip, located: [Expense]) -> some View {
        let sum = located.reduce(0) { $0 + $1.homeValue(in: trip) }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Summe: \(Formatters.money(sum, trip.homeCurrency))")
                        .font(.title3.bold())
                    Text("\(located.count) Einträge mit Standort")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textDim)
                }
                Spacer()
                Button {
                    withAnimation { showList = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Theme.cardSoft))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(located.sorted { abs($0.homeValue(in: trip)) > abs($1.homeValue(in: trip)) }) { expense in
                        Button {
                            editorExpense = expense
                        } label: {
                            HStack(spacing: 12) {
                                CategoryBadge(category: expense.category, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(expense.title)
                                        .foregroundStyle(Theme.textPrimary)
                                        .lineLimit(1)
                                    Text(expense.placeName.nonEmpty ?? expense.category.label)
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.blue.opacity(0.85))
                                        .lineLimit(1)
                                }
                                Spacer()
                                AmountText(expense: expense, trip: trip)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 260)
            .padding(.bottom, 86)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.background.opacity(0.97))
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
