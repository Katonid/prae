import SwiftUI

struct FormatPanel: View {
    @Binding var project: CalendarProject

    private var f: Binding<PageFormat> { $project.format }

    var body: some View {
        Form {
            Section {
                FormatDiagram(format: project.format)
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    legendRow(color: .red.opacity(0.5), text: "Beschnitt — wird abgeschnitten; Hintergründe und randlose Fotos reichen bis hierher.")
                    legendRow(color: .primary, text: "Endformat — die fertige Seite.")
                    legendRow(color: .blue, text: "Sicherheitsabstand — Texte und Kalendarium bleiben innerhalb.")
                }
            }

            Section("Vorlage") {
                Menu {
                    ForEach(PageFormat.presets.indices, id: \.self) { i in
                        let preset = PageFormat.presets[i]
                        Button("\(preset.name) — \(preset.format.summary)") {
                            project.format = preset.format
                        }
                    }
                } label: {
                    Label("Format des Druckdienstes wählen", systemImage: "doc.on.doc")
                }
                Button {
                    let w = project.format.widthMM
                    project.format.widthMM = project.format.heightMM
                    project.format.heightMM = w
                } label: {
                    Label("Hoch- und Querformat tauschen", systemImage: "rotate.right")
                }
            }

            Section {
                MMField(title: "Breite", value: f.widthMM, range: 50...1200)
                MMField(title: "Höhe", value: f.heightMM, range: 50...1200)
            } header: {
                Text("Endformat")
            } footer: {
                Text("Die Maße der fertig geschnittenen Seite, wie der Druckdienst sie angibt.")
            }

            Section {
                MMField(title: "Beschnitt je Seite", value: f.bleedMM, range: 0...20)
                MMField(title: "Sicherheitsabstand", value: f.safetyMM, range: 0...60)
            } header: {
                Text("Beschnitt und Sicherheitsabstand")
            } footer: {
                Text("Üblich sind 2–3 mm Beschnitt und 4–10 mm Sicherheitsabstand. Der Sicherheitsabstand wird vom Endformatrand nach innen gemessen.")
            }

            Section {
                Picker("Bindung", selection: f.bindingEdge) {
                    ForEach(BindingEdge.allCases) { e in Text(e.title).tag(e) }
                }
                .pickerStyle(.segmented)
                if project.format.bindingEdge != .none {
                    MMField(title: "Abstand zur Bindung", value: f.bindingMM, range: 0...80)
                }
            } header: {
                Text("Bindung")
            } footer: {
                Text("Für Spiral- oder Wire-O-Bindung, gemessen vom Rand des Endformats — so, wie Druckdienste es angeben (z. B. „2 cm von oben“). Texte und Kalendarium bleiben darunter, Hintergründe und randlose Fotos laufen weiter bis in den Beschnitt.")
            }

            Section("Druckdatei") {
                LabeledContent("Endformat", value: project.format.summary)
                LabeledContent("Mit Beschnitt",
                               value: "\(project.format.documentWidthMM.mmText) × \(project.format.documentHeightMM.mmText) mm")
                LabeledContent("Bei 300 dpi", value: pixelText(dpi: 300))
                LabeledContent("Seiten", value: "\(project.pages.count)")
            }
        }
    }

    private func pixelText(dpi: Double) -> String {
        let w = Int((project.format.documentWidthMM / 25.4 * dpi).rounded())
        let h = Int((project.format.documentHeightMM / 25.4 * dpi).rounded())
        return "\(w) × \(h) Pixel"
    }

    private func legendRow(color: Color, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 14, height: 8)
            Text(text)
        }
    }
}

/// Eingabefeld in Millimetern mit Plus/Minus.
struct MMField: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .focused($focused)
                .onSubmit(commit)
            Text("mm").foregroundStyle(.secondary)
            Stepper("", value: Binding(get: { value }, set: { value = clamp($0); text = value.mmText }),
                    in: range, step: 1)
                .labelsHidden()
        }
        .onAppear { text = value.mmText }
        .onChange(of: value) { _, neu in
            if !focused { text = neu.mmText }
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { commit() }
        }
    }

    private func clamp(_ v: Double) -> Double {
        min(max(v, range.lowerBound), range.upperBound)
    }

    private func commit() {
        let normalized = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        if let v = Double(normalized) {
            value = clamp((v * 10).rounded() / 10)
        }
        text = value.mmText
    }
}

/// Maßstäbliche Skizze der Seite mit Beschnitt, Endformat und Sicherheitsbereich.
struct FormatDiagram: View {
    let format: PageFormat

    var body: some View {
        GeometryReader { geo in
            let g = PageGeometry(format)
            let scale = min((geo.size.width - 20) / g.size.width, (geo.size.height - 20) / g.size.height)
            let w = g.size.width * scale
            let h = g.size.height * scale
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.red.opacity(0.25))
                    .frame(width: w, height: h)
                Rectangle()
                    .fill(Color(.systemBackground))
                    .frame(width: g.trimRect.width * scale, height: g.trimRect.height * scale)
                    .overlay(Rectangle().stroke(Color.primary, lineWidth: 1))
                    .offset(x: g.trimRect.minX * scale, y: g.trimRect.minY * scale)
                if format.bindingEdge != .none && format.bindingMM > 0 {
                    bindingStripe(g, scale: scale)
                }
                Rectangle()
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                    .frame(width: g.safeRect.width * scale, height: g.safeRect.height * scale)
                    .offset(x: g.safeRect.minX * scale, y: g.safeRect.minY * scale)
                VStack(spacing: 4) {
                    Text(format.summary)
                        .font(.headline)
                    Text("Beschnitt \(format.bleedMM.mmText) mm · Abstand \(format.safetyMM.mmText) mm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: w, height: h)
            }
            .frame(width: w, height: h)
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.snappy, value: format)
        }
    }

    @ViewBuilder
    private func bindingStripe(_ g: PageGeometry, scale: CGFloat) -> some View {
        let b = Units.pt(format.bindingMM) * scale
        let t = g.trimRect
        switch format.bindingEdge {
        case .top:
            Rectangle()
                .fill(Color.orange.opacity(0.25))
                .frame(width: t.width * scale, height: min(b, t.height * scale / 3))
                .offset(x: t.minX * scale, y: t.minY * scale)
        case .left:
            Rectangle()
                .fill(Color.orange.opacity(0.25))
                .frame(width: min(b, t.width * scale / 3), height: t.height * scale)
                .offset(x: t.minX * scale, y: t.minY * scale)
        case .none:
            EmptyView()
        }
    }
}
