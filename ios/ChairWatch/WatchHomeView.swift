//
//  WatchHomeView.swift
//  ChairWatch
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct WatchHomeActions {
    let onJoin: () -> Void
    let onNewMatch: () -> Void
    let onRetry: () -> Void
}

struct WatchHomeView: View {
    let content: WatchHomeContent
    let hasAskedForNewMatch: Bool
    let actions: WatchHomeActions

    var body: some View {
        VStack(spacing: Spacing.chair.sm) {
            switch content {
            case let .join(state):
                joinCard(state)
            case let .startOnPhone(lastResult):
                startOnPhone(lastResult)
            case .unreachable:
                message("Open Chair on your iPhone", identifier: "watch.unreachable")
                button("Retry", identifier: "watch.retry", action: actions.onRetry)
            case .updatePhone:
                message("Update Chair on your iPhone", identifier: "watch.updatePhone")
            }
        }
        .padding(.horizontal, Spacing.chair.xxs)
    }

    private func joinCard(_ state: WatchState) -> some View {
        Button(action: actions.onJoin) {
            VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                Text("Join match")
                    .chairFont(.caption)
                    .foregroundStyle(Color.chair.accent)
                Text(state.title)
                    .chairFont(.headline)
                    .foregroundStyle(Color.chair.ink)
                    .lineLimit(2)
                HStack(alignment: .firstTextBaseline) {
                    Text(state.setsLine)
                        .chairFont(.body)
                        .foregroundStyle(Color.chair.inkSecondary)
                    Spacer(minLength: Spacing.chair.xs)
                    Text(state.pointsLine)
                        .font(Font.chair.score)
                        .foregroundStyle(Color.chair.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.chair.sm)
            .background(Color.chair.surfaceRaised, in: .rect(cornerRadius: Radius.chair.card))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("watch.join")
    }

    @ViewBuilder
    private func startOnPhone(_ lastResult: String?) -> some View {
        message("Start a match on your iPhone", identifier: "watch.startOnPhone")
        if let lastResult {
            Text(lastResult)
                .chairFont(.callout)
                .foregroundStyle(Color.chair.inkSecondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("watch.lastResult")
        }
        if hasAskedForNewMatch {
            Text("Open Chair on your iPhone to set it up")
                .chairFont(.callout)
                .foregroundStyle(Color.chair.inkSecondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("watch.newMatchSent")
        } else {
            button("New match", identifier: "watch.newMatch", action: actions.onNewMatch)
        }
    }

    private func message(
        _ text: String,
        identifier: String
    ) -> some View {
        Text(text)
            .chairFont(.headline)
            .foregroundStyle(Color.chair.ink)
            .multilineTextAlignment(.center)
            .accessibilityIdentifier(identifier)
    }

    private func button(
        _ title: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .chairFont(.headline)
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.chair.accent, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
