//
//  ContentView.swift
//  ChairWatch
//
//  Created by Aaron Musa on 10/26/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct ContentView: View {
    let model: WatchMatchModel

    var body: some View {
        VStack(spacing: Spacing.chair.xs) {
            if model.link.isVersionMismatched {
                Text("Update Chair on your iPhone")
                    .chairFont(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.chair.ink)
                    .accessibilityIdentifier("watch.updatePhone")
            } else {
                Text("Chair")
                    .chairFont(.headline)
                    .foregroundStyle(Color.chair.ink)
                if model.link.isWaitingForPeer {
                    Circle()
                        .fill(Color.chair.inkSecondary)
                        .frame(width: 8, height: 8)
                        .accessibilityLabel("Waiting for phone")
                        .accessibilityIdentifier("watch.waitingForPhone")
                }
            }
        }
        .task(handleStart)
    }

    @Sendable
    private func handleStart() async {
        model.start()
        await model.link.send(.requestState)
    }
}
