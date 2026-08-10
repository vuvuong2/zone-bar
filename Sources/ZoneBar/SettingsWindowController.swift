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
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
    }

    func show() {
        // An accessory app is not active by default, so ask for focus
        // explicitly or the window opens behind everything — and worse, opens
        // without key status, which costs the user their first click.
        //
        // Deferred one hop: `show()` runs from a status-menu action while
        // AppKit is still tearing down the menu tracking session, and
        // activation requests made during tracking get dropped.
        DispatchQueue.main.async { [window] in
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
        }
    }
}
