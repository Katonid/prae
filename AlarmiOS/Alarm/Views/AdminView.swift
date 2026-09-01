//  AdminView.swift
//  Everything only the leadership does.
//
//  Kept as one entry point with sub-pages rather than scattered through the
//  app: an administrator opens this twice a year, and a menu item they have to
//  hunt for is a menu item they will ask about by e-mail.

import SwiftUI

struct AdminView: View {

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var cleanupResult: String?

    var body: some View {
        NavigationStack {
            List {
                staff
                group
                afterwards
            }
            .navigationTitle("Verwaltung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    // The three sections are separate properties, not one long `List`.
    //
    // Not a matter of taste: as one expression the type checker gave up on it
    // ("unable to type-check this expression in reasonable time"). Every
    // `NavigationLink` with a trailing `label:` closure multiplies the number
    // of overloads it has to consider, and a dozen of them in one builder is
    // past the budget. Splitting gives each piece its own, small problem.

    private var staff: some View {
        Section("Kollegium") {
            NavigationLink {
                InviteCodesView().environmentObject(model)
            } label: {
                Label("Beitrittscodes", systemImage: "qrcode")
            }
            NavigationLink {
                MembersView().environmentObject(model)
            } label: {
                Label("Mitglieder", systemImage: "person.2")
            }
            NavigationLink {
                DeviceListView().environmentObject(model)
            } label: {
                Label("Geräteübersicht", systemImage: "ipad.and.iphone")
            }
        }
    }

    private var group: some View {
        Section("Gruppe") {
            NavigationLink {
                LocationsView().environmentObject(model)
            } label: {
                Label("Standorte", systemImage: "mappin.and.ellipse")
            }
            NavigationLink {
                InstructionsView().environmentObject(model)
            } label: {
                Label("Handlungstexte", systemImage: "text.book.closed")
            }
        }
    }

    private var afterwards: some View {
        Section {
            NavigationLink {
                AlarmHistoryView().environmentObject(model)
            } label: {
                Label("Alarm-Historie", systemImage: "clock.arrow.circlepath")
            }
            Button {
                Task { await model.beendeAlleLaufenden() }
            } label: {
                Label("Alle laufenden Alarme beenden", systemImage: "bell.slash")
            }
            Button(action: cleanUp) {
                Label("Aufräumen (älter als 90 Tage)", systemImage: "trash")
            }
            if let cleanupResult {
                Text(cleanupResult).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Nachbereitung")
        } footer: {
            Text("„Alle laufenden Alarme beenden“ gibt Entwarnung für alles, "
                 + "was gerade offen ist — der Ausweg, wenn sich etwas "
                 + "aufgestaut hat.\n\n"
                 + "Aufräumen läuft zusätzlich bei jedem Start einer "
                 + "Leitungs-App von selbst. Alarme, Rückmeldungen und Nachrichten sind "
                 + "Leistungs- und Verhaltensdaten benannter Personen — sie "
                 + "bleiben nicht länger liegen als nötig.")
        }
    }

    private func cleanUp() {
        Task {
            do {
                let report = try await model.backend.cleanUp(olderThanDays: 90)
                cleanupResult = report.summary
            } catch {
                model.report(error)
            }
        }
    }
}

// MARK: - Invite codes

struct InviteCodesView: View {

    @EnvironmentObject private var model: AppModel
    @State private var codes: [InviteCode] = []
    @State private var note = ""
    @State private var showing: InviteCode?

    var body: some View {
        List {
            Section {
                TextField("Notiz, z. B. „Kollegium 2026“", text: $note)
                Button("Neuen Code erzeugen") {
                    Task {
                        do {
                            let code = try await model.backend.createInviteCode(
                                note: note.isEmpty ? nil : note)
                            note = ""
                            showing = code
                            await load()
                        } catch {
                            model.report(error)
                        }
                    }
                }
            }

            Section("Vorhanden") {
                if codes.isEmpty {
                    Text("Noch kein Code.").foregroundStyle(.secondary)
                }
                ForEach(codes) { code in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(code.id)
                                .font(.system(.title3, design: .monospaced))
                                .strikethrough(code.revoked)
                            Spacer()
                            if code.revoked {
                                Text("zurückgezogen").font(.caption).foregroundStyle(.secondary)
                            } else {
                                Button("Anzeigen") { showing = code }
                                Button("Zurückziehen", role: .destructive) {
                                    Task {
                                        do {
                                            try await model.backend.revokeInviteCode(code.id)
                                            await load()
                                        } catch {
                                            model.report(error)
                                        }
                                    }
                                }
                            }
                        }
                        if let note = code.note {
                            Text(note).font(.footnote).foregroundStyle(.secondary)
                        }
                        Text("Angelegt \(Clock.dayAndTime.string(from: code.createdAt))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Beitrittscodes")
        .buttonStyle(.borderless)
        .task { await load() }
        .sheet(item: $showing) { code in
            NavigationStack {
                VStack(spacing: 24) {
                    QRCodeView(text: code.id, size: 280)
                    Text(code.id)
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                    Text("Auf den Beamer damit. Wer den Code abtippt, tippt genau "
                         + "diese sechs Zeichen — I, O, 0 und 1 kommen darin nicht vor.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 40)
                    Spacer()
                }
                .padding(.top, 40)
                .navigationTitle("Beitrittscode")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { showing = nil }
                    }
                }
            }
        }
    }

    private func load() async {
        do { codes = try await model.backend.fetchInviteCodes() }
        catch { model.report(error) }
    }
}

// MARK: - Members

struct MembersView: View {

    @EnvironmentObject private var model: AppModel
    @State private var members: [Member] = []

    var body: some View {
        List {
            Section {
                ForEach(members) { member in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.displayName).font(.headline)
                            Text(member.role.label)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            Button(member.role == .admin ? "Rechte entziehen"
                                                         : "Zur Leitung machen") {
                                setzeRolle(member,
                                           auf: member.role == .admin ? .member : .admin)
                            }
                            if member.userId != model.member?.userId {
                                Button("Testalarm senden") {
                                    Task { await model.sendTestAlarm(to: member) }
                                }
                                .disabled(model.isWorking)
                            }
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }
                }
            .onDelete { indexSet in
                let doomed = indexSet.map { members[$0] }
                Task {
                    for member in doomed {
                        do { try await model.backend.removeMember(memberId: member.id) }
                        catch { model.report(error) }
                    }
                    await load()
                }
            }
            } footer: {
                Text("Ein Mitglied ist eine APPLE-ID, kein iPad. Wer beitritt, "
                     + "wird Mitglied; Leitung wird man nur, indem eine Leitung "
                     + "einen dazu ernennt — es dürfen beliebig viele sein.\n\n"
                     + "Zwei iPads mit derselben Apple-ID sind EIN Mitglied mit "
                     + "EINER Rolle. Die Geräteübersicht zeigt sie einzeln; die "
                     + "Rückmeldung im Ernstfall kann sie nicht "
                     + "auseinanderhalten. Jede Lehrkraft braucht deshalb eine "
                     + "eigene Apple-ID.\n\n"
                     + "„Testalarm senden“ schickt einen Probealarm an genau dieses "
                     + "eine iPad — das Kollegium merkt nichts davon. Auf dem "
                     + "Zielgerät setzt sich damit der Haken „Zustellung geprüft“.\n\n"
                     + "An das eigene Gerät geht kein Test: CloudKit stellt einem "
                     + "Gerät keine Meldung zu einem Datensatz zu, den es selbst "
                     + "geschrieben hat. Die Zustellung beweist ein zweites iPad "
                     + "oder gar nichts.\n\n"
                     + "Mindestens zwei Personen sollten die Leitung haben. Sonst "
                     + "kann niemand mehr Codes vergeben, Standorte pflegen oder "
                     + "Entwarnung geben, sobald dieses eine iPad zurückgesetzt "
                     + "wird.")
            }
        }
        .navigationTitle("Mitglieder")
        .task { await load() }
        .overlay {
            if members.isEmpty {
                Text("Noch niemand beigetreten.").foregroundStyle(.secondary)
            }
        }
    }

    private func setzeRolle(_ member: Member, auf rolle: MemberRole) {
        Task {
            do {
                try await model.backend.setRole(memberId: member.id, role: rolle)
                await load()
            } catch {
                model.report(error)
            }
        }
    }

    private func load() async {
        do { members = try await model.backend.fetchMembers() }
        catch { model.report(error) }
    }
}

// MARK: - Locations

struct LocationsView: View {

    @EnvironmentObject private var model: AppModel
    @State private var places: [String] = []
    @State private var newPlace = ""

    var body: some View {
        List {
            Section {
                ForEach(places, id: \.self) { Text($0) }
                    .onDelete { places.remove(atOffsets: $0); save() }
                    .onMove { places.move(fromOffsets: $0, toOffset: $1); save() }
                HStack {
                    TextField("Neuer Ort", text: $newPlace)
                    Button("Hinzufügen") {
                        let trimmed = newPlace.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, !places.contains(trimmed) else { return }
                        places.append(trimmed)
                        newPlace = ""
                        save()
                    }
                    .buttonStyle(.borderless)
                }
            } footer: {
                Text("Die Reihenfolge ist die Reihenfolge auf dem Auslöse-Bildschirm. "
                     + "Was oben steht, wird am schnellsten getroffen.")
            }
        }
        .navigationTitle("Standorte")
        .toolbar { EditButton() }
        .task { places = model.group?.locations ?? DefaultInstructions.locations }
    }

    private func save() {
        let snapshot = places
        Task {
            do { try await model.backend.updateLocations(snapshot) }
            catch { model.report(error) }
        }
    }
}

// MARK: - Instructions

struct InstructionsView: View {

    @EnvironmentObject private var model: AppModel
    @State private var texts: [String: String] = [:]

    var body: some View {
        Form {
            Section {
                Text("Diese Texte stehen im Ernstfall groß auf dem Alarm-Bildschirm. "
                     + "Die Voreinstellung ist bewusst ein sichtbarer Platzhalter — "
                     + "was hier steht, gehört mit Schulleitung, Polizei und "
                     + "Feuerwehr abgestimmt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(AlarmType.allCases, id: \.self) { type in
                Section(type.title) {
                    TextEditor(text: binding(for: type))
                        .frame(minHeight: 120)
                        .font(.body)
                }
            }
        }
        .navigationTitle("Handlungstexte")
        .task {
            texts = model.group?.instructions ?? DefaultInstructions.byType
        }
        .onDisappear { save() }
    }

    private func binding(for type: AlarmType) -> Binding<String> {
        Binding(get: { texts[type.rawValue] ?? "" },
                set: { texts[type.rawValue] = $0 })
    }

    private func save() {
        let snapshot = texts
        Task {
            do { try await model.backend.updateInstructions(snapshot) }
            catch { model.report(error) }
        }
    }
}
