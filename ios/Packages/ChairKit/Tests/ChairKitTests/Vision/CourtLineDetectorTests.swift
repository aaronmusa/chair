//
//  CourtLineDetectorTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/11/26.
//

import AVFoundation
import CoreGraphics
import Foundation
import XCTest

import ChairKit
import ChairTestSupport

final class CourtLineDetectorTests: XCTestCase {
    func testTheSyntheticClipsAreFound() async throws {
        let set = try FootageFixtureTests.fixture()
        var rows: [String] = []
        for clip in set.clips {
            let truth = try XCTUnwrap(clip.groundTruth?.keypoints.first?.pixels)
            let frame = try await Self.firstFrame(clip.url)
            let start = Date()
            let suggestion = CourtLineDetector.suggest(
                in: frame,
                placement: clip.entry.placement,
                frameSize: CGSize(width: 1920, height: 1080)
            )
            let elapsed = Date().timeIntervalSince(start)
            rows.append(String(format: "%@: confidence %.2f, %.2f s", clip.entry.id, suggestion.confidence, elapsed))
            for (keypoint, pixel) in truth.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                let found = suggestion.keypoints[keypoint]
                let error = found.map { hypot($0.x - pixel.x, $0.y - pixel.y) / 1920 * 100 }
                rows.append("  \(keypoint): " + (error.map { String(format: "%.2f %%", $0) } ?? "missing"))
                XCTAssertLessThan(error ?? 100, 2, "\(clip.entry.id) \(keypoint)")
            }
            XCTAssertGreaterThanOrEqual(suggestion.confidence, CourtLineDetector.minimumConfidence, clip.entry.id)
        }
        print(rows.joined(separator: "\n"))
    }

    func testRandomNetPostCamerasAreFound() throws {
        try assertFound(.netPost, count: 4, seed: 21)
    }

    func testRandomChairCamerasAreFound() throws {
        try assertFound(.chair, count: 3, seed: 33)
    }

    func testRandomBaselineCamerasAreFound() throws {
        try assertFound(.baseline, count: 3, seed: 45)
    }

    func testPlayersAFenceAndNoiseDoNotThrowItOff() throws {
        try assertFound(.netPost, count: 3, seed: 57, clutter: SyntheticCourt.Clutter(players: 6, fence: true, noise: 8))
    }

    func testALowOneMetreMountIsStillFound() throws {
        let camera = PinholeCamera(position: SIMD3(-6.2, 0.4, 1.0), target: SIMD3(3, 0, 0), focal: 697)
        try assertFound([camera], placement: .netPost)
    }

    func testAFourByThreeStillMapsIntoTheSixteenByNineFrame() throws {
        let still = PinholeCamera(
            position: SIMD3(-6.6, 0.2, 1.6),
            target: SIMD3(2.5, 0, 0),
            focal: 697,
            size: CGSize(width: 1920, height: 1440)
        )
        let image = try XCTUnwrap(SyntheticCourt(camera: still).render())

        let suggestion = CourtLineDetector.suggest(in: image, placement: .netPost, frameSize: CGSize(width: 1920, height: 1080))

        for keypoint in CourtKeypoint.defaultSet(for: .netPost) {
            let truth = try XCTUnwrap(still.project(keypoint.court))
            let expected = CGPoint(x: truth.x, y: truth.y - 180)
            let found = try XCTUnwrap(suggestion.keypoints[keypoint], "\(keypoint)")
            XCTAssertLessThan(hypot(found.x - expected.x, found.y - expected.y), 0.02 * 1920, "\(keypoint)")
        }
    }

    func testASkyWithNoCourtSuggestsNothing() {
        var generator = SeededGenerator(seed: 5)
        let pixels = (0 ..< 1920 * 1080).map { _ in UInt8.random(in: 170 ... 190, using: &generator) }
        let sky = LumaImage(width: 1920, height: 1080, pixels: pixels)

        let suggestion = CourtLineDetector.suggest(in: sky, placement: .netPost, frameSize: CGSize(width: 1920, height: 1080))

        XCTAssertLessThan(suggestion.confidence, CourtLineDetector.minimumConfidence)
        XCTAssertTrue(suggestion.keypoints.isEmpty)
    }

    private func assertFound(
        _ placement: CameraPlacement,
        count: Int,
        seed: UInt64,
        clutter: SyntheticCourt.Clutter = SyntheticCourt.Clutter()
    ) throws {
        var generator = SeededGenerator(seed: seed)
        var cameras: [PinholeCamera] = []
        while cameras.count < count {
            let camera = Self.randomCamera(placement, using: &generator)
            if CourtKeypoint.defaultSet(for: placement).allSatisfy({ camera.inFrame($0.court) }) {
                cameras.append(camera)
            }
        }
        try assertFound(cameras, placement: placement, clutter: clutter)
    }

    private func assertFound(
        _ cameras: [PinholeCamera],
        placement: CameraPlacement,
        clutter: SyntheticCourt.Clutter = SyntheticCourt.Clutter()
    ) throws {
        for (index, camera) in cameras.enumerated() {
            let image = try XCTUnwrap(SyntheticCourt(camera: camera, clutter: clutter).render(seed: UInt64(index + 1)))
            let suggestion = CourtLineDetector.suggest(in: image, placement: placement, frameSize: camera.size)
            let label = "\(placement) camera \(index) at \(camera.position)"
            XCTAssertGreaterThanOrEqual(suggestion.confidence, CourtLineDetector.minimumConfidence, label)
            for keypoint in CourtKeypoint.defaultSet(for: placement) {
                let truth = try XCTUnwrap(camera.project(keypoint.court))
                let found = try XCTUnwrap(suggestion.keypoints[keypoint], "\(label) missed \(keypoint)")
                let error = hypot(found.x - truth.x, found.y - truth.y) / camera.size.width * 100
                XCTAssertLessThan(error, 2, "\(label) \(keypoint) is off by \(String(format: "%.2f", error)) %")
            }
        }
    }

    static func randomCamera(
        _ placement: CameraPlacement,
        using generator: inout SeededGenerator
    ) -> PinholeCamera {
        let doubles = CourtDimensions.halfDoublesWidth
        let roll = Double.random(in: -0.05 ... 0.05, using: &generator)
        switch placement {
        case .netPost, .chair:
            let height = placement == .chair ? Double.random(in: 2 ... 3.5, using: &generator) : .random(in: 1 ... 2.2, using: &generator)
            return PinholeCamera(
                position: SIMD3(
                    -(doubles + .random(in: 0.4 ... 2.5, using: &generator)),
                    .random(in: -1.5 ... 1.5, using: &generator),
                    height
                ),
                target: SIMD3(.random(in: 1 ... 4.5, using: &generator), .random(in: -1.5 ... 1.5, using: &generator), 0),
                focal: 697 * .random(in: 0.9 ... 1.15, using: &generator),
                roll: roll
            )
        case .baseline:
            return PinholeCamera(
                position: SIMD3(
                    .random(in: -2 ... 2, using: &generator),
                    -(CourtDimensions.halfLength + .random(in: 5 ... 10, using: &generator)),
                    .random(in: 1.5 ... 4, using: &generator)
                ),
                target: SIMD3(.random(in: -1 ... 1, using: &generator), .random(in: -6 ... 1, using: &generator), 0),
                focal: 697 * .random(in: 0.9 ... 1.25, using: &generator),
                roll: roll
            )
        }
    }

    static func firstFrame(_ url: URL) async throws -> LumaImage {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = try await generator.image(at: .zero).image
        return try XCTUnwrap(LumaImage(cgImage: image))
    }
}
