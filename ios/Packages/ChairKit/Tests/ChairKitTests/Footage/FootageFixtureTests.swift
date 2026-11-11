//
//  FootageFixtureTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/11/26.
//

import Foundation
import XCTest

final class FootageFixtureTests: XCTestCase {
    func testTheSyntheticClipLoadsWithItsGroundTruth() throws {
        let set = try Self.fixture()

        let clip = try XCTUnwrap(set.clips.first)
        XCTAssertEqual(set.clips.count, 1)
        XCTAssertEqual(clip.entry.id, "synthetic-baseline")
        XCTAssertEqual(clip.entry.placement, .baseline)
        XCTAssertEqual(clip.entry.frameCount, 120)
        XCTAssertEqual(clip.groundTruth?.corners.map(\.frame), [0])
        XCTAssertEqual(clip.groundTruth?.groundPoints.count, 12)
        XCTAssertTrue(set.missingFiles().isEmpty)
    }

    func testTheSyntheticSetIsConsistent() async throws {
        let set = try Self.fixture()

        XCTAssertEqual(set.problems, [])
        let media = try await set.clips[0].mediaProblems()
        XCTAssertEqual(media, [])
    }

    func testReversedCornersAreReported() throws {
        let clip = try XCTUnwrap(Self.fixture().clips.first)
        var truth = try XCTUnwrap(clip.groundTruth)
        truth.corners[0].points.reverse()

        let broken = FootageSet.Clip(entry: clip.entry, groundTruth: truth, url: clip.url)

        XCTAssertEqual(broken.problems, ["frame 0: corners are not ordered far-left, far-right, near-right, near-left"])
    }

    func testMissingCornerFramesAndThinGroundTruthAreReported() throws {
        let clip = try XCTUnwrap(Self.fixture().clips.first)
        var entry = clip.entry
        entry.duration = 25
        var truth = try XCTUnwrap(clip.groundTruth)
        truth.groundPoints = Array(truth.groundPoints.prefix(9))
        truth.groundPoints[0].court.y = 13

        let broken = FootageSet.Clip(entry: entry, groundTruth: truth, url: clip.url)

        XCTAssertEqual(broken.problems, [
            "no corners at frame 600",
            "no corners at frame 1200",
            "9 ground points, need 10",
            "far baseline, left doubles sideline lies outside the court",
        ])
    }

    func testAClipWithoutGroundTruthAndAStrayFileAreReported() throws {
        let clip = try XCTUnwrap(Self.fixture().clips.first)
        let set = FootageSet(
            clips: [FootageSet.Clip(entry: clip.entry, groundTruth: nil, url: clip.url)],
            strayGroundTruth: ["old-clip"]
        )

        XCTAssertEqual(set.problems, [
            "old-clip: ground truth with no manifest entry",
            "synthetic-baseline: no ground truth",
        ])
    }

    private static func fixture() throws -> FootageSet {
        let folder = try XCTUnwrap(Bundle.module.url(forResource: "Footage", withExtension: nil, subdirectory: "Fixtures"))
        return try FootageSet.load(
            manifest: folder.appending(path: "manifest.json"),
            groundTruth: folder.appending(path: "ground_truth"),
            clips: folder
        )
    }
}
