//
//  MockMemoryBox.swift
//  Pandora
//
//  Created by Josh Gallant on 13/07/2025.
//

import Foundation
import Combine
@testable import Pandora

final class MockMemoryBox<Key: Hashable & Sendable, Value: Sendable>: PandoraMemoryBox<Key, Value>, @unchecked Sendable {
    private var mockStorage: [Key: Value] = [:]
    private var mockSubjects: [Key: CurrentValueSubject<Value?, Never>] = [:]
    private let mockLock = NSLock()

    override func put(key: Key, value: Value, expiresAfter: TimeInterval? = nil) {
        mockLock.lock()
        mockStorage[key] = value
        if let subj = mockSubjects[key] {
            subj.send(value)
        } else {
            let subj = CurrentValueSubject<Value?, Never>(value)
            mockSubjects[key] = subj
        }
        mockLock.unlock()
    }

    override func get(_ key: Key) -> Value? {
        mockLock.lock()
        defer { mockLock.unlock() }
        return mockStorage[key]
    }

    override func remove(_ key: Key) {
        mockLock.lock()
        mockStorage.removeValue(forKey: key)
        let subject = mockSubjects[key]
        mockLock.unlock()
        
        subject?.send(nil)
    }

    override func clear() {
        mockLock.lock()
        let allSubjects = Array(mockSubjects.values)
        mockStorage.removeAll()
        mockLock.unlock()
        
        allSubjects.forEach { $0.send(nil) }
    }

    override func publisher(for key: Key) -> AnyPublisher<Value?, Never> {
        let currentValue = mockLock.withLock { mockStorage[key] }
        
        return Publishers.Merge(
            Just(currentValue).eraseToAnyPublisher(),
            getOrCreateMockPublisher(for: key).dropFirst()
        )
        .eraseToAnyPublisher()
    }
    
    private func getOrCreateMockPublisher(for key: Key) -> AnyPublisher<Value?, Never> {
        mockLock.lock()
        let subject: CurrentValueSubject<Value?, Never>
        if let subj = mockSubjects[key] {
            subject = subj
        } else {
            subject = CurrentValueSubject<Value?, Never>(nil) // Start with nil
            mockSubjects[key] = subject
        }
        let publisher = subject.eraseToAnyPublisher()
        mockLock.unlock()
        
        return publisher
    }
}
