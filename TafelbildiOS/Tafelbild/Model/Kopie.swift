import Foundation

// MARK: - Kopien bekommen eigene Kennungen

extension WidgetContent {
    /// Frische Kennungen für alles, was im Inhalt eine eigene trägt.
    ///
    /// Eine Kopie bekommt eine neue Element-Kennung — was IN ihr steckt,
    /// behielt bis 1.4.5 die alte. Bei den Klangfeldern fiel das auf: Der
    /// Abspieler führt das Laufende je Feld, und zwei Felder mit derselben
    /// Kennung sind für ihn dasselbe Feld. Ein Tipp auf das eine ließ auch
    /// das andere leuchten und seinen Balken ablaufen (gemeldet 09/2026).
    /// Die Punkte einer Checkliste tragen ebenfalls Kennungen; dort fällt es
    /// heute nicht auf, morgen vielleicht doch.
    ///
    /// Der Abspieler nimmt seit 1.4.5 zusätzlich das Element mit in den
    /// Schlüssel (`SoundPlayer.feld`) — das heilt auch Kopien, die es schon
    /// gibt. Beides gehört zusammen: Hier wird die Ursache abgestellt, dort
    /// hält es auch gegen Kennungen, die längst doppelt auf der Platte
    /// liegen.
    ///
    /// **Wer eine neue Art von Inhalt mit eigenen Kennungen baut, trägt sie
    /// hier ein** — sonst erbt jede Kopie die Identität des Originals.
    func mitNeuenKennungen() -> WidgetContent {
        switch self {
        case .sounds(var inhalt):
            inhalt.buttons = inhalt.buttons.map { feld in
                var neu = feld
                neu.id = UUID().uuidString
                return neu
            }
            return .sounds(inhalt)
        case .checklist(var inhalt):
            inhalt.items = inhalt.items.map { punkt in
                var neu = punkt
                neu.id = UUID().uuidString
                return neu
            }
            return .checklist(inhalt)
        default:
            return self
        }
    }
}
