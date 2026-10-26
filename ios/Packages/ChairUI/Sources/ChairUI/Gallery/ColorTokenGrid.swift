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
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            ForEach(ChairColorToken.allCases, id: \.self) { token in
                ColorTokenSwatch(token: token)
            }
        }
        .padding(16)
        .background(Color.chair.surface)
    }
}

private struct ColorTokenSwatch: View {
    let token: ChairColorToken

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                swatch(.light)
                swatch(.dark)
            }
            .frame(height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.chair.outline, lineWidth: 1.5))

            Text(token.rawValue)
                .font(.caption.weight(.semibold))
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
