//
//  MetricTokenList.swift
//  ChairUI
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI

#if DEBUG

    public struct MetricTokenList: View {
        public init() {}

        public var body: some View {
            VStack(alignment: .leading, spacing: Spacing.chair.xl) {
                section("Spacing", Spacing.chair.scale) { value in
                    Rectangle()
                        .fill(Color.chair.ink)
                        .frame(width: value, height: Spacing.chair.md)
                }
                section("Radius", Radius.chair.scale) { value in
                    RoundedRectangle(cornerRadius: value)
                        .stroke(Color.chair.ink, lineWidth: Stroke.chair.regular)
                        .frame(width: 56, height: 40)
                }
                section("Stroke", Stroke.chair.scale) { value in
                    Rectangle()
                        .fill(Color.chair.ink)
                        .frame(width: 56, height: value)
                }
            }
            .padding(Spacing.chair.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.chair.surface)
        }

        private func section(
            _ title: String,
            _ scale: [(name: String, value: CGFloat)],
            @ViewBuilder sample: @escaping (CGFloat) -> some View
        ) -> some View {
            VStack(alignment: .leading, spacing: Spacing.chair.sm) {
                Text(title)
                    .chairFont(.caption)
                    .foregroundStyle(Color.chair.inkSecondary)
                ForEach(scale, id: \.name) { token in
                    HStack(spacing: Spacing.chair.md) {
                        sample(token.value)
                            .frame(width: 64, alignment: .leading)
                        Text("\(token.name) · \(token.value.formatted())")
                            .chairFont(.callout)
                            .foregroundStyle(Color.chair.ink)
                    }
                }
            }
        }
    }

    #Preview {
        ScrollView { MetricTokenList() }
    }
#endif
