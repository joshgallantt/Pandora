//
//  MemoryBoxTests.swift
//  Pandora
//
//  Created by Josh Gallant on 13/07/2025.
//


import XCTest
import Combine

final class MemoryBoxTests: XCTestCase {

    typealias Key = String
    typealias Value = Int

    var cache: MockMemoryBox<Key, Value>!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cache = MockMemoryBox()
        cancellables = []
    }

    override func tearDown() {
        cache = nil
        cancellables = nil
        super.tearDown()
    }

    func test_givenEmptyCache_whenPut_thenGetReturnsValue() {
        // Given
        // A new cache

        // When
        cache.put(key: "a", value: 1)

        // Then
        XCTAssertEqual(cache.get("a"), 1)
        XCTAssertNil(cache.get("b"))
    }

    func test_givenCacheWithKey_whenRemove_thenKeyIsRemoved() {
        // Given
        cache.put(key: "a", value: 2)

        // When
        cache.remove("a")

        // Then
        XCTAssertNil(cache.get("a"))
    }

    func test_givenNonExistentKey_whenRemove_thenKeyIsAbsent() {
        // Given
        // The key "z" does not exist

        // When
        cache.remove("z")

        // Then
        XCTAssertNil(cache.get("z"))
    }


    func test_givenNoValue_whenPublisherSubscribesAndPut_thenEmitsNilThenValue() {
        // Given
        let expectation = self.expectation(description: "Publisher emits value")
        var received: [Value?] = []
        cache.publisher(for: "pub").sink { value in
            received.append(value)
            if received.count == 2 { expectation.fulfill() }
        }.store(in: &cancellables)

        // When
        cache.put(key: "pub", value: 99)

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(received, [nil, 99])
    }

    func test_givenValue_whenPublisherSubscribesAndRemove_thenEmitsValueThenNil() {
        // Given
        cache.put(key: "pub", value: 100)
        let expectation = self.expectation(description: "Publisher emits nil after removal")
        var values: [Value?] = []
        cache.publisher(for: "pub").sink { value in
            values.append(value)
            if values.contains(nil) { expectation.fulfill() }
        }.store(in: &cancellables)

        // When
        cache.remove("pub")

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(values.contains(nil))
    }

    func test_givenValue_whenPublisherSubscribesAndClear_thenEmitsValueThenNil() {
        // Given
        cache.put(key: "x", value: 1)
        let expectation = self.expectation(description: "Publisher emits nil after clear")
        var values: [Value?] = []
        cache.publisher(for: "x").sink { value in
            values.append(value)
            if values.contains(nil) { expectation.fulfill() }
        }.store(in: &cancellables)

        // When
        cache.clear()

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(values.contains(nil))
    }

    func test_givenMultipleSubscribers_whenPut_thenAllSubscribersAreNotified() {
        // Given
        cache.put(key: "abc", value: 10)
        let expectation1 = expectation(description: "Subscriber 1 notified")
        let expectation2 = expectation(description: "Subscriber 2 notified")

        cache.publisher(for: "abc").sink { value in
            if value == 20 { expectation1.fulfill() }
        }.store(in: &cancellables)

        cache.publisher(for: "abc").sink { value in
            if value == 20 { expectation2.fulfill() }
        }.store(in: &cancellables)

        // When
        cache.put(key: "abc", value: 20)

        // Then
        wait(for: [expectation1, expectation2], timeout: 1)
    }

    func test_givenNonExistentKey_whenPublisherSubscribes_thenEmitsNil() {
        // Given
        let expectation = self.expectation(description: "Initial value nil")

        // When
        cache.publisher(for: "nope").sink { value in
            // Then
            XCTAssertNil(value)
            expectation.fulfill()
        }.store(in: &cancellables)

        wait(for: [expectation], timeout: 1)
    }
    

    func test_givenMock_whenPutWithPerKeyExpiry_thenGetReturnsValue() {
        // Given
        // When
        cache.put(key: "exp1", value: 123, expiresAfter: 2) // 2s TTL (ignored in mock)
        cache.put(key: "exp2", value: 456, expiresAfter: nil) // nil TTL (should work)
        cache.put(key: "exp3", value: 789, expiresAfter: 0) // 0s TTL (should work)

        // Then
        XCTAssertEqual(cache.get("exp1"), 123)
        XCTAssertEqual(cache.get("exp2"), 456)
        XCTAssertEqual(cache.get("exp3"), 789)
    }

    func test_givenMock_whenPutWithPerKeyExpiry_thenPublisherEmitsCorrectly() {
        // Given
        let expectation = self.expectation(description: "Publisher emits correct value with per-key expiry")
        var received: [Value?] = []
        cache.publisher(for: "expPub").sink { value in
            received.append(value)
            if received.count == 2 { expectation.fulfill() }
        }.store(in: &cancellables)

        // When
        cache.put(key: "expPub", value: 555, expiresAfter: 3)

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(received, [nil, 555])
    }

    func test_givenMock_whenPutWithPerKeyExpiryOverridesGlobalPut_thenLastWins() {
        // Given
        cache.put(key: "over", value: 1)
        cache.put(key: "over", value: 2, expiresAfter: 42)
        cache.put(key: "over", value: 3)

        // When & Then
        XCTAssertEqual(cache.get("over"), 3)
    }

    func test_givenMock_whenPutWithNilExpiry_thenBehavesLikeNormalPut() {
        // Given
        cache.put(key: "nil", value: 10, expiresAfter: nil)
        // When & Then
        XCTAssertEqual(cache.get("nil"), 10)
    }

}
