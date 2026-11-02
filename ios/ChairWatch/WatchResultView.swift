//
//  WatchResultView.swift
//  ChairWatch
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct WatchResultView: View {
    let state: WatchState
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: Spacing.chair.sm) {
            Text(state.resultText)
                .chairFont(.title)
                .foregroundStyle(Color.chair.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .accessibilityIdentifier("watch.result")
            Text(state.title)
                .chairFont(.callout)
                .foregroundStyle(Color.chair.inkSecondary)
                .lineLimit(1)
            Button(action: onDone) {
                Text("Done")
                    .chairFont(.headline)
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.chair.accent, in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("watch.done")
        }
    }
}
