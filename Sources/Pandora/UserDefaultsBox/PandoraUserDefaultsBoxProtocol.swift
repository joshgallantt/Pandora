//
//  PandoraUserDefaultsBoxProtocol.swift
//  Pandora
//
//  Created by Josh Gallant on 13/07/2025.
//


import Foundation
import Combine

/// A UserDefaults-deferred cache with in-memory layer and per-key observation.
/// All keys are String.
public protocol PandoraDefaultsBoxProtocol {
    associatedtype Value: Codable

    var namespace: String { get }

    /// Emits current + future value for a key.
    func publisher(for key: String) -> AnyPublisher<Value?, Never>

    /// Reads value, checking memory first, then UserDefaults (and iCloud if enabled).
    func get(_ key: String) async -> Value?

    /// Writes value to memory (immediately), UserDefaults (immediately), iCloud (sync, if enabled).
    func put(key: String, value: Value)

    /// Removes value from memory/UserDefaults/iCloud.
    func remove(_ key: String)

    /// Clears all values for this namespace.
    func clear()
}

