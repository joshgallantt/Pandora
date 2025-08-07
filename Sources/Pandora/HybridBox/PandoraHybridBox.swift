//
//  PandoraHybridBox.swift
//  Pandora
//
//  Created by Josh Gallant on 27/07/2025.
//

import Foundation
import Combine

public final class PandoraHybridBox<Key: Hashable & Sendable, Value: Codable & Sendable>: PandoraHybridBoxProtocol {

    public let namespace: String

    private let memory: PandoraMemoryBox<Key, Value>
    private let disk: PandoraDiskBox<Key, Value>
    private let diskQueue: DispatchQueue
    private let memoryExpiresAfter: TimeInterval?
    private let diskExpiresAfter: TimeInterval?

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
        let safeNamespace = namespace.replacingOccurrences(of: "[^A-Za-z0-9_.-]", with: "_", options: .regularExpression)
        self.diskQueue = DispatchQueue(label: "HybridBox.DiskWrite.\(safeNamespace)", qos: .utility)
    }
    
    internal init(
        namespace: String,
        memory: PandoraMemoryBox<Key, Value>,
        disk: PandoraDiskBox<Key, Value>,
        memoryExpiresAfter: TimeInterval? = nil,
        diskExpiresAfter: TimeInterval? = nil,
        diskQueue: DispatchQueue? = nil
    ) {
        self.namespace = namespace
        self.memory = memory
        self.disk = disk
        self.memoryExpiresAfter = memoryExpiresAfter
        self.diskExpiresAfter = diskExpiresAfter
        let safeNamespace = namespace.replacingOccurrences(of: "[^A-Za-z0-9_.-]", with: "_", options: .regularExpression)
        self.diskQueue = diskQueue ?? DispatchQueue(label: "HybridBox.DiskWrite.\(safeNamespace)", qos: .utility)
    }

    public func publisher(for key: Key) -> AnyPublisher<Value?, Never> {
        memory.publisher(for: key)
    }

    public func get(_ key: Key) async -> Value? {
        if let value = memory.get(key) {
            return value
        }
        if let diskValue = await disk.get(key) {
            memory.put(key: key, value: diskValue, expiresAfter: memoryExpiresAfter)
            return diskValue
        }
        return nil
    }

    public func put(key: Key, value: Value, expiresAfter: TimeInterval? = nil) {
        let memoryExpiry = calculateExpiryDate(overrideTTL: expiresAfter, fallbackTTL: memoryExpiresAfter)
        let diskExpiry = calculateExpiryDate(overrideTTL: expiresAfter, fallbackTTL: diskExpiresAfter)
        
        memory.put(key: key, value: value, expiresAfter: memoryExpiry?.timeIntervalSinceNow)
        diskQueue.async { [disk = self.disk] in
            Task {
                await disk.put(key: key, value: value, expiresAfter: diskExpiry?.timeIntervalSinceNow)
            }
        }
    }

    public func remove(_ key: Key) {
        memory.remove(key)
        diskQueue.async { [disk = self.disk] in
            Task { await disk.remove(key) }
        }
    }

    public func clear() {
        memory.clear()
        diskQueue.async { [disk = self.disk] in
            Task { await disk.clear() }
        }
    }
}
