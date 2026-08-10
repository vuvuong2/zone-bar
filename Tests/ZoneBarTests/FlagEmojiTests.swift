import Foundation
import ZoneBarCore

let flagEmojiTests: [TestCase] = [
    TestCase(name: "flag for country code") {
        expectEqual(FlagEmoji.flag(forCountryCode: "SE"), "🇸🇪")
        expectEqual(FlagEmoji.flag(forCountryCode: "US"), "🇺🇸")
        expectEqual(FlagEmoji.flag(forCountryCode: "JP"), "🇯🇵")
    },

    TestCase(name: "country code is case insensitive") {
        expectEqual(FlagEmoji.flag(forCountryCode: "se"), "🇸🇪")
    },

    TestCase(name: "invalid country codes return nil") {
        expectNil(FlagEmoji.flag(forCountryCode: ""))
        expectNil(FlagEmoji.flag(forCountryCode: "S"))
        expectNil(FlagEmoji.flag(forCountryCode: "SWE"))
        expectNil(FlagEmoji.flag(forCountryCode: "12"))
        expectNil(FlagEmoji.flag(forCountryCode: "S1"))
    },

    TestCase(name: "flag is two regional indicators rendering as one grapheme") {
        let flag = FlagEmoji.flag(forCountryCode: "SE")
        expectEqual(flag?.unicodeScalars.count, 2)
        expectEqual(flag?.count, 1, "should render as a single grapheme cluster")
    },

    TestCase(name: "flag for time zone identifier") {
        expectEqual(FlagEmoji.flag(forTZIdentifier: "Europe/Stockholm"), "🇸🇪")
        expectEqual(FlagEmoji.flag(forTZIdentifier: "Asia/Tokyo"), "🇯🇵")
        expectEqual(FlagEmoji.flag(forTZIdentifier: "America/New_York"), "🇺🇸")
        expectEqual(FlagEmoji.flag(forTZIdentifier: "UTC"), FlagEmoji.fallback)
    },

    TestCase(name: "unknown time zone falls back to globe") {
        expectEqual(FlagEmoji.flag(forTZIdentifier: "Not/AZone"), "🌐")
        expectEqual(FlagEmoji.flag(forTZIdentifier: "GMT"), "🌐")
    },

    TestCase(name: "every generated country code produces a flag") {
        for (zone, code) in tzIdentifierToCountryCode {
            expectNotNil(FlagEmoji.flag(forCountryCode: code), "no flag for \(code) (zone \(zone))")
        }
    },
]
