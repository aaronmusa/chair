//
//  CourtGeometry.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/11/26.
//

import Foundation

public struct CourtPoint: Codable, Hashable, Sendable {
    public let x: Double
    public let y: Double

    public init(
        x: Double,
        y: Double
    ) {
        self.x = x
        self.y = y
    }

    public func distance(to other: CourtPoint) -> Double {
        hypot(x - other.x, y - other.y)
    }
}

public enum CourtDimensions {
    public static let length = 23.77
    public static let doublesWidth = 10.97
    public static let singlesWidth = 8.23
    public static let serviceLineFromNet = 6.40
    public static let centreMarkLength = 0.10
    public static let runOffBehindBaseline = 3.0
    public static let runOffBesideSideline = 2.0

    public static var halfLength: Double {
        length / 2
    }

    public static var halfDoublesWidth: Double {
        doublesWidth / 2
    }

    public static var halfSinglesWidth: Double {
        singlesWidth / 2
    }

    public static var areaLength: Double {
        length + runOffBehindBaseline * 2
    }

    public static var areaWidth: Double {
        doublesWidth + runOffBesideSideline * 2
    }
}
