//  AlarmBackend.swift
//  The seam.
//
//  Everything the app can ask of a server sits in this one protocol. The rule
//  that makes it worth anything: no type from any backend SDK appears in a
//  signature here, and no view or view model ever talks to a backend directly
//  — they hold an `any AlarmBackend`.
//
//  When Android joins and CloudKit has to go (it delivers to Apple devices
//  only), a second implementation of this protocol plus a push sender that
//  follows `docs/PUSH_CONTRACT.md` is the whole job. The screens do not change.

import Foundation

/// Whether the backend can be used at all right now.
///
/// Split out from `throws` because "no iCloud account on this iPad" is not an
/// error in the usual sense — it is a state the onboarding checklist has to
/// show and explain, not a failure to retry.
enum BackendAvailability: Equatable {
    case ready
    /// No account signed in. With CloudKit this means: nothing will be
    /// delivered to this device, at all.
    case noAccount
    /// Signed in, but the account is restricted (managed device policy).
    case restricted
    case networkUnavailable
    case unknown(String)

    var isReady: Bool { self == .ready }

    var explanation: String {
        switch self {
        case .ready:
            return "Verbunden."
        case .noAccount:
            return """
            Auf diesem iPad ist keine Apple-ID angemeldet. Ohne sie kommt \
            kein Alarm an — auch kein Probealarm. Einstellungen → oben auf \
            den Namen tippen → anmelden.
            """
        case .restricted:
            return """
            Die Apple-ID auf diesem iPad darf iCloud nicht nutzen. Das ist \
            eine Einstellung der Geräteverwaltung; bitte an die \
            Jamf-Administration wenden.
            """
        case .networkUnavailable:
            return "Keine Netzverbindung. Alarme lassen sich derzeit nicht auslösen."
        case .unknown(let detail):
            return "Unerwarteter Zustand: \(detail)"
        }
    }
}

/// Errors the app has to be able to explain to a teacher standing in a
/// corridor. Nothing here may end up on screen as a raw code.
enum BackendError: LocalizedError, Equatable {
    case notJoined
    case notPermitted
    case codeUnknown
    case codeRevoked
    case alarmAlreadyRunning(AlarmType)
    case accountUnavailable(BackendAvailability)
    case network(String)
    case server(String)
    case notImplemented(String)

    var errorDescription: String? {
        switch self {
        case .notJoined:
            return "Dieses Gerät gehört noch zu keiner Gruppe."
        case .notPermitted:
            return "Dafür fehlt die Berechtigung. Nur ein Admin darf das."
        case .codeUnknown:
            return "Diesen Beitrittscode gibt es nicht."
        case .codeRevoked:
            return "Dieser Beitrittscode wurde zurückgezogen."
        case .alarmAlreadyRunning(let type):
            return "Es läuft bereits ein \(NSLocalizedString(type.titleKey, comment: "")). "
                 + "Ein zweiter desselben Art wird nicht ausgelöst."
        case .accountUnavailable(let availability):
            return availability.explanation
        case .network(let detail):
            return "Keine Verbindung: \(detail)"
        case .server(let detail):
            return "Der Dienst hat abgelehnt: \(detail)"
        case .notImplemented(let what):
            return "\(what) ist in dieser Fassung nicht eingebaut."
        }
    }
}

/// Everything the app asks of a server.
///
/// Two kinds of methods, deliberately kept apart:
///
/// * `async throws` calls — a question with an answer, or a change with a
///   receipt. They fail loudly.
/// * `observe…` streams — a value now and every value after it. They never
///   fail; a broken stream simply stops producing, and the caller keeps the
///   last value it had. During an alarm that is the right trade: the last
///   known list of acknowledgements is worth more than an error banner.
protocol AlarmBackend: AnyObject {

    // MARK: Account and device

    /// The backend's own identifier for the signed-in account, or `nil` when
    /// there is none. With CloudKit this survives reinstalling the app, which
    /// is what makes a member recognisable across a device wipe.
    func currentUserId() async -> String?

    func availability() async -> BackendAvailability

    /// Writes (or refreshes) this device's `DeviceStatus`.
    func registerDevice(_ draft: DeviceStatusDraft) async throws

    // MARK: Membership

    /// Creates a brand-new group and makes the caller its administrator.
    ///
    /// Somebody has to go first. Without this the app cannot be entered at
    /// all: `joinGroup` needs an invite code, an invite code needs a group,
    /// and a group needs a creator. The person who sets the school up is the
    /// one who then hands out codes, edits the action texts and calls the
    /// all-clear — so creating and being admin are the same act.
    func createGroup(name: String, displayName: String) async throws -> Membership

    func joinGroup(code: String, displayName: String) async throws -> Membership

    /// The group this device belongs to, or `nil` when it belongs to none.
    func fetchGroup() async throws -> AlarmGroup?

    func fetchMembers() async throws -> [Member]

    /// The member record of this device's account, if it has one.
    func currentMember() async throws -> Member?

    // MARK: The alarm path

    func triggerAlarm(type: AlarmType, location: String?) async throws -> Alarm

    func clearAlarm(alarmId: String) async throws

    func sendAck(alarmId: String, state: AckState, location: String?) async throws

    /// The currently running alarm, or `nil`. Emits on every change.
    func observeActiveAlarm() -> AsyncStream<Alarm?>

    func observeAcks(alarmId: String) -> AsyncStream<[Ack]>

    func sendMessage(alarmId: String, text: String) async throws

    func observeMessages(alarmId: String) -> AsyncStream<[Message]>

    // MARK: Checking that it works

    /// Schickt einen Testalarm an GENAU EIN anderes Gerät.
    ///
    /// Nicht an das eigene, und das ist keine Bequemlichkeit: CloudKit stellt
    /// eine Subscription-Meldung dem Gerät, das den Datensatz geschrieben hat,
    /// nicht zu. Ein Selbsttest auf einem einzelnen Gerät kann deshalb nicht
    /// funktionieren — er sah nur so aus, als könnte er. Die Zustellung
    /// beweist ein zweites iPad oder gar nichts.
    ///
    /// Nur ein Admin darf ihn senden; er ist ein Probealarm und trägt alle
    /// Kennzeichen eines solchen.
    func sendTestAlarm(toUserId userId: String) async throws

    /// Asks every device in the group to refresh its `DeviceStatus`.
    func pingAllDevices() async throws

    func fetchDeviceStatuses() async throws -> [DeviceStatus]

    /// Everything the backend knows about why a push might not arrive.
    ///
    /// Never throws: a diagnosis that fails to run is the least useful thing
    /// imaginable. Each check reports its own outcome as a line.
    func diagnose() async -> [Diagnose]

    /// Creates the push subscriptions if they are missing. Called at every
    /// start — a subscription can disappear (account switched, container
    /// reset), and a device without one is silently deaf.
    func refreshSubscriptions() async throws

    // MARK: Administration

    func createInviteCode(note: String?) async throws -> InviteCode
    func revokeInviteCode(_ code: String) async throws
    func fetchInviteCodes() async throws -> [InviteCode]

    func updateLocations(_ locations: [String]) async throws
    func updateInstructions(_ instructions: [String: String]) async throws

    func removeMember(memberId: String) async throws

    /// Promotes a colleague to the leadership, or takes it back.
    ///
    /// Needed because one administrator is a single point of failure: if that
    /// one iPad is wiped over the summer, nobody can hand out a code, edit a
    /// location or call an all-clear ever again. A deputy head with the same
    /// rights costs nothing and removes the trap.
    func setRole(memberId: String, role: MemberRole) async throws

    func fetchAlarmHistory(limit: Int) async throws -> [Alarm]
    func fetchAcks(alarmId: String) async throws -> [Ack]
    func fetchMessages(alarmId: String) async throws -> [Message]

    /// Deletes alarms, acknowledgements and messages older than `days`.
    @discardableResult
    func cleanUp(olderThanDays days: Int) async throws -> CleanupReport

    // MARK: Push

    /// Hands a parsed push to the backend so it can refresh whatever the event
    /// touched. The app does the presenting; the backend does the fetching.
    func handle(event: AlarmEvent) async
}
