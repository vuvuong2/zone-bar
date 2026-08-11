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

    /// Last title *and appearance* pushed to the button, so we skip redundant
    /// redraws but still re-render when the menu bar flips light/dark.
    private var renderedKey: String?
    /// True while the dropdown is open, when rows need live updates too.
    private var isMenuOpen = false

    var onOpenSettings: (() -> Void)?

    init(store: PreferencesStore) {
        self.store = store
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        menu.delegate = self
        statusItem.menu = menu
        statusItem.button?.imagePosition = .imageOnly

        // Preference edits must show up immediately, not on the next tick.
        store.$preferences
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.renderedKey = nil
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
        // The appearance joins the key so a light/dark flip repaints the strip
        // even when the clocks read the same as they did a second ago.
        let appearance = statusItem.button?.effectiveAppearance ?? NSApp.effectiveAppearance
        let key = "\(appearance.name.rawValue)\u{1F}\(title)"
        if key != renderedKey {
            renderedKey = key
            applyTitle(title, appearance: appearance)
        }

        if isMenuOpen {
            rebuildMenu(preferences: preferences, now: now)
        }
    }

    /// Draws the strip into an image rather than setting the button's title.
    ///
    /// macOS dims a status item's *text title* on the menu bar of whichever
    /// display is not active, but leaves images at full strength — which is why
    /// a plain title greys out over there while every neighbouring item stays
    /// bright. Drawing the same string into an image sidesteps that.
    ///
    /// The image is deliberately *not* a template: a template is only a mask, so
    /// it would flatten the flag emoji into grey silhouettes. That means the
    /// system will not tint the text either, so the colour is resolved from the
    /// button's own appearance, which reports the menu bar's true light/dark
    /// state on each display.
    ///
    /// Monospaced digits stop the strip from jittering as the numbers change.
    private func applyTitle(_ title: String, appearance: NSAppearance) {
        guard let button = statusItem.button else { return }

        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let measured = NSAttributedString(string: title, attributes: [.font: font])
        let textSize = measured.size()
        let size = NSSize(width: ceil(textSize.width), height: NSStatusBar.system.thickness)

        let image = NSImage(size: size, flipped: false) { rect in
            // Resolving labelColor inside the appearance keeps the strip white on
            // a dark menu bar and black on a light one.
            appearance.performAsCurrentDrawingAppearance {
                let drawn = NSAttributedString(
                    string: title,
                    attributes: [.font: font, .foregroundColor: NSColor.labelColor])
                drawn.draw(at: NSPoint(x: 0, y: (rect.height - textSize.height) / 2))
            }
            return true
        }
        image.isTemplate = false
        // The button carries no title now, so VoiceOver reads this instead.
        image.accessibilityDescription = title

        button.image = image
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
                .font: NSFont.menuFont(ofSize: 0),
                // Without this the line paints black instead of following the
                // menu appearance and the row highlight.
                .foregroundColor: NSColor.labelColor,
            ])

        var detail = "\(row.time)"
        if !row.dayOffset.isEmpty { detail += "  \(row.dayOffset)" }
        if !row.offsetDetail.isEmpty { detail += "  \(row.offsetDetail)" }
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
