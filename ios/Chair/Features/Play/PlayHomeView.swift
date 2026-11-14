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
        VStack(alignment: .leading, spacing: Spacing.chair.sm) {
            if let scoreboard = resume.scoreboard {
                HStack(spacing: Spacing.chair.xs) {
                    Circle()
                        .fill(Color.chair.tint)
                        .frame(width: 8, height: 8)
                    Text("Live · \(scoreboard.setLabel.components(separatedBy: " · ").first ?? "")")
                }
                .chairFont(.caption)
                .foregroundStyle(Color.chair.ink)
                .accessibilityHidden(true)
                ScoreboardView(model: scoreboard)
            }
            Button(action: handleOpen(resume.matchID)) {
                Label("Resume match", systemImage: "play.fill")
                    .chairFont(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(ChairButtonStyle(.primary))
            .accessibilityLabel(resume.title)
            .accessibilityIdentifier("play.resume")
        }
    }

    private var newMatchCard: some View {
        Button(action: actions.onNewMatch) {
            HStack(spacing: Spacing.chair.sm) {
                Image(systemName: "plus")
                    .font(Font.chair.title)
                VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                    Text("New match")
                        .chairFont(.title)
                    Text("Pick players and rules, and Chair keeps score")
                        .chairFont(.callout)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.chair.md)
        }
        .buttonStyle(ChairButtonStyle(model.resume == nil ? .primary : .secondary))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("New match")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("play.newMatch")
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
            HStack(spacing: Spacing.chair.xs) {
                Label(title, systemImage: systemImage)
                    .chairFont(.headline)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(Font.chair.callout.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .padding(Spacing.chair.md)
            .frame(minHeight: 56)
        }
        .buttonStyle(ChairButtonStyle(.ghost))
        .accessibilityIdentifier(identifier)
    }

    private func lastMatchCard(_ lastMatch: PlayHomeModel.LastMatch) -> some View {
        VStack(alignment: .leading, spacing: Spacing.chair.xs) {
            sectionLabel("Last match")
            Button(action: handleOpen(lastMatch.matchID)) {
                HStack(spacing: Spacing.chair.sm) {
                    VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                        Text(lastMatch.title)
                            .chairFont(.headline)
                        Text(lastMatch.date)
                            .chairFont(.caption)
                            .foregroundStyle(Color.chair.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let result = lastMatch.result {
                        ResultBadge(result: result)
                    }
                    SetLineText(setLine: lastMatch.setLine)
                    Image(systemName: "chevron.right")
                        .font(Font.chair.callout.weight(.semibold))
                        .accessibilityHidden(true)
                }
                .padding(Spacing.chair.md)
            }
            .buttonStyle(ChairButtonStyle(.ghost))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Last match, \(lastMatch.title), \(lastMatch.detail)")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("play.lastMatch")
        }
    }

    private var thisWeek: some View {
        VStack(alignment: .leading, spacing: Spacing.chair.xs) {
            sectionLabel("This week")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.chair.sm) { tiles }
                VStack(spacing: Spacing.chair.sm) { tiles }
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .chairFont(.caption)
            .foregroundStyle(Color.chair.inkSecondary)
            .accessibilityAddTraits(.isHeader)
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
        ChairCard {
            VStack(spacing: Spacing.chair.xxs) {
                Text(value)
                    .chairFont(.scoreLarge)
                    .foregroundStyle(Color.chair.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(title)
                    .chairFont(.caption)
                    .foregroundStyle(Color.chair.inkSecondary)
            }
            .frame(maxWidth: .infinity)
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

struct ResultBadge: View {
    let result: String

    var body: some View {
        Text(result)
            .chairFont(.headline)
            .foregroundStyle(result == "L" ? Color.chair.surface : Color.chair.onButton)
            .frame(minWidth: 32, minHeight: 28)
            .background(result == "L" ? Color.chair.danger : Color.chair.button, in: RoundedRectangle(cornerRadius: Radius.chair.small))
            .accessibilityHidden(true)
    }
}

struct SetLineText: View {
    let setLine: String

    var body: some View {
        HStack(spacing: Spacing.chair.sm) {
            ForEach(Array(setLine.split(separator: " ").enumerated()), id: \.offset) { _, set in
                Text(set)
                    .chairFont(.title)
                    .fontWidth(.compressed)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(setLine)
    }
}
