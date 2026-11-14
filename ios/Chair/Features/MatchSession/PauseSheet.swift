//
//  PauseSheet.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI

import ChairUI

struct PauseActions {
    var onResume: () -> Void = {}
    var onSwapSides: () -> Void = {}
    var onFixScore: () -> Void = {}
    var onEndMatch: () -> Void = {}
}

struct PauseSheet: View {
    let actions: PauseActions

    var body: some View {
        VStack(spacing: Spacing.chair.sm) {
            Text("Paused")
                .chairFont(.display)
                .foregroundStyle(Color.chair.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            sheetButton("Resume", systemImage: "play.fill", style: .primary, height: 64, onTap: actions.onResume)
                .accessibilityIdentifier("pause.resume")
            HStack(spacing: Spacing.chair.sm) {
                sheetButton("Swap sides", systemImage: "arrow.left.arrow.right", style: .secondary, height: 52, onTap: handleSwapSides())
                sheetButton("Fix score", systemImage: "pencil", style: .secondary, height: 52, onTap: actions.onFixScore)
                    .accessibilityIdentifier("pause.fixScore")
            }
            sheetButton("End match", systemImage: "flag.fill", style: .destructive, height: 52, onTap: actions.onEndMatch)
                .accessibilityIdentifier("pause.endMatch")
        }
        .padding(Spacing.chair.md)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.chair.surface)
    }

    private func sheetButton(
        _ title: String,
        systemImage: String,
        style: ChairButton.Style,
        height: CGFloat,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            Label(title, systemImage: systemImage)
                .chairFont(.action)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: height)
        }
        .buttonStyle(ChairButtonStyle(style))
        .accessibilityLabel(title)
    }

    private func handleSwapSides() -> () -> Void {
        {
            actions.onSwapSides()
            actions.onResume()
        }
    }
}
