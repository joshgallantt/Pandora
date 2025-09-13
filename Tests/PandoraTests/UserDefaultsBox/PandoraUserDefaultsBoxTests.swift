//
//  TestValue.swift
//  Pandora
//
//  Created by Josh Gallant on 08/08/2025.
//


import XCTest
import Combine
@testable import Pandora

private struct TestValue: Codable, Equatable {
    let id: Int
}

final class PandoraUserDefaultsBoxTests: XCTestCase {
    
    private var userDefaultsSuiteName: String!
    private var userDefaults: UserDefaults!
    private var iCloudStore: MockICloudStore!
    private var memory: MockMemoryBox<String, TestValue>!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        userDefaultsSuiteName = UUID().uuidString
        userDefaults = UserDefaults(suiteName: userDefaultsSuiteName)
        iCloudStore = MockICloudStore()
        memory = MockMemoryBox<String, TestValue>()
        cancellables = []
    }
    
    override func tearDown() {
        userDefaults.removePersistentDomain(forName: userDefaultsSuiteName)
        Pandora.deleteAllLocalStorage()
        cancellables = nil
        super.tearDown()
    }
    
    func test_givenValueInMemory_whenGet_thenReturnsImmediately() async {
        // Given
        let sut = makeSUT()
        let expected = TestValue(id: 1)
        memory.put(key: "foo", value: expected)
        
        // When
        let result = await sut.get("foo")
        
        // Then
        XCTAssertEqual(result, expected)
    }
    
    func test_givenValueInUserDefaults_whenGet_thenCachesInMemoryAndReturns() async throws {
        // Given
        let sut = makeSUT()
        let expected = TestValue(id: 2)
        let data = try JSONEncoder().encode(expected)
        userDefaults.set(data, forKey: "ns.foo")
        
        // When
        let result = await sut.get("foo")
        
        // Then
        XCTAssertEqual(result, expected)
        XCTAssertEqual(memory.get("foo"), expected)
    }
    
    func test_givenValueInICloud_whenGet_thenCachesInMemoryAndUserDefaultsAndReturns() async throws {
        // Given
        let sut = makeSUT()
        let expected = TestValue(id: 3)
        let data = try JSONEncoder().encode(expected)
        iCloudStore.set(data, forKey: "ns.foo")
        
        // When
        let result = await sut.get("foo")
        
        // Then
        XCTAssertEqual(result, expected)
        XCTAssertEqual(memory.get("foo"), expected)
        XCTAssertEqual(userDefaults.data(forKey: "ns.foo"), data)
    }
    
    func test_givenNoValueAnywhere_whenGet_thenReturnsNil() async {
        // Given
        let sut = makeSUT()
        
        // When
        let result = await sut.get("missing")
        
        // Then
        XCTAssertNil(result)
    }
    
    func test_putStoresInMemoryUserDefaultsAndICloud() throws {
        // Given
        let sut = makeSUT()
        let value = TestValue(id: 10)
        
        // When
        sut.put(key: "abc", value: value)
        
        // Then
        XCTAssertEqual(memory.get("abc"), value)
        XCTAssertNotNil(userDefaults.data(forKey: "ns.abc"))
        XCTAssertNotNil(iCloudStore.data(forKey: "ns.abc"))
    }
    
    func test_putWithoutICloud_storesOnlyMemoryAndUserDefaults() {
        // Given
        let sut = makeSUT(iCloud: false)
        let value = TestValue(id: 20)
        
        // When
        sut.put(key: "noicloud", value: value)
        
        // Then
        XCTAssertEqual(memory.get("noicloud"), value)
        XCTAssertNotNil(userDefaults.data(forKey: "ns.noicloud"))
    }
    
    func test_removeDeletesFromAllStoresAndSyncsICloud() {
        // Given
        let sut = makeSUT()
        memory.put(key: "rm", value: TestValue(id: 1))
        userDefaults.set(Data(), forKey: "ns.rm")
        iCloudStore.set(Data(), forKey: "ns.rm")
        
        // When
        sut.remove("rm")
        
        // Then
        XCTAssertNil(memory.get("rm"))
        XCTAssertNil(userDefaults.object(forKey: "ns.rm"))
        XCTAssertNil(iCloudStore.object(forKey: "ns.rm"))
        XCTAssertTrue(iCloudStore.didSynchronize)
    }
    
    func test_removeWithoutICloud_deletesFromMemoryAndUserDefaultsOnly() {
        // Given
        let sut = makeSUT(iCloud: false)
        memory.put(key: "rm", value: TestValue(id: 1))
        userDefaults.set(Data(), forKey: "ns.rm")
        
        // When
        sut.remove("rm")
        
        // Then
        XCTAssertNil(memory.get("rm"))
        XCTAssertNil(userDefaults.object(forKey: "ns.rm"))
    }
    
    func test_clearRemovesAllWithPrefixFromAllStores() {
        // Given
        let sut = makeSUT()
        memory.put(key: "x", value: TestValue(id: 1))
        userDefaults.set(Data(), forKey: "ns.x")
        userDefaults.set(Data(), forKey: "other")
        iCloudStore.set(Data(), forKey: "ns.x")
        iCloudStore.set(Data(), forKey: "other")
        
        // When
        sut.clear()
        
        // Then
        XCTAssertNil(memory.get("x"))
        XCTAssertNotNil(userDefaults.object(forKey: "other"))
        XCTAssertNil(userDefaults.object(forKey: "ns.x"))
        XCTAssertNotNil(iCloudStore.object(forKey: "other"))
        XCTAssertNil(iCloudStore.object(forKey: "ns.x"))
        XCTAssertTrue(iCloudStore.didSynchronize)
    }
    
    func test_clearWithoutICloud_onlyTouchesUserDefaultsAndMemory() {
        // Given
        let sut = makeSUT(iCloud: false)
        memory.put(key: "y", value: TestValue(id: 1))
        userDefaults.set(Data(), forKey: "ns.y")
        
        // When
        sut.clear()
        
        // Then
        XCTAssertNil(memory.get("y"))
        XCTAssertNil(userDefaults.object(forKey: "ns.y"))
    }
    
    func test_publisherEmitsChangesFromMemory() {
        // Given
        let sut = makeSUT()
        var received: [TestValue?] = []
        sut.publisher(for: "pub").sink { received.append($0) }.store(in: &cancellables)
        
        // When
        memory.put(key: "pub", value: TestValue(id: 1))
        memory.remove("pub")
        
        // Then
        XCTAssertTrue(received.contains(nil))
    }
    
    func test_iCloudDidChangeWithMatchingKey_updatesMemoryAndUserDefaults() throws {
        // Given
        let sut = makeSUT()
        let value = TestValue(id: 42)
        let data = try JSONEncoder().encode(value)
        iCloudStore.set(data, forKey: "ns.match")
        
        // When
        sut.iCloudDidChange(
            Notification(
                name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: iCloudStore,
                userInfo: [NSUbiquitousKeyValueStoreChangedKeysKey: ["ns.match"]]
            )
        )
        
        // Allow async Task to run
        let exp = expectation(description: "wait")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1)
        
        // Then
        XCTAssertEqual(memory.get("match"), value)
        XCTAssertEqual(userDefaults.data(forKey: "ns.match"), data)
    }
    
    func test_iCloudDidChangeWithMissingData_removesFromMemoryAndUserDefaults() {
        // Given
        let sut = makeSUT()
        memory.put(key: "gone", value: TestValue(id: 9))
        userDefaults.set(Data(), forKey: "ns.gone")
        
        // When
        sut.iCloudDidChange(Notification(name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                         object: iCloudStore,
                                         userInfo: [NSUbiquitousKeyValueStoreChangedKeysKey: ["ns.gone"]]))
        
        let exp = expectation(description: "wait")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1)
        
        // Then
        XCTAssertNil(memory.get("gone"))
        XCTAssertNil(userDefaults.object(forKey: "ns.gone"))
    }
    
    func test_iCloudDidChangeWithNonMatchingKey_doesNothing() {
        // Given
        let sut = makeSUT()
        memory.put(key: "keep", value: TestValue(id: 1))
        
        // When
        sut.iCloudDidChange(Notification(name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                         object: iCloudStore,
                                         userInfo: [NSUbiquitousKeyValueStoreChangedKeysKey: ["otherprefix.key"]]))
        
        // Then
        XCTAssertEqual(memory.get("keep"), TestValue(id: 1))
    }

    // MARK: - emitInitial Tests

    func test_givenValueExists_whenPublisherWithEmitInitialTrue_thenEmitsCurrentValueImmediately() {
        // Given
        let sut = makeSUT()
        let value = TestValue(id: 42)
        memory.put(key: "test", value: value)
        let expectation = XCTestExpectation(description: "Publisher emits current value")
        var received: [TestValue?] = []

        // When
        sut.publisher(for: "test", emitInitial: true)
            .sink { value in
                received.append(value)
                if received.count == 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(received, [value])
    }

    func test_givenValueExists_whenPublisherWithEmitInitialFalse_thenDoesNotEmitCurrentValue() {
        // Given
        let sut = makeSUT()
        let value = TestValue(id: 42)
        memory.put(key: "test", value: value)
        let expectation = XCTestExpectation(description: "Publisher does not emit current value")
        var received: [TestValue?] = []

        // When
        sut.publisher(for: "test", emitInitial: false)
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
        let sut = makeSUT()
        let initialValue = TestValue(id: 42)
        let updatedValue = TestValue(id: 99)
        memory.put(key: "test", value: initialValue)
        let expectation = XCTestExpectation(description: "Publisher emits future updates")
        var received: [TestValue?] = []

        sut.publisher(for: "test", emitInitial: false)
            .sink { value in
                received.append(value)
                if received.count == 2 { // Should get updatedValue, then nil
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When
        memory.put(key: "test", value: updatedValue)
        memory.remove("test")

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(received, [updatedValue, nil])
    }

    func test_givenNoValue_whenPublisherWithEmitInitialTrue_thenEmitsNilImmediately() {
        // Given
        let sut = makeSUT()
        let expectation = XCTestExpectation(description: "Publisher emits nil immediately")
        var received: [TestValue?] = []

        // When
        sut.publisher(for: "missing", emitInitial: true)
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
        let sut = makeSUT()
        let expectation = XCTestExpectation(description: "Publisher does not emit initially")
        var received: [TestValue?] = []

        sut.publisher(for: "missing", emitInitial: false)
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
        let sut = makeSUT()
        let value = TestValue(id: 123)
        memory.put(key: "default", value: value)
        let expectation = XCTestExpectation(description: "Default behavior emits current value")
        var received: [TestValue?] = []

        // When (using default parameter)
        sut.publisher(for: "default")
            .sink { value in
                received.append(value)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // Then
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(received, [value])
    }
    
    // MARK: - Helpers
    
    private func makeSUT(iCloud: Bool = true) -> PandoraUserDefaultsBox<TestValue> {
        PandoraUserDefaultsBox<TestValue>(
            namespace: "ns",
            memory: memory,
            userDefaults: userDefaults,
            iCloudStore: iCloud ? iCloudStore : nil,
            iCloudBacked: iCloud
        )
    }
}

