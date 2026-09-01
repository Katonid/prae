//  AlarmHistoryView.swift
//  What happened, and who answered.
//
//  Read after the fact, in a debrief. So it shows the two things a debrief
//  argues about: how long it took from the alarm to each acknowledgement, and
//  who never answered at all.

import SwiftUI

struct AlarmHistoryView: View {

    @EnvironmentObject private var model: AppModel
    @State private var alarms: [Alarm] = []

    var body: some View {
        List {
            if alarms.isEmpty {
                Text("Noch kein Alarm — auch kein Probealarm.")
                    .foregroundStyle(.secondary)
            }
            ForEach(alarms) { alarm in
                NavigationLink {
                    AlarmDetailView(alarm: alarm).environmentObject(model)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: alarm.type.symbol)
                            .foregroundStyle(alarm.type.tint)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(alarm.type.title).font(.headline)
                            Text(Clock.dayAndTime.string(from: alarm.createdAt)
                                 + (alarm.location.map { " · \($0)" } ?? ""))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if alarm.isActive {
                            Text("läuft").font(.caption).foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .navigationTitle("Historie")
        .task {
            do { alarms = try await model.backend.fetchAlarmHistory(limit: 100) }
            catch { model.report(error) }
        }
    }
}

struct AlarmDetailView: View {

    let alarm: Alarm

    @EnvironmentObject private var model: AppModel
    @State private var acks: [Ack] = []
    @State private var messages: [Message] = []
    @State private var members: [Member] = []

    var body: some View {
        List {
            Section("Alarm") {
                labelled("Art", alarm.type.title)
                labelled("Ort", alarm.location ?? "—")
                labelled("Ausgelöst von", alarm.triggeredByName)
                labelled("Ausgelöst", Clock.dayAndTime.string(from: alarm.createdAt))
                if let clearedAt = alarm.clearedAt {
                    labelled("Entwarnung", Clock.dayAndTime.string(from: clearedAt))
                    labelled("Entwarnt von", alarm.clearedByName ?? "—")
                }
            }

            Section("Rückmeldungen (\(acks.count))") {
                if acks.isEmpty { Text("Keine.").foregroundStyle(.secondary) }
                ForEach(acks) { ack in
                    HStack {
                        Image(systemName: ack.state.symbol).foregroundStyle(ack.state.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ack.displayName).fontWeight(.semibold)
                            Text(ack.state.label + (ack.location.map { " · \($0)" } ?? ""))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        // The number a debrief actually wants: how long from
                        // the alarm to this answer.
                        Text(delay(ack)).font(.caption).monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !missing.isEmpty {
                Section {
                    ForEach(missing, id: \.id) { member in
                        Text(member.displayName)
                    }
                } header: {
                    Text("Ohne Rückmeldung (\(missing.count))")
                } footer: {
                    Text("Ohne Rückmeldung heißt nicht „hat nichts gehört“ — das "
                         + "iPad kann aus gewesen sein. Es heißt: hier ist "
                         + "nachzufragen.")
                }
            }

            if !messages.isEmpty {
                Section("Nachrichten") {
                    ForEach(messages) { message in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(message.senderName) · "
                                 + Clock.time.string(from: message.createdAt))
                                .font(.caption).foregroundStyle(.secondary)
                            Text(message.text)
                        }
                    }
                }
            }
        }
        .navigationTitle(alarm.type.short)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                acks = try await model.backend.fetchAcks(alarmId: alarm.id)
                messages = try await model.backend.fetchMessages(alarmId: alarm.id)
                members = try await model.backend.fetchMembers()
            } catch {
                model.report(error)
            }
        }
    }

    private var missing: [Member] {
        let answered = Set(acks.map(\.userId))
        return members.filter { !answered.contains($0.userId) }
    }

    private func delay(_ ack: Ack) -> String {
        let seconds = Int(ack.createdAt.timeIntervalSince(alarm.createdAt))
        guard seconds >= 0 else { return "—" }
        return seconds < 60 ? "+\(seconds) s" : "+\(seconds / 60) min"
    }

    private func labelled(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}
