//
//  PandoraHybridBox.swift
//  Pandora
//
//  Created by Josh Gallant on 27/07/2025.
//

import Foundation
import Combine

public final class PandoraHybridBox<Key: Hashable & Codable & Sendable, Value: Codable & Sendable>: PandoraHybridBoxProtocol, @unchecked Sendable {

    public let namespace: String

    private let memory: PandoraMemoryBox<Key, Value>
    private let disk: PandoraDiskBox<Key, Value>
    private let memoryExpiresAfter: TimeInterval?
    private let diskExpiresAfter: TimeInterval?
    private let syncLock = NSLock()
    private var inflight: [Key: Task<Value?, Never>] = [:]

    public init(
        namespace: String,
        memoryMaxSize: Int = 500,
        memoryExpiresAfter: TimeInterval? = nil,
        diskMaxSize: Int? = nil,
        diskExpiresAfter: TimeInterval? = nil
    ) {
        self.namespace = namespace
        self.memoryExpiresAfter = memoryExpiresAfter
        self.diskExpiresAfter = diskExpiresAfter
        self.memory = PandoraMemoryBox<Key, Value>(maxSize: memoryMaxSize, expiresAfter: memoryExpiresAfter)
        self.disk = PandoraDiskBox<Key, Value>(namespace: namespace, maxSize: diskMaxSize, expiresAfter: diskExpiresAfter)
    }

    internal init(
        namespace: String,
        memory: PandoraMemoryBox<Key, Value>,
        disk: PandoraDiskBox<Key, Value>,
        memoryExpiresAfter: TimeInterval? = nil,
        diskExpiresAfter: TimeInterval? = nil
    ) {
        self.namespace = namespace
        self.memory = memory
        self.disk = disk
        self.memoryExpiresAfter = memoryExpiresAfter
        self.diskExpiresAfter = diskExpiresAfter
    }

    public func publisher(for key: Key, emitInitial: Bool = true) -> AnyPublisher<Value?, Never> {
        if emitInitial {
            let currentValue = syncLock.withLock { memory.get(key) }
            return Publishers.Merge(
                Just(currentValue).eraseToAnyPublisher(),
                memory.publisher(for: key, emitInitial: false)
            )
            .eraseToAnyPublisher()
        } else {
            return memory.publisher(for: key, emitInitial: false)
        }
    }

    public func get(_ key: Key) async -> Value? {
        // Fast path: check memory under scoped lock
        if let inMemory = syncLock.withLock({ memory.get(key) }) {
            return inMemory
        }

        // Atomically get or create a single in-flight task for this key
        let task: Task<Value?, Never> = syncLock.withLock {
            if let existing = inflight[key] {
                return existing
            }
            let newTask = Task<Value?, Never> { [weak self] in
                guard let self else { return nil }
                let diskValue = await self.disk.get(key)

                self.syncLock.withLock {
                    // Always clean up the in-flight entry
                    self.inflight.removeValue(forKey: key)

                    // Guarded hydrate: only populate memory if still missing
                    if let v = diskValue, self.memory.get(key) == nil {
                        self.memory.put(key: key, value: v, expiresAfter: self.memoryExpiresAfter)
                    }
                }

                return diskValue
            }
            inflight[key] = newTask
            return newTask
        }

        // Await the shared result (no locks held while awaiting)
        return await task.value
    }

    public func put(key: Key, value: Value, expiresAfter: TimeInterval? = nil) {
        let memoryExpiry = calculateExpiryDate(overrideTTL: expiresAfter, fallbackTTL: memoryExpiresAfter)
        let diskExpiry = calculateExpiryDate(overrideTTL: expiresAfter, fallbackTTL: diskExpiresAfter)

        // Write to memory synchronously (scoped lock)
        syncLock.withLock {
            memory.put(key: key, value: value, expiresAfter: memoryExpiry?.timeIntervalSinceNow)
        }

        // Write to disk asynchronously
        Task {
            await disk.put(key: key, value: value, expiresAfter: diskExpiry?.timeIntervalSinceNow)
        }
    }

    public func remove(_ key: Key) {
        // Remove from memory immediately
        syncLock.withLock {
            memory.remove(key)
        }

        // Remove from disk asynchronously
        Task {
            await disk.remove(key)
        }
    }

    public func clear() {
        // Clear memory immediately
        syncLock.withLock {
            memory.clear()
        }

        // Clear disk asynchronously
        Task {
            await disk.clear()
        }
    }
}
