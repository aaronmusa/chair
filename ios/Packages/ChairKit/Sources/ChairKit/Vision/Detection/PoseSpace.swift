//
//  PoseSpace.swift
//  ChairKit
//
//  Created by Aaron Musa on 11/12/26.
//

import Foundation
import simd

struct PoseSpace {
    struct Pose {
        var values: [Double]
    }

    static let ultraWideFieldOfView = 108.0 * .pi / 180

    let placement: CameraPlacement
    let ranges: [ClosedRange<Double>]
    let baseFocal: Double
    let centre: SIMD2<Double>

    init(
        placement: CameraPlacement,
        maskWidth: Int,
        maskHeight: Int
    ) {
        self.placement = placement
        baseFocal = Double(maskWidth) / (2 * tan(Self.ultraWideFieldOfView / 2))
        centre = SIMD2(Double(maskWidth) / 2, Double(maskHeight) / 2)
        let roll = -0.1 ... 0.1
        let focal = 0.85 ... 1.35
        switch placement {
        case .netPost:
            ranges = [0.2 ... 4, -2.5 ... 2.5, 0.8 ... 2.6, -1 ... 5.5, -4 ... 4, roll, focal]
        case .chair:
            ranges = [0.3 ... 3, -2 ... 2, 1.5 ... 4, -1 ... 5.5, -4 ... 4, roll, focal]
        case .baseline:
            ranges = [0.5 ... 14, -3 ... 3, 0.8 ... 5, -3 ... 3, -10 ... 6, roll, focal]
        }
    }

    func clamp(
        _ value: Double,
        at index: Int
    ) -> Double {
        min(max(value, ranges[index].lowerBound), ranges[index].upperBound)
    }

    func seeds() -> [Pose] {
        let grid = [0.125, 0.375, 0.625, 0.875]
        var poses: [Pose] = []
        for a in grid {
            for b in grid {
                for c in grid {
                    for d in grid {
                        for e in grid {
                            for focal in [0.92, 1.05, 1.2] {
                                let fractions = [a, b, c, d, e]
                                var values = zip(fractions, ranges).map { $1.lowerBound + ($1.upperBound - $1.lowerBound) * $0 }
                                values.append(0)
                                values.append(focal)
                                poses.append(Pose(values: values))
                            }
                        }
                    }
                }
            }
        }
        return poses
    }

    struct Frame {
        let camera: SIMD3<Double>
        let forward: SIMD3<Double>
        let right: SIMD3<Double>
        let down: SIMD3<Double>
        let focal: Double
        let centre: SIMD2<Double>

        func depth(_ court: CourtPoint) -> Double {
            simd_dot(SIMD3(court.x, court.y, 0) - camera, forward)
        }

        func project(_ court: CourtPoint) -> SIMD2<Double>? {
            let p = SIMD3(court.x, court.y, 0) - camera
            let depth = simd_dot(p, forward)
            guard depth > 0.1 else { return nil }
            return SIMD2(centre.x + focal * simd_dot(p, right) / depth, centre.y + focal * simd_dot(p, down) / depth)
        }

        func segment(
            _ from: CourtPoint,
            _ to: CourtPoint
        ) -> (SIMD2<Double>, SIMD2<Double>)? {
            let near = 0.2
            let a = depth(from)
            let b = depth(to)
            guard a > near || b > near else { return nil }
            func clip(_ inside: CourtPoint, _ outside: CourtPoint, _ di: Double, _ dout: Double) -> CourtPoint {
                let t = (di - near) / (di - dout)
                return CourtPoint(x: inside.x + (outside.x - inside.x) * t, y: inside.y + (outside.y - inside.y) * t)
            }
            let start = a > near ? from : clip(to, from, b, a)
            let end = b > near ? to : clip(from, to, a, b)
            guard let p = project(start), let q = project(end) else { return nil }
            return (p, q)
        }
    }

    func frame(_ pose: Pose) -> Frame {
        let v = pose.values
        let camera: SIMD3<Double> = switch placement {
        case .netPost, .chair:
            SIMD3(-(CourtDimensions.halfDoublesWidth + v[0]), v[1], v[2])
        case .baseline:
            SIMD3(v[1], -(CourtDimensions.halfLength + v[0]), v[2])
        }
        let forward = simd_normalize(SIMD3(v[3], v[4], 0) - camera)
        let flatRight = simd_normalize(simd_cross(forward, SIMD3(0, 0, 1)))
        let flatDown = simd_cross(forward, flatRight)
        return Frame(
            camera: camera,
            forward: forward,
            right: flatRight * cos(v[5]) + flatDown * sin(v[5]),
            down: flatDown * cos(v[5]) - flatRight * sin(v[5]),
            focal: baseFocal * v[6],
            centre: centre
        )
    }

    func project(
        _ court: CourtPoint,
        pose: Pose
    ) -> SIMD2<Double>? {
        frame(pose).project(court)
    }
}
