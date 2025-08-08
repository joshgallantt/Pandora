//
//  PandoraUserDefaultsBox.swift
//  Pandora
//
//  Created by Josh Gallant on 08/08/2025.
//

import Foundation
import Combine

/// A thread-safe, namespaced cache backed by an in-memory store and `UserDefaults`,
/// with optional iCloud synchronization and size-limited entries.
///
/// ### Storage Model
/// - **Memory layer**: Fast in-memory cache (`PandoraMemoryBox`) without expiry by default.
/// - **UserDefaults layer**: Persistent local storage.
/// - **iCloud layer** *(optional)*: Backed by `NSUbiquitousKeyValueStore` for cross-device synchronization.
/// - **Size constraint**: All values are encoded with `JSONEncoder` before storage, and
///   rejected entirely if the encoded size exceeds `maxMemoryBytes` (1024 bytes).
///
/// ### Thread Safety
/// - `.get` is synchronized across all backing stores using an internal `PandoraLock`.
/// - `.put`, `.remove`, and `.clear` are not locked, as they only perform atomic per-store writes.
///
/// ### Key Handling
/// All keys are scoped to a `namespace` to avoid collisions across different storage consumers.
/// Internally, keys are prefixed as `"<namespace>.<key>"` before persistence.
///
/// ### iCloud Sync
/// When `iCloudBacked` is `true`, values are mirrored to iCloud on writes (subject to the size limit),
/// and changes from other devices are merged into memory and `UserDefaults` via notifications.
/// Syncing from iCloud is:
/// - **Eager** on initialization (via `.synchronize()`).
/// - **Reactive** via `NSUbiquitousKeyValueStore.didChangeExternallyNotification`.
///
/// ### Observation
/// The `.publisher(for:)` method returns a `Combine` publisher emitting the current value
/// immediately, followed by subsequent changes from memory, local, or iCloud writes.
///
/// - Note: The `Value` type must be `Codable` to support encoding/decoding for persistence.
public final class PandoraUserDefaultsBox<Value: Codable>: PandoraDefaultsBoxProtocol {

    public let namespace: String
    public let iCloudBacked: Bool

    private let memory: PandoraMemoryBox<String, Value>
    private let userDefaults: UserDefaults
    private let iCloudStore: NSUbiquitousKeyValueStore?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let syncLock = PandoraLock()
    
    private let maxMemoryItems = 1024
    private let maxMemoryBytes = 1024

    /// Creates a new `PandoraUserDefaultsBox`.
    ///
    /// - Parameters:
    ///   - namespace: A unique identifier used to prefix all stored keys.
    ///   - userDefaults: The backing `UserDefaults` instance. Defaults to `.standard`.
    ///   - iCloudBacked: Whether to mirror values to iCloud and observe changes.
    public init(
        namespace: String,
        userDefaults: UserDefaults = .standard,
        iCloudBacked: Bool = true
    ) {
        self.namespace = namespace
        self.userDefaults = userDefaults
        self.iCloudBacked = iCloudBacked
        self.iCloudStore = iCloudBacked ? NSUbiquitousKeyValueStore.default : nil
        self.memory = PandoraMemoryBox<String, Value>(maxSize: maxMemoryItems, expiresAfter: nil)

        if iCloudBacked {
            iCloudStore?.synchronize()
            startObservingiCloudChanges()
        }
    }

    internal init(
        namespace: String,
        memory: PandoraMemoryBox<String, Value>,
        userDefaults: UserDefaults,
        iCloudStore: NSUbiquitousKeyValueStore?,
        iCloudBacked: Bool,
        memoryExpiresAfter: TimeInterval? = nil
    ) {
        self.namespace = namespace
        self.memory = memory
        self.userDefaults = userDefaults
        self.iCloudStore = iCloudStore
        self.iCloudBacked = iCloudBacked
        if iCloudBacked {
            startObservingiCloudChanges()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func nsKey(_ key: String) -> String {
        "\(namespace).\(key)"
    }

    // MARK: - Publisher

    /// Returns a publisher that emits the current and future values for the specified key.
    ///
    /// The publisher observes the in-memory cache and reflects changes from local writes,
    /// reads from persistent stores, and incoming iCloud updates.
    public func publisher(for key: String) -> AnyPublisher<Value?, Never> {
        memory.publisher(for: key)
    }

    // MARK: - Get (thread safe)

    /// Retrieves the value for the specified key.
    ///
    /// Lookup order:
    /// 1. In-memory cache (fastest).
    /// 2. `UserDefaults` (decoded into memory if found).
    /// 3. iCloud store (decoded into memory and mirrored to `UserDefaults` if found).
    ///
    /// Thread-safe: guarded by `syncLock` to ensure atomic multi-store reads and writes.
    public func get(_ key: String) async -> Value? {
        await syncLock.withCriticalRegion {
            if let value = memory.get(key) {
                return value
            }
            let fullKey = nsKey(key)
            if let data = userDefaults.data(forKey: fullKey),
               let decoded = try? decoder.decode(Value.self, from: data) {
                memory.put(key: key, value: decoded)
                return decoded
            }
            if iCloudBacked,
               let data = iCloudStore?.data(forKey: fullKey),
               let decoded = try? decoder.decode(Value.self, from: data) {
                memory.put(key: key, value: decoded)
                userDefaults.set(data, forKey: fullKey)
                return decoded
            }
            return nil
        }
    }

    // MARK: - Put (no lock)

    /// Stores a value in memory and persistent stores if it meets size constraints.
    ///
    /// - Encodes the value using `JSONEncoder`.
    /// - Rejects the value entirely if the encoded size exceeds `maxMemoryBytes` (1024 bytes).
    /// - Writes to the in-memory cache (if size limit is met).
    /// - Persists to `UserDefaults` (if size limit is met).
    /// - Mirrors to iCloud if enabled and size limit is met.
    /// - Does not acquire a lock — designed for fast, non-blocking writes.
    public func put(key: String, value: Value) {
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            return
        }

        guard data.count <= maxMemoryBytes else {
            return
        }

        let fullKey = nsKey(key)
        memory.put(key: key, value: value)
        userDefaults.set(data, forKey: fullKey)

        if iCloudBacked {
            iCloudStore?.set(data, forKey: fullKey)
        }
    }

    // MARK: - Remove (no lock)

    /// Removes the specified key from memory, `UserDefaults`, and iCloud (if enabled).
    ///
    /// The iCloud store is synchronized after removal to propagate changes.
    public func remove(_ key: String) {
        let fullKey = nsKey(key)
        memory.remove(key)
        userDefaults.removeObject(forKey: fullKey)
        if iCloudBacked {
            iCloudStore?.removeObject(forKey: fullKey)
            iCloudStore?.synchronize()
        }
    }

    // MARK: - Clear (no lock)

    /// Removes all keys in the current namespace from memory, `UserDefaults`, and iCloud (if enabled).
    public func clear() {
        let prefix = "\(namespace)."
        memory.clear()
        for (key, _) in userDefaults.dictionaryRepresentation() where key.hasPrefix(prefix) {
            userDefaults.removeObject(forKey: key)
        }
        if iCloudBacked, let store = iCloudStore {
            for (key, _) in store.dictionaryRepresentation where key.hasPrefix(prefix) {
                store.removeObject(forKey: key)
            }
            store.synchronize()
        }
    }

    // MARK: - iCloud Sync (thread safe)

    private func startObservingiCloudChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore
        )
    }

    @objc internal func iCloudDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
              let store = iCloudStore else { return }
        let prefix = "\(namespace)."
        Task {
            await syncLock.withCriticalRegion {
                for fullKey in changedKeys where fullKey.hasPrefix(prefix) {
                    let key = String(fullKey.dropFirst(prefix.count))
                    if let data = store.data(forKey: fullKey),
                       let decoded = try? decoder.decode(Value.self, from: data) {
                        memory.put(key: key, value: decoded)
                        userDefaults.set(data, forKey: fullKey)
                    } else {
                        memory.remove(key)
                        userDefaults.removeObject(forKey: fullKey)
                    }
                }
            }
        }
    }
}
