//
//  PandoraStorageManagerTests.swift
//  Pandora
//
//  Created by Josh Gallant on 08/08/2025.
//

import XCTest
@testable import Pandora

final class PandoraStorageManagerTests: XCTestCase {

    private var sut: PandoraStorageManager!

    override func setUp() {
        super.setUp()
        sut = PandoraStorageManager.shared
        #if DEBUG
        sut._resetForTesting()
        #endif
    }

    override func tearDown() {
        #if DEBUG
        sut._resetForTesting()
        #endif
        sut = nil
        super.tearDown()
    }

    // MARK: - canStore

    func test_givenNewKey_withDataUnderLimit_andTotalBelowMax_thenCanStoreIsTrue() {
        // Given
        // total = 100 (well below 1024)
        sut.updateCount(namespace: "nsA", count: 60)
        sut.updateCount(namespace: "nsB", count: 40)
        let smallData = Data(repeating: 0, count: 10)

        // When
        let result = sut.canStore(namespace: "nsA", data: smallData, isNewKey: true)

        // Then
        XCTAssertTrue(result)
    }

    func test_givenNewKey_withTotalAtMax_thenCanStoreIsFalse() {
        // Given
        // set one namespace to 1024 so total == 1024
        sut.updateCount(namespace: "nsFull", count: 1024)
        let smallData = Data(repeating: 0, count: 10)

        // When
        let result = sut.canStore(namespace: "another", data: smallData, isNewKey: true)

        // Then
        XCTAssertFalse(result)
    }

    func test_givenExistingKey_whenTotalAtOrOverMax_thenCanStoreIsTrue() {
        // Given
        sut.updateCount(namespace: "nsFull", count: 1024)
        let smallData = Data(repeating: 0, count: 10)

        // When
        let result = sut.canStore(namespace: "nsFull", data: smallData, isNewKey: false)

        // Then
        XCTAssertTrue(result)
    }

    func test_givenDataExceedsPerValueLimit_thenCanStoreIsFalse() {
        // Given
        // limit is 1024 bytes; use 1025
        let tooLargeData = Data(repeating: 0, count: 1025)

        // When
        let resultNew = sut.canStore(namespace: "ns", data: tooLargeData, isNewKey: true)
        let resultExisting = sut.canStore(namespace: "ns", data: tooLargeData, isNewKey: false)

        // Then
        XCTAssertFalse(resultNew)
        XCTAssertFalse(resultExisting)
    }

    // MARK: - recordAddition

    func test_givenEmpty_whenRecordAddition_thenNamespaceAndTotalIncrease() {
        // Given
        XCTAssertEqual(sut.getTotalItemCount(), 0)
        XCTAssertEqual(sut.getNamespaceCount("A"), 0)

        // When
        sut.recordAddition(namespace: "A")
        sut.recordAddition(namespace: "A")

        // Then
        XCTAssertEqual(sut.getNamespaceCount("A"), 2)
        XCTAssertEqual(sut.getTotalItemCount(), 2)
    }

    // MARK: - recordRemoval

    func test_givenNamespaceWithItems_whenRecordRemoval_thenDecrementsAndRemovesAtZero() {
        // Given
        sut.updateCount(namespace: "A", count: 2)

        // When
        sut.recordRemoval(namespace: "A")

        // Then
        XCTAssertEqual(sut.getNamespaceCount("A"), 1)
        XCTAssertEqual(sut.getTotalItemCount(), 1)

        // When (again)
        sut.recordRemoval(namespace: "A")

        // Then (namespace should be removed)
        XCTAssertEqual(sut.getNamespaceCount("A"), 0)
        XCTAssertEqual(sut.getTotalItemCount(), 0)
    }

    func test_givenMissingOrZeroNamespace_whenRecordRemoval_thenNoOp() {
        // Given
        XCTAssertEqual(sut.getNamespaceCount("missing"), 0)
        XCTAssertEqual(sut.getTotalItemCount(), 0)

        // When
        sut.recordRemoval(namespace: "missing")

        // Then
        XCTAssertEqual(sut.getNamespaceCount("missing"), 0)
        XCTAssertEqual(sut.getTotalItemCount(), 0)
    }

    // MARK: - updateCount

    func test_givenPositiveCount_whenUpdateCount_thenSetsValue() {
        // Given
        XCTAssertEqual(sut.getNamespaceCount("X"), 0)

        // When
        sut.updateCount(namespace: "X", count: 3)

        // Then
        XCTAssertEqual(sut.getNamespaceCount("X"), 3)
        XCTAssertEqual(sut.getTotalItemCount(), 3)
    }

    func test_givenZeroCount_whenUpdateCount_thenNamespaceRemoved() {
        // Given
        sut.updateCount(namespace: "X", count: 3)
        XCTAssertEqual(sut.getNamespaceCount("X"), 3)

        // When
        sut.updateCount(namespace: "X", count: 0)

        // Then
        XCTAssertEqual(sut.getNamespaceCount("X"), 0)
        XCTAssertEqual(sut.getTotalItemCount(), 0)
    }

    // MARK: - getters

    func test_givenMultipleNamespaces_whenGetTotalItemCount_thenSumsAccurately() {
        // Given
        sut.updateCount(namespace: "A", count: 1)
        sut.updateCount(namespace: "B", count: 2)

        // When
        let total = sut.getTotalItemCount()

        // Then
        XCTAssertEqual(total, 3)
    }

    func test_givenUnknownNamespace_whenGetNamespaceCount_thenReturnsZero() {
        // Given
        // No setup for "unknown"

        // When
        let count = sut.getNamespaceCount("unknown")

        // Then
        XCTAssertEqual(count, 0)
    }
}
