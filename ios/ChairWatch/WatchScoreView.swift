//
//  WatchScoreView.swift
//  ChairWatch
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct WatchScoreView: View {
    let state: WatchState?
    let isWaitingForPhone: Bool

    var body: some View {
        VStack(spacing: Spacing.chair.xs) {
            if let state {
                Text(state.title)
                    .chairFont(.headline)
                    .foregroundStyle(Color.chair.ink)
                    .lineLimit(1)
                Text(state.setsLine)
                    .chairFont(.body)
                    .foregroundStyle(Color.chair.inkSecondary)
                Text(state.pointsLine)
                    .font(Font.chair.score)
                    .foregroundStyle(Color.chair.ink)
                    .accessibilityIdentifier("watch.score.points")
            } else {
                ProgressView()
            }
            if isWaitingForPhone {
                Circle()
                    .fill(Color.chair.inkSecondary)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("Waiting for phone")
                    .accessibilityIdentifier("watch.waitingForPhone")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}
