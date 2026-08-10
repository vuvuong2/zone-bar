import AppKit
import ZoneBarCore

// Manual bootstrap rather than @main: this is a plain SPM executable, so there
// is no Info.plist driving startup when run straight from .build.
//
// NSApplication stores its delegate weakly, so keep a strong reference here for
// the lifetime of the process.
nonisolated(unsafe) private var appDelegate: AppDelegate?

/// `--print-state` renders what the menu bar would show and exits, without
/// touching the status bar. Useful for checking stored preferences from a
/// terminal, and for verifying the app end to end without a screenshot.
private func printStateAndExit() -> Never {
    let store = PreferencesStore()
    let preferences = store.preferences
    let now = Date()

    print("display mode: \(preferences.displayMode.rawValue)")
    print("menu bar:     \(MenuBuilder.menuBarTitle(preferences: preferences, now: now))")
    print("dropdown:")
    for row in MenuBuilder.menuRows(preferences: preferences, now: now) {
        switch row {
        case .sectionHeader(let title): print("  — \(title) —")
        case .separator: print("  ---")
        case .clock(let clock): print("  \(clock.displayTitle)   \(clock.utcOffset)")
        }
    }
    exit(0)
}

if CommandLine.arguments.contains("--print-state") {
    printStateAndExit()
}

// Top-level code in main.swift already runs on the main thread; this states that
// to the compiler so the main-actor-isolated AppKit calls below are allowed.
MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    appDelegate = delegate
    application.delegate = delegate
    application.run()
}
