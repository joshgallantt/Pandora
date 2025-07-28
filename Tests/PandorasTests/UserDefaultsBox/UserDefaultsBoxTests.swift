//
//  UserDefaultsBoxTests.swift
//  Pandoras
//
//  Created by Josh Gallant on 13/07/2025.
//


import XCTest
@testable import Pandoras

final class UserDefaultsBoxTests: XCTestCase {
    private var storage: MockUserDefaultsBox!

    override func setUp() {
        super.setUp()
        storage = MockUserDefaultsBox(namespace: "UnitTestNamespace")
    }

    func test_givenCodableValue_whenPutAndGet_thenValueIsEqual() async throws {
        // Given
        struct Dummy: Codable, Sendable, Equatable { let value: String }
        let dummy = Dummy(value: "test")
        
        // When
        try await storage.put(key: "dummyKey", value: dummy)
        let retrieved: Dummy = try await storage.get("dummyKey")
        
        // Then
        XCTAssertEqual(dummy, retrieved)
    }

    func test_givenUnencodableValue_whenPut_thenEncodingFails() async {
        // Given
        struct BadNumber: Codable, Sendable {
            let value: Double
        }
        let bad = BadNumber(value: .nan)
        
        // When
        do {
            try await storage.put(key: "badKey", value: bad)
            XCTFail("Expected encoding failure")
        } catch let UserDefaultsStorageError.encodingFailed(namespace, key, underlyingError) {
            // Then
            XCTAssertEqual(namespace, "UnitTestNamespace")
            XCTAssertEqual(key, "badKey")
            XCTAssertNotNil(underlyingError)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_givenMissingKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "nonexistent"
        
        // When
        do {
            let _: String = try await storage.get(key)
            XCTFail("Expected value not found error")
        } catch let UserDefaultsStorageError.valueNotFound(namespace, foundKey) {
            // Then
            XCTAssertEqual(namespace, "UnitTestNamespace")
            XCTAssertEqual(foundKey, key)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_givenStoredString_whenGetAsInt_thenThrowsDecodingFailedOrTypeMismatch() async throws {
        // Given
        try await storage.put(key: "key", value: "stringValue")
        
        // When
        do {
            let _: Int = try await storage.get("key")
            XCTFail("Expected decoding failure")
        } catch let UserDefaultsStorageError.decodingFailed(namespace, key, underlyingError) {
            // Then
            XCTAssertEqual(namespace, "UnitTestNamespace")
            XCTAssertEqual(key, "key")
            XCTAssertNotNil(underlyingError)
        } catch let UserDefaultsStorageError.foundButTypeMismatch(namespace, key, _, _) {
            // Then
            XCTAssertEqual(namespace, "UnitTestNamespace")
            XCTAssertEqual(key, "key")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_givenKeyWithValue_whenRemove_thenGetThrowsValueNotFound() async throws {
        // Given
        try await storage.put(key: "intKey", value: 123)
        
        // When
        await storage.remove("intKey")
        
        // Then
        do {
            let _: Int = try await storage.get("intKey")
            XCTFail("Expected value not found after removal")
        } catch UserDefaultsStorageError.valueNotFound {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_givenKeys_whenClear_thenAllKeysIsEmpty() async throws {
        // Given
        try await storage.put(key: "key1", value: "value1")
        try await storage.put(key: "key2", value: "value2")
        
        // When
        let keysBefore = await storage.allKeys()
        await storage.clear()
        let keysAfter = await storage.allKeys()
        
        // Then
        XCTAssertEqual(Set(keysBefore), ["key1", "key2"])
        XCTAssertTrue(keysAfter.isEmpty)
    }

    func test_givenKeyExistsAndMissing_whenContains_thenReturnsCorrectBoolean() async throws {
        // Given
        try await storage.put(key: "exists", value: true)
        
        // When
        let containsExists = await storage.contains("exists")
        let containsMissing = await storage.contains("missing")
        
        // Then
        XCTAssertTrue(containsExists)
        XCTAssertFalse(containsMissing)
    }

    func test_givenEncodingFailedError_whenDescription_thenDescriptionIsCorrect() {
        // Given
        let error = NSError(domain: "testDomain", code: 1)
        let subject = UserDefaultsStorageError.encodingFailed(namespace: "TestSpace", key: "key1", underlyingError: error)
        
        // When
        let description = subject.description
        
        // Then
        XCTAssertTrue(description.contains("PersistentStorage TestSpace encoding failed for key 'key1':"))
        XCTAssertTrue(description.contains("testDomain"))
    }

    func test_givenDecodingFailedError_whenDescription_thenDescriptionIsCorrect() {
        // Given
        let error = NSError(domain: "decodeDomain", code: 2)
        let subject = UserDefaultsStorageError.decodingFailed(namespace: "OtherSpace", key: "key2", underlyingError: error)
        
        // When
        let description = subject.description
        
        // Then
        XCTAssertTrue(description.contains("PersistentStorage OtherSpace decoding failed for key 'key2':"))
        XCTAssertTrue(description.contains("decodeDomain"))
    }

    func test_givenValueNotFoundError_whenDescription_thenDescriptionIsCorrect() {
        // Given
        let subject = UserDefaultsStorageError.valueNotFound(namespace: "SomeSpace", key: "unknownKey")
        
        // When
        let description = subject.description
        
        // Then
        XCTAssertEqual(description, "PersistentStorage SomeSpace could not find value for key 'unknownKey'")
    }

    func test_givenTypeMismatchError_whenDescription_thenDescriptionIsCorrect() {
        // Given
        let subject = UserDefaultsStorageError.foundButTypeMismatch(
            namespace: "MismatchNS",
            key: "theKey",
            expected: String.self,
            found: Int.self
        )
        
        // When
        let description = subject.description
        
        // Then
        XCTAssertTrue(description.contains("PersistentStorage MismatchNS found value for key 'theKey' but type mismatch"))
        XCTAssertTrue(description.contains("expected String, found Int"))
    }
}
