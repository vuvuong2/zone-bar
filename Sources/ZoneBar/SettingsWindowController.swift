import AppKit
import SwiftUI
import ZoneBarCore

/// Hosts `SettingsView` in a plain window. Created lazily and kept alive so the
/// window reopens with its previous position.
@MainActor
final class SettingsWindowController {
    private let window: NSWindow

    init(store: PreferencesStore) {
        let hosting = NSHostingController(rootView: SettingsView(store: store))

        window = NSWindow(contentViewController: hosting)
        window.title = "ZoneBar Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
    }

    func show() {
        // An accessory app is not active by default, so ask for focus
        // explicitly or the window opens behind everything.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
