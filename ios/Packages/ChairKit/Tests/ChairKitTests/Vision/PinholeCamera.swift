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
    static let behindBaseline = PinholeCamera(position: SIMD3(0, -18.5, 3.5), target: SIMD3(0, -3, 0), focal: 697)
    static let netPost = PinholeCamera(position: SIMD3(-6.4, 0, 1.3), target: SIMD3(3, 0, 0), focal: 697)

    let position: SIMD3<Double>
    let target: SIMD3<Double>
    let roll: Double
    let focal: Double
    let size: CGSize
    private let forward: SIMD3<Double>
    private let right: SIMD3<Double>
    private let down: SIMD3<Double>

    init(
        position: SIMD3<Double>,
        target: SIMD3<Double>,
        focal: Double,
        roll: Double = 0,
        size: CGSize = CGSize(width: 1920, height: 1080)
    ) {
        self.position = position
        self.target = target
        self.roll = roll
        self.focal = focal
        self.size = size
        forward = simd_normalize(target - position)
        let flatRight = simd_normalize(simd_cross(forward, SIMD3(0, 0, 1)))
        let flatDown = simd_cross(forward, flatRight)
        right = flatRight * cos(roll) + flatDown * sin(roll)
        down = flatDown * cos(roll) - flatRight * sin(roll)
    }

    func project(_ court: CourtPoint) -> CGPoint? {
        let p = SIMD3(court.x, court.y, 0) - position
        let depth = simd_dot(p, forward)
        guard depth > 0.1 else { return nil }
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
