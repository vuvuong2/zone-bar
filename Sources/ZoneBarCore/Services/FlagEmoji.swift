import Foundation

/// Turns ISO 3166 alpha-2 country codes into Unicode flag emoji.
public enum FlagEmoji {
    /// Shown for zones with no country (UTC, GMT) or an unmappable code.
    public static let fallback = "🌐"

    private static let regionalIndicatorA: UInt32 = 0x1F1E6
    private static let asciiA: UInt32 = 65  // "A"

    /// Composes the two regional indicator symbols for a country code.
    /// Returns `nil` for anything that is not two ASCII letters.
    public static func flag(forCountryCode code: String) -> String? {
        let letters = code.uppercased().unicodeScalars
        guard letters.count == 2 else { return nil }

        var result = ""
        for letter in letters {
            guard letter.value >= asciiA, letter.value <= asciiA + 25 else { return nil }
            let indicator = regionalIndicatorA + (letter.value - asciiA)
            guard let scalar = Unicode.Scalar(indicator) else { return nil }
            result.unicodeScalars.append(scalar)
        }
        return result
    }

    /// Flag for a time zone, or `fallback` when the zone has no country.
    public static func flag(forTZIdentifier identifier: String) -> String {
        guard let code = TimeZoneCatalog.countryCode(for: identifier),
            let flag = flag(forCountryCode: code)
        else {
            return fallback
        }
        return flag
    }
}
