//
//  MockHybridBox.swift
//  Pandora
//
//  Created by Josh Gallant on 27/07/2025.
//

import Foundation
import Combine
@testable import Pandora

final class MockHybridBox<Key: Hashable & Codable & Sendable, Value: Codable & Sendable>: PandoraHybridBoxProtocol, @unchecked Sendable {
    let namespace: String

    private var storage: [Key: Value] = [:]
    private var publishers: [Key: CurrentValueSubject<Value?, Never>] = [:]
    private let lock = NSLock()

    init(namespace: String = "mock") {
        self.namespace = namespace
    }

    func publisher(for key: Key) -> AnyPublisher<Value?, Never> {
        let currentValue = lock.withLock { storage[key] }
        
        return Publishers.Merge(
            Just(currentValue).eraseToAnyPublisher(),
            getOrCreateMockPublisher(for: key).dropFirst()
        )
        .eraseToAnyPublisher()
    }
    
    private func getOrCreateMockPublisher(for key: Key) -> AnyPublisher<Value?, Never> {
        let subject = lock.withLock {
            if publishers[key] == nil {
                publishers[key] = CurrentValueSubject<Value?, Never>(nil) // Start with nil
            }
            return publishers[key]!
        }
        
        return subject.eraseToAnyPublisher()
    }

    func get(_ key: Key) async -> Value? {
        // Wrap synchronous lock in a Task to bridge to async context
        return await Task {
            lock.withLock { storage[key] }
        }.value
    }

    func put(key: Key, value: Value, expiresAfter: TimeInterval?) {
        let publisher = lock.withLock {
            storage[key] = value
            return publishers[key]
        }
        
        publisher?.send(value)
    }

    func remove(_ key: Key) {
        let publisher = lock.withLock {
            storage.removeValue(forKey: key)
            return publishers[key]
        }
        
        publisher?.send(nil)
    }

    func clear() {
        let allPublishers = lock.withLock {
            storage.removeAll()
            return Array(publishers.values)
        }
        
        allPublishers.forEach { $0.send(nil) }
    }

    static func clearAll() {
        // No-op for mock
    }
}
