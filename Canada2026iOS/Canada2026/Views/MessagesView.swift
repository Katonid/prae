import SwiftUI

// Nachrichten – Gruppenchat wie in der PWA. Crew sieht die Kanäle
// "STAN Crew" und "Alle zusammen", Betrachter nur "Alle zusammen".

struct MessagesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedChannel = "all"
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    private var channels: [AppStore.ChatChannel] { store.availableChannels }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if channels.count > 1 {
                    Picker("Kanal", selection: $selectedChannel) {
                        ForEach(channels, id: \.id) { channel in
                            let unread = store.unreadCount(channel: channel.id)
                            Text(unread > 0 ? "\(channel.title) (\(unread))" : channel.title)
                                .tag(channel.id)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }

                messageList

                inputBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Nachrichten")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { SyncStatusDot() }
            }
            .onAppear {
                if !channels.contains(where: { $0.id == selectedChannel }) {
                    selectedChannel = channels.first?.id ?? "all"
                }
                store.markChannelRead(selectedChannel)
            }
            .onChange(of: selectedChannel) { _, channel in
                store.markChannelRead(channel)
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    let messages = store.messages(in: selectedChannel)
                    if messages.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Noch keine Nachrichten – schreib die erste!")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 60)
                    }
                    ForEach(messages) { message in
                        MessageBubble(message: message, isMine: message.author == store.deviceUser.name)
                            .id(message.id)
                            .contextMenu {
                                if message.author == store.deviceUser.name || store.isAdmin {
                                    Button(role: .destructive) {
                                        store.deleteMessage(message)
                                    } label: {
                                        Label("Nachricht löschen", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
                .padding()
            }
            .onChange(of: store.messages(in: selectedChannel).count) { _, _ in
                if let last = store.messages(in: selectedChannel).last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
                store.markChannelRead(selectedChannel)
            }
            .onAppear {
                if let last = store.messages(in: selectedChannel).last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Nachricht an \(channels.first(where: { $0.id == selectedChannel })?.title ?? "alle") ...", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .focused($inputFocused)

            Button {
                store.sendMessage(draft, channel: selectedChannel)
                draft = ""
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Theme.canadaRed)
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool

    private var role: AccessRole { AccessRole(rawValue: message.authorRole) ?? .crew }

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if !isMine {
                    HStack(spacing: 6) {
                        Text(message.author)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.memberColor(message.author))
                        if role.isViewer {
                            Text(role.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Text(message.text)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isMine ? Theme.canadaRed : Color(.secondarySystemGroupedBackground))
                    .foregroundStyle(isMine ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(message.createdAt, format: .dateTime.day().month().hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !isMine { Spacer(minLength: 40) }
        }
    }
}
