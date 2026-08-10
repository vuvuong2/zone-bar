import Combine
import Foundation

/// Owns the single copy of `Preferences`, persists it, and notifies observers.
///
/// Storage is injected so tests can use a throwaway `UserDefaults` suite.
public final class PreferencesStore: ObservableObject {
    public static let defaultsKey = "preferences"

    private let storage: PreferencesStorage
    private let localTZIdentifier: String

    /// Mutating this saves and republishes.
    @Published public var preferences: Preferences {
        didSet {
            guard preferences != oldValue else { return }
            save()
        }
    }

    public init(
        storage: PreferencesStorage = UserDefaults.standard,
        localTZIdentifier: String = TimeZone.current.identifier
    ) {
        self.storage = storage
        self.localTZIdentifier = localTZIdentifier
        self.preferences =
            Self.load(from: storage)
            ?? Preferences.makeDefault(localTZIdentifier: localTZIdentifier)
    }

    /// Unreadable or corrupt data is treated as "nothing stored" so a bad write
    /// cannot brick the app.
    private static func load(from storage: PreferencesStorage) -> Preferences? {
        guard let data = storage.loadPreferencesData(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(Preferences.self, from: data)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        storage.savePreferencesData(data, forKey: Self.defaultsKey)
    }

    // MARK: - Editing

    /// Appends a clock. Duplicates of the same zone are allowed on purpose so a
    /// zone can appear twice under different labels.
    public func addClock(tzIdentifier: String) {
        var updated = preferences
        let clock = Clock(tzIdentifier: tzIdentifier)
        updated.clocks.append(clock)
        if updated.primaryClockID == nil { updated.primaryClockID = clock.id }
        preferences = updated
    }

    public func removeClock(id: UUID) {
        var updated = preferences
        updated.clocks.removeAll { $0.id == id }
        // Hand the primary role to whatever is left.
        if updated.primaryClockID == id { updated.primaryClockID = updated.clocks.first?.id }
        preferences = updated
    }

    /// Reorders clocks using SwiftUI's `onMove` convention: `destination` is an
    /// index in the *original* array, before which the moved items land.
    /// Implemented here rather than via SwiftUI's `move` so Core stays UI-free.
    public func moveClocks(fromOffsets source: IndexSet, toOffset destination: Int) {
        let clocks = preferences.clocks
        guard source.allSatisfy(clocks.indices.contains),
            (0...clocks.count).contains(destination)
        else {
            return
        }

        let moving = source.map { clocks[$0] }
        let removedBeforeDestination = source.filter { $0 < destination }.count

        var remaining = clocks
        for index in source.sorted(by: >) { remaining.remove(at: index) }
        remaining.insert(contentsOf: moving, at: destination - removedBeforeDestination)

        var updated = preferences
        updated.clocks = remaining
        preferences = updated
    }

    public func setPrimaryClock(id: UUID) {
        guard preferences.clocks.contains(where: { $0.id == id }) else { return }
        var updated = preferences
        updated.primaryClockID = id
        preferences = updated
    }

    public func setCustomLabel(_ label: String?, for id: UUID) {
        guard let index = preferences.clocks.firstIndex(where: { $0.id == id }) else { return }
        var updated = preferences
        let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.clocks[index].customLabel = (trimmed?.isEmpty ?? true) ? nil : trimmed
        preferences = updated
    }

    /// Discards everything and returns to the first-run state.
    public func resetToDefaults() {
        preferences = Preferences.makeDefault(localTZIdentifier: localTZIdentifier)
    }
}
