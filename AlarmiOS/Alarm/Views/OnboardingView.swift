//  OnboardingView.swift
//  The checklist, and the self-test that ends it.
//
//  The rule this screen exists to enforce: onboarding is not finished when
//  every line is green. It is finished when a test alarm has actually arrived
//  on this device and somebody confirmed hearing it. Green ticks describe
//  settings; a delivered notification describes reality, and only the second
//  one is what the school is relying on.

import SwiftUI

struct OnboardingView: View {

    @EnvironmentObject private var model: AppModel
    @State private var testRequestedAt: Date?

    var body: some View {
        NavigationStack {
            List {
                if let code = model.freshInviteCode { codeSection(code) }

                Section {
                    Text("Dieses iPad muss laut werden können, auch wenn es "
                         + "gesperrt ist und ein Fokus läuft. Die folgenden Punkte "
                         + "sind dafür nötig.")
                        .font(.callout)
                }

                Section("Von der App prüfbar") {
                    ForEach(model.checklist) { item in
                        checklistRow(item)
                    }
                }

                Section {
                    Button {
                        Task { await model.requestPermissions() }
                    } label: {
                        Label("Berechtigungen anfragen", systemImage: "bell.badge")
                    }
                }

                Section {
                    ForEach(OnboardingChecklist.manualHints, id: \.title) { hint in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(hint.title, systemImage: "hand.point.right")
                                .font(.headline)
                            Text(hint.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Von Hand, einmal je Gerät")
                } footer: {
                    Text("Diese drei Punkte kann keine App nachsehen — iOS gibt sie "
                         + "nicht heraus. Sie stehen hier als Anleitung und nicht als "
                         + "Häkchen, weil ein Häkchen ohne Prüfung eine Behauptung wäre.")
                }

                tontestSection
                selfTestSection

                Section {
                    Button {
                        model.finishOnboarding()
                    } label: {
                        Text("Einrichtung abschließen").fontWeight(.semibold)
                    }
                    .disabled(!model.blockingItems.isEmpty)
                } footer: {
                    if !model.blockingItems.isEmpty {
                        Text("Noch offen: "
                             + model.blockingItems.map(\.title).joined(separator: ", "))
                    }
                }
            }
            .navigationTitle("Einrichtung")
            .refreshable { await model.refresh() }
            .task { await model.rebuildChecklist() }
        }
    }

    /// Der Code, mit dem das Kollegium hereinkommt — genau einmal, hier, wo
    /// die einrichtende Person ohnehin steht.
    ///
    /// Ein Code, der nur unter „Verwaltung → Beitrittscodes" liegt, ist ein
    /// Code, nach dem gefragt wird. Wiederzufinden ist er dort trotzdem.
    private func codeSection(_ code: InviteCode) -> some View {
        Section {
            VStack(spacing: 14) {
                Text(code.id)
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                QRCodeView(text: code.id, size: 180)
                Text("Damit tritt das Kollegium bei: Code abtippen oder scannen. "
                     + "Wiederzufinden unter Verwaltung → Beitrittscodes.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Verstanden") { model.freshInviteCode = nil }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } header: {
            Text("Die Schule ist eingerichtet")
        }
    }

    private func checklistRow(_ item: ChecklistItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.state.symbol)
                .foregroundStyle(item.state == .ok ? .green : .orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.headline)
                Text(item.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if item.isBlocking, let url = item.settingsURL {
                Link("Öffnen", destination: url).font(.footnote)
            }
        }
        .padding(.vertical, 4)
    }

    /// Zuerst der Ton, dann die Zustellung. Die Reihenfolge ist die
    /// Fehlersuche: Wer den Ton nicht hört, braucht über die Zustellung noch
    /// gar nicht nachzudenken.
    @ViewBuilder
    private var tontestSection: some View {
        Section {
            Button {
                Task { await model.runTontest() }
            } label: {
                Label("Tontest starten", systemImage: "speaker.wave.3")
            }
            Text("Sperre das iPad jetzt und lege es hin. In \(Int(Tontest.vorlauf)) "
                 + "Sekunden weckt es sich selbst — mit dem Alarmton, in der "
                 + "Dringlichkeitsstufe des Ernstfalls.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Ich habe den Ton gehört") { model.confirmTontest() }
                .fontWeight(.semibold)
        } header: {
            Text("1. Tontest — ohne Netz")
        } footer: {
            Text("Dieser Test läuft ganz auf dem Gerät. Er beweist, dass das iPad "
                 + "laut werden DARF — nicht, dass ein Alarm von einer Kollegin "
                 + "ankommt. Dafür ist der nächste da.")
        }
    }

    @ViewBuilder
    private var selfTestSection: some View {
        Section {
            Button {
                testRequestedAt = Date()
                Task { await model.runSelfTest() }
            } label: {
                Label("Testalarm an dieses Gerät senden", systemImage: "bell.badge.waveform")
            }
            .disabled(model.isWorking)

            if let testRequestedAt {
                Text("Gesendet um \(Clock.timeWithSeconds.string(from: testRequestedAt)). "
                     + "Er sollte binnen weniger Sekunden hörbar ankommen — notfalls "
                     + "das iPad kurz sperren und warten.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Der Testalarm ist angekommen") {
                    model.confirmSelfTest()
                }
                .fontWeight(.semibold)
            }
            NavigationLink {
                DiagnoseView().environmentObject(model)
            } label: {
                Label("Zustellung prüfen", systemImage: "stethoscope")
            }
        } header: {
            Text("2. Selbsttest — über iCloud")
        } footer: {
            Text("Nur dieses Gerät bekommt den Testalarm; das Kollegium merkt "
                 + "nichts davon. Kommt nach zehn Sekunden nichts, tippe auf "
                 + "„Zustellung prüfen“ — dort steht, an welcher Stelle die Kette "
                 + "reißt.")
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView().environmentObject(PreviewModels.joined())
    }
}
