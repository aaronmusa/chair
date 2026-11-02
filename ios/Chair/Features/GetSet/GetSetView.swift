//
//  GetSetView.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct GetSetActions {
    var onSwapServer: () -> Void = {}
    var onSwapReceivers: () -> Void = {}
    var onSwapSides: () -> Void = {}
    var onFixScore: () -> Void = {}
    var onPlayPoint: () -> Void = {}
}

struct GetSetView: View {
    let presentation: GetSetPresentation
    var actions = GetSetActions()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.chair.md) {
                strip
                CourtView(players: presentation.markers)
                    .containerRelativeFrame(.vertical, alignment: .center, handleCourtHeight())
                serveSummary
                controls
            }
            .padding(Spacing.chair.md)
            .frame(maxWidth: columnWidth)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            ChairButton("Play point", size: .large, onTap: actions.onPlayPoint)
                .accessibilityIdentifier("getSet.playPoint")
                .frame(maxWidth: columnWidth)
                .padding(Spacing.chair.md)
                .background(Color.chair.surface)
        }
        .background(Color.chair.surface)
    }

    private var columnWidth: CGFloat {
        horizontalSizeClass == .regular ? 560 : .infinity
    }

    private func handleCourtHeight() -> (CGFloat, Axis) -> CGFloat {
        { length, _ in length * 0.45 }
    }

    private var strip: some View {
        Text(presentation.strip)
            .chairFont(.title)
            .foregroundStyle(Color.chair.ink)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(Spacing.chair.sm)
            .background(Color.chair.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.chair.large))
            .accessibilityHidden(true)
    }

    private var serveSummary: some View {
        Text(presentation.serveLabel)
            .chairFont(.headline)
            .foregroundStyle(Color.chair.ink)
            .multilineTextAlignment(.center)
            .accessibilityLabel(presentation.accessibilitySentence)
            .accessibilityIdentifier("getSet.summary")
    }

    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.chair.xs) { controlButtons }
            VStack(spacing: Spacing.chair.xs) { controlButtons }
        }
    }

    @ViewBuilder
    private var controlButtons: some View {
        ChairButton("Swap server", style: .secondary, onTap: actions.onSwapServer)
            .disabled(!presentation.canSwapServer)
            .accessibilityIdentifier("getSet.swapServer")
        if presentation.isDoubles {
            ChairButton("Swap receivers", style: .secondary, onTap: actions.onSwapReceivers)
                .disabled(!presentation.canSwapReceivers)
                .accessibilityIdentifier("getSet.swapReceivers")
        }
        ChairButton("Swap sides", style: .secondary, onTap: actions.onSwapSides)
            .disabled(!presentation.canSwapSides)
            .accessibilityIdentifier("getSet.swapSides")
        ChairButton("Fix score", style: .ghost, onTap: actions.onFixScore)
            .accessibilityIdentifier("getSet.fixScore")
    }
}

#if DEBUG
    #Preview("Singles") {
        GetSetView(presentation: .preview(format: .singles))
    }

    #Preview("Doubles") {
        GetSetView(presentation: .preview(format: .doubles))
    }

    extension GetSetPresentation {
        static func preview(format: MatchFormat) -> GetSetPresentation {
            GetSetPresentation(
                state: .initial(rules: MatchRules(), format: format),
                names: [.a1: "Aaron", .a2: "Bea", .b1: "Juan", .b2: "Lia"]
            )
        }
    }
#endif
