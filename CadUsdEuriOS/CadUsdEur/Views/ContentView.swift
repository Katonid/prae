import SwiftUI

enum FocusField: Hashable {
    case amount(AmountField)
    case city
    case taxRate
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var focus: FocusField?
    @Namespace private var switcherNamespace
    @State private var showScanner = false
    @State private var contentHeight: CGFloat = 0
    @State private var availableHeight: CGFloat = 0

    /// Inhalt so verkleinern, dass alles ohne Scrollen auf den Bildschirm passt.
    private var fitScale: CGFloat {
        guard contentHeight > 0, availableHeight > 0, contentHeight > availableHeight else { return 1 }
        return max(0.75, availableHeight / contentHeight)
    }

    var body: some View {
        ZStack {
            CountryBackground(country: model.country)
            GeometryReader { proxy in
                ScrollView {
                    content
                        .background(
                            GeometryReader { inner in
                                Color.clear.preference(key: ContentHeightKey.self, value: inner.size.height)
                            }
                        )
                        .scaleEffect(fitScale, anchor: .top)
                        .frame(height: contentHeight > 0 ? contentHeight * fitScale : nil, alignment: .top)
                        .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                .onAppear { availableHeight = max(availableHeight, proxy.size.height) }
                .onChange(of: proxy.size.height) { _, newValue in
                    availableHeight = max(availableHeight, newValue)
                }
            }
            .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
        }
        .overlay(alignment: .bottom) { cameraButton }
        .sheet(isPresented: $showScanner) {
            PriceScannerView()
                .environmentObject(model)
        }
        .task { await model.start() }
        .animation(.easeInOut(duration: 0.3), value: model.country)
        .sensoryFeedback(.selection, trigger: model.country)
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

    private var content: some View {
        VStack(spacing: 10) {
            switcher
            header
            card
            quickAmounts
            footer
        }
        .frame(maxWidth: 500)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 66)
    }

    // MARK: Kamera-Knopf (Preis scannen)

    private var cameraButton: some View {
        Button {
            focus = nil
            showScanner = true
        } label: {
            Image(systemName: "camera.fill")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 58, height: 58)
                .background(Theme.goldGradient, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                .shadow(color: Theme.gold.opacity(0.45), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)
        .accessibilityLabel("Preis mit der Kamera scannen")
    }

    // MARK: Länderwahl (gleitender Schalter)

    private var switcher: some View {
        HStack(spacing: 6) {
            switcherButton("Kanada CAD", country: .ca)
            switcherButton("USA USD", country: .us)
        }
        .padding(5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Theme.glassStroke, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.35), radius: 14, y: 8)
    }

    private func switcherButton(_ label: String, country: Country) -> some View {
        Button {
            focus = nil
            withAnimation(.snappy(duration: 0.3)) {
                model.applyMode(country)
            }
        } label: {
            Text(label)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 38)
                .foregroundStyle(model.country == country ? Color.white : Theme.textSecondary)
                .background {
                    if model.country == country {
                        Capsule()
                            .fill(Theme.accentGradient(country))
                            .shadow(color: Theme.localMain(country).opacity(0.5), radius: 10, y: 4)
                            .matchedGeometryEffect(id: "activeSegment", in: switcherNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: Kopfbereich

    private var header: some View {
        HStack(spacing: 10) {
            Group {
                if model.country == .ca {
                    CanadaFlag()
                } else {
                    USFlag()
                }
            }
            .frame(width: 46, height: 30)
            Text(model.mode.title)
                .font(.system(size: 36, weight: .black, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .foregroundStyle(Theme.textPrimary)
                .shadow(color: Color.black.opacity(0.4), radius: 6, y: 2)
            GermanyFlag()
                .frame(width: 46, height: 30)
        }
    }

    // MARK: Rechner-Karte (Glas)

    private var card: some View {
        VStack(spacing: 9) {
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
                .font(.system(size: 10, weight: .black, design: .rounded))
                .textCase(.uppercase)
                .kerning(0.8)
                .foregroundStyle(Theme.textFaint)
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(Theme.glassFill, in: Capsule())
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
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Theme.glassStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 26, y: 16)
    }

    private var rateBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tageskurs")
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                    .kerning(1)
                    .opacity(0.85)
                Text(model.rateDisplay)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Steuer")
                    .font(.system(size: 11, weight: .bold))
                    .textCase(.uppercase)
                    .kerning(1)
                    .opacity(0.85)
                Text(model.taxDisplay)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .foregroundStyle(Color.white)
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
        .background(
            Theme.rateBarGradient(model.country),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Theme.euroBlue.opacity(0.45), radius: 14, y: 6)
        .animation(.snappy, value: model.rateDisplay)
        .animation(.snappy, value: model.taxDisplay)
    }

    // MARK: Provinz-Panel (Kanada)

    private var provincePanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                provinceButton("Ontario", tax: 13)
                provinceButton("Quebec", tax: 14.975)
            }
            locationButton("Standort für Provinz nutzen")
        }
        .padding(9)
        .background(Theme.glassFill)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.glassStroke, lineWidth: 1)
        )
    }

    private func provinceButton(_ name: String, tax: Double) -> some View {
        let active = model.province == name
        return Button {
            model.setProvinceTax(label: name, tax: tax)
        } label: {
            Text(name)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 38)
                .foregroundStyle(active ? Color.white : Theme.textSecondary)
                .background {
                    if active {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Theme.accentGradient(.ca))
                            .shadow(color: Theme.canada.opacity(0.5), radius: 8, y: 3)
                    } else {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(Theme.glassFill)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(active ? Color.white.opacity(0.25) : Theme.glassStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Sales-Tax-Panel (USA)

    private var taxPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Stadt, Staat, z. B. Buffalo, NY", text: cityBinding)
                    .focused($focus, equals: .city)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { model.commitCity() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 38)
                    .background(Theme.fieldFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Theme.glassStroke, lineWidth: 1)
                    )
                TextField("Tax %", text: taxRateBinding)
                    .focused($focus, equals: .taxRate)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(width: 92, alignment: .leading)
                    .frame(minHeight: 38)
                    .background(Theme.fieldFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Theme.glassStroke, lineWidth: 1)
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
        .padding(9)
        .background(Theme.glassFill)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.glassStroke, lineWidth: 1)
        )
    }

    private func cityButton(_ label: String, city: String, tax: Double) -> some View {
        Button {
            focus = nil
            model.setCityTax(label: city, tax: tax, source: "voreingestellt")
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .minimumScaleFactor(0.8)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 36)
                .foregroundStyle(Color.white)
                .background(
                    Theme.accentGradient(.us),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Theme.usaBlue.opacity(0.45), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func locationButton(_ label: String) -> some View {
        Button {
            focus = nil
            model.useLocation()
        } label: {
            Label(label, systemImage: "location.fill")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 38)
                .foregroundStyle(Theme.textPrimary)
                .background(Theme.glassFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Theme.glassStroke, lineWidth: 1)
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
        let bright = style == .local ? Theme.localBright(model.country) : Theme.euroBright
        let gradient = style == .local ? Theme.accentGradient(model.country) : Theme.euroGradient
        let glow = style == .local ? Theme.localMain(model.country) : Theme.euroBlue
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .textCase(.uppercase)
                    .kerning(0.6)
                Spacer()
                Text(code)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .padding(.vertical, 2)
                    .padding(.horizontal, 8)
                    .background(bright.opacity(0.16), in: Capsule())
            }
            .foregroundStyle(bright)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                TextField("0", text: amountBinding(field))
                    .focused($focus, equals: .amount(field))
                    .keyboardType(.decimalPad)
                    .font(.system(size: large ? 34 : 26, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(Theme.textPrimary)
                Text(unit)
                    .font(.system(size: large ? 17 : 15, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(hint.isEmpty ? " " : hint)
                .font(.system(size: 12, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
                .contentTransition(.numericText())
                .animation(.snappy, value: hint)
        }
        .padding(.vertical, large ? 9 : 7)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.fieldFill)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(gradient)
                .frame(width: 4)
                .shadow(color: glow.opacity(0.8), radius: 5, x: 2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(focus == .amount(field) ? bright.opacity(0.7) : Theme.glassStroke, lineWidth: 1)
        )
        .onTapGesture { focus = .amount(field) }
    }

    // MARK: Status + Aktualisieren

    private var controls: some View {
        HStack(spacing: 10) {
            Text(model.status)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .contentTransition(.numericText())
                .animation(.snappy, value: model.status)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                focus = nil
                Task { await model.refreshRate() }
            } label: {
                HStack(spacing: 6) {
                    if model.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Theme.ink)
                    }
                    Text("Aktualisieren")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                .foregroundStyle(Theme.ink)
                .background(Theme.goldGradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .shadow(color: Theme.gold.opacity(0.35), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(model.isRefreshing)
            .opacity(model.isRefreshing ? 0.75 : 1)
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
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .foregroundStyle(Theme.textPrimary)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.glassStroke, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var footer: some View {
        Text("Quelle: frankfurter.dev. US-Steuer: Ortsbestimmung mit NY-County-Tabelle (Pub 718), Bundesstaaten-Basissätzen und Stadt-Voreinstellungen.")
            .font(.system(size: 10))
            .foregroundStyle(Theme.textFaint)
            .multilineTextAlignment(.center)
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
        .preferredColorScheme(.dark)
}
