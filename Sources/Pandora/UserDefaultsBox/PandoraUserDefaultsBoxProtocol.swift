//
//  PandoraUserDefaultsBoxProtocol.swift
//  Pandora
//
//  Created by Josh Gallant on 13/07/2025.
//


import Foundation
import Combine

/// A UserDefaults-backed cache with an in-memory layer and optional iCloud sync.
/// All keys are `String`.
public protocol PandoraDefaultsBoxProtocol {
    associatedtype Value: Codable

    /// The namespace used to isolate keys in memory, UserDefaults, and iCloud.
    var namespace: String { get }

    /// Emits the current and future values for the given key.
    func publisher(for key: String) -> AnyPublisher<Value?, Never>

    /// Reads the value for the given key, checking memory first, then UserDefaults,
    /// and iCloud if enabled.
    func get(_ key: String) async -> Value?

    /// Writes a value to memory and UserDefaults immediately,
    /// and to iCloud if enabled.
    func put(key: String, value: Value)

    /// Removes the value for the given key from memory, UserDefaults,
    /// and iCloud if enabled.
    func remove(_ key: String)

    /// Clears all values in the current namespace from memory, UserDefaults,
    /// and iCloud if enabled.
    func clear()
}


