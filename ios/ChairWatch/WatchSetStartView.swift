//
//  WatchSetStartView.swift
//  ChairWatch
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct WatchSetStartView: View {
    let card: SetStartCard
    let state: WatchState
    let onPick: (Bool) -> Void

    var body: some View {
        VStack(spacing: Spacing.chair.xs) {
            Text(question)
                .chairFont(.headline)
                .foregroundStyle(Color.chair.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier("watch.setStart.question")
            choice(state.name(of: slots.first), isSecond: false, identifier: "watch.setStart.first")
            choice(state.name(of: slots.second), isSecond: true, identifier: "watch.setStart.second")
        }
    }

    private var question: String {
        switch card {
        case .serve: "Who serves first for your team?"
        case .deuce: "Who receives on the deuce side?"
        }
    }

    private var slots: (first: PlayerSlot, second: PlayerSlot) {
        switch card {
        case let .serve(first, second): (first, second)
        case let .deuce(current, partner): (current, partner)
        }
    }

    private func choice(
        _ name: String,
        isSecond: Bool,
        identifier: String
    ) -> some View {
        Button(action: handlePick(isSecond)) {
            Text(name)
                .chairFont(.headline)
                .foregroundStyle(Color.chair.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.chair.surfaceRaised, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func handlePick(_ isSecond: Bool) -> () -> Void {
        { onPick(isSecond) }
    }
}
