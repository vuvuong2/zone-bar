import Foundation
import ZoneBarCore

/// 2024-01-15 12:00:30 UTC — Stockholm 13:00:30, Tokyo 21:00:30, New York 07:00:30.
private let reference = Date(timeIntervalSince1970: 1_705_320_030)

private let stockholm = TimeZone(identifier: "Europe/Stockholm")!
private let tokyo = TimeZone(identifier: "Asia/Tokyo")!
private let newYork = TimeZone(identifier: "America/New_York")!
private let utc = TimeZone(identifier: "UTC")!

let clockFormatterTests: [TestCase] = [
    TestCase(name: "time patterns") {
        expectEqual(ClockFormatter.timePattern(use24Hour: true, showSeconds: false), "HH:mm")
        expectEqual(ClockFormatter.timePattern(use24Hour: true, showSeconds: true), "HH:mm:ss")
        expectEqual(ClockFormatter.timePattern(use24Hour: false, showSeconds: false), "h:mm a")
        expectEqual(ClockFormatter.timePattern(use24Hour: false, showSeconds: true), "h:mm:ss a")
    },

    TestCase(name: "24-hour time") {
        expectEqual(
            ClockFormatter.time(reference, in: stockholm, use24Hour: true, showSeconds: false),
            "13:00")
        expectEqual(
            ClockFormatter.time(reference, in: tokyo, use24Hour: true, showSeconds: false), "21:00")
        expectEqual(
            ClockFormatter.time(reference, in: newYork, use24Hour: true, showSeconds: false),
            "07:00")
    },

    TestCase(name: "12-hour time") {
        expectEqual(
            ClockFormatter.time(reference, in: stockholm, use24Hour: false, showSeconds: false),
            "1:00 PM")
        expectEqual(
            ClockFormatter.time(reference, in: newYork, use24Hour: false, showSeconds: false),
            "7:00 AM")
    },

    TestCase(name: "seconds are included when requested") {
        expectEqual(
            ClockFormatter.time(reference, in: stockholm, use24Hour: true, showSeconds: true),
            "13:00:30")
        expectEqual(
            ClockFormatter.time(reference, in: stockholm, use24Hour: false, showSeconds: true),
            "1:00:30 PM")
    },

    TestCase(name: "formatter cache does not leak across zones") {
        let first = ClockFormatter.time(reference, in: tokyo, use24Hour: true, showSeconds: false)
        let second = ClockFormatter.time(reference, in: tokyo, use24Hour: true, showSeconds: false)
        expectEqual(first, second)
        // Same pattern, different zone must not reuse the previous zone's formatter.
        expectEqual(
            ClockFormatter.time(reference, in: newYork, use24Hour: true, showSeconds: false),
            "07:00")
    },

    TestCase(name: "day and date") {
        expectEqual(ClockFormatter.dayAndDate(reference, in: stockholm), "Mon 15 Jan")
        expectEqual(ClockFormatter.dayAndDate(reference, in: tokyo), "Mon 15 Jan")
    },

    TestCase(name: "day offset is empty within the same day") {
        expectEqual(
            ClockFormatter.dayOffsetDescription(reference, zone: tokyo, relativeTo: stockholm), "")
        expectEqual(
            ClockFormatter.dayOffsetDescription(reference, zone: stockholm, relativeTo: stockholm),
            "")
    },

    TestCase(name: "day offset across the date line") {
        // 2024-01-15 23:00 UTC — Tokyo is already the 16th, New York still the 15th.
        let lateUTC = Date(timeIntervalSince1970: 1_705_359_600)
        expectEqual(
            ClockFormatter.dayOffsetDescription(lateUTC, zone: tokyo, relativeTo: utc), "+1d")
        expectEqual(
            ClockFormatter.dayOffsetDescription(lateUTC, zone: utc, relativeTo: tokyo), "-1d")
        expectEqual(
            ClockFormatter.dayOffsetDescription(lateUTC, zone: newYork, relativeTo: tokyo), "-1d")
    },

    TestCase(name: "day offset across month boundary") {
        // 2024-01-31 23:30 UTC -> Tokyo is 2024-02-01.
        let endOfMonth = Date(timeIntervalSince1970: 1_706_743_800)
        expectEqual(
            ClockFormatter.dayOffsetDescription(endOfMonth, zone: tokyo, relativeTo: utc), "+1d")
        expectEqual(
            ClockFormatter.calendarDayDifference(endOfMonth, zone: tokyo, relativeTo: utc), 1)
    },

    TestCase(name: "day offset across year boundary") {
        // 2023-12-31 23:30 UTC -> Tokyo is 2024-01-01.
        let newYearEve = Date(timeIntervalSince1970: 1_704_065_400)
        expectEqual(
            ClockFormatter.dayOffsetDescription(newYearEve, zone: tokyo, relativeTo: utc), "+1d")
        expectEqual(
            ClockFormatter.calendarDayDifference(newYearEve, zone: tokyo, relativeTo: utc), 1)
    },

    TestCase(name: "day offset can span two days") {
        // Kiritimati is UTC+14 and Niue UTC-11: 25 hours apart, so at the right
        // instant their calendar dates differ by two days.
        let kiritimati = TimeZone(identifier: "Pacific/Kiritimati")!
        let niue = TimeZone(identifier: "Pacific/Niue")!
        let instant = Date(timeIntervalSince1970: 1_705_314_600)  // 2024-01-15 10:30 UTC
        expectEqual(
            ClockFormatter.calendarDayDifference(instant, zone: kiritimati, relativeTo: niue), 2)
        expectEqual(
            ClockFormatter.dayOffsetDescription(instant, zone: kiritimati, relativeTo: niue), "+2d")
    },
]
