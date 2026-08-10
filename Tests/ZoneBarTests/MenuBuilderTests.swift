import Foundation
import ZoneBarCore

/// 2024-01-15 12:00:30 UTC — Stockholm 13:00, Tokyo 21:00, New York 07:00.
private let now = Date(timeIntervalSince1970: 1_705_320_030)

private let stockholm = Clock(tzIdentifier: "Europe/Stockholm")
private let tokyo = Clock(tzIdentifier: "Asia/Tokyo")
private let newYork = Clock(tzIdentifier: "America/New_York")

private func clockRows(_ rows: [MenuRow]) -> [MenuRow.ClockRow] {
    rows.compactMap { if case .clock(let row) = $0 { return row } else { return nil } }
}

private func headers(_ rows: [MenuRow]) -> [String] {
    rows.compactMap { if case .sectionHeader(let title) = $0 { return title } else { return nil } }
}

let menuBuilderTests: [TestCase] = [
    // MARK: Menu bar title

    TestCase(name: "flat mode shows every clock inline") {
        let preferences = Preferences(
            clocks: [stockholm, newYork], displayMode: .flat, primaryClockID: stockholm.id)
        expectEqual(
            MenuBuilder.menuBarTitle(preferences: preferences, now: now), "🇸🇪 13:00  🇺🇸 07:00")
    },

    TestCase(name: "grouped mode shows only the primary clock") {
        let preferences = Preferences(
            clocks: [stockholm, newYork, tokyo], displayMode: .grouped, primaryClockID: newYork.id)
        expectEqual(MenuBuilder.menuBarTitle(preferences: preferences, now: now), "🇺🇸 07:00")
    },

    TestCase(name: "grouped mode falls back to the first clock when primary is stale") {
        let preferences = Preferences(
            clocks: [stockholm, tokyo], displayMode: .grouped, primaryClockID: UUID())
        expectEqual(MenuBuilder.menuBarTitle(preferences: preferences, now: now), "🇸🇪 13:00")
    },

    TestCase(name: "flags can be hidden in the menu bar") {
        let preferences = Preferences(
            clocks: [stockholm, newYork], displayMode: .flat, primaryClockID: stockholm.id,
            showFlagsInMenuBar: false)
        expectEqual(MenuBuilder.menuBarTitle(preferences: preferences, now: now), "13:00  07:00")
    },

    TestCase(name: "title honours 12-hour and seconds") {
        let preferences = Preferences(
            clocks: [stockholm], displayMode: .flat, primaryClockID: stockholm.id,
            use24Hour: false, showSeconds: true)
        expectEqual(MenuBuilder.menuBarTitle(preferences: preferences, now: now), "🇸🇪 1:00:30 PM")
    },

    TestCase(name: "title with no clocks falls back to a globe") {
        // Guards against an invisible, unclickable status item.
        expectEqual(MenuBuilder.menuBarTitle(preferences: Preferences(clocks: []), now: now), "🌐")
        expectEqual(
            MenuBuilder.menuBarTitle(
                preferences: Preferences(clocks: [], displayMode: .grouped), now: now), "🌐")
    },

    // MARK: Dropdown rows

    TestCase(name: "rows are empty without clocks") {
        expectTrue(MenuBuilder.menuRows(preferences: Preferences(clocks: []), now: now).isEmpty)
    },

    TestCase(name: "flat mode produces no headers and preserves user order") {
        let preferences = Preferences(
            clocks: [tokyo, stockholm, newYork], displayMode: .flat, primaryClockID: stockholm.id)
        let rows = MenuBuilder.menuRows(preferences: preferences, now: now)

        expectEqual(rows.count, 3)
        expectTrue(headers(rows).isEmpty, "flat mode must not emit section headers")
        expectFalse(rows.contains(.separator), "flat mode must not emit separators")
        expectEqual(clockRows(rows).map(\.label), ["Tokyo", "Stockholm", "New York"])
    },

    TestCase(name: "flat row contents") {
        let preferences = Preferences(
            clocks: [stockholm], displayMode: .flat, primaryClockID: stockholm.id)
        let rows = clockRows(MenuBuilder.menuRows(preferences: preferences, now: now))
        guard let row = rows.first else { return fail("expected one clock row") }

        expectEqual(row.clockID, stockholm.id)
        expectEqual(row.flag, "🇸🇪")
        expectEqual(row.label, "Stockholm")
        expectEqual(row.time, "13:00")
        expectEqual(row.utcOffset, "UTC+01:00")
        expectEqual(row.dayOffset, "")
        expectTrue(row.isPrimary)
    },

    TestCase(name: "grouped mode emits region headers in canonical order") {
        let preferences = Preferences(
            clocks: [tokyo, stockholm, newYork], displayMode: .grouped,
            primaryClockID: stockholm.id)
        let rows = MenuBuilder.menuRows(preferences: preferences, now: now)
        expectEqual(headers(rows), ["Americas", "Europe", "Asia"])
    },

    TestCase(name: "grouped mode interleaves headers and separators") {
        let preferences = Preferences(
            clocks: [stockholm, newYork], displayMode: .grouped, primaryClockID: stockholm.id)
        let rows = MenuBuilder.menuRows(preferences: preferences, now: now)

        expectEqual(rows.count, 5)
        expectEqual(rows.first, .sectionHeader("Americas"), "no leading separator")
        expectEqual(rows[2], .separator)
        expectEqual(rows[3], .sectionHeader("Europe"))
        expectEqual(clockRows(rows).map(\.label), ["New York", "Stockholm"])
    },

    TestCase(name: "grouped mode sorts within a region by offset then label") {
        let losAngeles = Clock(tzIdentifier: "America/Los_Angeles")  // UTC-08
        let newYorkClock = Clock(tzIdentifier: "America/New_York")  // UTC-05
        let saoPaulo = Clock(tzIdentifier: "America/Sao_Paulo")  // UTC-03
        let preferences = Preferences(
            clocks: [saoPaulo, newYorkClock, losAngeles], displayMode: .grouped,
            primaryClockID: newYorkClock.id)

        let rows = MenuBuilder.menuRows(preferences: preferences, now: now)
        expectEqual(
            clockRows(rows).map(\.label), ["Los Angeles", "New York", "Sao Paulo"],
            "west to east regardless of insertion order")
    },

    TestCase(name: "grouped mode sorts zones sharing an offset by label") {
        let stockholmClock = Clock(tzIdentifier: "Europe/Stockholm")  // UTC+01
        let amsterdam = Clock(tzIdentifier: "Europe/Amsterdam")  // UTC+01
        let preferences = Preferences(
            clocks: [stockholmClock, amsterdam], displayMode: .grouped,
            primaryClockID: stockholmClock.id)

        let rows = MenuBuilder.menuRows(preferences: preferences, now: now)
        expectEqual(clockRows(rows).map(\.label), ["Amsterdam", "Stockholm"])
    },

    TestCase(name: "Australia and Pacific share one Oceania section") {
        let sydney = Clock(tzIdentifier: "Australia/Sydney")
        let auckland = Clock(tzIdentifier: "Pacific/Auckland")
        let preferences = Preferences(
            clocks: [sydney, auckland], displayMode: .grouped, primaryClockID: sydney.id)

        let rows = MenuBuilder.menuRows(preferences: preferences, now: now)
        expectEqual(headers(rows), ["Oceania"])
        expectEqual(clockRows(rows).count, 2)
    },

    TestCase(name: "Other region sorts last") {
        let utcClock = Clock(tzIdentifier: "UTC")
        let preferences = Preferences(
            clocks: [utcClock, stockholm], displayMode: .grouped, primaryClockID: stockholm.id)
        expectEqual(headers(MenuBuilder.menuRows(preferences: preferences, now: now)), ["Europe", "Other"])
    },

    // MARK: Day offset

    TestCase(name: "day offset is relative to the primary clock") {
        // 2024-01-15 23:00 UTC: Tokyo is already the 16th, New York still the 15th.
        let lateUTC = Date(timeIntervalSince1970: 1_705_359_600)
        let preferences = Preferences(
            clocks: [newYork, tokyo], displayMode: .flat, primaryClockID: newYork.id)

        let rows = clockRows(MenuBuilder.menuRows(preferences: preferences, now: lateUTC))
        expectEqual(rows.count, 2)
        expectEqual(rows[0].dayOffset, "", "the primary clock is its own baseline")
        expectEqual(rows[1].dayOffset, "+1d")
    },

    TestCase(name: "day offset can be turned off") {
        let lateUTC = Date(timeIntervalSince1970: 1_705_359_600)
        let preferences = Preferences(
            clocks: [newYork, tokyo], displayMode: .flat, primaryClockID: newYork.id,
            showDayOffset: false)
        let rows = clockRows(MenuBuilder.menuRows(preferences: preferences, now: lateUTC))
        expectTrue(rows.allSatisfy { $0.dayOffset.isEmpty })
    },

    TestCase(name: "isPrimary marks exactly one row") {
        let preferences = Preferences(
            clocks: [stockholm, tokyo, newYork], displayMode: .grouped, primaryClockID: tokyo.id)
        let rows = clockRows(MenuBuilder.menuRows(preferences: preferences, now: now))
        expectEqual(rows.filter(\.isPrimary).count, 1)
        expectEqual(rows.first(where: \.isPrimary)?.label, "Tokyo")
    },

    // MARK: Row rendering

    TestCase(name: "display title includes the day offset only when present") {
        let plain = MenuRow.ClockRow(
            clockID: UUID(), flag: "🇸🇪", label: "Stockholm", time: "13:00", dayOffset: "",
            utcOffset: "UTC+01:00", isPrimary: true)
        expectEqual(plain.displayTitle, "🇸🇪  Stockholm   13:00")

        let shifted = MenuRow.ClockRow(
            clockID: UUID(), flag: "🇯🇵", label: "Tokyo", time: "07:00", dayOffset: "+1d",
            utcOffset: "UTC+09:00", isPrimary: false)
        expectEqual(shifted.displayTitle, "🇯🇵  Tokyo   07:00   (+1d)")
    },

    TestCase(name: "custom labels flow through to rows") {
        let labelled = Clock(tzIdentifier: "Asia/Tokyo", customLabel: "HQ")
        let preferences = Preferences(
            clocks: [labelled], displayMode: .flat, primaryClockID: labelled.id)
        expectEqual(clockRows(MenuBuilder.menuRows(preferences: preferences, now: now)).first?.label, "HQ")
    },

    // MARK: Determinism

    TestCase(name: "building is pure") {
        let preferences = Preferences(
            clocks: [stockholm, tokyo, newYork], displayMode: .grouped,
            primaryClockID: stockholm.id)
        // The status item relies on this to skip redundant redraws.
        expectEqual(
            MenuBuilder.menuRows(preferences: preferences, now: now),
            MenuBuilder.menuRows(preferences: preferences, now: now))
        expectEqual(
            MenuBuilder.menuBarTitle(preferences: preferences, now: now),
            MenuBuilder.menuBarTitle(preferences: preferences, now: now))
    },
]
