//
//  PandoraUserDefaultsBox.swift
//  Pandora
//
//  Created by Josh Gallant on 08/08/2025.
//


import Foundation
import Combine

/// A thread-safe, namespaced cache backed by an in-memory store and `UserDefaults`,
/// with optional iCloud synchronization and globally enforced size limits.
///
/// ### Singleton Storage Model
/// - Uses a singleton `PandoraStorageManager` to enforce global limits across all namespaces.
/// - Maximum 1024 items total across all instances.
/// - Maximum 1KB per value.
/// - Each namespace maintains isolation while sharing the global limit.
///
/// ### Storage Layers
/// - **Memory layer**: Fast in-memory cache without expiry by default.
/// - **UserDefaults layer**: Persistent local storage.
/// - **iCloud layer** *(optional)*: Backed by `NSUbiquitousKeyValueStore` for cross-device synchronization.
///
/// ### Thread Safety
/// - Uses `NSLock.withLock {}`.
/// - `get` avoids holding the lock while doing slower work (decoding or iCloud reads).
/// - Global storage limits are enforced atomically via `PandoraStorageManager`.
///
/// ### Key Handling
/// All keys are scoped to a `namespace` to avoid collisions across different storage consumers.
/// Internally, keys are prefixed as `"<namespace>.<key>"` before persistence.
public final class PandoraUserDefaultsBox<Value: Codable>: PandoraDefaultsBoxProtocol {
    
    public let namespace: String
    public let iCloudBacked: Bool
    
    private let memory: PandoraMemoryBox<String, Value>
    private let userDefaults: UserDefaults
    private let iCloudStore: NSUbiquitousKeyValueStore?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let syncLock = NSLock()
    private let storageManager = PandoraStorageManager.shared
    
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
        self.memory = PandoraMemoryBox<String, Value>(maxSize: Int.max, expiresAfter: nil)
        
        // Initialize storage tracking synchronously
        initializeStorageTracking()
        
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
        
        initializeStorageTracking()
        
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
    
    /// Initializes storage tracking by counting existing items for this namespace.
    private func initializeStorageTracking() {
        let prefix = "\(namespace)."
        var count = 0
        
        // Count existing items in UserDefaults
        for (key, _) in userDefaults.dictionaryRepresentation() where key.hasPrefix(prefix) {
            count += 1
        }
        
        // Update storage manager with actual count
        storageManager.updateCount(namespace: namespace, count: count)
    }
    
    // MARK: - Publisher
    
    /// Returns a publisher that emits the current and future values for the specified key.
    public func publisher(for key: String) -> AnyPublisher<Value?, Never> {
        memory.publisher(for: key)
    }
    
    // MARK: - Get
    
    /// Retrieves the value for the specified key.
    ///
    /// Lookup order:
    /// 1. In-memory cache (fastest).
    /// 2. `UserDefaults` (decoded into memory if found).
    /// 3. iCloud store (decoded into memory and mirrored to `UserDefaults` if found).
    public func get(_ key: String) async -> Value? {
        // Fast path: in-memory under scoped lock
        if let inMemory = syncLock.withLock({ memory.get(key) }) {
            return inMemory
        }
        
        let fullKey = nsKey(key)
        
        // Try UserDefaults without holding the lock (UserDefaults is thread-safe)
        if let data = userDefaults.data(forKey: fullKey),
           let decoded = try? decoder.decode(Value.self, from: data) {
            // Hydrate memory under scoped lock
            syncLock.withLock {
                if memory.get(key) == nil { // guarded hydrate
                    memory.put(key: key, value: decoded)
                }
            }
            return decoded
        }
        
        // Try iCloud (if enabled)
        if iCloudBacked,
           let data = iCloudStore?.data(forKey: fullKey),
           let decoded = try? decoder.decode(Value.self, from: data) {
            // Hydrate memory and mirror to UserDefaults
            syncLock.withLock {
                if memory.get(key) == nil { // guarded hydrate
                    memory.put(key: key, value: decoded)
                }
            }
            userDefaults.set(data, forKey: fullKey)
            return decoded
        }
        
        return nil
    }
    
    // MARK: - Put
    
    /// Stores a value if it meets global and per-value size constraints.
    ///
    /// - Enforces 1KB maximum per value.
    /// - Enforces 1024 maximum total items across all namespaces.
    /// - Writes to memory, UserDefaults, and iCloud (if enabled).
    public func put(key: String, value: Value) {
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            return
        }
        
        let fullKey = nsKey(key)
        
        // Check if this is a new key
        let isNewKey = userDefaults.data(forKey: fullKey) == nil
        
        // Check if we can store this value
        guard storageManager.canStore(namespace: namespace, data: data, isNewKey: isNewKey) else {
            return
        }
        
        // Store the value
        syncLock.withLock {
            memory.put(key: key, value: value)
        }
        
        userDefaults.set(data, forKey: fullKey)
        
        if iCloudBacked {
            iCloudStore?.set(data, forKey: fullKey)
        }
        
        // Update storage tracking if it's a new key
        if isNewKey {
            storageManager.recordAddition(namespace: namespace)
        }
    }
    
    // MARK: - Remove
    
    /// Removes the specified key from all storage layers.
    public func remove(_ key: String) {
        let fullKey = nsKey(key)
        
        // Check if key exists before removal
        let exists = userDefaults.data(forKey: fullKey) != nil
        
        syncLock.withLock {
            memory.remove(key)
        }
        userDefaults.removeObject(forKey: fullKey)
        
        if iCloudBacked {
            iCloudStore?.removeObject(forKey: fullKey)
            iCloudStore?.synchronize()
        }
        
        // Update storage tracking if key existed
        if exists {
            storageManager.recordRemoval(namespace: namespace)
        }
    }
    
    // MARK: - Clear
    
    /// Removes all keys in the current namespace from all storage layers.
    public func clear() {
        let prefix = "\(namespace)."
        
        syncLock.withLock {
            memory.clear()
        }
        
        for (key, _) in userDefaults.dictionaryRepresentation() where key.hasPrefix(prefix) {
            userDefaults.removeObject(forKey: key)
        }
        
        if iCloudBacked, let store = iCloudStore {
            for (key, _) in store.dictionaryRepresentation where key.hasPrefix(prefix) {
                store.removeObject(forKey: key)
            }
            store.synchronize()
        }
        
        // Reset the namespace count in the global manager
        storageManager.updateCount(namespace: namespace, count: 0)
    }
    
    // MARK: - Stats
    
    public func storageStatistics() -> (namespaceCount: Int, totalCount: Int) {
        let namespaceCount = storageManager.getNamespaceCount(namespace)
        let totalCount = storageManager.getTotalItemCount()
        return (namespaceCount, totalCount)
    }
    
    // MARK: - iCloud Sync
    
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
              let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
        
        let prefix = "\(namespace)."
        let relevantKeys = changedKeys.filter { $0.hasPrefix(prefix) }
        
        guard !relevantKeys.isEmpty else { return }
        
        // Extract data synchronously before entering Task
        var changesToProcess: [(key: String, data: Data?)] = []
        for fullKey in relevantKeys {
            let key = String(fullKey.dropFirst(prefix.count))
            let data = iCloudStore?.data(forKey: fullKey)
            changesToProcess.append((key: key, data: data))
        }
        
        Task {
            await processICloudChanges(changesToProcess)
        }
    }
    
    private func processICloudChanges(_ changes: [(key: String, data: Data?)]) async {
        // Entire block is synchronous work; use scoped lock (no await inside)
        syncLock.withLock {
            var addedCount = 0
            var removedCount = 0
            
            for (key, data) in changes {
                let fullKey = nsKey(key)
                let previouslyExisted = (memory.get(key) != nil) || (userDefaults.data(forKey: fullKey) != nil)
                
                if let data = data,
                   let decoded = try? decoder.decode(Value.self, from: data) {
                    memory.put(key: key, value: decoded)
                    userDefaults.set(data, forKey: fullKey)
                    if !previouslyExisted {
                        addedCount += 1
                    }
                } else {
                    memory.remove(key)
                    userDefaults.removeObject(forKey: fullKey)
                    if previouslyExisted {
                        removedCount += 1
                    }
                }
            }
            
            // Update storage tracking
            if addedCount > 0 {
                for _ in 0..<addedCount {
                    storageManager.recordAddition(namespace: namespace)
                }
            }
            if removedCount > 0 {
                for _ in 0..<removedCount {
                    storageManager.recordRemoval(namespace: namespace)
                }
            }
        }
    }
}
