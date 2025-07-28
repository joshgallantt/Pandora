//
//  CalculateExpiryDateTests.swift
//  Pandoras
//
//  Created by Josh Gallant on 27/07/2025.
//

import XCTest
@testable import Pandoras

final class CalculateExpiryDateTests: XCTestCase {
    private let referenceDate = Date(timeIntervalSince1970: 1_000_000)

    private func expectedExpiry(overrideTTL: TimeInterval?, fallbackTTL: TimeInterval?) -> Date? {
        if let override = overrideTTL {
            if override > 0 {
                return referenceDate.addingTimeInterval(override)
            } else {
                return nil
            }
        }
        if let fallback = fallbackTTL, fallback > 0 {
            return referenceDate.addingTimeInterval(fallback)
        }
        return nil
    }

    func test_givenPositiveOverrideTTL_whenCalculateExpiryDate_thenReturnsDatePlusOverride() {
        // Given
        let overrideTTL: TimeInterval? = 60
        let fallbackTTL: TimeInterval? = 120

        // When
        let expected = referenceDate.addingTimeInterval(overrideTTL!)
        let expiry = expectedExpiry(overrideTTL: overrideTTL, fallbackTTL: fallbackTTL)

        // Then
        XCTAssertNotNil(expiry)
        XCTAssertEqual(expiry?.timeIntervalSince1970, expected.timeIntervalSince1970)
    }

    func test_givenZeroOverrideTTL_whenCalculateExpiryDate_thenReturnsNil() {
        // Given
        let overrideTTL: TimeInterval? = 0
        let fallbackTTL: TimeInterval? = 120

        // When
        let expiry = expectedExpiry(overrideTTL: overrideTTL, fallbackTTL: fallbackTTL)

        // Then
        XCTAssertNil(expiry)
    }

    func test_givenNegativeOverrideTTL_whenCalculateExpiryDate_thenReturnsNil() {
        // Given
        let overrideTTL: TimeInterval? = -1
        let fallbackTTL: TimeInterval? = 120

        // When
        let expiry = expectedExpiry(overrideTTL: overrideTTL, fallbackTTL: fallbackTTL)

        // Then
        XCTAssertNil(expiry)
    }

    func test_givenNilOverride_andPositiveFallbackTTL_whenCalculateExpiryDate_thenReturnsDatePlusFallback() {
        // Given
        let overrideTTL: TimeInterval? = nil
        let fallbackTTL: TimeInterval? = 90

        // When
        let expected = referenceDate.addingTimeInterval(fallbackTTL!)
        let expiry = expectedExpiry(overrideTTL: overrideTTL, fallbackTTL: fallbackTTL)

        // Then
        XCTAssertNotNil(expiry)
        XCTAssertEqual(expiry?.timeIntervalSince1970, expected.timeIntervalSince1970)
    }

    func test_givenNilOverride_andZeroFallbackTTL_whenCalculateExpiryDate_thenReturnsNil() {
        // Given
        let overrideTTL: TimeInterval? = nil
        let fallbackTTL: TimeInterval? = 0

        // When
        let expiry = expectedExpiry(overrideTTL: overrideTTL, fallbackTTL: fallbackTTL)

        // Then
        XCTAssertNil(expiry)
    }

    func test_givenNilOverride_andNegativeFallbackTTL_whenCalculateExpiryDate_thenReturnsNil() {
        // Given
        let overrideTTL: TimeInterval? = nil
        let fallbackTTL: TimeInterval? = -42

        // When
        let expiry = expectedExpiry(overrideTTL: overrideTTL, fallbackTTL: fallbackTTL)

        // Then
        XCTAssertNil(expiry)
    }

    func test_givenNilOverride_andNilFallback_whenCalculateExpiryDate_thenReturnsNil() {
        // Given
        let overrideTTL: TimeInterval? = nil
        let fallbackTTL: TimeInterval? = nil

        // When
        let expiry = expectedExpiry(overrideTTL: overrideTTL, fallbackTTL: fallbackTTL)

        // Then
        XCTAssertNil(expiry)
    }
}

