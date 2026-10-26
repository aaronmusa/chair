//
//  ChairTextStyle.swift
//  ChairUI
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI

public enum ChairTextStyle: String, CaseIterable, Sendable {
    case display
    case title
    case headline
    case body
    case callout
    case caption
    case score
    case scoreLarge

    public var pointSize: CGFloat {
        switch self {
        case .display: 28
        case .title: 22
        case .headline: 17
        case .body: 15
        case .callout: 13
        case .caption: 11
        case .score: 34
        case .scoreLarge: 56
        }
    }
}

public struct ChairFonts: Sendable {
    public let display = Font.title.bold()
    public let title = Font.title2.bold()
    public let headline = Font.headline
    public let body = Font.subheadline
    public let callout = Font.footnote
    public let caption = Font.caption2.weight(.semibold)
    public let score = Font.largeTitle.bold().monospacedDigit()
}

public extension Font {
    static let chair = ChairFonts()
}

public extension View {
    func chairFont(_ style: ChairTextStyle) -> some View {
        modifier(ChairFontModifier(style: style))
    }
}

private struct ChairFontModifier: ViewModifier {
    let style: ChairTextStyle

    @ScaledMetric(relativeTo: .largeTitle) private var scoreLargeSize: CGFloat = 56
    @ScaledMetric(relativeTo: .caption2) private var captionTracking: CGFloat = 11 * 0.04

    func body(content: Content) -> some View {
        switch style {
        case .display: content.font(Font.chair.display)
        case .title: content.font(Font.chair.title)
        case .headline: content.font(Font.chair.headline)
        case .body: content.font(Font.chair.body)
        case .callout: content.font(Font.chair.callout)
        case .caption: content.font(Font.chair.caption).textCase(.uppercase).tracking(captionTracking)
        case .score: content.font(Font.chair.score)
        case .scoreLarge: content.font(.system(size: scoreLargeSize, weight: .bold).monospacedDigit())
        }
    }
}
