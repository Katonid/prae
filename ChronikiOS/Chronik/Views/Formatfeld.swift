import SwiftUI
import UIKit

// EINZELNE WÖRTER FORMATIEREN — IM TEXTFELD (KAPITELWEISE, ab 1.0.20).
//
// Ansage des Nutzers 11/2026: „Ich möchte in allen Bereichen die Möglichkeit
// haben, einzelne Wörter oder Abschnitte anders zu formatieren. Also
// Schriftgröße, Schriftart, fett oder unterstrichen eigenständig festlegen
// können."
//
// Über der Tastatur steht eine Leiste: Fett, Kursiv, Unterstrichen, kleiner,
// größer, Schrift, „Normal". Sie wirkt auf die Auswahl (oder, ohne Auswahl,
// auf das, was als Nächstes getippt wird). Dazu bleibt das Bearbeiten-Menü
// von iOS mit seinem „Format" an (`allowsEditingTextAttributes`).
//
// Gespeichert wird TEXT mit Marken (`Auszeichnung`): Nach jeder Änderung wird
// das Feld in Marken zurückgeschrieben und — nach einer Formatänderung — aus
// ihnen neu gesetzt. Damit sieht das Feld genau so aus, wie die Seite den
// gespeicherten Text setzt; einen zweiten Weg gibt es nicht.
final class Formatwerkzeug: NSObject, UIFontPickerViewControllerDelegate {
    weak var feld: UITextView?
    var bild: Schriftbild
    var schriften: [Schriftfamilie]
    /// Der gespeicherte Wortlaut, den das Feld gerade zeigt.
    var letzter: String = ""
    var geaendert: (String) -> Void
    private var bereichFuerWaehler: NSRange?
    /// LESBAR ZEIGEN (ab 1.0.25, gemeldet 11/2026 mit Bildschirmfoto: „Der
    /// Text ist leider nicht lesbar." — Nachtblau in 11 pt auf dunklem
    /// Grund). In Formularen zeigt das Feld die Schrift des Buches in der
    /// Farbe des Bildschirms und mindestens 16 pt; gespeichert wird
    /// unverändert (`massstab` rechnet Größenmarken hin und zurück). Auf der
    /// Seite (`TextflaecheBruecke`) bleibt es bei Druckgröße und -farbe —
    /// dort liegt das Feld über der Seite und soll aussehen wie sie.
    var lesbar: Bool

    init(bild: Schriftbild, schriften: [Schriftfamilie], lesbar: Bool = false,
         geaendert: @escaping (String) -> Void) {
        self.bild = bild
        self.schriften = schriften
        self.lesbar = lesbar
        self.geaendert = geaendert
    }

    private var massstab: Double { lesbar ? max(1, 16 / max(bild.groesse, 1)) : 1 }

    /// Die Schrift, in der das Feld zeigt.
    private var anzeige: Schriftbild {
        var b = bild
        b.groesse = bild.groesse * massstab
        return b
    }

    private func anzeigen(_ text: String) -> NSAttributedString {
        let gesetzt = NSMutableAttributedString(attributedString:
            Auszeichnung.gesetzt(text, bild: anzeige, massstab: massstab))
        if lesbar {
            gesetzt.addAttribute(.foregroundColor, value: UIColor.label,
                                 range: NSRange(location: 0, length: gesetzt.length))
        }
        return gesetzt
    }

    private var tippwerte: [NSAttributedString.Key: Any] {
        var werte = anzeige.attribute()
        if lesbar { werte[.foregroundColor] = UIColor.label }
        return werte
    }

    // MARK: Anzeigen

    func zeigen(_ text: String, in feld: UITextView) {
        let auswahl = feld.selectedRange
        feld.attributedText = anzeigen(text)
        feld.typingAttributes = tippwerte
        letzter = text
        let laenge = (feld.text as NSString).length
        feld.selectedRange = NSRange(location: min(auswahl.location, laenge),
                                     length: min(auswahl.length, max(0, laenge - min(auswahl.location, laenge))))
    }

    /// Nach dem Tippen: zurück in Marken.
    func uebernehmen(_ feld: UITextView) {
        let text = Auszeichnung.auszeichnen(feld.attributedText, bild: anzeige, massstab: massstab)
        letzter = text
        geaendert(text)
    }

    // MARK: Die Leiste

    func leiste() -> UIView {
        let leiste = UIToolbar(frame: CGRect(x: 0, y: 0, width: 400, height: 44))
        func knopf(_ symbol: String, _ wirkung: Selector) -> UIBarButtonItem {
            UIBarButtonItem(image: UIImage(systemName: symbol), style: .plain, target: self, action: wirkung)
        }
        let schrift = UIBarButtonItem(image: UIImage(systemName: "textformat"), menu: schriftmenue())
        let fertig = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(schliessen))
        leiste.items = [
            knopf("bold", #selector(fett)),
            knopf("italic", #selector(kursiv)),
            knopf("underline", #selector(unterstrichen)),
            .fixedSpace(12),
            knopf("textformat.size.smaller", #selector(kleiner)),
            knopf("textformat.size.larger", #selector(groesser)),
            .fixedSpace(12),
            schrift,
            UIBarButtonItem(title: "Normal", style: .plain, target: self, action: #selector(normal)),
            .flexibleSpace(),
            fertig,
        ]
        return leiste
    }

    private func schriftmenue() -> UIMenu {
        var gesehen = Set<String>()
        var eintraege: [UIMenuElement] = []
        for familie in [bild.familie] + schriften where gesehen.insert(familie.id).inserted {
            eintraege.append(UIAction(title: familie.name) { [weak self] _ in self?.familieSetzen(familie) })
        }
        eintraege.append(UIAction(title: "Weitere Schriften\u{2026}", image: UIImage(systemName: "ellipsis.circle")) {
            [weak self] _ in self?.waehlerOeffnen()
        })
        return UIMenu(title: "Schrift für die Auswahl", children: eintraege)
    }

    @objc private func schliessen() { feld?.resignFirstResponder() }

    @objc private func fett() { merkmalUmschalten(.traitBold) }
    @objc private func kursiv() { merkmalUmschalten(.traitItalic) }

    @objc private func unterstrichen() {
        aendern { text, bereich in
            var alle = true
            text.enumerateAttribute(.underlineStyle, in: bereich) { wert, _, _ in
                if (wert as? Int ?? 0) == 0 { alle = false }
            }
            if alle {
                text.removeAttribute(.underlineStyle, range: bereich)
            } else {
                text.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: bereich)
            }
        } tippen: { werte in
            let an = (werte[.underlineStyle] as? Int ?? 0) != 0
            werte[.underlineStyle] = an ? nil : NSUnderlineStyle.single.rawValue
        }
    }

    @objc private func kleiner() { groesseAendern(-1) }
    @objc private func groesser() { groesseAendern(+1) }

    @objc private func normal() {
        let grund = anzeige.uiFont
        aendern { text, bereich in
            text.addAttribute(.font, value: grund, range: bereich)
            text.removeAttribute(.underlineStyle, range: bereich)
        } tippen: { werte in
            werte[.font] = grund
            werte[.underlineStyle] = nil
        }
    }

    private func merkmalUmschalten(_ merkmal: UIFontDescriptor.SymbolicTraits) {
        aendern { text, bereich in
            var alle = true
            text.enumerateAttribute(.font, in: bereich) { wert, _, _ in
                if let f = wert as? UIFont, !f.fontDescriptor.symbolicTraits.contains(merkmal) { alle = false }
            }
            text.enumerateAttribute(.font, in: bereich) { wert, teil, _ in
                guard let f = wert as? UIFont else { return }
                text.addAttribute(.font, value: Self.mit(f, merkmal, an: !alle), range: teil)
            }
        } tippen: { werte in
            guard let f = werte[.font] as? UIFont else { return }
            werte[.font] = Self.mit(f, merkmal, an: !f.fontDescriptor.symbolicTraits.contains(merkmal))
        }
    }

    private static func mit(_ f: UIFont, _ merkmal: UIFontDescriptor.SymbolicTraits, an: Bool) -> UIFont {
        var merkmale = f.fontDescriptor.symbolicTraits
        if an { merkmale.insert(merkmal) } else { merkmale.remove(merkmal) }
        guard let neu = f.fontDescriptor.withSymbolicTraits(merkmale) else { return f }
        return UIFont(descriptor: neu, size: f.pointSize)
    }

    private func groesseAendern(_ schritt: CGFloat) {
        aendern { text, bereich in
            text.enumerateAttribute(.font, in: bereich) { wert, teil, _ in
                guard let f = wert as? UIFont else { return }
                text.addAttribute(.font, value: f.withSize(min(max(f.pointSize + schritt, 5), 96)), range: teil)
            }
        } tippen: { werte in
            guard let f = werte[.font] as? UIFont else { return }
            werte[.font] = f.withSize(min(max(f.pointSize + schritt, 5), 96))
        }
    }

    private func familieSetzen(_ familie: Schriftfamilie, bereich fest: NSRange? = nil) {
        aendern(bereich: fest) { text, bereich in
            text.enumerateAttribute(.font, in: bereich) { wert, teil, _ in
                let f = wert as? UIFont ?? self.anzeige.uiFont
                let m = f.fontDescriptor.symbolicTraits
                text.addAttribute(.font, value: familie.uiFont(groesse: Double(f.pointSize),
                                                               fett: m.contains(.traitBold),
                                                               kursiv: m.contains(.traitItalic)), range: teil)
            }
        } tippen: { werte in
            let f = werte[.font] as? UIFont ?? self.anzeige.uiFont
            let m = f.fontDescriptor.symbolicTraits
            werte[.font] = familie.uiFont(groesse: Double(f.pointSize), fett: m.contains(.traitBold),
                                          kursiv: m.contains(.traitItalic))
        }
    }

    /// Wendet eine Änderung auf die Auswahl an — oder, ohne Auswahl, auf
    /// das, was als Nächstes getippt wird. Danach: in Marken und zurück.
    private func aendern(bereich fest: NSRange? = nil,
                         _ arbeit: (NSMutableAttributedString, NSRange) -> Void,
                         tippen: (inout [NSAttributedString.Key: Any]) -> Void) {
        guard let feld else { return }
        let bereich = fest ?? feld.selectedRange
        if bereich.length == 0 {
            var werte = feld.typingAttributes
            tippen(&werte)
            feld.typingAttributes = werte
            return
        }
        let text = NSMutableAttributedString(attributedString: feld.attributedText)
        guard NSMaxRange(bereich) <= text.length else { return }
        arbeit(text, bereich)
        let marken = Auszeichnung.auszeichnen(text, bild: anzeige, massstab: massstab)
        zeigen(marken, in: feld)
        feld.selectedRange = bereich
        geaendert(marken)
    }

    // MARK: Schriften des Geräts (auch selbst installierte)

    private func waehlerOeffnen() {
        guard let feld else { return }
        bereichFuerWaehler = feld.selectedRange
        let aufbau = UIFontPickerViewController.Configuration()
        aufbau.includeFaces = false
        aufbau.displayUsingSystemFont = false
        let waehler = UIFontPickerViewController(configuration: aufbau)
        waehler.delegate = self
        var oben = feld.window?.rootViewController
        while let weiter = oben?.presentedViewController { oben = weiter }
        oben?.present(waehler, animated: true)
    }

    // Hier ist der Wähler von UIKit dargestellt (nicht von SwiftUI) — also
    // schließt er sich auch selbst, genau einmal (die Lehre aus 1.0.19).
    func fontPickerViewControllerDidPickFont(_ waehler: UIFontPickerViewController) {
        waehler.dismiss(animated: true)
        guard let deskriptor = waehler.selectedFontDescriptor else { return }
        let name = Geraeteschriften.familienname(deskriptor)
            ?? UIFont(descriptor: deskriptor, size: 12).familyName
        Geraeteschriften.merken(name)
        let familie = Schriftfamilie(familienname: name)
        let bereich = bereichFuerWaehler
        Geraeteschriften.anmelden(deskriptor) { [weak self] _ in
            self?.familieSetzen(familie, bereich: bereich)
        }
        feld?.becomeFirstResponder()
    }

    func fontPickerViewControllerDidCancel(_ waehler: UIFontPickerViewController) {
        waehler.dismiss(animated: true)
        feld?.becomeFirstResponder()
    }
}

/// Ein Textfeld für Formulare (Eintrag, Vorwort) — mit der Formatleiste.
struct Formatfeld: UIViewRepresentable {
    @Binding var text: String
    var bild: Schriftbild
    var schriften: [Schriftfamilie] = []

    func makeUIView(context: Context) -> UITextView {
        let feld = UITextView()
        feld.delegate = context.coordinator
        feld.backgroundColor = .clear
        feld.isScrollEnabled = true
        feld.allowsEditingTextAttributes = true
        feld.textContainerInset = UIEdgeInsets(top: 6, left: 2, bottom: 6, right: 2)
        context.coordinator.werkzeug.feld = feld
        feld.inputAccessoryView = context.coordinator.werkzeug.leiste()
        context.coordinator.werkzeug.zeigen(text, in: feld)
        return feld
    }

    func updateUIView(_ feld: UITextView, context: Context) {
        let werkzeug = context.coordinator.werkzeug
        werkzeug.geaendert = { neu in text = neu }
        if werkzeug.bild != bild {
            werkzeug.bild = bild
            werkzeug.zeigen(text, in: feld)
        } else if text != werkzeug.letzter {
            // Von außen geändert (Diktat, Zwischenablage, Vorschlag übernommen).
            werkzeug.zeigen(text, in: feld)
        }
    }

    func makeCoordinator() -> Bote {
        Bote(werkzeug: Formatwerkzeug(bild: bild, schriften: schriften, lesbar: true, geaendert: { _ in }))
    }

    final class Bote: NSObject, UITextViewDelegate {
        let werkzeug: Formatwerkzeug
        init(werkzeug: Formatwerkzeug) { self.werkzeug = werkzeug }
        func textViewDidChange(_ feld: UITextView) { werkzeug.uebernehmen(feld) }
    }
}

extension Reise {
    /// Die Schriften, die dieses Buch schon benutzt — für das Schriftmenü der
    /// Formatleiste.
    var buchschriften: [Schriftfamilie] {
        var liste = [typografie.titel.familie, typografie.flieText.familie,
                     typografie.datum.familie, typografie.bildunterschrift.familie]
        if let u = typografie.unterueberschrift { liste.append(u.familie) }
        return liste.map(\.ohneSchnitt)
    }
}
