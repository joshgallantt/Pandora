//
//  Pandora.swift
//  Pandora
//
//  Created by Josh Gallant on 28/07/2025.
//

import Foundation

public enum Pandora {
    
    // MARK: - Memory

    public enum Memory {
        /// Returns an in-memory cache box.
        ///
        /// Stores key-value pairs entirely in memory, with optional size and expiration limits.
        ///
        /// - Parameters:
        ///   - maxSize: Maximum number of items before evicting the oldest. Default is 500.
        ///   - expiresAfter: Optional expiration interval for each item.
        /// - Returns: A `PandoraMemoryBox` instance.
        ///
        /// ### Type Inference Examples
        /// ```swift
        /// struct TestUser: Codable, Equatable {
        ///     let id: Int
        ///     let name: String
        /// }
        ///
        /// // 1. Inference-based
        /// let box: PandoraMemoryBox<String, TestUser> = Pandora.Memory.box()
        ///
        /// // 2. Explicit cast
        /// let box = Pandora.Memory.box() as PandoraMemoryBox<String, TestUser>
        ///
        /// // 3. Explicit types
        /// let box = Pandora.Memory.box(keyType: String.self, valueType: TestUser.self)
        ///
        /// box.put(key: "user", value: TestUser(id: 1, name: "Alice"))
        /// ```
        public static func box<Key: Hashable, Value>(
            maxSize: Int = 500,
            expiresAfter: TimeInterval? = nil
        ) -> PandoraMemoryBox<Key, Value> {
            PandoraMemoryBox(maxSize: maxSize, expiresAfter: expiresAfter)
        }

        /// Returns an in-memory cache box with explicit key and value types.
        ///
        /// Useful when type inference fails—for example, when the return type isn't declared or can't be inferred.
        ///
        /// - Parameters:
        ///   - keyType: The key type (e.g., `String.self`).
        ///   - valueType: The value type (e.g., `TestUser.self`).
        ///   - maxSize: Maximum number of items. Default is 500.
        ///   - expiresAfter: Optional expiration interval.
        /// - Returns: A `PandoraMemoryBox` instance.
        ///
        /// ### Example
        /// ```swift
        /// let box = Pandora.Memory.box(
        ///     keyType: String.self,
        ///     valueType: TestUser.self,
        ///     maxSize: 100
        /// )
        ///
        /// box.put(key: "user", value: TestUser(id: 1, name: "Explicit"))
        /// ```
        public static func box<Key: Hashable, Value>(
            keyType: Key.Type,
            valueType: Value.Type,
            maxSize: Int = 500,
            expiresAfter: TimeInterval? = nil
        ) -> PandoraMemoryBox<Key, Value> {
            box(maxSize: maxSize, expiresAfter: expiresAfter)
        }
    }

    // MARK: - Disk

    public enum Disk {
        /// Returns a disk-backed cache box.
        ///
        /// Stores items on disk under a unique namespace, with optional size and expiration limits.
        ///
        /// - Parameters:
        ///   - namespace: Unique identifier for disk storage.
        ///   - maxSize: Optional maximum item count.
        ///   - expiresAfter: Optional expiration interval.
        /// - Returns: A `PandoraDiskBox` instance.
        ///
        /// ### Type Inference Examples
        /// ```swift
        /// struct TestUser: Codable, Equatable {
        ///     let id: Int
        ///     let name: String
        /// }
        ///
        /// // 1. Inference-based
        /// let box: PandoraDiskBox<String, TestUser> = Pandora.Disk.box(namespace: "disk1")
        ///
        /// // 2. Explicit cast
        /// let box = Pandora.Disk.box(namespace: "disk2") as PandoraDiskBox<String, TestUser>
        ///
        /// // 3. Explicit types
        /// let box = Pandora.Disk.box(namespace: "disk3", keyType: String.self, valueType: TestUser.self)
        ///
        /// await box.put(key: "user", value: TestUser(id: 2, name: "Bob"))
        /// ```
        public static func box<Key: Hashable, Value: Codable>(
            namespace: String,
            maxSize: Int? = nil,
            expiresAfter: TimeInterval? = nil
        ) -> PandoraDiskBox<Key, Value> {
            PandoraDiskBox(namespace: namespace, maxSize: maxSize, expiresAfter: expiresAfter)
        }

        /// Returns a disk-backed cache box with explicit key and value types.
        ///
        /// Useful when type inference fails—for example, if the result isn’t assigned to a concrete variable type.
        ///
        /// - Parameters:
        ///   - namespace: Unique identifier for disk storage.
        ///   - keyType: The key type (e.g., `String.self`).
        ///   - valueType: The value type (e.g., `TestUser.self`).
        ///   - maxSize: Optional maximum item count.
        ///   - expiresAfter: Optional expiration interval.
        /// - Returns: A `PandoraDiskBox` instance.
        ///
        /// ### Example
        /// ```swift
        /// let box = Pandora.Disk.box(
        ///     namespace: "com.example.explicit",
        ///     keyType: String.self,
        ///     valueType: TestUser.self
        /// )
        ///
        /// await box.put(key: "user", value: TestUser(id: 2, name: "ExplicitDisk"))
        /// ```
        public static func box<Key: Hashable, Value: Codable>(
            namespace: String,
            keyType: Key.Type,
            valueType: Value.Type,
            maxSize: Int? = nil,
            expiresAfter: TimeInterval? = nil
        ) -> PandoraDiskBox<Key, Value> {
            box(namespace: namespace, maxSize: maxSize, expiresAfter: expiresAfter)
        }
    }

    // MARK: - Hybrid

    public enum Hybrid {
        /// Returns a hybrid cache box combining memory and disk.
        ///
        /// Stores items in memory and persists them to disk, with separate expiration and size controls.
        ///
        /// - Parameters:
        ///   - namespace: Cache namespace.
        ///   - memoryMaxSize: Max items in memory. Default is 500.
        ///   - memoryExpiresAfter: Optional memory expiration interval.
        ///   - diskMaxSize: Optional max items on disk.
        ///   - diskExpiresAfter: Optional disk expiration interval.
        /// - Returns: A `PandoraHybridBox` instance.
        ///
        /// ### Type Inference Examples
        /// ```swift
        /// struct TestUser: Codable, Equatable {
        ///     let id: Int
        ///     let name: String
        /// }
        ///
        /// // 1. Inference-based
        /// let box: PandoraHybridBox<String, TestUser> = Pandora.Hybrid.box(namespace: "hybrid1")
        ///
        /// // 2. Explicit cast
        /// let box = Pandora.Hybrid.box(namespace: "hybrid2") as PandoraHybridBox<String, TestUser>
        ///
        /// // 3. Explicit types
        /// let box = Pandora.Hybrid.box(
        ///     namespace: "hybrid3",
        ///     keyType: String.self,
        ///     valueType: TestUser.self
        /// )
        ///
        /// box.put(key: "user", value: TestUser(id: 3, name: "Charlie"))
        /// ```
        public static func box<Key: Hashable, Value: Codable> (
            namespace: String,
            memoryMaxSize: Int = 500,
            memoryExpiresAfter: TimeInterval? = nil,
            diskMaxSize: Int? = nil,
            diskExpiresAfter: TimeInterval? = nil
        ) -> PandoraHybridBox<Key, Value> {
            PandoraHybridBox(
                namespace: namespace,
                memoryMaxSize: memoryMaxSize,
                memoryExpiresAfter: memoryExpiresAfter,
                diskMaxSize: diskMaxSize,
                diskExpiresAfter: diskExpiresAfter
            )
        }

        /// Returns a hybrid cache box with explicit key and value types.
        ///
        /// Useful when type inference fails or when constructing without assigning to a concrete type.
        ///
        /// - Parameters:
        ///   - namespace: Cache namespace.
        ///   - keyType: The key type (e.g., `String.self`).
        ///   - valueType: The value type (e.g., `TestUser.self`).
        ///   - memoryMaxSize: Max items in memory. Default is 500.
        ///   - memoryExpiresAfter: Optional memory expiration interval.
        ///   - diskMaxSize: Optional max items on disk.
        ///   - diskExpiresAfter: Optional disk expiration interval.
        /// - Returns: A `PandoraHybridBox` instance.
        ///
        /// ### Example
        /// ```swift
        /// let box = Pandora.Hybrid.box(
        ///     namespace: "com.example.hybrid",
        ///     keyType: String.self,
        ///     valueType: TestUser.self
        /// )
        ///
        /// box.put(key: "user", value: TestUser(id: 3, name: "ExplicitHybrid"))
        /// ```
        public static func box<Key: Hashable, Value: Codable>(
            namespace: String,
            keyType: Key.Type,
            valueType: Value.Type,
            memoryMaxSize: Int = 500,
            memoryExpiresAfter: TimeInterval? = nil,
            diskMaxSize: Int? = nil,
            diskExpiresAfter: TimeInterval? = nil
        ) -> PandoraHybridBox<Key, Value> {
            box(
                namespace: namespace,
                memoryMaxSize: memoryMaxSize,
                memoryExpiresAfter: memoryExpiresAfter,
                diskMaxSize: diskMaxSize,
                diskExpiresAfter: diskExpiresAfter
            )
        }
    }

    // MARK: - UserDefaults

    public enum UserDefaults {
        /// Returns a cache box backed by `UserDefaults`.
        ///
        /// Keys are namespaced and values stored via `UserDefaults`, with optional iCloud mirroring.
        /// All values are encoded before storage, and rejected entirely if the encoded size exceeds 1024 bytes.
        /// Maximum 1024 items total across all namespaces (enforced globally).
        ///
        /// - Parameters:
        ///   - namespace: Prefix used to isolate keys.
        ///   - userDefaults: The backing store. Defaults to `.standard`.
        ///   - iCloudBacked: Whether to mirror values to iCloud and observe changes. Defaults to `true`.
        /// - Returns: A `PandoraUserDefaultsBox` instance.
        ///
        /// ### Type Inference Examples
        /// ```swift
        /// struct TestUser: Codable, Equatable {
        ///     let id: Int
        ///     let name: String
        /// }
        ///
        /// // 1. Inference-based
        /// let box: PandoraUserDefaultsBox<TestUser> = Pandora.UserDefaults.box(namespace: "user.defaults")
        ///
        /// // 2. Explicit cast
        /// let box = Pandora.UserDefaults.box(namespace: "user.defaults", iCloudBacked: false) as PandoraUserDefaultsBox<TestUser>
        ///
        /// box.put(key: "user", value: TestUser(id: 4, name: "Dora"))
        /// let result = await box.get("user")
        /// ```
        public static func box<Value: Codable>(
            namespace: String,
            userDefaults: Foundation.UserDefaults = .standard,
            iCloudBacked: Bool = true
        ) -> PandoraUserDefaultsBox<Value> {
            PandoraUserDefaultsBox(namespace: namespace, userDefaults: userDefaults, iCloudBacked: iCloudBacked)
        }

        /// Returns a cache box backed by `UserDefaults` with an explicit value type.
        ///
        /// Useful when type inference fails — for example, when constructing without assigning
        /// to a concrete variable type or when returning from a function with a generic return type.
        ///
        /// - Parameters:
        ///   - namespace: Prefix used to isolate keys.
        ///   - valueType: The value type (e.g., `TestUser.self`).
        ///   - userDefaults: The backing store. Defaults to `.standard`.
        ///   - iCloudBacked: Whether to mirror values to iCloud and observe changes. Defaults to `true`.
        /// - Returns: A `PandoraUserDefaultsBox` instance.
        ///
        /// ### Example
        /// ```swift
        /// let box = Pandora.UserDefaults.box(
        ///     namespace: "user.defaults",
        ///     valueType: TestUser.self,
        ///     iCloudBacked: false
        /// )
        ///
        /// box.put(key: "user", value: TestUser(id: 4, name: "Dora"))
        /// let result = await box.get("user")
        /// ```
        public static func box<Value: Codable>(
            namespace: String,
            valueType: Value.Type,
            userDefaults: Foundation.UserDefaults = .standard,
            iCloudBacked: Bool = true
        ) -> PandoraUserDefaultsBox<Value> {
            box(namespace: namespace, userDefaults: userDefaults, iCloudBacked: iCloudBacked)
        }
    }


    // MARK: - Utilities

    /// Deletes all disk cache data created by `Pandora.Disk` and `Pandora.Hybrid`.
    ///
    /// - Note: This is a destructive and irreversible operation.
    /// - Warning: This will delete **all** Pandora-managed disk caches.
    public static func clearAllDiskData() {
        try? FileManager.default.removeItem(at: PandoraDiskBoxPath.sharedRoot)
    }

    /// Removes all keys from the standard `UserDefaults` and `NSUbiquitousKeyValueStore`.
    ///
    /// - Warning: This will clear **all keys**, not just Pandora-related ones.
    public static func clearUserDefaults() {
        let defaults = Foundation.UserDefaults.standard
        
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
        
        let store = NSUbiquitousKeyValueStore.default

        for key in store.dictionaryRepresentation.keys {
            store.removeObject(forKey: key)
        }
        
        defaults.synchronize()
        store.synchronize()

    }
    
    /// Deletes all local and iCloud-backed data for this app:
    ///
    /// - Note: This is a destructive and irreversible operation.
    /// - Warning: This will clear **all keys**, not just Pandora-related ones.
    public static func deleteAllLocalStorage() {
        clearAllDiskData()
        clearUserDefaults()
    }

}
