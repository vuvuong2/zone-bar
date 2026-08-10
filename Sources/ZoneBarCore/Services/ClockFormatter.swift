import Foundation

/// Renders times for a given zone. Formatters are cached because the status
/// item rebuilds its strings every second.
public enum ClockFormatter {
    /// Fixed locale so the pattern we ask for is the pattern we get, regardless
    /// of the user's regional settings.
    private static let formatterLocale = Locale(identifier: "en_US_POSIX")

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cache: [String: DateFormatter] = [:]

    private static func formatter(pattern: String, timeZone: TimeZone) -> DateFormatter {
        let key = "\(pattern)|\(timeZone.identifier)"

        cacheLock.lock()
        defer { cacheLock.unlock() }

        if let cached = cache[key] { return cached }

        let formatter = DateFormatter()
        formatter.locale = formatterLocale
        formatter.dateFormat = pattern
        formatter.timeZone = timeZone
        cache[key] = formatter
        return formatter
    }

    public static func timePattern(use24Hour: Bool, showSeconds: Bool) -> String {
        switch (use24Hour, showSeconds) {
        case (true, false): return "HH:mm"
        case (true, true): return "HH:mm:ss"
        case (false, false): return "h:mm a"
        case (false, true): return "h:mm:ss a"
        }
    }

    /// Just the time, e.g. "14:30" or "2:30 PM".
    public static func time(
        _ date: Date, in timeZone: TimeZone, use24Hour: Bool, showSeconds: Bool
    ) -> String {
        let pattern = timePattern(use24Hour: use24Hour, showSeconds: showSeconds)
        return formatter(pattern: pattern, timeZone: timeZone).string(from: date)
    }

    /// Weekday and date, e.g. "Mon 10 Aug" — used in the dropdown.
    public static func dayAndDate(_ date: Date, in timeZone: TimeZone) -> String {
        formatter(pattern: "EEE d MMM", timeZone: timeZone).string(from: date)
    }

    /// Whole-day difference between two zones at the same instant, as seen on
    /// the calendar. Returns "+1d" / "-1d" / "" (same day).
    public static func dayOffsetDescription(
        _ date: Date, zone: TimeZone, relativeTo baseline: TimeZone
    ) -> String {
        let days = calendarDayDifference(date, zone: zone, relativeTo: baseline)
        guard days != 0 else { return "" }
        return days > 0 ? "+\(days)d" : "\(days)d"
    }

    /// Positive when `zone` is on a later calendar day than `baseline`.
    public static func calendarDayDifference(
        _ date: Date, zone: TimeZone, relativeTo baseline: TimeZone
    ) -> Int {
        var zoneCalendar = Calendar(identifier: .gregorian)
        zoneCalendar.timeZone = zone
        var baselineCalendar = Calendar(identifier: .gregorian)
        baselineCalendar.timeZone = baseline

        let zoneDay = zoneCalendar.dateComponents([.year, .month, .day], from: date)
        let baselineDay = baselineCalendar.dateComponents([.year, .month, .day], from: date)

        // Compare the two calendar dates in a neutral calendar so month and
        // year boundaries are handled for us.
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!
        guard let zoneDate = utcCalendar.date(from: zoneDay),
            let baselineDate = utcCalendar.date(from: baselineDay)
        else {
            return 0
        }
        return utcCalendar.dateComponents([.day], from: baselineDate, to: zoneDate).day ?? 0
    }
}
