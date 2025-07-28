//
//  PandoraDiskBoxPath.swift
//  Pandora
//
//  Created by Josh Gallant on 28/07/2025.
//

import Foundation


public enum PandoraDiskBoxPath {
    /// Root folder for all disk-backed cache namespaces.
    public static var sharedRoot: URL {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PandoraDiskBox", isDirectory: true)
    }
}
