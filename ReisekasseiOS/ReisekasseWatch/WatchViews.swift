//
//  WatchViews.swift
//  ReisekasseWatch
//
//  Vier vertikale Seiten: Übersicht (Budgets), Einträge,
//  Schnelleingabe, Einstellungen (Reise, Name, Sync).
//

import SwiftUI

struct WatchRootView: View {
    @EnvironmentObject var store: WatchStore

    var body: some View {
        TabView {
            OverviewPage()
            EntriesPage()
            AddPage()
            SettingsPage()
        }
        .tabViewStyle(.verticalPage)
    }
}

// MARK: - Übersicht

struct OverviewPage: View {
    @EnvironmentObject var store: WatchStore

    var body: some View {
        ScrollView {
            if let trip = store.activeTrip {
                VStack(spacing: 10) {
                    Text(trip.name)
                        .font(.headline)

                    let total = store.totalSpent(trip)
                    budgetCard(
                        title: "Gesamt",
                        spent: total,
                        budget: trip.totalBudget,
                        currency: trip.homeCurrency
                    )

                    let today = store.spentToday(trip)
                    budgetCard(
                        title: "Heute",
                        spent: today,
                        budget: store.dailyBudget(trip),
                        currency: trip.homeCurrency
                    )
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.title2)
                    Text("Keine Reise sichtbar — in den Einstellungen (unterste Seite) deinen Namen wie auf dem iPhone eintragen und synchronisieren.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .navigationTitle("Kassenbuch")
    }

    private func budgetCard(title: String, spent: Double, budget: Double?, currency: String) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(WatchStore.money(spent, currency))
                .font(.system(size: 22, weight: .bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let budget, budget > 0 {
                Gauge(value: min(spent, budget), in: 0...budget) { EmptyView() }
                    .gaugeStyle(.accessoryLinear)
                    .tint(spent > budget ? .red : Color(red: 0.91, green: 0.29, blue: 0.40))
                Text("Verbleibend: \(WatchStore.money(budget - spent, currency))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
    }
}

// MARK: - Einträge

struct EntriesPage: View {
    @EnvironmentObject var store: WatchStore

    var body: some View {
        List {
            if let trip = store.activeTrip {
                let recent = store.recentExpenses(trip)
                if recent.isEmpty {
                    Text("Noch keine Einträge")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recent) { expense in
                        HStack(spacing: 8) {
                            Image(systemName: expense.category.symbol)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(expense.category.color))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(expense.title)
                                    .font(.footnote)
                                    .lineLimit(1)
                                Text(expense.date, format: .dateTime.day().month())
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 4)
                            Text(WatchStore.money(expense.signedAmount, expense.currency))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(expense.refunded ? .green : .primary)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .navigationTitle("Einträge")
    }
}

// MARK: - Schnelleingabe

struct AddPage: View {
    @EnvironmentObject var store: WatchStore
    @State private var input = ""
    @State private var feedback: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Neuer Eintrag")
                    .font(.headline)
                TextField("z. B. pizza 13,5 bar", text: $input)
                Button {
                    if let expense = store.quickAdd(input) {
                        feedback = "\(expense.title) — \(WatchStore.money(expense.amount, expense.currency)) ✓"
                        input = ""
                    } else {
                        feedback = "Bitte Name und Betrag angeben, z. B. „kaffee 4,50“."
                    }
                } label: {
                    Label("Speichern", systemImage: "checkmark.circle.fill")
                }
                .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                if let feedback {
                    Text(feedback)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Text("Diktat: Feld antippen und sprechen. Kategorie wird automatisch erkannt; „bar“, „karte“ oder „cad“ einfach mitsprechen.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Einstellungen

struct SettingsPage: View {
    @EnvironmentObject var store: WatchStore

    var body: some View {
        List {
            Section("Reise") {
                ForEach(store.visibleTrips) { trip in
                    Button {
                        store.activeTripId = trip.id
                    } label: {
                        HStack {
                            Text(trip.name)
                            Spacer()
                            if trip.id == store.activeTrip?.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            Section("Dein Name") {
                TextField("Name", text: $store.profileName)
            }
            Section("iCloud") {
                Button {
                    store.syncNow()
                } label: {
                    Label("Jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath")
                }
                Text(store.statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Einstellungen")
    }
}
