//
//  MockDiskBox.swift
//  Pandoras
//
//  Created by Josh Gallant on 27/07/2025.
//


import Foundation
@testable import Pandoras

public actor MockDiskBox<Key: Hashable, Value: Codable>: PandorasDiskBoxProtocol {
    public let namespace: String
    private var store: [Key: Value] = [:]
    private var expiry: [Key: Date] = [:]

    public init(namespace: String = "test-mock-disk-box") {
        self.namespace = namespace
    }

    public func put(key: Key, value: Value, expiresAfter: TimeInterval? = nil) async {
        store[key] = value
        if let ttl = expiresAfter {
            expiry[key] = Date().addingTimeInterval(ttl)
        } else {
            expiry.removeValue(forKey: key)
        }
    }

    public func get(_ key: Key) async -> Value? {
        if let exp = expiry[key], exp < Date() {
            store.removeValue(forKey: key)
            expiry.removeValue(forKey: key)
            return nil
        }
        return store[key]
    }

    public func remove(_ key: Key) async {
        store.removeValue(forKey: key)
        expiry.removeValue(forKey: key)
    }

    public func clear() async {
        store.removeAll()
        expiry.removeAll()
    }

    public static func clearAll() {}
}
