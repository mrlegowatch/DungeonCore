//
//  ColorExtensions.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/6/25.
//

import SwiftUI

extension Color {
    static let veryLightGray = Color(cgColor: .veryLightGray)
    static let lightGray = Color(cgColor: .lightGray)
    static let mediumGray = Color(cgColor: .gray)
    static let darkGray = Color(cgColor: .darkGray)
    static let darkBlue = Color(cgColor: .darkBlue)

    /// Thin outline around a pool's footprint.
    static let poolOutline = Color(red: 0.15, green: 0.45, blue: 0.45)
    /// Lighter of the two alternating stripes that fill a pool's footprint.
    static let poolStripeLight = Color(red: 0.75, green: 0.9, blue: 0.9)
    /// Medium of the two alternating stripes that fill a pool's footprint.
    static let poolStripeMedium = Color(red: 0.45, green: 0.72, blue: 0.72)
}

extension CGColor {
    static let darkGray = CGColor(gray: 0.25, alpha: 1.0)
    static let gray = CGColor(gray: 0.5, alpha: 1.0)
    static let lightGray = CGColor(gray: 0.75, alpha: 1.0)
    static let veryLightGray = CGColor(gray: 0.9, alpha: 1.0)
    static let white = CGColor(gray: 1.0, alpha: 1.0)
    static let darkBlue = CGColor(red: 0.1, green: 0.2, blue: 0.55, alpha: 1.0)
}
