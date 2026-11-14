//
//  HomographyTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/11/26.
//

import CoreGraphics
import XCTest

import ChairKit

final class HomographyTests: XCTestCase {
    func testRandomCourtPointsRoundTripWithinOneCentimetre() throws {
        let camera = PinholeCamera.behindBaseline
        let homography = try XCTUnwrap(Homography(camera.keypoints(CourtKeypoint.defaultSet(for: .baseline))))
        var generator = SeededGenerator(seed: 7)

        for _ in 0 ..< 100 {
            let point = CourtPoint(
                x: .random(in: -CourtDimensions.halfDoublesWidth ... CourtDimensions.halfDoublesWidth, using: &generator),
                y: .random(in: -CourtDimensions.halfLength ... CourtDimensions.halfLength, using: &generator)
            )
            let back = try XCTUnwrap(homography.toCourt(homography.toPixel(point)))
            XCTAssertLessThan(back.distance(to: point), 0.01)
        }
    }

    func testTheNetPostKeypointsMapTheWholeCourtFromTheFarSide() throws {
        let camera = PinholeCamera.netPost
        let keypoints = camera.keypoints(CourtKeypoint.defaultSet(for: .netPost))
        XCTAssertEqual(keypoints.count, 8)
        XCTAssertTrue(keypoints.keys.allSatisfy { camera.inFrame($0.court) })
        let homography = try XCTUnwrap(Homography(keypoints))
        var generator = SeededGenerator(seed: 11)

        for _ in 0 ..< 100 {
            let point = CourtPoint(
                x: .random(in: 0 ... CourtDimensions.halfDoublesWidth, using: &generator),
                y: .random(in: -CourtDimensions.halfLength ... CourtDimensions.halfLength, using: &generator)
            )
            let pixel = try XCTUnwrap(camera.project(point))
            let mapped = try XCTUnwrap(homography.toCourt(pixel))
            XCTAssertLessThan(mapped.distance(to: point), 0.01)
        }
    }

    func testTheNetPostCannotSeeTheNearCorners() {
        let camera = PinholeCamera.netPost

        XCTAssertFalse(camera.inFrame(CourtPoint(x: -CourtDimensions.halfDoublesWidth, y: CourtDimensions.halfLength)))
        XCTAssertFalse(camera.inFrame(CourtPoint(x: -CourtDimensions.halfDoublesWidth, y: -CourtDimensions.halfLength)))
    }

    func testExtraNoisyKeypointsAreAveragedByLeastSquares() throws {
        let camera = PinholeCamera.netPost
        var generator = SeededGenerator(seed: 3)
        let exact = camera.keypoints(CourtKeypoint.defaultSet(for: .netPost))
        let noisy = Dictionary(uniqueKeysWithValues: exact.sorted { $0.key.rawValue < $1.key.rawValue }.map { keypoint, pixel in
            (
                keypoint,
                CGPoint(x: pixel.x + .random(in: -1 ... 1, using: &generator), y: pixel.y + .random(in: -1 ... 1, using: &generator))
            )
        })

        let homography = try XCTUnwrap(Homography(noisy))

        XCTAssertLessThan(homography.reprojectionError(noisy), 1.5)
        let farCorner = CourtPoint(x: CourtDimensions.halfDoublesWidth, y: CourtDimensions.halfLength)
        let mapped = try XCTUnwrap(try homography.toCourt(XCTUnwrap(camera.project(farCorner))))
        XCTAssertLessThan(mapped.distance(to: farCorner), 0.15)
    }

    func testAPixelAboveTheHorizonHasNoCourtPoint() throws {
        let camera = PinholeCamera.behindBaseline
        let homography = try XCTUnwrap(Homography(camera.keypoints(CourtKeypoint.defaultSet(for: .baseline))))

        XCTAssertNil(homography.toCourt(CGPoint(x: 960, y: 10)))
        XCTAssertNotNil(homography.toCourt(CGPoint(x: 960, y: 700)))
    }

    func testAKeypointOnTheHorizonGivesNilWithoutCrashing() throws {
        let camera = PinholeCamera.behindBaseline
        let homography = try XCTUnwrap(Homography(camera.keypoints(CourtKeypoint.defaultSet(for: .baseline))))
        let horizon = try XCTUnwrap((0 ..< 1080).first { homography.toCourt(CGPoint(x: 960, y: Double($0) + 0.5)) != nil })

        XCTAssertNil(homography.toCourt(CGPoint(x: 960, y: Double(horizon) - 1)))
        XCTAssertNil(homography.toCourt(CGPoint(x: Double.infinity, y: 500)))
    }

    func testFewerThanFourOrCollinearPointsBuildNothing() {
        let camera = PinholeCamera.behindBaseline
        let three = camera.keypoints(Array(CourtKeypoint.defaultSet(for: .baseline).prefix(3)))
        let baselineOnly = camera.keypoints([
            CourtKeypoint(.doublesLeft, .farBaseline),
            CourtKeypoint(.singlesLeft, .farBaseline),
            CourtKeypoint(.singlesRight, .farBaseline),
            CourtKeypoint(.doublesRight, .farBaseline),
        ].compactMap(\.self))

        XCTAssertNil(Homography(three))
        XCTAssertNil(Homography(baselineOnly))
    }

    func testARefusalSaysWhy() {
        let sideline = [CourtKeypoint.Along.farBaseline, .farService, .nearService, .nearBaseline]
            .compactMap { CourtKeypoint(.singlesRight, $0) }
        let farCorner = CourtKeypoint(.doublesRight, .farBaseline)

        XCTAssertEqual(Homography.refusal(for: Array(sideline.prefix(3))), .tooFewPoints(3))
        XCTAssertEqual(Homography.refusal(for: sideline + [farCorner].compactMap(\.self)), .collinear)
        XCTAssertEqual(Homography.refusal(for: CourtKeypoint.defaultSet(for: .netPost)), nil)
        XCTAssertEqual(Homography.refusal(for: CourtKeypoint.defaultSet(for: .baseline)), nil)
        XCTAssertEqual(Homography.Refusal.tooFewPoints(3).message, "Place at least 4 points (3 placed)")
    }

    func testTheUndistorterIsAppliedBothWays() throws {
        let shift = ShiftUndistorter(offset: 5)
        let camera = PinholeCamera.behindBaseline
        let distorted = camera.keypoints(CourtKeypoint.defaultSet(for: .baseline)).mapValues { CGPoint(x: $0.x + 5, y: $0.y) }

        let homography = try XCTUnwrap(Homography(distorted, undistorter: shift))

        let corner = CourtPoint(x: CourtDimensions.halfDoublesWidth, y: -CourtDimensions.halfLength)
        let pixel = try XCTUnwrap(camera.project(corner))
        XCTAssertEqual(homography.toPixel(corner).x, pixel.x + 5, accuracy: 0.01)
        XCTAssertLessThan(try XCTUnwrap(homography.toCourt(CGPoint(x: pixel.x + 5, y: pixel.y))).distance(to: corner), 0.01)
    }
}

private struct ShiftUndistorter: Undistorter {
    let offset: Double

    func undistort(_ pixel: CGPoint) -> CGPoint {
        CGPoint(x: pixel.x - offset, y: pixel.y)
    }

    func distort(_ pixel: CGPoint) -> CGPoint {
        CGPoint(x: pixel.x + offset, y: pixel.y)
    }
}
