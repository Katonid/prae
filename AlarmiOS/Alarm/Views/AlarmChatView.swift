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
    /// „Fertig" hat schon zweimal eine Nachricht verschluckt.
    @State private var fragtWegenEntwurf = false

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
                    // NICHT „Fertig". „Fertig" liest sich wie „abschicken",
                    // und genau so wurde es zweimal benutzt: Text eingetippt,
                    // oben getippt, Blatt zu, Nachricht nie gesendet
                    // (gemeldet 09/2026). Der Knopf heißt jetzt, was er tut.
                    Button("Schließen") {
                        if entwurfVorhanden { fragtWegenEntwurf = true } else { dismiss() }
                    }
                }
            }
            .alert("Nachricht noch nicht gesendet", isPresented: $fragtWegenEntwurf) {
                Button("Jetzt senden") { senden(); dismiss() }
                Button("Verwerfen", role: .destructive) { draft = ""; dismiss() }
                Button("Weiter schreiben", role: .cancel) { }
            } message: {
                Text("Im Feld steht Text, der noch niemanden erreicht hat.")
            }
        }
    }

    private var entwurfVorhanden: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func senden() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        Task { await model.send(message: text, for: alarm) }
    }

    /// Eine Nachricht — und ein Weg, sie zu melden.
    ///
    /// **Der Meldeweg gehört AN den Inhalt** (ab 1.1.0/Build 44). Es gab ihn
    /// schon (Einstellungen → Hilfe → „Unangemessene Inhalte melden"), aber
    /// dort findet ihn niemand, der gerade etwas liest, das dort nicht stehen
    /// sollte — dieselbe Lehre wie beim Gruppenchat selbst, den bis 1.0.21
    /// niemand fand. Apples Regel zu von Nutzern eingestelltem Inhalt
    /// (Guideline 1.2) verlangt genau das: einen Weg zu melden, dort wo der
    /// Inhalt steht.
    ///
    /// Gemeldet wird per E-Mail, mit Kürzel, Uhrzeit und Wortlaut im Entwurf —
    /// ohne diese drei ist eine Meldung nicht zu bearbeiten. Abgeschickt wird
    /// sie vom Menschen, nicht von der App: Eine Meldung, die still hinausgeht,
    /// ist keine Meldung, sondern eine Übermittlung.
    ///
    /// Ein langes Drücken ist bewusst NICHT der einzige Weg — es gibt keine
    /// Geste, die jemand unter Druck errät. Deshalb steht das Menü hinter
    /// einem sichtbaren Zeichen am Rand der Karte.
    private func bubble(_ message: Message) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(message.senderName).font(.subheadline).fontWeight(.semibold)
                Text(Clock.time.string(from: message.createdAt))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Menu {
                    Link(destination: Hilfeadressen.meldung(zu: message)) {
                        Label("Diese Nachricht melden", systemImage: "exclamationmark.bubble")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
                .accessibilityLabel("Nachricht melden")
            }
            Text(message.text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(alarm.type.tint)
    }

    /// Ein Pfeil ist kein Knopf, den jemand unter Druck sucht.
    ///
    /// Die erste Fassung hatte ein Feld und daneben ein Papierflieger-Symbol.
    /// Beides zusammen sah aus wie in jeder Messenger-App und war trotzdem
    /// falsch: Wer den Text eingetippt hatte, tippte oben auf „Fertig" und
    /// hielt die Nachricht für gesendet. Zweimal passiert, und im Ernstfall
    /// wäre es dreißigmal passiert.
    ///
    /// Deshalb: ein breiter Knopf mit dem Wort **Senden** darauf, die
    /// Eingabetaste sendet ebenfalls, und solange etwas im Feld steht, sagt
    /// eine Zeile darunter, dass es noch nicht gesendet ist.
    private var composer: some View {
        VStack(spacing: 10) {
            TextField("Nachricht an alle", text: $draft)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit(senden)

            Button(action: senden) {
                Label("Senden", systemImage: "paperplane.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!entwurfVorhanden)

            if entwurfVorhanden {
                Label("Noch nicht gesendet — auf „Senden“ tippen.",
                      systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
