//
//  ChairRow.swift
//  ChairUI
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI

public struct ChairRow: View {
    let title: String
    let systemImage: String?
    let value: String?
    let showsChevron: Bool
    let onTap: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var iconWidth: CGFloat = 28

    public init(
        _ title: String,
        systemImage: String? = nil,
        value: String? = nil,
        showsChevron: Bool = false,
        onTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.value = value
        self.showsChevron = showsChevron
        self.onTap = onTap
    }

    public var body: some View {
        if let onTap {
            Button(action: onTap) { content }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(title)
                .accessibilityValue(value ?? "")
                .accessibilityAddTraits(.isButton)
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(title)
                .accessibilityValue(value ?? "")
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private var content: some View {
        HStack(spacing: Spacing.chair.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(Font.chair.headline)
                    .foregroundStyle(Color.chair.ink)
                    .frame(width: iconWidth)
            }
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                    titleText
                    valueText
                }
                Spacer(minLength: Spacing.chair.xs)
            } else {
                titleText
                Spacer(minLength: Spacing.chair.xs)
                valueText
                    .multilineTextAlignment(.trailing)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(Font.chair.callout.weight(.semibold))
                    .foregroundStyle(Color.chair.inkSecondary)
            }
        }
        .padding(.horizontal, Spacing.chair.md)
        .padding(.vertical, Spacing.chair.xs)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private var titleText: some View {
        Text(title)
            .chairFont(.body)
            .foregroundStyle(Color.chair.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var valueText: some View {
        if let value {
            Text(value)
                .chairFont(.body)
                .foregroundStyle(Color.chair.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Light") {
    ChairRowPreview()
}

#Preview("Dark") {
    ChairRowPreview()
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    ChairRowPreview()
        .environment(\.dynamicTypeSize, .accessibility5)
}

struct ChairRowPreview: View {
    var body: some View {
        VStack(spacing: 0) {
            ChairRow("Voice", systemImage: "speaker.wave.2", value: "Daniel", showsChevron: true, onTap: {})
            ChairRow("Home court", systemImage: "mappin", value: "Rizal Park")
            ChairRow("Subscription", showsChevron: true, onTap: {})
        }
        .background(Color.chair.surface)
    }
}
