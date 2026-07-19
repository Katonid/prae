//
//  ISSPasses.swift
//  Himmelskompass
//
//  ISS-Überflugberechnung auf Basis des SGP4-Propagators.
//

import Foundation

struct ISSPass: Identifiable {
    let id = UUID()
    var start: Date
    var end: Date
    var startAz: Double  // rad
    var endAz: Double    // rad
    var maxTime: Date
    var maxEl: Double    // rad
    var visibleFrom: Date?
    var visibleTo: Date?
}

struct ISSSkyState {
    var azimuth: Double   // rad
    var elevation: Double // rad
    var sunlit: Bool
    var darkSky: Bool
}

enum ISSCalc {
    private static let rad = Double.pi / 180
    private static let earthR = 6371.0 // km

    // Ist der Satellit von der Sonne beleuchtet? (zylindrisches Erdschatten-Modell)
    static func isSunlit(_ posEci: ECIPosition, sunRa: Double, sunDec: Double) -> Bool {
        let r = [posEci.x, posEci.y, posEci.z]
        let s = [cos(sunDec) * cos(sunRa), cos(sunDec) * sin(sunRa), sin(sunDec)]
        let dot = r[0] * s[0] + r[1] * s[1] + r[2] * s[2]
        if dot >= 0 { return true } // auf der Sonnenseite der Erde
        let r2 = r[0] * r[0] + r[1] * r[1] + r[2] * r[2]
        let perp = (max(0, r2 - dot * dot)).squareRoot()
        return perp > earthR
    }

    /// Aktuelle Position der ISS am Himmel des Beobachters.
    static func skyState(satrec: Satrec, date: Date, lat: Double, lng: Double) -> ISSSkyState? {
        guard let pos = SGP4.propagate(satrec, date: date) else { return nil }
        let gmst = SGP4.gstime(SGP4.julianDate(date))
        let ecf = SGP4.eciToEcf(pos, gmst: gmst)
        let observer = GeodeticObserver(latitude: lat * rad, longitude: lng * rad, height: 0.05)
        let look = SGP4.ecfToLookAngles(observer: observer, satelliteEcf: ecf)
        let sunAlt = Astro.sunPosition(date: date, lat: lat, lng: lng).altitude
        let sun = Astro.sunRaDec(date: date)
        return ISSSkyState(
            azimuth: look.azimuth,
            elevation: look.elevation,
            sunlit: isSunlit(pos, sunRa: sun.ra, sunDec: sun.dec),
            darkSky: sunAlt < -6 * rad
        )
    }

    /*
     * Überflüge mit Elevation > 10° im Zeitfenster [start, start + hours].
     * Ein Überflug ist "sichtbar", solange der Beobachter im Dunkeln steht
     * (Sonne < −6°) und die ISS von der Sonne angestrahlt wird.
     */
    static func computePasses(satrec: Satrec, lat: Double, lng: Double,
                              start: Date, hours: Double) -> [ISSPass] {
        let observer = GeodeticObserver(latitude: lat * rad, longitude: lng * rad, height: 0.05)
        let stepS = 15.0
        let minEl = 10 * rad
        var passes: [ISSPass] = []
        var cur: [(t: Date, el: Double, az: Double, visible: Bool)] = []

        var t = 0.0
        while t <= hours * 3600 {
            let date = start.addingTimeInterval(t)
            t += stepS
            guard let pos = SGP4.propagate(satrec, date: date) else { continue }

            let gmst = SGP4.gstime(SGP4.julianDate(date))
            let ecf = SGP4.eciToEcf(pos, gmst: gmst)
            let look = SGP4.ecfToLookAngles(observer: observer, satelliteEcf: ecf)

            if look.elevation > minEl {
                let sunAltObs = Astro.sunPosition(date: date, lat: lat, lng: lng).altitude
                let sun = Astro.sunRaDec(date: date)
                let visible = sunAltObs < -6 * rad && isSunlit(pos, sunRa: sun.ra, sunDec: sun.dec)
                cur.append((t: date, el: look.elevation, az: look.azimuth, visible: visible))
            } else if !cur.isEmpty {
                passes.append(finishPass(cur))
                cur = []
            }
        }
        if !cur.isEmpty { passes.append(finishPass(cur)) }
        return passes
    }

    private static func finishPass(_ samples: [(t: Date, el: Double, az: Double, visible: Bool)]) -> ISSPass {
        var maxSample = samples[0]
        for s in samples where s.el > maxSample.el { maxSample = s }
        let vis = samples.filter { $0.visible }
        return ISSPass(
            start: samples[0].t,
            end: samples[samples.count - 1].t,
            startAz: samples[0].az,
            endAz: samples[samples.count - 1].az,
            maxTime: maxSample.t,
            maxEl: maxSample.el,
            visibleFrom: vis.first?.t,
            visibleTo: vis.last?.t
        )
    }
}
