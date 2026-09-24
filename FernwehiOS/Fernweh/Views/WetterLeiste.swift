import SwiftUI

/// Die vier Abschnitte eines Tages nebeneinander: Symbol, Temperatur, Regen.
struct WetterLeiste: View {
    let wetter: Tageswetter
    var kompakt = false

    var body: some View {
        if kompakt {
            HStack(spacing: 10) {
                ForEach(wetter.abschnitte) { a in
                    HStack(spacing: 3) {
                        Image(systemName: a.symbol).symbolRenderingMode(.multicolor)
                        Text("\(Int(a.hoechst.rounded()))°")
                    }
                    .accessibilityLabel("\(a.name): \(a.beschreibung), \(a.temperatur)")
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 0) {
                    ForEach(wetter.abschnitte) { a in
                        VStack(spacing: 5) {
                            Text(a.name)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Image(systemName: a.symbol)
                                .symbolRenderingMode(.multicolor)
                                .font(.title2)
                                .frame(height: 30)
                            Text(a.temperatur)
                                .font(.subheadline.weight(.bold))
                            Text(a.regen >= 0.2 ? String(format: "%.1f mm", a.regen) : a.beschreibung)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                if wetter.vorhersage {
                    Text("Vorhersage, noch keine Messung")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
