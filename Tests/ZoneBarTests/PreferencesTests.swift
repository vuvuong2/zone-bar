import Foundation
import ZoneBarCore

let preferencesTests: [TestCase] = [
    TestCase(name: "codable round trip") {
        let stockholm = Clock(tzIdentifier: "Europe/Stockholm")
        let tokyo = Clock(tzIdentifier: "Asia/Tokyo", customLabel: "HQ")
        let original = Preferences(
            clocks: [stockholm, tokyo],
            displayMode: .grouped,
            primaryClockID: tokyo.id,
            use24Hour: false,
            showSeconds: true,
            showDayOffset: false,
            showFlagsInMenuBar: false
        )

        do {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(Preferences.self, from: data)
            expectEqual(decoded, original)
            expectEqual(decoded.clocks.map(\.tzIdentifier), ["Europe/Stockholm", "Asia/Tokyo"])
            expectEqual(decoded.clocks[1].customLabel, "HQ")
            expectEqual(decoded.primaryClockID, tokyo.id)
        } catch {
            fail("round trip threw: \(error)")
        }
    },

    TestCase(name: "decoding tolerates missing keys") {
        // A payload written by an older build: only clocks present.
        let json = """
            {"clocks":[{"id":"E621E1F8-C36C-495A-93FC-0C247A3E6E5F","tzIdentifier":"Asia/Tokyo"}]}
            """
        do {
            let decoded = try JSONDecoder().decode(Preferences.self, from: Data(json.utf8))
            expectEqual(decoded.clocks.count, 1)
            expectEqual(decoded.displayMode, .flat)
            expectTrue(decoded.use24Hour)
            expectFalse(decoded.showSeconds)
            expectTrue(decoded.showDayOffset)
            expectTrue(decoded.showFlagsInMenuBar)
            expectNil(decoded.primaryClockID)
        } catch {
            fail("decoding threw: \(error)")
        }
    },

    TestCase(name: "decoding an empty object yields defaults") {
        do {
            let decoded = try JSONDecoder().decode(Preferences.self, from: Data("{}".utf8))
            expectEqual(decoded, Preferences())
            expectTrue(decoded.clocks.isEmpty)
        } catch {
            fail("decoding threw: \(error)")
        }
    },

    TestCase(name: "makeDefault uses the local zone as primary") {
        let preferences = Preferences.makeDefault(localTZIdentifier: "Europe/Stockholm")
        expectEqual(preferences.clocks.count, 1)
        expectEqual(preferences.clocks[0].tzIdentifier, "Europe/Stockholm")
        expectEqual(preferences.displayMode, .flat)
        expectEqual(preferences.primaryClockID, preferences.clocks[0].id)
        expectEqual(preferences.primaryClock?.tzIdentifier, "Europe/Stockholm")
    },

    TestCase(name: "primary clock falls back to first when the id is stale") {
        let stockholm = Clock(tzIdentifier: "Europe/Stockholm")
        let preferences = Preferences(clocks: [stockholm], primaryClockID: UUID())
        expectEqual(preferences.primaryClock?.id, stockholm.id)
    },

    TestCase(name: "primary clock is nil without clocks") {
        expectNil(Preferences(clocks: []).primaryClock)
    },

    TestCase(name: "clock label prefers a custom label") {
        expectEqual(Clock(tzIdentifier: "Europe/Stockholm").label, "Stockholm")
        expectEqual(Clock(tzIdentifier: "Europe/Stockholm", customLabel: "Home").label, "Home")
        // A blank custom label must not blank out the row.
        expectEqual(Clock(tzIdentifier: "Europe/Stockholm", customLabel: "   ").label, "Stockholm")
        expectEqual(Clock(tzIdentifier: "Europe/Stockholm", customLabel: "").label, "Stockholm")
    },

    TestCase(name: "clock resolves its time zone and falls back to zero offset") {
        expectEqual(Clock(tzIdentifier: "Asia/Tokyo").timeZone.identifier, "Asia/Tokyo")
        // An unrecognised zone must still yield a usable zone at UTC+00:00.
        // Foundation normalises the "UTC" identifier to "GMT", so assert the
        // offset rather than the name.
        expectEqual(Clock(tzIdentifier: "Bogus/Zone").timeZone.secondsFromGMT(for: Date()), 0)
    },

    TestCase(name: "clock flag") {
        expectEqual(Clock(tzIdentifier: "Europe/Stockholm").flag, "🇸🇪")
        expectEqual(Clock(tzIdentifier: "UTC").flag, "🌐")
    },

    TestCase(name: "display mode raw values are stable") {
        // These are persisted, so they must not drift.
        expectEqual(DisplayMode.flat.rawValue, "flat")
        expectEqual(DisplayMode.grouped.rawValue, "grouped")
        expectEqual(DisplayMode.allCases.count, 2)
    },
]
