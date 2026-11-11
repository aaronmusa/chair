//
//  CalibrationTests.swift
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
final class CalibrationTests: XCTestCase {
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

    func testAClipGetsSuggestedHandlesWhoseLinesOverlayTheCourt() async throws {
        let truth = try Self.truth("synthetic-netPost")
        let capture = FakeCaptureSession(source: .clip(Self.footage.appending(path: "synthetic-netPost.mp4")))
        let model = makeModel(capture: capture, suggester: CourtLineSuggester())

        await model.start()
        let deadline = Date().addingTimeInterval(90)
        while model.keypoints.isEmpty, Date() < deadline {
            try await Task.sleep(for: .milliseconds(200))
        }
        await model.stop()

        XCTAssertEqual(Set(model.keypoints.keys), Set(truth.keys))
        for (keypoint, pixel) in truth {
            let found = try XCTUnwrap(model.keypoints[keypoint])
            XCTAssertLessThan(hypot(found.x - pixel.x, found.y - pixel.y), 0.02 * 1920, "\(keypoint)")
        }
        let still = await capture.captureStill()
        let frame = try XCTUnwrap(still)
        let mask = try XCTUnwrap(LumaImage(pixelBuffer: frame).map { LineMask($0) })
        let points = model.projectedLines.flatMap(\.self).filter { CGRect(x: 0, y: 0, width: 1920, height: 1080).contains($0) }
        let onPaint = points.count { (mask.distance(atX: $0.x, y: $0.y) ?? 99) <= 3 }
        XCTAssertGreaterThan(Double(onPaint) / Double(max(points.count, 1)), 0.9)
        XCTAssertTrue(model.canContinue)
    }

    func testDraggingAHandleMovesTheLinesAndTheDepthPill() throws {
        let truth = try Self.truth("synthetic-netPost")
        let model = makeModel(initial: truth)
        let lines = model.projectedLines
        let depth = model.pills.first { $0.id == "depth" }
        let corner = try XCTUnwrap(CourtKeypoint(.doublesRight, .farBaseline))
        let start = try XCTUnwrap(truth[corner])

        model.move(corner, to: CGPoint(x: start.x + 40, y: start.y))

        XCTAssertNotEqual(model.projectedLines, lines)
        XCTAssertNotNil(depth)
        XCTAssertNotEqual(model.pills.first { $0.id == "depth" }, depth)
        XCTAssertTrue(model.isTouched)
    }

    func testPointsInALineOrTooFewDisableNextWithAHint() throws {
        let truth = try Self.truth("synthetic-netPost")
        let sideline = truth.filter { $0.key.across == .singlesRight }
        let model = makeModel(initial: sideline)
        XCTAssertFalse(model.canContinue)
        XCTAssertEqual(model.refusal, .collinear)

        let corner = try XCTUnwrap(CourtKeypoint(.doublesRight, .farBaseline))
        try model.move(corner, to: XCTUnwrap(truth[corner]))
        XCTAssertEqual(model.refusal, .collinear)
        XCTAssertFalse(model.canContinue)

        let tooFew = makeModel(initial: Dictionary(uniqueKeysWithValues: Array(truth.prefix(3))))
        XCTAssertEqual(tooFew.refusal, .tooFewPoints(3))
        XCTAssertEqual(tooFew.refusal?.message, "Place at least 4 points (3 placed)")
    }

    func testTheRulerReadsCourtPositionsInMetres() throws {
        let truth = try Self.truth("synthetic-netPost")
        let empty = makeModel()
        empty.measure(at: CGPoint(x: 500, y: 500))
        XCTAssertEqual(empty.measurement, "Place 4 points first")

        let model = makeModel(initial: truth)
        let tee = try XCTUnwrap(try truth[XCTUnwrap(CourtKeypoint(.centre, .farService))])
        model.measure(at: tee)

        XCTAssertEqual(model.measurement, "x 0.00 m · y 6.40 m")
    }

    func testBackgroundAndResumeKeepThePointsAndRestartThePreview() async throws {
        let truth = try Self.truth("synthetic-netPost")
        let capture = FakeCaptureSession(source: .blank(width: 1920, height: 1080))
        let model = makeModel(capture: capture, initial: truth)

        await model.start()
        await model.stop()
        XCTAssertEqual(model.captureState, .idle)
        await model.start()

        XCTAssertEqual(model.captureState, .running(frameRate: 60))
        XCTAssertEqual(model.keypoints, truth)
        await model.stop()
    }

    func testNextSavesTheCalibrationOnTheMatchSoARelaunchRestoresIt() throws {
        let truth = try Self.truth("synthetic-netPost")
        let container = try InMemoryModelContainer()
        self.container = container
        let repository = LocalMatchRepository(context: container.mainContext)
        let match = Match.sample()
        try repository.save(match)
        var opened: UUID?
        let model = CalibrationViewModel(
            matchID: match.remoteID,
            placement: .netPost,
            capture: FakeCaptureSession(source: .blank(width: 64, height: 36)),
            suggester: NoSuggestions(),
            repository: repository,
            clock: FixedClock(Fixtures.matchDay),
            initial: truth
        ) { opened = $0 }

        model.finish()

        XCTAssertEqual(opened, match.remoteID)
        let relaunched = try XCTUnwrap(LocalMatchRepository(context: ModelContext(container)).fetch().first)
        XCTAssertEqual(relaunched.cameraPlacementValue, .netPost)
        XCTAssertEqual(relaunched.calibration?.keypoints, truth)
        XCTAssertEqual(relaunched.calibration?.placement, .netPost)
    }

    func testCalibrationSnapshots() async throws {
        let truth = try Self.truth("synthetic-netPost")
        let capture = FakeCaptureSession(source: .clip(Self.footage.appending(path: "synthetic-netPost.mp4")))
        let model = makeModel(capture: capture, initial: truth)
        await capture.start()
        let deadline = Date().addingTimeInterval(10)
        while await capture.captureStill() == nil, Date() < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        await model.refresh()
        XCTAssertNotNil(model.still)
        await capture.stop()
        let configs: [(String, ViewImageConfig)] = [
            ("phone", .iPhone13(.landscape)),
            ("pad", ViewImageConfig(safeArea: .zero, size: CGSize(width: 1180, height: 820), traits: .init())),
        ]
        for (name, config) in configs {
            for style in [UIUserInterfaceStyle.light, .dark] {
                let host = UIHostingController(rootView: NavigationStack { CalibrationView(viewModel: model, isLive: false) })
                assertSnapshot(
                    of: host,
                    as: .image(
                        on: config,
                        precision: 0.99,
                        perceptualPrecision: 0.97,
                        traits: UITraitCollection(userInterfaceStyle: style)
                    ),
                    named: "\(name)-\(style == .light ? "light" : "dark")"
                )
            }
        }
    }

    private func makeModel(
        capture: any CaptureSource = FakeCaptureSession(source: .blank(width: 64, height: 36)),
        suggester: any KeypointSuggesting = NoSuggestions(),
        initial: [CourtKeypoint: CGPoint] = [:]
    ) -> CalibrationViewModel {
        CalibrationViewModel(
            matchID: UUID(),
            placement: .netPost,
            capture: capture,
            suggester: suggester,
            repository: nil,
            clock: FixedClock(Fixtures.matchDay),
            initial: initial
        ) { _ in }
    }

    private static func truth(_ clip: String) throws -> [CourtKeypoint: CGPoint] {
        let data = try Data(contentsOf: footage.appending(path: "ground_truth/\(clip).json"))
        return try JSONDecoder().decode(Truth.self, from: data).pixels
    }
}

private struct TruthMark: Decodable {
    let keypoint: CourtKeypoint
    let pixel: TruthPoint
}

private struct TruthPoint: Decodable {
    let x: Double
    let y: Double
}

private struct TruthKeypoints: Decodable {
    let points: [TruthMark]
}

private struct Truth: Decodable {
    let keypoints: [TruthKeypoints]

    var pixels: [CourtKeypoint: CGPoint] {
        Dictionary(uniqueKeysWithValues: keypoints[0].points.map { ($0.keypoint, CGPoint(x: $0.pixel.x, y: $0.pixel.y)) })
    }
}
