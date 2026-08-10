import SwiftUI
import ZoneBarCore

/// Settings UI. Edits go straight through `PreferencesStore`, so the menu bar
/// updates as the user types.
///
/// Live times come from `TimelineView`s around the individual labels rather than
/// a view-wide timer: a timer here would invalidate the whole `List` every
/// second, which is both wasteful and a source of reentrant NSTableView updates.
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

    /// Recomputed once per body evaluation and reused by the list, the empty
    /// state and `syncSelection()`; the search walks every known zone, so it is
    /// not something to call several times over.
    private var matches: [String] {
        TimeZoneCatalog.search(query)
    }

    var body: some View {
        let matches = self.matches

        return VStack(alignment: .leading, spacing: 12) {
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
                    // A tap gesture anywhere on a row consumes the click before
                    // AppKit's table can run its own selection, so selection is
                    // driven explicitly here rather than left to the List.
                    // Count 2 is declared first so a double-click resolves as
                    // "add" instead of two selections.
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { onAdd(identifier) }
                    .onTapGesture(count: 1) { selection = identifier }
                    // Outermost, matching the clock list above: the List reads
                    // the tag off the row it is handed, so wrapping it in
                    // further modifiers can hide it.
                    .tag(identifier)
                }
            }
            .frame(minHeight: 280)

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
        .onAppear {
            isSearchFocused = true
            syncSelection()
        }
        .onChange(of: query) { _, _ in syncSelection() }
    }

    /// Highlights the top hit *while filtering*, so typing a city and pressing
    /// Return adds it. Deliberately does nothing when the field is empty:
    /// pre-selecting the first of several hundred unfiltered zones means a
    /// reflexive click on Add quietly adds the wrong clock.
    private func syncSelection() {
        guard !query.isEmpty else {
            selection = nil
            return
        }
        if let selection, matches.contains(selection) { return }
        selection = matches.first
    }
}
