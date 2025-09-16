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

    func test_memoryBox_factoryMethods() {
        // Test inference-based creation
        let box1: PandoraMemoryBox<String, TestUser> = Pandora.Memory.box()
        let user1 = TestUser(id: 1, name: "Inference")
        box1.put(key: "user", value: user1)
        XCTAssertEqual(box1.get("user"), user1)
        
        // Test explicit types
        let box2 = Pandora.Memory.box(maxSize: 100, expiresAfter: nil) as PandoraMemoryBox<String, TestUser>
        let user2 = TestUser(id: 2, name: "Explicit")
        box2.put(key: "user", value: user2)
        XCTAssertEqual(box2.get("user"), user2)
    }

    // MARK: - DiskBox

    func test_diskBox_factoryMethods() async {
        // Test inference-based creation
        let box1: PandoraDiskBox<String, TestUser> = Pandora.Disk.box(namespace: UUID().uuidString)
        let user1 = TestUser(id: 3, name: "Disky")
        await box1.put(key: "user", value: user1)
        let result1 = await box1.get("user")
        XCTAssertEqual(result1, user1)
        
        // Test explicit types
        let box2 = Pandora.Disk.box(
            namespace: UUID().uuidString,
            maxSize: 10,
            expiresAfter: 3600
        ) as PandoraDiskBox<String, TestUser>
        let user2 = TestUser(id: 4, name: "ExplicitDisk")
        await box2.put(key: "user", value: user2)
        let result2 = await box2.get("user")
        XCTAssertEqual(result2, user2)
    }

    // MARK: - PandoraHybridBox

    func test_hybridBox_factoryMethods() async {
        // Test inference-based creation
        let box1: PandoraHybridBox<String, TestUser> = Pandora.Hybrid.box(namespace: UUID().uuidString)
        let user1 = TestUser(id: 5, name: "Hybrid")
        box1.put(key: "user", value: user1)
        let result1 = await box1.get("user")
        XCTAssertEqual(result1, user1)
        
        // Test explicit types
        let box2 = Pandora.Hybrid.box(
            namespace: UUID().uuidString,
            keyType: String.self,
            valueType: TestUser.self,
            memoryMaxSize: 100,
            memoryExpiresAfter: nil,
            diskMaxSize: 50,
            diskExpiresAfter: nil
        )
        let user2 = TestUser(id: 6, name: "ExplicitHybrid")
        box2.put(key: "user", value: user2)
        let result2 = await box2.get("user")
        XCTAssertEqual(result2, user2)
    }

    // MARK: - PandoraUserDefaultsBoxProtocol

    func test_userDefaultsBox_factoryMethods() async throws {
        // Test inference-based creation
        let box1: PandoraUserDefaultsBox<TestUser> = Pandora.UserDefaults.box(namespace: UUID().uuidString)
        let user1 = TestUser(id: 7, name: "UD")
        box1.put(key: "user", value: user1)
        let result1 = await box1.get("user")
        XCTAssertEqual(result1, user1)
        
        // Test explicit cast
        let box2: PandoraUserDefaultsBox<TestUser> = Pandora.UserDefaults.box(namespace: UUID().uuidString)
        let user2 = TestUser(id: 8, name: "UD Explicit")
        box2.put(key: "explicit", value: user2)
        let result2 = await box2.get("explicit")
        XCTAssertEqual(result2, user2)
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
    
    // MARK: - Additional Factory Coverage
    
    func test_factoryMethodsWithCustomParameters() async {
        // Test MemoryBox with custom parameters
        let memoryBox = Pandora.Memory.box(keyType: String.self, valueType: TestUser.self, maxSize: 2, expiresAfter: 1)
        let user1 = TestUser(id: 11, name: "CustomMemory")
        memoryBox.put(key: "custom", value: user1)
        XCTAssertEqual(memoryBox.get("custom"), user1)
        
        // Test DiskBox with custom parameters
        let diskBox = Pandora.Disk.box(namespace: UUID().uuidString, keyType: String.self, valueType: TestUser.self, maxSize: 2, expiresAfter: 1)
        let user2 = TestUser(id: 12, name: "CustomDisk")
        await diskBox.put(key: "custom", value: user2)
        let result2 = await diskBox.get("custom")
        XCTAssertEqual(result2, user2)
        
        // Test HybridBox with custom parameters
        let hybridBox = Pandora.Hybrid.box(namespace: UUID().uuidString, keyType: String.self, valueType: TestUser.self, memoryMaxSize: 10, memoryExpiresAfter: 1, diskMaxSize: 2, diskExpiresAfter: 1)
        let user3 = TestUser(id: 13, name: "CustomHybrid")
        hybridBox.put(key: "custom", value: user3)
        let result3 = await hybridBox.get("custom")
        XCTAssertEqual(result3, user3)
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
        Pandora.clearAllUserDefaults()

        // Then
        XCTAssertNil(defaults.object(forKey: udKey))
        XCTAssertNil(store.object(forKey: icKey))
    }

    // MARK: - New Clearing API Tests

    func test_clearDiskData_forSpecificNamespace_removesOnlyThatNamespace() async {
        // Given
        let namespace1 = "test.disk.namespace1"
        let namespace2 = "test.disk.namespace2"
        
        let box1: PandoraDiskBox<String, String> = Pandora.Disk.box(namespace: namespace1)
        let box2: PandoraDiskBox<String, String> = Pandora.Disk.box(namespace: namespace2)
        
        // Add data to both namespaces
        await box1.put(key: "key1", value: "value1")
        await box2.put(key: "key2", value: "value2")
        
        // Verify data exists
        let result1 = await box1.get("key1")
        let result2 = await box2.get("key2")
        XCTAssertEqual(result1, "value1")
        XCTAssertEqual(result2, "value2")
        
        // When - clear only namespace1
        Pandora.clearDiskData(for: namespace1)
        
        // Then - create new boxes to test disk clearing
        let newBox1: PandoraDiskBox<String, String> = Pandora.Disk.box(namespace: namespace1)
        let newBox2: PandoraDiskBox<String, String> = Pandora.Disk.box(namespace: namespace2)
        
        // namespace1 should be empty (disk cleared), namespace2 should still have data
        let result3 = await newBox1.get("key1")
        let result4 = await newBox2.get("key2")
        XCTAssertNil(result3) // Disk data cleared for namespace1
        XCTAssertEqual(result4, "value2") // Disk data still exists for namespace2
    }

    // MARK: - Namespace Clearing Functions

    func test_clearUserDefaultsNamespace_removesSpecificNamespace() async {
        // Given
        let namespace1 = "test.ud.namespace1"
        let namespace2 = "test.ud.namespace2"
        
        let box1: PandoraUserDefaultsBox<String> = Pandora.UserDefaults.box(namespace: namespace1)
        let box2: PandoraUserDefaultsBox<String> = Pandora.UserDefaults.box(namespace: namespace2)
        
        // Add data to both namespaces
        box1.put(key: "key1", value: "value1")
        box2.put(key: "key2", value: "value2")
        
        // Verify data exists
        let result1 = await box1.get("key1")
        let result2 = await box2.get("key2")
        XCTAssertEqual(result1, "value1")
        XCTAssertEqual(result2, "value2")
        
        // When - clear only namespace1
        Pandora.clearUserDefaults(for: namespace1)
        
        // Then - create new boxes to test clearing (memory will be empty)
        let newBox1: PandoraUserDefaultsBox<String> = Pandora.UserDefaults.box(namespace: namespace1)
        let newBox2: PandoraUserDefaultsBox<String> = Pandora.UserDefaults.box(namespace: namespace2)
        
        // namespace1 should be empty (cleared), namespace2 should still have data
        let result3 = await newBox1.get("key1")
        let result4 = await newBox2.get("key2")
        XCTAssertNil(result3) // Data cleared for namespace1
        XCTAssertEqual(result4, "value2") // Data still exists for namespace2
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

