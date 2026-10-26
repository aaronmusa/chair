//
//  CourtGeometryTests.swift
//  ChairUIPackageTests
//
//  Created by Aaron Musa on 10/27/26.
//

import CoreGraphics
import XCTest

@testable import ChairUI

final class CourtGeometryTests: XCTestCase {
    private let server = CourtPoint.behindBaseline(.near, on: .deuce, by: 1)

    func testDeuceServerSitsBottomRightInPortrait() {
        let size = CGSize(width: 340, height: 340 / CourtCoordinate.aspectRatio(for: .portrait))
        let point = CourtCoordinate(size: size, orientation: .portrait).point(server)

        XCTAssertGreaterThan(point.x, size.width / 2, "deuce side is right of centre")
        XCTAssertGreaterThan(point.y, size.height / 2, "near side is the bottom half")
    }

    func testDeuceServerSitsBottomLeftInLandscape() {
        let size = CGSize(width: 600, height: 600 / CourtCoordinate.aspectRatio(for: .landscape))
        let point = CourtCoordinate(size: size, orientation: .landscape).point(server)

        XCTAssertLessThan(point.x, size.width / 2, "near side is the left half")
        XCTAssertGreaterThan(point.y, size.height / 2, "deuce side is below centre")
    }

    func testServerIsOneMetreBehindTheBaseline() {
        let coordinate = CourtCoordinate(size: CGSize(width: 340, height: 676), orientation: .portrait)
        let baseline = coordinate.point(CourtPoint(x: server.x, y: -CourtDimensions.halfLength))

        XCTAssertEqual(coordinate.point(server).y - baseline.y, coordinate.pointsPerMetre, accuracy: 0.001)
    }

    func testFarDeuceIsTheOtherWayAcross() {
        XCTAssertGreaterThan(CourtPoint.behindBaseline(.near, on: .deuce, by: 1).x, 0)
        XCTAssertLessThan(CourtPoint.behindBaseline(.far, on: .deuce, by: 1).x, 0)
        XCTAssertLessThan(CourtPoint.behindBaseline(.near, on: .ad, by: 1).x, 0)
    }

    func testCourtKeepsItsRealProportions() {
        let size = CGSize(width: 340, height: 340 / CourtCoordinate.aspectRatio(for: .portrait))
        let coordinate = CourtCoordinate(size: size, orientation: .portrait)
        let court = coordinate.rect(
            CourtPoint(x: -CourtDimensions.halfDoublesWidth, y: -CourtDimensions.halfLength),
            CourtPoint(x: CourtDimensions.halfDoublesWidth, y: CourtDimensions.halfLength)
        )

        XCTAssertEqual(court.height / court.width, 23.77 / 10.97, accuracy: 0.001)
    }
}
