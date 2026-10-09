//
//  ZoomControlBar.swift
//  DungeonMapBuilder
//
//  Created by Brian Arnold on 12/6/25.
//

import SwiftUI

struct ZoomControlBar: View {
    @Bindable var viewModel: DungeonMapViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { viewModel.zoomOut() }
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .frame(width: 28, height: 28)
            }
            .disabled(!viewModel.canZoomOut)

            if horizontalSizeClass == .regular {
                Slider(
                    value: $viewModel.scale,
                    in: MapViewConfiguration.minScale...MapViewConfiguration.maxScale,
                    step: 1
                )
                .frame(width: 140)
            }

            let scalePercent = Int((viewModel.scale / MapViewConfiguration.defaultScale) * 100.0)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { viewModel.resetScale() }
            } label: {
                Text("\(scalePercent)%")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(scalePercent != 100 ? .primary : .secondary)
                    .frame(width: 44, alignment: .center)
            }
            .disabled(scalePercent == 100)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { viewModel.zoomIn() }
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .frame(width: 28, height: 28)
            }
            .disabled(!viewModel.canZoomIn)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
    }
}
