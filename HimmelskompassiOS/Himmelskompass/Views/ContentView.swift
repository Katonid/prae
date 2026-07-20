//
//  ContentView.swift
//  Himmelskompass
//
//  Hauptansicht: Datum/Ort-Steuerung, Kartenvorschau und die drei Bereiche
//  Zeiten / Kompass / Nacht wie in der Web-App.
//

import SwiftUI

enum AppTab: String, CaseIterable {
    case zeiten, kompass, nacht

    var title: String {
        switch self {
        case .zeiten: return "☀️ Zeiten"
        case .kompass: return "🧭 Kompass"
        case .nacht: return "🌌 Nacht"
        }
    }
}

enum ARMode {
    case iss, sunmoon, planets
}

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @AppStorage("hk-tab") private var tabRaw = AppTab.zeiten.rawValue
    @State private var showFullscreenMap = false
    @State private var arMode: ARMode?
    @State private var started = false

    private var tab: AppTab { AppTab(rawValue: tabRaw) ?? .zeiten }

    var body: some View {
        ZStack {
            HKColor.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 12) {
                    Text("🌗 Himmelskompass")
                        .font(.title3.bold())
                        .foregroundStyle(HKColor.fg)
                        .padding(.top, 4)

                    controlsCard

                    tabBar

                    switch tab {
                    case .zeiten:
                        SunCardView(openAR: { arMode = .sunmoon })
                        MoonCardView()
                    case .kompass:
                        CompassCardView(openAR: { arMode = .sunmoon })
                    case .nacht:
                        MilkyWayCardView()
                        ISSCardView(openAR: { arMode = .iss })
                        PlanetsCardView(openAR: { arMode = .planets })
                        AuroraCardView()
                    }

                    Text("Himmelskompass · Kartendaten © Apple Maps · ISS-Bahndaten © CelesTrak · Weltraumwetter © NOAA SWPC")
                        .font(.caption2)
                        .foregroundStyle(HKColor.fgDim)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 8)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: 860)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            guard !started else { return }
            started = true
            state.start()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            state.minuteTick()
        }
        .fullScreenCover(isPresented: $showFullscreenMap) {
            FullscreenMapView()
                .environmentObject(state)
        }
        .fullScreenCover(item: Binding(
            get: { arMode.map { ARModeBox(mode: $0) } },
            set: { arMode = $0?.mode }
        )) { box in
            ARSkyView(mode: box.mode)
                .environmentObject(state)
        }
    }

    // MARK: - Steuerung (Datum, Ort, Kartenvorschau)

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Datum")
                        .font(.caption)
                        .foregroundStyle(HKColor.fgDim)
                    DatePicker("Datum",
                               selection: Binding(
                                   get: { state.selectedDayAsDate },
                                   set: { state.selectedDayAsDate = $0 }
                               ),
                               displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "de_DE"))
                        .environment(\.timeZone, state.timeZone)
                        .colorScheme(.dark)
                }
                Spacer()
                Button("Heute") { state.goToToday() }
                    .buttonStyle(HKButtonStyle())
                Button {
                    state.locate()
                } label: {
                    if state.locating {
                        ProgressView().tint(HKColor.fg)
                    } else {
                        Text("📍 Standort")
                    }
                }
                .buttonStyle(HKButtonStyle())
            }

            Text(state.locating ? "Standort wird ermittelt …" : state.locationLabel)
                .font(.caption)
                .foregroundStyle(HKColor.fgDim)
                .lineLimit(2)

            MapPreviewView()
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(HKColor.border, lineWidth: 1))
                .contentShape(Rectangle())
                .onTapGesture { showFullscreenMap = true }

            Text("Tippe auf die Karte für die Vollbild-Ansicht mit Sonnen-/Mondbahnen – dort wählst du den Ort per Tippen auf die Karte.")
                .font(.caption2)
                .foregroundStyle(HKColor.fgDim)
        }
        .hkCard()
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases, id: \.self) { t in
                Button {
                    tabRaw = t.rawValue
                } label: {
                    Text(t.title)
                        .font(.subheadline.weight(tab == t ? .semibold : .regular))
                        .foregroundStyle(tab == t ? HKColor.bg : HKColor.fg)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(tab == t ? HKColor.accent : HKColor.card2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

private struct ARModeBox: Identifiable {
    var mode: ARMode
    var id: Int {
        switch mode {
        case .iss: return 0
        case .sunmoon: return 1
        case .planets: return 2
        }
    }
}

struct HKButtonStyle: ButtonStyle {
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundStyle(HKColor.fg)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(active ? HKColor.border : HKColor.card2)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(HKColor.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
