//
//  DefaultUserDefaultsBoxTests.swift
//  Pandoras
//
//  Created by Josh Gallant on 13/07/2025.
//


import XCTest
@testable import Pandoras

final class DefaultUserDefaultsBoxTests: XCTestCase {
    var storage: PandorasUserDefaultsBox!
    let namespace = "testNamespace"

    struct TestObject: Codable, Equatable, Sendable {
        let id: Int
        let name: String
    }

    override func setUp() {
        super.setUp()
        let userDefaults = UserDefaults(suiteName: "DefaultUserDefaultsStorageTests")!
        userDefaults.removePersistentDomain(forName: "DefaultUserDefaultsStorageTests")
        storage = PandorasUserDefaultsBox(namespace: namespace, userDefaults: userDefaults)
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Put and Get Basic Types

    func test_givenString_whenPutAndGet_thenValueIsReturned() async throws {
        // Given
        let value = "hello"

        // When
        try await storage.put(key: "myString", value: value)
        let result: String = try await self.storage.get("myString")

        // Then
        XCTAssertEqual(result, value)
    }

    func test_givenEmptyString_whenPutAndGet_thenEmptyStringIsReturned() async throws {
        // Given
        let value = ""

        // When
        try await storage.put(key: "myString", value: value)
        let result: String = try await self.storage.get("myString")

        // Then
        XCTAssertEqual(result, value)
    }

    func test_givenInt_whenPutAndGet_thenValueIsReturned() async throws {
        // Given
        let value = 42

        // When
        try await storage.put(key: "myInt", value: value)
        let result: Int = try await self.storage.get("myInt")

        // Then
        XCTAssertEqual(result, value)
    }

    func test_givenDouble_whenPutAndGet_thenValueIsReturned() async throws {
        // Given
        let value = 3.14

        // When
        try await storage.put(key: "myDouble", value: value)
        let result: Double = try await self.storage.get("myDouble")

        // Then
        XCTAssertEqual(result, value)
    }

    func test_givenBool_whenPutAndGet_thenValueIsReturned() async throws {
        // Given
        let value = true

        // When
        try await storage.put(key: "myBool", value: value)
        let result: Bool = try await self.storage.get("myBool")

        // Then
        XCTAssertEqual(result, value)
    }

    func test_givenFloat_whenPutAndGet_thenValueIsReturned() async throws {
        // Given
        let value = Float(1.23)

        // When
        try await storage.put(key: "myFloat", value: value)
        let result: Float = try await self.storage.get("myFloat")

        // Then
        XCTAssertEqual(result, value)
    }

    func test_givenDate_whenPutAndGet_thenValueIsReturned() async throws {
        // Given
        let value = Date()

        // When
        try await storage.put(key: "myDate", value: value)
        let result: Date = try await self.storage.get("myDate")

        // Then
        XCTAssertEqual(result.timeIntervalSince1970, value.timeIntervalSince1970, accuracy: 0.01)
    }

    func test_givenURL_whenPutAndGet_thenValueIsReturned() async throws {
        // Given
        let value = URL(string: "https://apple.com")!

        // When
        try await storage.put(key: "myURL", value: value)
        let result: URL = try await self.storage.get("myURL")

        // Then
        XCTAssertEqual(result, value)
    }

    func test_givenData_whenPutAndGet_thenValueIsReturned() async throws {
        // Given
        let value = "swift".data(using: .utf8)!

        // When
        try await storage.put(key: "myData", value: value)
        let result: Data = try await self.storage.get("myData")

        // Then
        XCTAssertEqual(result, value)
    }

    // MARK: - Custom Codable

    func test_givenCodable_whenPutAndGet_thenValueIsReturned() async throws {
        // Given
        let value = TestObject(id: 1, name: "Josh")

        // When
        try await storage.put(key: "myObject", value: value)
        let result: TestObject = try await self.storage.get("myObject")

        // Then
        XCTAssertEqual(result, value)
    }

    // MARK: - Nonexistent Keys

    func test_givenNonexistentStringKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "doesNotExist"

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(key) as String) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .valueNotFound(let ns, let gotKey) = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    // All types version, pattern repeated for coverage
    func test_givenNonexistentIntKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "doesNotExistInt"

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(key) as Int) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .valueNotFound(let ns, let gotKey) = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    func test_givenNonexistentDoubleKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "doesNotExistDouble"

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(key) as Double) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .valueNotFound(let ns, let gotKey) = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    func test_givenNonexistentBoolKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "doesNotExistBool"

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(key) as Bool) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .valueNotFound(let ns, let gotKey) = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    func test_givenNonexistentFloatKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "doesNotExistFloat"

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(key) as Float) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .valueNotFound(let ns, let gotKey) = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    func test_givenNonexistentDateKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "doesNotExistDate"

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(key) as Date) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .valueNotFound(let ns, let gotKey) = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    func test_givenNonexistentURLKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "doesNotExistURL"

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(key) as URL) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .valueNotFound(let ns, let gotKey) = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    func test_givenNonexistentDataKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "doesNotExistData"

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(key) as Data) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .valueNotFound(let ns, let gotKey) = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    func test_givenNonexistentCodableKey_whenGet_thenThrowsValueNotFound() async {
        // Given
        let key = "doesNotExistObject"

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(key) as TestObject) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .valueNotFound(let ns, let gotKey) = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    // MARK: - Remove and Clear

    func test_givenKeyExists_whenRemove_thenKeyIsRemoved() async throws {
        // Given
        try await storage.put(key: "removeMe", value: "value")

        // When
        await storage.remove("removeMe")

        // Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get("removeMe") as String) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .valueNotFound = storageError else {
                XCTFail("Expected valueNotFound error")
                return
            }
        }
    }

    func test_givenMultipleKeys_whenClear_thenAllNamespaceKeysAreRemoved() async throws {
        // Given
        try await storage.put(key: "one", value: "A")
        try await storage.put(key: "two", value: "B")

        // When
        await storage.clear()

        // Then
        let keys = await storage.allKeys()
        XCTAssertTrue(keys.isEmpty)
    }

    func test_givenKeyExists_whenClearAndRemoveAgain_thenNoErrorIsThrown() async throws {
        // Given
        try await storage.put(key: "toRemove", value: "something")
        await storage.clear()

        // When/Then
        await storage.remove("toRemove")
    }

    func test_givenOtherSuiteKey_whenClear_thenOtherSuiteKeyRemains() async throws {
        // Given
        let otherDefaults = UserDefaults(suiteName: "OtherSuite")!
        otherDefaults.set("shouldRemain", forKey: "randomKey")
        try await storage.put(key: "shouldRemove", value: "one")

        // When
        await storage.clear()

        // Then
        XCTAssertEqual(otherDefaults.string(forKey: "randomKey"), "shouldRemain")
    }

    // MARK: - allKeys & contains

    func test_givenKeysExist_whenAllKeys_thenReturnsOnlyNamespaceKeys() async throws {
        // Given
        try await storage.put(key: "key1", value: "a")
        try await storage.put(key: "key2", value: "b")

        // When
        let keys = await storage.allKeys()

        // Then
        XCTAssertEqual(Set(keys), Set(["key1", "key2"]))
    }

    func test_givenNoKeys_whenAllKeys_thenReturnsEmpty() async throws {
        // Given/When
        let keys = await storage.allKeys()

        // Then
        XCTAssertTrue(keys.isEmpty)
    }

    func test_givenKeyExists_whenContains_thenReturnsTrue() async throws {
        // Given
        try await storage.put(key: "foo", value: 123)

        // When
        let contains = await storage.contains("foo")

        // Then
        XCTAssertTrue(contains)
    }

    func test_givenKeyDoesNotExist_whenContains_thenReturnsFalse() async throws {
        // Given/When
        let contains = await storage.contains("nope")

        // Then
        XCTAssertFalse(contains)
    }

    // MARK: - Type Safety / Decoding / Encoding / Type mismatch

    func test_givenCorruptedData_whenGetCodable_thenThrowsDecodingFailed() async throws {
        // Given
        let key = "badCodable"
        let badData = "notjson".data(using: .utf8)!
        let udKey = "\(namespace).\(key)"
        let userDefaults = UserDefaults(suiteName: "DefaultUserDefaultsStorageTests")!
        userDefaults.set(badData, forKey: udKey)

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get(key) as TestObject) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .decodingFailed(let ns, let gotKey, _) = storageError else {
                XCTFail("Expected decodingFailed error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(gotKey, key)
        }
    }

    func test_givenFailingEncodable_whenPut_thenThrowsEncodingFailed() async throws {
        // Given
        struct FailingEncodable: Encodable, Sendable {
            func encode(to encoder: Encoder) throws {
                throw NSError(domain: "Test", code: 123, userInfo: nil)
            }
        }

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.put(key: "bad", value: FailingEncodable())) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .encodingFailed(let ns, let key, _) = storageError else {
                XCTFail("Expected encodingFailed error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(key, "bad")
        }
    }

    func test_givenLegacyURLData_whenGetURL_thenHandlesLegacyDataFormat() async throws {
        // Given
        let key = "urlFromData"
        let url = URL(string: "https://swift.org")!
        let data = try NSKeyedArchiver.archivedData(withRootObject: url, requiringSecureCoding: false)
        let udKey = "\(namespace).\(key)"
        let userDefaults = UserDefaults(suiteName: "DefaultUserDefaultsStorageTests")!
        userDefaults.set(data, forKey: udKey)

        // When
        let result: URL = try await self.storage.get(key)

        // Then
        XCTAssertEqual(result, url)
    }

    // MARK: - Type Mismatch

    func test_givenIntStored_whenGetAsString_thenThrowsTypeMismatch() async throws {
        // Given
        try await storage.put(key: "typeMismatchKey", value: 123)

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get("typeMismatchKey") as String) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .foundButTypeMismatch(let ns, let key, _, _) = storageError else {
                XCTFail("Expected foundButTypeMismatch error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(key, "typeMismatchKey")
        }
    }

    func test_givenStringStored_whenGetAsInt_thenThrowsTypeMismatch() async throws {
        // Given
        try await storage.put(key: "intButString", value: "abc")

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get("intButString") as Int) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .foundButTypeMismatch(let ns, let key, _, _) = storageError else {
                XCTFail("Expected foundButTypeMismatch error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(key, "intButString")
        }
    }

    func test_givenStringStored_whenGetAsDouble_thenThrowsTypeMismatch() async throws {
        // Given
        try await storage.put(key: "doubleButString", value: "hello")

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get("doubleButString") as Double) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .foundButTypeMismatch(let ns, let key, _, _) = storageError else {
                XCTFail("Expected foundButTypeMismatch error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(key, "doubleButString")
        }
    }

    func test_givenStringStored_whenGetAsURL_thenThrowsTypeMismatch() async throws {
        // Given
        try await storage.put(key: "urlButString", value: "notAURL")

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get("urlButString") as URL) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .foundButTypeMismatch(let ns, let key, _, _) = storageError else {
                XCTFail("Expected foundButTypeMismatch error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(key, "urlButString")
        }
    }

    func test_givenFloatStored_whenGetAsString_thenThrowsTypeMismatch() async throws {
        // Given
        try await storage.put(key: "floatAsString", value: Float(1.23))

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get("floatAsString") as String) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .foundButTypeMismatch(let ns, let key, _, _) = storageError else {
                XCTFail("Expected foundButTypeMismatch error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(key, "floatAsString")
        }
    }

    func test_givenStringStored_whenGetAsFloat_thenThrowsTypeMismatch() async throws {
        // Given
        try await storage.put(key: "floatButString", value: "hello")

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get("floatButString") as Float) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .foundButTypeMismatch(let ns, let key, _, _) = storageError else {
                XCTFail("Expected foundButTypeMismatch error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(key, "floatButString")
        }
    }

    func test_givenIntStored_whenGetAsDate_thenThrowsTypeMismatch() async throws {
        // Given
        try await storage.put(key: "dateButInt", value: 42)

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get("dateButInt") as Date) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .foundButTypeMismatch(let ns, let key, _, _) = storageError else {
                XCTFail("Expected foundButTypeMismatch error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(key, "dateButInt")
        }
    }

    func test_givenStringStored_whenGetAsData_thenThrowsTypeMismatch() async throws {
        // Given
        try await storage.put(key: "dataButString", value: "notdata")

        // When/Then
        await XCTAssertThrowsErrorAsync(try await self.storage.get("dataButString") as Data) { error in
            guard let storageError = error as? UserDefaultsStorageError,
                  case .foundButTypeMismatch(let ns, let key, _, _) = storageError else {
                XCTFail("Expected foundButTypeMismatch error")
                return
            }
            XCTAssertEqual(ns, self.namespace)
            XCTAssertEqual(key, "dataButString")
        }
    }

    // MARK: - Overwrite

    func test_givenKeyExists_whenPutAgain_thenValueIsOverwrittenAndNoDuplicateKey() async throws {
        // Given
        let initial = TestObject(id: 1, name: "First")
        let updated = TestObject(id: 2, name: "Second")
        try await storage.put(key: "sharedKey", value: initial)

        // When
        let keysAfterFirstPut = await storage.allKeys()
        try await storage.put(key: "sharedKey", value: updated)
        let keysAfterUpdate = await storage.allKeys()
        let result: TestObject = try await self.storage.get("sharedKey")

        // Then
        XCTAssertEqual(keysAfterFirstPut, ["sharedKey"])
        XCTAssertEqual(keysAfterUpdate, ["sharedKey"])
        XCTAssertEqual(result, updated)
    }

    // MARK: - Helper

    func XCTAssertThrowsErrorAsync<T>(
        _ expression: @autoclosure @escaping () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error to be thrown" + (message().isEmpty ? "" : ": \(message())"), file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }
}
