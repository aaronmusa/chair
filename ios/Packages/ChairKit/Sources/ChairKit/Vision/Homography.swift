//
//  Homography.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/11/26.
//

import CoreGraphics
import Foundation
import simd

public protocol Undistorter: Sendable {
    func undistort(_ pixel: CGPoint) -> CGPoint
    func distort(_ pixel: CGPoint) -> CGPoint
}

public struct NoUndistortion: Undistorter {
    public init() {}

    public func undistort(_ pixel: CGPoint) -> CGPoint {
        pixel
    }

    public func distort(_ pixel: CGPoint) -> CGPoint {
        pixel
    }
}

public struct Homography: Sendable {
    public static let minimumPoints = 4

    public let matrix: simd_double3x3
    public let undistorter: any Undistorter
    private let inverse: simd_double3x3
    private let facing: Double

    public init?(
        _ keypoints: [CourtKeypoint: CGPoint],
        undistorter: any Undistorter = NoUndistortion()
    ) {
        let pairs = keypoints.map { (court: $0.key.court, pixel: undistorter.undistort($0.value)) }
        self.init(pairs: pairs, undistorter: undistorter)
    }

    public init?(
        court: [CourtPoint],
        pixels: [CGPoint],
        undistorter: any Undistorter = NoUndistortion()
    ) {
        guard court.count == pixels.count else { return nil }
        let pairs = zip(court, pixels).map { (court: $0, pixel: undistorter.undistort($1)) }
        self.init(pairs: pairs, undistorter: undistorter)
    }

    private init?(
        pairs: [(court: CourtPoint, pixel: CGPoint)],
        undistorter: any Undistorter
    ) {
        guard pairs.count >= Self.minimumPoints else { return nil }
        let courtPoints = pairs.map { SIMD2($0.court.x, $0.court.y) }
        let pixelPoints = pairs.map { SIMD2(Double($0.pixel.x), Double($0.pixel.y)) }
        let courtNorm = Self.normalisation(courtPoints)
        let pixelNorm = Self.normalisation(pixelPoints)
        guard let normalised = Self.solve(
            court: courtPoints.map { Self.apply(courtNorm, $0) },
            pixels: pixelPoints.map { Self.apply(pixelNorm, $0) }
        ) else { return nil }
        let matrix = pixelNorm.inverse * normalised * courtNorm
        guard matrix.determinant.isFinite, abs(matrix.determinant) > 1e-12 else { return nil }
        self.matrix = matrix
        inverse = matrix.inverse
        self.undistorter = undistorter
        let first = matrix * SIMD3(pairs[0].court.x, pairs[0].court.y, 1)
        facing = first.z < 0 ? -1 : 1
    }

    public func toPixel(_ court: CourtPoint) -> CGPoint {
        let p = matrix * SIMD3(court.x, court.y, 1)
        return undistorter.distort(CGPoint(x: p.x / p.z, y: p.y / p.z))
    }

    public func toCourt(_ pixel: CGPoint) -> CourtPoint? {
        let flat = undistorter.undistort(pixel)
        let c = inverse * SIMD3(Double(flat.x), Double(flat.y), 1)
        guard abs(c.z) > 1e-12 else { return nil }
        let court = CourtPoint(x: c.x / c.z, y: c.y / c.z)
        guard court.x.isFinite, court.y.isFinite else { return nil }
        let w = (matrix * SIMD3(court.x, court.y, 1)).z * facing
        return w > 0 ? court : nil
    }

    public func reprojectionError(_ keypoints: [CourtKeypoint: CGPoint]) -> Double {
        guard !keypoints.isEmpty else { return 0 }
        let squares = keypoints.map { keypoint, pixel in
            let projected = toPixel(keypoint.court)
            return pow(projected.x - pixel.x, 2) + pow(projected.y - pixel.y, 2)
        }
        return sqrt(squares.reduce(0, +) / Double(squares.count))
    }

    private static func normalisation(_ points: [SIMD2<Double>]) -> simd_double3x3 {
        let centroid = points.reduce(SIMD2<Double>.zero, +) / Double(points.count)
        let meanDistance = points.map { simd_distance($0, centroid) }.reduce(0, +) / Double(points.count)
        let scale = meanDistance > 0 ? 2.0.squareRoot() / meanDistance : 1
        return simd_double3x3(rows: [
            SIMD3(scale, 0, -scale * centroid.x),
            SIMD3(0, scale, -scale * centroid.y),
            SIMD3(0, 0, 1),
        ])
    }

    private static func apply(
        _ matrix: simd_double3x3,
        _ point: SIMD2<Double>
    ) -> SIMD2<Double> {
        let p = matrix * SIMD3(point.x, point.y, 1)
        return SIMD2(p.x / p.z, p.y / p.z)
    }

    private static func solve(
        court: [SIMD2<Double>],
        pixels: [SIMD2<Double>]
    ) -> simd_double3x3? {
        var normal = [[Double]](repeating: [Double](repeating: 0, count: 9), count: 8)
        for (c, p) in zip(court, pixels) {
            let rows: [[Double]] = [
                [c.x, c.y, 1, 0, 0, 0, -p.x * c.x, -p.x * c.y, p.x],
                [0, 0, 0, c.x, c.y, 1, -p.y * c.x, -p.y * c.y, p.y],
            ]
            for row in rows {
                for i in 0 ..< 8 {
                    for j in 0 ..< 9 {
                        normal[i][j] += row[i] * row[j]
                    }
                }
            }
        }
        guard let h = eliminate(normal) else { return nil }
        return simd_double3x3(rows: [
            SIMD3(h[0], h[1], h[2]),
            SIMD3(h[3], h[4], h[5]),
            SIMD3(h[6], h[7], 1),
        ])
    }

    private static func eliminate(_ augmented: [[Double]]) -> [Double]? {
        var m = augmented
        let n = m.count
        for column in 0 ..< n {
            guard let pivot = (column ..< n).max(by: { abs(m[$0][column]) < abs(m[$1][column]) }),
                  abs(m[pivot][column]) > 1e-10 else { return nil }
            m.swapAt(column, pivot)
            for row in 0 ..< n where row != column {
                let factor = m[row][column] / m[column][column]
                for j in column ... n {
                    m[row][j] -= factor * m[column][j]
                }
            }
        }
        return (0 ..< n).map { m[$0][n] / m[$0][$0] }
    }
}
