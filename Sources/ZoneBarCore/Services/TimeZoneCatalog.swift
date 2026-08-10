import Foundation

/// Lookups over the IANA time zone database: country, region and display names.
public enum TimeZoneCatalog {
    /// Every selectable zone, sorted. Uses the tz database shipped with the OS.
    public static let allIdentifiers: [String] = TimeZone.knownTimeZoneIdentifiers.sorted()

    public static func countryCode(for identifier: String) -> String? {
        tzIdentifierToCountryCode[identifier]
    }

    public static func countryName(for identifier: String) -> String? {
        guard let code = countryCode(for: identifier) else { return nil }
        return countryCodeToName[code]
    }

    /// Human-readable region used for grouping, derived from the zone prefix.
    public static func region(for identifier: String) -> String {
        guard let prefix = identifier.split(separator: "/").first.map(String.init),
            identifier.contains("/")
        else {
            return "Other"
        }

        switch prefix {
        case "America": return "Americas"
        case "Europe": return "Europe"
        case "Asia": return "Asia"
        case "Africa": return "Africa"
        case "Australia", "Pacific": return "Oceania"
        default: return "Other"
        }
    }

    /// Stable display order for region section headers.
    public static let regionOrder = ["Americas", "Europe", "Africa", "Asia", "Oceania", "Other"]

    public static func regionSortIndex(_ region: String) -> Int {
        regionOrder.firstIndex(of: region) ?? regionOrder.count
    }

    /// City portion of the identifier, with separators turned back into spaces.
    /// "America/Argentina/Buenos_Aires" -> "Buenos Aires"
    public static func cityName(for identifier: String) -> String {
        guard let last = identifier.split(separator: "/").last else { return identifier }
        return last.replacingOccurrences(of: "_", with: " ")
    }

    /// Label for pickers: "Stockholm — Sweden", falling back to the raw zone.
    public static func searchLabel(for identifier: String) -> String {
        let city = cityName(for: identifier)
        if let country = countryName(for: identifier) {
            return "\(city) — \(country)"
        }
        return city
    }

    /// Case-insensitive match over city, country and raw identifier.
    public static func search(_ query: String, in identifiers: [String] = allIdentifiers)
        -> [String]
    {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return identifiers }
        let needle = trimmed.lowercased()

        return identifiers.filter { identifier in
            if identifier.lowercased().contains(needle) { return true }
            if cityName(for: identifier).lowercased().contains(needle) { return true }
            if let country = countryName(for: identifier)?.lowercased(),
                country.contains(needle)
            {
                return true
            }
            return false
        }
    }

    /// Current UTC offset rendered as "UTC+02:00" (or "UTC" when zero).
    public static func utcOffsetDescription(for timeZone: TimeZone, at date: Date) -> String {
        let seconds = timeZone.secondsFromGMT(for: date)
        if seconds == 0 { return "UTC" }

        let sign = seconds < 0 ? "-" : "+"
        let magnitude = abs(seconds)
        let hours = magnitude / 3600
        let minutes = (magnitude % 3600) / 60
        return String(format: "UTC%@%02d:%02d", sign, hours, minutes)
    }
}
