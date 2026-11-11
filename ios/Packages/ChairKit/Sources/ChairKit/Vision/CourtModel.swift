//
//  CourtModel.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/11/26.
//

import Foundation

public enum LineCall: Equatable, Sendable {
    case `in`
    case out
    case onLine(distance: Double)
}

public enum CourtModel {
    public struct Segment: Equatable, Sendable {
        public let from: CourtPoint
        public let to: CourtPoint
    }

    public static let ballRadius = 0.033

    public static var lines: [Segment] {
        let half = CourtDimensions.halfLength
        let doubles = CourtDimensions.halfDoublesWidth
        let singles = CourtDimensions.halfSinglesWidth
        let service = CourtDimensions.serviceLineFromNet
        let mark = CourtDimensions.centreMarkLength
        return [
            segment(-doubles, half, doubles, half),
            segment(-doubles, -half, doubles, -half),
            segment(-doubles, -half, -doubles, half),
            segment(doubles, -half, doubles, half),
            segment(-singles, -half, -singles, half),
            segment(singles, -half, singles, half),
            segment(-singles, service, singles, service),
            segment(-singles, -service, singles, -service),
            segment(0, -service, 0, service),
            segment(0, half - mark, 0, half),
            segment(0, -half, 0, -half + mark),
        ]
    }

    public static func isIn(
        _ point: CourtPoint,
        singles: Bool,
        radius: Double = ballRadius
    ) -> LineCall {
        let halfWidth = singles ? CourtDimensions.halfSinglesWidth : CourtDimensions.halfDoublesWidth
        let outside = hypot(
            max(abs(point.x) - halfWidth, 0),
            max(abs(point.y) - CourtDimensions.halfLength, 0)
        )
        if outside == 0 {
            return .in
        }
        return outside <= radius ? .onLine(distance: outside) : .out
    }

    private static func segment(
        _ x0: Double,
        _ y0: Double,
        _ x1: Double,
        _ y1: Double
    ) -> Segment {
        Segment(from: CourtPoint(x: x0, y: y0), to: CourtPoint(x: x1, y: y1))
    }
}
