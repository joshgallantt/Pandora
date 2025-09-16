//
//  PublisherBehaviorTests.swift
//  PandoraTests
//
//  Created by Josh Gallant on 16/09/2025.
//

import XCTest
import Combine
@testable import Pandora

final class PublisherBehaviorTests: XCTestCase {
    
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = []
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Common Publisher Behavior Tests
    
    func test_publisherEmitsCurrentValueImmediately() {
        // Test MemoryBox
        let memoryBox = MockMemoryBox<String, String>()
        memoryBox.put(key: "test", value: "memory")
        
        let memoryExpectation = expectation(description: "MemoryBox emits current value")
        memoryBox.publisher(for: "test")
            .sink { value in
                XCTAssertEqual(value, "memory")
                memoryExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Test HybridBox
        let hybridBox = MockHybridBox<String, String>()
        hybridBox.put(key: "test", value: "hybrid", expiresAfter: nil)
        
        let hybridExpectation = expectation(description: "HybridBox emits current value")
        hybridBox.publisher(for: "test")
            .sink { value in
                XCTAssertEqual(value, "hybrid")
                hybridExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        waitForExpectations(timeout: 1.0)
    }
    
    func test_publisherEmitsNilForNonExistentKey() {
        // Test MemoryBox
        let memoryBox = MockMemoryBox<String, String>()
        
        let memoryExpectation = expectation(description: "MemoryBox emits nil")
        memoryBox.publisher(for: "nonexistent")
            .sink { value in
                XCTAssertNil(value)
                memoryExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Test HybridBox
        let hybridBox = MockHybridBox<String, String>()
        
        let hybridExpectation = expectation(description: "HybridBox emits nil")
        hybridBox.publisher(for: "nonexistent")
            .sink { value in
                XCTAssertNil(value)
                hybridExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        waitForExpectations(timeout: 1.0)
    }
    
    func test_publisherEmitsOnValueAdded() {
        // Test MemoryBox
        let memoryBox = MockMemoryBox<String, String>()
        
        let memoryExpectation = expectation(description: "MemoryBox emits on value added")
        memoryBox.publisher(for: "test")
            .dropFirst() // Skip initial nil
            .sink { value in
                XCTAssertEqual(value, "added")
                memoryExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        memoryBox.put(key: "test", value: "added")
        
        // Test HybridBox
        let hybridBox = MockHybridBox<String, String>()
        
        let hybridExpectation = expectation(description: "HybridBox emits on value added")
        hybridBox.publisher(for: "test")
            .dropFirst() // Skip initial nil
            .sink { value in
                XCTAssertEqual(value, "added")
                hybridExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        hybridBox.put(key: "test", value: "added", expiresAfter: nil)
        
        waitForExpectations(timeout: 1.0)
    }
    
    func test_publisherEmitsOnValueRemoval() {
        // Test MemoryBox
        let memoryBox = MockMemoryBox<String, String>()
        memoryBox.put(key: "test", value: "initial")
        
        let memoryExpectation = expectation(description: "MemoryBox emits on removal")
        memoryBox.publisher(for: "test")
            .dropFirst() // Skip initial value
            .sink { value in
                XCTAssertNil(value)
                memoryExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        memoryBox.remove("test")
        
        // Test HybridBox
        let hybridBox = MockHybridBox<String, String>()
        hybridBox.put(key: "test", value: "initial", expiresAfter: nil)
        
        let hybridExpectation = expectation(description: "HybridBox emits on removal")
        hybridBox.publisher(for: "test")
            .dropFirst() // Skip initial value
            .sink { value in
                XCTAssertNil(value)
                hybridExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        hybridBox.remove("test")
        
        waitForExpectations(timeout: 1.0)
    }
    
    func test_publisherEmitsOnValueUpdate() {
        // Test MemoryBox
        let memoryBox = MockMemoryBox<String, String>()
        memoryBox.put(key: "test", value: "initial")
        
        let memoryExpectation = expectation(description: "MemoryBox emits on update")
        memoryBox.publisher(for: "test")
            .dropFirst() // Skip initial value
            .sink { value in
                XCTAssertEqual(value, "updated")
                memoryExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        memoryBox.put(key: "test", value: "updated")
        
        // Test HybridBox
        let hybridBox = MockHybridBox<String, String>()
        hybridBox.put(key: "test", value: "initial", expiresAfter: nil)
        
        let hybridExpectation = expectation(description: "HybridBox emits on update")
        hybridBox.publisher(for: "test")
            .dropFirst() // Skip initial value
            .sink { value in
                XCTAssertEqual(value, "updated")
                hybridExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        hybridBox.put(key: "test", value: "updated", expiresAfter: nil)
        
        waitForExpectations(timeout: 1.0)
    }
}
