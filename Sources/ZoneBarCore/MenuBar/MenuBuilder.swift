import Foundation

/// One row in the dropdown. The AppKit layer turns these into `NSMenuItem`s.
public enum MenuRow: Equatable {
    /// Disabled region header, only produced in `.grouped` mode.
    case sectionHeader(String)
    /// A clock: flag, label, time, day offset and UTC offset.
    case clock(ClockRow)
    case separator

    public struct ClockRow: Equatable {
        public let clockID: UUID
        public let flag: String
        public let label: String
        public let time: String
        /// "+1d", "-1d" or "" when the day matches the primary clock.
        public let dayOffset: String
        /// e.g. "UTC+02:00". Always populated — the row's tooltip shows it
        /// whatever `offsetDetail` ends up being.
        public let utcOffset: String
        /// Offset text the user asked for, per `Preferences.offsetDisplay`:
        /// the UTC offset, the distance from the machine's zone, or "".
        public let offsetDetail: String
        /// True for the clock shown in the menu bar in grouped mode.
        public let isPrimary: Bool

        public init(
            clockID: UUID, flag: String, label: String, time: String, dayOffset: String,
            utcOffset: String, offsetDetail: String, isPrimary: Bool
        ) {
            self.clockID = clockID
            self.flag = flag
            self.label = label
            self.time = time
            self.dayOffset = dayOffset
            self.utcOffset = utcOffset
            self.offsetDetail = offsetDetail
            self.isPrimary = isPrimary
        }

        /// Single-line rendering used by the menu item title.
        public var displayTitle: String {
            var parts = ["\(flag)  \(label)"]
            parts.append(time)
            if !dayOffset.isEmpty { parts.append("(\(dayOffset))") }
            if !offsetDetail.isEmpty { parts.append(offsetDetail) }
            return parts.joined(separator: "   ")
        }
    }
}

/// Builds the menu-bar title and the dropdown rows. Pure: same inputs always
/// produce the same output, which is what the tests rely on.
public enum MenuBuilder {

    /// Text shown in the menu bar itself.
    ///
    /// - `.flat`: every clock, inline — "🇸🇪 14:30  🇺🇸 08:30"
    /// - `.grouped`: the primary clock only — "🇸🇪 14:30"
    ///
    /// Falls back to a globe when no clocks are configured, so the status item
    /// never becomes an invisible, unclickable strip.
    public static func menuBarTitle(preferences: Preferences, now: Date) -> String {
        let clocks: [Clock]
        switch preferences.displayMode {
        case .flat:
            clocks = preferences.clocks
        case .grouped:
            clocks = preferences.primaryClock.map { [$0] } ?? []
        }

        guard !clocks.isEmpty else { return FlagEmoji.fallback }

        let rendered = clocks.map { clock -> String in
            let time = ClockFormatter.time(
                now, in: clock.timeZone, use24Hour: preferences.use24Hour,
                showSeconds: preferences.showSeconds)
            return preferences.showFlagsInMenuBar ? "\(clock.flag) \(time)" : time
        }
        return rendered.joined(separator: "  ")
    }

    /// Rows for the dropdown, flat or grouped by region per the display mode.
    ///
    /// `localTimeZone` is the machine's own zone, injected so this stays pure
    /// and the tests do not depend on where they are run.
    public static func menuRows(
        preferences: Preferences, now: Date, localTimeZone: TimeZone = .current
    ) -> [MenuRow] {
        guard !preferences.clocks.isEmpty else { return [] }

        let baseline = preferences.primaryClock?.timeZone ?? localTimeZone
        let primaryID = preferences.primaryClock?.id

        func row(for clock: Clock) -> MenuRow {
            let time = ClockFormatter.time(
                now, in: clock.timeZone, use24Hour: preferences.use24Hour,
                showSeconds: preferences.showSeconds)
            let dayOffset =
                preferences.showDayOffset
                ? ClockFormatter.dayOffsetDescription(
                    now, zone: clock.timeZone, relativeTo: baseline)
                : ""
            let utcOffset = TimeZoneCatalog.utcOffsetDescription(for: clock.timeZone, at: now)
            let offsetDetail: String
            switch preferences.offsetDisplay {
            case .none:
                offsetDetail = ""
            case .utc:
                offsetDetail = utcOffset
            case .relative:
                // Against the machine's zone, not `baseline`: this answers "how
                // far is this from me", which the primary clock cannot.
                offsetDetail = ClockFormatter.relativeOffsetDescription(
                    now, zone: clock.timeZone, relativeTo: localTimeZone)
            }
            return .clock(
                MenuRow.ClockRow(
                    clockID: clock.id,
                    flag: clock.flag,
                    label: clock.label,
                    time: time,
                    dayOffset: dayOffset,
                    utcOffset: utcOffset,
                    offsetDetail: offsetDetail,
                    isPrimary: clock.id == primaryID
                ))
        }

        switch preferences.displayMode {
        case .flat:
            // User's own ordering is preserved.
            return preferences.clocks.map(row)

        case .grouped:
            let groups = Dictionary(grouping: preferences.clocks) {
                TimeZoneCatalog.region(for: $0.tzIdentifier)
            }
            let orderedRegions = groups.keys.sorted {
                let left = TimeZoneCatalog.regionSortIndex($0)
                let right = TimeZoneCatalog.regionSortIndex($1)
                return left == right ? $0 < $1 : left < right
            }

            var rows: [MenuRow] = []
            for (index, region) in orderedRegions.enumerated() {
                if index > 0 { rows.append(.separator) }
                rows.append(.sectionHeader(region))
                // Within a region, order by current offset then label so the
                // section reads west-to-east.
                let clocks = (groups[region] ?? []).sorted { left, right in
                    let leftOffset = left.timeZone.secondsFromGMT(for: now)
                    let rightOffset = right.timeZone.secondsFromGMT(for: now)
                    return leftOffset == rightOffset
                        ? left.label < right.label : leftOffset < rightOffset
                }
                rows.append(contentsOf: clocks.map(row))
            }
            return rows
        }
    }
}
