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
        VStack(spacing: Spacing.chair.md) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 56))
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
        .background(Color.chair.surface)
    }
}
