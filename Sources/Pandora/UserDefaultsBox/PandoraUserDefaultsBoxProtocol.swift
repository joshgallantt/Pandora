//
//  PandoraUserDefaultsBoxProtocol.swift
//  Pandora
//
//  Created by Josh Gallant on 13/07/2025.
//


import Foundation

public protocol PandoraUserDefaultsBoxProtocol: Actor {
    /// Namespace prefix to ensure key separation from other uses of the same UserDefaults instance.
    var namespace: String { get }

    /// Stores a codable, sendable value under the given key.
    /// - Parameters:
    ///   - key: The referejce key for this value.
    ///   - value: The value to encode and store.
    func put<T: Encodable & Sendable>(key: String, value: T) async throws

    /// Loads and decodes a value of type `T` for the given key.
    /// - Parameter key: The logical key (un-namespaced).
    /// - Returns: The decoded value of type `T`.
    /// - Throws: `PersistentStorageError.valueNotFound` if no value, or `PersistentStorageError.decodingFailed` if decode fails.
    func get<T: Decodable & Sendable>(_ key: String) async throws -> T

    /// Removes the value for the given key from this namespace.
    /// - Parameter key: The logical key (un-namespaced).
    func remove(_ key: String) async

    /// Removes all values in this namespace only.
    func clear() async

    /// Returns all logical keys present in this namespace.
    /// - Returns: An array of key strings (un-namespaced).
    func allKeys() async -> [String]

    /// Checks if a value exists for the given key in this namespace.
    /// - Parameter key: The logical key (un-namespaced).
    /// - Returns: `true` if the key exists, otherwise `false`.
    func contains(_ key: String) async -> Bool
}

public enum UserDefaultsStorageError: Error, CustomStringConvertible {
    case encodingFailed(namespace: String, key: String, underlyingError: Error)
    case decodingFailed(namespace: String, key: String, underlyingError: Error)
    case valueNotFound(namespace: String, key: String)
    case foundButTypeMismatch(namespace: String, key: String, expected: Any.Type, found: Any.Type)

    public var description: String {
        switch self {
        case let .encodingFailed(namespace, key, underlyingError):
            return "PersistentStorage \(namespace) encoding failed for key '\(key)': \(underlyingError)"
        case let .decodingFailed(namespace, key, underlyingError):
            return "PersistentStorage \(namespace) decoding failed for key '\(key)': \(underlyingError)"
        case let .valueNotFound(namespace, key):
            return "PersistentStorage \(namespace) could not find value for key '\(key)'"
        case let .foundButTypeMismatch(namespace, key, expected, found):
            return "PersistentStorage \(namespace) found value for key '\(key)' but type mismatch: expected \(expected), found \(found)"
        }
    }
}

