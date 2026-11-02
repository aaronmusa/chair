//
//  MatchEndViews.swift
//  Chair
//
//  Created by Aaron Musa on 11/2/26.
//

import SwiftUI

import ChairKit
import ChairUI

struct MatchOverView: View {
    let text: String

    var body: some View {
        VStack(spacing: Spacing.chair.md) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.chair.accent)
                .accessibilityHidden(true)
            Text(text)
                .chairFont(.display)
                .foregroundStyle(Color.chair.ink)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("session.matchOver")
        }
        .padding(Spacing.chair.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.chair.surface)
    }
}

// TODO: Replace with MatchSummaryView in E2-10.
struct MatchCompleteView: View {
    let title: String
    let sets: [SetScore]

    var body: some View {
        VStack(spacing: Spacing.chair.sm) {
            Text(title)
                .chairFont(.title)
                .foregroundStyle(Color.chair.ink)
                .accessibilityIdentifier("summary.title")
            Text(sets.map { "\($0.a)–\($0.b)" }.joined(separator: "  "))
                .chairFont(.score)
                .monospacedDigit()
                .foregroundStyle(Color.chair.ink)
                .accessibilityIdentifier("summary.sets")
        }
        .padding(Spacing.chair.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.chair.surface)
    }
}
