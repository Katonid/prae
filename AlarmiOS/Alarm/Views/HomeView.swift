//  HomeView.swift
//  The screen the app sits on all day.
//
//  One job above all others: the alarm button has to be findable without
//  looking. Everything else — settings, administration, the checklist warning
//  — is arranged around it and never in front of it.

import SwiftUI

struct HomeView: View {

    @EnvironmentObject private var model: AppModel
    // Welches Blatt offen ist, weiß das Modell und nicht diese Ansicht: Im
    // Alarmfall muss es jemand anderes zumachen können. Ein offenes Blatt und
    // der Alarm-Bildschirm sind beide modal, und iOS zeigt davon nur eines.

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let cleared = model.allClearNotice { allClear(cleared) }
                    if !model.blockingItems.isEmpty { warning }
                    triggerButton
                    if let alarm = model.activeAlarm, alarm.isActive { runningAlarm(alarm) }
                    statusCard
                }
                .padding(24)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(model.group?.name ?? "Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if model.isAdmin {
                        Button {
                            model.offenesBlatt = .verwaltung
                        } label: {
                            Label("Verwaltung", systemImage: "person.2.badge.gearshape")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        model.offenesBlatt = .einstellungen
                    } label: {
                        Label("Einstellungen", systemImage: "gearshape")
                    }
                }
            }
            .sheet(item: $model.offenesBlatt) { blatt in
                switch blatt {
                case .ausloesen: TriggerFlowView().environmentObject(model)
                case .einstellungen: SettingsView().environmentObject(model)
                case .verwaltung: AdminView().environmentObject(model)
                }
            }
        }
    }

    /// The button is deliberately enormous and deliberately not red.
    ///
    /// Red would make the home screen look like an emergency at all times, and
    /// a warning colour that is always on is a warning colour nobody sees. The
    /// red appears one tap later, on the alarm type itself.
    private var triggerButton: some View {
        Button {
            model.offenesBlatt = .ausloesen
        } label: {
            VStack(spacing: 14) {
                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .font(.system(size: 76, weight: .semibold))
                Text("Alarm auslösen")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Art wählen, Ort wählen, 5 Sekunden Bedenkzeit")
                    .font(.subheadline)
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 44)
            .background(Color(red: 0.62, green: 0.08, blue: 0.10),
                        in: RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Alarm auslösen")
    }

    /// Was auf der Karte steht, wenn der Alarm-Bildschirm zur Seite liegt.
    ///
    /// Die ungelesenen Nachrichten gehören hierher und nur hierher: Auf dem
    /// Alarm-Bildschirm stehen sie offen da, hier ist es die einzige Spur.
    private func laufzeile(_ alarm: Alarm) -> String {
        var teile = ["Seit \(Clock.time.string(from: alarm.createdAt))",
                     "\(model.acks.count) Rückmeldungen"]
        if model.ungeleseneNachrichten == 1 { teile.append("1 neue Nachricht") }
        if model.ungeleseneNachrichten > 1 {
            teile.append("\(model.ungeleseneNachrichten) neue Nachrichten")
        }
        return teile.joined(separator: " · ")
    }

    private func runningAlarm(_ alarm: Alarm) -> some View {
        Button {
            model.zeigeAlarmBildschirm(fuer: alarm.id)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: alarm.type.symbol).font(.title)
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(alarm.type.title) läuft").font(.headline)
                    Text(laufzeile(alarm))
                        .font(.subheadline).opacity(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.white)
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(alarm.type.tint, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }

    /// "Entwarnung durch KL um 09:21" — and it stays until it is dismissed.
    ///
    /// Whoever was in a locked classroom needs to read this after looking up,
    /// not four seconds after it appeared.
    private func allClear(_ alarm: Alarm) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "bell.slash.fill")
                .font(.title)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text("Entwarnung").font(.headline)
                Text(entwarnungstext(alarm))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                model.allClearNotice = nil
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .card(.blue)
    }

    private func entwarnungstext(_ alarm: Alarm) -> String {
        let zeit = Clock.time.string(from: alarm.clearedAt ?? Date())
        guard let name = alarm.clearedByName else {
            return "\(alarm.type.title) beendet um \(zeit)."
        }
        return "\(alarm.type.title) beendet durch \(name) um \(zeit)."
    }

    private var warning: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Dieses iPad ist nicht einsatzbereit", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            ForEach(model.blockingItems) { item in
                Text("• " + item.title).font(.subheadline)
            }
            Button("Prüfliste öffnen") { model.offenesBlatt = .einstellungen }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
        }
        .card(.orange)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            row("Kürzel", model.displayName.isEmpty ? "—" : model.displayName)
            row("Rolle", model.isAdmin ? MemberRole.admin.label : MemberRole.member.label)
            row("Verbindung", model.availability.isReady ? "bereit" : "Problem")
            if let group = model.group {
                row("Gruppe", group.name)
            }
        }
        .card()
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView().environmentObject(PreviewModels.joined())
    }
}
