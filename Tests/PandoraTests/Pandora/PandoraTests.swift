//
//  PandoraTests.swift
//  PandoraTests
//
//  Created by Josh Gallant on 28/07/2025.
//

import XCTest
@testable import Pandora

final class PandoraTests: XCTestCase {

    struct TestUser: Codable, Equatable {
        let id: Int
        let name: String
    }

    // MARK: - PandoraMemoryBoxProtocol

    func test_memoryBox_inference_based() {
        // Given
        let box: PandoraMemoryBox<String, TestUser> = Pandora.Memory.box()
        let user = TestUser(id: 1, name: "Inference")

        // When
        box.put(key: "user", value: user)
        let result = box.get("user")

        // Then
        XCTAssertEqual(result, user)
        
    }

    func test_memoryBox_explicit_types() {
        // Given
        let box = Pandora.Memory.box(maxSize: 100, expiresAfter: nil) as PandoraMemoryBox<String, TestUser>
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
        let box: PandoraDiskBox<String, TestUser> = Pandora.Disk.box(namespace: UUID().uuidString)
        let user = TestUser(id: 3, name: "Disky")

        // When
        await box.put(key: "user", value: user)
        let result = await box.get("user")

        // Then
        XCTAssertEqual(result, user)
    }

    func test_diskBox_explicit_types() async {
        // Given
        let box = Pandora.Disk.box(
            namespace: UUID().uuidString,
            maxSize: 10,
            expiresAfter: 3600
        ) as PandoraDiskBox<String, TestUser>
        let user = TestUser(id: 4, name: "ExplicitDisk")

        // When
        await box.put(key: "user", value: user)
        let result = await box.get("user")

        // Then
        XCTAssertEqual(result, user)
    }

    // MARK: - PandoraHybridBox

    func test_hybridBox_inference_based() async {
        // Given
        let box: PandoraHybridBox<String, TestUser> = Pandora.Hybrid.box(namespace: UUID().uuidString)
        let user = TestUser(id: 5, name: "Hybrid")

        // When
        box.put(key: "user", value: user)
        let result = await box.get("user")

        // Then
        XCTAssertEqual(result, user)
    }

    func test_hybridBox_explicit_types() async {
        // Given
        let box = Pandora.Hybrid.box(
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

    // MARK: - PandoraUserDefaultsBoxProtocol

    func test_userDefaultsBox_inference_based() async throws {
        // Given
        let box: PandoraUserDefaultsBox<TestUser> = Pandora.UserDefaults.box(namespace: UUID().uuidString)
        let user = TestUser(id: 7, name: "UD")

        // When
        box.put(key: "user", value: user)
        let result: TestUser? = await box.get("user")

        // Then
        XCTAssertEqual(result, user)
    }

    func test_userDefaultsBox_explicit_cast() async throws {
        // Given
        let box: PandoraUserDefaultsBox<TestUser> = Pandora.UserDefaults.box(namespace: UUID().uuidString)
        let user = TestUser(id: 8, name: "UD Explicit")

        // When
        box.put(key: "explicit", value: user)
        let result: TestUser? = await box.get("explicit")

        // Then
        XCTAssertEqual(result, user)
    }

    // MARK: - Global Disk Cleanup

    func test_clearAllDiskData_removesAllFiles() async {
        // Given
        let box: PandoraDiskBox<String, TestUser> = Pandora.Disk.box(namespace: UUID().uuidString)
        let user = TestUser(id: 9, name: "ToBeDeleted")

        await box.put(key: "deleteMe", value: user)
        let existing = await box.get("deleteMe")
        XCTAssertNotNil(existing)

        // When
        Pandora.clearAllDiskData()

        // Then
        let result = await box.get("deleteMe")
        XCTAssertNil(result)
    }
    
    // MARK: - Pandora Enum Static Factory Coverage
    
    func test_memoryBox_factory_explicitTypes() {
        let box = Pandora.Memory.box(keyType: String.self, valueType: TestUser.self, maxSize: 2, expiresAfter: 1)
        let user = TestUser(id: 11, name: "ExplicitMemory")
        box.put(key: "explicit", value: user)
        let result = box.get("explicit")
        XCTAssertEqual(result, user)
    }
    
    func test_diskBox_factory_explicitTypes() async {
        let box = Pandora.Disk.box(namespace: UUID().uuidString, keyType: String.self, valueType: TestUser.self, maxSize: 2, expiresAfter: 1)
        let user = TestUser(id: 12, name: "ExplicitDiskAlt")
        await box.put(key: "explicit", value: user)
        let result = await box.get("explicit")
        XCTAssertEqual(result, user)
    }
    
    func test_hybridBox_factory_explicitTypes() async {
        let box = Pandora.Hybrid.box(namespace: UUID().uuidString, keyType: String.self, valueType: TestUser.self, memoryMaxSize: 10, memoryExpiresAfter: 1, diskMaxSize: 2, diskExpiresAfter: 1)
        let user = TestUser(id: 13, name: "ExplicitHybridAlt")
        box.put(key: "explicit", value: user)
        let result = await box.get("explicit")
        XCTAssertEqual(result, user)
    }
    
    func test_memoryBox_factory_defaultParams() {
        let box = Pandora.Memory.box() as PandoraMemoryBox<String, TestUser>
        let user = TestUser(id: 14, name: "DefaultMemory")
        box.put(key: "default", value: user)
        let result = box.get("default")
        XCTAssertEqual(result, user)
    }
    
    func test_diskBox_factory_defaultParams() async {
        let box = Pandora.Disk.box(namespace: UUID().uuidString) as PandoraDiskBox<String, TestUser>
        let user = TestUser(id: 15, name: "DefaultDisk")
        await box.put(key: "default", value: user)
        let result = await box.get("default")
        XCTAssertEqual(result, user)
    }
    
    func test_hybridBox_factory_defaultParams() async {
        let box: PandoraHybridBox<String, TestUser> = Pandora.Hybrid.box(namespace: UUID().uuidString)
        let user = TestUser(id: 16, name: "DefaultHybrid")
        box.put(key: "default", value: user)
        let result = await box.get("default")
        XCTAssertEqual(result, user)
    }
    
    func test_userDefaultsBox_factory_customUserDefaults() async throws {
        let suiteName = "pandoras.udtests." + UUID().uuidString
        let customUD = UserDefaults(suiteName: suiteName)!
        let box: PandoraUserDefaultsBox<TestUser> = Pandora.UserDefaults.box(
            namespace: "custom",
            userDefaults: customUD
        )
        let user = TestUser(id: 17, name: "CustomUD")
        box.put(key: "custom", value: user)
        let result: TestUser? = await box.get("custom")
        XCTAssertEqual(result, user)
        customUD.removePersistentDomain(forName: suiteName)
    }
    
    func test_clearAllDiskData_static() async {
        let ns = UUID().uuidString
        let box: PandoraDiskBox<String, TestUser> = Pandora.Disk.box(namespace: ns)
        let user = TestUser(id: 18, name: "ClearAllSpecial")
        await box.put(key: "delete", value: user)
        Pandora.clearAllDiskData()
        let result = await box.get("delete")
        XCTAssertNil(result)
        
    }
    
    func test_givenExplicitValueType_whenCreateUserDefaultsBox_thenRoundTripsValue() async {
        // Given
        let box = Pandora.UserDefaults.box(
            namespace: "ud.explicit.\(UUID().uuidString)",
            valueType: TestUser.self,
            iCloudBacked: false
        )
        let user = TestUser(id: 20, name: "ExplicitValueType")

        // When
        box.put(key: "user", value: user)
        let result = await box.get("user")

        // Then
        XCTAssertEqual(result, user)
    }

    // MARK: - clearUserDefaults (standard + iCloud KVS)

    func test_givenKeysInUserDefaultsAndICloud_whenClearUserDefaults_thenStoresAreEmpty() {
        // Given
        let defaults = Foundation.UserDefaults.standard
        let udKey = "pandora.tests.ud.hi"
        defaults.set("value", forKey: udKey)
        XCTAssertNotNil(defaults.object(forKey: udKey)) // sanity

        let store = NSUbiquitousKeyValueStore.default
        let icKey = "pandora.tests.icloud.hi"
        store.set("value", forKey: icKey)
        store.synchronize()

        // When
        Pandora.clearUserDefaults()

        // Then
        XCTAssertNil(defaults.object(forKey: udKey))
        XCTAssertNil(store.object(forKey: icKey))
    }

    // MARK: - deleteAllLocalStorage (disk + UD + iCloud)

    func test_givenDataEverywhere_whenDeleteAllLocalStorage_thenEverythingIsGone() async {
        // Given: disk
        let ns = "pandora.tests.disk.hi"
        let diskBox: PandoraDiskBox<String, TestUser> = Pandora.Disk.box(namespace: ns)
        let user = TestUser(id: 21, name: "NukeAll")
        await diskBox.put(key: "user", value: user)
        let preDiskValue = await diskBox.get("user")
        XCTAssertEqual(preDiskValue, user)

        // Given: user defaults
        let defaultsKey = "pandora.tests.deleteall.ud.hi"
        Foundation.UserDefaults.standard.set(123, forKey: defaultsKey)
        XCTAssertEqual(Foundation.UserDefaults.standard.integer(forKey: defaultsKey), 123)

        // Given: iCloud KVS
        let store = NSUbiquitousKeyValueStore.default
        let icKey = "pandora.tests.deleteall.icloud.hi"
        store.set(true, forKey: icKey)
        store.synchronize()

        // When
        Pandora.deleteAllLocalStorage()

        // Then: disk gone
        let postDiskValue = await diskBox.get("user")
        XCTAssertNil(postDiskValue)

        // Then: UD gone
        XCTAssertNil(Foundation.UserDefaults.standard.object(forKey: defaultsKey))

        // Then: iCloud gone
        XCTAssertNil(store.object(forKey: icKey))
    }

}

