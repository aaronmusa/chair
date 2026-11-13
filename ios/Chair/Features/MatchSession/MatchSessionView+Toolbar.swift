//
//  MatchSessionView+Toolbar.swift
//  Chair
//
//  Created by Aaron Musa on 11/14/26.
//

import SwiftUI

import ChairUI

extension MatchSessionView {
    @ToolbarContentBuilder
    var matchToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.phase == .complete {
                Button("Done", action: handleDone())
                    .accessibilityIdentifier("session.done")
            } else if viewModel.phase != .finishing {
                PauseButton(onTap: handlePause())
            }
        }
        .hidingSharedBackground(viewModel.phase != .complete)
        if let umpire, viewModel.isLive {
            ToolbarItem(placement: .topBarLeading) {
                UmpirePill(isMuted: umpire.isMuted, routeName: umpire.routeName, onToggle: handleToggleUmpire())
                    .fixedSize()
            }
            .hidingSharedBackground()
        }
    }
}

struct PauseButton: View {
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .headline) private var size: CGFloat = 36

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "pause.fill")
                .font(Font.chair.headline)
                .foregroundStyle(Color.chair.onButton)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.chair.button))
        }
        .accessibilityLabel("Pause")
        .accessibilityIdentifier("session.pause")
    }
}

extension ToolbarContent {
    @ToolbarContentBuilder
    func hidingSharedBackground(_ isHidden: Bool = true) -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            sharedBackgroundVisibility(isHidden ? .hidden : .automatic)
        } else {
            self
        }
    }
}
