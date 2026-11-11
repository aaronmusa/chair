//
//  PinholeCamera.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/11/26.
//

import CoreGraphics
import simd

import ChairKit

struct PinholeCamera {
    static let behindBaseline = PinholeCamera(position: SIMD3(0, -19, 4), target: SIMD3(0, -2, 0), focal: 1100)
    static let netPost = PinholeCamera(position: SIMD3(-6.4, 0, 1.3), target: SIMD3(3, 0, 0), focal: 697)

    let position: SIMD3<Double>
    let focal: Double
    let size = CGSize(width: 1920, height: 1080)
    private let forward: SIMD3<Double>
    private let right: SIMD3<Double>
    private let down: SIMD3<Double>

    init(
        position: SIMD3<Double>,
        target: SIMD3<Double>,
        focal: Double
    ) {
        self.position = position
        self.focal = focal
        forward = simd_normalize(target - position)
        right = simd_normalize(simd_cross(forward, SIMD3(0, 0, 1)))
        down = simd_cross(forward, right)
    }

    func project(_ court: CourtPoint) -> CGPoint? {
        let p = SIMD3(court.x, court.y, 0) - position
        let depth = simd_dot(p, forward)
        guard depth > 0 else { return nil }
        return CGPoint(
            x: size.width / 2 + focal * simd_dot(p, right) / depth,
            y: size.height / 2 + focal * simd_dot(p, down) / depth
        )
    }

    func inFrame(_ court: CourtPoint) -> Bool {
        project(court).map { CGRect(origin: .zero, size: size).contains($0) } ?? false
    }

    func keypoints(_ keypoints: [CourtKeypoint]) -> [CourtKeypoint: CGPoint] {
        Dictionary(uniqueKeysWithValues: keypoints.compactMap { keypoint in project(keypoint.court).map { (keypoint, $0) } })
    }
}
