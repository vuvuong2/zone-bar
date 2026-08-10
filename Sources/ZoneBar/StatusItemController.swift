import AppKit
import Combine
import ZoneBarCore

/// Drives the menu bar: keeps the title current and rebuilds the dropdown.
///
/// All rendering decisions live in `MenuBuilder`; this class only applies the
/// result to AppKit objects.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let store: PreferencesStore
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    /// Last title pushed to the button, so we skip redundant redraws.
    private var renderedTitle: String?
    /// True while the dropdown is open, when rows need live updates too.
    private var isMenuOpen = false

    var onOpenSettings: (() -> Void)?

    init(store: PreferencesStore) {
        self.store = store
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.imagePosition = .noImage

        // Preference edits must show up immediately, not on the next tick.
        store.$preferences
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.renderedTitle = nil
                self?.refresh()
            }
            .store(in: &cancellables)

        refresh()
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    private func startTimer() {
        // One second keeps a seconds-enabled clock honest; the work is just
        // string formatting and is skipped when nothing changed.
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        // .common lets the title keep ticking while a menu is tracking.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func refresh() {
        let preferences = store.preferences
        let now = Date()

        let title = MenuBuilder.menuBarTitle(preferences: preferences, now: now)
        if title != renderedTitle {
            renderedTitle = title
            applyTitle(title)
        }

        if isMenuOpen {
            rebuildMenu(preferences: preferences, now: now)
        }
    }

    /// Monospaced digits stop the strip from jittering as the numbers change.
    private func applyTitle(_ title: String) {
        guard let button = statusItem.button else { return }
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: font]
        )
    }

    // MARK: - Menu

    private func rebuildMenu(preferences: Preferences, now: Date) {
        menu.removeAllItems()

        let rows = MenuBuilder.menuRows(preferences: preferences, now: now)
        if rows.isEmpty {
            let empty = NSMenuItem(title: "No clocks yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for row in rows {
                menu.addItem(menuItem(for: row, preferences: preferences, now: now))
            }
        }

        menu.addItem(.separator())

        // Quick access to the one setting users flip most often.
        let modeItem = NSMenuItem(
            title: preferences.displayMode == .flat
                ? "Switch to Grouped" : "Switch to Flat",
            action: #selector(toggleDisplayMode),
            keyEquivalent: "g")
        modeItem.target = self
        menu.addItem(modeItem)

        let settingsItem = NSMenuItem(
            title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit ZoneBar", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func menuItem(for row: MenuRow, preferences: Preferences, now: Date) -> NSMenuItem {
        switch row {
        case .separator:
            return .separator()

        case .sectionHeader(let title):
            // sectionHeader(title:) is the native look, added in macOS 14.
            return NSMenuItem.sectionHeader(title: title)

        case .clock(let clockRow):
            let item = NSMenuItem(
                title: "", action: #selector(copyClockTime(_:)), keyEquivalent: "")
            item.target = self
            item.attributedTitle = attributedClockTitle(clockRow, preferences: preferences, now: now)
            item.state = clockRow.isPrimary ? .on : .off
            // The id travels with the item so the copy action knows its row.
            item.representedObject = clockRow.clockID
            item.toolTip = "\(clockRow.utcOffset) — click to copy"
            return item
        }
    }

    /// Two-line row: name on top, time and date below in secondary colour.
    private func attributedClockTitle(
        _ row: MenuRow.ClockRow, preferences: Preferences, now: Date
    ) -> NSAttributedString {
        let clock = preferences.clocks.first { $0.id == row.clockID }
        let zone = clock?.timeZone ?? .gmt

        let title = NSMutableAttributedString(
            string: "\(row.flag)  \(row.label)",
            attributes: [
                .font: NSFont.menuFont(ofSize: 0)
            ])

        var detail = "\(row.time)"
        if !row.dayOffset.isEmpty { detail += "  \(row.dayOffset)" }
        detail += "  ·  \(ClockFormatter.dayAndDate(now, in: zone))"

        title.append(
            NSAttributedString(
                string: "\n\(detail)",
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(
                        ofSize: NSFont.smallSystemFontSize, weight: .regular),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]))
        return title
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        rebuildMenu(preferences: store.preferences, now: Date())
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }

    // MARK: - Actions

    @objc private func toggleDisplayMode() {
        store.preferences.displayMode = store.preferences.displayMode == .flat ? .grouped : .flat
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    /// Copying the time is the most common reason to reach for one of these rows.
    @objc private func copyClockTime(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
            let clock = store.preferences.clocks.first(where: { $0.id == id })
        else {
            return
        }

        let now = Date()
        let time = ClockFormatter.time(
            now, in: clock.timeZone, use24Hour: store.preferences.use24Hour,
            showSeconds: store.preferences.showSeconds)
        let text = "\(clock.label) \(time) (\(ClockFormatter.dayAndDate(now, in: clock.timeZone)))"

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
