//
//  PandoraHybridBoxProtocol.swift
//  Pandora
//
//  Created by Josh Gallant on 27/07/2025.
//

import Foundation
import Combine

/// A hybrid cache that stores values in memory first, falling back to disk if missing,
/// and hydrates memory from disk on a hit.
/// Supports per-key value observation using Combine publishers.
public protocol PandoraHybridBoxProtocol {
    associatedtype Key: Hashable
    associatedtype Value: Codable

    /// The unique namespace isolating this cache’s memory and disk entries.
    var namespace: String { get }

    /// A publisher emitting the current and subsequent value for the given key.
    ///
    /// - Emits the current value (or nil) on subscription, then updates or removals in real time.
    /// - Events are sent immediately for memory changes.
    func publisher(for key: Key) -> AnyPublisher<Value?, Never>

    /// Reads a value for the given key, checking memory first, then disk.
    ///
    /// - On disk hit, value is loaded into memory and returned.
    /// - Returns nil if not found.
    func get(_ key: Key) async -> Value?

    /// Writes a value for the given key, storing in memory instantly and to disk asynchronously.
    ///
    /// - Parameters:
    ///   - key: The cache key.
    ///   - value: The value to store.
    ///   - expiresAfter: Optional override TTL for both memory and disk for this entry.
    func put(key: Key, value: Value, expiresAfter: TimeInterval?)

    /// Removes a value for the given key from both memory and disk.
    func remove(_ key: Key)

    /// Clears all values from memory and disk for this instance.
    func clear()
}
