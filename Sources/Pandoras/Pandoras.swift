//
//  Pandoras.swift
//  Pandoras
//
//  Created by Josh Gallant on 28/07/2025.
//

import Foundation

public enum Pandoras {
    
    // MARK: - Memory
    
    public enum Memory {
        /// Creates an in-memory cache box with optional maximum size and expiration.
        ///
        /// This cache stores key-value pairs entirely in memory.
        ///
        /// - Parameters:
        ///   - maxSize: The maximum number of elements to store before evicting oldest items. Default is 500.
        ///   - expiresAfter: Optional time interval after which cached items expire.
        /// - Returns: A `PandorasMemoryBox` instance for caching in memory.
        ///
        /// ```swift
        /// let cache = Pandoras.Memory.box(maxSize: 1000, expiresAfter: 3600)
        /// cache.set("value", forKey: "key")
        /// ```
        public static func box<Key: Hashable, Value>(
            maxSize: Int = 500,
            expiresAfter: TimeInterval? = nil
        ) -> PandorasMemoryBox<Key, Value> {
            PandorasMemoryBox(maxSize: maxSize, expiresAfter: expiresAfter)
        }
        
        /// Creates an in-memory cache box with explicit key and value types.
        ///
        /// Use this method as a fallback when Swift's type inference does not work.
        ///
        /// - Parameters:
        ///   - keyType: Explicit key type.
        ///   - valueType: Explicit value type.
        ///   - maxSize: The maximum number of elements to store before evicting oldest items. Default is 500.
        ///   - expiresAfter: Optional time interval after which cached items expire.
        /// - Returns: A `PandorasMemoryBox` instance for caching in memory.
        ///
        /// ```swift
        /// let cache = Pandoras.Memory.box(keyType: String.self, valueType: Int.self, maxSize: 100)
        /// cache.set(123, forKey: "userId")
        /// ```
        public static func box<Key: Hashable, Value>(
            keyType: Key.Type,
            valueType: Value.Type,
            maxSize: Int = 500,
            expiresAfter: TimeInterval? = nil
        ) -> PandorasMemoryBox<Key, Value> {
            box(maxSize: maxSize, expiresAfter: expiresAfter)
        }
    }
    
    // MARK: - Disk

    public enum Disk {
        /// Creates a disk-backed cache box within a specified namespace.
        ///
        /// Cached items are stored on disk and can optionally have size limits and expiration.
        ///
        /// - Parameters:
        ///   - namespace: The unique namespace for isolating cache data on disk.
        ///   - maxSize: Optional maximum number of items to store on disk.
        ///   - expiresAfter: Optional expiration time for cached items.
        /// - Returns: A `PandorasDiskBox` instance for disk-backed caching.
        ///
        /// ```swift
        /// let diskCache = Pandoras.Disk.box(namespace: "com.example.cache", maxSize: 10000)
        /// diskCache.set(value, forKey: "userProfile")
        /// ```
        public static func box<Key: Hashable, Value: Codable>(
            namespace: String,
            maxSize: Int? = nil,
            expiresAfter: TimeInterval? = nil
        ) -> PandorasDiskBox<Key, Value> {
            PandorasDiskBox(namespace: namespace, maxSize: maxSize, expiresAfter: expiresAfter)
        }
        
        /// Creates a disk-backed cache box with explicit key and value types.
        ///
        /// Use this method as a fallback when Swift's type inference does not work.
        ///
        /// - Parameters:
        ///   - namespace: The unique namespace for isolating cache data on disk.
        ///   - keyType: Explicit key type.
        ///   - valueType: Explicit value type.
        ///   - maxSize: Optional maximum number of items to store on disk.
        ///   - expiresAfter: Optional expiration time for cached items.
        /// - Returns: A `PandorasDiskBox` instance for disk-backed caching.
        ///
        /// ```swift
        /// let diskCache = Pandoras.Disk.box(namespace: "com.example.cache", keyType: String.self, valueType: Data.self)
        /// diskCache.set(Data(), forKey: "blob")
        /// ```
        public static func box<Key: Hashable, Value: Codable>(
            namespace: String,
            keyType: Key.Type,
            valueType: Value.Type,
            maxSize: Int? = nil,
            expiresAfter: TimeInterval? = nil
        ) -> PandorasDiskBox<Key, Value> {
            box(namespace: namespace, maxSize: maxSize, expiresAfter: expiresAfter)
        }
    }

    // MARK: - Hybrid

    public enum Hybrid {
        /// Creates a hybrid cache box that combines in-memory and disk caching.
        ///
        /// This method leverages Swift's type inference when the destination type is explicit.
        ///
        /// - Parameters:
        ///   - namespace: The cache namespace to isolate data.
        ///   - memoryMaxSize: Maximum number of items in memory cache. Default is 500.
        ///   - memoryExpiresAfter: Optional expiration for memory cache items.
        ///   - diskMaxSize: Optional maximum number of items in disk cache.
        ///   - diskExpiresAfter: Optional expiration for disk cache items.
        /// - Returns: A `PandorasHybridBox` combining memory and disk caching.
        ///
        /// ```swift
        /// let hybridCache: PandorasHybridBox<String, String> = Pandoras.Hybrid.box(namespace: "com.example.hybrid")
        /// hybridCache.set("cachedValue", forKey: "key")
        /// ```
        public static func box<Key: Hashable & Sendable, Value: Codable & Sendable>(
            namespace: String,
            memoryMaxSize: Int = 500,
            memoryExpiresAfter: TimeInterval? = nil,
            diskMaxSize: Int? = nil,
            diskExpiresAfter: TimeInterval? = nil
        ) -> PandorasHybridBox<Key, Value> {
            PandorasHybridBox(
                namespace: namespace,
                memoryMaxSize: memoryMaxSize,
                memoryExpiresAfter: memoryExpiresAfter,
                diskMaxSize: diskMaxSize,
                diskExpiresAfter: diskExpiresAfter
            )
        }

        /// Creates a hybrid cache box with explicit key and value types.
        ///
        /// Use this method as a fallback when Swift's type inference does not work.
        ///
        /// - Parameters:
        ///   - namespace: The cache namespace.
        ///   - keyType: Explicit key type.
        ///   - valueType: Explicit value type.
        ///   - memoryMaxSize: Maximum items in memory cache. Default is 500.
        ///   - memoryExpiresAfter: Optional expiration for memory cache items.
        ///   - diskMaxSize: Optional maximum items in disk cache.
        ///   - diskExpiresAfter: Optional expiration for disk cache items.
        /// - Returns: A `PandorasHybridBox` configured with explicit types.
        ///
        /// ```swift
        /// let hybridCache = Pandoras.Hybrid.box(
        ///     namespace: "com.example.hybrid",
        ///     keyType: String.self,
        ///     valueType: User.self
        /// )
        /// ```
        public static func box<Key: Hashable & Sendable, Value: Codable & Sendable>(
            namespace: String,
            keyType: Key.Type,
            valueType: Value.Type,
            memoryMaxSize: Int = 500,
            memoryExpiresAfter: TimeInterval? = nil,
            diskMaxSize: Int? = nil,
            diskExpiresAfter: TimeInterval? = nil
        ) -> PandorasHybridBox<Key, Value> {
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
        /// Creates a cache box backed by `UserDefaults`.
        ///
        /// This cache stores values using the `UserDefaults` API, isolated by a namespace.
        ///
        /// - Parameters:
        ///   - namespace: The namespace to prefix keys in UserDefaults.
        ///   - userDefaults: The `UserDefaults` instance to use. Defaults to `.standard`.
        /// - Returns: A `PandorasUserDefaultsBox` instance for caching with UserDefaults.
        ///
        /// ```swift
        /// let userDefaultsCache = Pandoras.UserDefaults.box(namespace: "com.example.settings")
        /// userDefaultsCache.set("darkModeEnabled", forKey: "darkMode")
        /// ```
        public static func box(
            namespace: String,
            userDefaults: Foundation.UserDefaults = .standard
        ) -> PandorasUserDefaultsBox {
            PandorasUserDefaultsBox(namespace: namespace, userDefaults: userDefaults)
        }
    }

    // MARK: - Utilities

    /// Removes all cached data stored on disk within the default disk cache root directory.
    ///
    /// Use this method to clear all disk cache data created by the Pandoras Disk and Hybrid boxes.
    ///
    /// - Note: This operation is destructive and irreversible.
    ///
    /// ```swift
    /// Pandoras.clearAllDiskData()
    /// ```
    public static func clearAllDiskData() {
        try? FileManager.default.removeItem(at: PandorasDiskBoxPath.sharedRoot)
    }
}

