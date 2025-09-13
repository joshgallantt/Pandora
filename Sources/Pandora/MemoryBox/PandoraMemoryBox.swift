//
//  PandoraMemoryBox.swift
//  Pandora
//
//  Created by Josh Gallant on 13/07/2025.
//

import Foundation
import Combine

/// An in-memory, thread-safe, generic cache with LRU eviction and optional global entry expiration (TTL).
/// Supports per-key value observation using Combine publishers.
/// On every key removal (explicit, LRU, or expiry), publishers are notified with `nil`.
/// Subjects are **kept alive** so existing subscribers keep receiving future updates if the key is set again.
public class PandoraMemoryBox<Key: Hashable & Sendable, Value: Sendable>: PandoraMemoryBoxProtocol, @unchecked Sendable {

    // MARK: - Private properties

    /// Maximum number of items retained in the cache. `nil` means unlimited.
    private let maxSize: Int?

    /// Optional global time-to-live (in seconds) for cache entries. If set, entries expire after this interval.
    private let expiresAfter: TimeInterval?

    /// Tracks key order for LRU eviction. Most recently used key is at the end.
    private var lruKeys: [Key] = []

    /// Backing storage for cache entries. Each entry stores the value and its optional expiry date.
    private var storage: [Key: (value: Value, expiry: Date?)] = [:]

    /// Per-key publisher for observation. Sends `nil` on removal or expiry, but subjects remain alive.
    private var subjects: [Key: CurrentValueSubject<Value?, Never>] = [:]

    /// Synchronizes access to all mutable state.
    private let lock = NSLock()

    // MARK: - Initialization

    public init(maxSize: Int? = 500, expiresAfter: TimeInterval? = nil) {
        if let maxSize, maxSize > 0 {
            self.maxSize = maxSize
        } else {
            self.maxSize = nil // unlimited
        }
        
        if let expiresAfter, expiresAfter > 0 {
            self.expiresAfter = expiresAfter
        } else {
            self.expiresAfter = nil // unlimited
        }
    }

    // MARK: - Public API

    public func put(key: Key, value: Value, expiresAfter: TimeInterval? = nil) {
        let expiry = calculateExpiryDate(overrideTTL: expiresAfter, fallbackTTL: self.expiresAfter)
        var removedSubjects: [CurrentValueSubject<Value?, Never>] = []
        var subject: CurrentValueSubject<Value?, Never>?
        
        lock.lock()
        storage[key] = (value, expiry)
        updateLRU_locked(for: key)
        subject = subjects[key]
        removedSubjects.append(contentsOf: removeExpired_locked())
        removedSubjects.append(contentsOf: evictIfNeeded_locked())
        lock.unlock()
        
        subject?.send(value)
        removedSubjects.forEach { $0.send(nil) }
    }

    public func get(_ key: Key) -> Value? {
        var result: Value?
        var expiredSubject: CurrentValueSubject<Value?, Never>?
        
        lock.lock()
        if let entry = storage[key] {
            if isEntryExpired(entry) {
                storage[key] = nil
                lruKeys.removeAll { $0 == key }
                expiredSubject = subjects[key]
            } else {
                updateLRU_locked(for: key)
                result = entry.value
            }
        }
        lock.unlock()
        
        expiredSubject?.send(nil)
        return result
    }

    public func remove(_ key: Key) {
        var removedSubject: CurrentValueSubject<Value?, Never>?
        
        lock.lock()
        storage[key] = nil
        lruKeys.removeAll { $0 == key }
        removedSubject = subjects[key]
        lock.unlock()
        
        removedSubject?.send(nil)
    }

    public func publisher(for key: Key, emitInitial: Bool = true) -> AnyPublisher<Value?, Never> {
        lock.lock()
        let subject: CurrentValueSubject<Value?, Never>
        if let existing = subjects[key] {
            subject = existing
        } else {
            let value: Value? = {
                if let entry = storage[key], !isEntryExpired(entry) {
                    return entry.value
                } else {
                    return nil
                }
            }()
            subject = .init(value)
            subjects[key] = subject
        }
        let publisher = subject.eraseToAnyPublisher()
        lock.unlock()
        
        if emitInitial {
            return publisher
        } else {
            return publisher.dropFirst().eraseToAnyPublisher()
        }
    }

    public func clear() {
        var removedSubjects: [CurrentValueSubject<Value?, Never>] = []
        
        lock.lock()
        storage.removeAll()
        lruKeys.removeAll()
        removedSubjects = Array(subjects.values)
        lock.unlock()
        
        removedSubjects.forEach { $0.send(nil) }
    }

    // MARK: - Internal helpers

    private func updateLRU_locked(for key: Key) {
        lruKeys.removeAll { $0 == key }
        lruKeys.append(key)
    }

    private func removeExpired_locked() -> [CurrentValueSubject<Value?, Never>] {
        let now = Date()
        var expiredSubjects: [CurrentValueSubject<Value?, Never>] = []
        let expiredKeys = storage.compactMap { (key, entry) -> Key? in
            if isEntryExpired(entry, now: now) { return key }
            return nil
        }
        for key in expiredKeys {
            storage[key] = nil
            lruKeys.removeAll { $0 == key }
            if let subject = subjects[key] {
                expiredSubjects.append(subject)
            }
        }
        return expiredSubjects
    }

    private func evictIfNeeded_locked() -> [CurrentValueSubject<Value?, Never>] {
        guard let limit = maxSize else { return [] }
        var removedSubjects: [CurrentValueSubject<Value?, Never>] = []
        while lruKeys.count > limit {
            let oldest = lruKeys.removeFirst()
            storage.removeValue(forKey: oldest)
            if let subject = subjects[oldest] {
                removedSubjects.append(subject)
            }
        }
        return removedSubjects
    }

    private func isEntryExpired(_ entry: (value: Value, expiry: Date?), now: Date = Date()) -> Bool {
        if let expiry = entry.expiry {
            return expiry < now
        }
        return false
    }
}
