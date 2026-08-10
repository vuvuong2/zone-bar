import AppKit
import ZoneBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = PreferencesStore()
    private var statusItemController: StatusItemController?
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar only: no Dock icon, no app menu.
        NSApp.setActivationPolicy(.accessory)

        let controller = StatusItemController(store: store)
        controller.onOpenSettings = { [weak self] in self?.showSettings() }
        statusItemController = controller
    }

    func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(store: store)
        }
        settingsWindowController?.show()
    }
}
