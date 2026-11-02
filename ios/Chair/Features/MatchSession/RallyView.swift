//
//  RallyView.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct RallyActions {
    var onPoint: (Side) -> Void = { _ in }
    var onFault: () -> Void = {}
    var onLet: () -> Void = {}
    var onUndo: () -> Void = {}
}

struct RallyView: View {
    let scoreboard: ScoreboardModel
    let getSet: GetSetPresentation
    let announcement: String
    let names: [Side: String]
    var actions = RallyActions()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if horizontalSizeClass == .regular {
            HStack(spacing: 0) {
                cameraPlaceholder
                sidePanel
                    .frame(width: 420)
            }
        } else {
            sidePanel
        }
    }

    private var cameraPlaceholder: some View {
        Text("Camera scoring arrives in a later update")
            .chairFont(.headline)
            .foregroundStyle(Color.chair.inkSecondary)
            .multilineTextAlignment(.center)
            .padding(Spacing.chair.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.chair.surfaceRaised)
    }

    private var sidePanel: some View {
        VStack(spacing: Spacing.chair.sm) {
            ScrollView {
                VStack(spacing: Spacing.chair.sm) {
                    topStrip
                    AnnouncementStrip(text: announcement)
                    ScoreboardView(model: scoreboard)
                    HStack(alignment: .center, spacing: Spacing.chair.sm) {
                        CourtView(players: getSet.markers)
                            .frame(maxHeight: 160)
                        Text(getSet.serveLabel)
                            .chairFont(.callout)
                            .foregroundStyle(Color.chair.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel(getSet.accessibilitySentence)
                    }
                    if dynamicTypeSize.isAccessibilitySize {
                        secondaryButtons
                    }
                }
                .padding(Spacing.chair.md)
            }
            bottomBar
        }
        .background(Color.chair.surface)
    }

    private var topStrip: some View {
        HStack {
            Text(scoreboard.setLabel)
            Spacer()
            Text(scoreboard.setsLead)
        }
        .chairFont(.callout)
        .foregroundStyle(Color.chair.inkSecondary)
    }

    private var bottomBar: some View {
        VStack(spacing: Spacing.chair.xs) {
            ForEach(Side.allCases, id: \.self) { side in
                ChairButton("Point \(names[side] ?? side.rawValue)", size: .large, onTap: handlePoint(side))
                    .accessibilityIdentifier("session.point.\(side.rawValue)")
            }
            if !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: Spacing.chair.xs) { secondaryButtonRow }
            }
        }
        .padding(Spacing.chair.md)
        .background(Color.chair.surface)
    }

    private var secondaryButtons: some View {
        VStack(spacing: Spacing.chair.xs) { secondaryButtonRow }
    }

    @ViewBuilder
    private var secondaryButtonRow: some View {
        ChairButton("Fault", style: .secondary, onTap: actions.onFault)
            .accessibilityIdentifier("session.fault")
        ChairButton("Let", style: .secondary, onTap: actions.onLet)
            .accessibilityIdentifier("session.let")
        ChairButton("Undo last", style: .ghost, onTap: actions.onUndo)
            .accessibilityIdentifier("session.undo")
    }

    private func handlePoint(_ side: Side) -> () -> Void {
        { actions.onPoint(side) }
    }
}

struct AnnouncementStrip: View {
    let text: String

    var body: some View {
        Text(text)
            .chairFont(.headline)
            .foregroundStyle(Color.chair.ink)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, Spacing.chair.sm)
            .background(Color.chair.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.chair.medium))
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier("session.announcement")
    }
}
