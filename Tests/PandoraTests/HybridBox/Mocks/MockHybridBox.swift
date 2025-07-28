//
//  MockHybridBox.swift
//  Pandora
//
//  Created by Josh Gallant on 27/07/2025.
//


import Foundation
import Combine
@testable import Pandora

final class MockHybridBox<Key: Hashable & Sendable, Value: Codable & Sendable>: PandoraHybridBoxProtocol {
    let namespace: String

    private var storage: [Key: Value] = [:]
    private var publishers: [Key: CurrentValueSubject<Value?, Never>] = [:]

    init(namespace: String = "mock") {
        self.namespace = namespace
    }

    func publisher(for key: Key) -> AnyPublisher<Value?, Never> {
        if publishers[key] == nil {
            publishers[key] = .init(storage[key])
        }
        return publishers[key]!.eraseToAnyPublisher()
    }

    func get(_ key: Key) async -> Value? {
        return storage[key]
    }

    func put(key: Key, value: Value, expiresAfter: TimeInterval?) {
        storage[key] = value
        publishers[key]?.send(value)
    }

    func remove(_ key: Key) {
        storage.removeValue(forKey: key)
        publishers[key]?.send(nil)
    }

    func clear() {
        storage.removeAll()
        publishers.values.forEach { $0.send(nil) }
    }

    static func clearAll() {
        // No-op for mock
    }
}
