<div align="center">

<h1>Pandoras</h1>

[![Platforms](https://img.shields.io/badge/Platforms-iOS%2016%2B%20%7C%20iPadOS%2016%2B%20%7C%20macOS%2014%2B%20%7C%20watchOS%209%2B%20%7C%20tvOS%2016%2B%20%7C%20visionOS%201%2B-blue.svg?style=flat)](#requirements)
<br>

[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg?style=flat)](https://swift.org)
[![SPM ready](https://img.shields.io/badge/SPM-ready-brightgreen.svg?style=flat-square)](https://swift.org/package-manager/)
[![Coverage](https://img.shields.io/badge/Coverage-98%25-brightgreen.svg?style=flat)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

</div>

A modern, type-safe Swift package providing thread-safe caching and storage solutions with comprehensive expiry, LRU eviction, and reactive observation capabilities.

## Overview

Pandoras offers four specialized storage "boxes" that can be used individually or combined to create powerful caching architectures:

- **MemoryBox** - Fast, in-memory caching with LRU eviction and TTL support
- **DiskBox** - Persistent disk storage with namespace isolation and file-based caching
- **UserDefaultsBox** - Type-safe UserDefaults wrapper with async/await support
- **HybridBox** - Combines memory and disk storage for optimal performance and persistence

## Features

- ✅ **Type Safety** - Full generic support with Codable constraints where needed
- ✅ **Thread Safety** - All components are designed for concurrent access
- ✅ **Reactive** - Combine publishers for real-time value observation
- ✅ **Expiry Support** - Global and per-key TTL with automatic cleanup
- ✅ **LRU Eviction** - Configurable size limits with least-recently-used eviction
- ✅ **Namespace Isolation** - Prevent key collisions across different use cases
- ✅ **Actor Isolation** - Modern Swift concurrency patterns for disk operations
- ✅ **Comprehensive Testing** - Extensive test coverage with mocks for easy testing

## Installation

### Swift Package Manager

Add Pandoras to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/Pandoras.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/yourusername/Pandoras.git`

## Quick Start

### Memory Caching

```swift
import Pandoras

// Create an in-memory cache with 100 item limit and 5-minute TTL
let cache = DefaultMemoryBox<String, User>(maxSize: 100, expiresAfter: 300)

// Store a value
cache.put("user123", value: user)

// Retrieve a value
let user = cache.get("user123")

// Observe changes with Combine
cache.publisher(for: "user123")
    .sink { user in
        print("User updated: \(user)")
    }
    .store(in: &cancellables)
```

### Disk Storage

```swift
// Create a disk-backed cache with namespace isolation
let diskCache = DefaultDiskBox<String, UserProfile>(
    namespace: "user-profiles",
    maxSize: 1000,
    expiresAfter: 3600
)

// Store with custom expiry
await diskCache.put("profile456", value: profile, expiresAfter: 1800)

// Retrieve
let profile = await diskCache.get("profile456")

// Clear all data for this namespace
await diskCache.clear()
```

### UserDefaults Storage

```swift
// Type-safe UserDefaults wrapper
let settings = DefaultUserDefaultsBox(namespace: "app-settings")

// Store any Codable type
try await settings.put(userPreferences, forKey: "preferences")

// Retrieve with strong typing
let preferences: UserPreferences = try await settings.get(forKey: "preferences")

// Check existence
let hasPrefs = await settings.contains("preferences")
```

### Hybrid Storage (Best of Both Worlds)

```swift
// Combines fast memory access with persistent disk storage
let hybridCache = DefaultHybridBox<String, APIResponse>(
    namespace: "api-cache",
    memoryMaxSize: 50,           // Keep 50 items in memory
    memoryExpiresAfter: 300,     // Memory TTL: 5 minutes
    diskMaxSize: 500,            // Keep 500 items on disk
    diskExpiresAfter: 3600       // Disk TTL: 1 hour
)

// Store once - goes to both memory and disk
hybridCache.put("api/users", value: response)

// Fast retrieval - checks memory first, then disk
let response = await hybridCache.get("api/users")

// Reactive observation
hybridCache.publisher(for: "api/users")
    .compactMap { $0 }
    .sink { response in
        updateUI(with: response)
    }
```

## Advanced Usage

### Custom Expiry Per Key

```swift
// Global TTL with per-key overrides
let cache = DefaultMemoryBox<String, Data>(expiresAfter: 3600)

// This item expires in 10 minutes instead of 1 hour
cache.put("short-lived", value: data, expiresAfter: 600)

// This item never expires (overrides global TTL)
cache.put("permanent", value: data, expiresAfter: 0)
```

### Namespace Isolation

```swift
// Different namespaces prevent key collisions
let userCache = DefaultDiskBox<String, User>(namespace: "users")
let postCache = DefaultDiskBox<String, Post>(namespace: "posts")

// These don't interfere with each other
await userCache.put("123", value: user)
await postCache.put("123", value: post)
```

### Reactive Programming

```swift
// Observe multiple keys
let userPublisher = cache.publisher(for: "current-user")
let settingsPublisher = cache.publisher(for: "user-settings")

Publishers.CombineLatest(userPublisher, settingsPublisher)
    .compactMap { user, settings in
        guard let user = user, let settings = settings else { return nil }
        return (user, settings)
    }
    .sink { user, settings in
        configureApp(for: user, with: settings)
    }
```

### Testing Support

Pandoras includes mock implementations for easy testing:

```swift
// Use mocks in your tests
let mockCache = MockMemoryBox<String, TestData>()
let mockDisk = MockDiskBox<String, TestData>()
let mockHybrid = MockHybridBox<String, TestData>()

// Inject mocks into your classes
class DataManager {
    let cache: any MemoryBox<String, APIResponse>
    
    init(cache: any MemoryBox<String, APIResponse> = DefaultMemoryBox()) {
        self.cache = cache
    }
}

// Test with mock
let manager = DataManager(cache: mockCache)
```


## Global Cache Management

```swift
// Clear all disk caches across the entire app
DefaultDiskBox<String, Any>.clearAll()
DefaultHybridBox<String, Any>.clearAll()

// Per-instance clearing
await specificCache.clear()
```

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

Pandoras is available under the MIT license. See the [LICENSE](LICENSE) file for more info.

## Credits

Created with ❤️ by Josh Gallant - for the Swift community.
