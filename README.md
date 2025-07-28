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

A powerful, type-safe caching library for iOS that provides multiple storage strategies with a unified API. Built with Swift Concurrency, Combine integration, and modern Swift best practices.

</div>

## Features

✨ **Multiple Storage Strategies**
- **Memory Cache**: Fast in-memory storage with LRU eviction
- **Disk Cache**: Persistent file-based storage with actor isolation
- **Hybrid Cache**: Combines memory and disk for optimal performance
- **UserDefaults Cache**: Simple key-value storage with type safety

🚀 **Modern Swift**
- Built with Swift Concurrency (async/await)
- Actor isolation for thread safety
- Combine publishers for reactive programming
- Generic types with full type safety

⚡ **Performance & Features**
- LRU (Least Recently Used) eviction policies
- Configurable TTL (Time To Live) expiration
- Namespace isolation for multi-cache scenarios
- Automatic cleanup and memory management

## Installation

### Swift Package Manager

Add Pandora to your project using Xcode or by adding it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/pandoras-cache.git", from: "1.0.0")
]
```

## Quick Start

```swift
import Pandora

// Memory cache for fast access (explicit type annotation)
let memoryCache: PandoraMemoryBox<String, User> = Pandora.Memory.box()
memoryCache.put(key: "user123", value: user)
let cachedUser = memoryCache.get("user123")

// Disk cache for persistence (type casting)
let diskCache = Pandora.Disk.box(namespace: "users") as PandoraDiskBox<String, User>
await diskCache.put(key: "user123", value: user)
let persistedUser = await diskCache.get("user123")

// Hybrid cache for best of both worlds (explicit type annotation)
let hybridCache: PandoraHybridBox<String, User> = Pandora.Hybrid.box(namespace: "users")
hybridCache.put(key: "user123", value: user)
let hybridUser = await hybridCache.get("user123")
```

## Cache Types

### Memory Cache

Perfect for frequently accessed data that doesn't need persistence.

```swift
// Option 1: Explicit type annotation
let cache: PandoraMemoryBox<String, Data> = Pandora.Memory.box(
    maxSize: 1000,
    expiresAfter: 3600 // 1 hour TTL
)

// Option 2: Using explicit type parameters
let cache = Pandora.Memory.box(
    keyType: String.self,
    valueType: Data.self,
    maxSize: 1000,
    expiresAfter: 3600
)

// Store data
cache.put(key: "image_thumbnail", value: imageData)

// Retrieve data
if let data = cache.get("image_thumbnail") {
    // Use cached data
}

// Observe changes with Combine
cache.publisher(for: "image_thumbnail")
    .sink { data in
        // React to cache changes
    }
    .store(in: &cancellables)
```

### Disk Cache

Actor-isolated persistent storage for data that survives app restarts.

```swift
// Option 1: Type casting
let diskCache = Pandora.Disk.box(
    namespace: "user_profiles",
    maxSize: 10000,
    expiresAfter: 86400 // 24 hours
) as PandoraDiskBox<String, UserProfile>

// Option 2: Using explicit type parameters
let diskCache = Pandora.Disk.box(
    namespace: "user_profiles",
    keyType: String.self,
    valueType: UserProfile.self,
    maxSize: 10000,
    expiresAfter: 86400
)

// All operations are async
await diskCache.put(key: "profile_123", value: userProfile)
let profile = await diskCache.get("profile_123")
await diskCache.remove("profile_123")
await diskCache.clear()
```

### Hybrid Cache

Combines memory and disk caching for optimal performance and persistence.

```swift
// Option 1: Explicit type annotation
let hybridCache: PandoraHybridBox<String, APIResponse> = Pandora.Hybrid.box(
    namespace: "api_cache",
    memoryMaxSize: 500,        // Fast memory access
    memoryExpiresAfter: 300,   // 5 minutes in memory
    diskMaxSize: 5000,         // Persistent storage
    diskExpiresAfter: 3600     // 1 hour on disk
)

// Option 2: Using explicit type parameters
let hybridCache = Pandora.Hybrid.box(
    namespace: "api_cache",
    keyType: String.self,
    valueType: APIResponse.self,
    memoryMaxSize: 500,
    memoryExpiresAfter: 300,
    diskMaxSize: 5000,
    diskExpiresAfter: 3600
)

// Stores in memory immediately, writes to disk asynchronously
hybridCache.put(key: "api_response", value: response)

// Checks memory first, falls back to disk
let cachedResponse = await hybridCache.get("api_response")

// Observe memory changes
hybridCache.publisher(for: "api_response")
    .sink { response in
        updateUI(with: response)
    }
    .store(in: &cancellables)
```

### UserDefaults Cache

Type-safe UserDefaults storage with namespace isolation.

```swift
let settingsCache = Pandora.UserDefaults.box(namespace: "app_settings")

// Store various types safely
try await settingsCache.put(key: "username", value: "john_doe")
try await settingsCache.put(key: "darkMode", value: true)
try await settingsCache.put(key: "lastSync", value: Date())

// Retrieve with full type safety
let username: String = try await settingsCache.get("username")
let isDarkMode: Bool = try await settingsCache.get("darkMode")
let lastSync: Date = try await settingsCache.get("lastSync")
```

## Advanced Usage

### Custom Expiration Per Key

```swift
// Explicit type annotation required
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
// Explicit type annotation required
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

## Cache Management

### Cleanup Operations

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
import Combine

final class WishlistRepository {
    private let cache: DefaultMemoryBox<String, Set<String>>
    private let service: WishlistService
    private let wishlistKey = "wishlist"

    init(cache: ObservableMemoryCache<String, Set<String>>, service: WishlistService) {
        self.cache = cache
        self.service = service
    }

    func observeIsWishlisted(productID: String) -> AnyPublisher<Bool, Never> {
        cache.publisher(for: wishlistKey)
            .map { ids in ids?.contains(productID) ?? false }
            .eraseToAnyPublisher()
    }

    func addToWishlist(productID: String) async throws {
        let updatedIDs = try await service.addProduct(productID: productID)
        cache.put(wishlistKey, value: Set(updatedIDs))
    }

    func removeFromWishlist(productID: String) async throws {
        let updatedIDs = try await service.removeProduct(productID: productID)
        cache.put(wishlistKey, value: Set(updatedIDs))
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
