//
//  FixedClockTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 10/27/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

final class FixedClockTests: XCTestCase {
    private let matchDay = Date(timeIntervalSince1970: 1_793_000_000)

    func testNowReturnsTheDateItWasSetTo() {
        let clock = FixedClock(matchDay)

        XCTAssertEqual(clock.now, matchDay)
    }

    func testNowNeverAdvancesOnItsOwn() async throws {
        let clock = FixedClock(matchDay)

        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(clock.now, matchDay)
        XCTAssertEqual(clock.now, clock.now)
    }

    func testAdvanceMovesNowByTheGivenInterval() {
        var clock = FixedClock(matchDay)

        clock.advance(by: 90)

        XCTAssertEqual(clock.now, matchDay.addingTimeInterval(90))
    }

    func testFixedClockStandsInForAnyClockProvider() {
        let provider: any ClockProvider = FixedClock(matchDay)

        XCTAssertEqual(provider.now, matchDay)
    }

    func testSystemClockFollowsTheRealTime() {
        let before = Date()
        let now = SystemClock().now
        let after = Date()

        XCTAssertTrue((before ... after).contains(now))
    }
}
