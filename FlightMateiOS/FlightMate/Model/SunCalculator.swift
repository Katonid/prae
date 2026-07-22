//
//  SunCalculator.swift
//  FlightMate
//
//  Sonnenstand und Lichtfenster, vollständig on-device berechnet
//  (PRD Kap. 10 — kein Netzwerk nötig, deterministisch).
//  Algorithmen: vereinfachte Sonnenposition nach Meeus/SunCalc,
//  Genauigkeit für Fotoplanung mehr als ausreichend (< 1 min).
//

import Foundation
import CoreLocation

/// Ein Lichtfenster am Tag (goldene Stunde, blaue Stunde …).
struct LightWindow: Hashable {
    let start: Date
    let end: Date
    let kind: Kind

    enum Kind: String {
        case blueHourMorning = "Blaue Stunde (morgens)"
        case goldenHourMorning = "Goldene Stunde (morgens)"
        case goldenHourEvening = "Goldene Stunde (abends)"
        case blueHourEvening = "Blaue Stunde (abends)"
    }
}

struct SunDay {
    let sunrise: Date?
    let sunset: Date?
    let lightWindows: [LightWindow]
}

enum SunCalculator {

    // MARK: Sonnenposition

    /// Höhe (Grad über Horizont) und Azimut (Grad, 0 = Nord) der Sonne.
    static func position(at date: Date, latitude: Double, longitude: Double) -> (altitude: Double, azimuth: Double) {
        let rad = Double.pi / 180
        let d = date.timeIntervalSince1970 / 86400 - 10957.5 // Tage seit J2000.0

        let g = (357.529 + 0.98560028 * d) * rad              // mittlere Anomalie
        let q = 280.459 + 0.98564736 * d                      // mittlere Länge
        let l = (q + 1.915 * sin(g) + 0.020 * sin(2 * g)) * rad // ekliptikale Länge
        let e = (23.439 - 0.00000036 * d) * rad               // Ekliptikschiefe

        let ra = atan2(cos(e) * sin(l), cos(l))               // Rektaszension
        let dec = asin(sin(e) * sin(l))                       // Deklination

        let gmst = (280.16 + 360.9856235 * d).truncatingRemainder(dividingBy: 360) * rad
        let h = gmst + longitude * rad - ra                   // Stundenwinkel

        let lat = latitude * rad
        let altitude = asin(sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(h))
        var azimuth = atan2(sin(h), cos(h) * sin(lat) - tan(dec) * cos(lat)) / rad + 180
        if azimuth < 0 { azimuth += 360 }
        if azimuth >= 360 { azimuth -= 360 }
        return (altitude / rad, azimuth)
    }

    // MARK: Tagesfenster

    /// Sonnenauf-/-untergang und Lichtfenster für einen Kalendertag,
    /// ermittelt durch Abtasten der Sonnenhöhe in 2-Minuten-Schritten.
    /// Robust auch für polare Grenzfälle (kein Auf-/Untergang → nil).
    static func day(for date: Date, latitude: Double, longitude: Double, calendar: Calendar = .current) -> SunDay {
        let dayStart = calendar.startOfDay(for: date)
        let step: TimeInterval = 120
        let samples = 24 * 30

        var altitudes: [Double] = []
        altitudes.reserveCapacity(samples + 1)
        for i in 0...samples {
            let t = dayStart.addingTimeInterval(Double(i) * step)
            altitudes.append(position(at: t, latitude: latitude, longitude: longitude).altitude)
        }
        func time(_ i: Int) -> Date { dayStart.addingTimeInterval(Double(i) * step) }

        // Sonnenauf-/-untergang: Durchgang durch -0,833° (Refraktion + Sonnenradius).
        var sunrise: Date?
        var sunset: Date?
        let horizon = -0.833
        for i in 1...samples {
            if altitudes[i - 1] < horizon && altitudes[i] >= horizon && sunrise == nil {
                sunrise = time(i)
            }
            if altitudes[i - 1] >= horizon && altitudes[i] < horizon {
                sunset = time(i)
            }
        }

        // Lichtfenster über Höhenbereiche: blaue Stunde -8°…-4°, goldene -4°…+6°.
        func windows(range: ClosedRange<Double>, morning: LightWindow.Kind, evening: LightWindow.Kind) -> [LightWindow] {
            var result: [LightWindow] = []
            var windowStart: Int?
            for i in 0...samples {
                let inside = range.contains(altitudes[i])
                if inside && windowStart == nil { windowStart = i }
                if (!inside || i == samples), let s = windowStart {
                    let midIndex = (s + i) / 2
                    let rising = altitudes[min(midIndex + 1, samples)] > altitudes[midIndex]
                    result.append(LightWindow(start: time(s), end: time(i), kind: rising ? morning : evening))
                    windowStart = nil
                }
            }
            return result
        }

        var lightWindows = windows(range: (-8.0)...(-4.0), morning: .blueHourMorning, evening: .blueHourEvening)
        lightWindows += windows(range: (-4.0)...(6.0), morning: .goldenHourMorning, evening: .goldenHourEvening)
        lightWindows.sort { $0.start < $1.start }

        return SunDay(sunrise: sunrise, sunset: sunset, lightWindows: lightWindows)
    }

    // MARK: Lichtqualität

    /// Fotografische Lichtqualität 0…1 für einen Zeitpunkt — der
    /// Licht-Anteil des Flight Scores (PRD F3). Bewusst grob und
    /// erklärbar statt pseudo-präzise.
    static func lightQuality(at date: Date, latitude: Double, longitude: Double) -> Double {
        let altitude = position(at: date, latitude: latitude, longitude: longitude).altitude
        switch altitude {
        case ..<(-8):        return 0.10  // Nacht: fliegbar, aber kaum Foto-Licht
        case -8 ..< -4:      return 0.85  // blaue Stunde
        case -4 ..< 6:       return 1.00  // goldene Stunde
        case 6 ..< 15:       return 0.75  // tiefe Sonne, noch weiches Licht
        case 15 ..< 35:      return 0.50
        default:             return 0.35  // hartes Mittagslicht
        }
    }

    static func lightLabel(at date: Date, latitude: Double, longitude: Double) -> String {
        let altitude = position(at: date, latitude: latitude, longitude: longitude).altitude
        switch altitude {
        case ..<(-8):        return "Nacht"
        case -8 ..< -4:      return "Blaue Stunde"
        case -4 ..< 6:       return "Goldene Stunde"
        case 6 ..< 15:       return "Tiefe Sonne"
        case 15 ..< 35:      return "Tageslicht"
        default:             return "Hartes Mittagslicht"
        }
    }
}
