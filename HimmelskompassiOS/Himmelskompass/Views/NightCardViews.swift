//
//  NightCardViews.swift
//  Himmelskompass
//
//  Nacht-Bereich: Milchstraßen-Sichtbarkeit, ISS-Überflüge, Planeten-Tabelle
//  und Polarlicht-Chance.
//

import SwiftUI

// MARK: - Milchstraße

struct MilkyWayCardView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🌌 Milchstraße")
                .font(.headline)
                .foregroundStyle(HKColor.fg)

            if let mw = state.dayData?.milkyWay {
                StatusBox(info: mw.status)
                VStack(spacing: 0) {
                    TimesRow(label: "Zentrum sichtbar", value: mw.window)
                    TimesRow(label: "Beste Zeit", value: mw.best)
                    TimesRow(label: "Richtung / Höhe", value: mw.direction)
                    TimesRow(label: "Mond", value: mw.moon)
                }
            }

            Text("Helles Milchstraßenzentrum in der Nacht ab dem gewählten Datum: astronomische Nacht, Zentrum über dem Horizont, möglichst ohne Mondlicht. Lage im 3D-Kompass als violettes Band mit 🌌.")
                .font(.caption2)
                .foregroundStyle(HKColor.fgDim)
        }
        .hkCard()
    }
}

// MARK: - ISS

struct ISSCardView: View {
    @EnvironmentObject private var state: AppState
    var openAR: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🛰️ ISS-Überflüge")
                .font(.headline)
                .foregroundStyle(HKColor.fg)

            if let info = state.issInfo {
                StatusBox(info: info.status)

                Button("📡 AR-Ansicht: ISS am Himmel finden") {
                    openAR()
                }
                .buttonStyle(HKButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(state.tle == nil)
                .opacity(state.tle == nil ? 0.5 : 1)

                ForEach(info.passes) { pass in
                    passRow(pass)
                }

                Text(info.note.isEmpty
                     ? "Überflüge über 10° Horizonthöhe in der Nacht ab dem gewählten Datum. „Sichtbar“ heißt: dunkler Himmel und die ISS wird noch von der Sonne angestrahlt."
                     : info.note)
                    .font(.caption2)
                    .foregroundStyle(HKColor.fgDim)
            } else {
                StatusBox(info: StatusInfo(text: "Bahndaten werden geladen …", kind: .neutral))
            }
        }
        .hkCard()
    }

    private func passRow(_ pass: ISSPass) -> some View {
        let f = state.formatters
        let visible = pass.visibleFrom != nil
        let dir = HKFormatters.dirName(azDeg: HKFormatters.degValue(pass.startAz)) + " → " +
                  HKFormatters.dirName(azDeg: HKFormatters.degValue(pass.endAz))
        let visText: String
        if let from = pass.visibleFrom, let to = pass.visibleTo {
            let full = from == pass.start && to == pass.end
            visText = full ? "sichtbar" : "sichtbar " + f.range(from, to)
        } else {
            visText = "nicht sichtbar"
        }

        return HStack(spacing: 10) {
            Text(f.range(pass.start, pass.end))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(HKColor.fg)
            Spacer()
            Text("max. \(Int(HKFormatters.degValue(pass.maxEl).rounded()))° · \(dir)")
                .font(.caption)
                .foregroundStyle(HKColor.fgDim)
            Text(visText)
                .font(.caption.bold())
                .foregroundStyle(visible ? HKColor.good : HKColor.fgDim)
        }
        .padding(8)
        .background(visible ? HKColor.status(.good).opacity(0.25) : HKColor.card2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Planeten

struct PlanetsCardView: View {
    @EnvironmentObject private var state: AppState
    var openAR: () -> Void
    @State private var now = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🪐 Planeten")
                .font(.headline)
                .foregroundStyle(HKColor.fg)

            Button("📡 AR-Ansicht: Planeten, Mond & ISS", action: openAR)
                .buttonStyle(HKButtonStyle())
                .frame(maxWidth: .infinity)

            VStack(spacing: 0) {
                ForEach(state.planetRows(now: now)) { row in
                    TimesRow(label: row.name, value: row.text,
                             valueColor: row.up ? HKColor.fg : HKColor.fgDim)
                }
            }

            Text("Positionen zur aktuellen Uhrzeit. Helligkeit in mag – je kleiner der Wert, desto heller (Venus ca. −4, Jupiter ca. −2, mit bloßem Auge sichtbar bis ca. +6).")
                .font(.caption2)
                .foregroundStyle(HKColor.fgDim)
        }
        .hkCard()
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { d in
            now = d
        }
    }
}

// MARK: - Polarlicht

struct AuroraCardView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🌠 Polarlicht-Chance")
                .font(.headline)
                .foregroundStyle(HKColor.fg)

            if let info = state.auroraInfo {
                StatusBox(info: info.status)
                VStack(spacing: 0) {
                    TimesRow(label: "Kp-Index (max. in der Nacht)", value: info.kpText)
                    TimesRow(label: "Geomagnetische Breite", value: info.magLatText)
                    TimesRow(label: "Dunkelheit", value: info.darkText)
                }
            } else {
                StatusBox(info: StatusInfo(text: "Weltraumwetter wird geladen …", kind: .neutral))
            }

            Text("Abschätzung aus der NOAA-Kp-Prognose und der geomagnetischen Breite des Ortes. Kurzfristige Ausbrüche können die Chance jederzeit erhöhen – bei hohem Kp Richtung Norden schauen.")
                .font(.caption2)
                .foregroundStyle(HKColor.fgDim)
        }
        .hkCard()
    }
}
