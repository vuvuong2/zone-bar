import Foundation

// Entry point for the test runner: swift run ZoneBarTests
let exitCode = runSuites([
    ("FlagEmoji", flagEmojiTests),
    ("TimeZoneCatalog", timeZoneCatalogTests),
    ("ClockFormatter", clockFormatterTests),
    ("Preferences", preferencesTests),
    ("PreferencesStore", preferencesStoreTests),
    ("MenuBuilder", menuBuilderTests),
])

exit(exitCode)
