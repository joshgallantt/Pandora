//
//  PandoraDiskBox.swift
//  Pandora
//
//  Created by Josh Gallant on 27/07/2025.
//

import Foundation
import CryptoKit

/// A disk-backed, actor-isolated, generic key-value cache with LRU and expiry support.
/// Each instance stores its data under a unique, namespaced directory beneath the system cache.
/// Uses collision-resistant filenames derived from a stable hash of the key's canonical encoding.
public actor PandoraDiskBox<Key: Hashable & Codable & Sendable, Value: Codable & Sendable>: PandoraDiskBoxProtocol {
    public var namespace: String

    private let directory: URL
    private let maxSize: Int?
    private let expiresAfter: TimeInterval?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(namespace: String, maxSize: Int? = nil, expiresAfter: TimeInterval? = nil) {
        let safeNamespace = namespace.replacingOccurrences(of: "/", with: "_")
        let directory = PandoraDiskBoxPath.sharedRoot.appendingPathComponent(safeNamespace, isDirectory: true)
        self.maxSize = (maxSize ?? 0) > 0 ? maxSize : nil
        self.directory = directory
        self.expiresAfter = expiresAfter
        self.namespace = namespace
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func put(key: Key, value: Value, expiresAfter: TimeInterval? = nil) async {
        // keep your calculateExpiryDate as-is
        let expiry = calculateExpiryDate(overrideTTL: expiresAfter, fallbackTTL: self.expiresAfter)
        let url = fileURL(for: key)
        let entry = DiskEntry(value: value, expiry: expiry)
        if let data = try? encoder.encode(entry) {
            try? data.write(to: url, options: .atomic)
        }
        await enforceLRU()
    }

    public func get(_ key: Key) async -> Value? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let entry = try? decoder.decode(DiskEntry.self, from: data)
        else { return nil }
        if let expiry = entry.expiry, expiry < Date() {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return entry.value
    }

    public func remove(_ key: Key) async {
        let url = fileURL(for: key)
        try? FileManager.default.removeItem(at: url)
    }

    public func clear() async {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files { try? FileManager.default.removeItem(at: file) }
    }

    // MARK: - Stable filename from hashed Codable key

    private func fileURL(for key: Key) -> URL {
        let filename = filenameForKey(key)
        return directory.appendingPathComponent(filename).appendingPathExtension("box")
    }

    private func filenameForKey(_ key: Key) -> String {
        // Use a dedicated encoder for keys so value encoding remains unchanged.
        let keyEncoder = JSONEncoder()
        keyEncoder.outputFormatting = [.sortedKeys]

        guard let data = try? keyEncoder.encode(key) else {
            // Extremely unlikely for valid Codable keys; safe fallback.
            return "key_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        }

        let digest = SHA256.hash(data: data)
        // 64 hex chars, filesystem-safe.
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - LRU

    private func enforceLRU() async {
        guard let maxSize, maxSize > 0 else { return }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        guard files.count > maxSize else { return }
        let sorted = files.sorted { (lhs, rhs) -> Bool in
            let lDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lDate < rDate
        }
        for file in sorted.prefix(files.count - maxSize) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private struct DiskEntry: Codable {
        let value: Value
        let expiry: Date?
    }
}
