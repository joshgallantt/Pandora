//
//  PandoraHybridBoxTests.swift
//  Pandora
//
//  Created by Josh Gallant on 27/07/2025.
//

import XCTest
import Combine
@testable import Pandora

final class PandoraHybridBoxTests: XCTestCase {
    func test_publicInit_setsAllParametersAndUnderlyingBoxes() {
        // Given
        let namespace = "publicInitNS"
        let memoryMaxSize = 7
        let memoryExpires: TimeInterval? = 12
        let diskMaxSize: Int? = 9
        let diskExpires: TimeInterval? = 21

        // When
        let box = PandoraHybridBox<String, String>(
            namespace: namespace,
            memoryMaxSize: memoryMaxSize,
            memoryExpiresAfter: memoryExpires,
            diskMaxSize: diskMaxSize,
            diskExpiresAfter: diskExpires
        )

        // Then
        XCTAssertEqual(box.namespace, namespace)

        let mirror = Mirror(reflecting: box)
        let memory = mirror.children.first { $0.label == "memory" }?.value as? PandoraMemoryBox<String, String>
        let disk = mirror.children.first { $0.label == "disk" }?.value as? PandoraDiskBox<String, String>
        let memoryExpiresAfter = mirror.children.first { $0.label == "memoryExpiresAfter" }?.value as? TimeInterval
        let diskExpiresAfter = mirror.children.first { $0.label == "diskExpiresAfter" }?.value as? TimeInterval

        XCTAssertNotNil(memory)
        XCTAssertNotNil(disk)
        XCTAssertEqual(memoryExpiresAfter, memoryExpires)
        XCTAssertEqual(diskExpiresAfter, diskExpires)
    }

    private typealias Key = String
    private typealias Value = String

    private var cancellables: Set<AnyCancellable>!
    private var memory: PandoraMemoryBox<Key, Value>!
    private var disk: PandoraDiskBox<Key, Value>!
    private var box: PandoraHybridBox<Key, Value>!

    override func setUp() {
        super.setUp()
        cancellables = []
        memory = PandoraMemoryBox<Key, Value>()
        disk = PandoraDiskBox<Key, Value>(namespace: "test")
        box = PandoraHybridBox(
            namespace: "test",
            memory: memory,
            disk: disk,
            memoryExpiresAfter: nil,
            diskExpiresAfter: nil
        )
    }

    override func tearDown() {
        Pandora.deleteAllLocalStorage()
        cancellables = nil
        memory = nil
        disk = nil
        box = nil
        super.tearDown()
    }

    // MARK: - Get/Put

    func test_givenValueInMemory_whenGet_thenReturnsMemoryValue() async {
        // Given
        memory.put(key: "key", value: "mem", expiresAfter: nil)

        // When
        let result = await box.get("key")

        // Then
        XCTAssertEqual(result, "mem")
    }

    func test_givenValueOnlyInDisk_whenGet_thenLoadsToMemoryAndReturns() async {
        // Given
        await disk.put(key: "key", value: "disk", expiresAfter: nil)

        // When
        let result = await box.get("key")

        // Then
        XCTAssertEqual(result, "disk")
        XCTAssertEqual(memory.get("key"), "disk")
    }

    func test_givenPut_thenValueStoredInMemoryAndDisk() async {
        // Given
        let key = "k"
        let value = "v"

        // When
        box.put(key: key, value: value)

        // Wait for disk write
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(memory.get(key), value)
        let diskValue = await disk.get(key)
        XCTAssertEqual(diskValue, value)
    }

    // MARK: - Remove

    func test_givenExistingKey_whenRemove_thenDeletedFromMemoryAndDisk() async {
        // Given
        box.put(key: "toRemove", value: "v")
        try? await Task.sleep(nanoseconds: 100_000_000)

        // When
        box.remove("toRemove")
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertNil(memory.get("toRemove"))
        let diskValue = await disk.get("toRemove")
        XCTAssertNil(diskValue)
    }

    // MARK: - Clear

    func test_givenValuesStored_whenClear_thenBothLayersEmptied() async {
        // Given
        box.put(key: "k1", value: "v1")
        box.put(key: "k2", value: "v2")
        try? await Task.sleep(nanoseconds: 100_000_000)

        // When
        box.clear()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertNil(memory.get("k1"))
        XCTAssertNil(memory.get("k2"))
        let diskValue1 = await disk.get("k1")
        let diskValue2 = await disk.get("k2")
        XCTAssertNil(diskValue1)
        XCTAssertNil(diskValue2)
    }

    // MARK: - Publisher

    func test_givenKey_whenPut_thenPublisherEmitsValue() {
        // Given
        let expectation = expectation(description: "Publisher emits value")
        var received: [Value?] = []

        box.publisher(for: "pub").sink { value in
            received.append(value)
            if received.count == 2 { expectation.fulfill() }
        }.store(in: &cancellables)

        // When
        box.put(key: "pub", value: "value")

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(received, [nil, "value"])
    }

    func test_givenKey_whenRemove_thenPublisherEmitsNil() {
        // Given
        box.put(key: "rem", value: "gone")
        let expectation = expectation(description: "Publisher emits nil")
        var values: [Value?] = []

        box.publisher(for: "rem").sink { val in
            values.append(val)
            if values.contains(nil) { expectation.fulfill() }
        }.store(in: &cancellables)

        // When
        box.remove("rem")

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(values.contains(nil))
    }

    // MARK: - Expiry Passthrough

    func test_givenPerKeyExpiry_whenPut_thenDiskHonorsExpiry() async throws {
        // Given
        let key = "exp"
        let value = "temp"
        box.put(key: key, value: value, expiresAfter: 0.05)

        // When
        try await Task.sleep(nanoseconds: 100_000_000)
        let result = await box.get(key)

        // Then
        XCTAssertNil(result)
    }

    // MARK: - emitInitial Tests

    func test_givenValueExists_whenPublisherWithEmitInitialTrue_thenEmitsCurrentValueImmediately() {
        // Given
        box.put(key: "test", value: "hello")
        let expectation = expectation(description: "Publisher emits current value")
        var received: [Value?] = []

        // When
        box.publisher(for: "test", emitInitial: true)
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
        box.put(key: "test", value: "hello")
        let expectation = expectation(description: "Publisher does not emit current value")
        var received: [Value?] = []

        // When
        box.publisher(for: "test", emitInitial: false)
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
        box.put(key: "test", value: "hello")
        let expectation = expectation(description: "Publisher emits future updates")
        var received: [Value?] = []

        box.publisher(for: "test", emitInitial: false)
            .sink { value in
                received.append(value)
                if received.count == 2 { // Should get "world", then nil
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        box.put(key: "test", value: "world")
        box.remove("test")

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(received, ["world", nil])
    }

    func test_givenNoValue_whenPublisherWithEmitInitialTrue_thenEmitsNilImmediately() {
        // Given
        let expectation = expectation(description: "Publisher emits nil immediately")
        var received: [Value?] = []

        // When
        box.publisher(for: "missing", emitInitial: true)
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
        let expectation = expectation(description: "Publisher does not emit initially")
        var received: [Value?] = []

        box.publisher(for: "missing", emitInitial: false)
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
        box.put(key: "default", value: "test")
        let expectation = expectation(description: "Default behavior emits current value")
        var received: [Value?] = []

        // When (using default parameter)
        box.publisher(for: "default")
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
