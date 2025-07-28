//
//  CalculateExpiry.swift
//  Pandoras
//
//  Created by Josh Gallant on 27/07/2025.
//

import Foundation

internal func calculateExpiryDate(overrideTTL: TimeInterval?, fallbackTTL: TimeInterval?) -> Date? {
    if let override = overrideTTL {
        if override > 0 {
            return Date().addingTimeInterval(override)
        } else {
            return nil
        }
    }
    if let fallback = fallbackTTL, fallback > 0 {
        return Date().addingTimeInterval(fallback)
    }
    return nil
}
