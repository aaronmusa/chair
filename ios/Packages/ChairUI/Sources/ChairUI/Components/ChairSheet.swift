//
//  ChairSheet.swift
//  ChairUI
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI

public struct ChairSheet<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: Spacing.chair.md) {
            Capsule()
                .fill(Color.chair.outline)
                .frame(width: 36, height: 5)
                .padding(.top, Spacing.chair.xs)
                .accessibilityHidden(true)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.chair.md)
        .padding(.bottom, Spacing.chair.xl)
        .background(Color.chair.surface)
        .clipShape(shape)
        .overlay(shape.stroke(Color.chair.outline, lineWidth: Stroke.chair.regular))
        .accessibilityElement(children: .contain)
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: Radius.chair.sheet, topTrailingRadius: Radius.chair.sheet)
    }
}

#if DEBUG
    #Preview("Light") {
        ChairSheetPreview()
    }

    #Preview("Dark") {
        ChairSheetPreview()
            .preferredColorScheme(.dark)
    }

    #Preview("AX5") {
        ChairSheetPreview()
            .environment(\.dynamicTypeSize, .accessibility5)
    }

    struct ChairSheetPreview: View {
        var body: some View {
            ChairSheet {
                VStack(alignment: .leading, spacing: Spacing.chair.xs) {
                    Text("Point to Musa?").chairFont(.title).foregroundStyle(Color.chair.ink)
                    Text("Ball landed in, deep on the deuce side.").chairFont(.body).foregroundStyle(Color.chair.inkSecondary)
                }
            }
            .padding(.top, Spacing.chair.xxl)
            .background(Color.chair.surfaceRaised)
        }
    }
#endif
