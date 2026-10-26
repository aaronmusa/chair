//
//  ChairPill.swift
//  ChairUI
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI

public struct ChairPill: View {
    static let height: CGFloat = 34

    let title: String
    let isSelected: Bool
    let onTap: (() -> Void)?

    public init(
        _ title: String,
        isSelected: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.isSelected = isSelected
        self.onTap = onTap
    }

    public var body: some View {
        if let onTap {
            Button(action: onTap) { label }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityLabel(title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            label
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(title)
                .accessibilityAddTraits(isSelected ? [.isSelected, .isStaticText] : .isStaticText)
        }
    }

    private var label: some View {
        Text(title)
            .chairFont(.callout)
            .fontWeight(.semibold)
            .foregroundStyle(isSelected ? Color.chair.surface : Color.chair.ink)
            .padding(.horizontal, Spacing.chair.md)
            .frame(minHeight: Self.height)
            .background(
                Capsule()
                    .fill(isSelected ? Color.chair.accent : Color.clear)
                    .strokeBorder(isSelected ? Color.chair.accent : Color.chair.outline, lineWidth: Stroke.chair.regular)
            )
            .contentShape(Capsule())
    }
}

#Preview("Light") {
    ChairPillPreview()
}

#Preview("Dark") {
    ChairPillPreview()
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    ChairPillPreview()
        .environment(\.dynamicTypeSize, .accessibility5)
}

struct ChairPillPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.chair.sm) {
            HStack(spacing: Spacing.chair.xs) {
                ChairPill("All", isSelected: true, onTap: {})
                ChairPill("Singles", onTap: {})
                ChairPill("Doubles", onTap: {})
            }
            ChairPill("Pro")
        }
        .padding(Spacing.chair.md)
        .background(Color.chair.surface)
    }
}
