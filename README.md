<div align="center">

<img src="Image/pandora.png" alt="Pandora" width="300" />

> “Zeus gave man Pandora, a beautiful evil … and from her jar flowed every misfortune that haunts humanity, leaving only hope left inside.”
>
> — Aeschylus

[![Platforms](https://img.shields.io/badge/Platforms-iOS%2016%2B%20%7C%20iPadOS%2016%2B%20%7C%20macOS%2014%2B%20%7C%20watchOS%209%2B%20%7C%20tvOS%2016%2B%20%7C%20visionOS%201%2B-blue.svg?style=flat)](#requirements)
<br>

[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg?style=flat)](https://swift.org)
[![SPM ready](https://img.shields.io/badge/SPM-ready-brightgreen.svg?style=flat-square)](https://swift.org/package-manager/)
[![Coverage](https://img.shields.io/badge/Coverage-98%2B%25-brightgreen.svg?style=flat)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Size](https://img.shields.io/badge/Package_Size-1.5MB-purple.svg?style=flat-square)](#)


A powerful, type-safe caching library for Swift that provides multiple storage strategies with a unified API. Built with Swift Concurrency, Combine integration, and modern Swift best practices.

</div>

## Table of Contents

1. [Features](#features)
2. [Installation](#installation)  
   - [Swift Package Manager](#swift-package-manager)
3. [Quick Start](#quick-start)
4. [Cache Types](#cache-types)  
   - [Memory Box](#memory-box)  
   - [Disk Box](#disk-box)  
   - [Hybrid Box](#hybrid-box)  
   - [UserDefaults Box](#userdefaults-box)
5. [Type Declaration Options](#type-declaration-options)  
   - [Explicit Type Annotation](#1-explicit-type-annotation-recommended)  
   - [Type Casting](#2-type-casting)  
   - [Explicit Type Parameters](#3-explicit-type-parameters)
6. [Advanced Usage](#advanced-usage)  
   - [Custom Expiration Per Key](#custom-expiration-per-key)  
   - [Reactive Programming with Combine](#reactive-programming-with-combine)  
   - [Cache Cleanup](#cache-cleanup)
7. [Thread Safety](#thread-safety)
8. [Clean Architecture Example Usage](#clean-architecture-example-usage)  
   - [Repository Layer](#1-create-your-repository-and-initialise-the-cache)  
   - [Use Cases](#2-use-cases-use-the-cache)  
   - [ViewModels](#3-viewmodels-use-the-use-cases)
9. [License](#license)

## Features

✨ **Multiple Storage Strategies**
- **Memory Cache**: Fast in-memory storage with LRU eviction and optional TTL
- **Disk Cache**: Persistent file-based storage with actor isolation and optional TTL
- **Hybrid Cache**: Combines memory + disk with concurrent load deduplication
- **UserDefaults Cache**: Namespaced, type-safe storage with optional iCloud sync, global limits, and per-item size caps  
- **Lightweight**: ~1.5MB, zero dependencies

🚀 **Modern Swift Architecture**
- Built on **Swift Concurrency** (`async/await`)  
- **Actor isolation** for safe persistence without manual locks  
- Generic, type-safe APIs  
- **Combine** publishers for reactive data flow with simplified API  

⚡ **Performance**
- LRU eviction in memory & disk
- Per-entry and global TTLs
- Concurrent load deduplication in HybridBox (`inflight` task pooling)
- Namespace-based cache separation

## Installation

### Swift Package Manager

Add Pandora to your project using Xcode or by adding it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/joshgallantt/Pandora.git", from: "3.2.0")
]
```

## Quick Start

```swift
import Pandora

// Memory cache — fast, in-memory only
let memoryBox: PandoraMemoryBox<String, User> = Pandora.Memory.box()
memoryBox.put(key: "user123", value: user)
let cachedUser = memoryBox.get("user123")

// Disk cache — persistent, actor-isolated
let diskBox: PandoraDiskBox<String, User> = Pandora.Disk.box(namespace: "users")
await diskBox.put(key: "user123", value: user)
let persistedUser = await diskBox.get("user123")

// Hybrid cache — memory first, disk fallback, async hydration
let hybridBox: PandoraHybridBox<String, User> = Pandora.Hybrid.box(namespace: "users")
hybridBox.put(key: "user123", value: user)
let hybridUser = await hybridBox.get("user123")

// UserDefaults cache — type-safe key-value store with optional iCloud sync
let defaultsBox: PandoraUserDefaultsBox<User> = Pandora.UserDefaults.box(
    namespace: "user_defaults",
    iCloudBacked: true // default: true
)
defaultsBox.put(key: "user123", value: user)
let defaultsUser = await defaultsBox.get("user123")
```

## Cache Types

### Memory Box

Perfect for frequently accessed data that doesn't need persistence.

```swift
let box: PandoraMemoryBox<String, Data> = Pandora.Memory.box(
    maxSize: 1000,
    expiresAfter: 3600
)

box.put(key: "thumb", value: imageData)
let data = box.get("thumb")

box.publisher(for: "thumb")
    .sink { /* react to updates */ }
    .store(in: &cancellables)
```


### Disk Box

Actor-isolated persistent storage for data that survives app restarts.

```swift
let box: PandoraDiskBox<String, UserProfile> = Pandora.Disk.box(
    namespace: "profiles",
    maxSize: 10000,
    expiresAfter: 86400
)

await box.put(key: "p1", value: userProfile)
let profile = await box.get("p1")
```


### Hybrid Box

Combines memory and disk storage for optimal performance and persistence.

```swift
let box: PandoraHybridBox<String, APIResponse> = Pandora.Hybrid.box(
    namespace: "api_cache",
    memoryMaxSize: 500,
    memoryExpiresAfter: 300,
    diskMaxSize: 5000,
    diskExpiresAfter: 3600
)

box.put(key: "resp", value: response)
let cached = await box.get("resp")

box.publisher(for: "resp")
    .sink { updateUI($0) }
    .store(in: &cancellables)
```

### UserDefaults Box

Type-safe `UserDefaults` storage with namespace isolation,
optional iCloud synchronization.

```swift
let settingsBox: PandoraUserDefaultsBox<String> =
    Pandora.UserDefaults.box(namespace: "settings")
settingsBox.put(key: "username", value: "john")
let username = await settingsBox.get("username")
```

> [!WARNING] 
> * Max **1024 items** across all `UserDefaultsBox` instances
> * Max **1KB per stored value**
> * Enforced globally`

> [!TIP]
> To enable iCloud synchronization, you must add the **iCloud** capability in your Xcode target’s **Signing & Capabilities** tab, and under iCloud services check **Key-Value storage**. Without this, iCloud-backed `UserDefaults` (via `NSUbiquitousKeyValueStore`) will not work.

## Type Declaration Options

Pandora boxes are generic over their key and value types (except `UserDefaults`, which is generic only over the value type).
There are three ways to specify those types depending on context.


### 1. Explicit Type Annotation (recommended)

```swift
// Memory, Disk, and Hybrid require both Key and Value types
let memoryBox: PandoraMemoryBox<String, User> = Pandora.Memory.box()
let diskBox: PandoraDiskBox<String, User> = Pandora.Disk.box(namespace: "users")
let hybridBox: PandoraHybridBox<String, User> = Pandora.Hybrid.box(namespace: "users")

// UserDefaults requires only Value type
let defaultsBox: PandoraUserDefaultsBox<User> = Pandora.UserDefaults.box(namespace: "users")
```


### 2. Type Casting

```swift
let memoryBox = Pandora.Memory.box() as PandoraMemoryBox<String, User>
let diskBox = Pandora.Disk.box(namespace: "users") as PandoraDiskBox<String, User>
let hybridBox = Pandora.Hybrid.box(namespace: "users") as PandoraHybridBox<String, User>
let defaultsBox = Pandora.UserDefaults.box(namespace: "users") as PandoraUserDefaultsBox<User>
```


### 3. Explicit Type Parameters

Useful when Swift can’t infer types or when constructing dynamically (e.g., in generic or factory contexts).

```swift
// Memory, Disk, Hybrid
let memoryBox = Pandora.Memory.box(
    keyType: String.self,
    valueType: User.self
)

let diskBox = Pandora.Disk.box(
    namespace: "users",
    keyType: String.self,
    valueType: User.self
)

let hybridBox = Pandora.Hybrid.box(
    namespace: "users",
    keyType: String.self,
    valueType: User.self
)

// UserDefaults only requires Value type
let defaultsBox = Pandora.UserDefaults.box(
    namespace: "users",
    valueType: User.self
)
```

> [!TIP]
> Explicit type parameters are especially useful inside generic or factory contexts where the return type isn’t obvious.

## Advanced Usage

### Custom Expiration Per Key

```swift
let cache: PandoraMemoryBox<String, Data> = Pandora.Memory.box()

// Store with custom TTL
cache.put(
    key: "short_lived_data", 
    value: data, 
    expiresAfter: 60 // 1 minute
)

// Store without expiration (overrides global TTL)
cache.put(
    key: "permanent_data", 
    value: data, 
    expiresAfter: nil
)
```

### Reactive Programming with Combine

```swift
let cache: PandoraMemoryBox<String, User> = Pandora.Memory.box()

// Observe specific keys (emits current value immediately)
cache.publisher(for: "current_user")
    .compactMap { $0 } // Filter out nil values
    .sink { user in
        print("User updated: \(user.name)")
    }
    .store(in: &cancellables)

// Observe changes (current value is always emitted)
cache.publisher(for: "current_user")
    .compactMap { $0 }
    .sink { user in
        print("User changed: \(user.name)")
    }
    .store(in: &cancellables)

// Chain multiple cache operations
cache.publisher(for: "user_id")
    .compactMap { $0 }
    .flatMap { userId in
        fetchUserDetails(userId)
    }
    .sink { userDetails in
        // Handle user details
    }
    .store(in: &cancellables)

// Skip initial value if you only want future updates
cache.publisher(for: "current_user")
    .dropFirst() // Skip the immediate current value emission
    .compactMap { $0 }
    .sink { user in
        print("User changed: \(user.name)")
    }
    .store(in: &cancellables)
```

#### Publisher Behavior

All Pandora publishers emit the current value immediately upon subscription, followed by any future changes:

- `publisher(for: "key")` - Emits current value immediately, then future changes
- Use `.dropFirst()` if you only want to observe future changes, not the current value

### Cache Cleanup

```swift
// Clear specific cache instances
memoryCache.clear()                    // Synchronous for MemoryBox
await diskCache.clear()                // Asynchronous for DiskBox
await hybridCache.clear()              // Asynchronous for HybridBox
await userDefaultsCache.clear()        // Asynchronous for UserDefaultsBox

// Clear specific namespaces
Pandora.clearUserDefaults(for: "my_settings")    // Clear specific UserDefaults namespace
Pandora.clearDiskData(for: "my_cache")           // Clear specific disk namespace

// Clear all data
Pandora.clearAllUserDefaults()         // Clear all Pandora UserDefaults data
Pandora.clearAllDiskData()             // Clear all Pandora disk caches
Pandora.deleteAllLocalStorage()        // Nuclear option - clear everything
```

## Thread Safety

All Pandora cache types are designed for concurrent access:

* **MemoryBox**: Lock-based thread safety
* **DiskBox**: Actor-isolated
* **HybridBox**: Locks for memory + inflight tracking, actor-isolated disk
* **UserDefaultsBox**: Locks + optional iCloud sync


## Clean Architecture Example Usage

**1. Create your repository and initialise the Cache**

```Swift
import Pandora
import Combine

final class WishlistRepository {
    private let cache: PandoraMemoryBox<String, Set<String>>
    private let service: WishlistService
    private let wishlistKey = "wishlist"

    init(service: WishlistService) {
        self.service = service
        self.cache = Pandora.Memory.box(
            maxSize: 1000,
            expiresAfter: 3600 // 1 hour TTL
        )
    }

    func observeIsWishlisted(productID: String) -> AnyPublisher<Bool, Never> {
        cache.publisher(for: wishlistKey)
            .map { ids in ids?.contains(productID) ?? false }
            .eraseToAnyPublisher()
    }

    func addToWishlist(productID: String) async throws {
        let updatedIDs = try await service.addProduct(productID: productID)
        cache.put(key: wishlistKey, value: Set(updatedIDs))
    }

    func removeFromWishlist(productID: String) async throws {
        let updatedIDs = try await service.removeProduct(productID: productID)
        cache.put(key: wishlistKey, value: Set(updatedIDs))
    }
}
```

**2. Use Cases use the Cache**

```Swift
struct ObserveProductInWishlistUseCase {
    private let repository: WishlistRepository
    init(repository: WishlistRepository) { self.repository = repository }

    func execute(productID: String) -> AnyPublisher<Bool, Never> {
        repository.observeIsWishlisted(productID: productID)
            .removeDuplicates() // Ensures only changes are delivered to ViewModel
            .eraseToAnyPublisher()
    }
}

struct AddProductToWishlistUseCase {
    private let repository: WishlistRepository
    init(repository: WishlistRepository) { self.repository = repository }

    func execute(productID: String) async throws {
        try await repository.addToWishlist(productID: productID)
    }
}

struct RemoveProductFromWishlistUseCase {
    private let repository: WishlistRepository
    init(repository: WishlistRepository) { self.repository = repository }

    func execute(productID: String) async throws {
        try await repository.removeFromWishlist(productID: productID)
    }
}
```

**3. ViewModels use the Use Cases**

```Swift
import Combine
import Foundation

@MainActor
final class WishlistButtonViewModel: ObservableObject {
    @Published private(set) var isWishlisted: Bool = false

    private let productID: String
    private let observeProductInWishlist: ObserveProductInWishlistUseCase
    private let addProductToWishlist: AddProductToWishlistUseCase
    private let removeProductFromWishlist: RemoveProductFromWishlistUseCase

    private var cancellables = Set<AnyCancellable>()

    init(
        productID: String,
        observeProductInWishlist: ObserveProductInWishlistUseCase,
        addProductToWishlist: AddProductToWishlistUseCase,
        removeProductFromWishlist: RemoveProductFromWishlistUseCase
    ) {
        self.productID = productID
        self.observeProductInWishlist = observeProductInWishlist
        self.addProductToWishlist = addProductToWishlist
        self.removeProductFromWishlist = removeProductFromWishlist

        observeWishlistState()
    }

    private func observeWishlistState() {
        observeProductInWishlist.execute(productID: productID)
            .receive(on: DispatchQueue.main)
            .assign(to: &$isWishlisted)
    }

    func toggleWishlist() {
        let newValue = !isWishlisted
        isWishlisted = newValue

        Task(priority: .userInitiated) { [self, newValue] in
            do {
                if newValue {
                    try await addProductToWishlist.execute(productID: productID)
                } else {
                    try await removeProductFromWishlist.execute(productID: productID)
                }
            } catch {
                await MainActor.run {
                    isWishlisted = !newValue
                }
            }
        }
    }
}
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

----

Created with ❤️ by Josh Gallant - for the Swift community.
