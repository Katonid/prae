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
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for url in files {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        let descriptors = families.map { family in
            CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
        }
        guard !descriptors.isEmpty else { return }
        CTFontManagerRequestFonts(descriptors as CFArray) { _ in
            Task { @MainActor in FontStore.shared.objectWillChange.send() }
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
    }

    func remove(_ family: String) {
        families.removeAll { $0 == family }
        save()
    }

    /// Übernimmt eine Schriftdatei (.ttf, .otf, .ttc) aus „Dateien“.
    func importFile(_ source: URL) {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let target = folder.appendingPathComponent(source.lastPathComponent)
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
