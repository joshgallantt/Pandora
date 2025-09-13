//
//  HybridBoxTests.swift
//  Pandora
//
//  Created by Josh Gallant on 27/07/2025.
//


import XCTest
import Combine
@testable import Pandora

final class HybridBoxTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    func test_givenMock_whenInit_thenNamespaceIsSet() {
        // Given
        let namespace = "testNamespace"

        // When
        let mock = MockHybridBox<String, String>(namespace: namespace)

        // Then
        XCTAssertEqual(mock.namespace, namespace)
    }

    func test_givenNoValue_whenPublisherSubscribed_thenEmitsNil() {
        // Given
        let mock = MockHybridBox<String, String>()
        let key = "missing"
        let expectation = XCTestExpectation(description: "Expect nil on subscription")

        // When
        mock.publisher(for: key)
            .sink { value in
                XCTAssertNil(value)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // Then
        wait(for: [expectation], timeout: 1.0)
    }

    func test_givenValue_whenPutAndGet_thenPublisherEmitsValue() async {
        // Given
        let mock = MockHybridBox<String, String>()
        let key = "user"
        let value = "Josh"
        let expectation = XCTestExpectation(description: "Expect publisher to emit value")
        var received: [String?] = []

        mock.publisher(for: key)
            .sink {
                received.append($0)
                if received.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        mock.put(key: key, value: value, expiresAfter: nil)
        let result = await mock.get(key)

        // Then
        XCTAssertEqual(result, value)
        XCTAssertEqual(received, [nil, value])
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func test_givenValue_whenRemove_thenPublisherEmitsNil() async {
        // Given
        let mock = MockHybridBox<String, String>()
        let key = "token"
        let value = "abc123"
        let expectation = XCTestExpectation(description: "Expect nil emission after removal")
        var emissions: [String?] = []

        mock.put(key: key, value: value, expiresAfter: nil)

        mock.publisher(for: key)
            .sink {
                emissions.append($0)
                if emissions.contains(nil) {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        mock.remove(key)
        let result = await mock.get(key)

        // Then
        XCTAssertNil(result)
        XCTAssertEqual(emissions, [value, nil])
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func test_givenMultipleValues_whenClear_thenAllValuesRemovedAndPublishersEmitNil() async {
        // Given
        let mock = MockHybridBox<String, String>()
        let keys = ["a", "b", "c"]
        let values = ["1", "2", "3"]
        var emissions: [String: [String?]] = [:]
        let expectation = XCTestExpectation(description: "All publishers emit nil after clear")
        expectation.expectedFulfillmentCount = keys.count

        for (key, value) in zip(keys, values) {
            mock.put(key: key, value: value, expiresAfter: nil)
            emissions[key] = []
            mock.publisher(for: key)
                .sink {
                    emissions[key]?.append($0)
                    if $0 == nil {
                        expectation.fulfill()
                    }
                }
                .store(in: &cancellables)
        }

        // When
        mock.clear()

        // Then
        for key in keys {
            let result = await mock.get(key)
            XCTAssertNil(result)
            XCTAssertEqual(emissions[key], [values[keys.firstIndex(of: key)!], nil])
        }

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func test_whenClearAllCalled_thenDoesNotCrash() {
        // Given / When / Then
        MockHybridBox<String, String>.clearAll()
        // No state to verify, should not crash
    }

    // MARK: - emitInitial Tests

    func test_givenValueExists_whenPublisherWithEmitInitialTrue_thenEmitsCurrentValueImmediately() {
        // Given
        let mock = MockHybridBox<String, String>()
        mock.put(key: "test", value: "hello", expiresAfter: nil)
        let expectation = XCTestExpectation(description: "Publisher emits current value")
        var received: [String?] = []

        // When
        mock.publisher(for: "test", emitInitial: true)
            .sink { value in
                received.append(value)
                if received.count == 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(received, ["hello"])
    }

    func test_givenValueExists_whenPublisherWithEmitInitialFalse_thenDoesNotEmitCurrentValue() {
        // Given
        let mock = MockHybridBox<String, String>()
        mock.put(key: "test", value: "hello", expiresAfter: nil)
        let expectation = XCTestExpectation(description: "Publisher does not emit current value")
        var received: [String?] = []

        // When
        mock.publisher(for: "test", emitInitial: false)
            .sink { value in
                received.append(value)
                // Should not be called immediately
            }
            .store(in: &cancellables)

        // Wait a bit to ensure no immediate emission
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(received.isEmpty)
    }

    func test_givenValueExists_whenPublisherWithEmitInitialFalse_thenEmitsFutureUpdates() {
        // Given
        let mock = MockHybridBox<String, String>()
        mock.put(key: "test", value: "hello", expiresAfter: nil)
        let expectation = XCTestExpectation(description: "Publisher emits future updates")
        var received: [String?] = []

        mock.publisher(for: "test", emitInitial: false)
            .sink { value in
                received.append(value)
                if received.count == 2 { // Should get "world", then nil
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        mock.put(key: "test", value: "world", expiresAfter: nil)
        mock.remove("test")

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(received, ["world", nil])
    }

    func test_givenNoValue_whenPublisherWithEmitInitialTrue_thenEmitsNilImmediately() {
        // Given
        let mock = MockHybridBox<String, String>()
        let expectation = XCTestExpectation(description: "Publisher emits nil immediately")
        var received: [String?] = []

        // When
        mock.publisher(for: "missing", emitInitial: true)
            .sink { value in
                received.append(value)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(received, [nil])
    }

    func test_givenNoValue_whenPublisherWithEmitInitialFalse_thenDoesNotEmitInitially() {
        // Given
        let mock = MockHybridBox<String, String>()
        let expectation = XCTestExpectation(description: "Publisher does not emit initially")
        var received: [String?] = []

        mock.publisher(for: "missing", emitInitial: false)
            .sink { value in
                received.append(value)
                // Should not be called initially
            }
            .store(in: &cancellables)

        // Wait to ensure no immediate emission
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(received.isEmpty)
    }

    func test_givenDefaultEmitInitial_whenPublisherCalled_thenEmitsCurrentValue() {
        // Given
        let mock = MockHybridBox<String, String>()
        mock.put(key: "default", value: "test", expiresAfter: nil)
        let expectation = XCTestExpectation(description: "Default behavior emits current value")
        var received: [String?] = []

        // When (using default parameter)
        mock.publisher(for: "default")
            .sink { value in
                received.append(value)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(received, ["test"])
    }
}

