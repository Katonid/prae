import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// TEXTE SPRACHLICH ÜBERARBEITEN.
//
// Zwei Wege, und beide enden gleich: Der Vorschlag steht NEBEN dem alten
// Text und wird erst mit „Übernehmen" eingesetzt; die alte Fassung bleibt
// als `vorfassung` im Eintrag und lässt sich zurückholen.
//
// 1. **Auf dem Gerät** (Apple Intelligence, `FoundationModels`, ab iOS 26
//    auf geeigneten Geräten). Der Text verlässt das Gerät nicht. Das Modell
//    hat ein kleines Kontextfenster (rund 4000 Token für Anweisung, Text UND
//    Antwort) — lange Texte gehen deshalb absatzweise in Stücken hinein,
//    jedes in einer frischen Sitzung.
// 2. **Über einen KI-Chat** (ChatGPT, Claude …): Die App kopiert Anweisung
//    und Text, die Antwort kommt über die Zwischenablage zurück. Geht auf
//    jedem Gerät.
//
// Daneben bietet iOS ab 18.1 die Schreibwerkzeuge im Textfeld selbst an
// (Text markieren → „Schreibtools"). Die braucht die App nicht zu bauen.
enum Sprachhilfe {
    enum Art: String, CaseIterable, Identifiable {
        case korrigieren, glaetten, lebendiger, kuerzen
        var id: String { rawValue }

        var name: String {
            switch self {
            case .korrigieren: return "Nur korrigieren"
            case .glaetten: return "Sprachlich glätten"
            case .lebendiger: return "Lebendiger erzählen"
            case .kuerzen: return "Kürzen"
            }
        }

        var beschreibung: String {
            switch self {
            case .korrigieren: return "Rechtschreibung, Grammatik und Zeichensetzung — sonst bleibt jedes Wort."
            case .glaetten: return "Flüssiger, Wiederholungen vermeiden, holprige Sätze ordnen. Inhalt und Ton bleiben."
            case .lebendiger: return "Anschaulicher und erzählender, ohne etwas hinzuzuerfinden."
            case .kuerzen: return "Auf das Wesentliche, etwa zwei Drittel der Länge."
            }
        }

        var auftrag: String {
            switch self {
            case .korrigieren:
                return "Korrigiere ausschließlich Rechtschreibung, Grammatik und Zeichensetzung. Ändere keine Wortwahl und keinen Satzbau, wenn er nicht falsch ist."
            case .glaetten:
                return "Überarbeite den Text sprachlich: flüssiger, ohne Wortwiederholungen, mit klaren Sätzen. Inhalt, Reihenfolge und persönlicher Ton bleiben erhalten."
            case .lebendiger:
                return "Erzähle den Text lebendiger und anschaulicher, mit treffenden Verben und Bildern. Erfinde keine Ereignisse, Personen, Orte oder Gefühle hinzu, die nicht im Text stehen."
            case .kuerzen:
                return "Kürze den Text auf etwa zwei Drittel seiner Länge. Behalte alle wichtigen Ereignisse, Namen und Orte."
            }
        }
    }

    enum Fehler: LocalizedError {
        case nichtVerfuegbar
        var errorDescription: String? { "Die Überarbeitung auf dem Gerät ist hier nicht verfügbar." }
    }

    static let grundsatz = """
    Du bist ein behutsamer Lektor für persönliche Tagebuch- und Erinnerungstexte auf Deutsch. \
    Schreibe in derselben Sprache, Perspektive und Zeitform wie das Original. \
    Erfinde nichts hinzu und lass nichts Inhaltliches weg. \
    Gib ausschließlich den überarbeiteten Text zurück — ohne Vorbemerkung, ohne Erklärung, ohne Anführungszeichen.
    """

    /// Der Auftrag für einen KI-Chat: Anweisung und Text in einem Stück.
    static func auftrag(_ text: String, art: Art) -> String {
        grundsatz + "\n\n" + art.auftrag + "\n\nHier ist der Text:\n\n" + text
    }

    // MARK: - Auf dem Gerät

    /// Gibt es das Sprachmodell auf diesem Gerät, und ist es bereit?
    static var aufDemGeraet: Bool { grundOhneGeraet == nil }

    /// `nil`, wenn es geht — sonst ein Satz, warum nicht.
    static var grundOhneGeraet: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(let grund):
                switch grund {
                case .appleIntelligenceNotEnabled:
                    return "Apple Intelligence ist ausgeschaltet (Einstellungen → Apple Intelligence & Siri). Bis dahin geht es über einen KI-Chat."
                case .deviceNotEligible:
                    return "Dieses Gerät unterstützt Apple Intelligence nicht. Die Überarbeitung geht über einen KI-Chat."
                case .modelNotReady:
                    return "Apple Intelligence lädt das Sprachmodell noch. Später erneut versuchen — oder über einen KI-Chat."
                @unknown default:
                    return "Apple Intelligence steht gerade nicht zur Verfügung. Die Überarbeitung geht über einen KI-Chat."
                }
            @unknown default:
                return "Apple Intelligence steht gerade nicht zur Verfügung. Die Überarbeitung geht über einen KI-Chat."
            }
        }
        return "Die Überarbeitung auf dem Gerät braucht iOS 26 und Apple Intelligence. Sie geht hier über einen KI-Chat."
        #else
        return "Die Überarbeitung auf dem Gerät braucht iOS 26 und Apple Intelligence. Sie geht hier über einen KI-Chat."
        #endif
    }

    static func ueberarbeiten(_ text: String, art: Art) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            var ergebnis: [String] = []
            for stueck in stuecke(text) {
                let sitzung = LanguageModelSession(instructions: grundsatz + "\n\n" + art.auftrag)
                let antwort = try await sitzung.respond(to: "Text:\n\n" + stueck)
                ergebnis.append(bereinigen(antwort.content))
            }
            return ergebnis.joined(separator: "\n\n")
        }
        #endif
        throw Fehler.nichtVerfuegbar
    }

    /// Absätze zu Stücken von höchstens etwa 1800 Zeichen.
    static func stuecke(_ text: String) -> [String] {
        let absaetze = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var liste: [String] = []
        var aktuell = ""
        for a in absaetze {
            if !aktuell.isEmpty, aktuell.count + a.count > 1800 {
                liste.append(aktuell)
                aktuell = ""
            }
            aktuell += (aktuell.isEmpty ? "" : "\n\n") + a
        }
        if !aktuell.isEmpty { liste.append(aktuell) }
        return liste.isEmpty ? [text] : liste
    }

    /// Nimmt weg, was ein Modell gern um die Antwort legt: Codezäune,
    /// umschließende Anführungszeichen, Leerzeilen am Rand.
    static func bereinigen(_ roh: String) -> String {
        var s = roh.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            var zeilen = s.components(separatedBy: "\n")
            zeilen.removeFirst()
            if zeilen.last?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true { zeilen.removeLast() }
            s = zeilen.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let paare: [(Character, Character)] = [("\"", "\""), ("\u{201E}", "\u{201C}"), ("»", "«")]
        for (auf, zu) in paare where s.count > 2 && s.first == auf && s.last == zu {
            s = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s
    }
}
