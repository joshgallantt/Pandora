//
//  PandoraLock.swift
//  Pandora
//
//  Created by Josh Gallant on 07/08/2025.
//


/// A lightweight actor-based mutex for synchronizing critical sections.
/// Provides compile-time thread-safety guarantees using Swift's actor model.
///
/// Usage:
/// ```swift
/// private let lock = PandoraLock()
///
/// // Synchronous critical section
/// await lock.withCriticalRegion {
///     // Code that needs exclusive access
/// }
///
/// // Async critical section
/// await lock.withCriticalRegion {
///     await someAsyncOperation()
/// }
/// ```
public actor PandoraLock {
    
    /// Executes a synchronous closure within a critical region.
    /// - Parameter body: The closure to execute exclusively.
    /// - Returns: The value returned by the closure.
    /// - Throws: Any error thrown by the closure.
    public func withCriticalRegion<T>(_ body: () throws -> T) rethrows -> T {
        try body()
    }
    
    /// Executes an asynchronous closure within a critical region.
    /// - Parameter body: The async closure to execute exclusively.
    /// - Returns: The value returned by the closure.
    /// - Throws: Any error thrown by the closure.
    public func withCriticalRegion<T>(_ body: @Sendable () async throws -> T) async rethrows -> T {
        try await body()
    }
}
