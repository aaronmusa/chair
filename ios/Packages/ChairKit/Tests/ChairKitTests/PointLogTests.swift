//
//  PointLogTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

final class PointLogTests: XCTestCase {
    func testTheCurrentGameListsOnlyItsPoints() throws {
        var log = try MatchLog(rules: MatchRules())
        for _ in 0 ..< 4 {
            try log.append(point(.a))
        }
        try log.append(point(.b, outcome: .unforcedError))
        try log.append(TimedEvent(.fault, at: Fixtures.matchDay))
        try log.append(point(.a, outcome: .winner))

        let points = log.currentGamePoints

        XCTAssertEqual(points.map(\.number), [1, 2])
        XCTAssertEqual(points.map(\.winner), [.b, .a])
        XCTAssertEqual(points.map(\.outcome), [.unforcedError, .winner])
        XCTAssertEqual(points.map(\.index), [4, 6])
    }

    func testFlippingPointTwoMatchesTheReplayWithItsWinnerSwapped() throws {
        var log = try MatchLog(rules: MatchRules())
        try log.append(point(.a))
        try log.append(point(.a, outcome: .winner))
        try log.append(point(.b))

        for event in try log.flipEvents(at: 1) {
            try log.append(TimedEvent(event, at: Fixtures.matchDay))
        }

        let expected = try MatchLog(rules: MatchRules(), events: [point(.a), point(.b, outcome: .winner), point(.b)])
        XCTAssertEqual(log.state, expected.state)
        XCTAssertEqual(log.currentGamePoints.map(\.winner), [.a, .b, .b])
    }

    func testAnAceCannotBeFlipped() throws {
        var log = try MatchLog(rules: MatchRules())
        try log.append(point(.a))
        try log.append(point(.a, outcome: .ace))
        try log.append(point(.b))

        XCTAssertThrowsError(try log.flipEvents(at: 1)) { error in
            XCTAssertEqual(error as? FlipError, .aceOrDoubleFault)
        }
    }

    func testAPointFromAnEarlierSetCannotBeFlipped() throws {
        var log = try MatchLog(rules: MatchRules())
        for _ in 0 ..< 24 {
            try log.append(point(.a))
        }
        try log.append(point(.b))

        XCTAssertThrowsError(try log.flipEvents(at: 0)) { error in
            XCTAssertEqual(error as? FlipError, .otherSet)
        }
    }

    func testAFaultBetweenPointsIsReplayed() throws {
        var log = try MatchLog(rules: MatchRules())
        try log.append(point(.a))
        try log.append(TimedEvent(.fault, at: Fixtures.matchDay))

        let events = try log.flipEvents(at: 0)

        XCTAssertEqual(events, [.undo, .undo, .pointWon(by: .b, outcome: nil, ending: nil), .fault])
    }

    func testAScoreFixSinceThePointRefusesTheFlip() throws {
        var log = try MatchLog(rules: MatchRules())
        try log.append(point(.a))
        try log.append(TimedEvent(.setScore(log.snapshot), at: Fixtures.matchDay))

        XCTAssertThrowsError(try log.flipEvents(at: 0)) { error in
            XCTAssertEqual(error as? FlipError, .changedSince)
        }
    }

    private func point(
        _ side: Side,
        outcome: PointOutcome? = nil
    ) -> TimedEvent {
        TimedEvent(.pointWon(by: side, outcome: outcome, ending: nil), at: Fixtures.matchDay)
    }
}
