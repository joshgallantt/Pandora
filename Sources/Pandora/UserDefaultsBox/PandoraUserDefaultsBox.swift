//
//  PandoraUserDefaultsBox.swift
//  Pandora
//
//  Created by Josh Gallant on 13/07/2025.
//

import Foundation

/// This actor provides async-safe, namespaced storage using strongly-typed, codable keys and values.
public actor PandoraUserDefaultsBox: PandoraUserDefaultsBoxProtocol {
    
    /// Namespace prefix to ensure key separation from other uses of the same UserDefaults instance.
    public let namespace: String
    
    /// Backing store instance for persistence.
    let userDefaults: UserDefaults

    /// Creates a new instance, optionally targeting a non-standard UserDefaults suite.
    /// - Parameters:
    ///   - namespace: Namespace string for all keys.
    ///   - userDefaults: The `UserDefaults` instance to use (defaults to `.standard`).
    public init(namespace: String, userDefaults: UserDefaults = .standard) {
        self.namespace = namespace
        self.userDefaults = userDefaults
    }

    /// Produces the full, namespaced key for internal use.
    /// - Parameter key: Logical (un-namespaced) key.
    /// - Returns: Full string with namespace prefix.
    private func nsKey(_ key: String) -> String {
        "\(namespace).\(key)"
    }

    /// Stores an encodable, sendable value under the given key.
    /// Uses type-specific fast-paths for Foundation primitives. All other types are encoded with `JSONEncoder`.
    /// - Throws: `PersistentStorageError.encodingFailed` if encoding fails.
    public func put<T: Encodable & Sendable>(key: String, value: T) async throws {
        switch value {
        case let val as String:
            userDefaults.set(val, forKey: nsKey(key))
        case let val as Int:
            userDefaults.set(val, forKey: nsKey(key))
        case let val as Double:
            userDefaults.set(val, forKey: nsKey(key))
        case let val as Float:
            userDefaults.set(Double(val), forKey: nsKey(key))
        case let val as Bool:
            userDefaults.set(val, forKey: nsKey(key))
        case let val as Date:
            userDefaults.set(val, forKey: nsKey(key))
        case let val as URL:
            userDefaults.set(val, forKey: nsKey(key))
        case let val as Data:
            userDefaults.set(val, forKey: nsKey(key))
        default:
            do {
                // Use detached task for thread safety and not to block actor executor.
                let data = try await Task.detached {
                    try JSONEncoder().encode(value)
                }.value
                userDefaults.set(data, forKey: nsKey(key))
            } catch {
                throw UserDefaultsStorageError.encodingFailed(namespace: namespace, key: key, underlyingError: error)
            }
        }
    }

    /// Loads and decodes a value of type `T` for the given key.
    ///
    /// For Foundation primitive types, type-checks and casts. For URLs, handles legacy Data-archived values as well.
    /// For custom types, decodes using `JSONDecoder`.
    ///
    /// - Throws:
    ///   - `PersistentStorageError.valueNotFound` if no value.
    ///   - `PersistentStorageError.decodingFailed` for custom types if decode fails.
    ///   - `PersistentStorageError.foundButTypeMismatch` if a value is found but not of type `T`.
    public func get<T: Decodable & Sendable>(_ key: String) async throws -> T {
        let fullKey = nsKey(key)

        /// Creates a type-mismatch error for a found value.
        func mismatch(found: Any) -> UserDefaultsStorageError {
            .foundButTypeMismatch(namespace: namespace, key: key, expected: T.self, found: type(of: found))
        }

        guard let object = userDefaults.object(forKey: fullKey) else {
            throw UserDefaultsStorageError.valueNotFound(namespace: namespace, key: key)
        }

        switch T.self {
        case is String.Type:
            if let string = object as? String {
                return string as! T
            }
            throw mismatch(found: object)
        case is Int.Type:
            if let int = object as? Int {
                return int as! T
            }
            throw mismatch(found: object)
        case is Double.Type:
            if let double = object as? Double {
                return double as! T
            }
            throw mismatch(found: object)
        case is Bool.Type:
            if let bool = object as? Bool {
                return bool as! T
            }
            throw mismatch(found: object)
        case is Float.Type:
            if let float = object as? Float {
                return float as! T
            }
            throw mismatch(found: object)
        case is Date.Type:
            if let date = object as? Date {
                return date as! T
            }
            throw mismatch(found: object)
        case is URL.Type:
            // Handles both direct storage and legacy Data-archived URLs
            if let data = object as? Data,
               let url = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSURL.self, from: data) as URL? {
                return url as! T
            } else if let url = object as? URL {
                return url as! T
            }
            throw mismatch(found: object)
        case is Data.Type:
            if let data = object as? Data {
                return data as! T
            }
            throw mismatch(found: object)
        default:
            // For custom types, decode via JSONDecoder.
            guard let data = object as? Data else {
                throw mismatch(found: object)
            }
            do {
                return try await Task.detached {
                    try JSONDecoder().decode(T.self, from: data)
                }.value
            } catch {
                throw UserDefaultsStorageError.decodingFailed(namespace: namespace, key: key, underlyingError: error)
            }
        }
    }

    /// Removes the value for the given key in this namespace, if it exists.
    /// - Parameter key: The logical key (un-namespaced).
    public func remove(_ key: String) async {
        userDefaults.removeObject(forKey: nsKey(key))
    }

    /// Removes all values in this namespace only.
    public func clear() async {
        let prefix = "\(namespace)."
        for (key, _) in userDefaults.dictionaryRepresentation() where key.hasPrefix(prefix) {
            userDefaults.removeObject(forKey: key)
        }
    }

    /// Returns all logical keys present in this namespace.
    /// - Returns: An array of key strings (un-namespaced).
    public func allKeys() async -> [String] {
        let prefix = "\(namespace)."
        return userDefaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    /// Checks if a value exists for the given key in this namespace.
    /// - Parameter key: The logical key (un-namespaced).
    /// - Returns: `true` if the key exists, otherwise `false`.
    public func contains(_ key: String) async -> Bool {
        userDefaults.object(forKey: nsKey(key)) != nil
    }
}
