import SwiftUI
import UIKit
import CoreText
import UniformTypeIdentifiers

/// Eigene Schriften: auf dem Gerät installierte (über die Schriftauswahl
/// von iOS freigegeben) und in die App geladene Schriftdateien.
///
/// Installierte Schriften (Adobe Fonts, Schrift-Apps, Profile) holt die App
/// seit 1.0.7 wie das Reisebuch: beim Start über die Systemabfrage
/// `CTFontManagerCopyRegisteredFontDescriptors(.persistent, true)` plus die
/// im Wähler gewählten Schnitte, angemeldet mit
/// `CTFontManagerRegisterFontDescriptors(.process)`. Beides braucht das
/// Schriftenrecht (`com.apple.developer.user-fonts`, seit 1.0.6) — ohne es
/// zeigt auch der Wähler von iOS nur die Systemschriften.
@MainActor
final class FontStore: ObservableObject {
    static let shared = FontStore()

    /// Familiennamen, neueste zuerst.
    @Published private(set) var families: [String] = []
    @Published var message: String?

    private let defaultsKey = "eigeneSchriften"
    var localFolder: URL { folder }

    private let folder: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("Schriften", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private init() {
        families = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        faces = UserDefaults.standard.stringArray(forKey: facesKey) ?? []
    }

    /// Familien, die das System als dauerhaft installiert meldet
    /// (`CTFontManagerCopyRegisteredFontDescriptors(.persistent, true)`).
    @Published private(set) var systemFamilies: [String] = []

    /// Beim Start: geladene Dateien anmelden, installierte Schriften holen.
    func activate() {
        // Geladene Dateien: vom Gerät und — mit iCloud — aus dem Behälter.
        // Eine schon angemeldete Schrift meldet einen Fehler („steht
        // schon“); der ist harmlos und wird nicht gedeutet.
        var dirs = [folder]
        if let cloud = CloudStore.shared.fontsDir { dirs.append(cloud) }
        for dir in dirs {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
            for raw in names {
                let url = dir.appendingPathComponent(CloudStore.realName(raw))
                guard CloudStore.shared.state(of: url) == .local else { continue }
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                if let descs = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] {
                    for d in descs {
                        if let fam = CTFontDescriptorCopyAttribute(d, kCTFontFamilyNameAttribute) as? String,
                           !families.contains(fam) {
                            families.append(fam)
                        }
                    }
                }
            }
        }
        save()
        FontFaces.reset()

        // Installierte Schriften — derselbe Weg wie im Reisebuch (1.0.43/
        // 1.0.66): erst fragen, was das System als installiert meldet, dazu
        // die über den Wähler gewählten Schnitte (PostScript-Namen) und
        // Familien, die dieser Prozess noch nicht kennt. Alles für DIESEN
        // Prozess anmelden (`.process`) — und das Ergebnis aus dem
        // Rückrufblock lesen, nicht gleich danach nachsehen.
        let fund = Self.systemFund()
        systemFamilies = fund.families
        let open = (faces + families).filter { UIFont(name: $0, size: 12) == nil && !isAvailable($0) }
        var descriptors = fund.descriptors
        descriptors += open.map { UIFontDescriptor(name: $0, size: 12) }
        let before = UIFont.familyNames.count
        let head = "Start: System meldet \(fund.raw) Einträge, lesbar \(fund.descriptors.count) "
            + "in \(fund.families.count) Familien; \(open.count) gemerkte noch offen; "
            + "Familien im Prozess: \(before)."
        guard !descriptors.isEmpty else {
            log(head + (faces.isEmpty && families.isEmpty
                        ? " Nichts anzumelden."
                        : " Nichts anzumelden — alle gemerkten sind auffindbar."))
            return
        }
        Self.register(descriptors) { result in
            FontFaces.reset()
            let missing = FontStore.shared.families.filter { !FontStore.shared.isAvailable($0) }
            FontStore.shared.log(head + " Angemeldet: \(descriptors.count), \(result). "
                + "Familien danach: \(UIFont.familyNames.count); nicht auffindbar: "
                + (missing.isEmpty ? "keine" : missing.joined(separator: ", ")) + ".")
            FontStore.shared.objectWillChange.send()
        }
    }

    // MARK: - Installierte Schriften (Weg aus dem Reisebuch)

    struct SystemFund {
        var raw: Int
        var descriptors: [UIFontDescriptor]
        var families: [String]
    }

    nonisolated static func systemFund() -> SystemFund {
        let raw = CTFontManagerCopyRegisteredFontDescriptors(.persistent, true) as NSArray
        let descriptors = raw.compactMap { $0 as? UIFontDescriptor }
        var fams: [String] = []
        for d in descriptors {
            // Den Namen aus dem Deskriptor — nicht aus einer daraus gebauten
            // Schrift; die wäre bei einer unbekannten Schrift ein Ersatz.
            if let f = d.fontAttributes[.family] as? String, !fams.contains(f) { fams.append(f) }
        }
        return SystemFund(raw: raw.count, descriptors: descriptors, families: fams.sorted())
    }

    /// Asynchron; das Ergebnis steht im Rückrufblock (Reisebuch 1.0.43).
    nonisolated static func register(_ descriptors: [UIFontDescriptor],
                                     done: @escaping @MainActor (String) -> Void) {
        guard !descriptors.isEmpty else {
            Task { @MainActor in done("nichts anzumelden") }
            return
        }
        var notes: [String] = []
        CTFontManagerRegisterFontDescriptors(descriptors as CFArray, .process, true) { errors, finished in
            for item in errors as NSArray {
                if let e = item as? NSError { notes.append(errorText(e)) }
            }
            if finished {
                let unique = Array(Set(notes)).sorted()
                let text = unique.isEmpty ? "ohne Fehlermeldung" : "Meldungen: " + unique.joined(separator: " / ")
                Task { @MainActor in done(text) }
            }
            return true
        }
    }

    /// Die Zahl sagt, was ein Fehler heißt, nicht sein Satz (Reisebuch
    /// 1.0.66). Unbekannte Zahlen werden nicht gedeutet.
    private nonisolated static let errorNames: [Int: String] = [
        101: "Datei nicht gefunden", 102: "zu wenig Rechte", 103: "Format nicht erkannt",
        104: "Schriftdaten ungültig", 105: "steht schon — bereits angemeldet",
        201: "nicht angemeldet", 202: "in Gebrauch", 203: "wird vom System gebraucht",
    ]

    private nonisolated static func errorText(_ e: NSError) -> String {
        var t = "\(e.domain) \(e.code)"
        if let n = errorNames[e.code] { t += " (\(n))" }
        return t
    }

    /// Eine im Wähler von iOS gewählte Schrift übernehmen: Schnitt und
    /// Familie merken, anmelden, danach melden, ob sie auffindbar ist.
    func adopt(_ descriptor: UIFontDescriptor, done: @escaping (String?) -> Void) {
        let face = descriptor.postscriptName
        let family = (descriptor.fontAttributes[.family] as? String)
            ?? UIFont(descriptor: descriptor, size: 12).familyName
        if !face.isEmpty, !faces.contains(face) {
            faces.append(face)
            UserDefaults.standard.set(faces, forKey: facesKey)
        }
        add(family: family)
        Self.register([descriptor]) { result in
            FontFaces.reset()
            let ok = FontStore.shared.isAvailable(family)
            FontStore.shared.log("Wähler: \(family) (\(face)) — \(result); "
                + (ok ? "auffindbar." : "NICHT auffindbar."))
            FontStore.shared.message = ok ? "„\(family)“ ist bereit."
                : "„\(family)“ ließ sich nicht anmelden — Einzelheiten unter Einstellungen › Schriften."
            FontStore.shared.objectWillChange.send()
            done(family)
        }
    }

    // MARK: - Protokoll

    private let facesKey = "eigeneSchnitte"
    private let logKey = "schriftenProtokoll"
    /// PostScript-Namen der im Wähler gewählten Schnitte.
    private(set) var faces: [String] = []

    var protocolLines: [String] { UserDefaults.standard.stringArray(forKey: logKey) ?? [] }

    func log(_ line: String) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        var lines = protocolLines
        lines.append(time + "  " + line)
        if lines.count > 40 { lines.removeFirst(lines.count - 40) }
        UserDefaults.standard.set(lines, forKey: logKey)
        objectWillChange.send()
    }

    func isAvailable(_ family: String) -> Bool {
        !UIFont.fontNames(forFamilyName: family).isEmpty
    }

    func add(family: String) {
        let name = family.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !FontLibrary.families.contains(name) else { return }
        families.removeAll { $0 == name }
        families.insert(name, at: 0)
        save()
        FontFaces.reset()
    }

    func remove(_ family: String) {
        families.removeAll { $0 == family }
        save()
    }

    /// Übernimmt eine Schriftdatei (.ttf, .otf, .ttc) aus „Dateien“.
    func importFile(_ source: URL) {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        // Mit iCloud in den Behälter — dann hat jedes Gerät die Schrift.
        let target = (CloudStore.shared.fontsDir ?? folder).appendingPathComponent(source.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: target.path) {
                CTFontManagerUnregisterFontsForURL(target as CFURL, .process, nil)
                try FileManager.default.removeItem(at: target)
            }
            try FileManager.default.copyItem(at: source, to: target)
        } catch {
            message = "„\(source.lastPathComponent)“ ließ sich nicht kopieren."
            return
        }
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(target as CFURL) as? [CTFontDescriptor],
              !descriptors.isEmpty else {
            try? FileManager.default.removeItem(at: target)
            message = "„\(source.lastPathComponent)“ ist keine lesbare Schriftdatei."
            return
        }
        CTFontManagerRegisterFontsForURL(target as CFURL, .process, nil)
        let names = Set(descriptors.compactMap {
            CTFontDescriptorCopyAttribute($0, kCTFontFamilyNameAttribute) as? String
        })
        for name in names.sorted() { add(family: name) }
        message = names.isEmpty ? nil : "Geladen: \(names.sorted().joined(separator: ", "))"
    }

    private func save() {
        UserDefaults.standard.set(families, forKey: defaultsKey)
    }
}

/// Apples Schriftauswahl — zeigt auch die vom Nutzer installierten Schriften,
/// sofern der Bau das Schriftenrecht trägt. Sie läuft als eigener Prozess.
/// Wie im Reisebuch mit Schnitten (`includeFaces`); `onFinish` bekommt den
/// gewählten Deskriptor oder `nil` bei Abbruch.
struct SystemFontPicker: UIViewControllerRepresentable {
    let onFinish: (UIFontDescriptor?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIFontPickerViewController {
        let config = UIFontPickerViewController.Configuration()
        config.includeFaces = true
        config.displayUsingSystemFont = false
        let picker = UIFontPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIFontPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIFontPickerViewControllerDelegate {
        let onFinish: (UIFontDescriptor?) -> Void
        init(onFinish: @escaping (UIFontDescriptor?) -> Void) { self.onFinish = onFinish }

        func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
            onFinish(viewController.selectedFontDescriptor)
        }

        func fontPickerViewControllerDidCancel(_ viewController: UIFontPickerViewController) {
            onFinish(nil)
        }
    }
}

extension UTType {
    static let fontFiles: [UTType] = [.font] + ["public.truetype-ttf-font", "public.opentype-font",
                                                "public.truetype-collection-font"].compactMap { UTType($0) }
}

/// Der richtige SCHNITT einer Familie. Ein Font aus dem bloßen Familiennamen
/// liefert oft nur den Normalschnitt (Lehre aus dem Reisebuch 1.0.29:
/// „Futura ist mir etwas zu dick“). Hier wird der Schnitt gesucht, dessen
/// Strichstärke der gewünschten am nächsten kommt — kursive ausgenommen.
enum FontFaces {
    private static var cache: [String: String] = [:]
    private static var none: Set<String> = []
    private static let lock = NSLock()

    static func reset() {
        lock.lock(); cache.removeAll(); none.removeAll(); lock.unlock()
    }

    static func face(family: String, weight: Font.Weight) -> String? {
        let target = numeric(weight)
        let key = "\(family)|\(target)"
        lock.lock()
        if let hit = cache[key] { lock.unlock(); return hit }
        if none.contains(key) { lock.unlock(); return nil }
        lock.unlock()

        var best: (name: String, distance: CGFloat)?
        var firstAny: String?
        for name in UIFont.fontNames(forFamilyName: family) {
            guard let font = UIFont(name: name, size: 12) else { continue }
            if firstAny == nil { firstAny = name }
            let desc = font.fontDescriptor
            if desc.symbolicTraits.contains(.traitItalic) { continue }
            let traits = desc.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any]
            let w = (traits?[.weight] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
            let d = abs(w - target)
            if best == nil || d < best!.distance { best = (name, d) }
        }
        let result = best?.name ?? firstAny
        lock.lock()
        if let result { cache[key] = result } else { none.insert(key) }
        lock.unlock()
        return result
    }

    /// Werte wie `UIFont.Weight`.
    private static func numeric(_ w: Font.Weight) -> CGFloat {
        switch w {
        case .ultraLight: return -0.8
        case .thin: return -0.6
        case .light: return -0.4
        case .medium: return 0.23
        case .semibold: return 0.3
        case .bold: return 0.4
        case .heavy: return 0.56
        case .black: return 0.62
        default: return 0
        }
    }
}

/// Darf eine Schrift ins PDF eingebettet werden? Das steht in ihr selbst —
/// im Feld `fsType` der OS/2-Tabelle (Lehre aus dem Reisebuch). Eine Schrift
/// mit „Restricted License Embedding“ landet nicht im PDF, und die Druckerei
/// ersetzt sie stillschweigend.
enum FontLicense {
    enum Result: Equatable {
        case allowed
        case restricted
        /// Die Schrift gibt ihre Tabelle nicht heraus — dann wird nicht geraten.
        case unknown
        case unavailable
    }

    static func check(family: String) -> Result {
        if ["System", "System Rounded", "New York", "Monospaced"].contains(family) { return .allowed }
        guard let name = UIFont.fontNames(forFamilyName: family).first else { return .unavailable }
        let font = CTFontCreateWithName(name as CFString, 12, nil)
        guard let table = CTFontCopyTable(font, CTFontTableTag(kCTFontTableOS2), []) else { return .unknown }
        let data = table as Data
        guard data.count >= 10 else { return .unknown }
        let fsType = UInt16(data[data.startIndex + 8]) << 8 | UInt16(data[data.startIndex + 9])
        // Bits 0–3: 2 = keine Einbettung erlaubt. Bit 9: nur Bitmaps.
        if fsType & 0x000F == 0x0002 || fsType & 0x0200 != 0 { return .restricted }
        return .allowed
    }
}
