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
                .chairFont(.title)
                .foregroundStyle(Color.chair.ink)
            ChairButton("Resume", size: .large, onTap: actions.onResume)
                .accessibilityIdentifier("pause.resume")
            ChairButton("Swap sides", style: .secondary, onTap: handleSwapSides())
            ChairButton("Fix score", style: .secondary, onTap: actions.onFixScore)
                .accessibilityIdentifier("pause.fixScore")
            ChairButton("End match", style: .ghost, onTap: actions.onEndMatch)
                .accessibilityIdentifier("pause.endMatch")
        }
        .padding(Spacing.chair.md)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.chair.surface)
    }

    private func handleSwapSides() -> () -> Void {
        {
            actions.onSwapSides()
            actions.onResume()
        }
    }
}
