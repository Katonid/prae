//  AlarmChatView.swift
//  A few lines of text, for the length of one incident.
//
//  Not a messenger. There is no history across alarms, no private thread and
//  no read receipts: this is the channel for "Aula is clear" and "two children
//  missing from 3b", and everything that would make it feel like a chat app
//  would also make it slower to read.

import Combine
import SwiftUI

struct AlarmChatView: View {

    let alarm: Alarm

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            if model.messages.isEmpty {
                                Text("Noch keine Nachrichten.")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 40)
                                    .frame(maxWidth: .infinity)
                            }
                            ForEach(model.messages) { message in
                                bubble(message).id(message.id)
                            }
                        }
                        .padding(20)
                    }
                    // `onReceive` rather than `onChange`: the single-closure
                    // `onChange` is deprecated from iOS 17 while this app still
                    // builds for 16, and a publisher does the same job without
                    // an availability dance.
                    .onReceive(model.$messages) { list in
                        guard let last = list.last else { return }
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                Divider()
                composer
            }
            .navigationTitle("Nachrichten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private func bubble(_ message: Message) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(message.senderName).font(.subheadline).fontWeight(.semibold)
                Text(Clock.time.string(from: message.createdAt))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(message.text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(alarm.type.tint)
    }

    private var composer: some View {
        HStack(spacing: 12) {
            TextField("Nachricht", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
            Button {
                let text = draft
                draft = ""
                Task { await model.send(message: text, for: alarm) }
            } label: {
                Image(systemName: "paperplane.fill").font(.title2)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
    }
}

struct AlarmChatView_Previews: PreviewProvider {
    static var previews: some View {
        AlarmChatView(alarm: PreviewModels.sampleAlarm)
            .environmentObject(PreviewModels.joined(runningAlarm: true))
    }
}
