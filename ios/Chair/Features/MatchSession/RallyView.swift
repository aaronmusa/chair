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
    var onShowLog: () -> Void = {}
}

struct RallyView: View {
    let scoreboard: ScoreboardModel
    let getSet: GetSetPresentation
    let announcement: String
    var note: String?
    let names: [Side: String]
    var actions = RallyActions()
    var camera: CameraPanelModel?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if horizontalSizeClass == .regular {
            HStack(spacing: 0) {
                if let camera {
                    CameraPanelView(model: camera)
                } else {
                    cameraPlaceholder
                }
                sidePanel
                    .frame(width: 420)
            }
        } else if let camera {
            VStack(spacing: 0) {
                CameraPanelView(model: camera)
                    .aspectRatio(16 / 9, contentMode: .fit)
                sidePanel
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
                VStack(spacing: Spacing.chair.md) {
                    topStrip
                    ScoreHeadline(score: scoreboard.headline, caption: getSet.serveLabel, announcement: announcement, note: note)
                    Button(action: actions.onShowLog) {
                        ScoreboardView(model: scoreboard)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows the points in this game")
                    CourtView(players: getSet.markers)
                        .frame(maxHeight: 150)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.chair.small))
                        .accessibilityLabel(getSet.accessibilitySentence)
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
        .chairFont(.caption)
        .foregroundStyle(Color.chair.inkSecondary)
    }

    private var bottomBar: some View {
        VStack(spacing: Spacing.chair.sm) {
            ForEach(Side.allCases, id: \.self) { side in
                pointButton(side)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: Spacing.chair.sm) { secondaryButtonRow }
            }
        }
        .padding(Spacing.chair.md)
        .background(Color.chair.surface)
    }

    private func pointButton(_ side: Side) -> some View {
        let name = names[side] ?? side.rawValue
        let isServing = scoreboard.rows.first { $0.side == side }?.isServing ?? false
        return Button(action: handlePoint(side)) {
            HStack(spacing: Spacing.chair.sm) {
                Image(systemName: "tennisball.fill")
                    .foregroundStyle(Color.chair.accent, Color.chair.onButton)
                    .opacity(isServing ? 1 : 0)
                Text("Point \(name)")
                    .chairFont(.action)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
                Text("+1")
                    .chairFont(.headline)
            }
            .padding(.horizontal, Spacing.chair.lg)
            .frame(maxWidth: .infinity, minHeight: 64)
        }
        .buttonStyle(ChairButtonStyle(.secondary))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Point \(name)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("session.point.\(side.rawValue)")
    }

    private var secondaryButtons: some View {
        VStack(spacing: Spacing.chair.xs) { secondaryButtonRow }
    }

    @ViewBuilder
    private var secondaryButtonRow: some View {
        actionButton("Fault", systemImage: nil, label: "Fault", onTap: actions.onFault)
            .accessibilityIdentifier("session.fault")
        actionButton("Let", systemImage: nil, label: "Let", onTap: actions.onLet)
            .accessibilityIdentifier("session.let")
        actionButton("Undo", systemImage: "arrow.uturn.backward", label: "Undo last", onTap: actions.onUndo)
            .accessibilityIdentifier("session.undo")
    }

    private func actionButton(
        _ title: String,
        systemImage: String?,
        label: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.chair.xxs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .chairFont(.action)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(ChairButtonStyle(.secondary))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }

    private func handlePoint(_ side: Side) -> () -> Void {
        { actions.onPoint(side) }
    }
}

struct ScoreHeadline: View {
    let score: String
    let caption: String
    let announcement: String
    var note: String?

    var body: some View {
        VStack(spacing: Spacing.chair.xxs) {
            Text(score)
                .chairFont(.scoreHero)
                .foregroundStyle(Color.chair.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityLabel(announcement)
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityIdentifier("session.announcement")
            Text(caption)
                .chairFont(.caption)
                .foregroundStyle(Color.chair.ink)
                .accessibilityHidden(true)
            if let note {
                Text(note)
                    .chairFont(.caption)
                    .foregroundStyle(Color.chair.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
