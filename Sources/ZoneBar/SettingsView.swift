import AppKit
import SwiftUI
import ZoneBarCore

/// Settings UI. Edits go straight through `PreferencesStore`, so the menu bar
/// updates as the user types.
///
/// Live times come from `TimelineView`s around the individual labels rather than
/// a view-wide timer: a timer here would invalidate the whole `List` every
/// second, which is both wasteful and a source of reentrant NSTableView updates.
///
/// Both lists here are NSTableView-backed, which constrains how a selectable row
/// may be built: attach no gesture to one, and keep `.tag()` outermost. Either
/// mistake silently stops selection working — it has twice — so double-click is
/// wired through `AddClockDoubleClickBridge` rather than a row gesture.
struct SettingsView: View {
    @ObservedObject var store: PreferencesStore

    @State private var selection: UUID?
    @State private var isAddingClock = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            preview
            Divider()
            clockList
            Divider()
            displayOptions
        }
        .padding(20)
        .frame(width: 480, height: 620)
        .sheet(isPresented: $isAddingClock) {
            AddClockView { identifier in
                store.addClock(tzIdentifier: identifier)
                isAddingClock = false
            } onCancel: {
                isAddingClock = false
            }
        }
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Menu bar preview")
                .font(.caption)
                .foregroundStyle(.secondary)
            TickingText { now in
                MenuBuilder.menuBarTitle(preferences: store.preferences, now: now)
            }
            .font(.system(size: 13).monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            Text(store.preferences.displayMode.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Clocks

    private var clockList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Clocks").font(.headline)
                Spacer()
                Text("\(store.preferences.clocks.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.preferences.clocks.isEmpty {
                emptyState
            } else {
                List(selection: $selection) {
                    ForEach(store.preferences.clocks) { clock in
                        ClockRowView(
                            clock: clock,
                            isPrimary: clock.id == store.preferences.primaryClock?.id,
                            preferences: store.preferences,
                            onSetPrimary: { store.setPrimaryClock(id: clock.id) },
                            onRename: { store.setCustomLabel($0, for: clock.id) },
                            onRemove: { remove(id: clock.id) }
                        )
                        .tag(clock.id)
                    }
                    .onMove { source, destination in
                        // Deferred: mutating the store inside the table's own
                        // drag callback reenters NSTableView's delegate.
                        DispatchQueue.main.async {
                            store.moveClocks(fromOffsets: source, toOffset: destination)
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .frame(minHeight: 200)
            }

            HStack {
                Button {
                    isAddingClock = true
                } label: {
                    Label("Add Clock", systemImage: "plus")
                }

                Button {
                    if let selection { remove(id: selection) }
                } label: {
                    Label("Remove", systemImage: "minus")
                }
                .disabled(selection == nil)

                Spacer()

                Text("Drag to reorder · the ✓ clock shows in the menu bar when grouped")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Clears the selection first so the list is never left pointing at a row
    /// that no longer exists.
    private func remove(id: UUID) {
        if selection == id { selection = nil }
        DispatchQueue.main.async {
            store.removeClock(id: id)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No clocks yet")
                .foregroundStyle(.secondary)
            Text("Add a time zone to see it in the menu bar.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Options

    private var displayOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Display").font(.headline)

            Picker("Mode", selection: displayModeBinding) {
                ForEach(DisplayMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Toggle("24-hour time", isOn: binding(\.use24Hour))
                    Toggle("Show seconds", isOn: binding(\.showSeconds))
                }
                GridRow {
                    Toggle("Flags in menu bar", isOn: binding(\.showFlagsInMenuBar))
                    Toggle("Show day offset", isOn: binding(\.showDayOffset))
                }
            }
            .toggleStyle(.checkbox)

            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    selection = nil
                    store.resetToDefaults()
                }
            }
        }
    }

    private var displayModeBinding: Binding<DisplayMode> {
        Binding(
            get: { store.preferences.displayMode },
            set: { store.preferences.displayMode = $0 }
        )
    }

    private func binding(_ keyPath: WritableKeyPath<Preferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.preferences[keyPath: keyPath] },
            set: { store.preferences[keyPath: keyPath] = $0 }
        )
    }
}

/// A label that re-renders once a second, keeping the tick scoped to itself.
private struct TickingText: View {
    let text: (Date) -> String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(text(context.date))
        }
    }
}

/// One row in the clock list: flag, label, live time and controls.
private struct ClockRowView: View {
    let clock: Clock
    let isPrimary: Bool
    let preferences: Preferences
    let onSetPrimary: () -> Void
    let onRename: (String?) -> Void
    let onRemove: () -> Void

    @State private var draftLabel: String = ""
    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 10) {
            Text(clock.flag).font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                if isEditing {
                    TextField("Label", text: $draftLabel)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(commit)
                } else {
                    Text(clock.label).fontWeight(isPrimary ? .semibold : .regular)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            TickingText { now in
                ClockFormatter.time(
                    now, in: clock.timeZone, use24Hour: preferences.use24Hour,
                    showSeconds: preferences.showSeconds)
            }
            .font(.system(.body, design: .monospaced))

            // Marks the clock shown in the menu bar in grouped mode.
            Button(action: onSetPrimary) {
                Image(systemName: isPrimary ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isPrimary ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help("Show this clock in the menu bar when grouped")
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Rename…") {
                draftLabel = clock.customLabel ?? clock.label
                isEditing = true
            }
            if clock.customLabel != nil {
                Button("Clear Custom Name") { onRename(nil) }
            }
            Button("Use in Menu Bar") { onSetPrimary() }
            Divider()
            Button("Remove", role: .destructive) { onRemove() }
        }
    }

    private var subtitle: String {
        // The UTC offset only shifts at DST boundaries, so it does not need to tick.
        let offset = TimeZoneCatalog.utcOffsetDescription(for: clock.timeZone, at: Date())
        let region = TimeZoneCatalog.region(for: clock.tzIdentifier)
        if let country = TimeZoneCatalog.countryName(for: clock.tzIdentifier) {
            return "\(country) · \(region) · \(offset)"
        }
        return "\(region) · \(offset)"
    }

    private func commit() {
        isEditing = false
        onRename(draftLabel)
    }
}

/// Searchable time zone picker.
private struct AddClockView: View {
    let onAdd: (String) -> Void
    let onCancel: () -> Void

    @State private var query = ""
    @State private var selection: String?
    @FocusState private var isSearchFocused: Bool

    /// Stored rather than computed in `body`: body also re-runs on every
    /// selection change, and the search walks all ~440 known zones. Kept in
    /// step with `query` by the single `onChange` below, so a keystroke costs
    /// exactly one search. Seeded through `search` rather than with
    /// `allIdentifiers` so what an empty query matches is stated in one place.
    @State private var matches: [String] = TimeZoneCatalog.search("")

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a Clock").font(.headline)

            TextField("Search city or country", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)

            List(selection: $selection) {
                ForEach(matches, id: \.self) { identifier in
                    HStack(spacing: 8) {
                        Text(FlagEmoji.flag(forTZIdentifier: identifier))
                        Text(TimeZoneCatalog.searchLabel(for: identifier))
                        Spacer()
                        Text(identifier)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    // Never attach a gesture to these rows. Any SwiftUI gesture
                    // here — count 1, count 2, or .simultaneousGesture — claims
                    // the mouse-down NSTableView needs for its own selection,
                    // and the row stops highlighting. Single click is the
                    // List's, via this tag; double click goes through the
                    // bridge below.
                    //
                    // Keep .tag outermost, as the clock list above does:
                    // modifiers wrapped around it hide it from the List.
                    .tag(identifier)
                }
            }
            .frame(minHeight: 280)
            .background(
                AddClockDoubleClickBridge {
                    if let selection { onAdd(selection) }
                }
            )

            if matches.isEmpty {
                Text("No time zones match “\(query)”.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }
                Button("Add") {
                    if let selection { onAdd(selection) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection == nil)
            }
        }
        .padding(20)
        .frame(width: 440, height: 460)
        .onAppear { isSearchFocused = true }
        .onChange(of: query) { _, newQuery in
            let newMatches = TimeZoneCatalog.search(newQuery)
            matches = newMatches
            syncSelection(for: newQuery, in: newMatches)
        }
    }

    /// Highlights the top hit *while filtering*, so typing a city and pressing
    /// Return adds it. Deliberately does nothing when the field is empty:
    /// pre-selecting the first of several hundred unfiltered zones means a
    /// reflexive click on Add quietly adds the wrong clock.
    ///
    /// Takes the query and matches it is reacting to rather than reading state,
    /// so it cannot act on a stale pair.
    private func syncSelection(for query: String, in matches: [String]) {
        guard !query.isEmpty else {
            selection = nil
            return
        }
        if let selection, matches.contains(selection) { return }
        selection = matches.first
    }
}

/// Gives the Add Clock picker its double-click-to-add, by handing the list's own
/// `NSTableView` a `doubleAction`. Lives in that list's `.background`.
///
/// macOS 14 SwiftUI has no double-click modifier, and a row tap gesture is not a
/// substitute — it swallows the click the table needs for its own selection,
/// which is the bug this arrangement exists to avoid. `NSTableView.doubleAction`
/// is AppKit's own hook: it fires *after* selection has moved to the clicked
/// row, so single clicks are untouched and nothing waits out a double-click
/// interval. That is also why `action` can read the current selection and never
/// needs a row index — by the time it runs, the two agree.
///
/// Scoped to this one picker deliberately, because it depends on SwiftUI's
/// private view hierarchy: that a `List` is NSTableView-backed and reachable
/// from a background view. If that ever stops holding, `tableView(near:)` finds
/// nothing and this quietly does nothing — double-click stops adding, while
/// selecting plus Add, and Return, keep working. Losing a convenience is the
/// intended failure mode, and the reason the dependency is acceptable at all.
/// So do not answer a miss by widening the search past the nearest table, and
/// never by putting a gesture back on a row.
private struct AddClockDoubleClickBridge: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = PassthroughView(frame: .zero)
        // The table is not in the hierarchy yet while the representable is being
        // made, so take one hop off the run loop before looking for it.
        DispatchQueue.main.async { attach(from: view, to: context.coordinator) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        // Refreshed every pass: the closure captures `selection`, which changes.
        context.coordinator.action = action
        attach(from: view, to: context.coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    /// Retries on each body pass until the table turns up — the search is the
    /// only signal available for when it appears — then costs one nil check per
    /// pass instead of a hierarchy walk. Re-searches if the table it found has
    /// since left the window, so a table swapped out underneath still gets wired.
    private func attach(from view: NSView, to coordinator: Coordinator) {
        if let attached = coordinator.tableView, attached.window != nil { return }
        guard let table = Self.tableView(near: view) else { return }
        coordinator.tableView = table
        // `target` is unretained, so the coordinator has to outlive this call.
        // SwiftUI holds it for as long as the representable is in the hierarchy.
        table.target = coordinator
        table.doubleAction = #selector(Coordinator.handleDoubleClick)
    }

    /// The table belonging to the list this view backs.
    ///
    /// SwiftUI is free to place a background view either inside the list's
    /// hierarchy or alongside it, so try both: up the ancestor chain, and down
    /// from each ancestor in turn. Widening a level at a time — rather than
    /// searching the whole window — means the table found is always the nearest
    /// one, so another list on screen can never be picked up by mistake.
    private static func tableView(near view: NSView) -> NSTableView? {
        var child = view
        while let parent = child.superview {
            if let table = parent as? NSTableView { return table }
            if let table = firstTableView(in: parent) { return table }
            child = parent
        }
        return nil
    }

    private static func firstTableView(in view: NSView) -> NSTableView? {
        for subview in view.subviews {
            if let table = subview as? NSTableView { return table }
            if let table = firstTableView(in: subview) { return table }
        }
        return nil
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        /// The table this coordinator is wired to, once found. Weak: the table
        /// belongs to the list, and holding it would outlive the sheet.
        weak var tableView: NSTableView?

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func handleDoubleClick() {
            action()
        }
    }

    /// Invisible and untouchable: it exists only as a handle on the hierarchy,
    /// and must never take a click away from the list it sits behind.
    private final class PassthroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
