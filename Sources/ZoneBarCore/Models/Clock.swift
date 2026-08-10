import Foundation

/// One time zone the user has chosen to display.
public struct Clock: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    /// IANA time zone identifier, e.g. "Europe/Stockholm".
    public var tzIdentifier: String
    /// Overrides the auto-derived city label when set.
    public var customLabel: String?

    public init(id: UUID = UUID(), tzIdentifier: String, customLabel: String? = nil) {
        self.id = id
        self.tzIdentifier = tzIdentifier
        self.customLabel = customLabel
    }

    /// The resolved time zone, falling back to GMT if the identifier is not
    /// recognised (for example a zone dropped by a tz database update).
    public var timeZone: TimeZone {
        TimeZone(identifier: tzIdentifier) ?? .gmt
    }

    /// Label shown next to the time: the custom label if set, else the city name.
    public var label: String {
        if let customLabel, !customLabel.trimmingCharacters(in: .whitespaces).isEmpty {
            return customLabel
        }
        return TimeZoneCatalog.cityName(for: tzIdentifier)
    }

    public var flag: String {
        FlagEmoji.flag(forTZIdentifier: tzIdentifier)
    }
}
