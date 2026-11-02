//
//  MatchSessionPlaceholder.swift
//  Chair
//
//  Created by Aaron Musa on 10/31/26.
//

import SwiftUI

import ChairUI

// TODO: Replace with MatchSessionView in E2-6.
struct MatchSessionPlaceholder: View {
    let match: PresentedMatch

    var body: some View {
        Text("Live match")
            .font(.title2.bold())
            .foregroundStyle(Color.chair.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.chair.surface)
            .accessibilityIdentifier("match.session")
    }
}
