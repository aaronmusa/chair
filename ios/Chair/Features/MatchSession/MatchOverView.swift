//
//  MatchOverView.swift
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
        VStack(spacing: Spacing.chair.sm) {
            Text("Match over")
                .chairFont(.caption)
                .foregroundStyle(Color.chair.tint)
                .accessibilityHidden(true)
            Text(text)
                .chairFont(.display)
                .foregroundStyle(Color.chair.ink)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("session.matchOver")
        }
        .padding(Spacing.chair.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Color.chair.surface
                CourtView()
                    .opacity(0.12)
                    .padding(Spacing.chair.xl)
                    .accessibilityHidden(true)
            }
        }
    }
}
