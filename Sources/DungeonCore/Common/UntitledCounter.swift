//
//  UntitledCounter.swift
//  DungeonMapMaker
//
//  Created by Brian Arnold on 11/29/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import Foundation
import Synchronization


final class UntitledCounter {
    private static let untitledCount = Atomic(0)

    static func increment() {
        untitledCount.add(1, ordering: .relaxed)
    }

    static var currentCount: Int {
        untitledCount.load(ordering: .relaxed)
    }
    
    static func generateUntitledName() -> String {
        increment()
        let counter = currentCount > 1 ? " \(currentCount)" : ""
        return "Untitled\(counter)"
    }
}
