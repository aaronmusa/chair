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
    var scoreboard: ScoreboardModel?
    var note: String?
    var actions = GetSetActions()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.chair.md) {
                if let scoreboard {
                    ScoreboardView(model: scoreboard, isCompact: true)
                }
                CourtView(players: presentation.markers)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.chair.small))
                    .containerRelativeFrame(.vertical, alignment: .center, handleCourtHeight())
                if let scoreboard {
                    Text(scoreboard.headline)
                        .chairFont(.scoreLarge)
                        .foregroundStyle(Color.chair.ink)
                        .accessibilityHidden(true)
                }
                serveSummary
                if let note {
                    Text(note)
                        .chairFont(.caption)
                        .foregroundStyle(Color.chair.inkSecondary)
                }
                controls
            }
            .padding(Spacing.chair.md)
            .frame(maxWidth: columnWidth)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: actions.onPlayPoint) {
                Text("Play point")
                    .chairFont(.action)
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
            .buttonStyle(ChairButtonStyle(.primary))
            .accessibilityLabel("Play point")
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

    private var serveSummary: some View {
        Text(presentation.serveLabel)
            .chairFont(.caption)
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
        controlButton("Swap server", isEnabled: presentation.canSwapServer, onTap: actions.onSwapServer)
            .accessibilityIdentifier("getSet.swapServer")
        if presentation.isDoubles {
            controlButton("Swap receivers", isEnabled: presentation.canSwapReceivers, onTap: actions.onSwapReceivers)
                .accessibilityIdentifier("getSet.swapReceivers")
        }
        controlButton("Swap sides", isEnabled: presentation.canSwapSides, onTap: actions.onSwapSides)
            .accessibilityIdentifier("getSet.swapSides")
        controlButton("Fix score", isEnabled: true, onTap: actions.onFixScore)
            .accessibilityIdentifier("getSet.fixScore")
    }

    private func controlButton(
        _ title: String,
        isEnabled: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            Text(title)
                .chairFont(.action)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, Spacing.chair.xs)
        }
        .buttonStyle(ChairButtonStyle(.secondary))
        .disabled(!isEnabled)
        .accessibilityLabel(title)
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
