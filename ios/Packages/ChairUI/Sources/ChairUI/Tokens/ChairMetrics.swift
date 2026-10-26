//
//  ChairMetrics.swift
//  ChairUI
//
//  Created by Aaron Musa on 10/27/26.
//

import CoreGraphics

public struct ChairSpacing: Sendable {
    public let xxs: CGFloat = 4
    public let xs: CGFloat = 8
    public let sm: CGFloat = 12
    public let md: CGFloat = 16
    public let lg: CGFloat = 20
    public let xl: CGFloat = 24
    public let xxl: CGFloat = 32

    public var scale: [(name: String, value: CGFloat)] {
        [("xxs", xxs), ("xs", xs), ("sm", sm), ("md", md), ("lg", lg), ("xl", xl), ("xxl", xxl)]
    }
}

public struct ChairRadius: Sendable {
    public let small: CGFloat = 8
    public let medium: CGFloat = 10
    public let large: CGFloat = 12
    public let card: CGFloat = 16

    public var scale: [(name: String, value: CGFloat)] {
        [("small", small), ("medium", medium), ("large", large), ("card", card)]
    }
}

public struct ChairStroke: Sendable {
    public let thin: CGFloat = 1
    public let regular: CGFloat = 1.5
    public let bold: CGFloat = 2

    public var scale: [(name: String, value: CGFloat)] {
        [("thin", thin), ("regular", regular), ("bold", bold)]
    }
}

public enum Spacing {
    public static let chair = ChairSpacing()
}

public enum Radius {
    public static let chair = ChairRadius()
}

public enum Stroke {
    public static let chair = ChairStroke()
}
