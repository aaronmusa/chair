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
            // TODO: Wire Fix score in E2-8 and End match in E2-9.
            ChairButton("Fix score", style: .secondary, onTap: {})
                .disabled(true)
            ChairButton("End match", style: .ghost, onTap: {})
                .disabled(true)
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
