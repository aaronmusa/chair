//
//  PlayPlaceholderView.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI

import ChairUI

// TODO: Replace with PlayHomeView in E2-3.
struct PlayPlaceholderView: View {
    let onNewMatch: () -> Void

    var body: some View {
        VStack(spacing: Spacing.chair.lg) {
            ContentUnavailableView {
                Label(AppSection.play.title, systemImage: AppSection.play.systemImage)
            } description: {
                Text("Start a match and Chair keeps score.")
            }
            ChairButton("New match", size: .large, onTap: onNewMatch)
                .accessibilityIdentifier("play.newMatch")
                .padding(.horizontal, Spacing.chair.md)
        }
        .foregroundStyle(Color.chair.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.chair.surface)
        .navigationTitle(AppSection.play.title)
    }
}
