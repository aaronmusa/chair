//
//  WatchEndMatchPage.swift
//  ChairWatch
//
//  Created by Aaron Musa on 11/3/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct WatchEndMatchPage: View {
    let onEnd: (WatchInput.EndChoice) -> Void

    @State var isChoosing = false

    var body: some View {
        VStack(spacing: Spacing.chair.xs) {
            if isChoosing {
                option("Finish as is", .finishAsIs, identifier: "watch.end.finish")
                option("Retire me", .retireMe, identifier: "watch.end.retireMe")
                option("Retire them", .retireThem, identifier: "watch.end.retireThem")
                Button("Cancel", action: handleToggle())
                    .chairFont(.callout)
                    .foregroundStyle(Color.chair.inkSecondary)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("watch.end.cancel")
            } else {
                Button(action: handleToggle()) {
                    Text("End match")
                        .chairFont(.headline)
                        .foregroundStyle(Color.chair.danger)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color.chair.surfaceRaised, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("watch.endMatch")
            }
        }
    }

    private func option(
        _ title: String,
        _ choice: WatchInput.EndChoice,
        identifier: String
    ) -> some View {
        Button(action: handleEnd(choice)) {
            Text(title)
                .chairFont(.headline)
                .foregroundStyle(choice == .finishAsIs ? Color.chair.ink : Color.chair.danger)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.chair.surfaceRaised, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func handleToggle() -> () -> Void {
        { isChoosing.toggle() }
    }

    private func handleEnd(_ choice: WatchInput.EndChoice) -> () -> Void {
        {
            isChoosing = false
            onEnd(choice)
        }
    }
}
