//
//  MatchUpdateTests.swift
//  ChairKitTests
//
//  Created by Aaron Musa on 11/2/26.
//

import Foundation
import XCTest

import ChairKit
import ChairTestSupport

final class MatchUpdateTests: XCTestCase {
    func testNewEventsAreAppendedAsRows() throws {
        let match = Match(playedAt: Fixtures.matchDay, format: .singles, createdAt: Fixtures.matchDay, updatedAt: Fixtures.matchDay)
        var log = try MatchLog(rules: MatchRules())
        try log.append(point(.a))
        try log.append(TimedEvent(.fault, at: Fixtures.matchDay))

        match.update(from: log, at: Fixtures.matchDay)

        XCTAssertEqual(match.orderedPoints.map(\.eventKind), ["point", "fault"])
        XCTAssertEqual(match.sets, [])
        XCTAssertEqual(match.status, .inProgress)
    }

    func testAnUndoMarksTheEarlierRowAndAddsTheUndoRow() throws {
        let match = Match(playedAt: Fixtures.matchDay, format: .singles, createdAt: Fixtures.matchDay, updatedAt: Fixtures.matchDay)
        var log = try MatchLog(rules: MatchRules())
        try log.append(point(.a))
        match.update(from: log, at: Fixtures.matchDay)

        try log.append(TimedEvent(.undo, at: Fixtures.matchDay))
        match.update(from: log, at: Fixtures.matchDay)

        XCTAssertEqual(match.orderedPoints.map(\.undone), [true, false])
        XCTAssertEqual(match.orderedPoints.map(\.eventKind), ["point", "undo"])
        let replayed = try MatchLog(rules: match.rules, format: match.format, pointEvents: match.points)
        XCTAssertEqual(replayed.state, log.state)
    }

    func testAGameInTheCurrentSetIsStoredAsTheSetInProgress() throws {
        let match = Match(playedAt: Fixtures.matchDay, format: .singles, createdAt: Fixtures.matchDay, updatedAt: Fixtures.matchDay)
        var log = try MatchLog(rules: MatchRules())
        for _ in 0 ..< 4 {
            try log.append(point(.a))
        }

        match.update(from: log, at: Fixtures.matchDay)

        XCTAssertEqual(match.sets, [SetScore(a: 1, b: 0)])
    }

    func testARetirementCompletesTheMatch() throws {
        let match = Match(playedAt: Fixtures.matchDay, format: .singles, createdAt: Fixtures.matchDay, updatedAt: Fixtures.matchDay)
        var log = try MatchLog(rules: MatchRules())
        try log.append(point(.a))
        try log.append(TimedEvent(.retire(.b), at: Fixtures.matchDay))

        match.update(from: log, at: Fixtures.matchDay)

        XCTAssertEqual(match.status, .completed)
    }

    private func point(_ side: Side) -> TimedEvent {
        TimedEvent(.pointWon(by: side, outcome: nil, ending: nil), at: Fixtures.matchDay)
    }
}
