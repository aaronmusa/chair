//
//  CourtModelTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/11/26.
//

import CoreGraphics
import XCTest

import ChairKit

final class CourtModelTests: XCTestCase {
    private let sideline = CourtDimensions.halfDoublesWidth

    func testAMarkTouchingTheLineFromOutsideIsOnTheLine() {
        let call = CourtModel.isIn(CourtPoint(x: sideline + 0.03, y: 2), singles: false, radius: 0.033)

        guard case let .onLine(distance) = call else { return XCTFail("expected onLine, got \(call)") }
        XCTAssertEqual(distance, 0.03, accuracy: 1e-9)
    }

    func testAMarkClearOfTheLineIsOut() {
        XCTAssertEqual(CourtModel.isIn(CourtPoint(x: sideline + 0.07, y: 2), singles: false, radius: 0.033), .out)
    }

    func testAMarkInsideIsIn() {
        XCTAssertEqual(CourtModel.isIn(CourtPoint(x: sideline - 0.01, y: 2), singles: false), .in)
    }

    func testTheSinglesSidelineAppliesInSingles() {
        let alley = CourtPoint(x: CourtDimensions.halfSinglesWidth + 0.5, y: 0)

        XCTAssertEqual(CourtModel.isIn(alley, singles: false), .in)
        XCTAssertEqual(CourtModel.isIn(alley, singles: true), .out)
    }

    func testBeyondTheCornerMeasuresToTheCorner() {
        let call = CourtModel.isIn(CourtPoint(x: sideline + 0.02, y: CourtDimensions.halfLength + 0.02), singles: false)

        guard case let .onLine(distance) = call else { return XCTFail("expected onLine, got \(call)") }
        XCTAssertEqual(distance, (0.02 * 0.02 * 2).squareRoot(), accuracy: 1e-9)
    }

    func testTheModelHasEveryCourtLine() {
        XCTAssertEqual(CourtModel.lines.count, 11)
    }
}

final class CourtKeypointTests: XCTestCase {
    func testThereAreFourteenIntersections() {
        XCTAssertEqual(CourtKeypoint.all.count, 14)
        XCTAssertEqual(Set(CourtKeypoint.all).count, 14)
    }

    func testOnlyRealIntersectionsExist() {
        XCTAssertNil(CourtKeypoint(.centre, .farBaseline))
        XCTAssertNil(CourtKeypoint(.doublesLeft, .nearService))
        XCTAssertNotNil(CourtKeypoint(.centre, .nearService))
    }

    func testTheRawValueRoundTrips() throws {
        let keypoint = try XCTUnwrap(CourtKeypoint(.singlesRight, .farService))

        XCTAssertEqual(keypoint.rawValue, "singlesRight-farService")
        XCTAssertEqual(CourtKeypoint(rawValue: keypoint.rawValue), keypoint)
        XCTAssertNil(CourtKeypoint(rawValue: "centre-farBaseline"))
        XCTAssertEqual(keypoint.court, CourtPoint(x: 4.115, y: 6.4))
    }

    func testEachPlacementHasItsDefaultSet() {
        XCTAssertEqual(CourtKeypoint.defaultSet(for: .netPost).count, 8)
        XCTAssertEqual(CourtKeypoint.defaultSet(for: .chair), CourtKeypoint.defaultSet(for: .netPost))
        XCTAssertEqual(CourtKeypoint.defaultSet(for: .baseline).map(\.rawValue), [
            "doublesLeft-farBaseline", "doublesRight-farBaseline", "doublesRight-nearBaseline", "doublesLeft-nearBaseline",
        ])
    }
}

final class CourtCalibrationTests: XCTestCase {
    func testACalibrationRoundTripsThroughJSON() throws {
        let calibration = try makeCalibration(.netPost, camera: .netPost)

        let data = try JSONEncoder().encode(calibration)
        let decoded = try JSONDecoder().decode(CourtCalibration.self, from: data)

        XCTAssertEqual(decoded, calibration)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["keypoints", "placement", "lens", "frameWidth", "frameHeight", "quality", "date"])
        let first = try XCTUnwrap((json["keypoints"] as? [[String: Any]])?.first)
        XCTAssertEqual(first["keypoint"] as? String, "singlesRight-farBaseline")
    }

    func testTooFewKeypointsCannotBeDecoded() throws {
        let calibration = try makeCalibration(.netPost, camera: .netPost)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(calibration)) as? [String: Any])
        json["keypoints"] = (json["keypoints"] as? [Any])?.prefix(3).map(\.self)

        XCTAssertThrowsError(try JSONDecoder().decode(CourtCalibration.self, from: JSONSerialization.data(withJSONObject: json)))
    }

    func testQualityIsMeasuredOverTheVisibleLines() throws {
        let quality = try makeCalibration(.netPost, camera: .netPost).quality

        let sideline = try XCTUnwrap(quality.sidelineError)
        let baseline = try XCTUnwrap(quality.baselineError)
        XCTAssertGreaterThan(sideline, 0)
        XCTAssertGreaterThan(baseline, sideline / 10)
        XCTAssertLessThan(baseline, 30)
        XCTAssertLessThan(quality.reprojectionError, 0.01)
    }

    func testAFarCornerCostsMoreCentimetresPerPixelThanANearOne() throws {
        let homography = try makeCalibration(.baseline, camera: .behindBaseline).homography
        let far = CourtPoint(x: CourtDimensions.halfDoublesWidth, y: CourtDimensions.halfLength)
        let near = CourtPoint(x: CourtDimensions.halfDoublesWidth, y: -CourtDimensions.halfLength)

        let farError = try XCTUnwrap(CalibrationQuality.centimetresPerPixel(at: far, homography: homography))
        let nearError = try XCTUnwrap(CalibrationQuality.centimetresPerPixel(at: near, homography: homography))
        XCTAssertGreaterThan(farError, nearError * 3)
    }

    private func makeCalibration(
        _ placement: CameraPlacement,
        camera: PinholeCamera
    ) throws -> CourtCalibration {
        try XCTUnwrap(CourtCalibration(
            keypoints: camera.keypoints(CourtKeypoint.defaultSet(for: placement)),
            placement: placement,
            frameSize: camera.size,
            date: Date(timeIntervalSince1970: 1_800_000_000)
        ))
    }
}
