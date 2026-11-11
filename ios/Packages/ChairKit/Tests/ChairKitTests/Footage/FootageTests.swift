//
//  FootageTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/11/26.
//

import Foundation
import XCTest

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

    func testEveryClipMatchesItsManifestEntry() async throws {
        for clip in footage.clips where FileManager.default.fileExists(atPath: clip.url.path) {
            let problems = try await clip.mediaProblems()
            XCTAssertEqual(problems, [], clip.entry.id)
        }
    }
}
