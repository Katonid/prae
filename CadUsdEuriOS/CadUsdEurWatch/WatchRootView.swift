import SwiftUI

// Farbwelt wie auf dem iPhone, reduziert für die Watch.
private enum WatchTheme {
    static let canada = Color(red: 0xD8 / 255, green: 0x06 / 255, blue: 0x21 / 255)
    static let usaBlue = Color(red: 0x3C / 255, green: 0x3B / 255, blue: 0x6E / 255)
    static let euroBlue = Color(red: 0x00 / 255, green: 0x33 / 255, blue: 0x99 / 255)
    static let euroBright = Color(red: 0.48, green: 0.64, blue: 1.0)
    static let goldBright = Color(red: 1.0, green: 0.86, blue: 0.35)
    static let secondary = Color.white.opacity(0.6)

    static func accent(_ country: WatchModel.Country) -> Color {
        country == .ca ? canada : usaBlue
    }
}

struct WatchRootView: View {
    @EnvironmentObject private var model: WatchModel

    var body: some View {
        TabView {
            ConverterPage()
            TaxPage()
        }
        .tabViewStyle(.verticalPage)
        .task { await model.start() }
    }
}

// MARK: - Seite 1: Umrechner

private struct ConverterPage: View {
    @EnvironmentObject private var model: WatchModel

    private var amountBinding: Binding<Double> {
        Binding(
            get: { model.amount },
            set: { model.setAmount($0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Button {
                    withAnimation(.snappy) { model.toggleCountry() }
                } label: {
                    HStack(spacing: 6) {
                        Text(model.country == .ca ? "🇨🇦" : "🇺🇸")
                        Text(model.code + " → EUR")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(WatchTheme.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background(WatchTheme.accent(model.country).opacity(0.4), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)

                // Betrag: mit der Krone drehen
                VStack(spacing: 0) {
                    Text(model.money(model.amount))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(WatchTheme.goldBright)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: model.amount)
                    Text("\(model.code) netto · Krone drehen")
                        .font(.system(size: 11))
                        .foregroundStyle(WatchTheme.secondary)
                }
                .frame(maxWidth: .infinity)
                .focusable(true)
                .digitalCrownRotation(
                    amountBinding,
                    from: 0, through: 50_000, by: 1,
                    sensitivity: .high,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )

                HStack(spacing: 4) {
                    ForEach([10, 50, 100, 500], id: \.self) { value in
                        Button {
                            withAnimation(.snappy) { model.setAmount(Double(value)) }
                        } label: {
                            Text("\(value)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity, minHeight: 24)
                                .background(Color.white.opacity(0.1), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                resultRow(label: "Euro netto",
                          value: model.money(model.eurNet) + " €",
                          color: WatchTheme.euroBright)
                resultRow(label: "inkl. \(model.percent(model.taxRate)) Steuer",
                          value: model.money(model.eurGross) + " €",
                          color: WatchTheme.euroBright, big: true)

                Text("\(model.money(model.localGross)) \(model.code) inkl. Steuer · \(model.rateDisplay)\(model.rateLoaded ? "" : " (Ersatzkurs)")")
                    .font(.system(size: 10))
                    .foregroundStyle(WatchTheme.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func resultRow(label: String, value: String, color: Color, big: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(WatchTheme.secondary)
                Spacer()
            }
            HStack {
                Text(value)
                    .font(.system(size: big ? 24 : 18, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: value)
                Spacer()
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Seite 2: Steuersatz wählen

private struct TaxPage: View {
    @EnvironmentObject private var model: WatchModel

    var body: some View {
        List {
            Section {
                ForEach(model.options) { option in
                    Button {
                        model.select(option)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(option.label)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                Text(model.percent(option.tax))
                                    .font(.system(size: 12))
                                    .foregroundStyle(WatchTheme.secondary)
                            }
                            Spacer()
                            if model.taxOption == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(WatchTheme.goldBright)
                            }
                        }
                    }
                }
            } header: {
                Text(model.country == .ca ? "Provinz (Kanada)" : "Ort (USA)")
            } footer: {
                Text("Sätze wie in der iPhone-App: Ontario 13 %, Quebec 14,975 %; Buffalo 8,75 %, Niagara Falls 8 %, Detroit 6 %, Cleveland 8 %.")
            }
        }
    }
}
