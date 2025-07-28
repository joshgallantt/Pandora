//
//  MockUserDefaultsBox.swift
//  Pandoras
//
//  Created by Josh Gallant on 13/07/2025.
//


import XCTest
@testable import Pandoras

actor MockUserDefaultsBox: PandorasUserDefaultsBoxProtocol {
    let namespace: String
    private var storage: [String: Data] = [:]

    init(namespace: String = "TestNamespace") {
        self.namespace = namespace
    }

    func put<T: Encodable & Sendable>(key: String, value: T) async throws {
        do {
            let data = try JSONEncoder().encode(value)
            storage[key] = data
        } catch {
            throw UserDefaultsStorageError.encodingFailed(namespace: namespace, key: key, underlyingError: error)
        }
    }

    func get<T: Decodable & Sendable>(_ key: String) async throws -> T {
        guard let data = storage[key] else {
            throw UserDefaultsStorageError.valueNotFound(namespace: namespace, key: key)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw UserDefaultsStorageError.decodingFailed(namespace: namespace, key: key, underlyingError: error)
        }
    }

    func remove(_ key: String) async {
        storage.removeValue(forKey: key)
    }

    func clear() async {
        storage.removeAll()
    }

    func allKeys() async -> [String] {
        Array(storage.keys)
    }

    func contains(_ key: String) async -> Bool {
        storage[key] != nil
    }
}
