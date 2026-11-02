//
//  WatchControlsPage.swift
//  ChairWatch
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct WatchControlsPage: View {
    let onSend: (WatchInput.Action) -> Void

    var body: some View {
        Grid(horizontalSpacing: Spacing.chair.xs, verticalSpacing: Spacing.chair.xs) {
            GridRow {
                control("Fault", .fault, identifier: "watch.fault")
                control("Let", .let, identifier: "watch.let")
            }
            GridRow {
                control("Swap ends", .swapEnds, identifier: "watch.swapEnds")
                control("Undo", .undo, identifier: "watch.undo")
            }
        }
    }

    private func control(
        _ title: String,
        _ action: WatchInput.Action,
        identifier: String
    ) -> some View {
        Button(action: handleSend(action)) {
            Text(title)
                .chairFont(.headline)
                .foregroundStyle(Color.chair.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, Spacing.chair.xxs)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 60)
                .background(Color.chair.surfaceRaised, in: .rect(cornerRadius: Radius.chair.card))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func handleSend(_ action: WatchInput.Action) -> () -> Void {
        { onSend(action) }
    }
}
