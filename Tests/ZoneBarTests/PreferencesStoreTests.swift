import Foundation
import ZoneBarCore

/// Runs `body` against a store backed by in-memory storage, so the tests never
/// touch ~/Library/Preferences.
private func withStore(
    localTZIdentifier: String = "Europe/Stockholm",
    _ body: (PreferencesStore, InMemoryPreferencesStorage) -> Void
) {
    let storage = InMemoryPreferencesStorage()
    body(PreferencesStore(storage: storage, localTZIdentifier: localTZIdentifier), storage)
}

let preferencesStoreTests: [TestCase] = [
    TestCase(name: "first run seeds the local time zone") {
        withStore { store, _ in
            expectEqual(store.preferences.clocks.count, 1)
            expectEqual(store.preferences.clocks.first?.tzIdentifier, "Europe/Stockholm")
            expectEqual(store.preferences.primaryClockID, store.preferences.clocks.first?.id)
        }
    },

    TestCase(name: "changes persist and reload") {
        withStore { store, storage in
            store.addClock(tzIdentifier: "Asia/Tokyo")
            store.preferences.displayMode = .grouped
            store.preferences.use24Hour = false

            // A fresh store over the same defaults must see the saved state.
            let reloaded = PreferencesStore(
                storage: storage, localTZIdentifier: "Europe/Stockholm")
            expectEqual(
                reloaded.preferences.clocks.map(\.tzIdentifier),
                ["Europe/Stockholm", "Asia/Tokyo"])
            expectEqual(reloaded.preferences.displayMode, .grouped)
            expectFalse(reloaded.preferences.use24Hour)
        }
    },

    TestCase(name: "corrupt stored data falls back to defaults") {
        withStore(localTZIdentifier: "Asia/Tokyo") { _, storage in
            storage.savePreferencesData(Data("not json".utf8), forKey: PreferencesStore.defaultsKey)

            let store = PreferencesStore(storage: storage, localTZIdentifier: "Asia/Tokyo")
            expectEqual(store.preferences.clocks.map(\.tzIdentifier), ["Asia/Tokyo"])
        }
    },

    TestCase(name: "add clock appends and keeps the existing primary") {
        withStore { store, _ in
            let originalPrimary = store.preferences.primaryClockID
            store.addClock(tzIdentifier: "Asia/Tokyo")

            expectEqual(store.preferences.clocks.count, 2)
            expectEqual(store.preferences.clocks.last?.tzIdentifier, "Asia/Tokyo")
            expectEqual(store.preferences.primaryClockID, originalPrimary, "primary must not move")
        }
    },

    TestCase(name: "the same zone may be added twice") {
        withStore { store, _ in
            store.addClock(tzIdentifier: "Asia/Tokyo")
            store.addClock(tzIdentifier: "Asia/Tokyo")
            expectEqual(
                store.preferences.clocks.filter { $0.tzIdentifier == "Asia/Tokyo" }.count, 2)
        }
    },

    TestCase(name: "remove clock hands the primary role on") {
        withStore { store, _ in
            store.addClock(tzIdentifier: "Asia/Tokyo")
            guard let first = store.preferences.clocks.first else {
                return fail("expected a clock")
            }
            let second = store.preferences.clocks[1]

            store.removeClock(id: first.id)
            expectEqual(store.preferences.clocks.map(\.id), [second.id])
            expectEqual(store.preferences.primaryClockID, second.id, "primary follows the survivor")
        }
    },

    TestCase(name: "removing the last clock clears the primary") {
        withStore { store, _ in
            guard let only = store.preferences.clocks.first else {
                return fail("expected a clock")
            }
            store.removeClock(id: only.id)
            expectTrue(store.preferences.clocks.isEmpty)
            expectNil(store.preferences.primaryClockID)
        }
    },

    TestCase(name: "adding to an empty list claims the primary role") {
        withStore { store, _ in
            guard let only = store.preferences.clocks.first else {
                return fail("expected a clock")
            }
            store.removeClock(id: only.id)
            store.addClock(tzIdentifier: "Asia/Tokyo")
            expectEqual(store.preferences.primaryClockID, store.preferences.clocks.first?.id)
        }
    },

    TestCase(name: "move clocks reorders the list") {
        withStore { store, _ in
            store.addClock(tzIdentifier: "Asia/Tokyo")
            store.addClock(tzIdentifier: "America/New_York")

            store.moveClocks(fromOffsets: IndexSet(integer: 2), toOffset: 0)
            expectEqual(
                store.preferences.clocks.map(\.tzIdentifier),
                ["America/New_York", "Europe/Stockholm", "Asia/Tokyo"])
        }
    },

    TestCase(name: "move clocks to the end") {
        withStore { store, _ in
            store.addClock(tzIdentifier: "Asia/Tokyo")
            store.addClock(tzIdentifier: "America/New_York")

            // SwiftUI passes an offset one past the last index for "move to end".
            store.moveClocks(fromOffsets: IndexSet(integer: 0), toOffset: 3)
            expectEqual(
                store.preferences.clocks.map(\.tzIdentifier),
                ["Asia/Tokyo", "America/New_York", "Europe/Stockholm"])
        }
    },

    TestCase(name: "move clocks ignores out-of-range input") {
        withStore { store, _ in
            store.addClock(tzIdentifier: "Asia/Tokyo")
            let before = store.preferences.clocks.map(\.tzIdentifier)

            store.moveClocks(fromOffsets: IndexSet(integer: 9), toOffset: 0)
            store.moveClocks(fromOffsets: IndexSet(integer: 0), toOffset: 99)
            expectEqual(store.preferences.clocks.map(\.tzIdentifier), before)
        }
    },

    TestCase(name: "set primary clock ignores unknown ids") {
        withStore { store, _ in
            let original = store.preferences.primaryClockID
            store.setPrimaryClock(id: UUID())
            expectEqual(store.preferences.primaryClockID, original)
        }
    },

    TestCase(name: "set primary clock accepts a known id") {
        withStore { store, _ in
            store.addClock(tzIdentifier: "Asia/Tokyo")
            let tokyo = store.preferences.clocks[1]
            store.setPrimaryClock(id: tokyo.id)
            expectEqual(store.preferences.primaryClockID, tokyo.id)
        }
    },

    TestCase(name: "custom labels are trimmed and blanked to nil") {
        withStore { store, _ in
            guard let clock = store.preferences.clocks.first else {
                return fail("expected a clock")
            }

            store.setCustomLabel("  Home  ", for: clock.id)
            expectEqual(store.preferences.clocks.first?.customLabel, "Home")
            expectEqual(store.preferences.clocks.first?.label, "Home")

            store.setCustomLabel("   ", for: clock.id)
            expectNil(store.preferences.clocks.first?.customLabel, "whitespace clears the label")
            expectEqual(store.preferences.clocks.first?.label, "Stockholm")

            store.setCustomLabel(nil, for: clock.id)
            expectNil(store.preferences.clocks.first?.customLabel)
        }
    },

    TestCase(name: "reset returns to the first-run state") {
        withStore { store, _ in
            store.addClock(tzIdentifier: "Asia/Tokyo")
            store.preferences.displayMode = .grouped

            store.resetToDefaults()
            expectEqual(store.preferences.clocks.map(\.tzIdentifier), ["Europe/Stockholm"])
            expectEqual(store.preferences.displayMode, .flat)
        }
    },
]
