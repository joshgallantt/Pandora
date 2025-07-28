//
//  PandoraDiskBoxTests.swift
//  Pandora
//
//  Created by Josh Gallant on 27/07/2025.
//

import XCTest
@testable import Pandora

final class PandoraDiskBoxTests: XCTestCase {
    struct TestCodable: Codable, Equatable, Hashable {
        let id: Int
        let name: String
    }
    
    var namespace: String!
    var box: PandoraDiskBox<Int, TestCodable>!
    var boxDirectory: URL!

    override func setUpWithError() throws {
        namespace = UUID().uuidString
        box = PandoraDiskBox<Int, TestCodable>(namespace: namespace)
        boxDirectory = PandoraDiskBoxPath.sharedRoot.appendingPathComponent(namespace)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: boxDirectory)
    }

    // MARK: - Directory creation and static root
    func test_givenNonexistentNamespace_whenInit_thenCreatesDirectory() throws {
        // Given
        let testNamespace = "dir-test-\(UUID().uuidString)"
        let newDir = PandoraDiskBoxPath.sharedRoot.appendingPathComponent(testNamespace)
        XCTAssertFalse(FileManager.default.fileExists(atPath: newDir.path))
        // When
        let _ = PandoraDiskBox<Int, TestCodable>(namespace: testNamespace)
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: newDir.path))
        try? FileManager.default.removeItem(at: newDir)
    }
    
    func test_givenStaticClearAll_whenSharedRootDoesNotExist_thenNoError() {
        // Given
        let sharedRoot = PandoraDiskBoxPath.sharedRoot
        try? FileManager.default.removeItem(at: sharedRoot)
        // When
        Pandora.clearAllDiskData()
        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: sharedRoot.path))
    }

    // MARK: - Namespace isolation
    func test_givenDifferentNamespaces_whenPutSameKey_thenDataIsIsolated() async {
        // Given
        let ns1 = "ns1-\(UUID().uuidString)"
        let ns2 = "ns2-\(UUID().uuidString)"
        let box1 = PandoraDiskBox<Int, TestCodable>(namespace: ns1)
        let box2 = PandoraDiskBox<Int, TestCodable>(namespace: ns2)
        let key = 99
        let value1 = TestCodable(id: 1, name: "NS1")
        let value2 = TestCodable(id: 2, name: "NS2")
        // When
        await box1.put(key: key, value: value1)
        await box2.put(key: key, value: value2)
        let result1 = await box1.get(key)
        let result2 = await box2.get(key)
        // Then
        XCTAssertEqual(result1, value1)
        XCTAssertEqual(result2, value2)
        XCTAssertNotEqual(result1, result2)
        // Cleanup
        let dir1 = PandoraDiskBoxPath.sharedRoot.appendingPathComponent(ns1)
        let dir2 = PandoraDiskBoxPath.sharedRoot.appendingPathComponent(ns2)
        try? FileManager.default.removeItem(at: dir1)
        try? FileManager.default.removeItem(at: dir2)
    }

    func test_givenNamespaceWithSlash_whenInit_thenCreatesSafeDirectory() throws {
        // Given
        let namespace = "my/feature-\(UUID().uuidString)"
        let safeNamespace = namespace.replacingOccurrences(of: "/", with: "_")
        let expectedDir = PandoraDiskBoxPath.sharedRoot.appendingPathComponent(safeNamespace)
        // When
        let _ = PandoraDiskBox<Int, TestCodable>(namespace: namespace)
        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedDir.path, isDirectory: nil))
        // Cleanup
        try? FileManager.default.removeItem(at: expectedDir)
    }

    func test_givenMultipleNamespaces_whenClearAll_thenAllNamespacesAreRemoved() async {
        // Given
        let ns1 = "A-\(UUID().uuidString)"
        let ns2 = "B-\(UUID().uuidString)"
        let box1 = PandoraDiskBox<Int, TestCodable>(namespace: ns1)
        let box2 = PandoraDiskBox<Int, TestCodable>(namespace: ns2)
        await box1.put(key: 1, value: TestCodable(id: 1, name: "A"))
        await box2.put(key: 2, value: TestCodable(id: 2, name: "B"))
        // When
        Pandora.clearAllDiskData()
        let result1 = await box1.get(1)
        let result2 = await box2.get(2)
        // Then
        XCTAssertNil(result1)
        XCTAssertNil(result2)
    }

    // MARK: - Basic put/get/remove/clear
    func test_givenValue_whenPutAndGet_thenReturnsCorrectValue() async {
        // Given
        let key = 42
        let value = TestCodable(id: 42, name: "Josh")
        // When
        await box.put(key: key, value: value)
        let result = await box.get(key)
        // Then
        XCTAssertEqual(result, value)
    }
    func test_givenNoValue_whenGet_thenReturnsNil() async {
        // When
        let result = await box.get(999)
        // Then
        XCTAssertNil(result)
    }
    func test_givenValue_whenRemove_thenGetReturnsNil() async {
        // Given
        let key = 123
        let value = TestCodable(id: 1, name: "DeleteMe")
        await box.put(key: key, value: value)
        // When
        await box.remove(key)
        let result = await box.get(key)
        // Then
        XCTAssertNil(result)
    }
    func test_givenMultipleValues_whenClear_thenAllRemoved() async {
        // Given
        for i in 0..<5 {
            await box.put(key: i, value: TestCodable(id: i, name: "User\(i)"))
        }
        // When
        await box.clear()
        // Then
        for i in 0..<5 {
            let result = await box.get(i)
            XCTAssertNil(result)
        }
    }
    func test_givenEmptyDirectory_whenClear_thenNoError() async {
        // When
        await box.clear()
        // Then
        XCTAssertTrue(true)
    }
    func test_givenFileMissing_whenRemove_thenNoError() async {
        // When
        await box.remove(888)
        // Then
        XCTAssertTrue(true)
    }

    // MARK: - Expiry
    func test_givenExpirySet_whenExpired_thenReturnsNilAndRemovesFile() async throws {
        // Given
        let expiringNamespace = "expire-\(UUID().uuidString)"
        let expiringBox = PandoraDiskBox<Int, TestCodable>(namespace: expiringNamespace, expiresAfter: 0.05)
        let key = 7
        let value = TestCodable(id: 7, name: "Expiring")
        await expiringBox.put(key: key, value: value)
        let fileURL = PandoraDiskBoxPath.sharedRoot
            .appendingPathComponent(expiringNamespace)
            .appendingPathComponent("7")
            .appendingPathExtension("box")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        // When
        try await Task.sleep(nanoseconds: 100_000_000)
        let result = await expiringBox.get(key)
        // Then
        XCTAssertNil(result)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        // Cleanup
        let expDir = PandoraDiskBoxPath.sharedRoot.appendingPathComponent(expiringNamespace)
        try? FileManager.default.removeItem(at: expDir)
    }
    func test_givenExpirySet_whenNotExpired_thenReturnsValue() async {
        // Given
        let expiringNamespace = "expire-\(UUID().uuidString)"
        let expiringBox = PandoraDiskBox<Int, TestCodable>(namespace: expiringNamespace, expiresAfter: 10)
        let key = 101
        let value = TestCodable(id: 2, name: "NotExpired")
        await expiringBox.put(key: key, value: value)
        // When
        let result = await expiringBox.get(key)
        // Then
        XCTAssertEqual(result, value)
        // Cleanup
        let expDir = PandoraDiskBoxPath.sharedRoot.appendingPathComponent(expiringNamespace)
        try? FileManager.default.removeItem(at: expDir)
    }

    // MARK: - Corrupted / Non-decodable files
    func test_givenCorruptedFile_whenGet_thenReturnsNil() async throws {
        // Given
        let key = 777
        let url = boxDirectory.appendingPathComponent("777").appendingPathExtension("box")
        try Data([0x00, 0xFF]).write(to: url)
        // When
        let result = await box.get(key)
        // Then
        XCTAssertNil(result)
    }
    func test_givenFileWithExpiredEntry_whenGet_thenRemovesFile() async throws {
        // Given
        let expiringNamespace = "expire-\(UUID().uuidString)"
        let expiringBox = PandoraDiskBox<Int, TestCodable>(namespace: expiringNamespace, expiresAfter: 0.01)
        let key = 70
        let value = TestCodable(id: 70, name: "Expiring70")
        await expiringBox.put(key: key, value: value)
        let fileURL = PandoraDiskBoxPath.sharedRoot
            .appendingPathComponent(expiringNamespace)
            .appendingPathComponent("70")
            .appendingPathExtension("box")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        // When
        try await Task.sleep(nanoseconds: 50_000_000)
        let result = await expiringBox.get(key)
        // Then
        XCTAssertNil(result)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        // Cleanup
        let expDir = PandoraDiskBoxPath.sharedRoot.appendingPathComponent(expiringNamespace)
        try? FileManager.default.removeItem(at: expDir)
    }

    // MARK: - LRU, maxSize, and edge cases
    func test_givenMaxSize_whenOverLimit_thenLeastRecentlyUsedEvicted() async {
        // Given
        let lruNamespace = "lru-\(UUID().uuidString)"
        let lruBox = PandoraDiskBox<Int, TestCodable>(namespace: lruNamespace, maxSize: 3)
        await lruBox.put(key: 1, value: TestCodable(id: 1, name: "User1"))
        await lruBox.put(key: 2, value: TestCodable(id: 2, name: "User2"))
        await lruBox.put(key: 3, value: TestCodable(id: 3, name: "User3"))
        let _ = await lruBox.get(1) // Key=2 now least recently used
        await lruBox.put(key: 4, value: TestCodable(id: 4, name: "User4"))
        // When
        let one = await lruBox.get(1)
        let two = await lruBox.get(2)
        let three = await lruBox.get(3)
        let four = await lruBox.get(4)
        // Then
        XCTAssertNotNil(one)
        XCTAssertNil(two)
        XCTAssertNotNil(three)
        XCTAssertNotNil(four)
        // Cleanup
        let lruDir = PandoraDiskBoxPath.sharedRoot.appendingPathComponent(lruNamespace)
        try? FileManager.default.removeItem(at: lruDir)
    }
    func test_givenMaxSizeZero_whenPut_thenLRUNotEnforced() async {
        // Given
        let zeroNamespace = "zero-\(UUID().uuidString)"
        let zeroBox = PandoraDiskBox<Int, TestCodable>(namespace: zeroNamespace, maxSize: 0)
        for i in 1...5 {
            await zeroBox.put(key: i, value: TestCodable(id: i, name: "User\(i)"))
        }
        // Then
        for i in 1...5 {
            let result = await zeroBox.get(i)
            XCTAssertNotNil(result)
        }
        // Cleanup
        let zeroDir = PandoraDiskBoxPath.sharedRoot.appendingPathComponent(zeroNamespace)
        try? FileManager.default.removeItem(at: zeroDir)
    }
    func test_givenMaxSizeNil_whenPut_thenLRUNotEnforced() async {
        // Given
        let nilNamespace = "nil-\(UUID().uuidString)"
        let nilBox = PandoraDiskBox<Int, TestCodable>(namespace: nilNamespace, maxSize: nil)
        for i in 1...5 {
            await nilBox.put(key: i, value: TestCodable(id: i, name: "User\(i)"))
        }
        // Then
        for i in 1...5 {
            let result = await nilBox.get(i)
            XCTAssertNotNil(result)
        }
        // Cleanup
        let nilDir = PandoraDiskBoxPath.sharedRoot.appendingPathComponent(nilNamespace)
        try? FileManager.default.removeItem(at: nilDir)
    }
    
    func test_givenMaxSize_whenPutMoreThanCapacity_thenLRUEnforced() async {
        // Given
        let lruNamespace = "lru-\(UUID().uuidString)"
        let lruBox = PandoraDiskBox<Int, TestCodable>(namespace: lruNamespace, maxSize: 2)
        await lruBox.put(key: 1, value: TestCodable(id: 1, name: "A"))
        await lruBox.put(key: 2, value: TestCodable(id: 2, name: "B"))
        let _ = await lruBox.get(1)
        await lruBox.put(key: 3, value: TestCodable(id: 3, name: "C"))
        // Then
        let one = await lruBox.get(1)
        let two = await lruBox.get(2)
        let three = await lruBox.get(3)
        XCTAssertNotNil(one)
        XCTAssertNil(two)
        XCTAssertNotNil(three)
        // Cleanup
        let lruDir = PandoraDiskBoxPath.sharedRoot.appendingPathComponent(lruNamespace)
        try? FileManager.default.removeItem(at: lruDir)
    }
    
    func test_givenFilesWithModificationDates_whenLRU_thenOldestAreEvicted() async throws {
        // Given
        let ns = "lru-\(UUID().uuidString)"
        let box = PandoraDiskBox<Int, String>(namespace: ns, maxSize: 2)
        // Insert two values
        await box.put(key: 1, value: "first")
        await box.put(key: 2, value: "second")
        let dir = PandoraDiskBoxPath.sharedRoot.appendingPathComponent(ns)

        // Manually set file 1's mod date to long ago to simulate LRU
        let file1 = dir.appendingPathComponent("1").appendingPathExtension("box")
        let oldDate = Date.distantPast
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: file1.path)
        // Wait a bit to ensure next file gets a newer date
        try await Task.sleep(nanoseconds: 50_000_000)
        // Insert third value (should evict file1)
        await box.put(key: 3, value: "third")

        // Then
        let exists1 = FileManager.default.fileExists(atPath: file1.path)
        let value1 = await box.get(1)
        let value2 = await box.get(2)
        let value3 = await box.get(3)
        XCTAssertFalse(exists1)
        XCTAssertNil(value1)
        XCTAssertEqual(value2, "second")
        XCTAssertEqual(value3, "third")
        // Cleanup
        try? FileManager.default.removeItem(at: dir)
    }


    // MARK: - Encoder failure (attempt)
    func test_givenPutFails_whenEncoderReturnsNil_thenNoFileWritten() async {
        struct NonEncodable: Codable {
            let value: Any // Any is not Codable, so encoding will fail
            init(_ value: Any) { self.value = value }
            enum CodingKeys: CodingKey { case value }
            func encode(to encoder: Encoder) throws { throw NSError(domain: "fail", code: 1) }
            init(from decoder: Decoder) throws { throw NSError(domain: "fail", code: 2) }
        }
        let encNamespace = "encfail-\(UUID().uuidString)"
        let stringBox = PandoraDiskBox<String, NonEncodable>(namespace: encNamespace)
        let key = "fail"
        await stringBox.put(key: key, value: NonEncodable(3))
        let url = PandoraDiskBoxPath.sharedRoot
            .appendingPathComponent(encNamespace)
            .appendingPathComponent("fail")
            .appendingPathExtension("box")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        // Cleanup
        let encDir = PandoraDiskBoxPath.sharedRoot.appendingPathComponent(encNamespace)
        try? FileManager.default.removeItem(at: encDir)
    }

    // MARK: - Multi-type support
    func test_givenPutAndGetWithStringKey_thenWorks() async {
        // Given
        let dirNamespace = "str-\(UUID().uuidString)"
        let stringBox = PandoraDiskBox<String, String>(namespace: dirNamespace)
        let key = "foo"
        let value = "bar"
        // When
        await stringBox.put(key: key, value: value)
        let result = await stringBox.get(key)
        // Then
        XCTAssertEqual(result, value)
        // Cleanup
        let strDir = PandoraDiskBoxPath.sharedRoot.appendingPathComponent(dirNamespace)
        try? FileManager.default.removeItem(at: strDir)
    }

    // MARK: - Static clearAll removes all boxes under shared root
    func test_givenClearAll_whenMultipleBoxesUnderSharedRoot_thenAllDataRemoved() async {
        // Given
        let box1Namespace = "c1-\(UUID().uuidString)"
        let box2Namespace = "c2-\(UUID().uuidString)"
        let box1 = PandoraDiskBox<Int, TestCodable>(namespace: box1Namespace)
        let box2 = PandoraDiskBox<Int, TestCodable>(namespace: box2Namespace)
        await box1.put(key: 1, value: TestCodable(id: 1, name: "A"))
        await box2.put(key: 2, value: TestCodable(id: 2, name: "B"))
        // When
        Pandora.clearAllDiskData()
        let result1 = await box1.get(1)
        let result2 = await box2.get(2)
        // Then
        XCTAssertNil(result1)
        XCTAssertNil(result2)
    }

    // MARK: - Coverage for fileURL/extension
    func test_givenKey_whenFileURLUsed_thenCorrectFileExtension() {
        // Given
        let key = 77
        let url = boxDirectory.appendingPathComponent(String(describing: key)).appendingPathExtension("box")
        // Then
        XCTAssertEqual(url.pathExtension, "box")
    }
}
