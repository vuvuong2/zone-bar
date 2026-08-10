import Foundation

/// Where `PreferencesStore` keeps its JSON blob.
///
/// This exists so tests can run fully in memory: pointing them at a real
/// `UserDefaults` suite leaves plist files behind in ~/Library/Preferences,
/// because `cfprefsd` re-flushes cached values when the process exits.
public protocol PreferencesStorage: AnyObject {
    func loadPreferencesData(forKey key: String) -> Data?
    func savePreferencesData(_ data: Data, forKey key: String)
}

extension UserDefaults: PreferencesStorage {
    public func loadPreferencesData(forKey key: String) -> Data? {
        data(forKey: key)
    }

    public func savePreferencesData(_ data: Data, forKey key: String) {
        set(data, forKey: key)
    }
}

/// In-memory storage, for tests and previews.
public final class InMemoryPreferencesStorage: PreferencesStorage {
    private var storage: [String: Data]

    public init(initial: [String: Data] = [:]) {
        self.storage = initial
    }

    public func loadPreferencesData(forKey key: String) -> Data? {
        storage[key]
    }

    public func savePreferencesData(_ data: Data, forKey key: String) {
        storage[key] = data
    }
}
