//
//  CameraPanelTests.swift
//  ChairTests
//
//  Created by Aaron Musa on 11/12/26.
//

import SwiftData
import SwiftUI
import XCTest

import ChairKit
import ChairTestSupport
import ChairUI
import SnapshotTesting

@testable import Chair

@MainActor
final class CameraPanelTests: XCTestCase {
    private struct NoSuggestions: KeypointSuggesting {
        func suggest(
            in _: LumaImage,
            placement _: CameraPlacement,
            frameSize _: CGSize
        ) async -> CourtSuggestion {
            .none
        }
    }

    private static let footage = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Packages/ChairKit/Tests/ChairKitTests/Fixtures/Footage")

    private var container: ModelContainer?

    func testACameraMatchShowsTheCalibratedPanelWhileScoringUndoAndCallsKeepWorking() async throws {
        let (repository, match) = try makeCameraMatch()
        let session = MatchSessionViewModel(matchID: match.remoteID, repository: repository, clock: FixedClock(Fixtures.matchDay))
        var calls = session.outputs().makeAsyncIterator()

        session.load()
        let calibration = try XCTUnwrap(session.calibration)
        let panel = makePanel(match: match, calibration: calibration, repository: repository)
        let start = Date()
        await panel.start()
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 1)
        XCTAssertEqual(panel.captureState, .running(frameRate: 60))
        XCTAssertFalse(panel.lines.isEmpty)
        XCTAssertEqual(panel.chip, "60 fps · Calibrated")
        session.playPoint()
        await session.apply(.pointWon(by: .a, outcome: .winner, ending: nil))
        let call = await calls.next()
        XCTAssertNotNil(call)
        let afterPoint = session.scoreboard?.rows.map(\.points)
        await session.apply(.undo)
        XCTAssertNotEqual(session.scoreboard?.rows.map(\.points), afterPoint)
        await panel.stop()
    }

    func testAnInterruptionShowsTheBannerAndThePreviewResumes() async throws {
        let (repository, match) = try makeCameraMatch()
        let capture = FakeCaptureSession(source: .blank(width: 640, height: 360))
        let panel = try makePanel(match: match, calibration: XCTUnwrap(match.calibration), repository: repository) { capture }
        await panel.start()

        capture.simulateInterruption(.otherApp)
        try await waitUntil { panel.captureState == .interrupted(.otherApp) }
        XCTAssertEqual(CaptureStatus(panel.captureState)?.title, "Another app is using the camera")

        capture.endInterruption()
        try await waitUntil { panel.captureState == .running(frameRate: 60) }
        XCTAssertNil(CaptureStatus(panel.captureState))
        await panel.stop()
    }

    func testRecalibrateOpensWithTheCurrentPointsAndNextChangesTheMatch() async throws {
        let (repository, match) = try makeCameraMatch()
        let original = try XCTUnwrap(match.calibration)
        let panel = makePanel(match: match, calibration: original, repository: repository)
        await panel.start()

        await panel.recalibrate()
        XCTAssertTrue(panel.isRecalibrating)
        XCTAssertEqual(panel.captureState, .idle)
        let calibrating = panel.makeCalibrationModel()
        XCTAssertEqual(calibrating.keypoints, original.keypoints)
        let corner = try XCTUnwrap(CourtKeypoint(.doublesRight, .farBaseline))
        let point = try XCTUnwrap(original.keypoints[corner])
        calibrating.move(corner, to: CGPoint(x: point.x + 12, y: point.y))
        calibrating.finish()

        try await waitUntil { !panel.isRecalibrating }
        XCTAssertNotEqual(panel.calibration.keypoints, original.keypoints)
        XCTAssertEqual(try repository.fetch().first?.calibration?.keypoints, panel.calibration.keypoints)
        XCTAssertEqual(panel.captureState, .running(frameRate: 60))
        await panel.stop()
    }

    func testCameraPanelSnapshots() async throws {
        let (repository, match) = try makeCameraMatch()
        let capture = FakeCaptureSession(source: .clip(Self.footage.appending(path: "synthetic-netPost.mp4")))
        let panel = try makePanel(match: match, calibration: XCTUnwrap(match.calibration), repository: repository) { capture }
        await capture.start()
        let deadline = Date().addingTimeInterval(10)
        while await capture.captureStill() == nil, Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        await panel.refreshStill()
        await capture.stop()
        XCTAssertNotNil(panel.still)
        let sizes = ["phone": CGSize(width: 390, height: 220), "pad": CGSize(width: 774, height: 834)]
        let configs: [String: ViewImageConfig] = ["phone": .iPhone13, "pad": .iPadPro11(.landscape)]
        for name in ["phone", "pad"] {
            guard let size = sizes[name], let config = configs[name] else { continue }
            for style in [UIUserInterfaceStyle.light, .dark] {
                let view = CameraPanelView(model: panel).frame(width: size.width, height: size.height)
                assertSnapshot(
                    of: view,
                    as: .image(
                        precision: 0.99,
                        perceptualPrecision: 0.97,
                        layout: .fixed(width: size.width, height: size.height),
                        traits: config.traits.modifyingTraits { $0.userInterfaceStyle = style }
                    ),
                    named: "\(name)-\(style == .light ? "light" : "dark")"
                )
            }
        }
    }

    private func makeCameraMatch() throws -> (LocalMatchRepository, Match) {
        let container = try InMemoryModelContainer()
        self.container = container
        let repository = LocalMatchRepository(context: container.mainContext)
        let match = Match.sample()
        match.inputMode = InputMode.camera.rawValue
        match.cameraPlacementValue = .netPost
        match.calibration = try CourtCalibration(
            keypoints: Self.truth(),
            placement: .netPost,
            frameSize: CGSize(width: 1920, height: 1080),
            date: Fixtures.matchDay
        )
        try repository.save(match)
        return (repository, match)
    }

    private func makePanel(
        match: Match,
        calibration: CourtCalibration,
        repository: LocalMatchRepository,
        makeCapture: @escaping () -> any CaptureSource = { FakeCaptureSession(source: .blank(width: 640, height: 360)) }
    ) -> CameraPanelModel {
        CameraPanelModel(
            matchID: match.remoteID,
            calibration: calibration,
            makeCapture: makeCapture,
            suggester: NoSuggestions(),
            repository: repository,
            clock: FixedClock(Fixtures.matchDay)
        )
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(condition())
    }

    private static func truth() throws -> [CourtKeypoint: CGPoint] {
        struct Mark: Decodable {
            let keypoint: CourtKeypoint
            let pixel: [String: Double]
        }
        struct Frame: Decodable {
            let points: [Mark]
        }
        struct Truth: Decodable {
            let keypoints: [Frame]
        }
        let data = try Data(contentsOf: footage.appending(path: "ground_truth/synthetic-netPost.json"))
        let truth = try JSONDecoder().decode(Truth.self, from: data)
        return Dictionary(uniqueKeysWithValues: truth.keypoints[0].points.map {
            ($0.keypoint, CGPoint(x: $0.pixel["x"] ?? 0, y: $0.pixel["y"] ?? 0))
        })
    }
}
