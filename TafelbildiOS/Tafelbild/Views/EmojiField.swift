import SwiftUI
import UIKit

// Eingabefeld für ein einzelnes Symbol: Beim Antippen öffnet sich direkt die
// Emoji-Tastatur von iOS, also die volle Auswahl — nicht nur eine Handvoll
// vorgegebener Symbole.

/// Textfeld, das iOS die Emoji-Tastatur als Eingabeart vorschlägt.
final class EmojiUITextField: UITextField {
    /// Leerer Bezeichner: iOS wertet die Eingabeart dadurch neu aus, statt die
    /// zuletzt benutzte Tastatur zu behalten.
    override var textInputContextIdentifier: String? { "" }

    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" }
            ?? super.textInputMode
    }
}

/// SwiftUI-Hülle um `EmojiUITextField`. Es bleibt immer nur ein Zeichen stehen.
struct EmojiField: UIViewRepresentable {
    @Binding var emoji: String
    var placeholder: String = "🙂"
    var fontSize: CGFloat = 30

    func makeUIView(context: Context) -> EmojiUITextField {
        let field = EmojiUITextField()
        field.delegate = context.coordinator
        field.text = emoji
        field.placeholder = placeholder
        field.font = .systemFont(ofSize: fontSize)
        field.textAlignment = .center
        field.tintColor = UIColor(Theme.accent)
        field.autocorrectionType = .no
        field.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        field.addTarget(context.coordinator,
                        action: #selector(Coordinator.changed(_:)),
                        for: .editingChanged)
        return field
    }

    func updateUIView(_ field: EmojiUITextField, context: Context) {
        if field.text != emoji { field.text = emoji }
        field.font = .systemFont(ofSize: fontSize)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        private let parent: EmojiField

        init(_ parent: EmojiField) {
            self.parent = parent
        }

        /// Nur das zuletzt eingegebene Zeichen behalten — ein Symbol genügt.
        @objc func changed(_ field: UITextField) {
            let text = field.text ?? ""
            let letzte = text.isEmpty ? "" : String(text.suffix(1))
            if field.text != letzte { field.text = letzte }
            parent.emoji = letzte
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

/// Zeile mit Symbolfeld und Schnellauswahl — überall dort verwendet, wo ein
/// Element ein Symbol tragen kann.
struct EmojiPickerRow: View {
    @Binding var emoji: String
    var title: String = "Symbol"
    var suggestions: [String] = ["🌟", "🍎", "📚", "✏️", "🎨", "🧩", "🔬", "🌍",
                                 "🎵", "⚽️", "🐝", "🚀", "🧮", "🖍️", "🗺️", "🎭"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(title)
                Spacer()
                EmojiField(emoji: $emoji)
                    .frame(width: 60, height: 44)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { item in
                        Button {
                            emoji = item
                            Haptics.tap()
                        } label: {
                            Text(item)
                                .font(.system(size: 24))
                                .frame(width: 40, height: 40)
                                .background {
                                    Circle().fill(item == emoji
                                                  ? Theme.accent.opacity(0.3)
                                                  : Color.primary.opacity(0.06))
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
