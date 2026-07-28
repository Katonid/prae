import SwiftUI

enum FocusField: Hashable {
    case amount(AmountField)
    case city
    case taxRate
}

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var focus: FocusField?

    var body: some View {
        ZStack {
            CountryBackground(country: model.country)
            ScrollView {
                VStack(spacing: 14) {
                    switcher
                    header
                    card
                    quickAmounts
                    footer
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .task { await model.start() }
        .animation(.easeInOut(duration: 0.2), value: model.country)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") { focus = nil }
                    .fontWeight(.bold)
            }
        }
        .onChange(of: focus) { oldValue, newValue in
            if case .amount(let field) = oldValue, model.text(for: field).isEmpty {
                model.restoreAmounts()
            }
            if oldValue == .taxRate { model.commitTaxRate() }
            if oldValue == .city, newValue != .city { model.commitCity() }
            if case .amount(let field) = newValue {
                model.beginEditing(field)
            }
        }
    }

    // MARK: Länderwahl

    private var switcher: some View {
        HStack(spacing: 8) {
            switcherButton("Kanada CAD", country: .ca)
            switcherButton("USA USD", country: .us)
        }
        .padding(6)
        .background(Color.white.opacity(0.86), in: Capsule())
        .shadow(color: Theme.ink.opacity(0.12), radius: 11, y: 8)
    }

    private func switcherButton(_ label: String, country: Country) -> some View {
        Button {
            focus = nil
            model.applyMode(country)
        } label: {
            Text(label)
                .font(.system(size: 16, weight: .black))
                .frame(maxWidth: .infinity, minHeight: 42)
                .foregroundStyle(model.country == country ? Color.white : Theme.muted)
                .background(
                    model.country == country ? Theme.localMain(country) : Color.clear,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Kopfbereich

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Group {
                    if model.country == .ca {
                        CanadaFlag()
                    } else {
                        USFlag()
                    }
                }
                .frame(width: 54, height: 36)
                Text(model.mode.title)
                    .font(.system(size: 46, weight: .black))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(model.country == .us ? Color.white : Theme.ink)
                    .shadow(color: model.country == .us ? .black.opacity(0.72) : .clear, radius: 5, y: 2)
                GermanyFlag()
                    .frame(width: 54, height: 36)
            }
            Text(model.mode.subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Rechner-Karte

    private var card: some View {
        VStack(spacing: 12) {
            rateBar
            if model.country == .ca {
                provincePanel
            } else {
                taxPanel
            }
            amountField(.local, style: .local, large: true,
                        label: model.mode.netLabel, code: model.mode.code,
                        unit: "$", hint: model.localHint)
            Text("\(model.mode.code) oben - EUR unten")
                .font(.system(size: 12, weight: .black))
                .textCase(.uppercase)
                .kerning(0.8)
                .foregroundStyle(Theme.muted)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Theme.ink.opacity(0.06), in: Capsule())
            amountField(.eur, style: .eur, large: false,
                        label: "Euro netto", code: "EUR",
                        unit: "€", hint: model.eurHint)
            amountField(.localTax, style: .local, large: false,
                        label: model.localTaxFieldLabel, code: model.mode.code,
                        unit: "$", hint: model.localTaxHint)
            amountField(.eurTax, style: .eur, large: true,
                        label: "Endpreis inkl. Steuer", code: "EUR",
                        unit: "€", hint: model.eurTaxHint)
            controls
        }
        .padding(16)
        .background(Color.white.opacity(0.93))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.92), lineWidth: 1)
        )
        .shadow(color: Theme.ink.opacity(0.14), radius: 22, y: 18)
    }

    private var rateBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tageskurs")
                    .font(.system(size: 12, weight: .bold))
                    .textCase(.uppercase)
                    .kerning(1)
                    .opacity(0.86)
                Text(model.rateDisplay)
                    .font(.system(size: 17, weight: .heavy))
                    .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Steuer")
                    .font(.system(size: 12, weight: .bold))
                    .textCase(.uppercase)
                    .kerning(1)
                    .opacity(0.86)
                Text(model.taxDisplay)
                    .font(.system(size: 17, weight: .heavy))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(Color.white)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Theme.localMain(model.country), location: 0),
                    .init(color: Theme.usaBlue, location: 0.54),
                    .init(color: Theme.euroBlue, location: 1)
                ],
                startPoint: .leading, endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    // MARK: Provinz-Panel (Kanada)

    private var provincePanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                provinceButton("Ontario", tax: 13)
                provinceButton("Quebec", tax: 14.975)
            }
            locationButton("Standort für Provinz nutzen")
        }
        .padding(12)
        .background(Color.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.usaBlue.opacity(0.18), lineWidth: 1)
        )
    }

    private func provinceButton(_ name: String, tax: Double) -> some View {
        Button {
            model.setProvinceTax(label: name, tax: tax)
        } label: {
            Text(name)
                .font(.system(size: 16, weight: .black))
                .frame(maxWidth: .infinity, minHeight: 42)
                .foregroundStyle(Color.white)
                .background(Theme.canada, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Sales-Tax-Panel (USA)

    private var taxPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("Stadt, Staat, z. B. Buffalo, NY", text: cityBinding)
                    .focused($focus, equals: .city)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { model.commitCity() }
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 42)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Theme.line, lineWidth: 1)
                    )
                TextField("Tax %", text: taxRateBinding)
                    .focused($focus, equals: .taxRate)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 16, weight: .heavy))
                    .monospacedDigit()
                    .padding(.horizontal, 12)
                    .frame(width: 92, alignment: .leading)
                    .frame(minHeight: 42)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Theme.line, lineWidth: 1)
                    )
            }
            HStack(spacing: 8) {
                cityButton("Buffalo", city: "Buffalo", tax: 8.75)
                cityButton("Niagara Falls", city: "Niagara Falls (New York)", tax: 8)
            }
            HStack(spacing: 8) {
                cityButton("Detroit", city: "Detroit", tax: 6)
                cityButton("Cleveland", city: "Cleveland", tax: 8)
            }
            locationButton("Standort für Sales Tax nutzen")
        }
        .padding(12)
        .background(Color.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.usaBlue.opacity(0.18), lineWidth: 1)
        )
    }

    private func cityButton(_ label: String, city: String, tax: Double) -> some View {
        Button {
            focus = nil
            model.setCityTax(label: city, tax: tax, source: "voreingestellt")
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .black))
                .minimumScaleFactor(0.8)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 42)
                .foregroundStyle(Color.white)
                .background(Theme.usaBlue, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func locationButton(_ label: String) -> some View {
        Button {
            focus = nil
            model.useLocation()
        } label: {
            Text(label)
                .font(.system(size: 16, weight: .black))
                .frame(maxWidth: .infinity, minHeight: 42)
                .foregroundStyle(Theme.usaBlue)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.usaBlue.opacity(0.22), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Betragsfelder

    private enum FieldStyle {
        case local
        case eur
    }

    private func amountField(_ field: AmountField, style: FieldStyle, large: Bool,
                             label: String, code: String, unit: String, hint: String) -> some View {
        let accent = style == .local ? Theme.localMain(model.country) : Theme.euroBlue
        let dark = style == .local ? Theme.localDark(model.country) : Theme.euroBlue
        let soft = style == .local ? Theme.localSoft(model.country) : Theme.euroSoft
        let borderColor = style == .local ? Theme.usaRed.opacity(0.34) : Theme.euroBlue.opacity(0.34)
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .black))
                    .textCase(.uppercase)
                    .kerning(0.7)
                Spacer()
                Text(code)
                    .font(.system(size: 16, weight: .black))
            }
            .foregroundStyle(dark)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                TextField("0", text: amountBinding(field))
                    .focused($focus, equals: .amount(field))
                    .keyboardType(.decimalPad)
                    .font(.system(size: large ? 44 : 30, weight: .heavy))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(dark)
                Text(unit)
                    .font(.system(size: large ? 19 : 16, weight: .black))
                    .foregroundStyle(Theme.muted)
            }
            Text(hint.isEmpty ? " " : hint)
                .font(.system(size: 14))
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
        }
        .padding(.vertical, large ? 14 : 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color.white, soft], startPoint: .top, endPoint: .bottom)
        )
        .overlay(alignment: .leading) {
            accent.frame(width: 5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .onTapGesture { focus = .amount(field) }
    }

    // MARK: Status + Aktualisieren

    private var controls: some View {
        HStack(spacing: 10) {
            Text(model.status)
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                focus = nil
                Task { await model.refreshRate() }
            } label: {
                Text("Aktualisieren")
                    .font(.system(size: 15, weight: .black))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 42)
                    .foregroundStyle(Color(red: 0x16 / 255, green: 0x16 / 255, blue: 0x16 / 255))
                    .background(Theme.gold, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(model.isRefreshing)
            .opacity(model.isRefreshing ? 0.6 : 1)
        }
    }

    // MARK: Schnellwerte

    private var quickAmounts: some View {
        HStack(spacing: 8) {
            ForEach([100, 500, 1000, 3000], id: \.self) { amount in
                Button {
                    focus = nil
                    model.setQuickAmount(amount)
                } label: {
                    Text("$\(amount)")
                        .font(.system(size: 15, weight: .black))
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .foregroundStyle(Theme.ink)
                        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Theme.line, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        Text("Quelle: frankfurter.dev. US-Steuer: Ortsbestimmung mit NY-County-Tabelle (Pub 718), Bundesstaaten-Basissätzen und Stadt-Voreinstellungen.")
            .font(.system(size: 12))
            .foregroundStyle(Color.white)
            .multilineTextAlignment(.center)
            .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
    }

    // MARK: Bindings

    private func amountBinding(_ field: AmountField) -> Binding<String> {
        Binding(
            get: { model.text(for: field) },
            set: { model.userEdited($0, field: field) }
        )
    }

    private var cityBinding: Binding<String> {
        Binding(
            get: { model.cityText },
            set: { model.userEditedCity($0) }
        )
    }

    private var taxRateBinding: Binding<String> {
        Binding(
            get: { model.taxRateText },
            set: { model.userEditedTaxRate($0) }
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
}
