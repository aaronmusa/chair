//
//  WatchScorePage.swift
//  ChairWatch
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct WatchScoreActions {
    let onScore: (Bool) -> Void
    let onUndo: () -> Void
}

struct WatchScorePage: View {
    let state: WatchState
    let announcement: String?
    let showsCorrection: Bool
    let isWaitingForPhone: Bool
    let requiresHold: Bool
    var heartRate: Int?
    var notice: String?
    let actions: WatchScoreActions

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        if isLuminanceReduced {
            dimmed
        } else {
            live
        }
    }

    private var dimmed: some View {
        VStack(spacing: Spacing.chair.xxs) {
            row(state.mySide)
            row(state.theirSide)
        }
        .frame(maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityIdentifier("watch.score.dimmed")
    }

    private var live: some View {
        VStack(spacing: Spacing.chair.xxs) {
            HStack {
                Text(state.setGameLabel)
                    .chairFont(.caption)
                    .foregroundStyle(Color.chair.inkSecondary)
                Spacer(minLength: 0)
                if let heartRate {
                    Text("♥ \(heartRate)")
                        .chairFont(.callout)
                        .monospacedDigit()
                        .foregroundStyle(Color.chair.inkSecondary)
                        .accessibilityLabel("Heart rate \(heartRate)")
                }
                if isWaitingForPhone {
                    Circle()
                        .fill(Color.chair.warning)
                        .frame(width: 6, height: 6)
                        .accessibilityLabel("Waiting for phone")
                        .accessibilityIdentifier("watch.waitingForPhone")
                }
            }
            VStack(spacing: 0) {
                row(state.mySide)
                row(state.theirSide)
            }
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 20).onEnded(handleSwipe()))
            .accessibilityAction(named: "Undo", actions.onUndo)
            Text(strip)
                .chairFont(.callout)
                .foregroundStyle(showsCorrection ? Color.chair.warning : Color.chair.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier("watch.strip")
            if let notice {
                Text(notice)
                    .chairFont(.callout)
                    .foregroundStyle(Color.chair.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityIdentifier("watch.keepAliveNotice")
            }
            Spacer(minLength: 0)
            HStack(spacing: Spacing.chair.xs) {
                HoldToScoreButton(title: "Me", requiresHold: requiresHold, identifier: "watch.me", onScore: handleScore(me: true))
                HoldToScoreButton(title: "Them", requiresHold: requiresHold, identifier: "watch.them", onScore: handleScore(me: false))
            }
        }
        .overlay(alignment: .bottom) {
            if let announcement {
                Text(announcement)
                    .chairFont(.headline)
                    .foregroundStyle(Color.black)
                    .multilineTextAlignment(.center)
                    .padding(Spacing.chair.sm)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.chair.accent, in: .rect(cornerRadius: Radius.chair.card))
                    .accessibilityIdentifier("watch.announcement")
            }
        }
    }

    private var strip: String {
        showsCorrection ? "Correction" : state.serveStrip
    }

    private func row(_ side: Side) -> some View {
        HStack(spacing: Spacing.chair.xxs) {
            Circle()
                .fill(state.server.side == side ? Color.chair.accent : Color.clear)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(state.rowName(for: side))
                .chairFont(.body)
                .foregroundStyle(Color.chair.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: Spacing.chair.xxs)
            Text(state.games(for: side).map(String.init).joined(separator: " "))
                .chairFont(.body)
                .monospacedDigit()
                .foregroundStyle(Color.chair.inkSecondary)
                .lineLimit(1)
            Text(state.points(for: side))
                .font(Font.chair.score)
                .foregroundStyle(Color.chair.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(minWidth: 44, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(side == state.mySide ? "watch.row.me" : "watch.row.them")
    }

    private func handleScore(me: Bool) -> () -> Void {
        { actions.onScore(me) }
    }

    private func handleSwipe() -> (DragGesture.Value) -> Void {
        { value in
            guard value.translation.width < -30, abs(value.translation.height) < abs(value.translation.width) else { return }
            actions.onUndo()
        }
    }
}
