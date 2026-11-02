//
//  PlayHomeView.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct PlayHomeActions {
    var onNewMatch: () -> Void = {}
    var onServeTraining: () -> Void = {}
    var onQuickScore: () -> Void = {}
    var onOpenMatch: (UUID) -> Void = { _ in }
}

struct PlayHomeView: View {
    let model: PlayHomeModel
    var actions = PlayHomeActions()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.chair.md) {
                if let resume = model.resume {
                    resumeBanner(resume)
                }
                newMatchCard
                shortcuts
                if let lastMatch = model.lastMatch {
                    lastMatchCard(lastMatch)
                }
                thisWeek
            }
            .padding(Spacing.chair.md)
            .frame(maxWidth: horizontalSizeClass == .regular ? 720 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .background(Color.chair.surface)
        .navigationTitle(AppSection.play.title)
    }

    private func resumeBanner(_ resume: PlayHomeModel.Resume) -> some View {
        Button(action: handleOpen(resume.matchID)) {
            HStack(spacing: Spacing.chair.sm) {
                Image(systemName: "play.fill")
                    .accessibilityHidden(true)
                Text(resume.title)
                    .chairFont(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .accessibilityHidden(true)
            }
            .foregroundStyle(Color.chair.surface)
            .padding(Spacing.chair.md)
            .background(Color.chair.accent, in: RoundedRectangle(cornerRadius: Radius.chair.large))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("play.resume")
    }

    private var newMatchCard: some View {
        ChairCard(isRaised: true) {
            VStack(alignment: .leading, spacing: Spacing.chair.sm) {
                Text("New match")
                    .chairFont(.title)
                    .foregroundStyle(Color.chair.ink)
                Text("Pick the players and rules, and Chair keeps score.")
                    .chairFont(.body)
                    .foregroundStyle(Color.chair.inkSecondary)
                ChairButton("New match", size: .large, onTap: actions.onNewMatch)
                    .accessibilityIdentifier("play.newMatch")
            }
        }
    }

    private var shortcuts: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.chair.sm) { shortcutCards }
            VStack(spacing: Spacing.chair.sm) { shortcutCards }
        }
    }

    @ViewBuilder
    private var shortcutCards: some View {
        shortcut("Serve training", systemImage: "figure.tennis", identifier: "play.serveTraining", onTap: actions.onServeTraining)
        shortcut("Quick score", systemImage: "hand.tap", identifier: "play.quickScore", onTap: actions.onQuickScore)
    }

    private func shortcut(
        _ title: String,
        systemImage: String,
        identifier: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            ChairCard {
                Label(title, systemImage: systemImage)
                    .chairFont(.headline)
                    .foregroundStyle(Color.chair.ink)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func lastMatchCard(_ lastMatch: PlayHomeModel.LastMatch) -> some View {
        Button(action: handleOpen(lastMatch.matchID)) {
            ChairCard {
                VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                    Text("Last match")
                        .chairFont(.callout)
                        .foregroundStyle(Color.chair.inkSecondary)
                    Text(lastMatch.title)
                        .chairFont(.headline)
                        .foregroundStyle(Color.chair.ink)
                    Text(lastMatch.detail)
                        .chairFont(.body)
                        .foregroundStyle(Color.chair.ink)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("play.lastMatch")
    }

    private var thisWeek: some View {
        VStack(alignment: .leading, spacing: Spacing.chair.xs) {
            Text("This week")
                .chairFont(.headline)
                .foregroundStyle(Color.chair.ink)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.chair.sm) { tiles }
                VStack(spacing: Spacing.chair.sm) { tiles }
            }
        }
    }

    @ViewBuilder
    private var tiles: some View {
        tile("Matches", value: model.matchesPlayed, identifier: "play.tile.matches")
        tile("1st serve", value: model.firstServe, identifier: "play.tile.firstServe")
        tile("W–L", value: model.winLoss, identifier: "play.tile.winLoss")
    }

    private func tile(
        _ title: String,
        value: String,
        identifier: String
    ) -> some View {
        ChairCard(isRaised: true) {
            VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                Text(value)
                    .chairFont(.score)
                    .monospacedDigit()
                    .foregroundStyle(Color.chair.ink)
                Text(title)
                    .chairFont(.callout)
                    .foregroundStyle(Color.chair.inkSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value == "—" ? "No matches yet" : value)
        .accessibilityIdentifier(identifier)
    }

    private func handleOpen(_ matchID: UUID) -> () -> Void {
        { actions.onOpenMatch(matchID) }
    }
}
