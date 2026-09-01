//  ManagedAppConfiguration.swift
//  What Jamf School puts into the app before anybody opens it.
//
//  A managed device can carry a configuration dictionary for each app, under
//  the `com.apple.configuration.managed` key in `UserDefaults`. Nothing has to
//  be installed for this to work — iOS writes it, the app reads it.
//
//  Why it matters here: without it, joining means typing a six-character code
//  on 30 iPads, and the one iPad where somebody mistyped it is the one that
//  stays silent. With it, the app already knows its group at first launch and
//  only asks for the handle.
//
//  The schema is documented as a ready-made plist in `docs/MDM_APPCONFIG.md`.

import Foundation

struct ManagedAppConfiguration: Equatable {

    static let defaultsKey = "com.apple.configuration.managed"

    var schoolName: String?
    var groupInviteCode: String?
    var displayNameHint: String?

    var isEmpty: Bool {
        schoolName == nil && groupInviteCode == nil && displayNameHint == nil
    }

    static func current(defaults: UserDefaults = .standard) -> ManagedAppConfiguration {
        guard let raw = defaults.dictionary(forKey: defaultsKey) else {
            return ManagedAppConfiguration()
        }
        return ManagedAppConfiguration(
            schoolName: string(raw["schoolName"]),
            // Normalized, not merely trimmed: an administrator pasting a code
            // out of a mail brings whitespace and lower case with it, and a
            // configuration that is nearly right is worse than none.
            groupInviteCode: string(raw["groupInviteCode"]).map(InviteCode.normalize),
            displayNameHint: string(raw["displayNameHint"]))
    }

    private static func string(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
