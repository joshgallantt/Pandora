//
//  PandoraDiskBoxProtocol.swift
//  Pandora
//
//  Created by Josh Gallant on 27/07/2025.
//

import Foundation

/// A disk-backed, actor-isolated, generic key-value cache protocol with optional LRU eviction and entry expiration.
///
/// Designed for safe, concurrent use via actor isolation and async APIs.
/// Conforming types persist values under a namespace-specific directory in the cache folder.
public protocol PandoraDiskBoxProtocol: Actor {
    associatedtype Key: Hashable
    associatedtype Value: Codable
    
    /// The namespace for this disk cache, also used as the directory name.
    var namespace: String { get }

    /// Inserts or updates the value for a given key.
    /// Overwrites any existing value.
    ///
    /// - Parameters:
    ///   - key: The cache key.
    ///   - value: The value to store.
    ///   - expiresAfter: Optional TTL (seconds) for this key. If nil, uses global TTL if set.
    func put(key: Key, value: Value, expiresAfter: TimeInterval?) async

    /// Retrieves the value for the given key if present and not expired.
    func get(_ key: Key) async -> Value?

    /// Removes the value for the given key.
    func remove(_ key: Key) async

    /// Clears all entries in this namespace.
    func clear() async
}
