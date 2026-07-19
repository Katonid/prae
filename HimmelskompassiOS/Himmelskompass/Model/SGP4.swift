//
//  SGP4.swift
//  Himmelskompass
//
//  SGP4-Bahnpropagator (Near-Earth-Modell) nach Vallado, "Revisiting Spacetrack
//  Report #3", in der Form der verbreiteten satellite.js-Implementierung.
//  Für erdnahe Satelliten wie die ISS (Umlaufzeit < 225 min) vollkommen
//  ausreichend; das Deep-Space-Modell (SDP4) ist bewusst nicht enthalten.
//

import Foundation

struct ECIPosition {
    var x: Double // km
    var y: Double
    var z: Double
}

struct LookAngles {
    var azimuth: Double   // rad, 0 = Nord
    var elevation: Double // rad
    var rangeSat: Double  // km
}

struct GeodeticObserver {
    var latitude: Double  // rad
    var longitude: Double // rad
    var height: Double    // km
}

final class Satrec {
    // Bahnelemente aus der TLE
    var ecco = 0.0, inclo = 0.0, nodeo = 0.0, argpo = 0.0, mo = 0.0
    var no = 0.0          // mittlere Bewegung (rad/min, "un-kozai")
    var bstar = 0.0
    var jdsatepoch = 0.0

    // Initialisierte Koeffizienten
    var isimp = false
    var aycof = 0.0, con41 = 0.0, cc1 = 0.0, cc4 = 0.0, cc5 = 0.0
    var d2 = 0.0, d3 = 0.0, d4 = 0.0
    var delmo = 0.0, eta = 0.0, argpdot = 0.0, omgcof = 0.0, sinmao = 0.0
    var t2cof = 0.0, t3cof = 0.0, t4cof = 0.0, t5cof = 0.0
    var x1mth2 = 0.0, x7thm1 = 0.0, mdot = 0.0, nodedot = 0.0
    var xlcof = 0.0, xmcof = 0.0, nodecf = 0.0
    var error = 0
}

enum SGP4 {
    // WGS72-Konstanten (wie in satellite.js Standard)
    static let earthRadiusKm = 6378.135
    private static let mu = 398600.8
    private static let xke = 60.0 / (earthRadiusKm * earthRadiusKm * earthRadiusKm / mu).squareRoot()
    private static let j2 = 0.001082616
    private static let j3 = -0.00000253881
    private static let j4 = -0.00000165597
    private static let j3oj2 = j3 / j2
    private static let x2o3 = 2.0 / 3.0
    private static let twoPi = 2 * Double.pi
    private static let deg2rad = Double.pi / 180

    // MARK: - TLE einlesen

    /// Erstellt einen Satellitendatensatz aus den beiden TLE-Zeilen.
    /// Gibt nil zurück, wenn die Zeilen nicht lesbar sind oder es sich um
    /// einen Deep-Space-Satelliten handelt (hier nicht unterstützt).
    static func twoline2satrec(_ line1: String, _ line2: String) -> Satrec? {
        guard line1.count >= 64, line2.count >= 63 else { return nil }
        let l1 = Array(line1)
        let l2 = Array(line2)

        func sub(_ arr: [Character], _ from: Int, _ to: Int) -> String {
            String(arr[from..<min(to, arr.count)]).trimmingCharacters(in: .whitespaces)
        }
        func num(_ arr: [Character], _ from: Int, _ to: Int) -> Double? {
            Double(sub(arr, from, to))
        }

        guard let epochyr = Int(sub(l1, 18, 20)),
              let epochdays = num(l1, 20, 32),
              let inclo = num(l2, 8, 16),
              let nodeo = num(l2, 17, 25),
              let eccoRaw = Double("0." + sub(l2, 26, 33)),
              let argpo = num(l2, 34, 42),
              let mo = num(l2, 43, 51),
              let noRevs = num(l2, 52, 63)
        else { return nil }

        // B*-Term: Vorzeichen + 5-stellige Mantisse + Exponent, z. B. " 34123-4"
        var bstar = 0.0
        let bstarStr = String(l1[53..<61])
        if bstarStr.count == 8 {
            let sign: Double = bstarStr.hasPrefix("-") ? -1 : 1
            let mantissa = Double(bstarStr.dropFirst().prefix(5).trimmingCharacters(in: .whitespaces)) ?? 0
            let expStr = String(bstarStr.suffix(2)).replacingOccurrences(of: "+", with: "")
            let exp = Double(expStr) ?? 0
            bstar = sign * (mantissa / 100000.0) * pow(10, exp)
        }

        let rec = Satrec()
        rec.ecco = eccoRaw
        rec.inclo = inclo * deg2rad
        rec.nodeo = nodeo * deg2rad
        rec.argpo = argpo * deg2rad
        rec.mo = mo * deg2rad

        let xpdotp = 1440.0 / twoPi
        rec.no = noRevs / xpdotp // rad/min (noch Kozai)
        rec.bstar = bstar

        let year = epochyr < 57 ? 2000 + epochyr : 1900 + epochyr
        // Julianisches Datum für den 1. Januar 0:00 des Jahres + Tagesbruchteil
        let jdJan1 = 367.0 * Double(year)
            - ((7.0 * Double(year)) * 0.25).rounded(.down)
            + 30.0 + 1.0 + 1721013.5
        rec.jdsatepoch = jdJan1 + (epochdays - 1.0)

        guard sgp4init(rec) else { return nil }
        return rec
    }

    // MARK: - Initialisierung

    private static func sgp4init(_ rec: Satrec) -> Bool {
        let temp4 = 1.5e-12

        let ecco = rec.ecco
        let inclo = rec.inclo
        let no = rec.no

        let eccsq = ecco * ecco
        let omeosq = 1.0 - eccsq
        let rteosq = omeosq.squareRoot()
        let cosio = cos(inclo)
        let cosio2 = cosio * cosio
        let sinio = sin(inclo)

        // initl: Kozai → Brouwer mittlere Bewegung
        let ak = pow(xke / no, x2o3)
        let d1 = 0.75 * j2 * (3.0 * cosio2 - 1.0) / (rteosq * omeosq)
        var del = d1 / (ak * ak)
        let adel = ak * (1.0 - del * del - del * (1.0 / 3.0 + 134.0 * del * del * del / 81.0))
        del = d1 / (adel * adel)
        let noUnkozai = no / (1.0 + del)
        rec.no = noUnkozai

        let ao = pow(xke / noUnkozai, x2o3)
        let po = ao * omeosq
        let con42 = 1.0 - 5.0 * cosio2
        rec.con41 = -con42 - 2.0 * cosio2
        let posq = po * po
        let rp = ao * (1.0 - ecco)

        // Deep-Space-Satelliten (Umlaufzeit ≥ 225 min) werden nicht unterstützt
        if twoPi / noUnkozai >= 225.0 { return false }
        guard omeosq >= 0 || noUnkozai >= 0 else { return false }

        rec.isimp = rp < (220.0 / earthRadiusKm + 1.0)

        let ss = 78.0 / earthRadiusKm + 1.0
        let qzms2t = pow((120.0 - 78.0) / earthRadiusKm, 4)
        var sfour = ss
        var qzms24 = qzms2t
        let perige = (rp - 1.0) * earthRadiusKm
        if perige < 156.0 {
            sfour = perige - 78.0
            if perige < 98.0 { sfour = 20.0 }
            qzms24 = pow((120.0 - sfour) / earthRadiusKm, 4)
            sfour = sfour / earthRadiusKm + 1.0
        }
        let pinvsq = 1.0 / posq
        let tsi = 1.0 / (ao - sfour)
        rec.eta = ao * ecco * tsi
        let etasq = rec.eta * rec.eta
        let eeta = ecco * rec.eta
        let psisq = abs(1.0 - etasq)
        let coef = qzms24 * pow(tsi, 4)
        let coef1 = coef / pow(psisq, 3.5)
        let cc2 = coef1 * noUnkozai *
            (ao * (1.0 + 1.5 * etasq + eeta * (4.0 + etasq)) +
             0.375 * j2 * tsi / psisq * rec.con41 * (8.0 + 3.0 * etasq * (8.0 + etasq)))
        rec.cc1 = rec.bstar * cc2
        var cc3 = 0.0
        if ecco > 1.0e-4 {
            cc3 = -2.0 * coef * tsi * j3oj2 * noUnkozai * sinio / ecco
        }
        rec.x1mth2 = 1.0 - cosio2
        rec.cc4 = 2.0 * noUnkozai * coef1 * ao * omeosq *
            (rec.eta * (2.0 + 0.5 * etasq) + ecco * (0.5 + 2.0 * etasq) -
             j2 * tsi / (ao * psisq) *
             (-3.0 * rec.con41 * (1.0 - 2.0 * eeta + etasq * (1.5 - 0.5 * eeta)) +
              0.75 * rec.x1mth2 * (2.0 * etasq - eeta * (1.0 + etasq)) * cos(2.0 * rec.argpo)))
        rec.cc5 = 2.0 * coef1 * ao * omeosq * (1.0 + 2.75 * (etasq + eeta) + eeta * etasq)

        let cosio4 = cosio2 * cosio2
        let temp1 = 1.5 * j2 * pinvsq * noUnkozai
        let temp2 = 0.5 * temp1 * j2 * pinvsq
        let temp3 = -0.46875 * j4 * pinvsq * pinvsq * noUnkozai
        rec.mdot = noUnkozai + 0.5 * temp1 * rteosq * rec.con41 +
            0.0625 * temp2 * rteosq * (13.0 - 78.0 * cosio2 + 137.0 * cosio4)
        rec.argpdot = -0.5 * temp1 * con42 +
            0.0625 * temp2 * (7.0 - 114.0 * cosio2 + 395.0 * cosio4) +
            temp3 * (3.0 - 36.0 * cosio2 + 49.0 * cosio4)
        let xhdot1 = -temp1 * cosio
        rec.nodedot = xhdot1 + (0.5 * temp2 * (4.0 - 19.0 * cosio2) +
                                2.0 * temp3 * (3.0 - 7.0 * cosio2)) * cosio
        rec.omgcof = rec.bstar * cc3 * cos(rec.argpo)
        rec.xmcof = 0.0
        if ecco > 1.0e-4 {
            rec.xmcof = -x2o3 * coef * rec.bstar / eeta
        }
        rec.nodecf = 3.5 * omeosq * xhdot1 * rec.cc1
        rec.t2cof = 1.5 * rec.cc1
        if abs(cosio + 1.0) > 1.5e-12 {
            rec.xlcof = -0.25 * j3oj2 * sinio * (3.0 + 5.0 * cosio) / (1.0 + cosio)
        } else {
            rec.xlcof = -0.25 * j3oj2 * sinio * (3.0 + 5.0 * cosio) / temp4
        }
        rec.aycof = -0.5 * j3oj2 * sinio
        rec.delmo = pow(1.0 + rec.eta * cos(rec.mo), 3)
        rec.sinmao = sin(rec.mo)
        rec.x7thm1 = 7.0 * cosio2 - 1.0

        if !rec.isimp {
            let cc1sq = rec.cc1 * rec.cc1
            rec.d2 = 4.0 * ao * tsi * cc1sq
            let temp = rec.d2 * tsi * rec.cc1 / 3.0
            rec.d3 = (17.0 * ao + sfour) * temp
            rec.d4 = 0.5 * temp * ao * tsi * (221.0 * ao + 31.0 * sfour) * rec.cc1
            rec.t3cof = rec.d2 + 2.0 * cc1sq
            rec.t4cof = 0.25 * (3.0 * rec.d3 + rec.cc1 * (12.0 * rec.d2 + 10.0 * cc1sq))
            rec.t5cof = 0.2 * (3.0 * rec.d4 + 12.0 * rec.cc1 * rec.d3 +
                               6.0 * rec.d2 * rec.d2 + 15.0 * cc1sq * (2.0 * rec.d2 + cc1sq))
        }

        return sgp4(rec, 0.0) != nil
    }

    // MARK: - Propagation

    /// Position (ECI/TEME, km) zum Zeitpunkt tsince Minuten nach der TLE-Epoche.
    static func sgp4(_ rec: Satrec, _ tsince: Double) -> ECIPosition? {
        let t = tsince
        let xmdf = rec.mo + rec.mdot * t
        let argpdf = rec.argpo + rec.argpdot * t
        let nodedf = rec.nodeo + rec.nodedot * t
        var argpm = argpdf
        var mm = xmdf
        let t2 = t * t
        var nodem = nodedf + rec.nodecf * t2
        var tempa = 1.0 - rec.cc1 * t
        var tempe = rec.bstar * rec.cc4 * t
        var templ = rec.t2cof * t2

        if !rec.isimp {
            let delomg = rec.omgcof * t
            let delmtemp = 1.0 + rec.eta * cos(xmdf)
            let delm = rec.xmcof * (delmtemp * delmtemp * delmtemp - rec.delmo)
            let temp = delomg + delm
            mm = xmdf + temp
            argpm = argpdf - temp
            let t3 = t2 * t
            let t4 = t3 * t
            tempa -= rec.d2 * t2 + rec.d3 * t3 + rec.d4 * t4
            tempe += rec.bstar * rec.cc5 * (sin(mm) - rec.sinmao)
            templ += rec.t3cof * t3 + t4 * (rec.t4cof + t * rec.t5cof)
        }

        var nm = rec.no
        var em = rec.ecco
        let inclm = rec.inclo
        guard nm > 0 else { rec.error = 2; return nil }

        let am = pow(xke / nm, x2o3) * tempa * tempa
        nm = xke / pow(am, 1.5)
        em -= tempe
        if em >= 1.0 || em < -0.001 { rec.error = 1; return nil }
        if em < 1.0e-6 { em = 1.0e-6 }
        mm += rec.no * templ
        var xlm = mm + argpm + nodem

        nodem = nodem.truncatingRemainder(dividingBy: twoPi)
        argpm = argpm.truncatingRemainder(dividingBy: twoPi)
        xlm = xlm.truncatingRemainder(dividingBy: twoPi)
        mm = (xlm - argpm - nodem).truncatingRemainder(dividingBy: twoPi)

        let sinim = sin(inclm)
        let cosim = cos(inclm)

        let ep = em
        let xincp = inclm
        let argpp = argpm
        let nodep = nodem
        let mp = mm
        let sinip = sinim
        let cosip = cosim

        let axnl = ep * cos(argpp)
        var temp = 1.0 / (am * (1.0 - ep * ep))
        let aynl = ep * sin(argpp) + temp * rec.aycof
        let xl = mp + argpp + nodep + temp * rec.xlcof * axnl

        // Kepler-Gleichung
        let u = (xl - nodep).truncatingRemainder(dividingBy: twoPi)
        var eo1 = u
        var tem5 = 9999.9
        var ktr = 1
        var sineo1 = 0.0
        var coseo1 = 0.0
        while abs(tem5) >= 1.0e-12 && ktr <= 10 {
            sineo1 = sin(eo1)
            coseo1 = cos(eo1)
            tem5 = 1.0 - coseo1 * axnl - sineo1 * aynl
            tem5 = (u - aynl * coseo1 + axnl * sineo1 - eo1) / tem5
            if abs(tem5) >= 0.95 {
                tem5 = tem5 > 0 ? 0.95 : -0.95
            }
            eo1 += tem5
            ktr += 1
        }

        let ecose = axnl * coseo1 + aynl * sineo1
        let esine = axnl * sineo1 - aynl * coseo1
        let el2 = axnl * axnl + aynl * aynl
        let pl = am * (1.0 - el2)
        guard pl >= 0 else { rec.error = 4; return nil }

        let rl = am * (1.0 - ecose)
        let betal = (1.0 - el2).squareRoot()
        temp = esine / (1.0 + betal)
        let sinu = am / rl * (sineo1 - aynl - axnl * temp)
        let cosu = am / rl * (coseo1 - axnl + aynl * temp)
        var su = atan2(sinu, cosu)
        let sin2u = (cosu + cosu) * sinu
        let cos2u = 1.0 - 2.0 * sinu * sinu
        temp = 1.0 / pl
        let temp1 = 0.5 * j2 * temp
        let temp2 = temp1 * temp

        let mrt = rl * (1.0 - 1.5 * temp2 * betal * rec.con41) +
            0.5 * temp1 * rec.x1mth2 * cos2u
        su -= 0.25 * temp2 * rec.x7thm1 * sin2u
        let xnode = nodep + 1.5 * temp2 * cosip * sin2u
        let xinc = xincp + 1.5 * temp2 * cosip * sinip * cos2u

        // Bahnlage → ECI-Vektor
        let sinsu = sin(su)
        let cossu = cos(su)
        let snod = sin(xnode)
        let cnod = cos(xnode)
        let sini = sin(xinc)
        let cosi = cos(xinc)
        let xmx = -snod * cosi
        let xmy = cnod * cosi
        let ux = xmx * sinsu + cnod * cossu
        let uy = xmy * sinsu + snod * cossu
        let uz = sini * sinsu

        guard mrt >= 1.0 else { rec.error = 6; return nil } // Satellit ist verglüht

        return ECIPosition(
            x: mrt * ux * earthRadiusKm,
            y: mrt * uy * earthRadiusKm,
            z: mrt * uz * earthRadiusKm
        )
    }

    /// Propagation zu einem konkreten Zeitpunkt.
    static func propagate(_ rec: Satrec, date: Date) -> ECIPosition? {
        let jd = julianDate(date)
        let tsince = (jd - rec.jdsatepoch) * 1440.0
        return sgp4(rec, tsince)
    }

    // MARK: - Koordinaten-Hilfsfunktionen

    static func julianDate(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86400.0 + 2440587.5
    }

    /// Greenwich Mean Sidereal Time (rad)
    static func gstime(_ jdut1: Double) -> Double {
        let tut1 = (jdut1 - 2451545.0) / 36525.0
        var temp = -6.2e-6 * tut1 * tut1 * tut1 +
            0.093104 * tut1 * tut1 +
            (876600.0 * 3600.0 + 8640184.812866) * tut1 + 67310.54841
        temp = (temp * deg2rad / 240.0).truncatingRemainder(dividingBy: twoPi)
        if temp < 0 { temp += twoPi }
        return temp
    }

    static func eciToEcf(_ eci: ECIPosition, gmst: Double) -> ECIPosition {
        ECIPosition(
            x: eci.x * cos(gmst) + eci.y * sin(gmst),
            y: -eci.x * sin(gmst) + eci.y * cos(gmst),
            z: eci.z
        )
    }

    static func geodeticToEcf(_ observer: GeodeticObserver) -> ECIPosition {
        let a = 6378.137
        let b = 6356.7523142
        let f = (a - b) / a
        let e2 = 2 * f - f * f
        let lat = observer.latitude
        let lon = observer.longitude
        let normal = a / (1 - e2 * sin(lat) * sin(lat)).squareRoot()
        return ECIPosition(
            x: (normal + observer.height) * cos(lat) * cos(lon),
            y: (normal + observer.height) * cos(lat) * sin(lon),
            z: (normal * (1 - e2) + observer.height) * sin(lat)
        )
    }

    static func ecfToLookAngles(observer: GeodeticObserver, satelliteEcf: ECIPosition) -> LookAngles {
        let obsEcf = geodeticToEcf(observer)
        let lat = observer.latitude
        let lon = observer.longitude
        let rx = satelliteEcf.x - obsEcf.x
        let ry = satelliteEcf.y - obsEcf.y
        let rz = satelliteEcf.z - obsEcf.z

        let topS = sin(lat) * cos(lon) * rx + sin(lat) * sin(lon) * ry - cos(lat) * rz
        let topE = -sin(lon) * rx + cos(lon) * ry
        let topZ = cos(lat) * cos(lon) * rx + cos(lat) * sin(lon) * ry + sin(lat) * rz

        let rangeSat = (topS * topS + topE * topE + topZ * topZ).squareRoot()
        let el = asin(topZ / rangeSat)
        var az = atan2(-topE, topS) + .pi
        if az < 0 { az += twoPi }
        return LookAngles(azimuth: az, elevation: el, rangeSat: rangeSat)
    }
}
