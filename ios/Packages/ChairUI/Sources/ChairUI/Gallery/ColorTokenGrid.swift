//
//  ColorTokenGrid.swift
//  ChairUI
//
//  Created by Aaron Musa on 10/26/26.
//

import SwiftUI

public struct ColorTokenGrid: View {
    public init() {}

    public var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.chair.sm)], spacing: Spacing.chair.sm) {
            ForEach(ChairColorToken.allCases, id: \.self) { token in
                ColorTokenSwatch(token: token)
            }
        }
        .padding(Spacing.chair.md)
        .background(Color.chair.surface)
    }
}

private struct ColorTokenSwatch: View {
    let token: ChairColorToken

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.chair.xs) {
            HStack(spacing: 0) {
                swatch(.light)
                swatch(.dark)
            }
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: Radius.chair.medium))
            .overlay(RoundedRectangle(cornerRadius: Radius.chair.medium).stroke(Color.chair.outline, lineWidth: Stroke.chair.regular))

            Text(token.rawValue)
                .chairFont(.callout)
                .foregroundStyle(Color.chair.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(token.rawValue), light and dark")
    }

    private func swatch(_ scheme: ColorScheme) -> some View {
        token.color
            .environment(\.colorScheme, scheme)
    }
}

#Preview("Light") {
    ScrollView { ColorTokenGrid() }
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ScrollView { ColorTokenGrid() }
        .preferredColorScheme(.dark)
}
