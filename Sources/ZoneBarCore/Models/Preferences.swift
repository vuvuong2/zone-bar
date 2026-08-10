import Foundation

/// Everything the user can configure. Persisted as JSON.
public struct Preferences: Codable, Equatable, Sendable {
    public var clocks: [Clock]
    public var displayMode: DisplayMode
    /// Clock shown in the menu bar when `displayMode == .grouped`.
    public var primaryClockID: UUID?
    public var use24Hour: Bool
    public var showSeconds: Bool
    /// Show each clock's day offset relative to the primary clock (e.g. "+1d").
    public var showDayOffset: Bool
    /// Show flags in the menu-bar strip. Flags always show in the dropdown.
    public var showFlagsInMenuBar: Bool

    public init(
        clocks: [Clock] = [],
        displayMode: DisplayMode = .flat,
        primaryClockID: UUID? = nil,
        use24Hour: Bool = true,
        showSeconds: Bool = false,
        showDayOffset: Bool = true,
        showFlagsInMenuBar: Bool = true
    ) {
        self.clocks = clocks
        self.displayMode = displayMode
        self.primaryClockID = primaryClockID
        self.use24Hour = use24Hour
        self.showSeconds = showSeconds
        self.showDayOffset = showDayOffset
        self.showFlagsInMenuBar = showFlagsInMenuBar
    }

    /// First-run state: a single clock for the machine's own time zone.
    public static func makeDefault(localTZIdentifier: String = TimeZone.current.identifier)
        -> Preferences
    {
        let clock = Clock(tzIdentifier: localTZIdentifier)
        return Preferences(clocks: [clock], displayMode: .flat, primaryClockID: clock.id)
    }

    /// The clock used for the collapsed menu bar and as the day-offset baseline.
    /// Falls back to the first clock when the stored id no longer exists.
    public var primaryClock: Clock? {
        if let primaryClockID, let match = clocks.first(where: { $0.id == primaryClockID }) {
            return match
        }
        return clocks.first
    }

    /// Decoding tolerates older payloads that lack newer keys.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Preferences()
        clocks = try container.decodeIfPresent([Clock].self, forKey: .clocks) ?? defaults.clocks
        displayMode =
            try container.decodeIfPresent(DisplayMode.self, forKey: .displayMode)
            ?? defaults.displayMode
        primaryClockID = try container.decodeIfPresent(UUID.self, forKey: .primaryClockID)
        use24Hour =
            try container.decodeIfPresent(Bool.self, forKey: .use24Hour) ?? defaults.use24Hour
        showSeconds =
            try container.decodeIfPresent(Bool.self, forKey: .showSeconds) ?? defaults.showSeconds
        showDayOffset =
            try container.decodeIfPresent(Bool.self, forKey: .showDayOffset)
            ?? defaults.showDayOffset
        showFlagsInMenuBar =
            try container.decodeIfPresent(Bool.self, forKey: .showFlagsInMenuBar)
            ?? defaults.showFlagsInMenuBar
    }
}
