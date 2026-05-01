import Foundation
import CoreLocation

class PrayerCalculator {
    private let coordinate: CLLocationCoordinate2D
    private let timezone: TimeZone
    private let method: CalculationMethod
    private let asrMethod: AsrJuristicMethod

    init(coordinate: CLLocationCoordinate2D, timezone: TimeZone, method: CalculationMethod, asrMethod: AsrJuristicMethod = .standard) {
        self.coordinate = coordinate
        self.timezone = timezone
        self.method = method
        self.asrMethod = asrMethod
    }

    func calculate(for date: Date) throws -> PrayerTimes {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: timezone, from: date)

        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            throw IqamahError.invalidDate("Could not extract date components from \(date)")
        }

        let julianDay = calculateJulianDay(year: year, month: month, day: day)
        let sunDeclination = calculateSunDeclination(julianDay: julianDay)
        let equationOfTime = calculateEquationOfTime(julianDay: julianDay)

        let transitTime = calculateTransitTime(equationOfTime: equationOfTime)
        let sunriseTime = calculateSunriseTime(transitTime: transitTime, sunDeclination: sunDeclination)
        let sunsetTime = calculateSunsetTime(transitTime: transitTime, sunDeclination: sunDeclination)

        let fajrTime = calculateFajrTime(transitTime: transitTime, sunDeclination: sunDeclination)
        let dhuhrTime = transitTime + (1.0 / 60.0) // Add 1 minute as a precaution
        let asrTime = calculateAsrTime(transitTime: transitTime, sunDeclination: sunDeclination)
        let maghribTime = calculateMaghribTime(sunsetTime: sunsetTime, sunDeclination: sunDeclination, transitTime: transitTime)
        let ishaTime = calculateIshaTime(transitTime: transitTime, sunDeclination: sunDeclination, maghribTime: maghribTime)

        return PrayerTimes(
            fajr: timeToDate(fajrTime, date: date),
            sunrise: timeToDate(sunriseTime, date: date),
            dhuhr: timeToDate(dhuhrTime, date: date),
            asr: timeToDate(asrTime, date: date),
            maghrib: timeToDate(maghribTime, date: date),
            isha: timeToDate(ishaTime, date: date),
            date: date
        )
    }

    // MARK: - Julian Day Calculations

    private func calculateJulianDay(year: Int, month: Int, day: Int) -> Double {
        var y = year
        var m = month

        if m <= 2 {
            y -= 1
            m += 12
        }

        let a = Int(Double(y) / 100.0)
        let b = 2 - a + Int(Double(a) / 4.0)

        return Double(Int(365.25 * Double(y + 4716))) + Double(Int(30.6001 * Double(m + 1))) + Double(day) + Double(b) - 1524.5
    }

    // MARK: - Sun Position Calculations

    private func calculateSunDeclination(julianDay: Double) -> Double {
        let t = (julianDay - 2451545.0) / 36525.0
        let l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
        let m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t

        let mRad = m * .pi / 180.0
        let c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(mRad)
            + (0.019993 - 0.000101 * t) * sin(2 * mRad)
            + 0.000289 * sin(3 * mRad)

        let sunLong = l0 + c
        let omega = 125.04 - 1934.136 * t
        let lambda = sunLong - 0.00569 - 0.00478 * sin(omega * .pi / 180.0)

        let obliquity = 23.439 - 0.00000036 * (julianDay - 2451545.0)
        let obliquityRad = obliquity * .pi / 180.0
        let lambdaRad = lambda * .pi / 180.0

        return asin(sin(obliquityRad) * sin(lambdaRad)) * 180.0 / .pi
    }

    private func calculateEquationOfTime(julianDay: Double) -> Double {
        let t = (julianDay - 2451545.0) / 36525.0
        let l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
        let m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t
        let e = 0.016708634 - 0.000042037 * t - 0.0000001267 * t * t

        let l0Rad = l0 * .pi / 180.0
        let mRad = m * .pi / 180.0
        let obliquity = 23.439 - 0.00000036 * (julianDay - 2451545.0)
        let y = tan(obliquity * .pi / 360.0)
        let ySquared = y * y

        let eqTime = ySquared * sin(2 * l0Rad)
            - 2 * e * sin(mRad)
            + 4 * e * ySquared * sin(mRad) * cos(2 * l0Rad)
            - 0.5 * ySquared * ySquared * sin(4 * l0Rad)
            - 1.25 * e * e * sin(2 * mRad)

        return eqTime * 4 * 180.0 / .pi // Convert to minutes
    }

    // MARK: - Prayer Time Calculations

    private func calculateTransitTime(equationOfTime: Double) -> Double {
        let longitudeOffset = coordinate.longitude / 15.0
        let timezoneOffset = Double(timezone.secondsFromGMT()) / 3600.0
        return 12.0 + timezoneOffset - longitudeOffset - equationOfTime / 60.0
    }

    private func calculateSunriseTime(transitTime: Double, sunDeclination: Double) -> Double {
        let hourAngle = calculateHourAngle(angle: 0.833, sunDeclination: sunDeclination)
        return transitTime - hourAngle / 15.0
    }

    private func calculateSunsetTime(transitTime: Double, sunDeclination: Double) -> Double {
        let hourAngle = calculateHourAngle(angle: 0.833, sunDeclination: sunDeclination)
        return transitTime + hourAngle / 15.0
    }

    private func calculateFajrTime(transitTime: Double, sunDeclination: Double) -> Double {
        let hourAngle = calculateHourAngle(angle: method.fajrAngle, sunDeclination: sunDeclination)
        return transitTime - hourAngle / 15.0
    }

    private func calculateAsrTime(transitTime: Double, sunDeclination: Double) -> Double {
        let latitudeRad = coordinate.latitude * .pi / 180.0
        let declinationRad = sunDeclination * .pi / 180.0

        let factor = asrMethod.shadowFactor
        let angle = atan(1.0 / (factor + tan(abs(latitudeRad - declinationRad))))
        let asrAngle = acos(
            (sin(angle) - sin(latitudeRad) * sin(declinationRad)) /
            (cos(latitudeRad) * cos(declinationRad))
        ) * 180.0 / .pi

        return transitTime + asrAngle / 15.0
    }

    private func calculateMaghribTime(sunsetTime: Double, sunDeclination: Double, transitTime: Double) -> Double {
        if let maghribAngle = method.maghribAngle {
            let hourAngle = calculateHourAngle(angle: maghribAngle, sunDeclination: sunDeclination)
            return transitTime + hourAngle / 15.0
        }
        return sunsetTime
    }

    private func calculateIshaTime(transitTime: Double, sunDeclination: Double, maghribTime: Double) -> Double {
        if let interval = method.ishaInterval {
            return maghribTime + Double(interval) / 60.0
        }

        let hourAngle = calculateHourAngle(angle: method.ishaAngle, sunDeclination: sunDeclination)
        return transitTime + hourAngle / 15.0
    }

    private func calculateHourAngle(angle: Double, sunDeclination: Double) -> Double {
        let latitudeRad = coordinate.latitude * .pi / 180.0
        let declinationRad = sunDeclination * .pi / 180.0
        let angleRad = angle * .pi / 180.0

        let cosHourAngle = (-sin(angleRad) - sin(latitudeRad) * sin(declinationRad)) /
                           (cos(latitudeRad) * cos(declinationRad))

        // Clamp value to valid range for acos
        let clampedCos = max(-1, min(1, cosHourAngle))
        return acos(clampedCos) * 180.0 / .pi
    }

    // MARK: - Time Conversion

    private func timeToDate(_ hours: Double, date: Date) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        var components = calendar.dateComponents(in: timezone, from: date)

        let totalMinutes = Int(hours * 60)
        components.hour = totalMinutes / 60
        components.minute = totalMinutes % 60
        components.second = 0

        return calendar.date(from: components) ?? date
    }
}

// MARK: - Hijri Date Conversion

extension Date {
    func hijriDate() -> (day: Int, month: Int, year: Int, monthName: String) {
        let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        let components = hijriCalendar.dateComponents([.day, .month, .year], from: self)

        let monthNames = [
            "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
            "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban",
            "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"
        ]

        let monthName = components.month.map { monthNames[$0 - 1] } ?? ""

        return (
            day: components.day ?? 1,
            month: components.month ?? 1,
            year: components.year ?? 1,
            monthName: monthName
        )
    }

    func formattedGregorianDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: self)
    }

    func formattedHijriDate() -> String {
        let hijri = hijriDate()
        return "\(hijri.day) \(hijri.monthName) \(hijri.year) AH"
    }
}
