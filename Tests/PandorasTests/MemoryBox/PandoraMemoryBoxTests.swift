//
//  PandorasMemoryBoxTests.swift
//  Pandoras
//
//  Created by Josh Gallant on 13/07/2025.
//


import XCTest
import Combine

@testable import Pandoras

final class PandorasMemoryBoxTests: XCTestCase {
    typealias Cache = PandorasMemoryBox<String, Int>
    var cache: Cache!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    override func tearDown() {
        cache = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initialisation

    func test_givenNegativeMaxSize_whenInit_thenEvictsOldest() {
        // Given
        cache = Cache(maxSize: -10)
        cache.put(key: "x", value: 1)
        // When
        for i in 0..<500 { cache.put(key: "n\(i)", value: i) }
        cache.put(key: "y", value: 2)
        // Then
        XCTAssertNil(cache.get("x"))
        XCTAssertNotNil(cache.get("y"))
    }

    func test_givenNegativeExpiresAfter_whenInit_thenNeverExpires() {
        cache = Cache(expiresAfter: -1)
        cache.put(key: "x", value: 1)
        usleep(100_000)
        XCTAssertEqual(cache.get("x"), 1)
    }

    func test_givenNilExpiresAfter_whenInit_thenNeverExpires() {
        cache = Cache(expiresAfter: nil)
        cache.put(key: "a", value: 1)
        usleep(100_000)
        XCTAssertEqual(cache.get("a"), 1)
    }

    func test_givenZeroExpiresAfter_whenInit_thenNeverExpires() {
        cache = Cache(expiresAfter: 0)
        cache.put(key: "b", value: 2)
        usleep(100_000)
        XCTAssertEqual(cache.get("b"), 2)
    }

    // MARK: - Basic Put/Get/Remove

    func test_givenEmptyCache_whenPut_thenGetReturnsValue() {
        cache = Cache()
        cache.put(key: "a", value: 10)
        XCTAssertEqual(cache.get("a"), 10)
        XCTAssertNil(cache.get("b"))
    }

    func test_givenKeyInCache_whenRemove_thenValueRemoved() {
        cache = Cache()
        cache.put(key: "x", value: 42)
        cache.remove("x")
        XCTAssertNil(cache.get("x"))
        let exp = expectation(description: "Publisher sends nil")
        cache.publisher(for: "x").sink { value in
            XCTAssertNil(value)
            exp.fulfill()
        }.store(in: &cancellables)
        wait(for: [exp], timeout: 1)
    }

    func test_givenNonexistentKey_whenRemove_thenDoesNotCrashAndGetReturnsNil() {
        cache = Cache()
        cache.remove("not-there")
        XCTAssertNil(cache.get("not-there"))
    }

    // MARK: - Clear

    func test_givenCacheWithValues_whenClear_thenAllRemovedAndPublishersEmitNil() {
        cache = Cache()
        cache.put(key: "a", value: 1)
        cache.put(key: "b", value: 2)
        let exp1 = expectation(description: "Publisher for a sends nil")
        let exp2 = expectation(description: "Publisher for b sends nil")
        cache.publisher(for: "a").sink { if $0 == nil { exp1.fulfill() } }.store(in: &cancellables)
        cache.publisher(for: "b").sink { if $0 == nil { exp2.fulfill() } }.store(in: &cancellables)
        cache.clear()
        XCTAssertNil(cache.get("a"))
        XCTAssertNil(cache.get("b"))
        wait(for: [exp1, exp2], timeout: 1)
    }

    // MARK: - LRU eviction

    func test_givenMaxSize_whenPutBeyondLimit_thenEvictsLeastRecentlyUsed() {
        cache = Cache(maxSize: 2)
        cache.put(key: "one", value: 1)
        cache.put(key: "two", value: 2)
        cache.put(key: "three", value: 3)
        // Only "two" and "three" remain
        XCTAssertNil(cache.get("one"))
        XCTAssertEqual(cache.get("two"), 2)
        XCTAssertEqual(cache.get("three"), 3)
        // No more than 2 keys present
        XCTAssertEqual([cache.get("one"), cache.get("two"), cache.get("three")].compactMap { $0 }.count, 2)
    }

    func test_givenItemAccessed_whenPutBeyondLimit_thenEvictionOrderUpdated() {
        cache = Cache(maxSize: 2)
        cache.put(key: "one", value: 1)
        cache.put(key: "two", value: 2)
        _ = cache.get("one") // now "two" is oldest
        cache.put(key: "three", value: 3)
        XCTAssertEqual(cache.get("one"), 1)
        XCTAssertNil(cache.get("two"))
        XCTAssertEqual(cache.get("three"), 3)
    }

    // MARK: - TTL/Expiry

    func test_givenShortTTL_whenEntryExpires_thenIsRemoved() {
        cache = Cache(expiresAfter: 0.05)
        cache.put(key: "expiring", value: 123)
        XCTAssertEqual(cache.get("expiring"), 123)
        usleep(100_000)
        XCTAssertNil(cache.get("expiring"))
    }

    func test_givenExpiringEntry_whenExpires_thenPublisherSendsNil() {
        cache = Cache(expiresAfter: 0.05)
        let exp = expectation(description: "Publisher sends nil after expiry")
        cache.put(key: "expirePub", value: 88)
        cache.publisher(for: "expirePub").sink { val in
            if val == nil { exp.fulfill() }
        }.store(in: &cancellables)
        usleep(100_000)
        _ = cache.get("expirePub")
        wait(for: [exp], timeout: 1)
    }

    func test_givenExpiredEntry_whenGet_thenPublisherEmitsNil() {
        cache = Cache(expiresAfter: 0.05)
        cache.put(key: "a", value: 1)
        let exp = expectation(description: "Publisher emits nil after expired get")
        cache.publisher(for: "a").sink { v in
            if v == nil { exp.fulfill() }
        }.store(in: &cancellables)
        usleep(100_000)
        _ = cache.get("a")
        wait(for: [exp], timeout: 1)
    }

    func test_givenPerKeyExpiry_whenEntryExpires_thenIsRemoved() {
        cache = Cache(expiresAfter: 60)
        cache.put(key: "short", value: 1, expiresAfter: 0.05)
        XCTAssertEqual(cache.get("short"), 1)
        usleep(100_000)
        XCTAssertNil(cache.get("short"))
    }

    func test_givenPerKeyExpiry_whenExpires_thenPublisherSendsNil() {
        cache = Cache(expiresAfter: 60)
        let exp = expectation(description: "Publisher sends nil after per-key expiry")
        cache.put(key: "pubExpire", value: 99, expiresAfter: 0.05)
        cache.publisher(for: "pubExpire").sink { v in
            if v == nil { exp.fulfill() }
        }.store(in: &cancellables)
        usleep(100_000)
        _ = cache.get("pubExpire")
        wait(for: [exp], timeout: 1)
    }

    func test_givenPerKeyExpiryZero_whenGlobalTTLExists_thenNeverExpires() {
        cache = Cache(expiresAfter: 0.05)
        cache.put(key: "never", value: 10, expiresAfter: 0)
        usleep(100_000)
        XCTAssertEqual(cache.get("never"), 10)
    }

    func test_givenGlobalTTLAndPerKeyExpiryNil_whenExpires_thenUsesGlobalTTL() {
        cache = Cache(expiresAfter: 0.05)
        cache.put(key: "global", value: 55, expiresAfter: nil)
        usleep(100_000)
        XCTAssertNil(cache.get("global"))
    }

    func test_givenNoGlobalTTLAndPerKeyExpiryNil_thenNeverExpires() {
        cache = Cache(expiresAfter: nil)
        cache.put(key: "noExpire", value: 1, expiresAfter: nil)
        usleep(100_000)
        XCTAssertEqual(cache.get("noExpire"), 1)
    }

    func test_givenPutWithZeroOrNegativePerKeyTTL_thenNeverExpires() {
        cache = Cache(expiresAfter: -10)
        cache.put(key: "neg", value: 111, expiresAfter: -42)
        usleep(100_000)
        XCTAssertEqual(cache.get("neg"), 111)
        cache.put(key: "zero", value: 222, expiresAfter: 0)
        usleep(100_000)
        XCTAssertEqual(cache.get("zero"), 222)
    }

    // MARK: - Publishers

    func test_givenValueExists_whenPublisherSubscribes_thenEmitsCurrentValue() {
        cache = Cache()
        cache.put(key: "exists", value: 42)
        let exp = expectation(description: "Publisher emits current value")
        var results: [Int?] = []
        cache.publisher(for: "exists").sink { value in
            results.append(value)
            exp.fulfill()
        }.store(in: &cancellables)
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(results, [42])
    }

    func test_givenNoValue_whenPublisherSubscribesAndPut_thenEmitsNilThenValue() {
        cache = Cache()
        var results: [Int?] = []
        let exp = expectation(description: "Publisher emits on put")
        cache.publisher(for: "pubkey").sink { value in
            results.append(value)
            if results.count == 2 { exp.fulfill() }
        }.store(in: &cancellables)
        cache.put(key: "pubkey", value: 55)
        wait(for: [exp], timeout: 1)
        XCTAssertEqual(results, [nil, 55])
    }

    func test_givenValue_whenRemoved_thenPublisherEmitsNilAndResubscribeReceivesNil() {
        cache = Cache()
        let exp = expectation(description: "Publisher sends nil after removal")
        cache.put(key: "z", value: 5)
        cache.publisher(for: "z").sink { value in
            if value == nil { exp.fulfill() }
        }.store(in: &cancellables)
        cache.remove("z")
        wait(for: [exp], timeout: 1)
        let exp2 = expectation(description: "New subscriber gets nil")
        cache.publisher(for: "z").sink { value in
            XCTAssertNil(value)
            exp2.fulfill()
        }.store(in: &cancellables)
        wait(for: [exp2], timeout: 1)
    }

    func test_givenMultipleSubscribers_whenPut_thenAllAreNotified() {
        cache = Cache()
        cache.put(key: "shared", value: 99)
        let exp1 = expectation(description: "Sub1 notified")
        let exp2 = expectation(description: "Sub2 notified")
        cache.publisher(for: "shared").sink { value in
            if value == 42 { exp1.fulfill() }
        }.store(in: &cancellables)
        cache.publisher(for: "shared").sink { value in
            if value == 42 { exp2.fulfill() }
        }.store(in: &cancellables)
        cache.put(key: "shared", value: 42)
        wait(for: [exp1, exp2], timeout: 1)
    }

    func test_givenNonexistentKey_whenPublisherSubscribes_thenEmitsNil() {
        cache = Cache()
        let exp = expectation(description: "Publisher starts nil for missing key")
        cache.publisher(for: "nope").sink { value in
            XCTAssertNil(value)
            exp.fulfill()
        }.store(in: &cancellables)
        wait(for: [exp], timeout: 1)
    }

    func test_givenPublisher_whenKeyEvictedLRU_thenPublisherSendsNil() {
        cache = Cache(maxSize: 2)
        cache.put(key: "a", value: 1)
        cache.put(key: "b", value: 2)
        let exp = expectation(description: "Publisher for a receives nil on LRU eviction")
        cache.publisher(for: "a").sink { value in
            if value == nil { exp.fulfill() }
        }.store(in: &cancellables)
        cache.put(key: "c", value: 3)
        wait(for: [exp], timeout: 1)
        XCTAssertNil(cache.get("a"))
    }

    // MARK: - Miscellaneous

    func test_givenExistingKey_whenPutTwice_thenUpdatesValue() {
        cache = Cache()
        cache.put(key: "a", value: 1)
        cache.put(key: "a", value: 2)
        XCTAssertEqual(cache.get("a"), 2)
    }

}
