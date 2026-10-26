//
//  TypeScaleList.swift
//  ChairUI
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI

#if DEBUG

    public struct TypeScaleList: View {
        public init() {}

        public var body: some View {
            VStack(alignment: .leading, spacing: Spacing.chair.lg) {
                ForEach(ChairTextStyle.allCases, id: \.self) { style in
                    TypeScaleRow(style: style)
                }
            }
            .padding(Spacing.chair.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.chair.surface)
        }
    }

    struct TypeScaleRow: View {
        let style: ChairTextStyle

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.chair.xxs) {
                Text(style.sample)
                    .chairFont(style)
                    .foregroundStyle(Color.chair.ink)
                Text("\(style.rawValue) · \(style.pointSize.formatted()) pt")
                    .chairFont(.callout)
                    .foregroundStyle(Color.chair.inkSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    extension ChairTextStyle {
        var sample: String {
            switch self {
            case .display: "Game, set and match"
            case .title: "Second set"
            case .headline: "Musa to serve"
            case .body: "Tap a side to give it the point, or say \"Chair, point Musa\"."
            case .callout: "Corrected by voice · 5 s ago"
            case .caption: "Deuce side"
            case .score: "40"
            case .scoreLarge: "15"
            }
        }
    }

    #Preview("Default") {
        ScrollView { TypeScaleList() }
    }

    #Preview("AX5") {
        ScrollView { TypeScaleList() }
            .environment(\.dynamicTypeSize, .accessibility5)
    }
#endif
