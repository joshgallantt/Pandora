//
//  PandorasDiskBox.swift
//  Pandoras
//
//  Created by Josh Gallant on 27/07/2025.
//

import Foundation

/// A disk-backed, actor-isolated, generic key-value cache with LRU and expiry support.
/// Each instance stores its data under a unique, namespaced directory beneath the system cache.
/// Uses collision-free filenames derived from the key.
public actor PandorasDiskBox<Key: Hashable, Value: Codable>: PandorasDiskBoxProtocol {
    public var namespace: String

    private let directory: URL
    private let maxSize: Int?
    private let expiresAfter: TimeInterval?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(namespace: String, maxSize: Int? = nil, expiresAfter: TimeInterval? = nil) {
        let safeNamespace = namespace.replacingOccurrences(of: "/", with: "_")
        let directory = PandorasDiskBoxPath.sharedRoot.appendingPathComponent(safeNamespace, isDirectory: true)
        self.maxSize = (maxSize ?? 0) > 0 ? maxSize : nil
        self.directory = directory
        self.expiresAfter = expiresAfter
        self.namespace = namespace
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func put(key: Key, value: Value, expiresAfter: TimeInterval? = nil) async {
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

    private func fileURL(for key: Key) -> URL {
        let keyString: String
        if let stringKey = key as? String {
            keyString = stringKey
        } else {
            keyString = String(describing: key)
        }
        if let encoded = keyString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) {
            return directory.appendingPathComponent(encoded).appendingPathExtension("box")
        }
        let fallback = "\(key.hashValue)_\(Int(Date().timeIntervalSince1970))"
        return directory.appendingPathComponent(fallback).appendingPathExtension("box")
    }

    private func enforceLRU() async {
        guard let maxSize, maxSize > 0 else { return }
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
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
