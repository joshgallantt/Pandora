//
//  PandoraStorageManager.swift
//  Pandora
//
//  Created by Josh Gallant on 08/08/2025.
//

import Foundation


final class PandoraStorageManager {
    static let shared = PandoraStorageManager()
    
    private let maxTotalItems = 1024
    private let maxBytesPerValue = 1024
    
    private var itemCounts: [String: Int] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    /// Validates if a value can be stored given the constraints.
    func canStore(namespace: String, data: Data, isNewKey: Bool) -> Bool {
        guard data.count <= maxBytesPerValue else { return false }
        
        lock.lock()
        defer { lock.unlock() }
        
        if !isNewKey {
            // Updating existing key doesn't affect count
            return true
        }
        
        let currentCount = itemCounts.values.reduce(0, +)
        return currentCount < maxTotalItems
    }
    
    /// Records that an item was added to a namespace.
    func recordAddition(namespace: String) {
        lock.lock()
        defer { lock.unlock() }
        itemCounts[namespace, default: 0] += 1
    }
    
    /// Records that an item was removed from a namespace.
    func recordRemoval(namespace: String) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let count = itemCounts[namespace], count > 0 else { return }
        itemCounts[namespace] = count - 1
        if itemCounts[namespace] == 0 {
            itemCounts.removeValue(forKey: namespace)
        }
    }
    
    /// Updates the count for a namespace based on actual stored keys.
    func updateCount(namespace: String, count: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        if count > 0 {
            itemCounts[namespace] = count
        } else {
            itemCounts.removeValue(forKey: namespace)
        }
    }
    
    /// Gets the total number of items across all namespaces.
    func getTotalItemCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return itemCounts.values.reduce(0, +)
    }
    
    /// Gets the count for a specific namespace.
    func getNamespaceCount(_ namespace: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return itemCounts[namespace] ?? 0
    }
    
    func _resetForTesting() {
        lock.lock()
        itemCounts.removeAll()
        lock.unlock()
    }
}
