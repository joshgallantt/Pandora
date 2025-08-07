//
//  MockICloudStore.swift
//  Pandora
//
//  Created by Josh Gallant on 07/08/2025.
//

import Foundation


final class MockICloudStore: NSUbiquitousKeyValueStore {
    private var store: [String: Any] = [:]
    var didSynchronize = false
    override func set(_ value: Any?, forKey key: String) { store[key] = value }
    override func data(forKey key: String) -> Data? { store[key] as? Data }
    override func object(forKey key: String) -> Any? { store[key] }
    override func removeObject(forKey key: String) { store.removeValue(forKey: key) }
    override var dictionaryRepresentation: [String : Any] { store }
    override func synchronize() -> Bool { didSynchronize = true; return true }
}
