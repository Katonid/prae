//  Meldungen.swift
//  Die drei Bänder — und warum sie mehr als einmal gebraucht werden.
//
//  Bis 1.0.25 hingen sie ausschließlich an `RootView`. Das sah richtig aus und
//  war es nicht: Verwaltung, Einstellungen und Auslösen sind BLÄTTER, und ein
//  Band unter einem Blatt sieht niemand.
//
//  Aufgefallen ist es beim Ernennen eines zweiten Admins (gemeldet 09/2026):
//  „Das Drücken des Textes zeigt keine Funktion." Der Knopf tat sehr wohl
//  etwas — er meldete einen Fehler, und der erschien hinter dem Blatt. Ein
//  Fehler, den niemand sieht, ist schlimmer als gar keiner: Er macht aus einem
//  erklärbaren Problem einen kaputten Knopf.
//
//  Also liegen die Bänder jetzt hier und werden über `.meldungen()` überall
//  dorthin gehängt, wo etwas schiefgehen kann.

import SwiftUI

struct Meldungsbaender: ViewModifier {

    @ObservedObject var model: AppModel

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            VStack(spacing: 8) {
                retryBanner
                hinweisBanner
                problemBanner
            }
        }
    }

    /// Der Alarm ist noch nicht durch und die App versucht es weiter.
    ///
    /// Bewusst nicht als Fehler gezeichnet: Ein Fehler sagt „es ist
    /// gescheitert", das hier sagt „es ist noch nicht fertig". Wer das Erste
    /// liest, geht weg; wer das Zweite liest, wartet die fünf Sekunden.
    @ViewBuilder
    private var retryBanner: some View {
        if let notice = model.retryNotice {
            band(farbe: .blue) {
                HStack(alignment: .top, spacing: 12) {
                    ProgressView()
                    Text(notice)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// Etwas hat geklappt. Verschwindet auf Tipp, nicht von selbst — auch eine
    /// gute Nachricht will gelesen werden.
    @ViewBuilder
    private var hinweisBanner: some View {
        if let hinweis = model.hinweis {
            band(farbe: .green) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(hinweis)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    schliessen { model.hinweis = nil }
                }
            }
        }
    }

    /// Ein Problem bleibt stehen, bis es weggetippt wird.
    ///
    /// Die üblichen vier Sekunden wären hier falsch: Dieses Band trägt Sätze
    /// wie „auf diesem iPad ist keine Apple-ID angemeldet", und genau die muss
    /// jemand noch lesen können, nachdem er aufgesehen hat.
    @ViewBuilder
    private var problemBanner: some View {
        if let problem = model.problem {
            band(farbe: .orange) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(problem)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    schliessen { model.problem = nil }
                }
            }
        }
    }

    private func schliessen(_ tun: @escaping () -> Void) -> some View {
        Button(action: tun) {
            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private func band<Inhalt: View>(farbe: Color,
                                    @ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        inhalt()
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(farbe.opacity(0.4)))
            .padding(.horizontal, 20)
            .padding(.top, 8)
    }
}

extension View {
    /// Hängt Hinweis-, Fehler- und Wiederholungsband über diese Ansicht.
    ///
    /// Gehört an JEDE Ansicht, die als Blatt aufgeht — sonst erscheinen die
    /// Meldungen darunter und damit gar nicht.
    func meldungen(_ model: AppModel) -> some View {
        modifier(Meldungsbaender(model: model))
    }
}
