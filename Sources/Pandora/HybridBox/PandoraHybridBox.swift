//
//  PandoraHybridBox.swift
//  Pandora
//
//  Created by Josh Gallant on 27/07/2025.
//

import Foundation
import Combine

public final class PandoraHybridBox<Key: Hashable, Value: Codable>: PandoraHybridBoxProtocol {

    public let namespace: String

    private let memory: PandoraMemoryBox<Key, Value>
    private let disk: PandoraDiskBox<Key, Value>
    private let memoryExpiresAfter: TimeInterval?
    private let diskExpiresAfter: TimeInterval?
    private let syncLock = PandoraLock()

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

    public func publisher(for key: Key) -> AnyPublisher<Value?, Never> {
        memory.publisher(for: key)
    }

    public func get(_ key: Key) async -> Value? {
        await syncLock.withCriticalRegion {
            // Check memory first (synchronous, fast)
            if let value = memory.get(key) {
                return value
            }
            
            // Check disk (async)
            if let diskValue = await disk.get(key) {
                // Hydrate memory cache
                memory.put(key: key, value: diskValue, expiresAfter: memoryExpiresAfter)
                return diskValue
            }
            
            return nil
        }
    }

    public func put(key: Key, value: Value, expiresAfter: TimeInterval? = nil) {
        let memoryExpiry = calculateExpiryDate(overrideTTL: expiresAfter, fallbackTTL: memoryExpiresAfter)
        let diskExpiry = calculateExpiryDate(overrideTTL: expiresAfter, fallbackTTL: diskExpiresAfter)
        
        // Write to memory immediately (synchronous)
        memory.put(key: key, value: value, expiresAfter: memoryExpiry?.timeIntervalSinceNow)
        
        // Write to disk asynchronously
        Task {
            await disk.put(key: key, value: value, expiresAfter: diskExpiry?.timeIntervalSinceNow)
        }
    }

    public func remove(_ key: Key) {
        // Remove from memory immediately
        memory.remove(key)
        
        // Remove from disk asynchronously
        Task {
            await disk.remove(key)
        }
    }

    public func clear() {
        // Clear memory immediately
        memory.clear()
        
        // Clear disk asynchronously
        Task {
            await disk.clear()
        }
    }
}
