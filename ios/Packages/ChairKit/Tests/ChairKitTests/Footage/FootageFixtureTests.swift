//
//  FootageFixtureTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/11/26.
//

import Foundation
import XCTest

import ChairKit

final class FootageFixtureTests: XCTestCase {
    func testTheSyntheticClipsLoadWithTheirGroundTruth() throws {
        let set = try Self.fixture()

        XCTAssertEqual(set.clips.map(\.entry.id), ["synthetic-baseline", "synthetic-netPost"])
        XCTAssertEqual(set.clips.map(\.entry.placement), [.baseline, .netPost])
        XCTAssertEqual(set.clips.map(\.entry.frameCount), [120, 120])
        XCTAssertEqual(set.clips.map { $0.groundTruth?.keypoints.first?.points.count }, [14, 8])
        XCTAssertEqual(
            Set(set.clips[1].groundTruth?.keypoints.first?.points.map(\.keypoint) ?? []),
            Set(CameraPlacement.netPost.keypoints)
        )
        XCTAssertTrue(set.missingFiles().isEmpty)
    }

    func testTheSyntheticSetIsConsistent() async throws {
        let set = try Self.fixture()

        XCTAssertEqual(set.problems, [])
        for clip in set.clips {
            let media = try await clip.mediaProblems()
            XCTAssertEqual(media, [], clip.entry.id)
        }
    }

    func testAMislabelledKeypointIsReported() throws {
        let clip = try Self.fixture().clips[0]
        var truth = try XCTUnwrap(clip.groundTruth)
        let first = truth.keypoints[0].points[0].keypoint
        truth.keypoints[0].points[0].keypoint = truth.keypoints[0].points[5].keypoint
        truth.keypoints[0].points[5].keypoint = first

        let broken = FootageSet.Clip(entry: clip.entry, groundTruth: truth, url: clip.url)

        XCTAssertEqual(broken.problems.count, 1)
        XCTAssertTrue(broken.problems[0].hasPrefix("frame 0: keypoints disagree by"), broken.problems[0])
    }

    func testMissingKeypointFramesAndThinGroundTruthAreReported() throws {
        let clip = try Self.fixture().clips[0]
        var entry = clip.entry
        entry.duration = 25
        var truth = try XCTUnwrap(clip.groundTruth)
        truth.groundPoints = Array(truth.groundPoints.prefix(9))
        truth.groundPoints[0].court.y = 13

        let broken = FootageSet.Clip(entry: entry, groundTruth: truth, url: clip.url)

        XCTAssertEqual(broken.problems, [
            "no keypoints at frame 600",
            "no keypoints at frame 1200",
            "9 ground points, need 10",
            "\(truth.groundPoints[0].name) lies outside the court",
        ])
    }

    func testTooFewKeypointsAreReported() throws {
        let clip = try Self.fixture().clips[1]
        var truth = try XCTUnwrap(clip.groundTruth)
        truth.keypoints[0].points = Array(truth.keypoints[0].points.prefix(3))

        let broken = FootageSet.Clip(entry: clip.entry, groundTruth: truth, url: clip.url)

        XCTAssertEqual(broken.problems, ["frame 0: 3 keypoints, need 4"])
    }

    func testAClipWithoutGroundTruthAndAStrayFileAreReported() throws {
        let clip = try Self.fixture().clips[0]
        let set = FootageSet(
            clips: [FootageSet.Clip(entry: clip.entry, groundTruth: nil, url: clip.url)],
            strayGroundTruth: ["old-clip"]
        )

        XCTAssertEqual(set.problems, [
            "old-clip: ground truth with no manifest entry",
            "synthetic-baseline: no ground truth",
        ])
    }

    func testTheSyntheticGroundPointsMapWithinTheTargets() throws {
        for clip in try Self.fixture().clips {
            let errors = clip.mappingErrors()
            let lines = try XCTUnwrap(errors.lines)
            let baselines = try XCTUnwrap(errors.baselines)
            XCTAssertLessThan(lines, 0.02, clip.entry.id)
            XCTAssertLessThan(baselines, 0.02, clip.entry.id)
        }
    }

    static func fixture() throws -> FootageSet {
        let folder = try XCTUnwrap(Bundle.module.url(forResource: "Footage", withExtension: nil, subdirectory: "Fixtures"))
        return try FootageSet.load(
            manifest: folder.appending(path: "manifest.json"),
            groundTruth: folder.appending(path: "ground_truth"),
            clips: folder
        )
    }
}
