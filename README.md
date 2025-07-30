<div align="center">

<img src="Image/pandora.png" alt="Pandora" width="300" />

> “Zeus gave man Pandora, a beautiful evil … and from her jar flowed every misfortune that haunts humanity, leaving only hope left inside.”
>
> — Aeschylus

[![Platforms](https://img.shields.io/badge/Platforms-iOS%2016%2B%20%7C%20iPadOS%2016%2B%20%7C%20macOS%2014%2B%20%7C%20watchOS%209%2B%20%7C%20tvOS%2016%2B%20%7C%20visionOS%201%2B-blue.svg?style=flat)](#requirements)
<br>

[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg?style=flat)](https://swift.org)
[![SPM ready](https://img.shields.io/badge/SPM-ready-brightgreen.svg?style=flat-square)](https://swift.org/package-manager/)
[![Coverage](https://img.shields.io/badge/Coverage-98%25-brightgreen.svg?style=flat)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

A powerful, type-safe caching library for Swift that provides multiple storage strategies with a unified API. Built with Swift Concurrency, Combine integration, and modern Swift best practices.

</div>

## Features

✨ **Multiple Storage Strategies**
- **Memory Cache**: Fast in-memory storage with LRU eviction
- **Disk Cache**: Persistent file-based storage with actor isolation
- **Hybrid Cache**: Combines memory and disk for optimal performance
- **UserDefaults Cache**: Simple key-value storage with type safety

🚀 Modern Swift Architecture
- Built on Swift Concurrency (async/await) for clean, readable async code
- Actor-based isolation to ensure thread safety without locks
- Generic, type-safe APIs for flexibility and compile-time safety
- Optional Combine publishers for reactive data flow
- test asd

⚡ High Performance Caching
- LRU eviction for efficient memory usage
- Tunable TTL (Time To Live) for automatic expiration
- Background cleanup to reduce main thread load
- Zero-lock reads and actor-guarded writes for fast concurrent access

🧩 Flexible Configuration
- Namespace support for logical cache separation
- Pluggable storage backends (in-memory, disk, etc.)
- Custom eviction and expiration policies

## Installation

### Swift Package Manager

Add Pandora to your project using Xcode or by adding it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/joshgallantt/Pandora.git", from: "1.0.3")
]
```

## Quick Start

```swift
import Pandora

// Memory box for fast access
let memoryBox: PandoraMemoryBox<String, User> = Pandora.Memory.box()
memoryBox.put(key: "user123", value: user)
let cachedUser = memoryBox.get("user123")

// Disk box for persistence
let diskBox: PandoraDiskBox<String, User> = Pandora.Disk.box(namespace: "users")
await diskBox.put(key: "user123", value: user)
let persistedUser = await diskBox.get("user123")

// Hybrid box for best of both worlds
let hybridBox: PandoraHybridBox<String, User> = Pandora.Hybrid.box(namespace: "users")
hybridBox.put(key: "user123", value: user)
let hybridUser = await hybridBox.get("user123")
````

## Cache Types

### Memory Box

Perfect for frequently accessed data that doesn't need persistence.

```swift
let box: PandoraMemoryBox<String, Data> = Pandora.Memory.box(
    maxSize: 1000,
    expiresAfter: 3600 // 1 hour TTL
)

// Store data
box.put(key: "image_thumbnail", value: imageData)

// Retrieve data
if let data = box.get("image_thumbnail") {
    // Use cached data
}

// Observe changes with Combine
box.publisher(for: "image_thumbnail")
    .sink { data in
        // React to box changes
    }
    .store(in: &cancellables)
```


### Disk Box

Actor-isolated persistent storage for data that survives app restarts.

```swift
let box: PandoraDiskBox<String, UserProfile> = Pandora.Disk.box(
    namespace: "user_profiles",
    maxSize: 10000,
    expiresAfter: 86400 // 24 hours
)

await box.put(key: "profile_123", value: userProfile)
let profile = await box.get("profile_123")
await box.remove("profile_123")
await box.clear()
```


### Hybrid Box

Combines memory and disk storage for optimal performance and persistence.

```swift
let box: PandoraHybridBox<String, APIResponse> = Pandora.Hybrid.box(
    namespace: "api_cache",
    memoryMaxSize: 500,        // Fast memory access
    memoryExpiresAfter: 300,   // 5 minutes in memory
    diskMaxSize: 5000,         // Persistent storage
    diskExpiresAfter: 3600     // 1 hour on disk
)

// Stores in memory immediately, writes to disk asynchronously
box.put(key: "api_response", value: response)

// Checks memory first, falls back to disk, memory is rehydrated.
let cachedResponse = await box.get("api_response")

// Observe memory changes
box.publisher(for: "api_response")
    .sink { response in
        updateUI(with: response)
    }
    .store(in: &cancellables)
```


### UserDefaults Box

Type-safe `UserDefaults` storage with namespace isolation.

```swift
let box = Pandora.UserDefaults.box(namespace: "app_settings")

try await box.put(key: "username", value: "john_doe")
try await box.put(key: "darkMode", value: true)
try await box.put(key: "lastSync", value: Date())

let username: String = try await box.get("username")
let isDarkMode: Bool = try await box.get("darkMode")
let lastSync: Date = try await box.get("lastSync")
```


## Type Declaration Options

Pandora boxes are generic over `Key` and `Value` types. There are three ways to specify those types depending on context:

### 1. Explicit Type Annotation (recommended)

```swift
let box: PandoraMemoryBox<String, User> = Pandora.Memory.box()
```

### 2. Type Casting

```swift
let box = Pandora.Memory.box() as PandoraMemoryBox<String, User>
```

### 3. Explicit Type Parameters

Used when Swift can’t infer types or when calling dynamically:

```swift
let box = Pandora.Memory.box(
    keyType: String.self,
    valueType: User.self
)
```

> [!TIP]
> This is especially useful inside generic or factory contexts where the return type isn’t obvious.

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

// Observe specific keys
cache.publisher(for: "current_user")
    .compactMap { $0 } // Filter out nil values
    .sink { user in
        print("User updated: \(user.name)")
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
```

### Cache Cleanup

```swift
// Clear specific cache
cache.clear()
await diskCache.clear()

// Remove all disk cache data across all namespaces
Pandora.clearAllDiskData()
```

## Thread Safety

All Pandora cache types are designed for concurrent access:

- **Memory Cache**: Thread-safe with internal locking
- **Disk Cache**: Actor-isolated for async safety
- **Hybrid Cache**: Combines both safety models
- **UserDefaults Cache**: Actor-isolated async operations


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
