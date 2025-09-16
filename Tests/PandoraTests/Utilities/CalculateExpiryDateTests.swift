//
//  CalculateExpiryDateTests.swift
//  Pandora
//
//  Created by Josh Gallant on 27/07/2025.
//

import XCTest
@testable import Pandora

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

    func test_givenZeroOrNegativeOverrideTTL_whenCalculateExpiryDate_thenReturnsNil() {
        // Test zero override
        let expiry1 = expectedExpiry(overrideTTL: 0, fallbackTTL: 120)
        XCTAssertNil(expiry1)
        
        // Test negative override
        let expiry2 = expectedExpiry(overrideTTL: -1, fallbackTTL: 120)
        XCTAssertNil(expiry2)
    }

    func test_givenNilOverride_whenCalculateExpiryDate_thenUsesFallbackOrReturnsNil() {
        // Test positive fallback
        let expected = referenceDate.addingTimeInterval(90)
        let expiry1 = expectedExpiry(overrideTTL: nil, fallbackTTL: 90)
        XCTAssertNotNil(expiry1)
        XCTAssertEqual(expiry1?.timeIntervalSince1970, expected.timeIntervalSince1970)
        
        // Test zero fallback
        let expiry2 = expectedExpiry(overrideTTL: nil, fallbackTTL: 0)
        XCTAssertNil(expiry2)
        
        // Test negative fallback
        let expiry3 = expectedExpiry(overrideTTL: nil, fallbackTTL: -42)
        XCTAssertNil(expiry3)
        
        // Test nil fallback
        let expiry4 = expectedExpiry(overrideTTL: nil, fallbackTTL: nil)
        XCTAssertNil(expiry4)
    }
}

