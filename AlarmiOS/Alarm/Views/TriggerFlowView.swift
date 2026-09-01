//  TriggerFlowView.swift
//  Raising an alarm: type, place, five seconds, done.
//
//  The countdown is the whole design. A false alarm in a school is expensive —
//  30 classrooms barricade themselves, parents hear about it, and the next
//  real alarm is met with a shrug. Five seconds with a cancel button the size
//  of a hand is what stands between a pocket tap and that.
//
//  Five and not ten: ten seconds is long enough to feel like the app is
//  arguing with you, and the person tapping is usually the person who can see
//  the reason.

import SwiftUI

struct TriggerFlowView: View {

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private enum Step: Equatable {
        case type
        case location(AlarmType)
        case countdown(AlarmType, String?)
        /// The countdown has run out and the alarm is on its way. A step of
        /// its own because sending can take up to half a minute when the
        /// network is poor (`AppModel.triggerRetryWindow`), and during that
        /// half minute the person needs to see that something is happening.
        case sending
    }

    @State private var step = Step.type

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .type:
                    typeList
                case .location(let type):
                    locationList(for: type)
                case .countdown(let type, let location):
                    CountdownView(type: type, location: location) {
                        step = .sending
                        Task {
                            if await model.trigger(type: type, location: location) != nil {
                                dismiss()
                            } else {
                                step = .type
                            }
                        }
                    } onCancel: {
                        step = .type
                    }
                case .sending:
                    sending
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !isCountingDown {
                        Button("Abbrechen") { dismiss() }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isCountingDown)
    }

    /// No way out while the countdown runs or the alarm is in flight. Swiping
    /// the sheet away mid-send would leave the person unsure whether it went.
    private var isCountingDown: Bool {
        switch step {
        case .countdown, .sending: return true
        case .type, .location: return false
        }
    }

    private var sending: some View {
        VStack(spacing: 22) {
            Spacer()
            ProgressView().scaleEffect(2)
            Text("Alarm wird gesendet …")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            if let notice = model.retryNotice {
                Text(notice)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 24)
            }
            Spacer()
        }
    }

    private var title: String {
        switch step {
        case .type: return "Welche Art?"
        case .location: return "Wo?"
        case .countdown: return "Achtung"
        case .sending: return "Wird gesendet"
        }
    }

    /// The drill sits at the bottom, visually apart.
    ///
    /// It is the only entry that admins alone may use, and putting it next to
    /// the intruder alarm would invite exactly the mis-tap the countdown is
    /// there to catch.
    private var typeList: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(AlarmType.allCases.filter { $0 != .test }, id: \.self) { type in
                    typeButton(type)
                }
                if model.isAdmin {
                    Divider().padding(.vertical, 8)
                    typeButton(.test)
                } else {
                    Text("Einen Probealarm löst die Leitung aus.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
    }

    private func typeButton(_ type: AlarmType) -> some View {
        Button {
            step = .location(type)
        } label: {
            HStack(spacing: 18) {
                Image(systemName: type.symbol).font(.system(size: 40))
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.title).font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(type.explanation).font(.subheadline).opacity(0.85)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(type.tint, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }

    private func locationList(for type: AlarmType) -> some View {
        let places = model.group?.locations ?? DefaultInstructions.locations
        return List {
            Section {
                ForEach(places, id: \.self) { place in
                    Button {
                        step = .countdown(type, place)
                    } label: {
                        HStack {
                            Text(place).font(.title3)
                            Spacer()
                            // The last place is pre-selected because the second
                            // tap is the expensive one when hands are shaking.
                            if place == model.store.lastLocation {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            } header: {
                Text("Ort")
            } footer: {
                Text("Die Liste pflegt die Leitung unter „Verwaltung“.")
            }

            Section {
                Button("Ohne Ortsangabe weiter") {
                    step = .countdown(type, nil)
                }
            }
        }
    }
}

/// Five seconds, one enormous way out.
private struct CountdownView: View {

    let type: AlarmType
    let location: String?
    let onFire: () -> Void
    let onCancel: () -> Void

    @State private var remaining = 5
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text(type.title)
                .bigTitle()
                .foregroundStyle(type.tint)
                .multilineTextAlignment(.center)
            if let location {
                Text(location).font(.title2).foregroundStyle(.secondary)
            }
            Text("\(remaining)")
                .font(.system(size: 140, weight: .black, design: .rounded))
                .monospacedDigit()
                .contentTransition(.identity)
            Text("Wird in \(remaining) Sekunden an das ganze Kollegium gesendet.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                stop()
                onCancel()
            } label: {
                Text("Abbrechen")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
            }
            .buttonStyle(.borderedProminent)
            .tint(.secondary)
        }
        .padding(28)
        .onAppear(perform: start)
        .onDisappear(perform: stop)
    }

    private func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                remaining -= 1
                if remaining <= 0 {
                    stop()
                    onFire()
                }
            }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }
}

struct TriggerFlowView_Previews: PreviewProvider {
    static var previews: some View {
        TriggerFlowView().environmentObject(PreviewModels.joined())
    }
}
