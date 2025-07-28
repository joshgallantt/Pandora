//
//  MockMemoryBox.swift
//  Pandora
//
//  Created by Josh Gallant on 13/07/2025.
//


import Foundation
import Combine

@testable import Pandora

final class MockMemoryBox<Key: Hashable, Value>: PandoraMemoryBoxProtocol {
    private var storage: [Key: Value] = [:]
    private var subjects: [Key: CurrentValueSubject<Value?, Never>] = [:]
    private let lock = NSLock()

    func put(key: Key, value: Value, expiresAfter: TimeInterval? = nil) {
        lock.lock()
        storage[key] = value
        if let subj = subjects[key] {
            subj.send(value)
        } else {
            let subj = CurrentValueSubject<Value?, Never>(value)
            subjects[key] = subj
        }
        lock.unlock()
    }

    func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func remove(_ key: Key) {
        lock.lock()
        storage.removeValue(forKey: key)
        subjects[key]?.send(nil)
        lock.unlock()
    }

    func clear() {
        lock.lock()
        storage.keys.forEach { key in
            subjects[key]?.send(nil)
        }
        storage.removeAll()
        lock.unlock()
    }

    func publisher(for key: Key) -> AnyPublisher<Value?, Never> {
        lock.lock()
        let subject: CurrentValueSubject<Value?, Never>
        if let subj = subjects[key] {
            subject = subj
        } else {
            subject = CurrentValueSubject<Value?, Never>(storage[key])
            subjects[key] = subject
        }
        lock.unlock()
        return subject.eraseToAnyPublisher()
    }
}
