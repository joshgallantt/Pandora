//
//  PandoraDiskBoxProtocol.swift
//  Pandora
//
//  Created by Josh Gallant on 27/07/2025.
//

import Foundation

/// A disk-backed, actor-isolated, generic key-value cache protocol with optional LRU eviction and entry expiration.
///
/// Designed for safe, concurrent use from any context via actor isolation and async APIs.
/// Each conforming type should persist values as files under a dedicated, namespace-isolated directory.
public protocol PandoraDiskBoxProtocol: Actor {
    associatedtype Key: Hashable
    associatedtype Value: Codable
    
    /// Directory name under which all cache files for this box are stored.
    var namespace: String { get }

    /// Inserts or updates the value for a given key.
    /// If a value already exists for this key, it is overwritten.
    ///
    /// - Parameters:
    ///   - key: The key to insert.
    ///   - value: The value to store. Must be `Codable`.
    ///   - expiresAfter: Optional TTL (in seconds) for this key. If nil, global TTL or no expiry is used.
    func put(key: Key, value: Value, expiresAfter: TimeInterval?) async

    /// Retrieves the value for the specified key, if present and not expired.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The value for this key, or `nil` if not present or expired.
    func get(_ key: Key) async -> Value?

    /// Removes the value for the specified key, if present.
    ///
    /// - Parameter key: The key to remove.
    func remove(_ key: Key) async

    /// Removes all entries managed by this cache instance (only this namespace).
    func clear() async
}

