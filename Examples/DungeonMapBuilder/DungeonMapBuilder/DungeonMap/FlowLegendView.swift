//
//  FlowLegendView.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/2/25.
//  Copyright © 2025 Brian Arnold. Licensed under the MIT License.
//

import SwiftUI

struct FlowLegendView: View {
    var body: some View {
        HStack(spacing: 12) {
            legendItem(.green, "Reachable")
            legendItem(.orange, "Key-gated")
            legendItem(.red, "Unreachable")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .allowsHitTesting(false)
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.7)).frame(width: 14, height: 14)
            Text(label).font(.caption)
        }
    }
}
