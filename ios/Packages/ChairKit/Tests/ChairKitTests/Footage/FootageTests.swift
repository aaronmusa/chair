//
//  FootageTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/11/26.
//

import CoreGraphics
import Foundation
import ImageIO
import XCTest

import ChairKit

final class FootageTests: XCTestCase {
    private struct MissingFootage: LocalizedError {
        let errorDescription: String?
    }

    private static let repository = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private var footage: FootageSet!

    override func setUpWithError() throws {
        let environment = ProcessInfo.processInfo.environment
        let folder = environment["FOOTAGE_DIR"].map { URL(filePath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "chair-footage")
        guard FileManager.default.fileExists(atPath: folder.path) else {
            let message = "No footage at \(folder.path). Run make footage first."
            guard environment["CHAIR_FOOTAGE_REQUIRED"] == "1" else { throw XCTSkip(message) }
            throw MissingFootage(errorDescription: message)
        }
        let tools = Self.repository.appending(path: "tools/footage")
        footage = try FootageSet.load(
            manifest: tools.appending(path: "manifest.json"),
            groundTruth: tools.appending(path: "ground_truth"),
            clips: folder
        )
    }

    func testEveryClipInTheManifestIsInTheFootageFolder() {
        XCTAssertEqual(footage.missingFiles(), [], "Run make footage to fetch the missing clips")
    }

    func testNetPostAndChairClipsHaveAStill() {
        XCTAssertEqual(footage.clipsWithoutStills, [], "E4-4 detects on a full-resolution still")
    }

    func testTheManifestAndGroundTruthAgree() {
        XCTAssertEqual(footage.problems, [])
    }

    func testGroundPointsMapWithinTheTargetsForEachPlacement() throws {
        for clip in footage.clips {
            let errors = clip.mappingErrors()
            let lines = try XCTUnwrap(errors.lines, clip.entry.id)
            print(String(
                format: "%@ (%@): lines %.1f cm, baselines %@",
                clip.entry.id,
                clip.entry.placement.rawValue,
                lines * 100,
                errors.baselines.map { String(format: "%.1f cm", $0 * 100) } ?? "none marked"
            ))
            switch clip.entry.placement {
            case .netPost, .chair:
                XCTAssertLessThan(lines, 0.15, clip.entry.id)
                XCTAssertLessThan(errors.baselines ?? 0, 0.30, clip.entry.id)
            case .baseline:
                XCTAssertLessThan(max(lines, errors.baselines ?? 0), 0.20, clip.entry.id)
            }
        }
    }

    func testSuggestedKeypointsLandWithinTwoPercentOnFourFifthsOfClips() async throws {
        var rows: [String] = []
        var passing = 0
        for clip in footage.clips {
            let truth = try XCTUnwrap(clip.groundTruth?.keypoints.min { $0.frame < $1.frame }?.pixels, clip.entry.id)
            let size = try XCTUnwrap(clip.groundTruth?.frameSize)
            let image: LumaImage = if let still = clip.entry.still {
                try Self.still(footage.folder.appending(path: still))
            } else {
                try await CourtLineDetectorTests.firstFrame(clip.url)
            }
            let suggestion = CourtLineDetector.suggest(
                in: image,
                placement: clip.entry.placement,
                frameSize: CGSize(width: size.width, height: size.height)
            )
            var worst = 0.0
            let header = String(format: "%@ (%@), confidence %.2f", clip.entry.id, clip.entry.placement.rawValue, suggestion.confidence)
            rows.append(header)
            for (keypoint, pixel) in truth.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                let error = suggestion.keypoints[keypoint].map { hypot($0.x - pixel.x, $0.y - pixel.y) / size.width * 100 }
                worst = max(worst, error ?? 100)
                rows.append("  \(keypoint.rawValue): " + (error.map { String(format: "%.2f %%", $0) } ?? "missing"))
            }
            passing += worst < 2 ? 1 : 0
        }
        print(rows.joined(separator: "\n"))
        let summary = "\(passing) of \(footage.clips.count) clips within 2 %"
        XCTAssertGreaterThanOrEqual(Double(passing), Double(footage.clips.count) * 0.8, summary)
    }

    private static func still(_ url: URL) throws -> LumaImage {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return try XCTUnwrap(LumaImage(cgImage: image))
    }

    func testEveryClipMatchesItsManifestEntry() async throws {
        for clip in footage.clips where FileManager.default.fileExists(atPath: clip.url.path) {
            let problems = try await clip.mediaProblems()
            XCTAssertEqual(problems, [], clip.entry.id)
        }
    }
}
