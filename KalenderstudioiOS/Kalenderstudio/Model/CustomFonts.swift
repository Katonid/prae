import SwiftUI
import UIKit
import CoreText
import UniformTypeIdentifiers

/// Eigene Schriften: auf dem Gerät installierte (über die Schriftauswahl
/// von iOS freigegeben) und in die App geladene Schriftdateien.
///
/// Installierte Schriften (Adobe Fonts, Schrift-Apps, Profile) gibt iOS
/// einer App nur über `UIFontPickerViewController` frei. Bei späteren
/// Starts holt `CTFontManagerRequestFonts` sie erneut — sonst fällt der
/// Text still auf die Systemschrift zurück.
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
    }

    /// Beim Start: geladene Dateien anmelden, installierte Schriften anfordern.
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
        let descriptors = families.map { family in
            CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
        }
        guard !descriptors.isEmpty else { return }
        CTFontManagerRequestFonts(descriptors as CFArray) { _ in
            Task { @MainActor in
                FontFaces.reset()
                FontStore.shared.objectWillChange.send()
            }
        }
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

/// Apples Schriftauswahl — zeigt auch die vom Nutzer installierten Schriften.
/// `onFinish` bekommt den Familiennamen oder `nil` bei Abbruch.
struct SystemFontPicker: UIViewControllerRepresentable {
    let onFinish: (String?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIFontPickerViewController {
        let config = UIFontPickerViewController.Configuration()
        config.includeFaces = false
        config.displayUsingSystemFont = false
        let picker = UIFontPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIFontPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIFontPickerViewControllerDelegate {
        let onFinish: (String?) -> Void
        init(onFinish: @escaping (String?) -> Void) { self.onFinish = onFinish }

        func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
            guard let descriptor = viewController.selectedFontDescriptor else {
                onFinish(nil)
                return
            }
            let family = (descriptor.object(forKey: .family) as? String)
                ?? UIFont(descriptor: descriptor, size: 17).familyName
            onFinish(family)
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
