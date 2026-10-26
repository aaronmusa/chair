//
//  ChairCard.swift
//  ChairUI
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI

public struct ChairCard<Content: View>: View {
    let isRaised: Bool
    let content: Content

    public init(
        isRaised: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.isRaised = isRaised
        self.content = content()
    }

    public var body: some View {
        content
            .padding(Spacing.chair.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isRaised ? Color.chair.surfaceRaised : Color.chair.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.chair.large))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.chair.large)
                    .stroke(Color.chair.outline, lineWidth: Stroke.chair.regular)
            )
            .accessibilityElement(children: .contain)
    }
}

#if DEBUG
    #Preview("Light") {
        ChairCardPreview()
    }

    #Preview("Dark") {
        ChairCardPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("AX5") {
        ChairCardPreview()
            .environment(\.dynamicTypeSize, .accessibility5)
    }

    struct ChairCardPreview: View {
        var body: some View {
            VStack(spacing: Spacing.chair.sm) {
                ChairCard {
                    VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                        Text("Last match").chairFont(.caption).foregroundStyle(Color.chair.inkSecondary)
                        Text("Musa def. Reyes 6–4 7–5").chairFont(.headline).foregroundStyle(Color.chair.ink)
                    }
                }
                ChairCard(isRaised: true) {
                    Text("Raised card").chairFont(.body).foregroundStyle(Color.chair.ink)
                }
            }
            .padding(Spacing.chair.md)
            .background(Color.chair.surface)
        }
    }
#endif
