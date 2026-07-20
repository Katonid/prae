//
//  Planets.swift
//  Himmelskompass
//
//  Positionen der hellen Planeten (Merkur bis Saturn).
//  Keplerbahn-Elemente und Raten aus JPL "Approximate Positions of the Planets"
//  (Table 1, gültig 1800–2050 n. Chr., Genauigkeit für AR-Zwecke weit ausreichend).
//

import Foundation

struct PlanetPosition {
    var azimuth: Double   // rad, 0 = Nord
    var altitude: Double  // rad
    var mag: Double       // scheinbare Helligkeit
    var delta: Double     // Entfernung zur Erde in au
}

enum Planets {
    private static let rad = Double.pi / 180

    // [a (au), e, I (°), L (°), ϖ (°), Ω (°)] bei J2000 und Raten pro Julianischem Jahrhundert
    private static let elements: [String: (el: [Double], rate: [Double])] = [
        "Merkur": (
            el: [0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593],
            rate: [0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081]
        ),
        "Venus": (
            el: [0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255],
            rate: [0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418]
        ),
        "Erde": (
            el: [1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0],
            rate: [0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0]
        ),
        "Mars": (
            el: [1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891],
            rate: [0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343]
        ),
        "Jupiter": (
            el: [5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909],
            rate: [-0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106]
        ),
        "Saturn": (
            el: [9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448],
            rate: [-0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794]
        )
    ]

    static let names = ["Merkur", "Venus", "Mars", "Jupiter", "Saturn"]

    private static func julianCenturies(_ date: Date) -> Double {
        (date.timeIntervalSince1970 / 86400 - 10957.5) / 36525 // ab J2000.0
    }

    // Heliozentrische ekliptikale Koordinaten (au)
    private static func heliocentric(_ name: String, _ T: Double) -> [Double] {
        let p = elements[name]!
        let a = p.el[0] + p.rate[0] * T
        let e = p.el[1] + p.rate[1] * T
        let I = (p.el[2] + p.rate[2] * T) * rad
        let L = (p.el[3] + p.rate[3] * T) * rad
        let varpi = (p.el[4] + p.rate[4] * T) * rad
        let Omega = (p.el[5] + p.rate[5] * T) * rad

        let omega = varpi - Omega
        let M = (L - varpi).truncatingRemainder(dividingBy: 2 * .pi)

        // Kepler-Gleichung iterativ lösen
        var E = M + e * sin(M)
        for _ in 0..<8 {
            let dE = (E - e * sin(E) - M) / (1 - e * cos(E))
            E -= dE
            if abs(dE) < 1e-8 { break }
        }

        let xv = a * (cos(E) - e)
        let yv = a * sqrt(1 - e * e) * sin(E)

        let cO = cos(Omega), sO = sin(Omega)
        let co = cos(omega), so = sin(omega)
        let cI = cos(I), sI = sin(I)

        return [
            (cO * co - sO * so * cI) * xv + (-cO * so - sO * co * cI) * yv,
            (sO * co + cO * so * cI) * xv + (-sO * so + cO * co * cI) * yv,
            (so * sI) * xv + (co * sI) * yv
        ]
    }

    // Näherungsformeln (Meeus) für die scheinbare Helligkeit
    private static func magnitude(_ name: String, _ r: Double, _ delta: Double, _ iDeg: Double) -> Double {
        let base = 5 * log10(r * delta)
        switch name {
        case "Merkur": return -0.42 + base + 0.0380 * iDeg - 0.000273 * iDeg * iDeg + 0.000002 * iDeg * iDeg * iDeg
        case "Venus": return -4.40 + base + 0.0009 * iDeg + 0.000239 * iDeg * iDeg - 0.00000065 * iDeg * iDeg * iDeg
        case "Mars": return -1.52 + base + 0.016 * iDeg
        case "Jupiter": return -9.40 + base + 0.005 * iDeg
        case "Saturn": return -8.88 + base + 0.044 * iDeg // ohne Ringanteil
        default: return base
        }
    }

    /*
     * Geozentrische Position eines Planeten:
     * (ra, dec (rad), delta (au, Entfernung zur Erde), mag (scheinbare Helligkeit))
     */
    static func compute(_ name: String, date: Date) -> (ra: Double, dec: Double, delta: Double, mag: Double) {
        let T = julianCenturies(date)
        let p = heliocentric(name, T)
        let earth = heliocentric("Erde", T)
        let g = [p[0] - earth[0], p[1] - earth[1], p[2] - earth[2]]

        // Ekliptik → Äquator
        let eps = 23.43928 * rad
        let x = g[0]
        let y = g[1] * cos(eps) - g[2] * sin(eps)
        let z = g[1] * sin(eps) + g[2] * cos(eps)

        let ra = atan2(y, x)
        let dec = atan2(z, hypot(x, y))
        let delta = sqrt(g[0] * g[0] + g[1] * g[1] + g[2] * g[2])
        let r = sqrt(p[0] * p[0] + p[1] * p[1] + p[2] * p[2])
        let R = sqrt(earth[0] * earth[0] + earth[1] * earth[1] + earth[2] * earth[2])

        // Phasenwinkel Sonne–Planet–Erde
        let cosI = (r * r + delta * delta - R * R) / (2 * r * delta)
        let iDeg = acos(max(-1, min(1, cosI))) / rad

        return (ra: ra, dec: dec, delta: delta, mag: magnitude(name, r, delta, iDeg))
    }

    // Position am Himmel eines Ortes
    static func position(_ name: String, date: Date, lat: Double, lng: Double) -> PlanetPosition {
        let c = compute(name, date: date)
        let aa = Astro.raDecToAzAlt(ra: c.ra, dec: c.dec, date: date, lat: lat, lng: lng)
        return PlanetPosition(azimuth: aa.azimuth, altitude: aa.altitude, mag: c.mag, delta: c.delta)
    }
}
