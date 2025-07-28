//
//  MockDiskBoxTests.swift
//  Pandora
//
//  Created by Josh Gallant on 27/07/2025.
//


import XCTest

final class MockDiskBoxTests: XCTestCase {
    private typealias Key = String
    private struct Value: Codable, Equatable { let id: Int }
    private var box: MockDiskBox<Key, Value>!

    override func setUp() async throws {
        box = MockDiskBox<Key, Value>()
    }

    func test_givenEmptyStore_whenGet_thenReturnsNil() async {
        let value = await box.get("nope")
        XCTAssertNil(value)
    }

    func test_givenValueInserted_whenGet_thenReturnsValue() async {
        let key = "abc"
        let expected = Value(id: 1)
        await box.put(key: key, value: expected)
        let value = await box.get(key)
        XCTAssertEqual(value, expected)
    }

    func test_givenKeyExists_whenRemove_thenValueIsGone() async {
        let key = "k"
        await box.put(key: key, value: Value(id: 42))
        await box.remove(key)
        let value = await box.get(key)
        XCTAssertNil(value)
    }

    func test_givenMultipleKeys_whenClear_thenAllGone() async {
        await box.put(key: "a", value: Value(id: 1))
        await box.put(key: "b", value: Value(id: 2))
        await box.clear()
        let valueA = await box.get("a")
        let valueB = await box.get("b")
        XCTAssertNil(valueA)
        XCTAssertNil(valueB)
    }

    func test_givenKeysInserted_whenClearAll_thenStoreUnaffected() async {
        await box.put(key: "a", value: Value(id: 1))
        MockDiskBox<Key, Value>.clearAll()
        let stillThere = await box.get("a")
        XCTAssertEqual(stillThere, Value(id: 1))
    }
    
    func test_givenValueWithExpiry_whenExpired_thenGetReturnsNil() async throws {
        // Given
        let key = "expire"
        let value = Value(id: 99)
        await box.put(key: key, value: value, expiresAfter: 0.05)
        // When
        try await Task.sleep(nanoseconds: 100_000_000)
        let result = await box.get(key)
        // Then
        XCTAssertNil(result)
    }

    func test_givenValueWithExpiry_whenNotExpired_thenGetReturnsValue() async {
        // Given
        let key = "not-expired"
        let value = Value(id: 1)
        await box.put(key: key, value: value, expiresAfter: 1)
        // When
        let result = await box.get(key)
        // Then
        XCTAssertEqual(result, value)
    }

    func test_givenValueWithNoExpiry_whenGet_thenReturnsValue() async {
        // Given
        let key = "no-expiry"
        let value = Value(id: 5)
        await box.put(key: key, value: value, expiresAfter: nil)
        // When
        let result = await box.get(key)
        // Then
        XCTAssertEqual(result, value)
    }

    func test_givenExpiredValue_whenGet_thenRemovesValueFromStore() async throws {
        // Given
        let key = "auto-purge"
        let value = Value(id: 77)
        await box.put(key: key, value: value, expiresAfter: 0.05)
        try await Task.sleep(nanoseconds: 100_000_000)
        // When
        let result = await box.get(key)
        let secondResult = await box.get(key)
        // Then
        XCTAssertNil(result)
        XCTAssertNil(secondResult)
    }
}
