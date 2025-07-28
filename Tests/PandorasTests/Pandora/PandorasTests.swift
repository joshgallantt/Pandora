//
//  PandorasTests.swift
//  PandoraTests
//
//  Created by Josh Gallant on 28/07/2025.
//

import XCTest
@testable import Pandoras

final class PandorasTests: XCTestCase {

    struct TestUser: Codable, Equatable {
        let id: Int
        let name: String
    }

    // MARK: - PandorasMemoryBoxProtocol

    func test_memoryBox_inference_based() {
        // Given
        let box: PandorasMemoryBox<String, TestUser> = Pandoras.Memory.box()
        let user = TestUser(id: 1, name: "Inference")

        // When
        box.put(key: "user", value: user)
        let result = box.get("user")

        // Then
        XCTAssertEqual(result, user)
    }

    func test_memoryBox_explicit_types() {
        // Given
        let box = Pandoras.Memory.box(maxSize: 100, expiresAfter: nil) as PandorasMemoryBox<String, TestUser>
        let user = TestUser(id: 2, name: "Explicit")

        // When
        box.put(key: "user", value: user)
        let result = box.get("user")

        // Then
        XCTAssertEqual(result, user)
    }

    // MARK: - DiskBox

    func test_diskBox_inference_based() async {
        // Given
        let box: PandorasDiskBox<String, TestUser> = Pandoras.Disk.box(namespace: UUID().uuidString)
        let user = TestUser(id: 3, name: "Disky")

        // When
        await box.put(key: "user", value: user)
        let result = await box.get("user")

        // Then
        XCTAssertEqual(result, user)
    }

    func test_diskBox_explicit_types() async {
        // Given
        let box = Pandoras.Disk.box(
            namespace: UUID().uuidString,
            maxSize: 10,
            expiresAfter: 3600
        ) as PandorasDiskBox<String, TestUser>
        let user = TestUser(id: 4, name: "ExplicitDisk")

        // When
        await box.put(key: "user", value: user)
        let result = await box.get("user")

        // Then
        XCTAssertEqual(result, user)
    }

    // MARK: - PandorasHybridBox

    func test_hybridBox_inference_based() async {
        // Given
        let box: PandorasHybridBox<String, TestUser> = Pandoras.Hybrid.box(namespace: UUID().uuidString)
        let user = TestUser(id: 5, name: "Hybrid")

        // When
        box.put(key: "user", value: user)
        let result = await box.get("user")

        // Then
        XCTAssertEqual(result, user)
    }

    func test_hybridBox_explicit_types() async {
        // Given
        let box = Pandoras.Hybrid.box(
            namespace: UUID().uuidString,
            keyType: String.self,
            valueType: TestUser.self,
            memoryMaxSize: 100,
            memoryExpiresAfter: nil,
            diskMaxSize: 50,
            diskExpiresAfter: nil
        )

        let user = TestUser(id: 6, name: "ExplicitHybrid")

        // When
        box.put(key: "user", value: user)
        let result = await box.get("user")

        // Then
        XCTAssertEqual(result, user)
    }

    // MARK: - PandorasUserDefaultsBoxProtocol

    func test_userDefaultsBox_inference_based() async throws {
        // Given
        let box = Pandoras.UserDefaults.box(namespace: UUID().uuidString)
        let user = TestUser(id: 7, name: "UD")

        // When
        try await box.put(key: "user", value: user)
        let result: TestUser = try await box.get("user")

        // Then
        XCTAssertEqual(result, user)
    }

    func test_userDefaultsBox_explicit_cast() async throws {
        // Given
        let box = Pandoras.UserDefaults.box(namespace: UUID().uuidString)
        let user = TestUser(id: 8, name: "UD Explicit")

        // When
        try await box.put(key: "explicit", value: user)
        let result: TestUser = try await box.get("explicit")

        // Then
        XCTAssertEqual(result, user)
    }

    // MARK: - Global Disk Cleanup

    func test_clearAllDiskData_removesAllFiles() async {
        // Given
        let box: PandorasDiskBox<String, TestUser> = Pandoras.Disk.box(namespace: UUID().uuidString)
        let user = TestUser(id: 9, name: "ToBeDeleted")

        await box.put(key: "deleteMe", value: user)
        let existing = await box.get("deleteMe")
        XCTAssertNotNil(existing)

        // When
        Pandoras.clearAllDiskData()

        // Then
        let result = await box.get("deleteMe")
        XCTAssertNil(result)
    }
    
    // MARK: - Pandoras Enum Static Factory Coverage
    
    func test_memoryBox_factory_explicitTypes() {
        let box = Pandoras.Memory.box(keyType: String.self, valueType: TestUser.self, maxSize: 2, expiresAfter: 1)
        let user = TestUser(id: 11, name: "ExplicitMemory")
        box.put(key: "explicit", value: user)
        let result = box.get("explicit")
        XCTAssertEqual(result, user)
    }
    
    func test_diskBox_factory_explicitTypes() async {
        let box = Pandoras.Disk.box(namespace: UUID().uuidString, keyType: String.self, valueType: TestUser.self, maxSize: 2, expiresAfter: 1)
        let user = TestUser(id: 12, name: "ExplicitDiskAlt")
        await box.put(key: "explicit", value: user)
        let result = await box.get("explicit")
        XCTAssertEqual(result, user)
    }
    
    func test_hybridBox_factory_explicitTypes() async {
        let box = Pandoras.Hybrid.box(namespace: UUID().uuidString, keyType: String.self, valueType: TestUser.self, memoryMaxSize: 10, memoryExpiresAfter: 1, diskMaxSize: 2, diskExpiresAfter: 1)
        let user = TestUser(id: 13, name: "ExplicitHybridAlt")
        box.put(key: "explicit", value: user)
        let result = await box.get("explicit")
        XCTAssertEqual(result, user)
    }
    
    func test_memoryBox_factory_defaultParams() {
        let box = Pandoras.Memory.box() as PandorasMemoryBox<String, TestUser>
        let user = TestUser(id: 14, name: "DefaultMemory")
        box.put(key: "default", value: user)
        let result = box.get("default")
        XCTAssertEqual(result, user)
    }
    
    func test_diskBox_factory_defaultParams() async {
        let box = Pandoras.Disk.box(namespace: UUID().uuidString) as PandorasDiskBox<String, TestUser>
        let user = TestUser(id: 15, name: "DefaultDisk")
        await box.put(key: "default", value: user)
        let result = await box.get("default")
        XCTAssertEqual(result, user)
    }
    
    func test_hybridBox_factory_defaultParams() async {
        let box: PandorasHybridBox<String, TestUser> = Pandoras.Hybrid.box(namespace: UUID().uuidString)
        let user = TestUser(id: 16, name: "DefaultHybrid")
        box.put(key: "default", value: user)
        let result = await box.get("default")
        XCTAssertEqual(result, user)
    }
    
    func test_userDefaultsBox_factory_customUserDefaults() async throws {
        let suiteName = "pandoras.udtests." + UUID().uuidString
        let customUD = UserDefaults(suiteName: suiteName)!
        let box = Pandoras.UserDefaults.box(namespace: "custom", userDefaults: customUD)
        let user = TestUser(id: 17, name: "CustomUD")
        try await box.put(key: "custom", value: user)
        let result: TestUser = try await box.get("custom")
        XCTAssertEqual(result, user)
        customUD.removePersistentDomain(forName: suiteName)
    }
    
    func test_clearAllDiskData_static() async {
        let ns = UUID().uuidString
        let box: PandorasDiskBox<String, TestUser> = Pandoras.Disk.box(namespace: ns)
        let user = TestUser(id: 18, name: "ClearAllSpecial")
        await box.put(key: "delete", value: user)
        Pandoras.clearAllDiskData()
        let result = await box.get("delete")
        XCTAssertNil(result)
    }
}
