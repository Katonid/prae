//
//  Astro.swift
//  Himmelskompass
//
//  Sonnen- und Mondberechnungen nach Jean Meeus, "Astronomical Algorithms",
//  in der vereinfachten Form der bekannten SunCalc-Algorithmen.
//  Genauigkeit: ~1 Minute für Sonnenzeiten, wenige Minuten für Mondzeiten.
//

import Foundation

struct SkyPosition {
    var azimuth: Double   // rad, 0 = Nord, im Uhrzeigersinn
    var altitude: Double  // rad
}

struct MoonSkyPosition {
    var azimuth: Double
    var altitude: Double
    var distance: Double  // km
    var parallacticAngle: Double
}

struct SunTimes {
    var solarNoon: Date?
    var nadir: Date?
    var sunrise: Date?
    var sunset: Date?
    var blueHourDawnEnd: Date?
    var blueHourDuskStart: Date?
    var dawn: Date?
    var dusk: Date?
    var blueHourDawnStart: Date?
    var blueHourDuskEnd: Date?
    var nauticalDawn: Date?
    var nauticalDusk: Date?
    var nightEnd: Date?
    var night: Date?
    var goldenHourDawnEnd: Date?
    var goldenHourDuskStart: Date?
}

struct MoonTimes {
    var rise: Date?
    var set: Date?
    var alwaysUp = false
    var alwaysDown = false
}

struct MoonIllumination {
    var fraction: Double
    var phase: Double   // 0 = Neumond, 0.5 = Vollmond
    var angle: Double
}

struct MilkyWayPoint {
    var azimuth: Double
    var altitude: Double
    var l: Double       // galaktische Länge in Grad (0 = Zentrum)
}

enum Astro {
    static let rad = Double.pi / 180
    private static let dayMs = 1000.0 * 60 * 60 * 24
    private static let J1970 = 2440588.0
    private static let J2000 = 2451545.0

    static func toJulian(_ date: Date) -> Double { date.timeIntervalSince1970 * 1000 / dayMs - 0.5 + J1970 }
    static func fromJulian(_ j: Double) -> Date { Date(timeIntervalSince1970: (j + 0.5 - J1970) * dayMs / 1000) }
    static func toDays(_ date: Date) -> Double { toJulian(date) - J2000 }

    // Ekliptikschiefe
    private static let e = rad * 23.4397

    private static func rightAscension(_ l: Double, _ b: Double) -> Double {
        atan2(sin(l) * cos(e) - tan(b) * sin(e), cos(l))
    }
    private static func declination(_ l: Double, _ b: Double) -> Double {
        asin(sin(b) * cos(e) + cos(b) * sin(e) * sin(l))
    }
    // Azimut hier: 0 = Süd; in den öffentlichen Funktionen auf 0 = Nord umgerechnet
    private static func azimuth(_ H: Double, _ phi: Double, _ dec: Double) -> Double {
        atan2(sin(H), cos(H) * sin(phi) - tan(dec) * cos(phi))
    }
    private static func altitude(_ H: Double, _ phi: Double, _ dec: Double) -> Double {
        asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(H))
    }
    private static func siderealTime(_ d: Double, _ lw: Double) -> Double {
        rad * (280.16 + 360.9856235 * d) - lw
    }

    private static func astroRefraction(_ h: Double) -> Double {
        let h2 = max(h, 0) // Formel gilt nur für positive Höhen
        return 0.0002967 / tan(h2 + 0.00312536 / (h2 + 0.08901179))
    }

    private static func normalizeAz(_ a: Double) -> Double {
        var a = a.truncatingRemainder(dividingBy: 2 * .pi)
        if a < 0 { a += 2 * .pi }
        return a
    }

    // MARK: - Sonne

    private static func solarMeanAnomaly(_ d: Double) -> Double { rad * (357.5291 + 0.98560028 * d) }

    private static func eclipticLongitude(_ M: Double) -> Double {
        let C = rad * (1.9148 * sin(M) + 0.02 * sin(2 * M) + 0.0003 * sin(3 * M))
        let P = rad * 102.9372 // Perihel der Erde
        return M + C + P + .pi
    }

    private static func sunCoords(_ d: Double) -> (dec: Double, ra: Double) {
        let M = solarMeanAnomaly(d)
        let L = eclipticLongitude(M)
        return (dec: declination(L, 0), ra: rightAscension(L, 0))
    }

    static func sunPosition(date: Date, lat: Double, lng: Double) -> SkyPosition {
        let lw = rad * -lng
        let phi = rad * lat
        let d = toDays(date)
        let c = sunCoords(d)
        let H = siderealTime(d, lw) - c.ra
        return SkyPosition(
            azimuth: normalizeAz(azimuth(H, phi, c.dec) + .pi),
            altitude: altitude(H, phi, c.dec)
        )
    }

    // Äquatorialkoordinaten der Sonne (für Beleuchtungsprüfung von Satelliten)
    static func sunRaDec(date: Date) -> (dec: Double, ra: Double) {
        sunCoords(toDays(date))
    }

    // RA/Dek → Azimut/Höhe für Ort und Zeitpunkt (z. B. für Planeten)
    static func raDecToAzAlt(ra: Double, dec: Double, date: Date, lat: Double, lng: Double) -> SkyPosition {
        let lw = rad * -lng
        let phi = rad * lat
        let H = siderealTime(toDays(date), lw) - ra
        return SkyPosition(
            azimuth: normalizeAz(azimuth(H, phi, dec) + .pi),
            altitude: altitude(H, phi, dec)
        )
    }

    // MARK: - Sonnenzeiten

    private static let J0 = 0.0009

    private static func julianCycle(_ d: Double, _ lw: Double) -> Double { (d - J0 - lw / (2 * .pi)).rounded() }
    private static func approxTransit(_ Ht: Double, _ lw: Double, _ n: Double) -> Double { J0 + (Ht + lw) / (2 * .pi) + n }
    private static func solarTransitJ(_ ds: Double, _ M: Double, _ L: Double) -> Double {
        J2000 + ds + 0.0053 * sin(M) - 0.0069 * sin(2 * L)
    }
    private static func hourAngle(_ h: Double, _ phi: Double, _ d: Double) -> Double {
        acos((sin(h) - sin(phi) * sin(d)) / (cos(phi) * cos(d)))
    }

    private static func getSetJ(_ h: Double, _ lw: Double, _ phi: Double, _ dec: Double,
                                _ n: Double, _ M: Double, _ L: Double) -> Double {
        let w = hourAngle(h, phi, dec)
        let a = approxTransit(w, lw, n)
        return solarTransitJ(a, M, L)
    }

    static func sunTimes(date: Date, lat: Double, lng: Double) -> SunTimes {
        let lw = rad * -lng
        let phi = rad * lat
        let d = toDays(date)
        let n = julianCycle(d, lw)
        let ds = approxTransit(0, lw, n)
        let M = solarMeanAnomaly(ds)
        let L = eclipticLongitude(M)
        let dec = declination(L, 0)
        let Jnoon = solarTransitJ(ds, M, L)

        var result = SunTimes()
        result.solarNoon = fromJulian(Jnoon)
        result.nadir = fromJulian(Jnoon - 0.5)

        func pair(_ angleDeg: Double) -> (rise: Date?, set: Date?) {
            let Jset = getSetJ(angleDeg * rad, lw, phi, dec, n, M, L)
            let Jrise = Jnoon - (Jset - Jnoon)
            return (Jrise.isNaN ? nil : fromJulian(Jrise), Jset.isNaN ? nil : fromJulian(Jset))
        }

        var p = pair(-0.833); result.sunrise = p.rise; result.sunset = p.set
        p = pair(-4); result.blueHourDawnEnd = p.rise; result.blueHourDuskStart = p.set
        p = pair(-6); result.dawn = p.rise; result.dusk = p.set
        p = pair(-8); result.blueHourDawnStart = p.rise; result.blueHourDuskEnd = p.set
        p = pair(-12); result.nauticalDawn = p.rise; result.nauticalDusk = p.set
        p = pair(-18); result.nightEnd = p.rise; result.night = p.set
        p = pair(6); result.goldenHourDawnEnd = p.rise; result.goldenHourDuskStart = p.set
        return result
    }

    // MARK: - Mond

    private static func moonCoords(_ d: Double) -> (ra: Double, dec: Double, dist: Double) {
        let L = rad * (218.316 + 13.176396 * d) // mittlere ekliptikale Länge
        let M = rad * (134.963 + 13.064993 * d) // mittlere Anomalie
        let F = rad * (93.272 + 13.229350 * d)  // mittlerer Abstand vom Knoten

        let l = L + rad * 6.289 * sin(M)        // Länge
        let b = rad * 5.128 * sin(F)            // Breite
        let dt = 385001 - 20905 * cos(M)        // Entfernung in km

        return (ra: rightAscension(l, b), dec: declination(l, b), dist: dt)
    }

    static func moonPosition(date: Date, lat: Double, lng: Double) -> MoonSkyPosition {
        let lw = rad * -lng
        let phi = rad * lat
        let d = toDays(date)
        let c = moonCoords(d)
        let H = siderealTime(d, lw) - c.ra
        var h = altitude(H, phi, c.dec)
        let pa = atan2(sin(H), tan(phi) * cos(c.dec) - sin(c.dec) * cos(H))
        h += astroRefraction(h)
        return MoonSkyPosition(
            azimuth: normalizeAz(azimuth(H, phi, c.dec) + .pi),
            altitude: h,
            distance: c.dist,
            parallacticAngle: pa
        )
    }

    static func moonIllumination(date: Date) -> MoonIllumination {
        let d = toDays(date)
        let s = sunCoords(d)
        let m = moonCoords(d)
        let sdist = 149598000.0 // Entfernung Erde–Sonne in km

        let phi = acos(
            sin(s.dec) * sin(m.dec) +
            cos(s.dec) * cos(m.dec) * cos(s.ra - m.ra)
        )
        let inc = atan2(sdist * sin(phi), m.dist - sdist * cos(phi))
        let angle = atan2(
            cos(s.dec) * sin(s.ra - m.ra),
            sin(s.dec) * cos(m.dec) - cos(s.dec) * sin(m.dec) * cos(s.ra - m.ra)
        )

        return MoonIllumination(
            fraction: (1 + cos(inc)) / 2,
            phase: 0.5 + 0.5 * inc * (angle < 0 ? -1 : 1) / .pi,
            angle: angle
        )
    }

    private static func hoursLater(_ date: Date, _ h: Double) -> Date {
        date.addingTimeInterval(h * 3600)
    }

    // Mondauf-/-untergang in den 24 Stunden ab dem übergebenen Zeitpunkt.
    // Der Aufrufer übergibt Mitternacht in der Zeitzone des Ortes.
    static func moonTimes(date: Date, lat: Double, lng: Double) -> MoonTimes {
        let t = date
        let hc = 0.133 * rad
        var h0 = moonPosition(date: t, lat: lat, lng: lng).altitude - hc
        var rise: Double?
        var set: Double?
        var ye = 0.0

        // stundenweise nach Nulldurchgängen suchen (Interpolation über 2 Stunden)
        var i = 1.0
        while i <= 24 {
            let h1 = moonPosition(date: hoursLater(t, i), lat: lat, lng: lng).altitude - hc
            let h2 = moonPosition(date: hoursLater(t, i + 1), lat: lat, lng: lng).altitude - hc

            let a = (h0 + h2) / 2 - h1
            let b = (h2 - h0) / 2
            let xe = -b / (2 * a)
            ye = (a * xe + b) * xe + h1
            let d = b * b - 4 * a * h1
            var roots = 0
            var x1 = 0.0
            var x2 = 0.0

            if d >= 0 {
                let dx = sqrt(d) / (abs(a) * 2)
                x1 = xe - dx
                x2 = xe + dx
                if abs(x1) <= 1 { roots += 1 }
                if abs(x2) <= 1 { roots += 1 }
                if x1 < -1 { x1 = x2 }
            }

            if roots == 1 {
                if h0 < 0 { rise = i + x1 } else { set = i + x1 }
            } else if roots == 2 {
                rise = i + (ye < 0 ? x2 : x1)
                set = i + (ye < 0 ? x1 : x2)
            }

            if rise != nil && set != nil { break }
            h0 = h2
            i += 2
        }

        var result = MoonTimes()
        result.rise = rise.map { hoursLater(t, $0) }
        result.set = set.map { hoursLater(t, $0) }
        if rise == nil && set == nil {
            if ye > 0 { result.alwaysUp = true } else { result.alwaysDown = true }
        }
        return result
    }

    // MARK: - Galaktisches Zentrum (Milchstraße)
    // J2000: RA 17h 45m 40s, Deklination −29° 00′ 28″ (Sagittarius A*)
    private static let gcRa = rad * 266.4168
    private static let gcDec = rad * -29.0078

    static func galacticCenterPosition(date: Date, lat: Double, lng: Double) -> SkyPosition {
        let lw = rad * -lng
        let phi = rad * lat
        let d = toDays(date)
        let H = siderealTime(d, lw) - gcRa
        return SkyPosition(
            azimuth: normalizeAz(azimuth(H, phi, gcDec) + .pi),
            altitude: altitude(H, phi, gcDec)
        )
    }

    // Galaktische Ebene (b = 0) als Punktkette in Äquatorialkoordinaten,
    // einmalig vorberechnet. Nordgalaktischer Pol (J2000): RA 192,85948°,
    // Dek 27,12825°; galaktische Länge des Himmelsnordpols: 122,93192°.
    private static let galacticPlane: [(ra: Double, dec: Double, l: Double)] = {
        let ngpRa = rad * 192.85948
        let ngpDec = rad * 27.12825
        let lNcp = rad * 122.93192
        var points: [(ra: Double, dec: Double, l: Double)] = []
        for l in stride(from: 0.0, to: 360.0, by: 4.0) {
            let dl = lNcp - rad * l
            let dec = asin(cos(ngpDec) * cos(dl))
            let ra = ngpRa + atan2(sin(dl), -sin(ngpDec) * cos(dl))
            points.append((ra: ra, dec: dec, l: l))
        }
        return points
    }()

    // Aktuelle Lage des Milchstraßen-Bands am Himmel des Ortes.
    // l = galaktische Länge (0 = galaktisches Zentrum, hellster Bereich).
    static func milkyWayBand(date: Date, lat: Double, lng: Double) -> [MilkyWayPoint] {
        let lw = rad * -lng
        let phi = rad * lat
        let st = siderealTime(toDays(date), lw)
        return galacticPlane.map { p in
            let H = st - p.ra
            return MilkyWayPoint(
                azimuth: normalizeAz(azimuth(H, phi, p.dec) + .pi),
                altitude: altitude(H, phi, p.dec),
                l: p.l
            )
        }
    }

    // Phasenname aus Phasenwert (0 = Neumond, 0.5 = Vollmond)
    static func moonPhaseName(_ phase: Double) -> String {
        let names = [
            "Neumond", "Zunehmende Sichel", "Erstes Viertel", "Zunehmender Mond",
            "Vollmond", "Abnehmender Mond", "Letztes Viertel", "Abnehmende Sichel"
        ]
        let idx = Int((phase * 8).rounded()) % 8
        return names[idx]
    }
}
