//  AlarmScreenView.swift
//  What everybody sees while an alarm is running.
//
//  Read from two metres away, on an iPad lying flat on a desk, by somebody who
//  is frightened. That is the design brief, and it decides everything: the
//  type of alarm is the largest thing on the screen, the two acknowledgement
//  buttons are the size of a palm, and nothing scrolls that has to be read in
//  the first two seconds.
//
//  A drill is marked as a drill in three ways at once — the grey colour, the
//  word PROBEALARM in the headline, and a banner across the top. One of them
//  will survive being glanced at.

import SwiftUI
import UIKit

struct AlarmScreenView: View {

    let alarm: Alarm

    @EnvironmentObject private var model: AppModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showsChat = false

    private var isWide: Bool { sizeClass == .regular }

    var body: some View {
        ZStack {
            alarm.type.tint.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    if alarm.type.isDrill { drillBanner }
                    headline
                    facts
                    if let instruction = alarm.instruction { instructionCard(instruction) }
                    acknowledgement
                    emergencyCall
                    responses
                    chatButton
                    if model.mayClear(alarm) { allClearButton }
                    closeButton
                }
                .padding(24)
                .frame(maxWidth: isWide ? 900 : .infinity)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showsChat) {
            AlarmChatView(alarm: alarm).environmentObject(model)
        }
    }

    // MARK: - Pieces

    private var drillBanner: some View {
        Text("PROBEALARM – ES BESTEHT KEINE GEFAHR")
            .font(.system(size: 22, weight: .heavy, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(.black)
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color.yellow, in: RoundedRectangle(cornerRadius: 14))
    }

    private var headline: some View {
        VStack(spacing: 10) {
            Image(systemName: alarm.type.symbol)
                .font(.system(size: 68, weight: .semibold))
            Text(alarm.type.title)
                .bigTitle()
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .padding(.top, 8)
    }

    private var facts: some View {
        VStack(spacing: 8) {
            factRow("Ort", alarm.location ?? "ohne Ortsangabe")
            factRow("Ausgelöst von", alarm.triggeredByName)
            factRow("Uhrzeit", Clock.timeWithSeconds.string(from: alarm.createdAt))
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
    }

    private func factRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.75))
            Spacer()
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }

    private func instructionCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Was jetzt zu tun ist")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.75))
            Text(text)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
    }

    /// Two buttons, and after the tap the answer stays visible.
    ///
    /// Showing what was answered matters as much as the answering: during an
    /// incident people forget within a minute whether they already pressed it,
    /// and pressing again would be the only way to find out.
    @ViewBuilder
    private var acknowledgement: some View {
        if model.hasAcknowledged(alarm) {
            let mine = model.acks.first { $0.userId == model.member?.userId }
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill").font(.title)
                VStack(alignment: .leading) {
                    Text("Deine Rückmeldung ist gesendet").font(.headline)
                    if let mine {
                        Text(mine.state.label).font(.subheadline).opacity(0.85)
                    }
                }
                Spacer()
                Button("Ändern") { Task { await sendAck(.needsHelp) } }
                    .buttonStyle(.bordered)
                    .tint(.white)
            }
            .foregroundStyle(.white)
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 18))
        } else {
            VStack(spacing: 14) {
                ackButton(.secured, title: "Gesehen – Klasse gesichert")
                ackButton(.needsHelp, title: "Gesehen – Hilfe nötig")
            }
        }
    }

    private func ackButton(_ state: AckState, title: String) -> some View {
        Button {
            Task { await sendAck(state) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: state.symbol).font(.title)
                Text(title).font(.system(size: 25, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.black)
            .padding(.vertical, 26)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    private func sendAck(_ state: AckState) async {
        await model.acknowledge(alarm, state: state, location: alarm.location)
    }

    /// The 110 button, and the honest alternative when there is no telephony.
    ///
    /// Most school iPads are Wi-Fi only. Offering a dial button that does
    /// nothing would be worse than offering none: somebody would press it and
    /// believe the call was made.
    @ViewBuilder
    private var emergencyCall: some View {
        let url = URL(string: "tel://110")
        if let url, UIApplication.shared.canOpenURL(url) {
            Button {
                UIApplication.shared.open(url)
            } label: {
                Label("Notruf 110", systemImage: "phone.fill")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black.opacity(0.55))
        } else {
            Label("Notruf 110 über Telefon oder Sekretariat — dieses iPad kann nicht telefonieren.",
                  systemImage: "phone.badge.waveform")
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    /// Everyone sees the count; only the leadership sees who.
    ///
    /// The count tells a colleague "I am not alone in this". The list is a
    /// coordination tool, and a live roll call of who has not answered yet is
    /// not something the whole staff needs to watch.
    private var responses: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rückmeldungen").font(.headline)
                Spacer()
                Text("\(model.acks.count)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
            if model.isAdmin {
                if model.acks.isEmpty {
                    Text("Noch niemand.").font(.subheadline).opacity(0.8)
                } else {
                    ForEach(model.acks) { ack in
                        HStack(spacing: 10) {
                            Image(systemName: ack.state.symbol)
                            Text(ack.displayName).fontWeight(.semibold)
                            Text(ack.state.label).opacity(0.8)
                            if let place = ack.location {
                                Text("· \(place)").opacity(0.7)
                            }
                            Spacer()
                            Text(Clock.time.string(from: ack.createdAt)).opacity(0.7)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
    }

    private var chatButton: some View {
        Button {
            showsChat = true
        } label: {
            Label(model.messages.isEmpty
                  ? "Nachrichten zum Alarm"
                  : "Nachrichten zum Alarm (\(model.messages.count))",
                  systemImage: "bubble.left.and.bubble.right.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.bordered)
        .tint(.white)
    }

    private var allClearButton: some View {
        Button {
            Task { await model.clear(alarm) }
        } label: {
            Label("Entwarnung geben", systemImage: "bell.slash.fill")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        }
        .buttonStyle(.borderedProminent)
        .tint(.black.opacity(0.55))
    }

    /// Closing the screen does not end the alarm — and says so.
    private var closeButton: some View {
        Button("Ansicht schließen (Alarm läuft weiter)") {
            model.showsAlarmScreen = false
        }
        .font(.footnote)
        .foregroundStyle(.white.opacity(0.7))
        .padding(.top, 4)
    }
}

struct AlarmScreenView_Previews: PreviewProvider {
    static var previews: some View {
        AlarmScreenView(alarm: PreviewModels.sampleAlarm)
            .environmentObject(PreviewModels.joined(runningAlarm: true))
    }
}
