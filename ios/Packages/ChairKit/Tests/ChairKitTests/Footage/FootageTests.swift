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

    func testEveryClipMatchesItsManifestEntry() async throws {
        for clip in footage.clips where FileManager.default.fileExists(atPath: clip.url.path) {
            let problems = try await clip.mediaProblems()
            XCTAssertEqual(problems, [], clip.entry.id)
        }
    }
}
