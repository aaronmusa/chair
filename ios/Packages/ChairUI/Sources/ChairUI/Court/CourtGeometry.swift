//
//  CourtGeometry.swift
//  ChairUI
//
//  Created by Aaron Musa on 10/27/26.
//

import CoreGraphics

import ChairKit

public struct CourtPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(
        x: Double,
        y: Double
    ) {
        self.x = x
        self.y = y
    }
}

public enum CourtOrientation: Sendable {
    case portrait
    case landscape
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

public struct CourtCoordinate: Sendable {
    public let size: CGSize
    public let orientation: CourtOrientation

    public init(
        size: CGSize,
        orientation: CourtOrientation
    ) {
        self.size = size
        self.orientation = orientation
    }

    public static func aspectRatio(for orientation: CourtOrientation) -> CGFloat {
        let ratio = CourtDimensions.areaWidth / CourtDimensions.areaLength
        return orientation == .portrait ? ratio : 1 / ratio
    }

    public var pointsPerMetre: CGFloat {
        switch orientation {
        case .portrait: size.width / CourtDimensions.areaWidth
        case .landscape: size.height / CourtDimensions.areaWidth
        }
    }

    public func point(_ court: CourtPoint) -> CGPoint {
        let across = court.x + CourtDimensions.areaWidth / 2
        let along = court.y + CourtDimensions.areaLength / 2
        switch orientation {
        case .portrait:
            return CGPoint(x: across * pointsPerMetre, y: size.height - along * pointsPerMetre)
        case .landscape:
            return CGPoint(x: along * pointsPerMetre, y: across * pointsPerMetre)
        }
    }

    public func rect(
        _ first: CourtPoint,
        _ second: CourtPoint
    ) -> CGRect {
        let a = point(first)
        let b = point(second)
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
}
