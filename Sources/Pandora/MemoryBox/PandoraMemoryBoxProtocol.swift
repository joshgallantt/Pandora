//
//  PandoraMemoryBoxProtocol.swift
//  Pandora
//
//  Created by Josh Gallant on 13/07/2025.
//


import Foundation
import Combine


/// An in-memory, thread-safe, generic cache with LRU eviction and optional entry expiration.
/// Supports per-key observation using Combine publishers.
public protocol PandoraMemoryBoxProtocol {
    associatedtype Key: Hashable
    associatedtype Value

    /// Inserts or updates a value for the given key, with optional per-key TTL.
    func put(key: Key, value: Value, expiresAfter: TimeInterval?)

    /// Retrieves the value for the given key, if present and not expired.
    func get(_ key: Key) -> Value?

    /// Removes the value for the given key.
    func remove(_ key: Key)

    /// Removes all entries from the cache.
    func clear()

    /// Returns a publisher that emits the current and subsequent values for the given key.
    func publisher(for key: Key) -> AnyPublisher<Value?, Never>
}
